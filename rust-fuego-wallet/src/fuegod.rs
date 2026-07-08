use std::path::PathBuf;
use std::process::{Child, Command, Stdio};

pub struct DaemonProcess {
    child: Option<Child>,
    port: u16,
}

impl DaemonProcess {
    pub fn new(port: u16) -> Self { Self { child: None, port } }

    pub fn rpc_url(&self) -> String { format!("http://127.0.0.1:{}", self.port) }

    pub async fn ensure_binary() -> Result<PathBuf, String> {
        let name = Self::binary_name();
        let target = Self::default_path().join(&name);
        if target.exists() { return Ok(target); }

        log::info!("fuegod not found — downloading from fuego-suite releases...");
        let url = format!(
            "https://github.com/usexfg/fuego-suite/releases/latest/download/{}", name
        );

        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(600))
            .build().map_err(|e| format!("http: {}", e))?;

        let resp = client.get(&url).send().await.map_err(|e| format!("download: {}", e))?;
        if !resp.status().is_success() { return Err(format!("HTTP {}", resp.status())); }

        let bytes = resp.bytes().await.map_err(|e| format!("read: {}", e))?;
        if let Some(p) = target.parent() { std::fs::create_dir_all(p).ok(); }
        std::fs::write(&target, &bytes).map_err(|e| format!("write: {}", e))?;

        #[cfg(unix)] {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&target, std::fs::Permissions::from_mode(0o755)).ok();
        }
        log::info!("fuegod downloaded to {}", target.display());
        Ok(target)
    }

    pub async fn start(&mut self, testnet: bool, data_dir: &str) -> Result<String, String> {
        let binary = Self::ensure_binary().await?;
        std::fs::create_dir_all(data_dir).map_err(|e| format!("mkdir: {}", e))?;

        let port_str = self.port.to_string();
        let mut args = vec![
            "--data-dir", data_dir,
            "--rpc-bind-port", &port_str,
            "--rpc-bind-ip", "127.0.0.1",
            "--log-level", "1",
        ];
        if testnet { args.push("--testnet"); }

        log::info!("Starting fuegod: {} {:?}", binary.display(), args);
        let child = Command::new(&binary).args(&args)
            .stdout(Stdio::piped()).stderr(Stdio::piped())
            .spawn().map_err(|e| format!("spawn: {}", e))?;

        self.child = Some(child);
        Self::wait_ready(self.rpc_url(), 60).await?;
        log::info!("fuegod ready on port {}", self.port);
        Ok(self.rpc_url())
    }

    async fn wait_ready(url: String, max_secs: u32) -> Result<(), String> {
        let check = format!("{}/getinfo", url);
        for _ in 0..max_secs {
            if let Ok(resp) = reqwest::get(&check).await {
                if resp.status().is_success() { return Ok(()); }
            }
            tokio::time::sleep(std::time::Duration::from_secs(2)).await;
        }
        Err(format!("fuegod not ready after {}s", max_secs))
    }

    pub fn stop(&mut self) {
        if let Some(mut c) = self.child.take() { let _ = c.kill(); let _ = c.wait(); }
    }

    fn binary_name() -> String {
        let os = if cfg!(target_os = "macos") { "macos" }
            else if cfg!(target_os = "linux") { "linux" } else { "windows" };
        let arch = if cfg!(target_arch = "aarch64") { "arm64" } else { "x86_64" };
        let ext = if cfg!(windows) { ".exe" } else { "" };
        format!("fuegod-{}-{}{}", os, arch, ext)
    }

    fn default_path() -> PathBuf {
        std::env::current_exe().ok().and_then(|p| p.parent().map(|d| d.to_path_buf()))
            .unwrap_or_else(|| PathBuf::from("."))
    }
}

impl Drop for DaemonProcess { fn drop(&mut self) { self.stop(); } }
