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
    pub fuegod_url: String,
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

fn remap_method(method: &str) -> String {
    match method {
        "getBalance" => "getbalance".to_string(),
        "getAddresses" => "get_address".to_string(),
        "getTransactions" => "get_transfers".to_string(),
        "sendTransaction" => "transfer".to_string(),
        "getStatus" => "get_height".to_string(),
        "cd::list" => "list_cds".to_string(),
        "cd::create" => "create_cd".to_string(),
        "cd::claim" => "withdraw_cd".to_string(),
        "cd::market_list" => "getcdoffers".to_string(),
        "cd::sell" => "submitcd".to_string(),
        "cd::buy" => "submitcd".to_string(),
        "cd::cancel_listing" => "cancelcd".to_string(),
        "cd::apy" => "estimate_cd_yield".to_string(),
        _ => method.to_string(),
    }
}

fn remap_params(method: &str, params: &serde_json::Value) -> serde_json::Value {
    match method {
        "sendTransaction" => {
            // Dart sends {destinations, fee, anonymity, paymentId}
            // walletd expects {destinations, fee, mixin, unlock_time}
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
            // Dart sends {coin, amount, duration_blocks}
            // walletd expects {amount, term}
            let amount = params.get("amount").cloned()
                .unwrap_or(serde_json::json!("0"));
            let term = params.get("duration_blocks").cloned()
                .unwrap_or(serde_json::json!(1440));
            serde_json::json!({
                "amount": amount,
                "term": term,
            })
        }
        "cd::claim" => {
            // Dart sends {cd_id}
            // walletd expects {deposit_id}
            let deposit_id = params.get("cd_id").cloned()
                .unwrap_or(serde_json::json!(""));
            serde_json::json!({"deposit_id": deposit_id})
        }
        "cd::sell" => {
            // Dart sends {cd_id, price}
            // fuegod expects {offerId, isSell, cdAmount, cdTerm, cdEpoch, cdKeyImage, askPrice, makerPubKey, signature, ttlBlocks}
            // This is a simplified stub — real implementation needs wallet signing
            let cd_id = params.get("cd_id").cloned()
                .unwrap_or(serde_json::json!(""));
            let price = params.get("price").cloned()
                .unwrap_or(serde_json::json!("0"));
            serde_json::json!({
                "offerId": "",
                "isSell": true,
                "cdAmount": cd_id,
                "cdTerm": 0,
                "cdEpoch": 0,
                "cdKeyImage": "",
                "askPrice": price,
                "makerPubKey": "",
                "signature": "",
                "ttlBlocks": 1440,
            })
        }
        "cd::buy" => {
            // Dart sends {listing_id}
            // fuegod expects {offerId, amount, takerPubKey, proofOfFunds}
            let listing_id = params.get("listing_id").cloned()
                .unwrap_or(serde_json::json!(""));
            serde_json::json!({
                "offerId": listing_id,
                "amount": 0,
                "takerPubKey": "",
                "proofOfFunds": "",
            })
        }
        "cd::cancel_listing" => {
            // Dart sends {listing_id}
            // fuegod expects {offerId, makerPubKey, signature}
            let listing_id = params.get("listing_id").cloned()
                .unwrap_or(serde_json::json!(""));
            serde_json::json!({
                "offerId": listing_id,
                "makerPubKey": "",
                "signature": "",
            })
        }
        _ => params.clone(),
    }
}

fn is_walletd_method(method: &str) -> bool {
    matches!(method,
        "getAddresses" | "getBalance" | "getTransactions" | "sendTransaction" |
        "getAddress" | "getStatus" |
        "start_mining" | "stop_mining" |
        "mint_heat" | "swap" | "add_liq" | "remove_liq" |
        "create_integrated" | "store" | "get_messages" |
        "get_payments" | "get_outputs" | "optimize" |
        "estimate_fusion" | "send_fusion" |
        "sign_offer" | "sign_cancel" |
        "initiate_swap" | "complete_swap" | "refund_swap" |
        "heat_mint" | "send_heat" | "amm_swap" | "amm_add_liquidity" | "heat_deposit" |
        "list_cds" | "create_cd" | "withdraw_cd" | "rollover_cd" | "estimate_cd_yield"
    )
}

fn is_fuegod_method(method: &str) -> bool {
    matches!(method,
        "getinfo" | "getheight" | "getblockcount" | "on_getblockhash" | "getblock" |
        "getlastblockheader" | "getblockheaderbyhash" | "getblockheaderbyheight" |
        "peers" | "feeaddress" | "getethereal" | "paymentid" |
        "gettransactions" | "sendrawtransaction" |
        "getrandom_outs_json" | "get_outputs_heights" |
        "check_tx_proof" | "check_reserve_proof" |
        "getcdoffers" | "submitcd" | "cancelcd" |
        "heat_metrics" | "amm_quote" | "amm_pool_info" |
        "get_orderbook_state" | "get_orderbook_info" | "get_orderbook_estimates" |
        "get_fuego_price" | "getswapoffers" | "getswapprice" | "getswaptrades" |
        "submitswap" | "cancelswap" | "requestswap" |
        "getdeposits" | "get_block_range" | "get_maturing_deposits" |
        "rollover_deposit" | "get_fee_pool_info" | "get_epoch_history" |
        "estimate_cd_yield" | "get_treasury_info" | "get_alias" | "get_alias_by_address" | "get_all_aliases" |
        "getactiveswaps" | "initiate" | "accept" | "processswap" | "refundswap"
    )
}

async fn proxy_to_walletd(walletd_url: &str, body: &serde_json::Value) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::new();
    let url = format!("{}/json_rpc", walletd_url);
    let resp = client.post(&url).json(body).send().await
        .map_err(|e| format!("walletd request: {}", e))?;
    let val: serde_json::Value = resp.json().await
        .map_err(|e| format!("walletd response: {}", e))?;
    let result = val.get("result").cloned().unwrap_or(val);
    Ok(result)
}

async fn proxy_to_fuegod(fuegod_url: &str, body: &serde_json::Value) -> Result<serde_json::Value, String> {
    let client = reqwest::Client::new();
    let url = format!("{}/json_rpc", fuegod_url);
    let resp = client.post(&url).json(body).send().await
        .map_err(|e| format!("fuego daemon request: {}", e))?;
    let val: serde_json::Value = resp.json().await
        .map_err(|e| format!("fuego daemon response: {}", e))?;
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

    let result: Result<serde_json::Value, String> = match method {
        "getinfo" => {
            let wallet = state.wallet.lock().await;
            wallet.wallet_status().await
        }

        "getheight" => {
            let wallet = state.wallet.lock().await;
            match wallet.wallet_status().await {
                Ok(info) => {
                    let h = info.get("height").and_then(|v| v.as_u64()).unwrap_or(0);
                    Ok(serde_json::json!({"height": h}))
                }
                Err(e) => Err(e),
            }
        }

        _ if is_walletd_method(method) => {
            let walletd_method = remap_method(method);
            let remapped_params = remap_params(method, &params);
            let mut forwarded = body.clone();
            forwarded["method"] = serde_json::json!(walletd_method);
            forwarded["params"] = remapped_params;

            match &state.walletd_url {
                Some(url) => proxy_to_walletd(url, &forwarded).await,
                None => Err("walletd not running — start with fuego-wallet serve".into()),
            }
        }

        _ if is_fuegod_method(method) => {
            proxy_to_fuegod(&state.fuegod_url, &body).await
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
    fuegod_url: &str,
    bind_addr: &str,
) -> Result<(), String> {
    let state = Arc::new(AppState {
        wallet: Mutex::new(wallet_state),
        walletd_url,
        fuegod_url: fuegod_url.to_string(),
    });

    let cors = CorsLayer::new()
        .allow_origin([
            "http://localhost:8070".parse().unwrap(),
            "http://127.0.0.1:8070".parse().unwrap(),
            "http://localhost:8080".parse().unwrap(),
        ])
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
