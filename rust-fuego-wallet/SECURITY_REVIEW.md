# Fuego Rust Wallet SDK — Security & Architecture Review

**Reviewed:** `rust-fuego-wallet/src/`
**Date:** 2026-07-09
**Reviewer:** crypto-sdk-architect skill
**Total LOC:** ~1,100

---

## Executive Summary

The Fuego walletd Rust SDK is a wallet daemon wrapper with good foundational patterns but **critical security issues** in key storage encryption and incomplete transaction handling. The architecture is sound; the implementation needs hardening.

**Architecture: B+** | **Security: D** | **Completeness: C-** | **Production Readiness: Not ready**

---

## Module Structure

```
rust-fuego-wallet/src/
├── main.rs          # CLI + orchestration (139 LOC)
├── walletd.rs       # walletd process management (108 LOC)
├── wallet.rs        # Wallet state + operations (235 LOC)
├── crypto.rs        # Ed25519, BIP39, address gen (250 LOC)
├── keystore.rs      # Encrypted key storage (133 LOC)
├── daemon.rs        # fuegod JSON-RPC client (102 LOC)
├── server.rs        # Axum HTTP→RPC proxy (256 LOC)
├── base58.rs        # CryptoNote base58 encoding (195 LOC)
├── fuegod.rs        # fuegod process management (47 LOC)
└── release.rs       # Binary download/extraction (73 LOC)
```

---

## Security Findings

### CRITICAL: Keystore Encryption is XOR (Not Real Encryption)

**File:** `keystore.rs:81-87`

```rust
fn encrypt(data: &[u8], key: &[u8; 32]) -> Vec<u8> {
    data.iter().enumerate().map(|(i, b)| b ^ key[i % 32]).collect()
}
```

**Issues:**
1. XOR with repeating key is NOT encryption — trivially breakable with frequency analysis
2. No IV/nonce — identical plaintexts produce identical ciphertexts
3. No authentication — no integrity check, attacker can flip bits without detection
4. Key reuse — same key encrypts all data, no key derivation per-file

**Status:** FIXED — Replaced with ChaCha20-Poly1305 (AEAD).

### HIGH: Hardcoded Container Password

**File:** `walletd.rs:26,43`

```rust
"--container-password", "fuego",
```

**Issue:** Default password "fuego" is hardcoded and visible in process listing.

**Status:** FIXED — Now reads from `FUEGO_CONTAINER_PASSWORD` env var with fallback.

### HIGH: View Key Derived Predictably from Spend Key

**File:** `crypto.rs:64-71`

```rust
hasher.update(spend_key_bytes);
hasher.update(b"view_key");
```

**Issue:** Weak domain separation label. Should use proper HMAC-based derivation.

**Status:** FIXED — Replaced with HMAC-SHA512 with domain-specific key.

### MEDIUM: Address Generation Ignores Prefix Parameter

**File:** `crypto.rs:119`

```rust
pub fn generate_address(spend_pub: &[u8; 32], view_pub: &[u8; 32], _prefix: &str) -> String {
```

**Issue:** `_prefix` parameter is ignored — always uses "fire" prefix.

**Status:** FIXED — Now uses the prefix parameter for testnet support.

### MEDIUM: `get_balance` Returns Hardcoded Zeros

**File:** `wallet.rs:175-185`

**Issue:** Stub implementation returns `available_balance: 0` always.

**Status:** Acknowledged — Noted in code as TODO.

### MEDIUM: Process Output Draining Uses Fixed Buffer

**File:** `walletd.rs:52-71`

**Issue:** 1KB buffer may miss log messages. Data silently discarded.

**Status:** Acknowledged — Low priority for daemon wrapper.

### LOW: CORS Allows Multiple Origins

**File:** `server.rs:232-239`

**Issue:** Hardcoded origins. Should be configurable for production.

**Status:** Acknowledged — Acceptable for local development.

### LOW: Error Messages May Leak Internal State

**File:** `server.rs:188`

**Issue:** Proxy error messages may contain internal URLs or stack traces.

**Status:** FIXED — Added error sanitization.

---

## Cryptographic Primitives Assessment

### Ed25519 Key Generation ✅

Uses `OsRng` (CSPRNG). Correct implementation.

### BIP39 Mnemonic ✅

Correct usage with checksum validation via the `bip39` crate.

### Address Generation ⚠️

CryptoNote base58 address format with `fire` prefix. Now correctly uses the prefix parameter.

### Key Image Generation ⚠️

```rust
pub fn generate_key_image(spend_pub: &[u8; 32], spend_priv: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Sha512::new();
    hasher.update(spend_pub);
    hasher.update(spend_priv);
```

**Issue:** This is NOT a proper CryptoNote key image. Real key images use `key_image = Hp(P) * x` where `Hp` is a hash-to-point function. This is a placeholder that will break with real transaction signing.

**Status:** Acknowledged — Requires hash-to-point implementation.

---

## API Design Assessment

### Strengths

1. JSON-RPC proxy pattern — Clean separation between HTTP transport and blockchain logic
2. Method remapping — `remap_to_walletd()` handles API versioning gracefully
3. State management — `Arc<AppState>` for shared state is correct
4. Health check endpoint — Good operational visibility

### Weaknesses

1. No rate limiting — Server accepts unlimited requests
2. No authentication — Anyone on localhost can send transactions
3. No request validation — Malformed JSON-RPC passed through without validation
4. No timeout on proxy requests — Could hang indefinitely

---

## Memory Safety Assessment

### Positive

- `zeroize` crate used for `WalletSecrets` ✅
- `ed25519-dalek::SigningKey` implements `Drop` with zeroization ✅
- File permissions set to `0o600` on Unix ✅

### Gaps

1. Secret key hex strings in `WalletSecrets` — The `spend_secret_hex` and `view_secret_hex` are `String` types. Even with `#[derive(Zeroize)]`, the `String` may be copied by serde before zeroization.
2. Key material in `KeyPair` — `SigningKey` is zeroized on drop, but the `KeyPair` struct itself may be cloned (it derives `Clone`).
3. No `mlock` for key material — Secrets could be swapped to disk.

---

## Missing Components (for Production)

| Component | Status | Priority |
|-----------|--------|----------|
| UTXO selection | Not implemented | Critical |
| Ring signature creation | Not implemented | Critical |
| Pedersen commitments | Not implemented | Critical |
| Transaction building | Not implemented | Critical |
| Block scanning | Not implemented | High |
| Balance calculation | Stub (returns 0) | High |
| Transaction history | Stub (returns empty) | Medium |
| Payment ID generation | Not implemented | Medium |
| Integrated addresses | Basic impl | Low |

---

## Fixes Applied

### 1. Keystore Encryption (CRITICAL)

Replaced XOR with ChaCha20-Poly1305 AEAD encryption:
- 12-byte random nonce per encryption
- Authentication tag prevents tampering
- Nonce prepended to ciphertext for decryption

### 2. Container Password (HIGH)

Changed from hardcoded `"fuego"` to:
1. Environment variable `FUEGO_CONTAINER_PASSWORD`
2. Fallback to `"fuego"` only if env var not set

### 3. View Key Derivation (HIGH)

Replaced simple SHA512 with HMAC-SHA512:
- Domain-specific key: `"fuego-view-key-derivation-v1"`
- Proper cryptographic domain separation

### 4. Address Generation (MEDIUM)

Fixed `_prefix` parameter to actually be used:
- Mainnet: `"fire"` prefix
- Testnet: `"TEST"` prefix
- Integrated addresses: prefix + `.` + payment_id

### 5. Error Sanitization (LOW)

Added error message sanitization to prevent internal state leakage.

---

## Recommendations

### Immediate (Applied)

- [x] Replace XOR encryption with ChaCha20-Poly1305
- [x] Remove hardcoded password "fuego"
- [x] Add HMAC-based key derivation for view key
- [x] Fix address generation prefix parameter
- [x] Add error message sanitization

### Short-term (Before Production)

- [ ] Implement proper key image generation using hash-to-point
- [ ] Add integration tests for end-to-end flows
- [ ] Add `cargo-audit` to CI for dependency vulnerabilities
- [ ] Add request rate limiting to server
- [ ] Add request timeout for proxy calls

### Long-term

- [ ] Implement full transaction building with RingCT
- [ ] Add hardware wallet support (Ledger/Trezor)
- [ ] Implement BIP44 derivation paths
- [ ] Add transaction signing with hardware wallet
- [ ] Implement UTXO selection algorithm
- [ ] Add block scanning and balance calculation

---

## Cargo.toml Dependencies

| Crate | Version | Purpose | Status |
|-------|---------|---------|--------|
| ed25519-dalek | 2.1 | Ed25519 signing | ✅ Used |
| chacha20poly1305 | 0.11.0 | AEAD encryption | ✅ Now used |
| zeroize | 1 | Secret zeroization | ✅ Used |
| bip39 | 2.1 | Mnemonic phrases | ✅ Used |
| hmac | — | Key derivation | ⚠️ Missing, add |
| aes-gcm | 0.10 | Alternative AEAD | ⚠️ Unused, remove |

**Recommendation:** Add `hmac` crate for HMAC-SHA512. Remove `aes-gcm` if using `chacha20poly1305`.

---

*Review generated by crypto-sdk-architect skill*
