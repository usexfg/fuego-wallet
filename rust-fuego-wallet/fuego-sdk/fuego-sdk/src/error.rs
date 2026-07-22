use thiserror::Error;

#[derive(Error, Debug)]
pub enum SdkError {
    #[error("Crypto error: {0}")]
    Crypto(String),

    #[error("Network error: {0}")]
    Network(String),

    #[error("Storage error: {0}")]
    Storage(String),

    #[error("Wallet error: {0}")]
    Wallet(String),

    #[error("Vault error: {0}")]
    Vault(String),

    #[error("Node error: {0}")]
    Node(String),

    #[error("Invalid address: {0}")]
    InvalidAddress(String),

    #[error("Insufficient funds: need {need}, have {have}")]
    InsufficientFunds { need: u64, have: u64 },

    #[error("Transaction error: {0}")]
    Transaction(String),

    #[error("Sync error: {0}")]
    Sync(String),

    #[error("Config error: {0}")]
    Config(String),

    #[error("Not found: {0}")]
    NotFound(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Serialization error: {0}")]
    Serialization(String),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("Feature not enabled: {0}")]
    FeatureDisabled(String),
}

pub type Result<T> = std::result::Result<T, SdkError>;
