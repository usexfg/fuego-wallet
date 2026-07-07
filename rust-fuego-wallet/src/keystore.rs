use rand::rngs::OsRng;
use rand::RngCore;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use zeroize::Zeroize;

const SERVICE: &str = "fuego-wallet-keystore";
const ACCOUNT: &str = "fuego-wallet";

#[derive(Serialize, Deserialize, Clone, Zeroize)]
pub struct WalletSecrets {
    pub spend_secret_hex: String,
    pub view_secret_hex: String,
    pub spend_public_hex: String,
    pub view_public_hex: String,
    pub address: String,
}

pub struct Keystore {
    path: PathBuf,
}

impl Keystore {
    pub fn new(path: PathBuf) -> Self { Self { path } }

    pub fn exists(&self) -> bool { self.path.exists() }

    fn get_key(&self) -> Result<[u8; 32], String> {
        // Try macOS keychain
        if let Ok(entry) = keyring::Entry::new(SERVICE, ACCOUNT) {
            if let Ok(hex_key) = entry.get_password() {
                let bytes: Vec<u8> = hex_key.chars()
                    .collect::<Vec<char>>()
                    .chunks(2)
                    .map(|c| u8::from_str_radix(&c.iter().collect::<String>(), 16))
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(|e| format!("hex: {}", e))?;
                if bytes.len() == 32 {
                    let mut key = [0u8; 32];
                    key.copy_from_slice(&bytes);
                    return Ok(key);
                }
            }
        }
        // Fallback: file-based key
        let key_path = self.path.with_extension("key");
        if key_path.exists() {
            let s = std::fs::read_to_string(&key_path).map_err(|e| format!("read: {}", e))?;
            return hex::decode(s.trim()).map_err(|e| format!("decode: {}", e))
                .and_then(|b| b.try_into().map_err(|_| "bad length".into()));
        }
        Err("no key".into())
    }

    fn ensure_key(&self) -> Result<[u8; 32], String> {
        if let Ok(key) = self.get_key() { return Ok(key); }
        let mut key = [0u8; 32];
        OsRng.fill_bytes(&mut key);
        let hex_key = hex::encode(key);
        let key_path = self.path.with_extension("key");
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::write(&key_path, &hex_key).map_err(|e| format!("write: {}", e))?;
            std::fs::set_permissions(&key_path, std::fs::Permissions::from_mode(0o600))
                .map_err(|e| format!("perms: {}", e))?;
        }
        #[cfg(not(unix))]
        {
            std::fs::write(&key_path, &hex_key).map_err(|e| format!("write: {}", e))?;
        }
        // Also try keychain
        if let Ok(entry) = keyring::Entry::new(SERVICE, ACCOUNT) {
            let _ = entry.set_password(&hex_key);
        }
        Ok(key)
    }

    fn encrypt(data: &[u8], key: &[u8; 32]) -> Vec<u8> {
        data.iter().enumerate().map(|(i, b)| b ^ key[i % 32]).collect()
    }

    fn decrypt(data: &[u8], key: &[u8; 32]) -> Vec<u8> {
        Self::encrypt(data, key) // XOR is symmetric
    }

    pub fn save(&self, secrets: &WalletSecrets) -> Result<(), String> {
        let plaintext = serde_json::to_vec(secrets).map_err(|e| format!("json: {}", e))?;
        let key = self.ensure_key()?;
        let ct = Self::encrypt(&plaintext, &key);
        std::fs::write(&self.path, hex::encode(&ct))
            .map_err(|e| format!("write: {}", e))?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = std::fs::set_permissions(&self.path, std::fs::Permissions::from_mode(0o600));
        }
        Ok(())
    }

    pub fn load(&self) -> Result<WalletSecrets, String> {
        let hex_data = std::fs::read_to_string(&self.path).map_err(|e| format!("read: {}", e))?;
        let ct = hex::decode(hex_data.trim()).map_err(|e| format!("decode: {}", e))?;
        let key = self.get_key()?;
        let pt = Self::decrypt(&ct, &key);
        serde_json::from_slice(&pt).map_err(|e| format!("deserialize: {}", e))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_save_load() {
        let dir = tempdir().unwrap();
        let ks = Keystore::new(dir.path().join("test.keystore"));
        let secrets = WalletSecrets {
            spend_secret_hex: hex::encode([0xAAu8; 32]),
            view_secret_hex: hex::encode([0xBBu8; 32]),
            spend_public_hex: hex::encode([0xCCu8; 32]),
            view_public_hex: hex::encode([0xDDu8; 32]),
            address: "fireTestAddress123".into(),
        };
        ks.save(&secrets).unwrap();
        assert!(ks.exists());
        let loaded = ks.load().unwrap();
        assert_eq!(loaded.spend_secret_hex, secrets.spend_secret_hex);
    }
}
