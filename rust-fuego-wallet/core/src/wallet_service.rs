use fuego_sdk::*;
use std::sync::Arc;

pub struct WalletService {
    pub wallet: Arc<Wallet>,
    pub node: EmbeddedNode,
}

struct WalletObserver {
    wallet: Arc<Wallet>,
}

impl BlockObserver for WalletObserver {
    fn on_block(&self, block: &Block) -> Result<()> {
        self.wallet.scan_block(block)?;
        Ok(())
    }
}

impl WalletService {
    pub fn new(seed: [u8; 32], daemon_host: &str, daemon_port: u16) -> Result<Self> {
        let wallet = Arc::new(Wallet::from_seed(seed)?);

        let builder = SdkBuilder::new()
            .rpc(daemon_host, daemon_port);
        let mut node = builder.build()?;

        let observer = Arc::new(WalletObserver { wallet: wallet.clone() });
        node.add_observer(observer);

        Ok(Self { wallet, node })
    }

    pub fn address(&self) -> String {
        self.wallet.primary_address().to_string()
    }

    pub fn balance(&self) -> u64 {
        self.wallet.balance().confirmed
    }

    pub fn height(&self) -> u64 {
        self.wallet.height()
    }

    pub fn balance_full(&self) -> Balance {
        self.wallet.balance()
    }

    pub fn sync_status(&self) -> SyncStatus {
        self.node.sync_status()
    }

    pub async fn start_sync(&self) -> Result<()> {
        let target = self.node.network().get_height().await?;
        self.node.sync(Some(target)).await
    }

    pub fn get_transactions(&self, limit: usize) -> Vec<Transaction> {
        self.wallet.get_transactions(limit)
    }

    pub fn get_keypair(&self, index: u32) -> Keypair {
        self.wallet.get_keypair(index)
    }

    pub async fn send_to_address(&self, to: &str, amount: u64, fee: u64) -> Result<[u8; 32]> {
        let address = fuego_sdk::Address::new(to);
        let tx = self.wallet.build_transaction(&address, amount, fee)?;
        let network = self.node.network();
        let tx_hash = network.send_transaction(&tx).await?;
        Ok(tx_hash)
    }
}
