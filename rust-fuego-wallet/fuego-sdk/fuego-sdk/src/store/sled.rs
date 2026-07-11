use crate::error::{Result, SdkError};
use crate::traits::StorageProvider;
use crate::types::*;

pub struct SledStore {
    db: sled::Db,
}

impl SledStore {
    pub fn open(path: impl AsRef<std::path::Path>) -> Result<Self> {
        let db = sled::open(path)
            .map_err(|e| SdkError::Storage(format!("Failed to open sled: {}", e)))?;
        Ok(Self { db })
    }
}

impl StorageProvider for SledStore {
    fn get_block(&self, height: u64) -> Result<Option<Block>> {
        let key = height.to_be_bytes();
        match self
            .db
            .get(&key)
            .map_err(|e| SdkError::Storage(e.to_string()))?
        {
            Some(data) => {
                let block: Block = bincode::deserialize(&data)
                    .map_err(|e| SdkError::Serialization(e.to_string()))?;
                Ok(Some(block))
            }
            None => Ok(None),
        }
    }

    fn save_block(&self, block: &Block) -> Result<()> {
        let key = block.header.height.to_be_bytes();
        let data = bincode::serialize(block).map_err(|e| SdkError::Serialization(e.to_string()))?;
        self.db
            .insert(&key, data)
            .map_err(|e| SdkError::Storage(e.to_string()))?;
        Ok(())
    }

    fn get_utxo(&self, tx_hash: &[u8; 32], index: u32) -> Result<Option<Utxo>> {
        let mut key = tx_hash.to_vec();
        key.extend_from_slice(&index.to_be_bytes());
        match self
            .db
            .get(&key)
            .map_err(|e| SdkError::Storage(e.to_string()))?
        {
            Some(data) => {
                let utxo: Utxo = bincode::deserialize(&data)
                    .map_err(|e| SdkError::Serialization(e.to_string()))?;
                Ok(Some(utxo))
            }
            None => Ok(None),
        }
    }

    fn save_utxo(&self, utxo: &Utxo) -> Result<()> {
        let mut key = utxo.tx_hash.to_vec();
        key.extend_from_slice(&utxo.output_index.to_be_bytes());
        let data = bincode::serialize(utxo).map_err(|e| SdkError::Serialization(e.to_string()))?;
        self.db
            .insert(&key, data)
            .map_err(|e| SdkError::Storage(e.to_string()))?;
        Ok(())
    }

    fn delete_utxo(&self, tx_hash: &[u8; 32], index: u32) -> Result<()> {
        let mut key = tx_hash.to_vec();
        key.extend_from_slice(&index.to_be_bytes());
        self.db
            .remove(&key)
            .map_err(|e| SdkError::Storage(e.to_string()))?;
        Ok(())
    }

    fn get_height(&self) -> Result<u64> {
        match self
            .db
            .get(b"height")
            .map_err(|e| SdkError::Storage(e.to_string()))?
        {
            Some(data) => {
                let bytes: [u8; 8] = data
                    .as_ref()
                    .try_into()
                    .map_err(|_| SdkError::Storage("Invalid height".into()))?;
                Ok(u64::from_be_bytes(bytes))
            }
            None => Ok(0),
        }
    }

    fn save_height(&self, height: u64) -> Result<()> {
        self.db
            .insert(b"height", height.to_be_bytes())
            .map_err(|e| SdkError::Storage(e.to_string()))?;
        Ok(())
    }

    fn get(&self, key: &[u8]) -> Result<Option<Vec<u8>>> {
        self.db
            .get(key)
            .map(|v| v.map(|d| d.to_vec()))
            .map_err(|e| SdkError::Storage(e.to_string()))
    }

    fn put(&self, key: &[u8], value: &[u8]) -> Result<()> {
        self.db
            .insert(key, value)
            .map_err(|e| SdkError::Storage(e.to_string()))?;
        Ok(())
    }

    fn delete(&self, key: &[u8]) -> Result<()> {
        self.db
            .remove(key)
            .map_err(|e| SdkError::Storage(e.to_string()))?;
        Ok(())
    }

    fn exists(&self, key: &[u8]) -> Result<bool> {
        self.db
            .contains_key(key)
            .map_err(|e| SdkError::Storage(e.to_string()))
    }
}
