use crate::error::{Result, SdkError};
use crate::chain::evm::{EvmReceipt, EvmBlock, EvmTx};
use reqwest::Client;

/// JSON-RPC client for EVM-compatible chains (ETH, ARB, BASE).
pub struct EvmRpcClient {
    url: String,
    client: Client,
}

impl EvmRpcClient {
    pub fn new(url: impl Into<String>) -> Self {
        Self {
            url: url.into(),
            client: Client::builder()
                .timeout(std::time::Duration::from_secs(30))
                .build()
                .unwrap_or_else(|_| Client::new()),
        }
    }

    pub async fn get_block_number(&self) -> Result<u64> {
        let hex: String = self.eth_call("eth_blockNumber", &[]).await?;
        parse_hex_u64(&hex).ok_or_else(|| SdkError::Network(format!("Invalid block number: {hex}")))
    }

    pub async fn get_block_by_number(&self, number: u64) -> Result<EvmBlock> {
        let block: serde_json::Value = self.eth_call("eth_getBlockByNumber", &[
            serde_json::json!(format!("0x{:x}", number)),
            serde_json::json!(false),
        ]).await?;

        Ok(EvmBlock {
            hash: block["hash"].as_str().unwrap_or("0x0").to_string(),
            parent_hash: block["parentHash"].as_str().unwrap_or("0x0").to_string(),
            number: parse_hex_u64(block["number"].as_str().unwrap_or("0x0")).unwrap_or(0),
            timestamp: parse_hex_u64(block["timestamp"].as_str().unwrap_or("0x0")).unwrap_or(0),
            logs_bloom: block["logsBloom"].as_str().unwrap_or("0x0").to_string(),
            receipts_root: block["receiptsRoot"].as_str().unwrap_or("0x0").to_string(),
        })
    }

    pub async fn get_block_by_hash(&self, hash: &str) -> Result<EvmBlock> {
        let block: serde_json::Value = self.eth_call("eth_getBlockByHash", &[
            serde_json::json!(hash),
            serde_json::json!(false),
        ]).await?;

        Ok(EvmBlock {
            hash: block["hash"].as_str().unwrap_or("0x0").to_string(),
            parent_hash: block["parentHash"].as_str().unwrap_or("0x0").to_string(),
            number: parse_hex_u64(block["number"].as_str().unwrap_or("0x0")).unwrap_or(0),
            timestamp: parse_hex_u64(block["timestamp"].as_str().unwrap_or("0x0")).unwrap_or(0),
            logs_bloom: block["logsBloom"].as_str().unwrap_or("0x0").to_string(),
            receipts_root: block["receiptsRoot"].as_str().unwrap_or("0x0").to_string(),
        })
    }

    pub async fn get_transaction_receipt(&self, tx_hash: &str) -> Result<EvmReceipt> {
        let receipt: serde_json::Value = self.eth_call("eth_getTransactionReceipt", &[
            serde_json::json!(tx_hash),
        ]).await?;

        if receipt.is_null() {
            return Err(SdkError::Network(format!("Transaction {tx_hash} not found")));
        }

        let status = receipt["status"].as_str().unwrap_or("0x1").to_string();
        if status != "0x1" && status != "0x0" {
            return Err(SdkError::Network(format!(
                "Unexpected receipt status for {tx_hash}: {status}"
            )));
        }

        let tx_index = parse_hex_u64(receipt["transactionIndex"].as_str().unwrap_or("0x0"))
            .ok_or_else(|| SdkError::Network(format!("Invalid transactionIndex for {tx_hash}")))?;

        Ok(EvmReceipt {
            block_hash: receipt["blockHash"].as_str().unwrap_or("0x0").to_string(),
            block_number: parse_hex_u64(receipt["blockNumber"].as_str().unwrap_or("0x0")).unwrap_or(0),
            transaction_index: tx_index,
            status,
            logs_bloom: receipt["logsBloom"].as_str().unwrap_or("0x0").to_string(),
        })
    }

    pub async fn get_transaction_by_hash(&self, tx_hash: &str) -> Result<EvmTx> {
        let tx: serde_json::Value = self.eth_call("eth_getTransactionByHash", &[
            serde_json::json!(tx_hash),
        ]).await?;

        if tx.is_null() {
            return Err(SdkError::Network(format!("Transaction {tx_hash} not found")));
        }

        Ok(EvmTx {
            hash: tx["hash"].as_str().unwrap_or("0x0").to_string(),
            from: tx["from"].as_str().unwrap_or("0x0").to_string(),
            to: tx["to"].as_str().unwrap_or("0x0").to_string(),
            value: tx["value"].as_str().unwrap_or("0x0").to_string(),
            block_number: tx["blockNumber"].as_str().and_then(parse_hex_u64),
        })
    }

    /// Get balance in wei. Returns u128 to handle large balances (ETH is 256-bit).
    pub async fn get_balance(&self, address: &str) -> Result<u128> {
        let hex: String = self.eth_call("eth_getBalance", &[
            serde_json::json!(address),
            serde_json::json!("latest"),
        ]).await?;
        parse_hex_u128(&hex).ok_or_else(|| SdkError::Network(format!("Invalid balance: {hex}")))
    }

    pub async fn get_chain_id(&self) -> Result<u64> {
        let hex: String = self.eth_call("eth_chainId", &[]).await?;
        parse_hex_u64(&hex).ok_or_else(|| SdkError::Network(format!("Invalid chain ID: {hex}")))
    }

    async fn eth_call<T: serde::de::DeserializeOwned>(&self, method: &str, params: &[serde_json::Value]) -> Result<T> {
        let body = serde_json::json!({
            "jsonrpc": "2.0",
            "id": "fuego-sdk",
            "method": method,
            "params": params,
        });

        let resp = self.client
            .post(&self.url)
            .json(&body)
            .send()
            .await
            .map_err(|e| SdkError::Network(format!("EVM RPC call {method} failed: {e}")))?;

        let status = resp.status();
        let text = resp.text().await
            .map_err(|e| SdkError::Network(format!("Failed to read EVM response: {e}")))?;

        if !status.is_success() {
            return Err(SdkError::Network(format!("EVM {method} returned {status}")));
        }

        let json: serde_json::Value = serde_json::from_str(&text)
            .map_err(|e| SdkError::Serialization(format!("Invalid EVM response: {e}")))?;

        if let Some(err) = json.get("error").filter(|e| !e.is_null()) {
            return Err(SdkError::Network(format!("EVM error in {method}: {err}")));
        }

        serde_json::from_value(json["result"].clone())
            .map_err(|e| SdkError::Serialization(format!("Failed to decode EVM result of {method}: {e}")))
    }
}

fn parse_hex_u64(hex_str: &str) -> Option<u64> {
    let clean = hex_str.trim_start_matches("0x");
    u64::from_str_radix(clean, 16).ok()
}

fn parse_hex_u128(hex_str: &str) -> Option<u128> {
    let clean = hex_str.trim_start_matches("0x");
    u128::from_str_radix(clean, 16).ok()
}
