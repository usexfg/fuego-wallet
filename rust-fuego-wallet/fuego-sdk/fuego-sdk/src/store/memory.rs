use crate::error::Result;
use crate::traits::StorageProvider;
use crate::types::*;
use std::collections::HashMap;
use std::sync::RwLock;

pub struct MemoryStore {
    blocks: RwLock<HashMap<u64, Block>>,
    utxos: RwLock<HashMap<(Vec<u8>, u32), Utxo>>,
    kv: RwLock<HashMap<Vec<u8>, Vec<u8>>>,
    height: RwLock<u64>,
}

impl Default for MemoryStore {
    fn default() -> Self {
        Self::new()
    }
}

impl MemoryStore {
    pub fn new() -> Self {
        Self {
            blocks: RwLock::new(HashMap::new()),
            utxos: RwLock::new(HashMap::new()),
            kv: RwLock::new(HashMap::new()),
            height: RwLock::new(0),
        }
    }
}

impl StorageProvider for MemoryStore {
    fn get_block(&self, height: u64) -> Result<Option<Block>> {
        Ok(self.blocks.read().unwrap().get(&height).cloned())
    }

    fn save_block(&self, block: &Block) -> Result<()> {
        self.blocks
            .write()
            .unwrap()
            .insert(block.header.height, block.clone());
        Ok(())
    }

    fn get_utxo(&self, tx_hash: &[u8; 32], index: u32) -> Result<Option<Utxo>> {
        Ok(self
            .utxos
            .read()
            .unwrap()
            .get(&(tx_hash.to_vec(), index))
            .cloned())
    }

    fn save_utxo(&self, utxo: &Utxo) -> Result<()> {
        self.utxos
            .write()
            .unwrap()
            .insert((utxo.tx_hash.to_vec(), utxo.output_index), utxo.clone());
        Ok(())
    }

    fn delete_utxo(&self, tx_hash: &[u8; 32], index: u32) -> Result<()> {
        self.utxos
            .write()
            .unwrap()
            .remove(&(tx_hash.to_vec(), index));
        Ok(())
    }

    fn get_height(&self) -> Result<u64> {
        Ok(*self.height.read().unwrap())
    }

    fn save_height(&self, height: u64) -> Result<()> {
        *self.height.write().unwrap() = height;
        Ok(())
    }

    fn get(&self, key: &[u8]) -> Result<Option<Vec<u8>>> {
        Ok(self.kv.read().unwrap().get(key).cloned())
    }

    fn put(&self, key: &[u8], value: &[u8]) -> Result<()> {
        self.kv
            .write()
            .unwrap()
            .insert(key.to_vec(), value.to_vec());
        Ok(())
    }

    fn delete(&self, key: &[u8]) -> Result<()> {
        self.kv.write().unwrap().remove(key);
        Ok(())
    }

    fn exists(&self, key: &[u8]) -> Result<bool> {
        Ok(self.kv.read().unwrap().contains_key(key))
    }
}
