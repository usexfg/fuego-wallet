use crate::error::{Result, SdkError};
use crate::chain::{ChainHeader, MerkleProof, ChainType};
use reqwest::Client;

/// JSON-RPC client for Bitcoin-family nodes.
pub struct BtcRpcClient {
    endpoint: String,
    user: String,
    pass: String,
    client: Client,
}

impl BtcRpcClient {
    pub fn new(endpoint: impl Into<String>, user: impl Into<String>, pass: impl Into<String>) -> Self {
        Self {
            endpoint: endpoint.into(),
            user: user.into(),
            pass: pass.into(),
            client: Client::builder()
                .timeout(std::time::Duration::from_secs(30))
                .build()
                .unwrap_or_else(|_| Client::new()),
        }
    }

    pub async fn get_block_count(&self) -> Result<u64> {
        let val: u64 = self.rpc_call("getblockcount", &[]).await?;
        Ok(val)
    }

    pub async fn get_block_hash(&self, height: u64) -> Result<String> {
        let hash: String = self.rpc_call("getblockhash", &[height.into()]).await?;
        Ok(hash)
    }

    pub async fn get_block_header(&self, hash: &str) -> Result<ChainHeader> {
        let header: serde_json::Value = self.rpc_call("getblockheader", &[hash.into()]).await?;

        let height = header["height"].as_u64().unwrap_or(0);
        let prev_hash = header["previousblockhash"].as_str().unwrap_or("0").to_string();
        let merkle_root = header["merkleroot"].as_str().unwrap_or("0").to_string();
        let timestamp = header["time"].as_u64().unwrap_or(0);
        let bits = header["bits"]
            .as_str()
            .and_then(|b| u32::from_str_radix(b, 16).ok())
            .unwrap_or(0);
        let confirmations = header["confirmations"].as_u64().unwrap_or(0) as u32;

        Ok(ChainHeader {
            chain: ChainType::BitcoinCash, // caller overrides if needed
            height,
            hash: hash.to_string(),
            prev_hash,
            merkle_root,
            timestamp,
            bits,
            confirmations,
        })
    }

    /// Get merkle proof for a transaction by computing it from the raw block.
    pub async fn get_merkle_proof(&self, tx_hash: &str, chain: ChainType) -> Result<MerkleProof> {
        // 1. Get the transaction to find which block it's in
        let tx: serde_json::Value = self.rpc_call(
            "getrawtransaction",
            &[tx_hash.into(), true.into()],
        ).await?;

        let block_hash = tx["blockhash"]
            .as_str()
            .ok_or_else(|| SdkError::Network(format!("Transaction {tx_hash} not found in any block")))?;

        // 2. Get the raw block (verbosity=0 returns hex-encoded block)
        let raw_block_hex: String = self.rpc_call(
            "getblock",
            &[block_hash.into(), 0u64.into()],
        ).await?;

        // 3. Decode the raw block to find tx index and build merkle path
        let block_bytes = hex::decode(&raw_block_hex)
            .map_err(|e| SdkError::Serialization(format!("Failed to decode raw block: {e}")))?;

        let (tx_index, total_txs, merkle_path) = decode_block_merkle(&block_bytes, tx_hash)?;

        // 4. Get block height from header
        let header_val: serde_json::Value = self.rpc_call(
            "getblockheader",
            &[block_hash.into()],
        ).await?;
        let height = header_val["height"].as_u64().unwrap_or(0);

        Ok(MerkleProof {
            chain,
            tx_hash: tx_hash.to_string(),
            block_height: height,
            block_hash: block_hash.to_string(),
            merkle_path,
            tx_index,
            total_txs,
        })
    }

    pub async fn get_raw_transaction(&self, tx_hash: &str) -> Result<serde_json::Value> {
        self.rpc_call("getrawtransaction", &[tx_hash.into(), true.into()]).await
    }

    pub async fn get_block(&self, hash: &str, verbosity: u8) -> Result<serde_json::Value> {
        self.rpc_call("getblock", &[hash.into(), verbosity.into()]).await
    }

    async fn rpc_call<T: serde::de::DeserializeOwned>(&self, method: &str, params: &[serde_json::Value]) -> Result<T> {
        let body = serde_json::json!({
            "jsonrpc": "1.0",
            "id": "fuego-sdk",
            "method": method,
            "params": params,
        });

        let resp = self.client
            .post(&self.endpoint)
            .basic_auth(&self.user, Some(&self.pass))
            .json(&body)
            .send()
            .await
            .map_err(|e| SdkError::Network(format!("RPC call {method} failed: {e}")))?;

        let status = resp.status();
        let text = resp.text().await
            .map_err(|e| SdkError::Network(format!("Failed to read RPC response: {e}")))?;

        if !status.is_success() {
            return Err(SdkError::Network(format!("RPC {method} returned {status}")));
        }

        let json: serde_json::Value = serde_json::from_str(&text)
            .map_err(|e| SdkError::Serialization(format!("Invalid RPC response: {e}")))?;

        if let Some(err) = json.get("error").filter(|e| !e.is_null()) {
            return Err(SdkError::Network(format!("RPC error in {method}: {err}")));
        }

        serde_json::from_value(json["result"].clone())
            .map_err(|e| SdkError::Serialization(format!("Failed to decode result of {method}: {e}")))
    }
}

/// Decode a raw Bitcoin block to find a transaction's index and merkle path.
/// Returns (tx_index, total_txs, merkle_path).
fn decode_block_merkle(block_bytes: &[u8], target_txid: &str) -> Result<(u32, u32, Vec<String>)> {
    use sha2::{Sha256, Digest};

    if block_bytes.len() < 80 {
        return Err(SdkError::Serialization("Block too short".into()));
    }

    // Skip 80-byte block header
    let mut offset = 80;

    // Read varint for tx count
    let (tx_count, new_offset) = read_varint(block_bytes, offset)?;
    offset = new_offset;

    // Collect all transaction hashes in internal byte order
    let mut tx_hashes: Vec<Vec<u8>> = Vec::with_capacity(tx_count as usize);
    let mut target_index: Option<u32> = None;

    for i in 0..tx_count {
        if offset >= block_bytes.len() {
            return Err(SdkError::Serialization("Block truncated".into()));
        }

        let tx_start = offset;

        // Read tx version (4 bytes LE)
        offset += 4;

        // Skip segwit marker if present
        if block_bytes[offset] == 0x00 {
            offset += 1;
            if offset < block_bytes.len() && block_bytes[offset] == 0x01 {
                offset += 1; // segwit marker
            }
        }

        // Count inputs
        let (input_count, new_offset) = read_varint(block_bytes, offset)?;
        offset = new_offset;

        // Skip all inputs
        for _ in 0..input_count {
            // prev tx hash (32 bytes)
            offset += 32;
            // prev output index (4 bytes)
            offset += 4;
            // script length
            let (script_len, new_offset) = read_varint(block_bytes, offset)?;
            offset = new_offset;
            // script
            offset += script_len as usize;
            // sequence (4 bytes)
            offset += 4;
        }

        // Count outputs
        let (output_count, new_offset) = read_varint(block_bytes, offset)?;
        offset = new_offset;

        // Skip all outputs
        for _ in 0..output_count {
            // amount (8 bytes)
            offset += 8;
            // script length
            let (script_len, new_offset) = read_varint(block_bytes, offset)?;
            offset = new_offset;
            // script
            offset += script_len as usize;
        }

        // Skip witness data if segwit
        if tx_start < block_bytes.len() && block_bytes[tx_start] == 0x00 {
            // Already consumed marker, check if there's actual witness data
        }

        // Locktime (4 bytes)
        offset += 4;

        // Compute tx hash (double SHA-256 of the raw tx)
        let raw_tx = &block_bytes[tx_start..offset];
        let first = Sha256::digest(raw_tx);
        let tx_hash = Sha256::digest(first);

        // Check if this is our target tx (compare in reversed byte order)
        let display_hash: Vec<u8> = tx_hash.iter().rev().cloned().collect();
        let display_hex = hex::encode(&display_hash);

        if display_hex == target_txid {
            target_index = Some(i as u32);
        }

        tx_hashes.push(tx_hash.to_vec());
    }

    let tx_index = target_index
        .ok_or_else(|| SdkError::Network(format!("Transaction {target_txid} not found in block")))?;

    // Build merkle path by pairing hashes level by level
    let mut current_level = tx_hashes.clone();
    let mut merkle_path = Vec::new();
    let mut idx = tx_index;

    while current_level.len() > 1 {
        // If odd number of hashes, duplicate the last one
        if current_level.len() % 2 != 0 {
            let last = current_level.last().cloned().unwrap();
            current_level.push(last);
        }

        let sibling_idx = if idx % 2 == 0 { idx + 1 } else { idx - 1 };
        if (sibling_idx as usize) < current_level.len() {
            merkle_path.push(hex::encode(&current_level[sibling_idx as usize]));
        }

        // Build next level
        let mut next_level = Vec::with_capacity(current_level.len() / 2);
        for pair in current_level.chunks(2) {
            let combined = [pair[0].as_slice(), pair[1].as_slice()].concat();
            let first = Sha256::digest(&combined);
            let hash = Sha256::digest(first);
            next_level.push(hash.to_vec());
        }

        current_level = next_level;
        idx /= 2;
    }

    Ok((tx_index, tx_count as u32, merkle_path))
}

/// Read a Bitcoin varint from a byte slice.
fn read_varint(data: &[u8], offset: usize) -> Result<(u64, usize)> {
    if offset >= data.len() {
        return Err(SdkError::Serialization("Truncated varint".into()));
    }

    match data[offset] {
        0xfd => {
            if offset + 3 > data.len() {
                return Err(SdkError::Serialization("Truncated varint".into()));
            }
            let val = u16::from_le_bytes([data[offset + 1], data[offset + 2]]);
            Ok((val as u64, offset + 3))
        }
        0xfe => {
            if offset + 5 > data.len() {
                return Err(SdkError::Serialization("Truncated varint".into()));
            }
            let val = u32::from_le_bytes([
                data[offset + 1],
                data[offset + 2],
                data[offset + 3],
                data[offset + 4],
            ]);
            Ok((val as u64, offset + 5))
        }
        0xff => {
            if offset + 9 > data.len() {
                return Err(SdkError::Serialization("Truncated varint".into()));
            }
            let val = u64::from_le_bytes([
                data[offset + 1],
                data[offset + 2],
                data[offset + 3],
                data[offset + 4],
                data[offset + 5],
                data[offset + 6],
                data[offset + 7],
                data[offset + 8],
            ]);
            Ok((val, offset + 9))
        }
        n => Ok((n as u64, offset + 1)),
    }
}
