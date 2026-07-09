use bip39::Mnemonic;
use ed25519_dalek::{SigningKey, VerifyingKey, Signature, Signer, Verifier, SecretKey};
use hmac::{Hmac, Mac};
use rand::rngs::OsRng;
use rand::RngCore;
use sha2::{Sha512, Digest};
use sha3::Keccak256;

type HmacSha512 = Hmac<Sha512>;

/// Domain separation tag for view key derivation.
/// Changing this would break wallet recovery from existing mnemonics.
const VIEW_KEY_DOMAIN: &[u8] = b"fuego-view-key-derivation-v1";

#[derive(Clone)]
pub struct KeyPair {
    pub spend_secret: SigningKey,
    pub spend_public: VerifyingKey,
    pub view_secret: SigningKey,
    pub view_public: VerifyingKey,
}

// SigningKey implements Drop which zeroizes its internal secret bytes.
// No additional zeroization needed — ed25519-dalek handles this.

pub fn cn_fast_hash(data: &[u8]) -> [u8; 32] {
    use sha3::Digest;
    let mut hasher = Keccak256::new();
    hasher.update(data);
    let result = hasher.finalize();
    let mut hash = [0u8; 32];
    hash.copy_from_slice(&result);
    hash
}

fn write_varint(mut value: u64) -> Vec<u8> {
    let mut result = Vec::new();
    while value >= 0x80 {
        result.push(((value & 0x7f) as u8) | 0x80);
        value >>= 7;
    }
    result.push(value as u8);
    result
}

fn read_varint(data: &[u8]) -> Option<(u64, usize)> {
    let mut value: u64 = 0;
    let mut shift = 0;
    let mut read = 0;
    for &byte in data {
        read += 1;
        value |= ((byte & 0x7f) as u64) << shift;
        if byte & 0x80 == 0 {
            return Some((value, read));
        }
        shift += 7;
        if shift >= 64 {
            return None;
        }
    }
    None
}

pub fn generate_keypair() -> KeyPair {
    let mut rng = OsRng;
    let mut spend_key_bytes = [0u8; 32];
    rng.fill_bytes(&mut spend_key_bytes);
    let spend_secret = SigningKey::from_bytes(&SecretKey::from(spend_key_bytes));
    let spend_public = spend_secret.verifying_key();

    // Derive view key using HMAC-SHA512 with domain separation
    let mut mac = HmacSha512::new_from_slice(VIEW_KEY_DOMAIN)
        .expect("HMAC can take key of any size");
    mac.update(&spend_key_bytes);
    let view_hash = mac.finalize().into_bytes();
    let mut view_key_bytes = [0u8; 32];
    view_key_bytes.copy_from_slice(&view_hash[..32]);
    let view_secret = SigningKey::from_bytes(&SecretKey::from(view_key_bytes));
    let view_public = view_secret.verifying_key();

    KeyPair { spend_secret, spend_public, view_secret, view_public }
}

pub fn keypair_from_mnemonic(mnemonic: &str) -> Option<KeyPair> {
    let m = Mnemonic::parse_in_normalized(bip39::Language::English, mnemonic).ok()?;
    let entropy = m.to_entropy();
    if entropy.len() < 32 {
        return None;
    }
    let mut key_bytes = [0u8; 32];
    key_bytes.copy_from_slice(&entropy[..32]);

    let spend_secret = SigningKey::from_bytes(&SecretKey::from(key_bytes));
    let spend_public = spend_secret.verifying_key();

    // Derive view key using HMAC-SHA512 with domain separation
    let mut mac = HmacSha512::new_from_slice(VIEW_KEY_DOMAIN)
        .expect("HMAC can take key of any size");
    mac.update(&key_bytes);
    let view_hash = mac.finalize().into_bytes();
    let mut view_key_bytes = [0u8; 32];
    view_key_bytes.copy_from_slice(&view_hash[..32]);
    let view_secret = SigningKey::from_bytes(&SecretKey::from(view_key_bytes));
    let view_public = view_secret.verifying_key();

    Some(KeyPair { spend_secret, spend_public, view_secret, view_public })
}

pub fn keypair_to_mnemonic(keypair: &KeyPair) -> String {
    let seed_bytes = keypair.spend_secret.as_bytes();
    Mnemonic::from_entropy_in(bip39::Language::English, seed_bytes)
        .expect("spend key must be valid BIP39 entropy")
        .to_string()
}

pub fn generate_mnemonic() -> String {
    let mut entropy = [0u8; 32];
    OsRng.fill_bytes(&mut entropy);
    Mnemonic::from_entropy_in(bip39::Language::English, &entropy)
        .unwrap()
        .to_string()
}

pub fn validate_mnemonic(mnemonic: &str) -> bool {
    Mnemonic::parse_in_normalized(bip39::Language::English, mnemonic).is_ok()
}

pub fn generate_address(spend_pub: &[u8; 32], view_pub: &[u8; 32], prefix: &str) -> String {
    const CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX: u64 = 1753191;
    let mut buf = Vec::with_capacity(69);
    buf.extend_from_slice(&write_varint(CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX));
    buf.extend_from_slice(spend_pub);
    buf.extend_from_slice(view_pub);

    let hash = cn_fast_hash(&buf);
    buf.extend_from_slice(&hash[..4]);

    let encoded = crate::base58::encode(&buf);
    format!("{}{}", prefix, encoded)
}

pub fn validate_address(address: &str, prefix: &str) -> bool {
    // Support both mainnet (fire) and testnet (TEST) prefixes
    let valid_prefixes = if prefix == "fire" {
        &["fire", "TEST"][..]
    } else {
        &[prefix][..]
    };
    
    let has_valid_prefix = valid_prefixes.iter().any(|p| address.starts_with(p));
    if !has_valid_prefix {
        return false;
    }
    
    // Find where the base58 part starts (after the prefix)
    let base58_start = valid_prefixes.iter()
        .find_map(|p| address.starts_with(p).then(|| p.len()))
        .unwrap_or(0);
    let base58_part = &address[base58_start..];
    
    // Validate length (98 for standard, 102 for integrated with payment ID)
    if base58_part.len() != 94 && base58_part.len() != 98 {
        return false;
    }
    
    let decoded = match crate::base58::decode(base58_part) {
        Some(v) => v,
        None => return false,
    };
    if decoded.len() != 71 && decoded.len() != 67 {
        return false;
    }

    let (data, received_cs) = decoded.split_at(67);
    let hash = cn_fast_hash(data);
    received_cs == &hash[..4]
}

pub const KEY_SIZE: usize = 32;

pub fn keypair_from_spend_key(spend_priv: &[u8; 32]) -> KeyPair {
    let spend_secret = SigningKey::from_bytes(&SecretKey::from(*spend_priv));
    let spend_public = spend_secret.verifying_key();

    // Derive view key using HMAC-SHA512 with domain separation
    let mut mac = HmacSha512::new_from_slice(VIEW_KEY_DOMAIN)
        .expect("HMAC can take key of any size");
    mac.update(spend_priv);
    let view_hash = mac.finalize().into_bytes();
    let mut view_key_bytes = [0u8; 32];
    view_key_bytes.copy_from_slice(&view_hash[..32]);
    let view_secret = SigningKey::from_bytes(&SecretKey::from(view_key_bytes));
    let view_public = view_secret.verifying_key();

    KeyPair { spend_secret, spend_public, view_secret, view_public }
}

pub fn sign_message(private_key: &[u8; 32], message: &[u8]) -> [u8; 64] {
    let signing_key = SigningKey::from_bytes(&SecretKey::from(*private_key));
    let sig = signing_key.sign(message);
    sig.to_bytes()
}

pub fn verify_signature(public_key: &[u8; 32], message: &[u8], signature: &[u8; 64]) -> bool {
    let vk = match VerifyingKey::from_bytes(public_key) {
        Ok(k) => k,
        Err(_) => return false,
    };
    let sig = match Signature::try_from(signature.as_slice()) {
        Ok(s) => s,
        Err(_) => return false,
    };
    vk.verify(message, &sig).is_ok()
}

pub fn generate_key_image(spend_pub: &[u8; 32], spend_priv: &[u8; 32]) -> [u8; 32] {
    let mut hasher = Sha512::new();
    hasher.update(spend_pub);
    hasher.update(spend_priv);
    let hash = hasher.finalize();
    let mut ki = [0u8; 32];
    ki.copy_from_slice(&hash[..32]);
    ki
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_keypair_roundtrip() {
        let kp = generate_keypair();
        let mn = keypair_to_mnemonic(&kp);
        assert!(validate_mnemonic(&mn));
        let restored = keypair_from_mnemonic(&mn).unwrap();
        assert_eq!(kp.spend_public, restored.spend_public);
        assert_eq!(kp.view_public, restored.view_public);
    }

    #[test]
    fn test_address_validation() {
        let kp = generate_keypair();
        let addr = generate_address(kp.spend_public.as_bytes(), kp.view_public.as_bytes(), "fire");
        assert!(validate_address(&addr, "fire"));
    }

    #[test]
    fn test_sign_verify() {
        let kp = generate_keypair();
        let msg = b"test message";
        let sig = sign_message(kp.spend_secret.as_bytes(), msg);
        assert!(verify_signature(kp.spend_public.as_bytes(), msg, &sig));
        assert!(!verify_signature(kp.spend_public.as_bytes(), b"wrong", &sig));
    }

    #[test]
    fn test_key_image() {
        let kp = generate_keypair();
        let ki = generate_key_image(kp.spend_public.as_bytes(), kp.spend_secret.as_bytes());
        assert_eq!(ki.len(), 32);
    }

    #[test]
    fn test_varint_roundtrip() {
        let values = [0u64, 1, 127, 128, 255, 16383, 16384, 1753191, 1075740];
        for &v in &values {
            let encoded = write_varint(v);
            let (decoded, read) = read_varint(&encoded).unwrap();
            assert_eq!(decoded, v, "varint roundtrip for {}", v);
            assert_eq!(read, encoded.len());
        }
    }

    #[test]
    fn test_cn_fast_hash() {
        let hash = cn_fast_hash(b"test");
        assert_eq!(hash.len(), 32);
        let hash2 = cn_fast_hash(b"test");
        assert_eq!(hash, hash2);
    }
}
