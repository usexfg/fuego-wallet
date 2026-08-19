use crate::error::{Result, SdkError};
use crate::chain::evm_rpc::EvmRpcClient;
use crate::chain::{ChainSpv, ChainHeader, MerkleProof, PaymentProof, ChainType};

/// Unified EVM SPV adapter (ETH, ARB, BASE).
/// Uses block receipts and transaction verification.
pub struct EvmChain {
    chain: ChainType,
    rpc: EvmRpcClient,
    min_confirmations: u64,
}

impl EvmChain {
    pub fn new(chain: ChainType, rpc_url: &str, min_confirmations: u64) -> Result<Self> {
        if !chain.is_evm() {
            return Err(SdkError::Config(format!(
                "EvmChain only supports EVM-compatible chains, got {chain:?}"
            )));
        }
        Ok(Self {
            chain,
            rpc: EvmRpcClient::new(rpc_url),
            min_confirmations,
        })
    }

    pub fn set_min_confirmations(&mut self, n: u64) {
        self.min_confirmations = n;
    }
}

#[async_trait::async_trait]
impl ChainSpv for EvmChain {
    fn chain_type(&self) -> ChainType {
        self.chain
    }

    async fn get_height(&self) -> Result<u64> {
        self.rpc.get_block_number().await
    }

    async fn get_header(&self, height: u64) -> Result<ChainHeader> {
        let block = self.rpc.get_block_by_number(height).await?;
        Ok(ChainHeader {
            chain: self.chain,
            height,
            hash: block.hash,
            prev_hash: block.parent_hash,
            merkle_root: block.receipts_root, // EVM uses receiptsRoot for receipt verification
            timestamp: block.timestamp,
            bits: 0,
            confirmations: 0,
        })
    }

    async fn get_header_by_hash(&self, hash: &str) -> Result<ChainHeader> {
        let block = self.rpc.get_block_by_hash(hash).await?;
        Ok(ChainHeader {
            chain: self.chain,
            height: block.number,
            hash: block.hash,
            prev_hash: block.parent_hash,
            merkle_root: block.receipts_root,
            timestamp: block.timestamp,
            bits: 0,
            confirmations: 0,
        })
    }

    async fn get_latest_header(&self) -> Result<ChainHeader> {
        let height = self.get_height().await?;
        self.get_header(height).await
    }

    async fn get_merkle_proof(&self, tx_hash: &str) -> Result<MerkleProof> {
        let receipt = self.rpc.get_transaction_receipt(tx_hash).await?;

        Ok(MerkleProof {
            chain: self.chain,
            tx_hash: tx_hash.to_string(),
            block_height: receipt.block_number,
            block_hash: receipt.block_hash,
            merkle_path: vec![receipt.transaction_index.to_string()],
            tx_index: receipt.transaction_index as u32,
            total_txs: 0,
        })
    }

    fn verify_merkle(&self, proof: &MerkleProof, header: &ChainHeader) -> Result<bool> {
        // EVM verification: check the transaction is in the correct block
        // by verifying block_hash matches. Full receipt trie verification
        // requires eth_getProof which is not universally supported.
        Ok(proof.block_hash == header.hash && proof.block_height > 0)
    }

    async fn get_confirmations(&self, tx_hash: &str) -> Result<u32> {
        let receipt = self.rpc.get_transaction_receipt(tx_hash).await?;
        let current_height = self.get_height().await?;

        if current_height >= receipt.block_number {
            Ok((current_height - receipt.block_number + 1) as u32)
        } else {
            // Stale data or reorg
            Ok(0)
        }
    }

    async fn build_payment_proof(
        &self,
        tx_hash: &str,
        from_address: &str,
        to_address: &str,
        amount: u64,
    ) -> Result<PaymentProof> {
        let merkle = self.get_merkle_proof(tx_hash).await?;
        let header = self.get_header(merkle.block_height).await?;
        let confirmations = self.get_confirmations(tx_hash).await?;

        Ok(PaymentProof {
            chain: self.chain,
            tx_hash: tx_hash.to_string(),
            amount,
            from_address: from_address.to_string(),
            to_address: to_address.to_string(),
            confirmations,
            block_height: merkle.block_height,
            block_hash: merkle.block_hash.clone(),
            verified: false,
            merkle_root: header.merkle_root.clone(),
            merkle_proof: merkle.merkle_path,
            tx_index: merkle.tx_index,
            total_txs: merkle.total_txs,
        })
    }

    async fn verify_payment_proof(&self, proof: &PaymentProof, min_confirmations: u32) -> Result<bool> {
        if proof.confirmations < min_confirmations {
            return Ok(false);
        }

        let header = self.get_header(proof.block_height).await?;

        // Verify block hash matches and merkle root matches
        if proof.block_hash != header.hash {
            return Ok(false);
        }
        if proof.merkle_root != header.merkle_root {
            return Ok(false);
        }

        // Verify the receipt exists in the claimed block and succeeded.
        let receipt = self.rpc.get_transaction_receipt(&proof.tx_hash).await?;
        if receipt.block_hash != proof.block_hash {
            return Ok(false);
        }
        if receipt.block_number != proof.block_height {
            return Ok(false);
        }
        // Reverted transactions must never verify.
        if receipt.status != "0x1" {
            return Ok(false);
        }

        // Verify the on-chain amount + sender + recipient (iron law:
        // verifyLock checks amount and recipient). Addresses are compared
        // case-insensitively; RPCs vary in checksum casing.
        let tx = self.rpc.get_transaction_by_hash(&proof.tx_hash).await?;
        if tx.block_number != Some(proof.block_height) {
            return Ok(false);
        }
        if !tx.to.eq_ignore_ascii_case(&proof.to_address) {
            return Ok(false);
        }
        if !proof.from_address.is_empty() && !tx.from.eq_ignore_ascii_case(&proof.from_address) {
            return Ok(false);
        }
        let value_wei = crate::chain::evm_rpc::parse_hex_u64_public(&tx.value);
        if value_wei != Some(proof.amount) {
            return Ok(false);
        }

        // Wrong-network RPC detection: the chain id must match the adapter's
        // expected chain id for this ChainType.
        let chain_id = self.rpc.get_chain_id().await?;
        if chain_id != expected_chain_id(self.chain) {
            return Ok(false);
        }

        Ok(true)
    }
}

// ── Receipt / Transaction types ────────────────────────────────────

/// Expected EVM chain id per ChainType — catches an adapter pointed at the
/// wrong network or a lying RPC.
fn expected_chain_id(chain: ChainType) -> u64 {
    match chain {
        ChainType::Ethereum => 1,
        ChainType::Arbitrum => 42161,
        ChainType::Base => 8453,
        ChainType::Bnb => 56,
        ChainType::Polygon => 137,
        _ => 0,
    }
}

#[derive(Debug, Clone)]
pub struct EvmReceipt {
    pub block_hash: String,
    pub block_number: u64,
    pub transaction_index: u64,
    pub status: String,
    pub logs_bloom: String,
}

#[derive(Debug, Clone)]
pub struct EvmBlock {
    pub hash: String,
    pub parent_hash: String,
    pub number: u64,
    pub timestamp: u64,
    pub logs_bloom: String,
    pub receipts_root: String,
}

#[derive(Debug, Clone)]
pub struct EvmTx {
    pub hash: String,
    pub from: String,
    pub to: String,
    pub value: String,
    pub block_number: Option<u64>,
}
