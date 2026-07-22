use serde::{Deserialize, Serialize};
use crate::error::{Result, SdkError};
use crate::types::*;

/// Certificate of Deposit market RPC client.
/// Wraps the fuegod daemon's CD endpoints.
pub struct CdMarketClient {
    endpoint: String,
    client: reqwest::Client,
}

impl CdMarketClient {
    pub fn new(endpoint: impl Into<String>) -> Self {
        Self {
            endpoint: endpoint.into(),
            client: reqwest::Client::new(),
        }
    }

    // ── CD Listings ───────────────────────────────────────────────────

    pub async fn get_cd_listings(&self, min_term: Option<u32>, max_term: Option<u32>) -> Result<Vec<CdListing>> {
        let mut body = serde_json::json!({});
        if let Some(min) = min_term {
            body["minTerm"] = serde_json::json!(min);
        }
        if let Some(max) = max_term {
            body["maxTerm"] = serde_json::json!(max);
        }
        let resp: CdListingsResponse = self.post("/getcdlistings", body).await?;
        Ok(resp.listings)
    }

    pub async fn get_cd_offers(&self) -> Result<Vec<CdOffer>> {
        let resp: CdOffersResponse = self.post("/getcdoffers", serde_json::json!({})).await?;
        Ok(resp.offers)
    }

    pub async fn create_cd(&self, amount: u64, term: u32) -> Result<String> {
        let resp: serde_json::Value = self.post("/createcd", serde_json::json!({
            "amount": amount,
            "term": term,
        })).await?;
        let cd_id = resp["cd_id"].as_str().unwrap_or("").to_string();
        Ok(cd_id)
    }

    pub async fn redeem_cd(&self, cd_id: &str) -> Result<()> {
        let _: serde_json::Value = self.post("/redeemcd", serde_json::json!({
            "cdId": cd_id,
        })).await?;
        Ok(())
    }

    pub async fn get_my_cds(&self) -> Result<Vec<MyCd>> {
        let resp: MyCdsResponse = self.post("/getmycds", serde_json::Value::Null).await?;
        Ok(resp.cds)
    }

    // ── CD Market Data ────────────────────────────────────────────────

    pub async fn get_cd_rate(&self, term: u32) -> Result<CdRate> {
        self.get(&format!("/getcdrate?term={term}")).await
    }

    pub async fn get_cd_rates_all(&self) -> Result<Vec<CdRate>> {
        self.get("/getcdrates").await
    }

    pub async fn get_cd_volume(&self, term: u32) -> Result<u64> {
        self.get(&format!("/getcdvolume?term={term}")).await
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
            .map_err(|e| SdkError::Serialization(format!("Failed to decode {path}: {e}")))
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
pub struct CdListingsResponse {
    pub listings: Vec<CdListing>,
    #[serde(default)]
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CdOffersResponse {
    pub offers: Vec<CdOffer>,
    #[serde(default)]
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MyCdsResponse {
    pub cds: Vec<MyCd>,
    #[serde(default)]
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CdRate {
    pub term: u32,
    pub apy: String,
    pub min_amount: u64,
    #[serde(default)]
    pub status: String,
}
