use crate::error::{Result, SdkError};
use crate::traits::{NetworkProvider, PeerInfo};
use crate::types::*;
use async_trait::async_trait;

pub struct NullNetwork;

#[async_trait]
impl NetworkProvider for NullNetwork {
    async fn get_height(&self) -> Result<u64> {
        Ok(0)
    }

    async fn get_header(&self, _height: u64) -> Result<BlockHeader> {
        Err(SdkError::Network("No network configured".into()))
    }

    async fn get_block(&self, _height: u64) -> Result<Block> {
        Err(SdkError::Network("No network configured".into()))
    }

    async fn send_transaction(&self, _tx: &Transaction) -> Result<[u8; 32]> {
        Err(SdkError::Network("No network configured".into()))
    }

    async fn get_peers(&self) -> Result<Vec<PeerInfo>> {
        Ok(Vec::new())
    }

    async fn get_transaction(&self, _hash: &[u8; 32]) -> Result<Option<Transaction>> {
        Ok(None)
    }
}
