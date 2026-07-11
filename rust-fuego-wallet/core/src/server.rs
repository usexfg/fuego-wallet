use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

use crate::wallet_service::WalletService;

pub struct AppState {
    pub wallet: Arc<WalletService>,
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

fn is_fuegod_method(method: &str) -> bool {
    matches!(method,
        "getinfo" | "getheight" | "getblockcount" | "on_getblockhash" | "getblock" |
        "getlastblockheader" | "getblockheaderbyhash" | "getblockheaderbyheight" |
        "peers" | "feeaddress" | "getethereal" | "paymentid" |
        "gettransactions" | "sendrawtransaction" |
        "getrandom_outs_json" | "get_outputs_heights" |
        "check_tx_proof" | "check_reserve_proof" |
        "start_mining" | "stop_mining" |
        "getcdoffers" | "submitcd" | "cancelcd" | "estimate_cd_yield" |
        "cd::market_list" | "cd::sell" | "cd::buy" | "cd::cancel_listing" | "cd::apy" |
        "heat_metrics" | "amm_quote" | "amm_pool_info" |
        "get_orderbook_state" | "get_orderbook_info" | "get_orderbook_estimates" |
        "get_fuego_price" | "getswapoffers" | "getswapprice" | "getswaptrades" |
        "submitswap" | "cancelswap" | "requestswap" |
        "getactiveswaps" | "initiate" | "accept" | "processswap" | "refundswap" |
        "getdeposits" | "get_block_range" | "get_maturing_deposits" |
        "rollover_deposit" | "get_fee_pool_info" | "get_epoch_history" |
        "get_treasury_info" | "get_alias" | "get_alias_by_address" | "get_all_aliases"
    )
}

fn is_wallet_method(method: &str) -> bool {
    matches!(method,
        "getBalance" | "getAddresses" | "getAddress" | "getTransactions" |
        "sendTransaction" | "getStatus" |
        "create_integrated" | "list_cds" | "cd::list" | "cd::create" | "cd::claim"
    )
}

fn sanitize_error(msg: &str) -> String {
    if msg.contains("127.0.0.1") || msg.contains("localhost")
        || msg.contains("/Users/") || msg.contains("/home/")
        || msg.contains("http://") || msg.contains("https://") {
        return "internal error".to_string();
    }
    let sanitized = msg
        .trim_start_matches("HTTP: ")
        .trim_start_matches("JSON: ")
        .trim_start_matches("RPC: ")
        .to_string();
    sanitized
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

async fn handle_wallet_method(
    wallet: &WalletService,
    method: &str,
    params: &serde_json::Value,
) -> Result<serde_json::Value, String> {
    match method {
        "getBalance" | "getbalance" => {
            let balance = wallet.balance_full();
            Ok(serde_json::json!({
                "availableBalance": balance.confirmed,
                "lockedAmount": balance.pending + balance.immature,
                "blockCount": wallet.height(),
            }))
        }
        "getAddress" | "getAddresses" | "get_address" => {
            Ok(serde_json::json!({
                "address": wallet.address(),
            }))
        }
        "getStatus" | "get_height" => {
            let status = wallet.sync_status();
            Ok(serde_json::json!({
                "height": status.current_height,
                "is_syncing": status.is_syncing,
            }))
        }
        "getTransactions" | "get_transfers" => {
            let txs = wallet.get_transactions(100);
            let items: Vec<serde_json::Value> = txs.iter().map(|tx| {
                serde_json::json!({
                    "transactionHash": hex::encode(tx.hash),
                    "fee": tx.fee,
                    "blockIndex": 0,
                    "amount": tx.outputs.iter().map(|o| o.amount as i64).sum::<i64>(),
                    "transfers": [],
                })
            }).collect();
            Ok(serde_json::json!({ "items": items, "transactions": txs.len() }))
        }
        "sendTransaction" | "transfer" => {
            let destinations = params.get("destinations")
                .and_then(|d| d.as_array())
                .ok_or("missing destinations")?;
            let dest = destinations.first()
                .ok_or("empty destinations")?;
            let address = dest.get("address")
                .and_then(|a| a.as_str())
                .ok_or("missing address")?;
            let amount = dest.get("amount")
                .and_then(|a| a.as_u64())
                .ok_or("missing amount")?;
            let fee = params.get("fee")
                .and_then(|f| f.as_u64())
                .unwrap_or(100_000);

            let tx_hash = wallet.send_to_address(address, amount, fee).await
                .map_err(|e| format!("send failed: {}", e))?;
            Ok(serde_json::json!({
                "transactionHash": hex::encode(tx_hash),
                "txHash": hex::encode(tx_hash),
            }))
        }
        "create_integrated" => {
            let addr = wallet.address();
            Ok(serde_json::json!({
                "integratedAddress": addr,
            }))
        }
        "list_cds" | "cd::list" => {
            Ok(serde_json::json!({
                "cds": [],
                "active": [],
                "matured": [],
            }))
        }
        "cd::create" => {
            Err("CDs require walletd RPC — not yet migrated to SDK".into())
        }
        "cd::claim" => {
            Err("CDs require walletd RPC — not yet migrated to SDK".into())
        }
        _ => Err(format!("unknown wallet method: {}", method)),
    }
}

async fn json_rpc_handler(
    State(state): State<Arc<AppState>>,
    Json(body): Json<serde_json::Value>,
) -> impl IntoResponse {
    let id = body.get("id").and_then(|v| v.as_u64()).unwrap_or(0);
    let method = body.get("method").and_then(|v| v.as_str()).unwrap_or("");

    let result: Result<serde_json::Value, String> = if is_wallet_method(method) {
        let params = body.get("params").cloned().unwrap_or(serde_json::Value::Null);
        handle_wallet_method(&state.wallet, method, &params).await
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
    let fuegod_ok = client.get(format!("{}/getinfo", state.fuegod_url))
        .send().await
        .map(|r| r.status().is_success())
        .unwrap_or(false);

    let status = state.wallet.sync_status();

    Json(serde_json::json!({
        "status": if fuegod_ok { "ok" } else { "degraded" },
        "fuego": fuegod_ok,
        "wallet": {
            "address": state.wallet.address(),
            "balance": state.wallet.balance(),
            "height": status.current_height,
            "syncing": status.is_syncing,
        },
        "scanned_height": state.wallet.height(),
    }))
}

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

async fn scan_balance_handler(
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    let balance = state.wallet.balance_full();
    let status = state.wallet.sync_status();
    Json(serde_json::json!({
        "balance": balance.confirmed,
        "pending": balance.pending,
        "immature": balance.immature,
        "height": status.current_height,
        "address": state.wallet.address(),
    }))
}

pub async fn run_server(
    wallet: Arc<WalletService>,
    fuegod_url: &str,
    bind_addr: &str,
) -> Result<(), String> {
    let state = Arc::new(AppState {
        wallet,
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
