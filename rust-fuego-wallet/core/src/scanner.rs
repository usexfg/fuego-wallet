use fuego_crypto::{PublicKey, generate_key_derivation, derive_public_key, generate_key_image};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct OwnedOutput {
    pub amount: u64,
    pub output_index: u32,
    pub tx_hash: String,
    pub block_height: u64,
    pub key_image: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ScanResult {
    pub balance: u64,
    pub outputs: Vec<OwnedOutput>,
    pub scanned_height: u64,
    pub scanned_tx_count: u64,
}

/// Extract the tx public key from a transaction's extra field.
/// Standard CryptoNote: tag 0x01 followed by 32 bytes.
fn extract_tx_public_key(extra_hex: &str) -> Option<[u8; 32]> {
    let bytes = hex::decode(extra_hex).ok()?;
    for i in 0..bytes.len().saturating_sub(33) {
        if bytes[i] == 0x01 {
            let mut key = [0u8; 32];
            key.copy_from_slice(&bytes[i + 1..i + 33]);
            return Some(key);
        }
    }
    None
}

/// Scan a batch of transactions for outputs belonging to our keys.
pub fn scan_transactions(
    view_secret: &[u8; 32],
    spend_public: &[u8; 32],
    transactions: &[serde_json::Value],
    block_height: u64,
) -> Vec<OwnedOutput> {
    let mut outputs = Vec::new();

    for tx_wrapper in transactions {
        let tx = tx_wrapper.get("tx").unwrap_or(tx_wrapper);

        // Extract tx public key
        let extra = tx.get("extra").and_then(|e| e.as_str()).unwrap_or("");
        let tx_pub = match extract_tx_public_key(extra) {
            Some(k) => k,
            None => continue,
        };

        // Compute key derivation
        let tx_pub_key = PublicKey(tx_pub);
        let derivation = match generate_key_derivation(&tx_pub_key, view_secret) {
            Some(d) => d,
            None => continue,
        };

        // Scan each output
        let empty: Vec<serde_json::Value> = vec![];
        let vout = tx.get("vout").and_then(|v| v.as_array()).unwrap_or(&empty);
        for (i, output) in vout.iter().enumerate() {
            let amount = output.get("amount")
                .and_then(|a| a.as_u64())
                .or_else(|| output.get("amount").and_then(|a| a.as_str()).and_then(|s| s.parse().ok()))
                .unwrap_or(0);

            // Derive expected public key for this output index
            let expected = derive_public_key(&derivation, i as u64);

            // Check if it matches our spend public key
            if expected.0 == *spend_public {
                // Generate key image for spent detection
                let spend_key = PublicKey(*spend_public);
                let ki = generate_key_image(&spend_key, view_secret);

                let tx_hash = tx_wrapper.get("tx_hash")
                    .and_then(|h| h.as_str())
                    .unwrap_or("")
                    .to_string();

                outputs.push(OwnedOutput {
                    amount,
                    output_index: i as u32,
                    tx_hash,
                    block_height,
                    key_image: hex::encode(ki.0),
                });
            }
        }
    }

    outputs
}

/// Parse a full transaction list from fuegod gettransactions response.
pub fn parse_gettransactions_response(response: &serde_json::Value) -> Vec<serde_json::Value> {
    response.get("txs")
        .and_then(|txs| txs.as_array())
        .cloned()
        .unwrap_or_default()
}
