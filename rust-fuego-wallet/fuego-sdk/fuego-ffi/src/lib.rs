use fuego_crypto::{Keypair, PublicKey, make_address, generate_key_derivation, derive_public_key, underive_public_key, generate_key_image, cn_base58_encode};
use fuego_vault::Vault;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;
use std::slice;

// ── Memory management ──

/// Free a string returned by fuego_ffi functions.
#[no_mangle]
pub unsafe extern "C" fn fuego_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(CString::from_raw(ptr));
    }
}

/// Free a byte buffer returned by fuego_ffi functions.
#[no_mangle]
pub unsafe extern "C" fn fuego_bytes_free(ptr: *mut u8, len: usize) {
    if !ptr.is_null() {
        drop(Vec::from_raw_parts(ptr, len, len));
    }
}

// ── Key generation ──

/// Generate a random keypair. Returns JSON: {"secret":"hex","public":"hex"}
#[no_mangle]
pub extern "C" fn fuego_keypair_generate() -> *mut c_char {
    let kp = Keypair::generate();
    let json = serde_json::json!({
        "secret": hex::encode(kp.secret),
        "public": hex::encode(kp.public),
    });
    CString::new(json.to_string()).unwrap().into_raw()
}

/// Create keypair from a 32-byte secret. Returns JSON: {"secret":"hex","public":"hex"}
#[no_mangle]
pub unsafe extern "C" fn fuego_keypair_from_secret(secret_ptr: *const u8) -> *mut c_char {
    if secret_ptr.is_null() {
        return CString::new("{\"error\":\"null pointer\"}").unwrap().into_raw();
    }
    let secret = slice::from_raw_parts(secret_ptr, 32);
    let mut secret_bytes = [0u8; 32];
    secret_bytes.copy_from_slice(secret);
    let kp = Keypair::from_secret(secret_bytes);
    let json = serde_json::json!({
        "secret": hex::encode(kp.secret),
        "public": hex::encode(kp.public),
    });
    CString::new(json.to_string()).unwrap().into_raw()
}

// ── Address generation ──

/// Generate a Fuego address from spend + view public keys (32 bytes each).
#[no_mangle]
pub unsafe extern "C" fn fuego_make_address(
    spend_pub_ptr: *const u8,
    view_pub_ptr: *const u8,
) -> *mut c_char {
    if spend_pub_ptr.is_null() || view_pub_ptr.is_null() {
        return CString::new("").unwrap().into_raw();
    }
    let spend_pub = slice::from_raw_parts(spend_pub_ptr, 32);
    let view_pub = slice::from_raw_parts(view_pub_ptr, 32);
    let mut spend = [0u8; 32];
    let mut view = [0u8; 32];
    spend.copy_from_slice(spend_pub);
    view.copy_from_slice(view_pub);
    let addr = make_address(&spend, &view);
    CString::new(addr.0).unwrap().into_raw()
}

// ── Vault (HD wallet) ──

/// Generate a new vault. Returns serialized vault bytes.
#[no_mangle]
pub extern "C" fn fuego_vault_generate() -> FuegoBytes {
    let vault = Vault::generate();
    let data = bincode::serialize(&vault).unwrap_or_default();
    let len = data.len();
    let mut buf = data.into_boxed_slice();
    let ptr = buf.as_mut_ptr();
    std::mem::forget(buf);
    FuegoBytes { ptr, len }
}

/// Create vault from a 32-byte seed. Returns serialized vault bytes.
#[no_mangle]
pub unsafe extern "C" fn fuego_vault_from_seed(seed_ptr: *const u8) -> FuegoBytes {
    if seed_ptr.is_null() {
        return FuegoBytes { ptr: ptr::null_mut(), len: 0 };
    }
    let seed = slice::from_raw_parts(seed_ptr, 32);
    let mut seed_bytes = [0u8; 32];
    seed_bytes.copy_from_slice(seed);
    let vault = Vault::new(seed_bytes);
    let data = bincode::serialize(&vault).unwrap_or_default();
    let len = data.len();
    let mut buf = data.into_boxed_slice();
    let ptr = buf.as_mut_ptr();
    std::mem::forget(buf);
    FuegoBytes { ptr, len }
}

/// Get address from vault at a given index.
#[no_mangle]
pub unsafe extern "C" fn fuego_vault_get_address(
    vault_ptr: *const u8,
    vault_len: usize,
    index: u32,
) -> *mut c_char {
    if vault_ptr.is_null() {
        return CString::new("").unwrap().into_raw();
    }
    let data = slice::from_raw_parts(vault_ptr, vault_len);
    match bincode::deserialize::<Vault>(data) {
        Ok(vault) => {
            let addr = vault.get_address(index);
            CString::new(addr.0).unwrap().into_raw()
        }
        Err(_) => CString::new("").unwrap().into_raw(),
    }
}

/// Get hex-encoded 32-byte seed from vault. Returns 64-char hex string.
#[no_mangle]
pub unsafe extern "C" fn fuego_vault_get_seed(
    vault_ptr: *const u8,
    vault_len: usize,
) -> *mut c_char {
    if vault_ptr.is_null() {
        return CString::new("").unwrap().into_raw();
    }
    let data = slice::from_raw_parts(vault_ptr, vault_len);
    match bincode::deserialize::<Vault>(data) {
        Ok(vault) => CString::new(hex::encode(vault.master_seed)).unwrap().into_raw(),
        Err(_) => CString::new("").unwrap().into_raw(),
    }
}

/// Derive keypair from vault at index. Returns JSON: {"secret":"hex","public":"hex"}
#[no_mangle]
pub unsafe extern "C" fn fuego_vault_derive_keypair(
    vault_ptr: *const u8,
    vault_len: usize,
    index: u32,
) -> *mut c_char {
    if vault_ptr.is_null() {
        return CString::new("{\"error\":\"null pointer\"}").unwrap().into_raw();
    }
    let data = slice::from_raw_parts(vault_ptr, vault_len);
    match bincode::deserialize::<Vault>(data) {
        Ok(vault) => {
            let kp = vault.derive_keypair(index);
            let json = serde_json::json!({
                "secret": hex::encode(kp.secret),
                "public": hex::encode(kp.public),
            });
            CString::new(json.to_string()).unwrap().into_raw()
        }
        Err(e) => {
            let json = serde_json::json!({"error": e.to_string()});
            CString::new(json.to_string()).unwrap().into_raw()
        }
    }
}

/// Save vault to file path.
#[no_mangle]
pub unsafe extern "C" fn fuego_vault_save(
    vault_ptr: *const u8,
    vault_len: usize,
    path_ptr: *const c_char,
) -> FuegoResult {
    if vault_ptr.is_null() || path_ptr.is_null() {
        return FuegoResult { ok: false, error: CString::new("null pointer").unwrap().into_raw() };
    }
    let data = slice::from_raw_parts(vault_ptr, vault_len);
    let path = CStr::from_ptr(path_ptr).to_str().unwrap_or("");
    match bincode::deserialize::<Vault>(data) {
        Ok(vault) => match vault.save_unencrypted(std::path::PathBuf::from(path)) {
            Ok(()) => FuegoResult { ok: true, error: ptr::null_mut() },
            Err(e) => FuegoResult { ok: false, error: CString::new(e.to_string()).unwrap().into_raw() },
        },
        Err(e) => FuegoResult { ok: false, error: CString::new(e.to_string()).unwrap().into_raw() },
    }
}

/// Load vault from file path. Returns serialized vault bytes.
#[no_mangle]
pub unsafe extern "C" fn fuego_vault_load(path_ptr: *const c_char) -> FuegoBytes {
    if path_ptr.is_null() {
        return FuegoBytes { ptr: ptr::null_mut(), len: 0 };
    }
    let path = CStr::from_ptr(path_ptr).to_str().unwrap_or("");
    match Vault::load_unencrypted(std::path::PathBuf::from(path)) {
        Ok(vault) => {
            let data = bincode::serialize(&vault).unwrap_or_default();
            let len = data.len();
            let mut buf = data.into_boxed_slice();
            let ptr = buf.as_mut_ptr();
            std::mem::forget(buf);
            FuegoBytes { ptr, len }
        }
        Err(_) => FuegoBytes { ptr: ptr::null_mut(), len: 0 },
    }
}

// ── Crypto operations ──

/// Generate key derivation. Returns 32-byte derivation as hex string.
#[no_mangle]
pub unsafe extern "C" fn fuego_generate_key_derivation(
    key1_ptr: *const u8,
    secret2_ptr: *const u8,
) -> *mut c_char {
    if key1_ptr.is_null() || secret2_ptr.is_null() {
        return CString::new("").unwrap().into_raw();
    }
    let key1_bytes = slice::from_raw_parts(key1_ptr, 32);
    let secret2_bytes = slice::from_raw_parts(secret2_ptr, 32);
    let mut key1 = [0u8; 32];
    let mut secret2 = [0u8; 32];
    key1.copy_from_slice(key1_bytes);
    secret2.copy_from_slice(secret2_bytes);
    let pk = PublicKey(key1);
    match generate_key_derivation(&pk, &secret2) {
        Some(derivation) => CString::new(hex::encode(derivation)).unwrap().into_raw(),
        None => CString::new("").unwrap().into_raw(),
    }
}

/// Derive public key from derivation. Returns 32-byte public key as hex string.
#[no_mangle]
pub unsafe extern "C" fn fuego_derive_public_key(
    derivation_ptr: *const u8,
    output_index: u64,
) -> *mut c_char {
    if derivation_ptr.is_null() {
        return CString::new("").unwrap().into_raw();
    }
    let deriv_bytes = slice::from_raw_parts(derivation_ptr, 32);
    let mut derivation = [0u8; 32];
    derivation.copy_from_slice(deriv_bytes);
    let pk = derive_public_key(&derivation, output_index);
    CString::new(hex::encode(pk.0)).unwrap().into_raw()
}

/// Generate key image. Returns 32-byte key image as hex string.
#[no_mangle]
pub unsafe extern "C" fn fuego_generate_key_image(
    pubkey_ptr: *const u8,
    secret_ptr: *const u8,
) -> *mut c_char {
    if pubkey_ptr.is_null() || secret_ptr.is_null() {
        return CString::new("").unwrap().into_raw();
    }
    let pk_bytes = slice::from_raw_parts(pubkey_ptr, 32);
    let sk_bytes = slice::from_raw_parts(secret_ptr, 32);
    let mut pk = [0u8; 32];
    let mut sk = [0u8; 32];
    pk.copy_from_slice(pk_bytes);
    sk.copy_from_slice(sk_bytes);
    let ki = generate_key_image(&PublicKey(pk), &sk);
    CString::new(hex::encode(ki.0)).unwrap().into_raw()
}

/// Reverse key derivation: recover spend public key from output key.
/// Returns 32-byte public key as hex string.
#[no_mangle]
pub unsafe extern "C" fn fuego_underive_public_key(
    derivation_ptr: *const u8,
    output_index: u64,
    output_key_ptr: *const u8,
) -> *mut c_char {
    if derivation_ptr.is_null() || output_key_ptr.is_null() {
        return CString::new("").unwrap().into_raw();
    }
    let deriv_bytes = slice::from_raw_parts(derivation_ptr, 32);
    let ok_bytes = slice::from_raw_parts(output_key_ptr, 32);
    let mut derivation = [0u8; 32];
    let mut output_key = [0u8; 32];
    derivation.copy_from_slice(deriv_bytes);
    output_key.copy_from_slice(ok_bytes);
    let pk = underive_public_key(&derivation, output_index, &PublicKey(output_key));
    CString::new(hex::encode(pk.0)).unwrap().into_raw()
}

/// Sign a message with a secret key. Returns 64-byte Ed25519 signature as hex.
#[no_mangle]
pub unsafe extern "C" fn fuego_sign(
    secret_ptr: *const u8,
    message_ptr: *const u8,
    message_len: usize,
) -> *mut c_char {
    if secret_ptr.is_null() || message_ptr.is_null() {
        return CString::new("").unwrap().into_raw();
    }
    let sk_bytes = slice::from_raw_parts(secret_ptr, 32);
    let message = slice::from_raw_parts(message_ptr, message_len);
    let mut sk = [0u8; 32];
    sk.copy_from_slice(sk_bytes);
    let kp = Keypair::from_secret(sk);
    let sig = kp.sign(message);
    CString::new(hex::encode(sig.to_bytes())).unwrap().into_raw()
}

/// Verify an Ed25519 signature. Returns 1 if valid, 0 if invalid.
#[no_mangle]
pub unsafe extern "C" fn fuego_verify(
    pubkey_ptr: *const u8,
    message_ptr: *const u8,
    message_len: usize,
    signature_ptr: *const u8,
) -> bool {
    if pubkey_ptr.is_null() || message_ptr.is_null() || signature_ptr.is_null() {
        return false;
    }
    let pk_bytes = slice::from_raw_parts(pubkey_ptr, 32);
    let message = slice::from_raw_parts(message_ptr, message_len);
    let sig_bytes = slice::from_raw_parts(signature_ptr, 64);
    let mut pk = [0u8; 32];
    let mut sig_arr = [0u8; 64];
    pk.copy_from_slice(pk_bytes);
    sig_arr.copy_from_slice(sig_bytes);
    let pk = PublicKey(pk);
    let sig = ed25519_dalek::Signature::from_bytes(&sig_arr);
    pk.verify(message, &sig)
}

/// Base58-encode data (CryptoNote block-based encoding).
#[no_mangle]
pub unsafe extern "C" fn fuego_base58_encode(
    data_ptr: *const u8,
    data_len: usize,
) -> *mut c_char {
    if data_ptr.is_null() {
        return CString::new("").unwrap().into_raw();
    }
    let data = slice::from_raw_parts(data_ptr, data_len);
    let encoded = cn_base58_encode(data);
    CString::new(encoded).unwrap().into_raw()
}

// ── FFI types ──

/// A byte buffer returned to the caller. Free with `fuego_bytes_free`.
#[repr(C)]
pub struct FuegoBytes {
    pub ptr: *mut u8,
    pub len: usize,
}

/// A result type for operations that can fail.
#[repr(C)]
pub struct FuegoResult {
    pub ok: bool,
    pub error: *mut c_char,
}

// ── Library info ──

/// Get library version. Returns a null-terminated C string.
#[no_mangle]
pub extern "C" fn fuego_version() -> *mut c_char {
    CString::new(env!("CARGO_PKG_VERSION")).unwrap().into_raw()
}
