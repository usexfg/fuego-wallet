use aes_gcm::{
    aead::{Aead, KeyInit, OsRng as AeadOsRng},
    Aes256Gcm, Nonce,
};
use argon2::Argon2;
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha2::{Sha256, Digest};
use std::path::PathBuf;
use zeroize::Zeroize;

#[derive(Serialize, Deserialize, Clone, Zeroize)]
pub struct WalletSecrets {
    pub spend_secret_hex: String,
    pub view_secret_hex: String,
    pub spend_public_hex: String,
    pub view_public_hex: String,
    pub address: String,
}

#[derive(Serialize, Deserialize)]
struct KeystoreFile {
    version: u32,
    salt_hex: String,
    nonce_hex: String,
    ciphertext_hex: String,
    checksum_hex: String,
}

pub struct Keystore {
    path: PathBuf,
}

impl Keystore {
    pub fn new(path: PathBuf) -> Self {
        Self { path }
    }

    pub fn exists(&self) -> bool {
        self.path.exists()
    }

    pub fn save(&self, secrets: &WalletSecrets, password: &str) -> Result<(), String> {
        let plaintext = serde_json::to_vec(secrets)
            .map_err(|e| format!("serialize: {}", e))?;

        let mut salt = [0u8; 32];
        let mut nonce_bytes = [0u8; 12];
        AeadOsRng.fill_bytes(&mut salt);
        AeadOsRng.fill_bytes(&mut nonce_bytes);

        let key = derive_key(password, &salt);
        let cipher = Aes256Gcm::new_from_slice(&key)
            .map_err(|e| format!("cipher init: {}", e))?;
        let nonce = Nonce::from_slice(&nonce_bytes);

        let ciphertext = cipher
            .encrypt(nonce, plaintext.as_ref())
            .map_err(|e| format!("encrypt: {}", e))?;

        let mut hasher = Sha256::new();
        hasher.update(&plaintext);
        let checksum = format!("{:x}", hasher.finalize());

        let file = KeystoreFile {
            version: 1,
            salt_hex: hex::encode(salt),
            nonce_hex: hex::encode(nonce_bytes),
            ciphertext_hex: hex::encode(&ciphertext),
            checksum_hex: checksum,
        };

        let json = serde_json::to_string_pretty(&file)
            .map_err(|e| format!("serialize file: {}", e))?;

        std::fs::write(&self.path, json)
            .map_err(|e| format!("write: {}", e))?;

        Ok(())
    }

    pub fn load(&self, password: &str) -> Result<WalletSecrets, String> {
        let data = std::fs::read_to_string(&self.path)
            .map_err(|e| format!("read: {}", e))?;
        let file: KeystoreFile = serde_json::from_str(&data)
            .map_err(|e| format!("parse: {}", e))?;

        let salt = hex::decode(&file.salt_hex)
            .map_err(|e| format!("salt: {}", e))?;
        let nonce_bytes = hex::decode(&file.nonce_hex)
            .map_err(|e| format!("nonce: {}", e))?;
        let ciphertext = hex::decode(&file.ciphertext_hex)
            .map_err(|e| format!("ciphertext: {}", e))?;

        let key = derive_key(password, &salt);
        let cipher = Aes256Gcm::new_from_slice(&key)
            .map_err(|e| format!("cipher init: {}", e))?;
        let nonce = Nonce::from_slice(&nonce_bytes);

        let plaintext = cipher
            .decrypt(nonce, ciphertext.as_ref())
            .map_err(|_| "decrypt failed: wrong password?".to_string())?;

        let mut hasher = Sha256::new();
        hasher.update(&plaintext);
        let checksum = format!("{:x}", hasher.finalize());
        if checksum != file.checksum_hex {
            return Err("checksum mismatch: corrupted keystore".to_string());
        }

        let secrets: WalletSecrets = serde_json::from_slice(&plaintext)
            .map_err(|e| format!("deserialize: {}", e))?;

        Ok(secrets)
    }
}

fn derive_key(password: &str, salt: &[u8]) -> [u8; 32] {
    let mut key = [0u8; 32];
    Argon2::default().hash_password_into(password.as_bytes(), salt, &mut key)
        .expect("argon2 key derivation");
    key
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use tempfile::tempdir;

    #[test]
    fn test_keystore_save_load() {
        let dir = tempdir().unwrap();
        let path: PathBuf = dir.path().join("test.keystore");
        let ks = Keystore::new(path);

        let secrets = WalletSecrets {
            spend_secret_hex: hex::encode([0xAAu8; 32]),
            view_secret_hex: hex::encode([0xBBu8; 32]),
            spend_public_hex: hex::encode([0xCCu8; 32]),
            view_public_hex: hex::encode([0xDDu8; 32]),
            address: "fireTestAddress123".into(),
        };

        ks.save(&secrets, "password123").unwrap();
        assert!(ks.exists());

        let loaded = ks.load("password123").unwrap();
        assert_eq!(loaded.spend_secret_hex, secrets.spend_secret_hex);
        assert_eq!(loaded.address, secrets.address);
    }

    #[test]
    fn test_keystore_wrong_password() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("test.keystore");
        let ks = Keystore::new(path);

        let secrets = WalletSecrets {
            spend_secret_hex: hex::encode([0x11u8; 32]),
            view_secret_hex: hex::encode([0x22u8; 32]),
            spend_public_hex: hex::encode([0x33u8; 32]),
            view_public_hex: hex::encode([0x44u8; 32]),
            address: "test".into(),
        };

        ks.save(&secrets, "correct").unwrap();
        assert!(ks.load("wrong").is_err());
    }
}
