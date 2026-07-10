#![allow(dead_code)]

mod base58;
mod crypto;
mod daemon;
mod fuegod;
mod keystore;
mod release;
mod scanner;
mod server;
mod walletd;

use clap::{Parser, Subcommand};
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
    #[arg(short = 'H', long, default_value = "127.0.0.1")]
    host: String,

    #[arg(short = 'P', long, default_value_t = 8070)]
    port: u16,

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

            // 2. Start walletd (optional — server works without it for network queries)
            let mut wp = WalletdProcess::new(8071);
            let container_path = wallet_dir.join("fuego_wallet.container");
            let walletd_url = match wp.start(&actual_host, daemon_port,
                container_path.to_str().unwrap_or("fuego_wallet.container")).await
            {
                Ok(url) => {
                    log::info!("walletd ready at {}", url);
                    Some(url)
                }
                Err(e) => {
                    log::warn!("walletd failed: {} — running without walletd", e);
                    None
                }
            };

            if let Some(ref url) = walletd_url {
                let addr = fetch_wallet_address(url).await;
                log::info!("Wallet address: {}", addr);
            } else {
                log::warn!("No walletd — address/balance/sync unavailable");
            }

            // 3. Start Axum server (works with or without walletd)
            let bind = format!("{}:{}", cli.host, cli.port);
            server::run_server(walletd_url, &daemon_url, &bind).await?;

            wp.stop();
            fuegod_proc.stop();
        }

        Commands::Status => {
            println!("Wallet dir: {:?}", wallet_dir);
            let container_path = wallet_dir.join("fuego_wallet.container");
            println!("Container: {}", if container_path.exists() { "exists" } else { "not found" });
            println!("Use 'fuego-wallet serve' to start.");
        }
    }

    Ok(())
}

async fn fetch_wallet_address(walletd_url: &str) -> String {
    let client = reqwest::Client::new();
    let body = serde_json::json!({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "get_address",
        "params": {}
    });
    match client.post(format!("{}/json_rpc", walletd_url))
        .json(&body).send().await
    {
        Ok(resp) => {
            let val: serde_json::Value = resp.json().await.unwrap_or_default();
            val.get("result")
                .and_then(|r| r.get("address"))
                .and_then(|a| a.as_str())
                .unwrap_or("unknown")
                .to_string()
        }
        Err(e) => format!("error: {}", e),
    }
}
