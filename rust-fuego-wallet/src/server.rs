use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

pub struct AppState {
    pub walletd_url: Option<String>,
    pub fuegod_url: String,
}

#[derive(Serialize)]
struct JsonRpcSuccess {
    jsonrpc: String,
    id: u64,
    result: serde_json::Value,
}

#[derive(Serialize)]
struct JsonRpcError {
    jsonrpc: String,
    id: u64,
    error: RpcErrorDetail,
}

#[derive(Serialize)]
struct RpcErrorDetail {
    code: i32,
    message: String,
}

fn remap_to_walletd(method: &str) -> String {
    match method {
        "getBalance" => "getbalance",
        "getAddresses" => "get_address",
        "getAddress" => "get_address",
        "getTransactions" => "get_transfers",
        "sendTransaction" => "transfer",
        "getStatus" => "get_height",
        "start_mining" => "start_mining",
        "stop_mining" => "stop_mining",
        "list_cds" => "list_cds",
        "cd::list" => "list_cds",
        "cd::create" => "create_cd",
        "cd::claim" => "withdraw_cd",
        "create_integrated" => "create_integrated",
        _ => method,
    }.to_string()
}

fn remap_params(method: &str, params: &serde_json::Value) -> serde_json::Value {
    match method {
        "sendTransaction" => {
            let destinations = params.get("destinations").cloned()
                .unwrap_or(serde_json::Value::Array(vec![]));
            let fee = params.get("fee").cloned()
                .unwrap_or(serde_json::json!(100000));
            let mixin = params.get("anonymity").cloned()
                .unwrap_or(serde_json::json!(10));
            let payment_id = params.get("paymentId").cloned();

            let mut out = serde_json::json!({
                "destinations": destinations,
                "fee": fee,
                "mixin": mixin,
                "unlock_time": 0,
            });
            if let Some(pid) = payment_id {
                if !pid.is_null() && !pid.as_str().unwrap_or("").is_empty() {
                    out["payment_id"] = pid;
                }
            }
            out
        }
        "cd::create" => {
            let amount = params.get("amount").cloned()
                .unwrap_or(serde_json::json!("0"));
            let term = params.get("duration_blocks").cloned()
                .unwrap_or(serde_json::json!(1440));
            serde_json::json!({"amount": amount, "term": term})
        }
        "cd::claim" => {
            let deposit_id = params.get("cd_id").cloned()
                .unwrap_or(serde_json::json!(""));
            serde_json::json!({"deposit_id": deposit_id})
        }
        _ => params.clone(),
    }
}

/// Methods that MUST go through walletd (wallet state operations)
fn needs_walletd(method: &str) -> bool {
    matches!(method,
        "getBalance" | "getAddresses" | "getAddress" | "getTransactions" |
        "sendTransaction" | "getStatus" |
        "create_integrated" |
        "list_cds" | "cd::list" | "cd::create" | "cd::claim"
    )
}

/// Everything else goes straight to fuegod
fn is_fuegod_method(method: &str) -> bool {
    // Network/blockchain queries
    matches!(method,
        "getinfo" | "getheight" | "getblockcount" | "on_getblockhash" | "getblock" |
        "getlastblockheader" | "getblockheaderbyhash" | "getblockheaderbyheight" |
        "peers" | "feeaddress" | "getethereal" | "paymentid" |
        "gettransactions" | "sendrawtransaction" |
        "getrandom_outs_json" | "get_outputs_heights" |
        "check_tx_proof" | "check_reserve_proof" |
        // Mining
        "start_mining" | "stop_mining" |
        // CD market operations (fuego RPC, not walletd)
        "getcdoffers" | "submitcd" | "cancelcd" | "estimate_cd_yield" |
        "cd::market_list" | "cd::sell" | "cd::buy" | "cd::cancel_listing" | "cd::apy" |
        // AMM / HEAT
        "heat_metrics" | "amm_quote" | "amm_pool_info" |
        "get_orderbook_state" | "get_orderbook_info" | "get_orderbook_estimates" |
        "get_fuego_price" | "getswapoffers" | "getswapprice" | "getswaptrades" |
        "submitswap" | "cancelswap" | "requestswap" |
        "getactiveswaps" | "initiate" | "accept" | "processswap" | "refundswap" |
        // Deposits / treasury
        "getdeposits" | "get_block_range" | "get_maturing_deposits" |
        "rollover_deposit" | "get_fee_pool_info" | "get_epoch_history" |
        "get_treasury_info" | "get_alias" | "get_alias_by_address" | "get_all_aliases"
    )
}

/// Sanitize error messages to prevent internal state leakage.
/// Removes URLs, file paths, and stack traces from error messages.
fn sanitize_error(msg: &str) -> String {
    // If message contains sensitive patterns, return generic error
    if msg.contains("127.0.0.1") || msg.contains("localhost") 
        || msg.contains("/Users/") || msg.contains("/home/")
        || msg.contains("http://") || msg.contains("https://") {
        return "internal error".to_string();
    }
    
    // Remove common internal prefixes
    let sanitized = msg
        .trim_start_matches("HTTP: ")
        .trim_start_matches("JSON: ")
        .trim_start_matches("RPC: ")
        .to_string();
    
    sanitized
}

async fn proxy_to_walletd(walletd_url: &str, body: &serde_json::Value) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::new();
    let url = format!("{}/json_rpc", walletd_url);
    let resp = client.post(&url).json(body).send().await
        .map_err(|e| sanitize_error(&format!("walletd request: {}", e)))?;
    let val: serde_json::Value = resp.json().await
        .map_err(|e| sanitize_error(&format!("walletd response: {}", e)))?;
    let result = val.get("result").cloned().unwrap_or(val);
    Ok(result)
}

async fn proxy_to_fuegod(fuegod_url: &str, body: &serde_json::Value) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::new();
    let method = body.get("method").and_then(|v| v.as_str()).unwrap_or("");
    let params = body.get("params").cloned().unwrap_or(serde_json::json!({}));

    let resp = match method {
        "getinfo" => {
            client.get(format!("{}/getinfo", fuegod_url)).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "getheight" => {
            client.post(format!("{}/getheight", fuegod_url))
                .json(&serde_json::json!({})).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "getblockcount" => {
            client.post(format!("{}/getblockcount", fuegod_url))
                .json(&serde_json::json!({})).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "on_getblockhash" => {
            client.post(format!("{}/on_getblockhash", fuegod_url))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "getblock" => {
            client.post(format!("{}/getblock", fuegod_url))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "getlastblockheader" => {
            client.post(format!("{}/getlastblockheader", fuegod_url))
                .json(&serde_json::json!({})).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "getblockheaderbyhash" => {
            client.post(format!("{}/getblockheaderbyhash", fuegod_url))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "getblockheaderbyheight" => {
            client.post(format!("{}/getblockheaderbyheight", fuegod_url))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "peers" => {
            client.post(format!("{}/peers", fuegod_url))
                .json(&serde_json::json!({})).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "feeaddress" => {
            client.post(format!("{}/feeaddress", fuegod_url))
                .json(&serde_json::json!({})).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "getethereal" => {
            client.post(format!("{}/getethereal", fuegod_url))
                .json(&serde_json::json!({})).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "paymentid" => {
            client.post(format!("{}/paymentid", fuegod_url))
                .json(&serde_json::json!({})).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "gettransactions" => {
            client.post(format!("{}/gettransactions", fuegod_url))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "sendrawtransaction" => {
            client.post(format!("{}/sendrawtransaction", fuegod_url))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "getrandom_outs_json" => {
            client.post(format!("{}/getrandom_outs_json", fuegod_url))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "get_outputs_heights" => {
            client.post(format!("{}/get_outputs_heights", fuegod_url))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "check_tx_proof" => {
            client.post(format!("{}/check_tx_proof", fuegod_url))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "check_reserve_proof" => {
            client.post(format!("{}/check_reserve_proof", fuegod_url))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "start_mining" => {
            client.post(format!("{}/start_mining", fuegod_url))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "stop_mining" => {
            client.post(format!("{}/stop_mining", fuegod_url))
                .json(&serde_json::json!({})).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        "getcdoffers" | "submitcd" | "cancelcd" | "estimate_cd_yield" |
        "cd::market_list" | "cd::sell" | "cd::buy" | "cd::cancel_listing" | "cd::apy" |
        "getswapoffers" | "getswapprice" | "getswaptrades" |
        "submitswap" | "cancelswap" | "requestswap" |
        "getactiveswaps" | "initiate" | "accept" | "processswap" | "refundswap" |
        "getdeposits" | "get_block_range" | "get_maturing_deposits" |
        "rollover_deposit" | "get_fee_pool_info" | "get_epoch_history" |
        "get_treasury_info" | "get_alias" | "get_alias_by_address" | "get_all_aliases" |
        "heat_metrics" | "amm_quote" | "amm_pool_info" |
        "get_orderbook_state" | "get_orderbook_info" | "get_orderbook_estimates" |
        "get_fuego_price" => {
            client.post(format!("{}/{}", fuegod_url, method))
                .json(&params).send().await
                .map_err(|e| sanitize_error(&format!("fuego daemon: {}", e)))?
        }
        _ => {
            return Err(format!("unknown fuegod method: {}", method));
        }
    };

    let text = resp.text().await
        .map_err(|e| sanitize_error(&format!("fuego daemon response: {}", e)))?;
    let val: serde_json::Value = serde_json::from_str(&text)
        .unwrap_or_else(|_| serde_json::json!({"status": text.trim()}));
    Ok(val)
}

async fn json_rpc_handler(
    State(state): State<Arc<AppState>>,
    Json(body): Json<serde_json::Value>,
) -> impl IntoResponse {
    let id = body.get("id").and_then(|v| v.as_u64()).unwrap_or(0);
    let method = body.get("method").and_then(|v| v.as_str()).unwrap_or("");
    let params = body.get("params").cloned().unwrap_or(serde_json::Value::Null);

    let result: Result<serde_json::Value, String> = if needs_walletd(method) {
        match &state.walletd_url {
            Some(url) => {
                let walletd_method = remap_to_walletd(method);
                let remapped_params = remap_params(method, &params);
                let mut forwarded = body.clone();
                forwarded["method"] = serde_json::json!(walletd_method);
                forwarded["params"] = remapped_params;
                proxy_to_walletd(url, &forwarded).await
            }
            None => Err("walletd not running".into()),
        }
    } else if is_fuegod_method(method) {
        proxy_to_fuegod(&state.fuegod_url, &body).await
    } else {
        Err(format!("unknown method: {}", method))
    };

    match result {
        Ok(val) => {
            let success = JsonRpcSuccess { jsonrpc: "2.0".into(), id, result: val };
            (StatusCode::OK, Json(serde_json::to_value(success).unwrap())).into_response()
        }
        Err(msg) => {
            let error = JsonRpcError {
                jsonrpc: "2.0".into(), id,
                error: RpcErrorDetail { code: -32000, message: msg },
            };
            (StatusCode::OK, Json(serde_json::to_value(error).unwrap())).into_response()
        }
    }
}

async fn health_check(State(state): State<Arc<AppState>>) -> impl IntoResponse {
    let client = reqwest::Client::new();

    // Check fuegod via direct HTTP endpoint
    let fuegod_ok = client.get(format!("{}/getinfo", state.fuegod_url))
        .send().await
        .map(|r| r.status().is_success())
        .unwrap_or(false);

    // Check walletd (optional - may not be running yet)
    let walletd_ok = match &state.walletd_url {
        Some(url) => client.post(format!("{}/json_rpc", url))
            .json(&serde_json::json!({"jsonrpc":"2.0","id":1,"method":"getBalance","params":{}}))
            .send().await
            .map(|r| r.status().is_success())
            .unwrap_or(false),
        None => false,
    };

    Json(serde_json::json!({
        "status": if fuegod_ok { "ok" } else { "degraded" },
        "fuego": fuegod_ok,
        "walletd": walletd_ok,
    }))
}

// ── Output scanning ──

#[derive(Deserialize)]
struct ScanBalanceRequest {
    view_secret: String,
    spend_public: String,
    #[serde(default)]
    start_height: u64,
    #[serde(default = "default_batch_size")]
    batch_size: u64,
}

fn default_batch_size() -> u64 { 100 }

/// Fetch a block hash from fuegod by height.
async fn fetch_block_hash(fuegod_url: &str, height: u64) -> Result<String, String> {
    let client = reqwest::Client::new();
    let resp = client.post(format!("{}/on_getblockhash", fuegod_url))
        .json(&serde_json::json!([height]))
        .send().await.map_err(|e| format!("hash request: {}", e))?;
    let val: serde_json::Value = resp.json().await.map_err(|e| format!("hash response: {}", e))?;
    val.as_str().map(|s| s.to_string())
        .or_else(|| val.get("result").and_then(|r| r.as_str()).map(|s| s.to_string()))
        .ok_or_else(|| format!("no hash for height {}", height))
}

/// Fetch a block from fuegod by hash.
async fn fetch_block(fuegod_url: &str, hash: &str) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::new();
    let resp = client.post(format!("{}/getblock", fuegod_url))
        .json(&serde_json::json!({"hash": hash}))
        .send().await.map_err(|e| format!("block request: {}", e))?;
    let val: serde_json::Value = resp.json().await.map_err(|e| format!("block response: {}", e))?;
    Ok(val)
}

/// Fetch full transactions by hash from fuegod.
async fn fetch_transactions(fuegod_url: &str, tx_hashes: &[String]) -> Result<Vec<serde_json::Value>, String> {
    if tx_hashes.is_empty() { return Ok(vec![]); }
    let client = reqwest::Client::new();
    let resp = client.post(format!("{}/gettransactions", fuegod_url))
        .json(&serde_json::json!({"txs_hashes": tx_hashes}))
        .send().await.map_err(|e| format!("tx request: {}", e))?;
    let val: serde_json::Value = resp.json().await.map_err(|e| format!("tx response: {}", e))?;
    Ok(val.get("txs").and_then(|t| t.as_array()).cloned().unwrap_or_default())
}

/// Get current blockchain height from fuegod.
async fn fetch_height(fuegod_url: &str) -> Result<u64, String> {
    let client = reqwest::Client::new();
    let resp = client.post(format!("{}/getheight", fuegod_url))
        .json(&serde_json::json!({}))
        .send().await.map_err(|e| format!("height request: {}", e))?;
    let val: serde_json::Value = resp.json().await.map_err(|e| format!("height response: {}", e))?;
    val.get("height").and_then(|h| h.as_u64())
        .or_else(|| val.as_u64())
        .ok_or_else(|| "no height".into())
}

async fn scan_balance_handler(
    State(state): State<Arc<AppState>>,
    Json(req): Json<ScanBalanceRequest>,
) -> impl IntoResponse {
    // Parse keys
    let view_secret_bytes = match hex::decode(&req.view_secret) {
        Ok(b) if b.len() == 32 => {
            let mut k = [0u8; 32]; k.copy_from_slice(&b); k
        }
        _ => return (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "invalid view_secret"}))).into_response(),
    };
    let spend_public_bytes = match hex::decode(&req.spend_public) {
        Ok(b) if b.len() == 32 => {
            let mut k = [0u8; 32]; k.copy_from_slice(&b); k
        }
        _ => return (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "invalid spend_public"}))).into_response(),
    };

    // Get current height
    let current_height = match fetch_height(&state.fuegod_url).await {
        Ok(h) => h,
        Err(e) => return (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e}))).into_response(),
    };

    let end_height = std::cmp::min(req.start_height + req.batch_size, current_height);
    let mut all_outputs = Vec::new();
    let mut total_balance: u64 = 0;
    let mut tx_count: u64 = 0;

    // Scan blocks in batch
    for height in req.start_height..=end_height {
        let hash = match fetch_block_hash(&state.fuegod_url, height).await {
            Ok(h) => h,
            Err(_) => continue,
        };
        let block = match fetch_block(&state.fuegod_url, &hash).await {
            Ok(b) => b,
            Err(_) => continue,
        };

        // Extract tx hashes from block
        let tx_hashes: Vec<String> = block.get("tx_hashes")
            .and_then(|t| t.as_array())
            .map(|arr| arr.iter().filter_map(|v| v.as_str().map(|s| s.to_string())).collect())
            .unwrap_or_default();

        // Fetch full transactions
        let txs = match fetch_transactions(&state.fuegod_url, &tx_hashes).await {
            Ok(t) => t,
            Err(_) => continue,
        };
        tx_count += txs.len() as u64;

        // Scan transactions
        let outputs = crate::scanner::scan_transactions(
            &view_secret_bytes, &spend_public_bytes, &txs, height,
        );
        for o in &outputs {
            total_balance += o.amount;
        }
        all_outputs.extend(outputs);
    }

    Json(serde_json::json!({
        "balance": total_balance,
        "outputs": all_outputs,
        "scanned_height": end_height,
        "current_height": current_height,
        "scanned_tx_count": tx_count,
        "batch_start": req.start_height,
        "batch_end": end_height,
    })).into_response()
}

pub async fn run_server(
    walletd_url: Option<String>,
    fuegod_url: &str,
    bind_addr: &str,
) -> Result<(), String> {
    let state = Arc::new(AppState {
        walletd_url,
        fuegod_url: fuegod_url.to_string(),
    });

    let cors = tower_http::cors::CorsLayer::new()
        .allow_origin([
            "http://localhost:8070".parse().unwrap(),
            "http://127.0.0.1:8070".parse().unwrap(),
            "http://localhost:8080".parse().unwrap(),
        ])
        .allow_methods(tower_http::cors::Any)
        .allow_headers(tower_http::cors::Any);

    let app = Router::new()
        .route("/json_rpc", post(json_rpc_handler))
        .route("/health", get(health_check))
        .route("/scan_balance", post(scan_balance_handler))
        .layer(cors)
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(bind_addr).await
        .map_err(|e| format!("bind {}: {}", bind_addr, e))?;

    log::info!("fuego-wallet listening on {}", bind_addr);

    axum::serve(listener, app).await
        .map_err(|e| format!("server: {}", e))?;

    Ok(())
}
