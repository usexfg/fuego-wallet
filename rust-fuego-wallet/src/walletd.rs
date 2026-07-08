use std::path::PathBuf;
use std::process::{Child, Command, Stdio};

pub struct WalletdProcess {
    child: Option<Child>,
    port: u16,
}

impl WalletdProcess {
    pub fn new(port: u16) -> Self { Self { child: None, port } }
    pub fn rpc_url(&self) -> String { format!("http://127.0.0.1:{}", self.port) }

    pub async fn start(
        &mut self, daemon_host: &str, daemon_port: u16, wallet_file: &str,
    ) -> Result<String, String> {
        let (_, walletd) = crate::release::ensure_binaries().await?;
        log::info!("Starting walletd: {}", walletd.display());

        let child = Command::new(&walletd)
            .args([
                "--daemon-address", daemon_host,
                "--daemon-port", &daemon_port.to_string(),
                "--container-file", wallet_file,
                "--container-password", "fuego",
                "--bind-port", &self.port.to_string(),
                "--bind-address", "127.0.0.1",
                "--log-level", "2",
            ])
            .stdout(Stdio::piped()).stderr(Stdio::piped())
            .spawn().map_err(|e| format!("spawn: {}", e))?;

        self.child = Some(child);
        Self::wait_ready(self.rpc_url(), 30).await?;
        log::info!("walletd ready on port {}", self.port);
        Ok(self.rpc_url())
    }

    async fn wait_ready(url: String, max_secs: u32) -> Result<(), String> {
        let check = format!("{}/json_rpc", url);
        for _ in 0..max_secs {
            if let Ok(resp) = reqwest::get(&check).await {
                if resp.status().is_success() { return Ok(()); }
            }
            tokio::time::sleep(std::time::Duration::from_secs(1)).await;
        }
        Err(format!("walletd not ready after {}s", max_secs))
    }

    pub fn stop(&mut self) {
        if let Some(mut c) = self.child.take() { let _ = c.kill(); let _ = c.wait(); }
    }
}

impl Drop for WalletdProcess { fn drop(&mut self) { self.stop(); } }
