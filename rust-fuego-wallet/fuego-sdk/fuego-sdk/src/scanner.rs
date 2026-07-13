use crate::alias::{add_alias_info_to_extra, AliasInfo};
use crate::error::{Result, SdkError};
use crate::types::*;
use crate::vault::WalletVault;
use std::collections::HashSet;
use std::sync::{Arc, RwLock};

pub struct UtxoScanner {
    vault: WalletVault,
    state: Arc<RwLock<ScannerState>>,
}

struct ScannerState {
    height: u64,
    utxos: Vec<Utxo>,
    tx_history: Vec<Transaction>,
    balance: Balance,
}

impl UtxoScanner {
    pub fn new(vault: WalletVault) -> Self {
        Self {
            vault,
            state: Arc::new(RwLock::new(ScannerState {
                height: 0,
                utxos: Vec::new(),
                tx_history: Vec::new(),
                balance: Balance::default(),
            })),
        }
    }

    pub fn vault(&self) -> &WalletVault {
        &self.vault
    }

    pub fn vault_mut(&mut self) -> &mut WalletVault {
        &mut self.vault
    }

    pub fn height(&self) -> u64 {
        self.state.read().unwrap().height
    }

    pub fn balance(&self) -> Balance {
        self.state.read().unwrap().balance.clone()
    }

    pub fn utxos(&self) -> Vec<Utxo> {
        self.state.read().unwrap().utxos.clone()
    }

    pub fn transaction_history(&self, limit: usize) -> Vec<Transaction> {
        let state = self.state.read().unwrap();
        state.tx_history.iter().rev().take(limit).cloned().collect()
    }

    pub fn scan_block(&self, block: &Block) -> Result<Vec<Transaction>> {
        let mut state = self.state.write().unwrap();
        let mut found = Vec::new();

        // Collect our public keys for matching
        let our_keys: HashSet<[u8; 32]> = (0..100)
            .map(|i| {
                let kp = self.vault.derive_keypair(i);
                kp.public
            })
            .collect();

        for tx in &block.transactions {
            let mut is_ours = false;

            // Check outputs — does any output pubkey belong to us?
            for output in &tx.outputs {
                if our_keys.contains(&output.pubkey) {
                    is_ours = true;
                    let utxo = Utxo {
                        tx_hash: tx.hash,
                        output_index: 0, // simplified
                        amount: output.amount,
                        pubkey: output.pubkey,
                        height: block.header.height,
                    };
                    state.utxos.push(utxo);
                }
            }

            // Check inputs — remove spent UTXOs
            for input in &tx.inputs {
                state.utxos.retain(|u| {
                    !(u.tx_hash == input.prev_tx_hash && u.output_index == input.prev_output_index)
                });
                is_ours = true;
            }

            if is_ours {
                found.push(tx.clone());
            }
        }

        // Update height and recalculate balance
        state.height = block.header.height;
        state.tx_history.extend(found.clone());
        state.balance.confirmed = state.utxos.iter().map(|u| u.amount).sum();

        Ok(found)
    }

    pub fn build_transaction(&self, _to: &Address, amount: u64, fee: u64) -> Result<Transaction> {
        let state = self.state.read().unwrap();
        let total = amount + fee;

        if state.balance.confirmed < total {
            return Err(SdkError::InsufficientFunds {
                need: total,
                have: state.balance.confirmed,
            });
        }

        // Simple greedy UTXO selection
        let mut selected = Vec::new();
        let mut accumulated = 0u64;
        for utxo in &state.utxos {
            selected.push(utxo.clone());
            accumulated += utxo.amount;
            if accumulated >= total {
                break;
            }
        }

        if accumulated < total {
            return Err(SdkError::InsufficientFunds {
                need: total,
                have: accumulated,
            });
        }

        let kp = self.vault.derive_keypair(0);

        // TODO: Derive recipient pubkey from address
        let mut outputs = vec![TxOutput {
            amount,
            pubkey: kp.public,
        }];

        // Change output back to us
        let change = accumulated - total;
        if change > 0 {
            outputs.push(TxOutput {
                amount: change,
                pubkey: kp.public,
            });
        }

        let tx = Transaction {
            hash: [0; 32],
            inputs: selected
                .into_iter()
                .map(|u| TxInput {
                    prev_tx_hash: u.tx_hash,
                    prev_output_index: u.output_index,
                    signature: Vec::new(),
                })
                .collect(),
            outputs,
            extra: Vec::new(),
            fee,
        };

        Ok(tx)
    }

    pub fn build_alias_transaction(
        &mut self,
        alias: &str,
        fee: u64,
    ) -> Result<Transaction> {
        let subaddress = self.vault.new_subaddress();
        let spend_index = 100 + self.vault.subaddress_count() * 2;
        let view_keypair = self.vault.derive_keypair(spend_index + 1);

        let sdk_address = Address(subaddress.0.clone());

        let alias_info = AliasInfo {
            alias: alias.to_string(),
            address: sdk_address.clone(),
            view_key: view_keypair.public_key(),
        };

        let mut tx = self.build_transaction(&sdk_address, 0, fee)?;
        add_alias_info_to_extra(&mut tx.extra, &alias_info);

        Ok(tx)
    }
}

impl Default for UtxoScanner {
    fn default() -> Self {
        Self::new(WalletVault::default())
    }
}
