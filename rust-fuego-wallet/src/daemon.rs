use reqwest::Client;
use serde::{Deserialize, Serialize};

#[derive(Clone)]
pub struct DaemonClient {
    pub base_url: String,
    client: Client,
}

#[derive(Debug, Deserialize)]
pub struct DaemonInfo {
    pub height: u64,
    pub difficulty: u64,
    pub tx_count: u64,
    pub tx_pool_size: u64,
    pub incoming_connections_count: u64,
    pub outgoing_connections_count: u64,
    pub last_block_timestamp: u64,
    pub last_block_reward: u64,
    pub top_block_hash: String,
    pub status: String,
    pub version: String,
}

#[derive(Debug, Serialize)]
struct JsonRpcRequest {
    jsonrpc: String,
    id: String,
    method: String,
    params: serde_json::Value,
}

#[derive(Debug, Deserialize)]
struct JsonRpcResponse<T> {
    result: Option<T>,
    error: Option<JsonRpcError>,
}

#[derive(Debug, Deserialize)]
struct JsonRpcError {
    message: String,
}

impl DaemonClient {
    pub fn new(base_url: &str) -> Self {
        Self {
            base_url: base_url.trim_end_matches('/').to_string(),
            client: Client::new(),
        }
    }

    pub async fn get_info(&self) -> Result<DaemonInfo, String> {
        let url = format!("{}/getinfo", self.base_url);
        let resp = self.client.get(&url).send().await
            .map_err(|e| format!("HTTP: {}", e))?;
        resp.json::<DaemonInfo>().await
            .map_err(|e| format!("JSON: {}", e))
    }

    pub async fn get_height(&self) -> Result<u64, String> {
        let resp = self.json_rpc::<serde_json::Value>("getblockcount", serde_json::json!({})).await?;
        resp.get("count").and_then(|v| v.as_u64())
            .ok_or("missing count".into())
    }

    pub async fn get_block_hash(&self, height: u64) -> Result<String, String> {
        self.json_rpc::<String>("on_getblockhash", serde_json::json!([height])).await
    }

    pub async fn send_raw_tx(&self, tx_hex: &str) -> Result<String, String> {
        let url = format!("{}/sendrawtransaction", self.base_url);
        let resp = self.client.post(&url)
            .json(&serde_json::json!({"tx_as_hex": tx_hex}))
            .send().await.map_err(|e| format!("HTTP: {}", e))?;
        let val: serde_json::Value = resp.json().await
            .map_err(|e| format!("JSON: {}", e))?;
        val["status"].as_str().map(|s| s.to_string())
            .ok_or("missing status".into())
    }

    async fn json_rpc<T: serde::de::DeserializeOwned>(
        &self, method: &str, params: serde_json::Value,
    ) -> Result<T, String> {
        let url = format!("{}/json_rpc", self.base_url);
        let req = JsonRpcRequest {
            jsonrpc: "2.0".into(),
            id: "1".into(),
            method: method.into(),
            params,
        };
        let resp: JsonRpcResponse<T> = self.client.post(&url)
            .json(&req).send().await
            .map_err(|e| format!("HTTP: {}", e))?
            .json().await
            .map_err(|e| format!("JSON: {}", e))?;
        if let Some(err) = resp.error {
            Err(format!("RPC: {}", err.message))
        } else {
            resp.result.ok_or("no result".into())
        }
    }
}
