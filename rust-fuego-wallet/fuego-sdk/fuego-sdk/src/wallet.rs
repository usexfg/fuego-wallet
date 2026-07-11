use crate::error::{Result, SdkError};
use crate::scanner::UtxoScanner;
use crate::types::*;
use crate::vault::WalletVault;
use std::path::PathBuf;

pub struct Wallet {
    pub(crate) scanner: UtxoScanner,
}

impl Wallet {
    pub fn generate() -> Result<Self> {
        Ok(Self {
            scanner: UtxoScanner::new(WalletVault::generate()),
        })
    }

    pub fn from_seed(seed: [u8; 32]) -> Result<Self> {
        Ok(Self {
            scanner: UtxoScanner::new(WalletVault::from_seed(seed)),
        })
    }

    pub(crate) fn from_vault(vault: WalletVault) -> Self {
        Self {
            scanner: UtxoScanner::new(vault),
        }
    }

    pub fn load(path: PathBuf, passphrase: &[u8]) -> Result<Self> {
        let vault = WalletVault::load(path, passphrase)?;
        Ok(Self {
            scanner: UtxoScanner::new(vault),
        })
    }

    pub fn save(&self, path: PathBuf, passphrase: &[u8]) -> Result<()> {
        self.scanner.vault().save(path, passphrase)
    }

    pub fn primary_address(&self) -> Address {
        self.get_address(0)
    }

    pub fn get_address(&self, index: u32) -> Address {
        let addr = self.scanner.vault().get_address(index);
        Address(addr.0)
    }

    pub fn get_keypair(&self, index: u32) -> Keypair {
        let kp = self.scanner.vault().derive_keypair(index);
        Keypair {
            secret: SecretKey(kp.secret),
            public: PublicKey(kp.public),
        }
    }

    pub fn balance(&self) -> Balance {
        self.scanner.balance()
    }

    pub fn height(&self) -> u64 {
        self.scanner.height()
    }

    pub fn scan_block(&self, block: &Block) -> Result<Vec<Transaction>> {
        self.scanner.scan_block(block)
    }

    pub fn build_transaction(&self, to: &Address, amount: u64, fee: u64) -> Result<Transaction> {
        self.scanner.build_transaction(to, amount, fee)
    }

    pub fn get_transactions(&self, limit: usize) -> Vec<Transaction> {
        self.scanner.transaction_history(limit)
    }

    pub fn add_guardian(&self, _address: Address) -> Result<()> {
        Err(SdkError::Vault(
            "Use vault_mut().add_guardian() for guardian management".into(),
        ))
    }

    pub fn vault(&self) -> &WalletVault {
        self.scanner.vault()
    }

    pub fn vault_mut(&mut self) -> &mut WalletVault {
        self.scanner.vault_mut()
    }
}
