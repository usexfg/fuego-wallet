use crate::error::{Result, SdkError};
use crate::chain::btc_rpc::BtcRpcClient;
use crate::chain::{ChainSpv, ChainHeader, MerkleProof, PaymentProof, ChainType};

/// Bitcoin-family SPV adapter (BCH).
/// Uses native block header validation and merkle proof verification.
pub struct BitcoinChain {
    chain: ChainType,
    rpc: BtcRpcClient,
}

impl BitcoinChain {
    pub fn new(chain: ChainType, endpoint: &str, user: &str, pass: &str) -> Result<Self> {
        if !chain.is_bitcoin_family() {
            return Err(SdkError::Config(format!(
                "BitcoinChain only supports Bitcoin-family chains, got {chain:?}"
            )));
        }
        Ok(Self {
            chain,
            rpc: BtcRpcClient::new(endpoint, user, pass),
        })
    }

    /// Reverse bytes in a hex string (txid display <-> internal byte order).
    fn reverse_hex_bytes(hex_str: &str) -> Result<String> {
        let bytes = hex::decode(hex_str)
            .map_err(|e| SdkError::Serialization(format!("Invalid hex in reverse_hex_bytes: {e}")))?;
        let reversed: Vec<u8> = bytes.into_iter().rev().collect();
        Ok(hex::encode(reversed))
    }
}

#[async_trait::async_trait]
impl ChainSpv for BitcoinChain {
    fn chain_type(&self) -> ChainType {
        self.chain
    }

    async fn get_height(&self) -> Result<u64> {
        self.rpc.get_block_count().await
    }

    async fn get_header(&self, height: u64) -> Result<ChainHeader> {
        let hash = self.rpc.get_block_hash(height).await?;
        let mut header = self.rpc.get_block_header(&hash).await?;
        header.chain = self.chain;
        Ok(header)
    }

    async fn get_header_by_hash(&self, hash: &str) -> Result<ChainHeader> {
        let mut header = self.rpc.get_block_header(hash).await?;
        header.chain = self.chain;
        Ok(header)
    }

    async fn get_latest_header(&self) -> Result<ChainHeader> {
        let height = self.get_height().await?;
        self.get_header(height).await
    }

    async fn get_merkle_proof(&self, tx_hash: &str) -> Result<MerkleProof> {
        self.rpc.get_merkle_proof(tx_hash, self.chain).await
    }

    fn verify_merkle(&self, proof: &MerkleProof, header: &ChainHeader) -> Result<bool> {
        use sha2::{Sha256, Digest};

        // Bitcoin txids are displayed in reversed byte order.
        // The merkle tree operates on internal byte order, so we must reverse
        // the txid before reconstructing the root.
        let internal_txid = Self::reverse_hex_bytes(&proof.tx_hash)?;
        let mut current = hex::decode(&internal_txid)
            .map_err(|e| SdkError::Serialization(format!("Invalid tx_hash hex: {e}")))?;

        for (level, sibling_hex) in proof.merkle_path.iter().enumerate() {
            let sibling = hex::decode(sibling_hex)
                .map_err(|e| SdkError::Serialization(format!("Invalid merkle path hex: {e}")))?;

            let pair = if is_left_node(level, proof.tx_index) {
                [current.as_slice(), sibling.as_slice()].concat()
            } else {
                [sibling.as_slice(), current.as_slice()].concat()
            };

            // Double SHA-256 as per Bitcoin consensus
            let first = Sha256::digest(&pair);
            current = Sha256::digest(first).to_vec();
        }

        // The reconstructed root is in internal byte order; the merkle_root
        // from the block header is also in internal byte order. Compare directly.
        let root_hex = hex::encode(&current);

        // Also reverse the header merkle_root for comparison if it's in display order.
        // Block headers store merkle_root in internal order, so direct comparison is correct.
        Ok(root_hex == header.merkle_root)
    }

    async fn get_confirmations(&self, tx_hash: &str) -> Result<u32> {
        let tx = self.rpc.get_raw_transaction(tx_hash).await?;
        let current_height = self.get_height().await?;
        if let Some(block_height) = tx.get("blockheight").and_then(|v| v.as_u64()) {
            if current_height >= block_height {
                Ok((current_height - block_height + 1) as u32)
            } else {
                // Block not yet in our chain (reorg or stale data)
                Ok(0)
            }
        } else {
            Ok(0)
        }
    }

    async fn build_payment_proof(
        &self,
        tx_hash: &str,
        from_address: &str,
        to_address: &str,
        amount: u64,
    ) -> Result<PaymentProof> {
        let merkle = self.get_merkle_proof(tx_hash).await?;
        let header = self.get_header(merkle.block_height).await?;
        let confirmations = self.get_confirmations(tx_hash).await?;

        Ok(PaymentProof {
            chain: self.chain,
            tx_hash: tx_hash.to_string(),
            amount,
            from_address: from_address.to_string(),
            to_address: to_address.to_string(),
            confirmations,
            block_height: merkle.block_height,
            block_hash: merkle.block_hash.clone(),
            verified: false,
            merkle_root: header.merkle_root.clone(),
            merkle_proof: merkle.merkle_path,
            tx_index: merkle.tx_index,
            total_txs: merkle.total_txs,
        })
    }

    async fn verify_payment_proof(&self, proof: &PaymentProof, min_confirmations: u32) -> Result<bool> {
        if proof.confirmations < min_confirmations {
            return Ok(false);
        }

        let header = self.get_header(proof.block_height).await?;
        if header.merkle_root != proof.merkle_root {
            return Ok(false);
        }

        let merkle = MerkleProof {
            chain: self.chain,
            tx_hash: proof.tx_hash.clone(),
            block_height: proof.block_height,
            block_hash: proof.block_hash.clone(),
            merkle_path: proof.merkle_proof.clone(),
            tx_index: proof.tx_index,
            total_txs: proof.total_txs,
        };

        self.verify_merkle(&merkle, &header)
    }
}

// ── Helpers ────────────────────────────────────────────────────────

fn is_left_node(level: usize, tx_index: u32) -> bool {
    ((tx_index >> level) & 1) == 0
}
