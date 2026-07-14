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

    fn json_rpc_url(&self) -> String {
        format!("http://{}:{}/json_rpc", self.host, self.port)
    }

    fn rest_url(&self, path: &str) -> String {
        format!("http://{}:{}/{}", self.host, self.port, path)
    }

    async fn call(
        &self,
        method: &str,
        params: serde_json::Value,
    ) -> Result<serde_json::Value> {
        let body = serde_json::json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params,
        });

        let resp = self
            .client
            .post(self.json_rpc_url())
            .header("Content-Type", "application/json")
            .json(&body)
            .send()
            .await
            .map_err(|e| SdkError::Network(format!("HTTP: {}", e)))?;

        let json: serde_json::Value = resp
            .json()
            .await
            .map_err(|e| SdkError::Network(format!("JSON parse: {}", e)))?;

        if let Some(error) = json.get("error") {
            return Err(SdkError::Network(format!("RPC error: {}", error)));
        }

        Ok(json
            .get("result")
            .cloned()
            .unwrap_or(serde_json::Value::Null))
    }

    fn parse_hash(hex_str: &str) -> [u8; 32] {
        let bytes = hex::decode(hex_str).unwrap_or_else(|_| vec![0u8; 32]);
        let mut hash = [0u8; 32];
        let len = bytes.len().min(32);
        hash[..len].copy_from_slice(&bytes[..len]);
        hash
    }
}

#[async_trait]
impl NetworkProvider for RpcProvider {
    async fn get_height(&self) -> Result<u64> {
        let result = self.call("getblockcount", serde_json::json!({})).await?;
        let count = result
            .get("count")
            .and_then(|v| v.as_u64())
            .ok_or_else(|| SdkError::Network("missing count".into()))?;
        Ok(count)
    }

    async fn get_header(&self, height: u64) -> Result<BlockHeader> {
        let block = self.get_block(height).await?;
        Ok(block.header)
    }

    async fn get_block(&self, height: u64) -> Result<Block> {
        let params = serde_json::json!({ "height": height });
        let result = self.call("getblockheaderbyheight", params).await?;

        let header = result
            .get("block_header")
            .ok_or_else(|| SdkError::Network("missing block_header".into()))?;

        let hash_str = header.get("hash").and_then(|v| v.as_str()).unwrap_or("");
        let hash = Self::parse_hash(hash_str);

        let prev_hash_str = header.get("prev_hash").and_then(|v| v.as_str()).unwrap_or("");
        let prev_hash = Self::parse_hash(prev_hash_str);

        let timestamp = header.get("timestamp").and_then(|v| v.as_u64()).unwrap_or(0);

        Ok(Block {
            header: BlockHeader {
                height,
                hash,
                prev_hash,
                timestamp,
                tx_count: 0,
            },
            transactions: Vec::new(),
        })
    }

    async fn send_transaction(&self, tx: &Transaction) -> Result<[u8; 32]> {
        let tx_hex = hex::encode(bincode::serialize(tx).unwrap_or_default());
        let body = serde_json::json!({ "tx_as_hex": tx_hex });

        let resp = self
            .client
            .post(self.rest_url("sendrawtransaction"))
            .json(&body)
            .send()
            .await
            .map_err(|e| SdkError::Network(format!("HTTP: {}", e)))?;

        let json: serde_json::Value = resp
            .json()
            .await
            .map_err(|e| SdkError::Network(format!("JSON parse: {}", e)))?;

        let status = json
            .get("status")
            .and_then(|v| v.as_str())
            .unwrap_or("");

        if status != "OK" && status != "Success" {
            return Err(SdkError::Network(format!(
                "sendrawtransaction: {}",
                status
            )));
        }

        Ok(tx.hash)
    }

    async fn get_peers(&self) -> Result<Vec<PeerInfo>> {
        let resp = self
            .client
            .get(self.rest_url("getinfo"))
            .send()
            .await
            .map_err(|e| SdkError::Network(format!("HTTP: {}", e)))?;

        let json: serde_json::Value = resp
            .json()
            .await
            .map_err(|e| SdkError::Network(format!("JSON parse: {}", e)))?;

        let connections = json
            .get("connections")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .enumerate()
                    .map(|(i, addr)| PeerInfo {
                        id: format!("peer_{}", i),
                        address: addr.as_str().unwrap_or("").to_string(),
                        version: 0,
                        height: json.get("height").and_then(|v| v.as_u64()).unwrap_or(0),
                        last_seen: 0,
                    })
                    .collect::<Vec<PeerInfo>>()
            })
            .unwrap_or_default();

        Ok(connections)
    }

    async fn get_transaction(&self, _hash: &[u8; 32]) -> Result<Option<Transaction>> {
        Ok(None)
    }
}
