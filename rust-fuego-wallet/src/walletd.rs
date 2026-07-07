use std::path::PathBuf;
use std::process::{Child, Command, Stdio};

pub struct WalletdProcess {
    child: Option<Child>,
    port: u16,
}

impl WalletdProcess {
    pub fn new(port: u16) -> Self {
        Self { child: None, port }
    }

    pub fn rpc_url(&self) -> String {
        format!("http://127.0.0.1:{}", self.port)
    }

    pub async fn start(
        &mut self,
        daemon_host: &str,
        daemon_port: u16,
        wallet_file: &str,
    ) -> Result<String, String> {
        let binary = Self::find_binary()?;
        log::info!("Starting walletd: {}", binary.display());

        let child = Command::new(&binary)
            .args([
                "--daemon-address", daemon_host,
                "--daemon-port", &daemon_port.to_string(),
                "--container-file", wallet_file,
                "--container-password", "fuego",
                "--bind-port", &self.port.to_string(),
                "--bind-address", "127.0.0.1",
                "--log-level", "2",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| format!("spawn walletd: {}", e))?;

        self.child = Some(child);
        Self::wait_ready(self.rpc_url(), 30).await?;
        log::info!("walletd ready on port {}", self.port);
        Ok(self.rpc_url())
    }

    async fn wait_ready(url: String, max_secs: u32) -> Result<(), String> {
        let check_url = format!("{}/json_rpc", url);
        for _ in 0..max_secs {
            match reqwest::get(&check_url).await {
                Ok(resp) if resp.status().is_success() => return Ok(()),
                _ => tokio::time::sleep(std::time::Duration::from_secs(1)).await,
            }
        }
        Err(format!("walletd not ready after {}s", max_secs))
    }

    pub fn stop(&mut self) {
        if let Some(mut child) = self.child.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }

    fn find_binary() -> Result<PathBuf, String> {
        let name = if cfg!(target_os = "windows") {
            "fuego-walletd-windows.exe"
        } else if cfg!(target_os = "macos") {
            if cfg!(target_arch = "aarch64") {
                "fuego-walletd-macos-arm64"
            } else {
                "fuego-walletd-macos-x86_64"
            }
        } else {
            if cfg!(target_arch = "x86_64") {
                "fuego-walletd-linux-x86_64"
            } else {
                "fuego-walletd-linux-arm64"
            }
        };

        let candidates: Vec<PathBuf> = [
            std::env::current_exe().ok().and_then(|p| p.parent().map(|d| d.join(name))),
            Some(PathBuf::from(name)),
            #[cfg(target_os = "macos")]
            std::env::current_exe().ok().and_then(|p| {
                // Resources/bin/walletd inside macOS app bundle
                p.parent()?.parent()?.parent()?.join("Resources").join("bin").join(name).into()
            }),
        ].into_iter().flatten().collect();

        for path in &candidates {
            if path.exists() {
                log::info!("Found walletd at: {}", path.display());
                return Ok(path.clone());
            }
        }

        Err(format!("walletd binary '{}' not found. Looked in: {:?}", name, candidates.iter().map(|p| p.display().to_string()).collect::<Vec<_>>()))
    }
}

impl Drop for WalletdProcess {
    fn drop(&mut self) {
        self.stop();
    }
}
