use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;

use crate::crypto::{self, KeyPair, generate_address};
use crate::daemon::DaemonClient;
use crate::keystore::{Keystore, WalletSecrets};

pub struct WalletState {
    pub keystore: Keystore,
    keypair: Option<KeyPair>,
    secrets: Option<WalletSecrets>,
    daemon: DaemonClient,
    txs: Arc<RwLock<Vec<WalletTx>>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BalanceResult {
    pub available_balance: u64,
    pub locked_amount: u64,
    pub block_count: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AddressResult {
    pub address: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WalletTx {
    pub transaction_hash: String,
    pub amount: i64,
    pub fee: u64,
    pub payment_id: String,
    pub block_index: u64,
    pub timestamp: i64,
    pub confirmations: u64,
    pub transfers: Vec<TransferEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransferEntry {
    pub address: String,
    pub amount: i64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TransactionsResult {
    pub items: Vec<BlockTransactions>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BlockTransactions {
    pub block_index: u64,
    pub block_hash: String,
    pub transactions: Vec<WalletTx>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SendTxRequest {
    pub destinations: Vec<SendDestination>,
    pub fee: u64,
    pub anonymity: u32,
    pub payment_id: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SendDestination {
    pub amount: u64,
    pub address: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SendTxResult {
    pub transaction_hash: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct IntegratedAddressResult {
    pub integrated_address: String,
}

impl WalletState {
    pub fn new(keystore: Keystore, daemon: DaemonClient) -> Self {
        Self {
            keystore,
            keypair: None,
            secrets: None,
            daemon,
            txs: Arc::new(RwLock::new(Vec::new())),
        }
    }

    pub fn is_unlocked(&self) -> bool {
        self.keypair.is_some()
    }

    pub fn address(&self) -> Option<String> {
        self.secrets.as_ref().map(|s| s.address.clone())
    }

    pub fn create(&mut self) -> Result<(String, WalletSecrets), String> {
        let kp = crypto::generate_keypair();
        let address = generate_address(
            kp.spend_public.as_bytes(),
            kp.view_public.as_bytes(),
            "fire",
        );
        let mnemonic = crypto::keypair_to_mnemonic(&kp);

        let secrets = WalletSecrets {
            spend_secret_hex: hex::encode(kp.spend_secret.as_bytes()),
            view_secret_hex: hex::encode(kp.view_secret.as_bytes()),
            spend_public_hex: hex::encode(kp.spend_public.as_bytes()),
            view_public_hex: hex::encode(kp.view_public.as_bytes()),
            address: address.clone(),
        };

        self.keystore.save(&secrets)?;
        self.keypair = Some(kp);
        self.secrets = Some(secrets.clone());

        Ok((mnemonic, secrets))
    }

    pub fn create_testnet(&mut self) -> Result<(String, WalletSecrets), String> {
        let kp = crypto::generate_keypair();
        let address = generate_address(
            kp.spend_public.as_bytes(),
            kp.view_public.as_bytes(),
            "TEST",
        );
        let mnemonic = crypto::keypair_to_mnemonic(&kp);

        let secrets = WalletSecrets {
            spend_secret_hex: hex::encode(kp.spend_secret.as_bytes()),
            view_secret_hex: hex::encode(kp.view_secret.as_bytes()),
            spend_public_hex: hex::encode(kp.spend_public.as_bytes()),
            view_public_hex: hex::encode(kp.view_public.as_bytes()),
            address,
        };

        self.keystore.save(&secrets)?;
        self.keypair = Some(kp);
        self.secrets = Some(secrets.clone());

        Ok((mnemonic, secrets))
    }

    pub fn open(&mut self) -> Result<WalletSecrets, String> {
        let secrets = self.keystore.load()?;

        let spend_priv: Vec<u8> = hex::decode(&secrets.spend_secret_hex)
            .map_err(|e| format!("hex decode spend_priv: {}", e))?;
        let spend_priv_arr: [u8; 32] = spend_priv.try_into()
            .map_err(|_| "invalid spend key length".to_string())?;

        let kp = crypto::keypair_from_spend_key(&spend_priv_arr);
        self.keypair = Some(kp);
        self.secrets = Some(secrets.clone());

        Ok(secrets)
    }

    pub async fn get_balance(&self) -> Result<BalanceResult, String> {
        if !self.is_unlocked() {
            return Err("wallet locked".into());
        }
        let info = self.daemon.get_info().await?;
        Ok(BalanceResult {
            available_balance: 0,
            locked_amount: 0,
            block_count: info.height,
        })
    }

    pub async fn get_addresses(&self) -> Result<AddressResult, String> {
        let addr = self.address().ok_or("wallet locked")?;
        Ok(AddressResult { address: addr })
    }

    pub async fn get_transactions(&self, _block_count: u64, _first_block_index: u64) -> Result<TransactionsResult, String> {
        Ok(TransactionsResult { items: vec![] })
    }

    pub async fn send_transaction(&self, req: &SendTxRequest) -> Result<SendTxResult, String> {
        if !self.is_unlocked() {
            return Err("wallet locked".into());
        }
        for dest in &req.destinations {
            let addr_ok = crypto::validate_address(&dest.address, "fire")
                || crypto::validate_address(&dest.address, "TEST");
            if !addr_ok {
                return Err(format!("invalid address: {}", dest.address));
            }
        }
        Err("send_transaction not yet implemented — needs UTXO query from fuegod".into())
    }

    pub fn create_integrated(&self, payment_id: &str) -> Result<IntegratedAddressResult, String> {
        let addr = self.address().ok_or("wallet locked")?;
        if payment_id.len() != 64 {
            return Err("payment_id must be 64 hex characters".into());
        }
        let integrated = format!("{}.{}", addr, payment_id);
        Ok(IntegratedAddressResult { integrated_address: integrated })
    }

    pub async fn wallet_status(&self) -> Result<serde_json::Value, String> {
        let info = self.daemon.get_info().await?;
        Ok(serde_json::json!({
            "wallet_unlocked": self.is_unlocked(),
            "height": info.height,
            "top_block_hash": info.top_block_hash,
            "difficulty": info.difficulty,
            "hashrate": 0,
            "incoming_connections_count": info.incoming_connections_count,
            "outgoing_connections_count": info.outgoing_connections_count,
            "tx_count": info.tx_count,
            "tx_pool_size": info.tx_pool_size,
            "daemon_status": info.status,
            "daemon_version": info.version,
        }))
    }
}
