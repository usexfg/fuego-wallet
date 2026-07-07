use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::Serialize;
use std::sync::Arc;
use tokio::sync::Mutex;
use tower_http::cors::{Any, CorsLayer};

use crate::wallet::WalletState;

pub struct AppState {
    pub wallet: Mutex<WalletState>,
    pub walletd_url: Option<String>,
}

#[derive(Serialize)]
struct JsonRpcSuccess<T: Serialize> {
    jsonrpc: String,
    id: u64,
    result: T,
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

async fn proxy_to_walletd(walletd_url: &str, body: &serde_json::Value) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::new();
    let url = format!("{}/json_rpc", walletd_url);
    let resp = client.post(&url).json(body).send().await
        .map_err(|e| format!("walletd request: {}", e))?;
    let val: serde_json::Value = resp.json().await
        .map_err(|e| format!("walletd response: {}", e))?;
    Ok(val)
}

async fn json_rpc_handler(
    State(state): State<Arc<AppState>>,
    Json(body): Json<serde_json::Value>,
) -> impl IntoResponse {
    let id = body.get("id").and_then(|v| v.as_u64()).unwrap_or(0);
    let method = body.get("method").and_then(|v| v.as_str()).unwrap_or("");
    let _params = body.get("params").cloned().unwrap_or(serde_json::Value::Null);

    let result: Result<serde_json::Value, String> = match method {
        "getinfo" => {
            let wallet = state.wallet.lock().await;
            wallet.wallet_status().await
        }

        "getheight" => {
            let wallet = state.wallet.lock().await;
            match wallet.wallet_status().await {
                Ok(info) => {
                    let h = info.get("daemon_height").and_then(|v| v.as_u64()).unwrap_or(0);
                    Ok(serde_json::json!({"height": h}))
                }
                Err(e) => Err(e),
            }
        }

        "getAddresses" => {
            let wallet = state.wallet.lock().await;
            wallet.get_addresses().await
                .map(|a| serde_json::to_value(a).unwrap_or_default())
        }

        "create_integrated" => {
            let wallet = state.wallet.lock().await;
            let pid = _params.get("payment_id").and_then(|v| v.as_str());
            match pid {
                Some(pid) => wallet.create_integrated(pid)
                    .map(|r| serde_json::to_value(r).unwrap_or_default()),
                None => Err("missing payment_id".to_string()),
            }
        }

        // Wallet operations — proxy to walletd
        "getBalance" | "getTransactions" | "sendTransaction" |
        "start_mining" | "stop_mining" |
        "mint_heat" | "swap" | "add_liq" | "remove_liq" |
        "cd::list" | "cd::create" | "cd::claim" |
        "cd::market_list" | "cd::sell" | "cd::buy" |
        "cd::cancel_listing" | "cd::apy" => {
            match &state.walletd_url {
                Some(url) => proxy_to_walletd(url, &body).await,
                None => Err("walletd not running — start with fuego-wallet serve".into()),
            }
        }

        "getblockcount" | "on_getblockhash" | "getblock" => {
            Err("connect directly to fuegod daemon for this RPC".into())
        }

        _ => Err(format!("unknown method: {}", method)),
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

async fn health_check() -> impl IntoResponse {
    Json(serde_json::json!({"status": "ok", "service": "fuego-wallet"}))
}

pub async fn run_server(
    wallet_state: WalletState,
    walletd_url: Option<String>,
    bind_addr: &str,
) -> Result<(), String> {
    let state = Arc::new(AppState {
        wallet: Mutex::new(wallet_state),
        walletd_url,
    });

    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

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
