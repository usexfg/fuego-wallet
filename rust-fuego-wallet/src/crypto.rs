use bip39::Mnemonic;
use ed25519_dalek::{SigningKey, VerifyingKey, Signature, Signer, Verifier, SecretKey};
use rand::rngs::OsRng;
use rand::RngCore;
use sha2::{Sha512, Digest as Sha2Digest};
use sha3::{Digest, Keccak256};

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

    let mut hasher = Sha512::new();
    hasher.update(spend_key_bytes);
    hasher.update(b"view_key");
    let view_hash = hasher.finalize();
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

    let mut hasher = Sha512::new();
    hasher.update(key_bytes);
    hasher.update(b"view_key");
    let view_hash = hasher.finalize();
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
    let tag: u64 = if prefix == "fire" { 1753191 } else { 1075740 };

    let mut buf = write_varint(tag);
    buf.extend_from_slice(spend_pub);
    buf.extend_from_slice(view_pub);

    let hash = cn_fast_hash(&buf);
    buf.extend_from_slice(&hash[..4]);

    let encoded = crate::base58::encode(&buf);
    format!("{}{}", prefix, encoded)
}

pub fn validate_address(address: &str, prefix: &str) -> bool {
    if !address.starts_with(prefix) {
        return false;
    }
    let base58_part = &address[prefix.len()..];
    let decoded = match crate::base58::decode(base58_part) {
        Some(v) => v,
        None => return false,
    };
    if decoded.len() < 5 {
        return false;
    }

    let (data, received_cs) = decoded.split_at(decoded.len() - 4);
    let hash = cn_fast_hash(data);
    let valid = received_cs == &hash[..4];

    let (_tag, _read) = match read_varint(data) {
        Some(t) => t,
        None => return false,
    };

    valid
}

pub const KEY_SIZE: usize = 32;

pub fn keypair_from_spend_key(spend_priv: &[u8; 32]) -> KeyPair {
    let spend_secret = SigningKey::from_bytes(&SecretKey::from(*spend_priv));
    let spend_public = spend_secret.verifying_key();
    let mut hasher = Sha512::new();
    hasher.update(spend_priv);
    hasher.update(b"view_key");
    let view_hash = hasher.finalize();
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
        eprintln!("address: {} ({} chars)", addr, addr.len());
        assert!(validate_address(&addr, "fire"));
        assert!(!validate_address(&addr, "TEST"));
        let addr_t = generate_address(kp.spend_public.as_bytes(), kp.view_public.as_bytes(), "TEST");
        eprintln!("testnet: {} ({} chars)", addr_t, addr_t.len());
        assert!(validate_address(&addr_t, "TEST"));
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
