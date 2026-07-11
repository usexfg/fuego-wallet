use crate::error::Result;
use crate::network::NullNetwork;
use crate::store::MemoryStore;
use crate::traits::{BlockObserver, EventListener, NetworkProvider, StorageProvider};
use crate::types::*;
use std::sync::{Arc, RwLock};
use tokio::sync::broadcast;

pub struct EmbeddedNode {
    _config: NodeConfig,
    network: Arc<dyn NetworkProvider>,
    storage: Arc<dyn StorageProvider>,
    observers: Vec<Arc<dyn BlockObserver>>,
    listeners: Vec<Arc<dyn EventListener>>,
    state: Arc<RwLock<NodeState>>,
    event_tx: broadcast::Sender<NodeEvent>,
}

#[derive(Debug, Clone, Default)]
pub struct NodeState {
    pub height: u64,
    pub is_syncing: bool,
    pub peer_count: usize,
}

#[derive(Debug, Clone)]
pub enum NodeEvent {
    SyncStarted { target: u64 },
    SyncProgress { current: u64, target: u64 },
    SyncComplete,
    BlockReceived(BlockHeader),
    TransactionReceived([u8; 32]),
    Error(String),
}

impl EmbeddedNode {
    pub fn new(config: NodeConfig) -> Result<Self> {
        let storage = Arc::new(MemoryStore::new());
        Self::with_storage(config, storage)
    }

    pub fn with_storage(config: NodeConfig, storage: Arc<dyn StorageProvider>) -> Result<Self> {
        let (event_tx, _) = broadcast::channel(100);
        Ok(Self {
            _config: config,
            network: Arc::new(NullNetwork),
            storage,
            observers: Vec::new(),
            listeners: Vec::new(),
            state: Arc::new(RwLock::new(NodeState::default())),
            event_tx,
        })
    }

    pub fn set_network(&mut self, network: Arc<dyn NetworkProvider>) {
        self.network = network;
    }

    pub fn add_observer(&mut self, observer: Arc<dyn BlockObserver>) {
        self.observers.push(observer);
    }

    pub fn add_listener(&mut self, listener: Arc<dyn EventListener>) {
        self.listeners.push(listener);
    }

    pub fn subscribe(&self) -> broadcast::Receiver<NodeEvent> {
        self.event_tx.subscribe()
    }

    pub fn height(&self) -> u64 {
        self.state.read().unwrap().height
    }

    pub fn sync_status(&self) -> SyncStatus {
        let state = self.state.read().unwrap();
        SyncStatus {
            current_height: state.height,
            target_height: 0,
            is_syncing: state.is_syncing,
            last_sync_time: None,
        }
    }

    pub fn peer_count(&self) -> usize {
        self.state.read().unwrap().peer_count
    }

    pub async fn sync(&self, target_height: Option<u64>) -> Result<()> {
        let target = match target_height {
            Some(h) => h,
            None => self.network.get_height().await?,
        };

        let current = self.height();
        if current >= target {
            return Ok(());
        }

        for listener in &self.listeners {
            listener.on_sync_start(target);
        }
        let _ = self.event_tx.send(NodeEvent::SyncStarted { target });

        let mut current = current;
        while current < target {
            match self.sync_block(current + 1).await {
                Ok(header) => {
                    current = header.height;

                    for listener in &self.listeners {
                        listener.on_sync_progress(current, target);
                    }
                    let _ = self
                        .event_tx
                        .send(NodeEvent::SyncProgress { current, target });

                    let block = self.network.get_block(header.height).await?;
                    for observer in &self.observers {
                        observer.on_block(&block)?;
                    }
                }
                Err(e) => {
                    let _ = self.event_tx.send(NodeEvent::Error(e.to_string()));
                    return Err(e);
                }
            }
        }

        {
            let mut state = self.state.write().unwrap();
            state.height = current;
            state.is_syncing = false;
        }

        self.storage.save_height(current)?;

        for listener in &self.listeners {
            listener.on_sync_complete();
        }
        let _ = self.event_tx.send(NodeEvent::SyncComplete);

        Ok(())
    }

    async fn sync_block(&self, height: u64) -> Result<BlockHeader> {
        let header = self.network.get_header(height).await?;
        self.storage.save_block(&Block {
            header: header.clone(),
            transactions: Vec::new(),
        })?;
        Ok(header)
    }

    pub fn get_block(&self, height: u64) -> Result<Option<Block>> {
        self.storage.get_block(height)
    }

    pub fn storage(&self) -> &Arc<dyn StorageProvider> {
        &self.storage
    }

    pub fn network(&self) -> &Arc<dyn NetworkProvider> {
        &self.network
    }
}
