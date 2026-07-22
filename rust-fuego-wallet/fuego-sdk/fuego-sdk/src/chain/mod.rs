pub mod bitcoin;
pub mod btc_rpc;
pub mod evm;
pub mod evm_rpc;

pub use bitcoin::BitcoinChain;
pub use btc_rpc::BtcRpcClient;
pub use evm::EvmChain;
pub use evm_rpc::EvmRpcClient;

use crate::error::Result;
use serde::{Deserialize, Serialize};

/// Supported chains for SPV verification.
/// Matches actual fuego-suite + Flutter wallet supported chains.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ChainType {
    Fuego,
    Solana,
    Ethereum,
    Monero,
    BitcoinCash,
    Arbitrum,
    Base,
}

impl ChainType {
    pub fn name(&self) -> &'static str {
        match self {
            Self::Fuego => "Fuego",
            Self::Solana => "Solana",
            Self::Ethereum => "Ethereum",
            Self::Monero => "Monero",
            Self::BitcoinCash => "Bitcoin Cash",
            Self::Arbitrum => "Arbitrum",
            Self::Base => "Base",
        }
    }

    pub fn symbol(&self) -> &'static str {
        match self {
            Self::Fuego => "XFG",
            Self::Solana => "SOL",
            Self::Ethereum => "ETH",
            Self::Monero => "XMR",
            Self::BitcoinCash => "BCH",
            Self::Arbitrum => "ARB",
            Self::Base => "BASE",
        }
    }

    pub fn is_bitcoin_family(&self) -> bool {
        matches!(self, Self::BitcoinCash)
    }

    pub fn is_evm(&self) -> bool {
        matches!(self, Self::Ethereum | Self::Arbitrum | Self::Base)
    }

    pub fn all() -> &'static [ChainType] {
        &[
            Self::Fuego,
            Self::Solana,
            Self::Ethereum,
            Self::Monero,
            Self::BitcoinCash,
            Self::Arbitrum,
            Self::Base,
        ]
    }

    pub fn from_symbol(sym: &str) -> Option<Self> {
        match sym.to_uppercase().as_str() {
            "XFG" => Some(Self::Fuego),
            "SOL" => Some(Self::Solana),
            "ETH" => Some(Self::Ethereum),
            "XMR" => Some(Self::Monero),
            "BCH" => Some(Self::BitcoinCash),
            "ARB" => Some(Self::Arbitrum),
            "BASE" => Some(Self::Base),
            _ => None,
        }
    }
}

/// Block header from a foreign chain.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChainHeader {
    pub chain: ChainType,
    pub height: u64,
    pub hash: String,
    pub prev_hash: String,
    pub merkle_root: String,
    pub timestamp: u64,
    pub bits: u32,
    pub confirmations: u32,
}

/// Merkle proof for a transaction.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MerkleProof {
    pub chain: ChainType,
    pub tx_hash: String,
    pub block_height: u64,
    pub block_hash: String,
    pub merkle_path: Vec<String>,
    pub tx_index: u32,
    pub total_txs: u32,
}

/// Payment verification result.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaymentProof {
    pub chain: ChainType,
    pub tx_hash: String,
    pub amount: u64,
    pub from_address: String,
    pub to_address: String,
    pub confirmations: u32,
    pub block_height: u64,
    pub block_hash: String,
    pub verified: bool,
    pub merkle_root: String,
    pub merkle_proof: Vec<String>,
    pub tx_index: u32,
    pub total_txs: u32,
}

/// Trait for SPV verification across all chains.
#[async_trait::async_trait]
pub trait ChainSpv: Send + Sync {
    fn chain_type(&self) -> ChainType;

    /// Get current block height.
    async fn get_height(&self) -> Result<u64>;

    /// Get block header by height.
    async fn get_header(&self, height: u64) -> Result<ChainHeader>;

    /// Get block header by hash.
    async fn get_header_by_hash(&self, hash: &str) -> Result<ChainHeader>;

    /// Get latest block header.
    async fn get_latest_header(&self) -> Result<ChainHeader>;

    /// Get merkle proof for a transaction.
    async fn get_merkle_proof(&self, tx_hash: &str) -> Result<MerkleProof>;

    /// Verify a merkle proof against a block header.
    fn verify_merkle(&self, proof: &MerkleProof, header: &ChainHeader) -> Result<bool>;

    /// Get payment confirmations for a transaction.
    async fn get_confirmations(&self, tx_hash: &str) -> Result<u32>;

    /// Build a full payment proof.
    async fn build_payment_proof(
        &self,
        tx_hash: &str,
        from_address: &str,
        to_address: &str,
        amount: u64,
    ) -> Result<PaymentProof>;

    /// Verify a payment proof (merkle + confirmations).
    async fn verify_payment_proof(&self, proof: &PaymentProof, min_confirmations: u32) -> Result<bool>;
}

// serde import moved to top of file
