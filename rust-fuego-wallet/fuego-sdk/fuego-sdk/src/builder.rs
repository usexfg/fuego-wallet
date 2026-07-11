use crate::error::Result;
use crate::network::RpcProvider;
use crate::node::EmbeddedNode;
use crate::traits::{NetworkProvider, StorageProvider};
use crate::types::*;
use std::sync::Arc;

// ============================================================
// Node builder
// ============================================================

pub struct SdkBuilder {
    config: NodeConfig,
    network: Option<Arc<dyn NetworkProvider>>,
    storage: Option<Arc<dyn StorageProvider>>,
}

impl SdkBuilder {
    pub fn new() -> Self {
        Self {
            config: NodeConfig::default(),
            network: None,
            storage: None,
        }
    }

    pub fn data_dir(mut self, path: impl Into<String>) -> Self {
        self.config.data_dir = path.into();
        self
    }

    pub fn network_type(mut self, network: NetworkType) -> Self {
        self.config.network = network;
        self
    }

    pub fn max_peers(mut self, max: usize) -> Self {
        self.config.max_peers = max;
        self
    }

    pub fn sync_interval(mut self, secs: u64) -> Self {
        self.config.sync_interval_secs = secs;
        self
    }

    pub fn enable_seeding(mut self, enable: bool) -> Self {
        self.config.enable_seeding = enable;
        self
    }

    pub fn rpc(mut self, host: impl Into<String>, port: u16) -> Self {
        self.network = Some(Arc::new(RpcProvider::new(host, port)));
        self
    }

    pub fn with_network(mut self, network: Arc<dyn NetworkProvider>) -> Self {
        self.network = Some(network);
        self
    }

    pub fn with_storage(mut self, storage: Arc<dyn StorageProvider>) -> Self {
        self.storage = Some(storage);
        self
    }

    pub fn build(self) -> Result<EmbeddedNode> {
        let mut node = match self.storage {
            Some(storage) => EmbeddedNode::with_storage(self.config, storage)?,
            None => EmbeddedNode::new(self.config)?,
        };

        if let Some(network) = self.network {
            node.set_network(network);
        }

        Ok(node)
    }
}

impl Default for SdkBuilder {
    fn default() -> Self {
        Self::new()
    }
}

// ============================================================
// Wallet builder
// ============================================================

pub struct WalletBuilder {
    seed: Option<[u8; 32]>,
    data_dir: Option<std::path::PathBuf>,
    passphrase: Option<Vec<u8>>,
}

impl WalletBuilder {
    pub fn new() -> Self {
        Self {
            seed: None,
            data_dir: None,
            passphrase: None,
        }
    }

    pub fn seed(mut self, seed: [u8; 32]) -> Self {
        self.seed = Some(seed);
        self
    }

    pub fn data_dir(mut self, path: impl Into<std::path::PathBuf>) -> Self {
        self.data_dir = Some(path.into());
        self
    }

    pub fn passphrase(mut self, passphrase: impl Into<Vec<u8>>) -> Self {
        self.passphrase = Some(passphrase.into());
        self
    }

    pub fn build(self) -> Result<crate::wallet::Wallet> {
        let vault = match self.seed {
            Some(seed) => crate::vault::WalletVault::from_seed(seed),
            None => crate::vault::WalletVault::generate(),
        };

        if let (Some(path), Some(passphrase)) = (&self.data_dir, &self.passphrase) {
            vault.save(path.clone(), passphrase)?;
        }

        Ok(crate::wallet::Wallet::from_vault(vault))
    }

    pub fn load(self) -> Result<crate::wallet::Wallet> {
        let path = self
            .data_dir
            .ok_or_else(|| crate::error::SdkError::Storage("No data_dir set for load".into()))?;
        let passphrase = self
            .passphrase
            .ok_or_else(|| crate::error::SdkError::Storage("No passphrase set for load".into()))?;
        crate::wallet::Wallet::load(path, &passphrase)
    }
}

impl Default for WalletBuilder {
    fn default() -> Self {
        Self::new()
    }
}
