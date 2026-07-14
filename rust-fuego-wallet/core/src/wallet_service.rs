use fuego_sdk::*;
use std::sync::Arc;
use tokio::sync::Mutex;

pub struct WalletService {
    pub wallet: Arc<Mutex<Wallet>>,
    pub node: Arc<Mutex<EmbeddedNode>>,
}

struct WalletObserver {
    wallet: Arc<Mutex<Wallet>>,
}

impl BlockObserver for WalletObserver {
    fn on_block(&self, block: &Block) -> Result<()> {
        if let Ok(wallet) = self.wallet.try_lock() {
            wallet.scan_block(block)?;
        }
        Ok(())
    }
}

impl WalletService {
    pub fn new(seed: [u8; 32], daemon_host: &str, daemon_port: u16) -> Result<Self> {
        let wallet = Arc::new(Mutex::new(Wallet::from_seed(seed)?));

        let builder = SdkBuilder::new()
            .rpc(daemon_host, daemon_port);
        let mut node = builder.build()?;

        let observer = Arc::new(WalletObserver { wallet: wallet.clone() });
        node.add_observer(observer);

        let node = Arc::new(Mutex::new(node));

        Ok(Self { wallet, node })
    }

    pub async fn address(&self) -> String {
        self.wallet.lock().await.primary_address().to_string()
    }

    pub async fn balance(&self) -> u64 {
        self.wallet.lock().await.balance().confirmed
    }

    pub async fn height(&self) -> u64 {
        self.wallet.lock().await.height()
    }

    pub async fn balance_full(&self) -> Balance {
        self.wallet.lock().await.balance()
    }

    pub fn sync_status(&self) -> SyncStatus {
        match self.node.try_lock() {
            Ok(node) => {
                // sync_status() on the node should return current status
                // We approximate from the node's internal state
                let status = node.sync_status();
                status
            }
            Err(_) => SyncStatus {
                current_height: 0,
                target_height: 0,
                is_syncing: false,
                last_sync_time: None,
            }
        }
    }

    pub async fn start_sync(&self) -> Result<()> {
        let target = {
            let node = self.node.lock().await;
            node.network().get_height().await?
        };
        let node = self.node.lock().await;
        node.sync(Some(target)).await
    }

    pub async fn get_transactions(&self, limit: usize) -> Vec<Transaction> {
        self.wallet.lock().await.get_transactions(limit)
    }

    pub async fn get_keypair(&self, index: u32) -> Keypair {
        self.wallet.lock().await.get_keypair(index)
    }

    pub async fn send_to_address(&self, to: &str, amount: u64, fee: u64) -> Result<[u8; 32]> {
        let address = fuego_sdk::Address::new(to);
        let tx = self.wallet.lock().await.build_transaction(&address, amount, fee)?;
        let network = {
            let node = self.node.lock().await;
            node.network().clone()
        };
        let tx_hash = network.send_transaction(&tx).await?;
        Ok(tx_hash)
    }

    pub async fn register_alias(&self, alias: &str, fee: u64) -> Result<[u8; 32]> {
        let tx = self.wallet.lock().await.build_alias_transaction(alias, fee)?;
        let network = {
            let node = self.node.lock().await;
            node.network().clone()
        };
        let tx_hash = network.send_transaction(&tx).await?;
        Ok(tx_hash)
    }

    pub async fn create_cd(&self, _amount: u64, _duration_blocks: u64) -> Result<[u8; 32]> {
        Err(SdkError::Vault("CD creation not yet implemented in SDK".into()))
    }

    pub async fn claim_cd(&self, _cd_id: &str) -> Result<[u8; 32]> {
        Err(SdkError::Vault("CD claim not yet implemented in SDK".into()))
    }

    pub async fn list_cds(&self) -> Vec<String> {
        Vec::new()
    }
}
