use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::Serialize;
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
        "start_mining" | "stop_mining" |
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
    let url = format!("{}/json_rpc", fuegod_url);
    let resp = client.post(&url).json(body).send().await
        .map_err(|e| sanitize_error(&format!("fuego daemon request: {}", e)))?;
    let val: serde_json::Value = resp.json().await
        .map_err(|e| sanitize_error(&format!("fuego daemon response: {}", e)))?;
    let result = val.get("result").cloned().unwrap_or(val);
    Ok(result)
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

    // Check fuegod (always available - embedded or remote)
    let fuegod_ok = client.post(format!("{}/json_rpc", state.fuegod_url))
        .json(&serde_json::json!({"jsonrpc":"2.0","id":1,"method":"getinfo","params":{}}))
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
        .layer(cors)
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(bind_addr).await
        .map_err(|e| format!("bind {}: {}", bind_addr, e))?;

    log::info!("fuego-wallet listening on {}", bind_addr);

    axum::serve(listener, app).await
        .map_err(|e| format!("server: {}", e))?;

    Ok(())
}
