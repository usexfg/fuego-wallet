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
            // 1. Start fuegod (embedded or remote)
            let mut fuegod_proc = fuegod::DaemonProcess::new(18180);
            let data_dir = format!("{}/fuegod", wallet_dir.to_str().unwrap_or("."));
            let actual_host = match fuegod_proc.start(false, &data_dir).await {
                Ok(_) => {
                    log::info!("Embedded fuegod started on 127.0.0.1:18180");
                    "127.0.0.1".to_string()
                }
                Err(e) => {
                    log::warn!("Embedded fuegod unavailable: {} — falling back to remote", e);
                    daemon_host.clone()
                }
            };

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

            let wallet = match wallet_service::WalletService::new(seed, &actual_host, daemon_port) {
                Ok(w) => {
                    log::info!("SDK wallet initialized — address: {}", w.address());
                    Arc::new(w)
                }
                Err(e) => {
                    log::error!("Failed to initialize SDK wallet: {}", e);
                    return Err(e.to_string().into());
                }
            };

            let wallet_addr = wallet.address();
            log::info!("Wallet address: {}", wallet_addr);

            // 3. Start background sync
            let sync_wallet = wallet.clone();
            tokio::spawn(async move {
                log::info!("Starting background wallet sync...");
                match sync_wallet.start_sync().await {
                    Ok(()) => log::info!("Wallet sync complete — balance: {}", sync_wallet.balance()),
                    Err(e) => log::warn!("Wallet sync interrupted: {}", e),
                }
            });

            // 4. Start Axum server
            let wallet_state = wallet;
            let bind = format!("{}:{}", cli.host, cli.port);
            server::run_server(wallet_state, &daemon_url, &bind).await?;

            fuegod_proc.stop();
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
