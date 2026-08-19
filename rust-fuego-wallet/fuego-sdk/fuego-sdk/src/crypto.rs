use crate::types::*;
use fuego_crypto as fc;

/// Generate random keypair
pub fn generate_keypair() -> Keypair {
    let kp = fc::Keypair::generate();
    Keypair {
        secret: SecretKey(kp.secret),
        public: PublicKey(kp.public),
    }
}

/// Create keypair from secret
pub fn keypair_from_secret(secret: [u8; 32]) -> Keypair {
    let kp = fc::Keypair::from_secret(secret);
    Keypair {
        secret: SecretKey(kp.secret),
        public: PublicKey(kp.public),
    }
}

/// Derive address from spend and view public keys
pub fn make_address(spend_pub: &PublicKey, view_pub: &PublicKey) -> Address {
    let addr = fc::make_address(&spend_pub.0, &view_pub.0);
    Address(addr.0)
}

/// Validate address format
pub fn is_valid_address(address: &str) -> bool {
    fc::is_valid_address(address)
}

/// Generate key derivation (CryptoNote)
pub fn generate_key_derivation(view_pub: &PublicKey, spend_secret: &SecretKey) -> Option<[u8; 32]> {
    let pk = fc::PublicKey(view_pub.0);
    fc::generate_key_derivation(&pk, &spend_secret.0)
}

/// Derive a one-time output key: P = Hs(D || varint(i)) * G + base.
pub fn derive_public_key(derivation: &[u8; 32], index: u64, base: &PublicKey) -> Option<PublicKey> {
    fc::derive_public_key(derivation, index, &base.0).map(|p| PublicKey(p.0))
}

/// Underive public key (recover sender).
pub fn underive_public_key(derivation: &[u8; 32], index: u64, output_key: &PublicKey) -> Option<PublicKey> {
    let out = fc::PublicKey(output_key.0);
    fc::underive_public_key(derivation, index, &out).map(|p| PublicKey(p.0))
}

/// Generate key image for ring signatures
pub fn generate_key_image(pub_key: &PublicKey, secret: &SecretKey) -> PublicKey {
    let pk = fc::PublicKey(pub_key.0);
    PublicKey(fc::generate_key_image(&pk, &secret.0).0)
}

/// Sign message — CryptoNote `generate_signature` over `cn_fast_hash(message)`,
/// consistent with the CryptoNote keypairs produced by [Keypair::from_secret].
/// (ed25519_dalek signing would key from a clamped SHA-512 scalar and can
/// never verify under the CryptoNote public key.)
pub fn sign(keypair: &Keypair, message: &[u8]) -> Vec<u8> {
    let prefix_hash = fc::cn_fast_hash(message);
    let mut rng = rand::thread_rng();
    match fc::generate_signature(&prefix_hash, &keypair.public.0, &keypair.secret.0, &mut rng) {
        Some(sig) => sig.to_vec(),
        None => Vec::new(),
    }
}

/// Verify signature — CryptoNote `check_signature` over
/// `cn_fast_hash(message)`.
pub fn verify(pub_key: &PublicKey, message: &[u8], signature: &[u8]) -> bool {
    let sig_bytes: [u8; 64] = match signature.try_into() {
        Ok(b) => b,
        Err(_) => return false,
    };
    let prefix_hash = fc::cn_fast_hash(message);
    fc::check_signature(&prefix_hash, &pub_key.0, &sig_bytes)
}

/// Compute hash
pub fn hash(data: &[u8]) -> [u8; 32] {
    use sha3::{Digest, Keccak256};
    let hash = Keccak256::digest(data);
    let mut result = [0u8; 32];
    result.copy_from_slice(&hash);
    result
}

/// Compute transaction hash
pub fn hash_transaction(tx: &Transaction) -> [u8; 32] {
    let data = bincode::serialize(tx).unwrap_or_default();
    hash(&data)
}
