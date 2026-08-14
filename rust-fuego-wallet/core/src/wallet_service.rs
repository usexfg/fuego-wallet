use crate::daemon::DaemonClient;

use fuego_sdk::*;
use fuego_sdk::serialization::{add_treasury_fund_extra, HEAT_TERM};
use fuego_sdk::transaction_builder::{
    build_commitment_spend_transaction, build_mixed_output_transaction, decompose_change,
    BuildCommitmentDestination, BuildDestination, CommitmentDeposit, DecoyEntry,
    DEFAULT_DUST_THRESHOLD, MINIMUM_FEE,
};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

/// Default ring size when the caller does not specify one (C++ API default
/// mixIn is 4).
const DEFAULT_MIXIN: usize = 4;
/// CryptoNoteConfig.h SWAP_FEE_RATE_BPS / SWAP_FEE_RATE_DIVISOR (AFK taker fee).
const SWAP_FEE_RATE_BPS: u64 = 100;
const SWAP_FEE_RATE_DIVISOR: u64 = 10000;
/// Atomic units per coin (CryptoNoteConfig.h COIN).
const COIN: u64 = 10_000_000;
/// AFK lock fee (WalletLegacy.cpp create_afk_lock).
const AFK_LOCK_FEE: u64 = 1000;
/// CryptoNoteConfig.h DEPOSIT_MIN_TERM / DEPOSIT_MAX_TERM (blocks).
const DEPOSIT_MIN_TERM: u32 = 5400;
const DEPOSIT_MAX_TERM: u32 = 64800;
/// CryptoNoteConfig.h HEAT_MINT_MIN_HEAT (0.1 HEAT).
const HEAT_MINT_MIN_HEAT: u64 = 1_000_000;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AfkLockSecret {
    secret: [u8; 32],
    pre_sig: Vec<u8>,
    amount: u64,
    timeout_hours: u32,
    pair: u8,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct PendingTx {
    tx_hash: [u8; 32],
    key_images: Vec<[u8; 32]>,
    serialized_hex: String,
    created_height: u64,
}

pub struct WalletService {
    pub wallet: Arc<Mutex<Wallet>>,
    pub daemon: DaemonClient,
    db: sled::Db,
    testnet: bool,
}

/// Background sync runner. Shares the wallet and daemon handles with the
/// service but never contends the server-facing mutex: the JSON-RPC handlers
/// stay responsive while sync batches are in flight.
#[derive(Clone)]
pub struct SyncEngine {
    pub wallet: Arc<Mutex<Wallet>>,
    pub daemon: DaemonClient,
    db: sled::Db,
}

const KEY_HEIGHT: &[u8] = b"height";
const KEY_TOP_HASH: &[u8] = b"top_hash";

fn meta_tree(db: &sled::Db) -> sled::Tree {
    db.open_tree("meta").expect("open meta tree")
}

impl WalletService {
    pub fn new(seed: [u8; 32], daemon_url: &str, wallet_dir: PathBuf, testnet: bool) -> Result<Self> {
        let wallet = Arc::new(Mutex::new(Wallet::from_seed(seed)?));
        let daemon = DaemonClient::new(daemon_url);
        let db = sled::open(wallet_dir.join("wallet_state.sled"))
            .map_err(|e| SdkError::Storage(format!("sled open: {e}")))?;

        let service = Self { wallet, daemon, db, testnet };
        service.sync_engine().load_state();
        Ok(service)
    }

    /// The wallet's primary address for the configured network.
    pub fn primary_address_string(&self) -> String {
        let keys = self.wallet.lock().unwrap().wallet_keys();
        let prefix = if self.testnet {
            fuego_crypto::TESTNET_ADDRESS_BASE58_PREFIX
        } else {
            fuego_crypto::ADDRESS_BASE58_PREFIX
        };
        fuego_crypto::make_address_with_prefix(&keys.spend_public, &keys.view_public, prefix).0
    }

    // ------------------------------------------------------------ state

    // ------------------------------------------------------------ sync

    /// One incremental sync round over /queryblockslite.bin. Returns the
    /// number of blocks scanned.
    pub async fn sync_once(&self) -> std::result::Result<u64, String> {
        self.sync_engine().sync_once().await
    }
}

impl SyncEngine {
    fn load_state(&self) {
        let db = &self.db;
        let wallet = self.wallet.lock().unwrap();

        if let Ok(Some(bytes)) = db.get(b"utxos") {
            if let Ok(utxos) = bincode::deserialize::<Vec<fuego_sdk::scanner::UtxoEntry>>(&bytes) {
                let snapshot = fuego_sdk::scanner::ScannerStateSnapshot {
                    height: db
                        .get(KEY_HEIGHT)
                        .ok()
                        .flatten()
                        .and_then(|b| bincode::deserialize::<u64>(&b).ok())
                        .unwrap_or(0),
                    utxos,
                    commitments: db
                        .get(b"commitments")
                        .ok()
                        .flatten()
                        .and_then(|b| bincode::deserialize::<Vec<fuego_sdk::scanner::CommitmentEntry>>(&b).ok())
                        .unwrap_or_default(),
                    spent_images: db
                        .get(b"spent")
                        .ok()
                        .flatten()
                        .and_then(|b| bincode::deserialize::<Vec<[u8; 32]>>(&b).ok())
                        .unwrap_or_default(),
                    history: db
                        .get(b"history")
                        .ok()
                        .flatten()
                        .and_then(|b| bincode::deserialize::<Vec<fuego_sdk::scanner::HistoryEntry>>(&b).ok())
                        .unwrap_or_default(),
                };
                wallet.restore_state(&snapshot);
            }
        }

        // Re-reserve pending sends (persist-before-broadcast: never release
        // these automatically).
        if let Ok(Some(bytes)) = db.get(b"pending") {
            if let Ok(pending) = bincode::deserialize::<Vec<PendingTx>>(&bytes) {
                let images: Vec<[u8; 32]> = pending
                    .iter()
                    .flat_map(|p| p.key_images.clone())
                    .collect();
                wallet.reserve_pending(&images);
            }
        }
    }

    fn persist_state(&self) {
        let wallet = self.wallet.lock().unwrap();
        let snapshot = wallet.snapshot_state();
        let db = &self.db;
        let _ = bincode::serialize(&snapshot.height).ok().and_then(|b| db.insert(KEY_HEIGHT, b).ok());
        let _ = bincode::serialize(&snapshot.utxos).ok().and_then(|b| db.insert(b"utxos", b).ok());
        let _ = bincode::serialize(&snapshot.commitments).ok().and_then(|b| db.insert(b"commitments", b).ok());
        let _ = bincode::serialize(&snapshot.spent_images).ok().and_then(|b| db.insert(b"spent", b).ok());
        let _ = bincode::serialize(&snapshot.history).ok().and_then(|b| db.insert(b"history", b).ok());
        if let Ok(Some(bytes)) = db.get(KEY_TOP_HASH) {
            let _ = db.flush();
            let _ = bytes;
        } else {
            let _ = db.flush();
        }
    }

    fn top_hash(&self) -> Option<[u8; 32]> {
        self.db
            .get(KEY_TOP_HASH)
            .ok()
            .flatten()
            .and_then(|b| bincode::deserialize::<[u8; 32]>(&b).ok())
    }

    fn set_top_hash(&self, hash: &[u8; 32]) {
        let _ = bincode::serialize(hash).ok().and_then(|b| self.db.insert(KEY_TOP_HASH, b).ok());
    }

    fn pending(&self) -> Vec<PendingTx> {
        self.db
            .get(b"pending")
            .ok()
            .flatten()
            .and_then(|b| bincode::deserialize::<Vec<PendingTx>>(&b).ok())
            .unwrap_or_default()
    }

    fn store_pending(&self, list: &[PendingTx]) {
        let _ = bincode::serialize(list).ok().and_then(|b| self.db.insert(b"pending", b).ok());
        let _ = self.db.flush();
    }


    /// One incremental sync round over /queryblockslite.bin. Returns the
    /// number of blocks scanned.
    pub async fn sync_once(&self) -> std::result::Result<u64, String> {
        let info = self.daemon.get_info().await?;
        let our_height = self.wallet.lock().unwrap().height();

        if info.height <= our_height {
            return Ok(0);
        }

        // Fuego requires a non-empty supplement locator ending in genesis.
        // A tip-only or empty locator makes /queryblockslite.bin return 500.
        let genesis = self.daemon.get_genesis_hash().await?;
        let locator: Vec<[u8; 32]> = match self.top_hash() {
            Some(h) if our_height > 0 => vec![h, genesis],
            _ => vec![genesis],
        };

        let resp = self.daemon.query_blocks_lite(&locator, 0).await?;
        let mut scanned = 0u64;

        for (k, item) in resp.items.iter().enumerate() {
            let block_height = resp.start_height + k as u64;

            for txi in &item.tx_prefixes {
                let prefix = &txi.parsed;
                let received = {
                    let wallet = self.wallet.lock().unwrap();
                    wallet
                        .scan_tx_prefix(&txi.tx_hash, &prefix, block_height)
                        .map_err(|e| format!("scan: {e}"))?
                        .0
                };

                if received > 0 {
                    match self.daemon.get_o_indexes(&txi.tx_hash).await {
                        Ok(indices) => {
                            let wallet = self.wallet.lock().unwrap();
                            wallet.attach_global_indices(&txi.tx_hash, &indices);
                        }
                        Err(e) => {
                            log::warn!("get_o_indexes failed for {}: {}", hex::encode(txi.tx_hash), e);
                        }
                    }
                }
            }

            // Remove pending sends that confirmed in this block.
            self.confirm_pending(&item.tx_prefixes);

            let wallet = self.wallet.lock().unwrap();
            wallet.set_height(block_height);
            drop(wallet);
            self.set_top_hash(&item.block_id);
            scanned += 1;
        }

        if scanned > 0 {
            // Reconcile deep-confirmed utxos against the daemon's key image
            // index (covers outputs spent before a seed restore).
            self.reconcile_spent(our_height).await;
            self.persist_state();
        }

        Ok(scanned)
    }

    /// Background sync loop; never returns.
    pub async fn sync_loop(&self) {
        loop {
            match self.sync_once().await {
                Ok(0) => {
                    tokio::time::sleep(std::time::Duration::from_secs(30)).await;
                }
                Ok(n) => {
                    log::info!("Synced {} blocks", n);
                }
                Err(e) => {
                    log::error!("Sync error: {}", e);
                    tokio::time::sleep(std::time::Duration::from_secs(30)).await;
                }
            }
        }
    }

    /// Remove pending entries whose transaction is now in a scanned block.
    fn confirm_pending(&self, prefixes: &[fuego_sdk::serialization::TxPrefixInfo]) {
        let mut pending = self.pending();
        if pending.is_empty() {
            return;
        }
        let confirmed: Vec<[u8; 32]> = prefixes.iter().map(|p| p.tx_hash).collect();
        let before = pending.len();
        pending.retain(|p| !confirmed.contains(&p.tx_hash));
        if pending.len() != before {
            self.store_pending(&pending);
        }
    }

    /// Ask the daemon whether any of our unspent outputs' key images are
    /// spent. Best-effort: if the endpoint is unavailable, scan-based
    /// tracking remains in effect.
    async fn reconcile_spent(&self, _our_height: u64) {
        let utxos = self.wallet.lock().unwrap().utxos();
        for utxo in utxos {
            match self.daemon.is_key_image_spent(&utxo.key_image).await {
                Ok(true) => {
                    log::info!(
                        "key image {} marked spent by daemon (tx {})",
                        hex::encode(utxo.key_image),
                        hex::encode(utxo.tx_hash)
                    );
                    let wallet = self.wallet.lock().unwrap();
                    wallet.reserve_pending(&[utxo.key_image]);
                }
                Ok(false) => {}
                Err(_) => return, // endpoint missing: stop, rely on scans
            }
        }
    }
}

impl WalletService {
    /// The background sync engine, detached from the service mutex.
    pub fn sync_engine(&self) -> SyncEngine {
        SyncEngine {
            wallet: self.wallet.clone(),
            daemon: self.daemon.clone(),
            db: self.db.clone(),
        }
    }

    // ------------------------------------------------------------ send

    /// Build, persist and broadcast a transaction. `anonymity` is the
    /// requested mixin (0 → default 4).
    pub async fn send_transaction(
        &self,
        destinations: &[(String, u64)],
        fee: u64,
        anonymity: u32,
    ) -> std::result::Result<String, String> {
        let fee = fee.max(MINIMUM_FEE);
        let mixin = if anonymity == 0 {
            DEFAULT_MIXIN
        } else {
            (anonymity as usize).min(fuego_sdk::transaction_builder::MAX_MIXIN)
        };

        let total: u64 = destinations.iter().map(|(_, a)| *a).sum::<u64>() + fee;

        let selected = {
            let wallet = self.wallet.lock().unwrap();
            wallet
                .select_for_send(total, &mut rand::thread_rng())
                .map_err(|e| format!("coin selection: {e}"))?
        };

        // Fetch decoys per input amount.
        let amounts: Vec<u64> = selected.iter().map(|u| u.amount).collect();
        let groups = self.daemon.get_random_outs(&amounts, (mixin + 1) as u64).await?;

        let mut decoys: Vec<Vec<DecoyEntry>> = Vec::with_capacity(selected.len());
        for utxo in selected.iter() {
            let group = groups
                .iter()
                .find(|g| g.amount == utxo.amount)
                .ok_or_else(|| format!("daemon returned no decoys for amount {}", utxo.amount))?;

            let mut entries: Vec<DecoyEntry> = group
                .outs
                .iter()
                .filter(|o| o.global_amount_index != utxo.global_index as u64)
                .map(|o| DecoyEntry {
                    global_index: o.global_amount_index as u32,
                    out_key: o.out_key,
                })
                .collect();
            entries.sort_by_key(|e| e.global_index);
            entries.truncate(mixin);

            if entries.len() < mixin && mixin > 0 {
                return Err(format!(
                    "MIXIN_COUNT_TOO_BIG: only {} decoys available for amount {} (requested {})",
                    entries.len(),
                    utxo.amount,
                    mixin
                ));
            }
            decoys.push(entries);
        }

        let dests: Vec<(fuego_sdk::Address, u64)> = destinations
            .iter()
            .map(|(addr, amount)| (fuego_sdk::Address(addr.clone()), *amount))
            .collect();

        let built = {
            let wallet = self.wallet.lock().unwrap();
            wallet
                .build_with_selection(&selected, &dests, fee, mixin, &decoys, &mut rand::thread_rng())
                .map_err(|e| format!("build: {e}"))?
        };

        let key_images: Vec<[u8; 32]> = selected.iter().map(|u| u.key_image).collect();
        self.broadcast_built(built, key_images).await
    }

    /// Persist-before-broadcast + reserve + submit, shared by all send paths.
    async fn broadcast_built(
        &self,
        built: fuego_sdk::transaction_builder::BuiltTransaction,
        key_images: Vec<[u8; 32]>,
    ) -> std::result::Result<String, String> {
        let tx_hash_hex = hex::encode(built.tx_hash);
        let serialized_hex = hex::encode(&built.serialized);

        let mut pending = self.sync_engine().pending();
        pending.push(PendingTx {
            tx_hash: built.tx_hash,
            key_images: key_images.clone(),
            serialized_hex: serialized_hex.clone(),
            created_height: self.wallet.lock().unwrap().height(),
        });
        self.sync_engine().store_pending(&pending);
        {
            let wallet = self.wallet.lock().unwrap();
            wallet.reserve_pending(&key_images);
        }

        let status = self.daemon.send_raw_tx(&serialized_hex).await?;
        match status.as_str() {
            "OK" => {
                log::info!("Transaction {} submitted", tx_hash_hex);
            }
            "Failed" => {
                let mut pending = self.sync_engine().pending();
                pending.retain(|p| p.tx_hash != built.tx_hash);
                self.sync_engine().store_pending(&pending);
                return Err(format!("daemon rejected transaction: {}", status));
            }
            other => {
                log::warn!(
                    "Transaction {} relay status: {} (inputs stay reserved)",
                    tx_hash_hex,
                    other
                );
            }
        }
        Ok(tx_hash_hex)
    }

    /// Fetch decoy commitment outputs for one deposit.
    async fn commitment_decoys(
        &self,
        deposit: &fuego_sdk::scanner::CommitmentEntry,
        mixin: usize,
    ) -> std::result::Result<Vec<(u32, [u8; 32])>, String> {
        let entries = self
            .daemon
            .get_random_commitment_outs(deposit.amount, (mixin + 1) as u64, 0)
            .await?;
        let mut decoys: Vec<(u32, [u8; 32])> = entries
            .into_iter()
            .filter(|e| e.global_amount_index != deposit.global_index)
            .map(|e| (e.global_amount_index, e.commit_key))
            .collect();
        decoys.sort_by_key(|(idx, _)| *idx);
        decoys.truncate(mixin);
        if decoys.len() < mixin {
            return Err(format!(
                "MIXIN_COUNT_TOO_BIG: only {} commitment decoys available for amount {} (requested {})",
                decoys.len(),
                deposit.amount,
                mixin
            ));
        }
        Ok(decoys)
    }

    /// create_afk_lock (WalletLegacy.cpp:2016): a self-transfer locked by
    /// unlock_time, with an Ed25519 adaptor pre-signature over the zero hash
    /// returned out-of-band for the swap counterparty.
    pub async fn create_afk_lock(
        &self,
        amount: u64,
        timeout_hours: u32,
        pair: u8,
    ) -> std::result::Result<(String, String, String, String), String> {
        if amount == 0 {
            return Err("amount must be > 0".into());
        }
        if timeout_hours == 0 || timeout_hours > 200 {
            return Err("timeout_hours must be in 1..=200".into());
        }

        // 1% taker fee folded into the locked amount.
        let fee_bob = amount * SWAP_FEE_RATE_BPS / SWAP_FEE_RATE_DIVISOR;
        let total = amount + fee_bob;
        let fee = AFK_LOCK_FEE;
        let unlock_time = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(|e| e.to_string())?
            .as_secs()
            + (timeout_hours as u64) * 3600;

        // Self-transfer with unlock time, mixin 0 (as the C++ wallet does).
        let own_address = self.primary_address_string();
        let selected = {
            let wallet = self.wallet.lock().unwrap();
            wallet
                .select_for_send(total + fee, &mut rand::thread_rng())
                .map_err(|e| format!("coin selection: {e}"))?
        };
        let decoys: Vec<Vec<DecoyEntry>> = selected.iter().map(|_| Vec::new()).collect();
        let built = {
            let wallet = self.wallet.lock().unwrap();
            wallet
                .build_with_selection_ext(
                    &selected,
                    &[(fuego_sdk::Address(own_address.clone()), total)],
                    fee,
                    0,
                    &decoys,
                    unlock_time,
                    &[],
                    &mut rand::thread_rng(),
                )
                .map_err(|e| format!("build: {e}"))?
        };

        // Adaptor pre-signature material.
        let keys = self.wallet.lock().unwrap().wallet_keys();
        let zero_hash = [0u8; 32];
        let (secret, adaptor_point, pre_sig) = fuego_crypto::ring::generate_afk_lock_data(
            &zero_hash,
            &keys.spend_public,
            &keys.spend_secret,
            &mut rand::thread_rng(),
        )
        .ok_or("adaptor pre-signature generation failed")?;

        // hashLock = H(T): SHA-256 for UTXO pairs, keccak otherwise
        // (WalletLegacy.cpp:2034-2045).
        let hash_lock = match pair {
            3 | 6 | 8 | 9 | 10 => {
                use sha2::Digest;
                let h = sha2::Sha256::digest(adaptor_point);
                hex::encode(h)
            }
            _ => hex::encode(fuego_crypto::cn_fast_hash(&adaptor_point)),
        };

        let key_images: Vec<[u8; 32]> = selected.iter().map(|u| u.key_image).collect();
        let lock_id = hex::encode(built.tx_hash);
        self.broadcast_built(built, key_images).await?;

        // Persist the AFK secret keyed by lock id.
        let afk = AfkLockSecret {
            secret,
            pre_sig: pre_sig.to_vec(),
            amount,
            timeout_hours,
            pair,
        };
        let key = format!("afk_secret:{}", lock_id);
        let _ = bincode::serialize(&afk)
            .ok()
            .and_then(|b| self.db.insert(key.as_bytes(), b).ok());
        let _ = self.db.flush();

        Ok((
            lock_id,
            hex::encode(adaptor_point),
            hex::encode(pre_sig),
            hash_lock,
        ))
    }

    /// mint_heat: burn XFG, mint HEAT at the Hearth pool spot price.
    pub async fn mint_heat(&self, xfg_burned: u64) -> std::result::Result<String, String> {
        if xfg_burned == 0 {
            return Err("xfg_burned must be > 0".into());
        }
        let (_rx, _rh, spot_price) = self.daemon.amm_pool_info().await?;
        if spot_price == 0 {
            return Err("no pool price available".into());
        }
        let heat_minted = (xfg_burned as u128 * spot_price as u128 / COIN as u128) as u64;
        if heat_minted < HEAT_MINT_MIN_HEAT {
            return Err(format!(
                "minted HEAT {} below minimum {}",
                heat_minted, HEAT_MINT_MIN_HEAT
            ));
        }

        let fee = MINIMUM_FEE;
        let keys = self.wallet.lock().unwrap().wallet_keys();
        let selected = {
            let wallet = self.wallet.lock().unwrap();
            wallet
                .select_for_send(xfg_burned + fee, &mut rand::thread_rng())
                .map_err(|e| format!("coin selection: {e}"))?
        };
        let found: u64 = selected.iter().map(|u| u.amount).sum();
        let change = found - xfg_burned - fee;

        let mixin = DEFAULT_MIXIN;
        let amounts: Vec<u64> = selected.iter().map(|u| u.amount).collect();
        let groups = self.daemon.get_random_outs(&amounts, (mixin + 1) as u64).await?;
        let mut decoys: Vec<Vec<DecoyEntry>> = Vec::with_capacity(selected.len());
        for utxo in selected.iter() {
            let group = groups
                .iter()
                .find(|g| g.amount == utxo.amount)
                .ok_or_else(|| format!("daemon returned no decoys for amount {}", utxo.amount))?;
            let mut entries: Vec<DecoyEntry> = group
                .outs
                .iter()
                .filter(|o| o.global_amount_index != utxo.global_index as u64)
                .map(|o| DecoyEntry {
                    global_index: o.global_amount_index as u32,
                    out_key: o.out_key,
                })
                .collect();
            entries.sort_by_key(|e| e.global_index);
            entries.truncate(mixin);
            if entries.len() < mixin {
                return Err(format!(
                    "MIXIN_COUNT_TOO_BIG: only {} decoys available for amount {}",
                    entries.len(),
                    utxo.amount
                ));
            }
            decoys.push(entries);
        }

        let inputs: Vec<fuego_sdk::transaction_builder::SpendableOutput> =
            selected.iter().map(|u| u.into()).collect();
        let built = fuego_sdk::transaction_builder::build_mint_transaction(
            &inputs,
            &decoys,
            mixin,
            xfg_burned,
            heat_minted,
            change,
            &keys.view_public,
            (&keys.spend_public, &keys.view_public),
            fee,
            &mut rand::thread_rng(),
        )
        .map_err(|e| format!("build: {e}"))?;

        let key_images = selected.iter().map(|u| u.key_image).collect();
        self.broadcast_built(built, key_images).await
    }

    /// create_cd: lock XFG into a finite-term commitment output.
    pub async fn create_cd(
        &self,
        amount: u64,
        term_blocks: u32,
    ) -> std::result::Result<String, String> {
        if amount == 0 {
            return Err("amount must be > 0".into());
        }
        if term_blocks < DEPOSIT_MIN_TERM || term_blocks > DEPOSIT_MAX_TERM {
            return Err(format!(
                "term must be in {}..={} blocks",
                DEPOSIT_MIN_TERM, DEPOSIT_MAX_TERM
            ));
        }
        let fee = MINIMUM_FEE;
        let keys = self.wallet.lock().unwrap().wallet_keys();
        let selected = {
            let wallet = self.wallet.lock().unwrap();
            wallet
                .select_for_send(amount + fee, &mut rand::thread_rng())
                .map_err(|e| format!("coin selection: {e}"))?
        };
        let found: u64 = selected.iter().map(|u| u.amount).sum();
        let change = found - amount - fee;

        let mixin = DEFAULT_MIXIN;
        let amounts: Vec<u64> = selected.iter().map(|u| u.amount).collect();
        let groups = self.daemon.get_random_outs(&amounts, (mixin + 1) as u64).await?;
        let mut decoys: Vec<Vec<DecoyEntry>> = Vec::with_capacity(selected.len());
        for utxo in selected.iter() {
            let group = groups
                .iter()
                .find(|g| g.amount == utxo.amount)
                .ok_or_else(|| format!("daemon returned no decoys for amount {}", utxo.amount))?;
            let mut entries: Vec<DecoyEntry> = group
                .outs
                .iter()
                .filter(|o| o.global_amount_index != utxo.global_index as u64)
                .map(|o| DecoyEntry {
                    global_index: o.global_amount_index as u32,
                    out_key: o.out_key,
                })
                .collect();
            entries.sort_by_key(|e| e.global_index);
            entries.truncate(mixin);
            if entries.len() < mixin {
                return Err(format!(
                    "MIXIN_COUNT_TOO_BIG: only {} decoys available for amount {}",
                    entries.len(),
                    utxo.amount
                ));
            }
            decoys.push(entries);
        }

        let (change_chunks, dust) = decompose_change(change, DEFAULT_DUST_THRESHOLD);
        let mut key_dests: Vec<BuildDestination> = Vec::with_capacity(change_chunks.len() + 1);
        for chunk in change_chunks {
            key_dests.push(BuildDestination {
                amount: chunk,
                spend_pub: keys.spend_public,
                view_pub: keys.view_public,
            });
        }
        if dust > 0 {
            key_dests.push(BuildDestination {
                amount: dust,
                spend_pub: keys.spend_public,
                view_pub: keys.view_public,
            });
        }

        let inputs: Vec<fuego_sdk::transaction_builder::SpendableOutput> =
            selected.iter().map(|u| u.into()).collect();
        let commitment_dests = vec![BuildCommitmentDestination {
            amount,
            term: term_blocks,
        }];
        let built = build_mixed_output_transaction(
            &inputs,
            &decoys,
            mixin,
            &commitment_dests,
            &key_dests,
            &keys.view_public,
            fee,
            &[],
            &mut rand::thread_rng(),
        )
        .map_err(|e| format!("build: {e}"))?;

        let key_images = selected.iter().map(|u| u.key_image).collect();
        self.broadcast_built(built, key_images).await
    }

    /// claim_cd: spend all mature finite-term deposits back to ourselves.
    pub async fn claim_cd(&self) -> std::result::Result<String, String> {
        let height = self.wallet.lock().unwrap().height();
        let deposits: Vec<fuego_sdk::scanner::CommitmentEntry> = self
            .wallet
            .lock()
            .unwrap()
            .deposits()
            .into_iter()
            .filter(|d| d.block_height + d.term as u64 <= height && d.global_index != 0)
            .collect();
        if deposits.is_empty() {
            return Err("no mature deposits to claim".into());
        }

        let fee = MINIMUM_FEE;
        let total: u64 = deposits.iter().map(|d| d.amount).sum();
        if total <= fee {
            return Err("deposit total below fee".into());
        }
        let payout = total - fee;

        let mixin = DEFAULT_MIXIN;
        let mut decoys = Vec::with_capacity(deposits.len());
        for deposit in &deposits {
            decoys.push(self.commitment_decoys(deposit, mixin).await?);
        }

        let keys = self.wallet.lock().unwrap().wallet_keys();
        let (chunks, dust) = decompose_change(payout, DEFAULT_DUST_THRESHOLD);
        let mut key_dests: Vec<BuildDestination> = Vec::with_capacity(chunks.len() + 1);
        for chunk in chunks {
            key_dests.push(BuildDestination {
                amount: chunk,
                spend_pub: keys.spend_public,
                view_pub: keys.view_public,
            });
        }
        if dust > 0 {
            key_dests.push(BuildDestination {
                amount: dust,
                spend_pub: keys.spend_public,
                view_pub: keys.view_public,
            });
        }

        let spends: Vec<CommitmentDeposit> = deposits
            .iter()
            .map(|d| CommitmentDeposit {
                amount: d.amount,
                commit_key: d.commit_key,
                key_scalar: d.key_scalar,
                key_image: d.key_image,
                global_index: d.global_index,
                claimed_interest: 0,
            })
            .collect();
        let built = build_commitment_spend_transaction(
            &spends,
            &decoys,
            mixin,
            &key_dests,
            &[],
            &keys.view_public,
            fee,
            &[],
            &mut rand::thread_rng(),
        )
        .map_err(|e| format!("build: {e}"))?;

        let key_images: Vec<[u8; 32]> = deposits.iter().map(|d| d.key_image).collect();
        self.broadcast_built(built, key_images).await
    }

    /// heat_cd: lock HEAT into a finite-term CD (with banking fee burned to
    /// the treasury via the 0xFF extra).
    pub async fn heat_cd(
        &self,
        amount: u64,
        epochs: u32,
        banking_fee: u64,
    ) -> std::result::Result<String, String> {
        if amount == 0 {
            return Err("amount must be > 0".into());
        }
        if epochs == 0 {
            return Err("epochs must be > 0".into());
        }
        let epoch_blocks: u64 = if self.testnet { 10 } else { 900 };
        let term_blocks = (epochs as u64) * epoch_blocks;
        let banking_fee = if banking_fee == 0 {
            (amount / 1000).max(1)
        } else {
            banking_fee
        };

        let heat: Vec<fuego_sdk::scanner::CommitmentEntry> = self
            .wallet
            .lock()
            .unwrap()
            .heat_outputs()
            .into_iter()
            .filter(|d| d.global_index != 0)
            .collect();
        let needed = amount + banking_fee;
        let mut selected = Vec::new();
        let mut found = 0u64;
        for entry in heat {
            found += entry.amount;
            selected.push(entry);
            if found >= needed {
                break;
            }
        }
        if found < needed {
            return Err(format!(
                "insufficient HEAT: need {}, have {}",
                needed, found
            ));
        }

        let fee = MINIMUM_FEE;
        let mixin = DEFAULT_MIXIN;
        let mut decoys = Vec::with_capacity(selected.len());
        for deposit in &selected {
            decoys.push(self.commitment_decoys(deposit, mixin).await?);
        }

        let keys = self.wallet.lock().unwrap().wallet_keys();
        let heat_change = found - needed;

        let mut commitment_dests = vec![BuildCommitmentDestination {
            amount,
            term: term_blocks as u32,
        }];
        if heat_change > 0 {
            commitment_dests.push(BuildCommitmentDestination {
                amount: heat_change,
                term: HEAT_TERM,
            });
        }

        let mut extra_extra = Vec::new();
        add_treasury_fund_extra(&mut extra_extra, 1 /* HEAT */, banking_fee);

        let spends: Vec<CommitmentDeposit> = selected
            .iter()
            .map(|d| CommitmentDeposit {
                amount: d.amount,
                commit_key: d.commit_key,
                key_scalar: d.key_scalar,
                key_image: d.key_image,
                global_index: d.global_index,
                claimed_interest: 0,
            })
            .collect();
        let built = build_commitment_spend_transaction(
            &spends,
            &decoys,
            mixin,
            &[],
            &commitment_dests,
            &keys.view_public,
            fee,
            &extra_extra,
            &mut rand::thread_rng(),
        )
        .map_err(|e| format!("build: {e}"))?;

        let key_images: Vec<[u8; 32]> = selected.iter().map(|d| d.key_image).collect();
        self.broadcast_built(built, key_images).await
    }

    // ------------------------------------------------------------ API

    pub async fn address(&self) -> String {
        self.primary_address_string()
    }

    pub async fn balance(&self) -> u64 {
        self.wallet.lock().unwrap().balance().confirmed
    }

    pub async fn height(&self) -> u64 {
        self.wallet.lock().unwrap().height()
    }

    pub async fn balance_full(&self) -> Balance {
        self.wallet.lock().unwrap().balance()
    }

    pub fn sync_status(&self) -> SyncStatus {
        SyncStatus {
            current_height: self.wallet.lock().unwrap().height(),
            target_height: 0,
            is_syncing: false,
            last_sync_time: None,
        }
    }

    pub async fn get_transactions(&self, limit: usize) -> Vec<fuego_sdk::scanner::HistoryEntry> {
        self.wallet.lock().unwrap().get_transactions(limit)
    }

    pub async fn get_keypair(&self, index: u32) -> Keypair {
        self.wallet.lock().unwrap().get_keypair(index)
    }

    pub async fn register_alias(&self, _alias: &str, _fee: u64) -> Result<[u8; 32]> {
        Err(SdkError::Vault(
            "alias registration is not part of the transaction builder path (Phase 7)".into(),
        ))
    }

    pub async fn claim_afk_swap(
        &self,
        lock_id: &str,
        payout_address: &str,
        _taker_signature_hex: &str,
    ) -> Result<[u8; 32]> {
        let key = format!("afk_secret:{}", lock_id);
        let secret = self
            .db
            .get(key.as_bytes())
            .ok()
            .flatten()
            .and_then(|b| bincode::deserialize::<AfkLockSecret>(&b).ok())
            .ok_or_else(|| SdkError::Vault(format!("no AFK lock secret for {}", lock_id)))?;

        let total_locked = secret.amount + secret.amount * SWAP_FEE_RATE_BPS / SWAP_FEE_RATE_DIVISOR;
        let taker_net = secret.amount - secret.amount * SWAP_FEE_RATE_BPS / SWAP_FEE_RATE_DIVISOR;
        let taker_gross = taker_net + MINIMUM_FEE;
        let fee_pool_amount = total_locked.saturating_sub(taker_gross + MINIMUM_FEE);

        let mut dests: Vec<(String, u64)> = vec![(payout_address.to_string(), taker_gross)];
        if fee_pool_amount > 0 {
            if let Ok(info) = self.daemon.get_info().await {
                if !info.fee_address.is_empty() {
                    dests.push((info.fee_address, fee_pool_amount));
                }
            }
        }
        let tx_hash = self
            .send_transaction(&dests, MINIMUM_FEE, DEFAULT_MIXIN as u32)
            .await
            .map_err(SdkError::Vault)?;
        let _ = self.db.remove(key.as_bytes());
        let _ = self.db.flush();
        let bytes = hex::decode(&tx_hash).map_err(|e| SdkError::Vault(e.to_string()))?;
        if bytes.len() != 32 {
            return Err(SdkError::Vault("unexpected tx hash length".into()));
        }
        let mut out = [0u8; 32];
        out.copy_from_slice(&bytes);
        Ok(out)
    }

    pub async fn list_cds(&self) -> Vec<String> {
        self.wallet
            .lock()
            .unwrap()
            .deposits()
            .iter()
            .map(|d| format!("{}:{}:{}", hex::encode(d.tx_hash), d.amount, d.term))
            .collect()
    }
}
