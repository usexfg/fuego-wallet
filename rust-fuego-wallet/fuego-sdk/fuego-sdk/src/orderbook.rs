use serde::{Deserialize, Serialize};
use crate::error::{Result, SdkError};
use crate::types::*;

/// Orderbook RPC client wrapping fuegod daemon endpoints.
pub struct OrderbookClient {
    endpoint: String,
    client: reqwest::Client,
}

impl OrderbookClient {
    pub fn new(endpoint: impl Into<String>) -> Self {
        Self {
            endpoint: endpoint.into(),
            client: reqwest::Client::new(),
        }
    }

    // ── Swap Offers ───────────────────────────────────────────────────

    pub async fn get_offers(&self, pair: SwapPair) -> Result<Vec<SwapOffer>> {
        let resp: OfferResponse = self.post("/getswapoffers", serde_json::json!({
            "pair": pair as u8,
        })).await?;
        Ok(resp.offers)
    }

    pub async fn get_price(&self, pair: SwapPair) -> Result<SwapPriceResponse> {
        self.post("/getswapprice", serde_json::json!({
            "pair": pair as u8,
        })).await
    }

    pub async fn get_trades(&self, pair: SwapPair, limit: u32) -> Result<Vec<SwapTrade>> {
        let resp: TradesResponse = self.post("/getswaptrades", serde_json::json!({
            "pair": pair as u8,
            "limit": limit,
        })).await?;
        Ok(resp.trades)
    }

    pub async fn submit_offer(&self, offer: &SignedOffer) -> Result<()> {
        let _: serde_json::Value = self.post("/submitswap", serde_json::to_value(offer)?).await?;
        Ok(())
    }

    pub async fn cancel_offer(&self, offer_id: &str, maker_pubkey: &str, signature: &str) -> Result<()> {
        let _: serde_json::Value = self.post("/cancelswap", serde_json::json!({
            "offerId": offer_id,
            "makerPubKey": maker_pubkey,
            "signature": signature,
        })).await?;
        Ok(())
    }

    pub async fn request_swap(
        &self,
        offer_id: &str,
        amount: u64,
        taker_pubkey: &str,
        proof_of_funds: &str,
    ) -> Result<()> {
        let _: serde_json::Value = self.post("/requestswap", serde_json::json!({
            "offerId": offer_id,
            "amount": amount,
            "takerPubKey": taker_pubkey,
            "proofOfFunds": proof_of_funds,
        })).await?;
        Ok(())
    }

    pub async fn get_active_swaps(&self) -> Result<Vec<SwapStatus>> {
        let resp: ActiveSwapsResponse = self.post("/getactiveswaps", serde_json::Value::Null).await?;
        Ok(resp.swaps)
    }

    pub async fn get_swap_status(&self, swap_id: &str) -> Result<SwapStatus> {
        self.post("/getswapstatus", serde_json::json!({
            "swapId": swap_id,
        })).await
    }

    // ── Orderbook State ───────────────────────────────────────────────

    pub async fn get_orderbook_state(&self, depth: u32) -> Result<OrderBookState> {
        self.get(&format!("/get_orderbook_state?depth={depth}")).await
    }

    pub async fn get_fuego_price(&self) -> Result<FuegoPrice> {
        self.get("/get_fuego_price").await
    }

    // ── AMM / Hearth ──────────────────────────────────────────────────

    pub async fn get_amm_quote(&self, sell_xfg: bool, amount: &str) -> Result<AmmQuote> {
        self.get(&format!(
            "/amm_quote?sell_xfg={sell_xfg}&amount={amount}"
        )).await
    }

    pub async fn get_pool_info(&self) -> Result<PoolInfo> {
        self.get("/amm_pool_info").await
    }

    // ── HTTP helpers ──────────────────────────────────────────────────

    async fn post<T: serde::de::DeserializeOwned>(&self, path: &str, body: serde_json::Value) -> Result<T> {
        let resp = self.client
            .post(format!("{}{}", self.endpoint, path))
            .json(&body)
            .send()
            .await
            .map_err(|e| SdkError::Network(format!("HTTP request failed: {e}")))?;

        let status = resp.status();
        let text = resp.text().await
            .map_err(|e| SdkError::Network(format!("Failed to read response: {e}")))?;

        if !status.is_success() {
            return Err(SdkError::Network(format!("RPC {path} returned {status}: {text}")));
        }

        serde_json::from_str(&text)
            .map_err(|e| SdkError::Serialization(format!("Failed to decode {}: {} (body: {})", path, e, &text[..text.len().min(200)])))
    }

    async fn get<T: serde::de::DeserializeOwned>(&self, path: &str) -> Result<T> {
        let resp = self.client
            .get(format!("{}{}", self.endpoint, path))
            .send()
            .await
            .map_err(|e| SdkError::Network(format!("HTTP request failed: {e}")))?;

        let status = resp.status();
        let text = resp.text().await
            .map_err(|e| SdkError::Network(format!("Failed to read response: {e}")))?;

        if !status.is_success() {
            return Err(SdkError::Network(format!("GET {path} returned {status}: {text}")));
        }

        serde_json::from_str(&text)
            .map_err(|e| SdkError::Serialization(format!("Failed to decode {path}: {e}")))
    }
}

// ── Response types ─────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OfferResponse {
    pub offers: Vec<SwapOffer>,
    #[serde(default)]
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TradesResponse {
    pub trades: Vec<SwapTrade>,
    #[serde(default)]
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActiveSwapsResponse {
    pub swaps: Vec<SwapStatus>,
    #[serde(default)]
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AmmQuote {
    pub sell_xfg: bool,
    pub input_amount: String,
    pub output_amount: String,
    pub price_impact: String,
    #[serde(default)]
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolInfo {
    pub xfg_reserve: String,
    pub heat_reserve: String,
    pub spot_price: String,
    pub xfg_heat_ratio: String,
    #[serde(default)]
    pub status: String,
}
