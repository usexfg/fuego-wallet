use std::path::{Path, PathBuf};
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

    pub async fn ensure_binary() -> Result<PathBuf, String> {
        match Self::find_binary() {
            Ok(path) => return Ok(path),
            Err(_) => {}
        }

        log::info!("walletd not found locally — downloading from fuego-suite releases...");

        let name = Self::binary_name();
        let url = format!(
            "https://github.com/usexfg/fuego-suite/releases/latest/download/{}",
            name
        );

        let target = Self::default_binary_path().join(&name);

        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(300))
            .build()
            .map_err(|e| format!("http client: {}", e))?;

        let resp = client.get(&url).send().await
            .map_err(|e| format!("download walletd: {}", e))?;

        if !resp.status().is_success() {
            return Err(format!("download failed: HTTP {}", resp.status()));
        }

        let bytes = resp.bytes().await
            .map_err(|e| format!("read response: {}", e))?;

        if let Some(parent) = target.parent() {
            std::fs::create_dir_all(parent).ok();
        }

        std::fs::write(&target, &bytes)
            .map_err(|e| format!("write walletd: {}", e))?;

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&target, std::fs::Permissions::from_mode(0o755))
                .map_err(|e| format!("chmod: {}", e))?;
        }

        log::info!("walletd downloaded to {}", target.display());
        Ok(target)
    }

    pub async fn start(
        &mut self,
        daemon_host: &str,
        daemon_port: u16,
        wallet_file: &str,
    ) -> Result<String, String> {
        let binary = Self::ensure_binary().await?;
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

    fn binary_name() -> String {
        let os = if cfg!(target_os = "macos") { "macos" }
            else if cfg!(target_os = "linux") { "linux" }
            else { "windows" };
        let arch = if cfg!(target_arch = "aarch64") || cfg!(target_arch = "arm") { "arm64" }
            else { "x86_64" };
        let ext = if cfg!(windows) { ".exe" } else { "" };
        format!("fuego-walletd-{}-{}{}", os, arch, ext)
    }

    fn default_binary_path() -> PathBuf {
        std::env::current_exe()
            .ok()
            .and_then(|p| p.parent().map(|d| d.to_path_buf()))
            .unwrap_or_else(|| PathBuf::from("."))
    }

    fn find_binary() -> Result<PathBuf, String> {
        let name = Self::binary_name();
        let candidates: Vec<PathBuf> = [
            Some(Self::default_binary_path().join(&name)),
            std::env::current_exe().ok().and_then(|p| {
                // macOS app bundle: Contents/MacOS/fuego-wallet -> Resources/bin/walletd
                let app = p.parent()?.parent()?.parent()?;
                Some(app.join("Resources").join("bin").join(&name))
            }),
        ].into_iter().flatten().collect();

        for path in &candidates {
            if path.exists() {
                return Ok(path.clone());
            }
        }
        Err(format!("walletd '{}' not found", name))
    }
}

impl Drop for WalletdProcess {
    fn drop(&mut self) {
        self.stop();
    }
}
