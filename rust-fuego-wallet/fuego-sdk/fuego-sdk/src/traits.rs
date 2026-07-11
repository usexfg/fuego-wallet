use crate::error::Result;
use crate::types::*;
use async_trait::async_trait;

/// Network provider trait — implemented by P2P, I2P, RPC, or Mock
#[async_trait]
pub trait NetworkProvider: Send + Sync {
    /// Get current blockchain height
    async fn get_height(&self) -> Result<u64>;

    /// Fetch block header at height
    async fn get_header(&self, height: u64) -> Result<BlockHeader>;

    /// Fetch full block
    async fn get_block(&self, height: u64) -> Result<Block>;

    /// Broadcast transaction
    async fn send_transaction(&self, tx: &Transaction) -> Result<[u8; 32]>;

    /// Get peers list
    async fn get_peers(&self) -> Result<Vec<PeerInfo>>;

    /// Get transaction by hash
    async fn get_transaction(&self, hash: &[u8; 32]) -> Result<Option<Transaction>>;
}

/// Peer information
#[derive(Debug, Clone)]
pub struct PeerInfo {
    pub id: String,
    pub address: String,
    pub version: u32,
    pub height: u64,
    pub last_seen: u64,
}

/// Storage provider trait — implemented by Memory, Sled, RocksDB, etc.
pub trait StorageProvider: Send + Sync {
    fn get_block(&self, height: u64) -> Result<Option<Block>>;
    fn save_block(&self, block: &Block) -> Result<()>;
    fn get_utxo(&self, tx_hash: &[u8; 32], index: u32) -> Result<Option<Utxo>>;
    fn save_utxo(&self, utxo: &Utxo) -> Result<()>;
    fn delete_utxo(&self, tx_hash: &[u8; 32], index: u32) -> Result<()>;
    fn get_height(&self) -> Result<u64>;
    fn save_height(&self, height: u64) -> Result<()>;
    fn get(&self, key: &[u8]) -> Result<Option<Vec<u8>>>;
    fn put(&self, key: &[u8], value: &[u8]) -> Result<()>;
    fn delete(&self, key: &[u8]) -> Result<()>;
    fn exists(&self, key: &[u8]) -> Result<bool>;
}

/// Block observer trait — for scanning blocks
pub trait BlockObserver: Send + Sync {
    fn on_block(&self, block: &Block) -> Result<()>;
}

/// Event listener for SDK events
pub trait EventListener: Send + Sync {
    fn on_sync_start(&self, _target_height: u64) {}
    fn on_sync_progress(&self, _current: u64, _total: u64) {}
    fn on_sync_complete(&self) {}
    fn on_transaction(&self, _tx: &Transaction) {}
    fn on_block(&self, _block: &BlockHeader) {}
    fn on_error(&self, _error: &crate::error::SdkError) {}
}
