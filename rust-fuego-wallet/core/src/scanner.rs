//! JSON-based output scanning over fuegod `/gettransactions` responses.
//! The live wallet path uses the SDK scanner over `/queryblockslite.bin`;
//! these helpers exist for RPC-based tooling.

use fuego_crypto::{PublicKey, derive_public_key, generate_key_derivation, generate_key_image, derive_secret_key};
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
/// Standard CryptoNote: tag 0x01 (varint) followed by 32 bytes.
fn extract_tx_public_key(extra_hex: &str) -> Option<[u8; 32]> {
    let bytes = hex::decode(extra_hex).ok()?;
    let mut pos = 0usize;
    while pos < bytes.len() {
        // tags are single-byte varints for 0x00/0x01/0x02
        match bytes[pos] {
            0x01 => {
                if pos + 33 > bytes.len() {
                    return None;
                }
                let mut key = [0u8; 32];
                key.copy_from_slice(&bytes[pos + 1..pos + 33]);
                return Some(key);
            }
            0x00 => pos += 1,
            0x02 => {
                if pos + 1 >= bytes.len() {
                    return None;
                }
                let len = bytes[pos + 1] as usize;
                if pos + 2 + len > bytes.len() {
                    return None;
                }
                pos += 2 + len;
            }
            _ => return None,
        }
    }
    None
}

/// Scan a batch of transactions for outputs belonging to our keys using the
/// standard CryptoNote discovery rule: P == Hs(a·R || i) · G + B.
pub fn scan_transactions(
    view_secret: &[u8; 32],
    spend_public: &[u8; 32],
    spend_secret: &[u8; 32],
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

        // Compute key derivation: D = a * R
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

            // P == Hs(D || i) * G + B
            let expected = match derive_public_key(&derivation, i as u64, spend_public) {
                Some(p) => p,
                None => continue,
            };
            let actual = output.get("target")
                .and_then(|t| t.get("key"))
                .or_else(|| output.get("target"))
                .and_then(|k| k.as_str())
                .and_then(|s| hex::decode(s).ok());
            let actual = match actual {
                Some(v) if v.len() == 32 => {
                    let mut k = [0u8; 32];
                    k.copy_from_slice(&v);
                    k
                }
                _ => continue,
            };

            if expected.0 != actual {
                continue;
            }

            // x = b + Hs(D || i); I = x * H_p(P)
            let secret = match derive_secret_key(&derivation, i as u64, spend_secret) {
                Some(s) => s,
                None => continue,
            };
            let ki = generate_key_image(&PublicKey(actual), &secret);

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

    outputs
}

/// Parse a full transaction list from fuegod gettransactions response.
pub fn parse_gettransactions_response(response: &serde_json::Value) -> Vec<serde_json::Value> {
    response.get("txs")
        .and_then(|txs| txs.as_array())
        .cloned()
        .unwrap_or_default()
}
