use std::path::Path;
use std::process::{Child, Command, Stdio};

pub struct WalletdProcess {
    child: Option<Child>,
    port: u16,
}

impl WalletdProcess {
    pub fn new(port: u16) -> Self { Self { child: None, port } }
    pub fn rpc_url(&self) -> String { format!("http://127.0.0.1:{}", self.port) }

    pub async fn start(
        &mut self, daemon_host: &str, daemon_port: u16, container_file: &str,
    ) -> Result<String, String> {
        let (_, walletd_bin) = crate::release::ensure_binaries().await?;
        log::info!("Starting walletd: {}", walletd_bin.display());

        // Generate walletd container if it doesn't exist
        if !Path::new(container_file).exists() {
            log::info!("Generating walletd container at {}", container_file);
            let output = Command::new(&walletd_bin)
                .args([
                    "--generate-container",
                    "--container-file", container_file,
                    "--container-password", "fuego",
                    "--daemon-address", daemon_host,
                    "--daemon-port", &daemon_port.to_string(),
                ])
                .output().map_err(|e| format!("generate container: {}", e))?;
            if !output.status.success() {
                let stderr = String::from_utf8_lossy(&output.stderr);
                return Err(format!("generate container failed: {}", stderr));
            }
            log::info!("Walletd container generated");
        }

        let mut child = Command::new(&walletd_bin)
            .args([
                "--daemon-address", daemon_host,
                "--daemon-port", &daemon_port.to_string(),
                "--container-file", container_file,
                "--container-password", "fuego",
                "--bind-port", &self.port.to_string(),
                "--bind-address", "127.0.0.1",
                "--log-level", "2",
            ])
            .stdout(Stdio::piped()).stderr(Stdio::piped())
            .spawn().map_err(|e| format!("spawn: {}", e))?;

        // Drain stdout/stderr so child doesn't block on pipe buffer
        if let Some(stdout) = child.stdout.take() {
            std::thread::spawn(move || {
                use std::io::Read;
                let mut reader = std::io::BufReader::new(stdout);
                let mut buf = [0u8; 1024];
                loop {
                    if reader.read(&mut buf).is_err() { break; }
                }
            });
        }
        if let Some(stderr) = child.stderr.take() {
            std::thread::spawn(move || {
                use std::io::Read;
                let mut reader = std::io::BufReader::new(stderr);
                let mut buf = [0u8; 1024];
                loop {
                    if reader.read(&mut buf).is_err() { break; }
                }
            });
        }

        self.child = Some(child);
        Self::wait_ready(self.rpc_url(), 30).await?;
        log::info!("walletd ready on port {}", self.port);
        Ok(self.rpc_url())
    }

    async fn wait_ready(url: String, max_secs: u32) -> Result<(), String> {
        let client = reqwest::Client::new();
        let body = serde_json::json!({
            "jsonrpc": "2.0",
            "id": "1",
            "method": "getBalance",
            "params": {}
        });
        for _ in 0..max_secs {
            if let Ok(resp) = client.post(format!("{}/json_rpc", url))
                .json(&body).send().await
            {
                if resp.status().is_success() {
                    let val: serde_json::Value = resp.json().await.unwrap_or_default();
                    if val.get("result").is_some() {
                        return Ok(());
                    }
                }
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
