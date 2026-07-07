#![allow(dead_code)]

mod base58;
mod crypto;
mod daemon;
mod keystore;
mod server;
mod wallet;
mod walletd;

use clap::{Parser, Subcommand};
use daemon::DaemonClient;
use keystore::Keystore;
use wallet::WalletState;
use walletd::WalletdProcess;
use std::path::PathBuf;

fn default_wallet_dir() -> PathBuf {
    directories::ProjectDirs::from("org", "usexfg", "fuego-wallet")
        .map(|d| d.data_local_dir().to_path_buf())
        .unwrap_or_else(|| PathBuf::from(".fuego-wallet"))
}

#[derive(Parser)]
#[command(name = "fuego-wallet", about = "Fuego-native wallet")]
struct Cli {
    #[arg(short, long, default_value = "127.0.0.1")]
    host: String,

    #[arg(short = 'P', long, default_value_t = 8070)]
    port: u16,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    Create,
    Open,
    Serve {
        #[arg(long, default_value = "207.244.247.64")]
        daemon_host: String,

        #[arg(long, default_value_t = 18180)]
        daemon_port: u16,

        #[arg(long)]
        testnet: bool,
    },
    Address,
    Status,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let cli = Cli::parse();
    let wallet_dir = default_wallet_dir();
    std::fs::create_dir_all(&wallet_dir)?;
    let keystore_path = wallet_dir.join("fuego_wallet.keystore");
    let has_keystore = keystore_path.exists();

    match cli.command.unwrap_or(Commands::Status) {
        Commands::Create => {
            if has_keystore {
                println!("Wallet already exists at {:?}", keystore_path);
                println!("Use 'open' to unlock or delete the keystore file to recreate.");
                return Ok(());
            }

            let daemon = DaemonClient::new("http://127.0.0.1:18180");
            let keystore = Keystore::new(keystore_path);
            let mut wallet = WalletState::new(keystore, daemon);
            let (mnemonic, _secrets) = wallet.create()?;
            println!("Wallet created successfully.");
            println!();
            println!("Mnemonic (SAVE THIS SECURELY):");
            println!("{}", mnemonic);
            println!();
            println!("Address: {}", wallet.address().unwrap());
        }

        Commands::Open => {
            if !has_keystore {
                println!("No wallet found at {:?}", keystore_path);
                println!("Create one with 'fuego-wallet create'.");
                return Ok(());
            }

            let daemon = DaemonClient::new("http://127.0.0.1:18180");
            let keystore = Keystore::new(keystore_path);
            let mut wallet = WalletState::new(keystore, daemon);
            wallet.open()?;
            println!("Wallet unlocked.");
            println!("Address: {}", wallet.address().unwrap());
        }

        Commands::Serve { daemon_host, daemon_port, testnet: _testnet } => {
            let daemon_url = format!("http://{}:{}", daemon_host, daemon_port);
            let daemon = DaemonClient::new(&daemon_url);
            let keystore = Keystore::new(keystore_path.clone());
            let mut wallet = WalletState::new(keystore, daemon);

            if has_keystore {
                wallet.open()?;
                log::info!("Wallet unlocked. Address: {}", wallet.address().unwrap_or_default());
            } else {
                log::warn!("Keystore not found. Create one first with 'fuego-wallet create'.");
            }

            let mut wp = WalletdProcess::new(8071);
            let walletd_url = match wp.start(&daemon_host, daemon_port,
                keystore_path.to_str().unwrap_or("fuego_wallet")).await
            {
                Ok(url) => Some(url),
                Err(e) => {
                    log::warn!("walletd: {}", e);
                    None
                }
            };

            let bind = format!("{}:{}", cli.host, cli.port);
            server::run_server(wallet, walletd_url, &bind).await?;
            wp.stop();
        }

        Commands::Address => {
            if !has_keystore {
                println!("No wallet found at {:?}", keystore_path);
                println!("Create one with 'fuego-wallet create'.");
                return Ok(());
            }
            println!("Keystore exists at {:?}", keystore_path);
            println!("Use 'fuego-wallet open' or 'fuego-wallet serve' to unlock.");
        }

        Commands::Status => {
            println!("Keystore: {:?}", keystore_path);
            println!("Exists: {}", has_keystore);
            if !has_keystore {
                println!("Create one with: fuego-wallet create");
            } else {
                println!("Use 'open' or 'serve' to unlock.");
            }
        }
    }

    Ok(())
}
