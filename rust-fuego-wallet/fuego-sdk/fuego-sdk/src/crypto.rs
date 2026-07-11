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

/// Derive public key from derivation
pub fn derive_public_key(derivation: &[u8; 32], index: u64) -> PublicKey {
    PublicKey(fc::derive_public_key(derivation, index).0)
}

/// Underive public key (recover sender)
pub fn underive_public_key(derivation: &[u8; 32], index: u64, output_key: &PublicKey) -> PublicKey {
    let out = fc::PublicKey(output_key.0);
    PublicKey(fc::underive_public_key(derivation, index, &out).0)
}

/// Generate key image for ring signatures
pub fn generate_key_image(pub_key: &PublicKey, secret: &SecretKey) -> PublicKey {
    let pk = fc::PublicKey(pub_key.0);
    PublicKey(fc::generate_key_image(&pk, &secret.0).0)
}

/// Sign message
pub fn sign(keypair: &Keypair, message: &[u8]) -> Vec<u8> {
    let kp = fc::Keypair {
        secret: keypair.secret.0,
        public: keypair.public.0,
    };
    let sig = kp.sign(message);
    sig.to_bytes().to_vec()
}

/// Verify signature
pub fn verify(pub_key: &PublicKey, message: &[u8], signature: &[u8]) -> bool {
    let pk = fc::PublicKey(pub_key.0);
    let sig_bytes: [u8; 64] = match signature.try_into() {
        Ok(b) => b,
        Err(_) => return false,
    };
    let sig = ed25519_dalek::Signature::from_bytes(&sig_bytes);
    pk.verify(message, &sig)
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
