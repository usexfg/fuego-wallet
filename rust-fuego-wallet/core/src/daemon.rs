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
    #[serde(default)]
    pub fee_address: String,
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
        let client = Client::builder()
            .timeout(std::time::Duration::from_secs(60))
            .build()
            .expect("build reqwest client");
        Self {
            base_url: base_url.trim_end_matches('/').to_string(),
            client,
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

    pub async fn get_genesis_hash(&self) -> Result<[u8; 32], String> {
        let resp = self
            .json_rpc::<serde_json::Value>("getcurrencyid", serde_json::json!({}))
            .await?;
        let hex_value = resp
            .get("currency_id_blob")
            .and_then(|v| v.as_str())
            .ok_or("missing currency_id_blob")?;
        let bytes = hex::decode(hex_value).map_err(|e| format!("invalid genesis hash: {e}"))?;
        bytes
            .try_into()
            .map_err(|_| "genesis hash must be 32 bytes".to_string())
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

    /// Binary POST helper for the .bin endpoints.
    async fn post_bin(&self, path: &str, body: Vec<u8>) -> Result<Vec<u8>, String> {
        let url = format!("{}{}", self.base_url, path);
        let resp = self.client.post(&url)
            .header("Content-Type", "application/octet-stream")
            .body(body)
            .send().await
            .map_err(|e| format!("HTTP: {}", e))?;
        if !resp.status().is_success() {
            return Err(format!("HTTP {} from {}", resp.status(), path));
        }
        resp.bytes().await.map(|b| b.to_vec()).map_err(|e| format!("body: {}", e))
    }

    /// /queryblockslite.bin — incremental block + tx-prefix sync.
    pub async fn query_blocks_lite(
        &self,
        block_ids: &[[u8; 32]],
        timestamp: u64,
    ) -> Result<fuego_sdk::serialization::QueryBlocksLiteResponse, String> {
        use fuego_sdk::serialization::{parse_query_blocks_lite_response, query_blocks_lite_request};
        let body = query_blocks_lite_request(block_ids, timestamp);
        let resp = self.post_bin("/queryblockslite.bin", body).await?;
        parse_query_blocks_lite_response(&resp).map_err(|e| e.to_string())
    }

    /// /getrandom_outs.bin — decoy outputs for the given amounts.
    pub async fn get_random_outs(
        &self,
        amounts: &[u64],
        outs_count: u64,
    ) -> Result<Vec<fuego_sdk::serialization::RandomOutsForAmount>, String> {
        use fuego_sdk::serialization::{get_random_outs_request, parse_get_random_outs_response};
        let body = get_random_outs_request(amounts, outs_count);
        let resp = self.post_bin("/getrandom_outs.bin", body).await?;
        parse_get_random_outs_response(&resp).map_err(|e| e.to_string())
    }

    /// /get_o_indexes.bin — global output indices of a transaction, aligned
    /// with its outputs. Request: 32-byte txid. Response: varint count +
    /// varint uint64 indices + status string.
    pub async fn get_o_indexes(&self, tx_hash: &[u8; 32]) -> Result<Vec<u64>, String> {
        let resp = self.post_bin("/get_o_indexes.bin", tx_hash.to_vec()).await?;
        let mut pos = 0usize;
        let read_varint = |data: &[u8], pos: &mut usize| -> Result<u64, String> {
            let mut result: u64 = 0;
            let mut shift = 0u32;
            loop {
                if *pos >= data.len() {
                    return Err("o_indexes: truncated".into());
                }
                let byte = data[*pos];
                *pos += 1;
                result |= ((byte & 0x7F) as u64) << shift;
                if byte & 0x80 == 0 {
                    return Ok(result);
                }
                shift += 7;
                if shift >= 64 {
                    return Err("o_indexes: varint overflow".into());
                }
            }
        };
        let count = read_varint(&resp, &mut pos)?;
        let mut indices = Vec::with_capacity(count as usize);
        for _ in 0..count {
            indices.push(read_varint(&resp, &mut pos)?);
        }
        Ok(indices)
    }

    /// /getrandom_commitment_outs.bin — decoy commitment outputs for a
    /// single amount.
    pub async fn get_random_commitment_outs(
        &self,
        amount: u64,
        outs_count: u64,
        max_height: u32,
    ) -> Result<Vec<fuego_sdk::serialization::RandomCommitmentOutEntry>, String> {
        use fuego_sdk::serialization::{
            get_random_commitment_outs_request, parse_get_random_commitment_outs_response,
        };
        let body = get_random_commitment_outs_request(amount, outs_count, max_height);
        let resp = self.post_bin("/getrandom_commitment_outs.bin", body).await?;
        parse_get_random_commitment_outs_response(&resp).map_err(|e| e.to_string())
    }

    /// /amm_pool_info — Hearth pool reserves and spot price.
    pub async fn amm_pool_info(&self) -> Result<(u64, u64, u64), String> {
        let val = self
            .json_rpc::<serde_json::Value>("amm_pool_info", serde_json::json!({}))
            .await?;
        let reserve_xfg = val.get("reserve_xfg").and_then(|v| v.as_u64()).unwrap_or(0);
        let reserve_heat = val.get("reserve_heat").and_then(|v| v.as_u64()).unwrap_or(0);
        let spot_price = val.get("spot_price").and_then(|v| v.as_u64()).unwrap_or(0);
        Ok((reserve_xfg, reserve_heat, spot_price))
    }

    /// /is_key_image_spent (JSON-RPC). Returns an error if the daemon does
    /// not provide the endpoint (older builds); callers fall back to
    /// scan-based spent tracking.
    pub async fn is_key_image_spent(&self, key_image: &[u8; 32]) -> Result<bool, String> {
        let val = self
            .json_rpc::<serde_json::Value>(
                "is_key_image_spent",
                serde_json::json!({ "key_image": hex::encode(key_image) }),
            )
            .await?;
        val.get("spent")
            .and_then(|v| v.as_bool())
            .ok_or_else(|| format!("bad is_key_image_spent response: {}", val))
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
