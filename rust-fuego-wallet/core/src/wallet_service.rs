use fuego_sdk::*;
use std::sync::Arc;
use tokio::sync::Mutex;

pub struct WalletService {
    pub wallet: Arc<Mutex<Wallet>>,
    pub node: EmbeddedNode,
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
        self.node.sync_status()
    }

    pub async fn start_sync(&self) -> Result<()> {
        let target = self.node.network().get_height().await?;
        self.node.sync(Some(target)).await
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
        let network = self.node.network();
        let tx_hash = network.send_transaction(&tx).await?;
        Ok(tx_hash)
    }

    pub async fn register_alias(&self, alias: &str, fee: u64) -> Result<[u8; 32]> {
        let mut wallet = self.wallet.lock().await;
        let tx = wallet.build_alias_transaction(alias, fee)?;
        let network = self.node.network();
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
