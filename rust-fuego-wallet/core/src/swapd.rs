//! xfg-swapd process management: the unified launcher story.
//!
//! fuegod carries the embedded XFG-side swap daemon (orderbook/trade RPCs on
//! the daemon port). The standalone `xfg-swapd` handles cross-chain HTLCs on
//! ports 18900/18901/18902 and needs a `--swap-config` JSON (chain RPC
//! endpoints + signer keys) before it is useful. This module mirrors
//! `fuegod.rs`: if a swap config is present (the GUI's Swap Settings screen
//! writes `<wallet_dir>/swap_config.json`), walletd launches xfg-swapd
//! alongside fuegod and reports its health.

use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

pub const SWAPD_RPC_PORT: u16 = 18902;

pub struct SwapdProcess {
    child: Child,
}

fn find_swapd_binary() -> Option<PathBuf> {
    if let Ok(b) = std::env::var("XFG_SWAPD_BIN") {
        let p = PathBuf::from(b);
        if p.exists() {
            return Some(p);
        }
    }
    // Sibling of the current executable (bundle layout).
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let sibling = dir.join("xfg-swapd");
            if sibling.exists() {
                return Some(sibling);
            }
        }
    }
    // PATH.
    if let Ok(path) = std::env::var("PATH") {
        for dir in path.split(':') {
            let p = PathBuf::from(dir).join("xfg-swapd");
            if p.is_file() {
                return Some(p);
            }
        }
    }
    None
}

/// Locate the swap config written by the GUI (SwapConfigService), or a
/// fallback in ~/.xfg-swapd.
pub fn find_swap_config(wallet_dir: &PathBuf) -> Option<PathBuf> {
    let primary = wallet_dir.join("swap_config.json");
    if primary.exists() {
        return Some(primary);
    }
    let fallback = std::env::var("HOME")
        .map(|h| PathBuf::from(h).join(".xfg-swapd").join("swap_config.json"))
        .ok();
    if let Some(f) = fallback {
        if f.exists() {
            return Some(f);
        }
    }
    None
}

/// True if xfg-swapd answers on its JSON-RPC port.
pub async fn swapd_healthy(rpc_port: u16) -> bool {
    let url = format!("http://127.0.0.1:{}/health", rpc_port);
    let Ok(client) = reqwest::Client::builder()
        .timeout(Duration::from_secs(3))
        .build()
    else {
        return false;
    };
    if let Ok(resp) = client.get(&url).send().await {
        if resp.status().is_success() {
            return true;
        }
    }
    // JSON-RPC getHealth fallback (unified-mode contract).
    let url = format!("http://127.0.0.1:{}/json_rpc", rpc_port);
    let Ok(resp) = client
        .post(&url)
        .json(&serde_json::json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getHealth",
            "params": {},
        }))
        .send()
        .await
    else {
        return false;
    };
    resp.status().is_success()
}

impl SwapdProcess {
    /// Spawn xfg-swapd in service mode. `config_path` must exist.
    pub fn start(
        config_path: &PathBuf,
        fuegod_host: &str,
        fuegod_port: u16,
        testnet: bool,
    ) -> Result<Self, String> {
        let binary = find_swapd_binary().ok_or_else(|| {
            "xfg-swapd binary not found (set XFG_SWAPD_BIN or place it next to fuego_walletd)"
                .to_string()
        })?;
        if !config_path.exists() {
            return Err(format!("swap config not found: {}", config_path.display()));
        }

        let mut cmd = Command::new(&binary);
        cmd.arg("--service")
            .arg("--swap-config")
            .arg(config_path)
            .arg("--fuegod-host")
            .arg(fuegod_host)
            .arg("--fuegod-port")
            .arg(fuegod_port.to_string());
        if testnet {
            cmd.arg("--testnet");
        }
        cmd.stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        let child = cmd.spawn().map_err(|e| format!("spawn xfg-swapd: {e}"))?;
        Ok(Self { child })
    }

    /// Wait for the swap daemon to answer on its RPC port.
    pub async fn wait_ready(&self, timeout: Duration) -> bool {
        let deadline = Instant::now() + timeout;
        while Instant::now() < deadline {
            if swapd_healthy(SWAPD_RPC_PORT).await {
                return true;
            }
            tokio::time::sleep(Duration::from_millis(500)).await;
        }
        false
    }

    pub fn stop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

impl Drop for SwapdProcess {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}
