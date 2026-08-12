use std::io::Read;
use std::process::{Child, Command, Stdio};

pub struct DaemonProcess {
    child: Option<Child>,
    port: u16,
}

impl DaemonProcess {
    pub fn new(port: u16) -> Self { Self { child: None, port } }
    pub fn rpc_url(&self) -> String { format!("http://127.0.0.1:{}", self.port) }

    pub async fn start(&mut self, testnet: bool, data_dir: &str) -> Result<String, String> {
        let fuegod = crate::release::find_fuegod()?;
        std::fs::create_dir_all(data_dir).map_err(|e| format!("mkdir: {}", e))?;

        let port_str = self.port.to_string();
        let mut args = vec!["--data-dir", data_dir, "--rpc-bind-port", &port_str, "--rpc-bind-ip", "127.0.0.1", "--log-level", "1"];
        if testnet { args.push("--testnet"); }

        log::info!("Starting fuegod: {}", fuegod.display());
        let mut cmd = Command::new(&fuegod);
        cmd.args(&args)
            .stdout(Stdio::piped()).stderr(Stdio::piped());

        #[cfg(windows)]
        { cmd.creation_flags(0x08000000); } // CREATE_NO_WINDOW

        let mut child = cmd.spawn().map_err(|e| format!("spawn: {}", e))?;

        // fuegod logs heavily on a synced data dir. The pipe buffer is only
        // 64KB — if the parent never reads, fuegod blocks on write and never
        // binds its RPC port. Drain both pipes on dedicated threads and
        // forward the output to the wallet proxy's own log stream.
        drain_async(child.stdout.take(), "fuegod:out");
        drain_async(child.stderr.take(), "fuegod:err");

        self.child = Some(child);
        Self::wait_ready(self.rpc_url(), 120).await?;
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
}

#[cfg(unix)]
fn drain_async<R: Read + Send + 'static>(pipe: Option<R>, label: &'static str) {
    if let Some(mut p) = pipe {
        std::thread::spawn(move || {
            let mut buf = [0u8; 4096];
            loop {
                match p.read(&mut buf) {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        let line = String::from_utf8_lossy(&buf[..n]);
                        log::info!("{} {}", label, line.trim_end());
                    }
                }
            }
        });
    }
}

#[cfg(windows)]
fn drain_async<R: Read + Send + 'static>(pipe: Option<R>, label: &'static str) {
    if let Some(mut p) = pipe {
        std::thread::spawn(move || {
            let mut buf = [0u8; 4096];
            loop {
                match p.read(&mut buf) {
                    Ok(0) | Err(_) => break,
                    Ok(n) => {
                        let line = String::from_utf8_lossy(&buf[..n]);
                        log::info!("{} {}", label, line.trim_end());
                    }
                }
            }
        });
    }
}

impl Drop for DaemonProcess { fn drop(&mut self) { self.stop(); } }