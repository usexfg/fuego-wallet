#![allow(dead_code)]

mod base58;
mod crypto;
mod daemon;
mod fuegod;
mod keystore;
mod release;
mod scanner;
mod server;
mod wallet_service;
mod walletd;

use clap::{Parser, Subcommand};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex;
use crate::wallet_service::WalletService;

fn default_wallet_dir() -> PathBuf {
    directories::ProjectDirs::from("org", "usexfg", "fuego-wallet")
        .map(|d| d.data_local_dir().to_path_buf())
        .unwrap_or_else(|| PathBuf::from(".fuego-wallet"))
}

#[derive(Parser)]
#[command(name = "fuego-wallet", about = "Fuego-native wallet")]
struct Cli {
    #[arg(short = 'H', long, default_value = "127.0.0.1")]
    host: String,

    #[arg(short = 'P', long, default_value_t = 8070)]
    port: u16,

    #[arg(long)]
    seed: Option<String>,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    Serve {
        #[arg(long, default_value = "207.244.247.64")]
        daemon_host: String,

        #[arg(long, default_value_t = 18180)]
        daemon_port: u16,

        #[arg(long)]
        testnet: bool,
    },
    Status,
}

fn load_or_create_seed(wallet_dir: &PathBuf) -> Result<[u8; 32], Box<dyn std::error::Error>> {
    let seed_path = wallet_dir.join("master_seed.bin");
    if seed_path.exists() {
        let data = std::fs::read(&seed_path)?;
        if data.len() == 32 {
            let mut seed = [0u8; 32];
            seed.copy_from_slice(&data);
            return Ok(seed);
        }
    }
    let mut seed = [0u8; 32];
    use rand::RngCore;
    rand::rngs::OsRng.fill_bytes(&mut seed);
    std::fs::write(&seed_path, &seed)?;
    log::info!("Created new wallet seed at {:?}", seed_path);
    Ok(seed)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let cli = Cli::parse();
    let wallet_dir = default_wallet_dir();
    std::fs::create_dir_all(&wallet_dir)?;

    match cli.command.unwrap_or(Commands::Status) {
        Commands::Serve { daemon_host, daemon_port, testnet: _testnet } => {
            // Use remote daemon directly — embedded fuegod is unreliable on macOS
            let actual_host = daemon_host.clone();

            let daemon_url = format!("http://{}:{}", actual_host, daemon_port);

            // 2. Initialize SDK wallet
            let seed = match &cli.seed {
                Some(s) => {
                    let bytes = hex::decode(s.trim_start_matches("0x"))
                        .map_err(|e| format!("invalid seed hex: {}", e))?;
                    if bytes.len() != 32 {
                        return Err(format!("seed must be 32 bytes").into());
                    }
                    let mut seed = [0u8; 32];
                    seed.copy_from_slice(&bytes);
                    seed
                }
                None => load_or_create_seed(&wallet_dir)?,
            };

            let wallet_service = WalletService::new(seed, &actual_host, daemon_port)
                .map_err(|e| format!("Failed to initialize SDK wallet: {}", e))?;
            let wallet_addr = wallet_service.address().await;
            let sync_node = wallet_service.node.clone();
            let wallet = Arc::new(Mutex::new(wallet_service));

            log::info!("Wallet address: {}", wallet_addr);

            // 3. Start background sync (100 blocks per batch, releases lock between)
            tokio::spawn(async move {
                log::info!("Starting background wallet sync...");
                loop {
                    match sync_node.lock().await.sync_batch(None, 100).await {
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
            });

            // 4. Start Axum server
            let bind = format!("{}:{}", cli.host, cli.port);
            server::run_server(wallet, &daemon_url, &bind).await?;
        }

        Commands::Status => {
            println!("Wallet dir: {:?}", wallet_dir);
            let seed_path = wallet_dir.join("master_seed.bin");
            println!("Seed: {}", if seed_path.exists() { "exists" } else { "not found" });
            println!("Use 'fuego-wallet serve' to start.");
        }
    }

    Ok(())
}
