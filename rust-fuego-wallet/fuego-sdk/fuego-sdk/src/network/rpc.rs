use crate::error::{Result, SdkError};
use crate::traits::{NetworkProvider, PeerInfo};
use crate::types::*;
use async_trait::async_trait;

pub struct RpcProvider {
    host: String,
    port: u16,
    client: reqwest::Client,
}

impl RpcProvider {
    pub fn new(host: impl Into<String>, port: u16) -> Self {
        Self {
            host: host.into(),
            port,
            client: reqwest::Client::new(),
        }
    }

    fn url(&self) -> String {
        format!("http://{}:{}/json_rpc", self.host, self.port)
    }

    async fn call(
        &self,
        method: &str,
        params: Option<serde_json::Value>,
    ) -> Result<serde_json::Value> {
        let body = serde_json::json!({
            "jsonrpc": "2.0",
            "id": "sdk",
            "method": method,
            "params": params,
        });

        let resp = self
            .client
            .post(self.url())
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(|e| SdkError::Network(format!("HTTP request failed: {}", e)))?;

        let json: serde_json::Value = resp
            .json()
            .await
            .map_err(|e| SdkError::Network(format!("Failed to parse response: {}", e)))?;

        if let Some(error) = json.get("error") {
            return Err(SdkError::Network(format!("RPC error: {}", error)));
        }

        Ok(json
            .get("result")
            .cloned()
            .unwrap_or(serde_json::Value::Null))
    }
}

#[async_trait]
impl NetworkProvider for RpcProvider {
    async fn get_height(&self) -> Result<u64> {
        let result = self.call("get_block_count", None).await?;
        let count = result
            .get("count")
            .or_else(|| result.get("block_count"))
            .and_then(|v| v.as_u64())
            .ok_or_else(|| SdkError::Network("Invalid block count response".into()))?;
        Ok(count)
    }

    async fn get_header(&self, height: u64) -> Result<BlockHeader> {
        let block = self.get_block(height).await?;
        Ok(block.header)
    }

    async fn get_block(&self, height: u64) -> Result<Block> {
        let params = serde_json::json!({ "height": height });
        let result = self.call("get_block", Some(params)).await?;

        let hash_str = result.get("hash").and_then(|v| v.as_str()).unwrap_or("");
        let hash_bytes = hex::decode(hash_str).unwrap_or_else(|_| vec![0u8; 32]);
        let mut hash = [0u8; 32];
        let copy_len = hash_bytes.len().min(32);
        hash[..copy_len].copy_from_slice(&hash_bytes[..copy_len]);

        let timestamp = result
            .get("timestamp")
            .and_then(|v| v.as_u64())
            .unwrap_or(0);
        let tx_count = result.get("tx_count").and_then(|v| v.as_u64()).unwrap_or(0) as u32;

        let prev_hash_str = result
            .get("prev_hash")
            .and_then(|v| v.as_str())
            .unwrap_or("");
        let prev_hash_bytes = hex::decode(prev_hash_str).unwrap_or_else(|_| vec![0u8; 32]);
        let mut prev_hash = [0u8; 32];
        let copy_len = prev_hash_bytes.len().min(32);
        prev_hash[..copy_len].copy_from_slice(&prev_hash_bytes[..copy_len]);

        let transactions = if let Some(txs) = result.get("transactions").and_then(|v| v.as_array())
        {
            txs.iter()
                .map(|tx| {
                    let tx_hash_str = tx.get("hash").and_then(|v| v.as_str()).unwrap_or("");
                    let tx_hash_bytes = hex::decode(tx_hash_str).unwrap_or_else(|_| vec![0u8; 32]);
                    let mut tx_hash = [0u8; 32];
                    let copy_len = tx_hash_bytes.len().min(32);
                    tx_hash[..copy_len].copy_from_slice(&tx_hash_bytes[..copy_len]);

                    let extra_str = tx.get("extra").and_then(|v| v.as_str()).unwrap_or("");
                    let extra = hex::decode(extra_str).unwrap_or_else(|_| vec![]);

                    let fee = tx.get("fee").and_then(|v| v.as_u64()).unwrap_or(0);

                    Transaction {
                        hash: tx_hash,
                        inputs: Vec::new(),
                        outputs: Vec::new(),
                        extra,
                        fee,
                    }
                })
                .collect()
        } else {
            Vec::new()
        };

        Ok(Block {
            header: BlockHeader {
                height,
                hash,
                prev_hash,
                timestamp,
                tx_count,
            },
            transactions,
        })
    }

    async fn send_transaction(&self, tx: &Transaction) -> Result<[u8; 32]> {
        let tx_hex = hex::encode(bincode::serialize(tx).unwrap_or_default());
        let params = serde_json::json!({ "tx_as_hex": tx_hex });
        let result = self.call("send_raw_transaction", Some(params)).await?;
        let hash_str = result.get("tx_hash").and_then(|v| v.as_str()).unwrap_or("");
        let hash_bytes = hex::decode(hash_str).unwrap_or_else(|_| vec![0u8; 32]);
        let mut hash = [0u8; 32];
        let copy_len = hash_bytes.len().min(32);
        hash[..copy_len].copy_from_slice(&hash_bytes[..copy_len]);
        Ok(hash)
    }

    async fn get_peers(&self) -> Result<Vec<PeerInfo>> {
        let result = self.call("get_peers", None).await?;
        let peers = result
            .as_array()
            .map(|arr| {
                arr.iter()
                    .map(|p| PeerInfo {
                        id: p
                            .get("id")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        address: p
                            .get("address")
                            .and_then(|v| v.as_str())
                            .unwrap_or("")
                            .to_string(),
                        version: p.get("version").and_then(|v| v.as_u64()).unwrap_or(0) as u32,
                        height: p.get("height").and_then(|v| v.as_u64()).unwrap_or(0),
                        last_seen: p.get("last_seen").and_then(|v| v.as_u64()).unwrap_or(0),
                    })
                    .collect()
            })
            .unwrap_or_default();
        Ok(peers)
    }

    async fn get_transaction(&self, hash: &[u8; 32]) -> Result<Option<Transaction>> {
        let hash_hex = hex::encode(hash);
        let params = serde_json::json!({ "tx_hash": hash_hex });
        let result = self.call("get_transaction", Some(params)).await?;
        if result.is_null() {
            return Ok(None);
        }
        let tx_hash_str = result.get("hash").and_then(|v| v.as_str()).unwrap_or("");
        let tx_hash_bytes = hex::decode(tx_hash_str).unwrap_or_else(|_| vec![0u8; 32]);
        let mut tx_hash = [0u8; 32];
        let copy_len = tx_hash_bytes.len().min(32);
        tx_hash[..copy_len].copy_from_slice(&tx_hash_bytes[..copy_len]);

        let extra_str = result.get("extra").and_then(|v| v.as_str()).unwrap_or("");
        let extra = hex::decode(extra_str).unwrap_or_else(|_| vec![]);
        let fee = result.get("fee").and_then(|v| v.as_u64()).unwrap_or(0);

        Ok(Some(Transaction {
            hash: tx_hash,
            inputs: Vec::new(),
            outputs: Vec::new(),
            extra,
            fee,
        }))
    }
}
