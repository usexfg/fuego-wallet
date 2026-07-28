use std::io::Read;
use std::path::PathBuf;

fn release_asset_name() -> &'static str {
    #[cfg(target_os = "macos")]
    {
        if cfg!(target_arch = "aarch64") {
            "fuego-cli-macOS-apple"
        } else {
            "fuego-cli-macOS-intel"
        }
    }
    #[cfg(target_os = "linux")]
    {
        "fuego-cli-Linux"
    }
    #[cfg(target_os = "windows")]
    {
        "fuego-cli-Windows"
    }
    #[cfg(not(any(target_os = "macos", target_os = "linux", target_os = "windows")))]
    {
        "fuego-cli-macOS-apple"
    }
}

pub async fn ensure_binaries() -> Result<(PathBuf, PathBuf), String> {
    let base = default_path();
    let fuegod_name = if cfg!(target_os = "windows") { "fuegod.exe" } else { "fuegod" };
    let walletd_name = if cfg!(target_os = "windows") { "walletd.exe" } else { "walletd" };
    let fuegod_path = base.join(fuegod_name);
    let walletd_path = base.join(walletd_name);

    if fuegod_path.exists() && walletd_path.exists() {
        return Ok((fuegod_path, walletd_path));
    }

    log::info!("Binaries not found — downloading fuego-suite release...");

    let tag = get_latest_tag().await?;
    let asset_name = format!("{}-v{}.zip", release_asset_name(), tag);
    let url = format!(
        "https://github.com/usexfg/fuego-suite/releases/download/{}/{}",
        tag, asset_name
    );

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(600))
        .build().map_err(|e| format!("http: {}", e))?;

    let resp = client.get(&url).send().await.map_err(|e| format!("download: {}", e))?;
    if !resp.status().is_success() { return Err(format!("HTTP {}", resp.status())); }

    let bytes = resp.bytes().await.map_err(|e| format!("read: {}", e))?;
    let cursor = std::io::Cursor::new(bytes);
    let mut archive = zip::ZipArchive::new(cursor).map_err(|e| format!("zip: {}", e))?;

    for i in 0..archive.len() {
        let mut file = archive.by_index(i).map_err(|e| format!("zip entry: {}", e))?;
        let name = file.name().to_string();
        let base_name = std::path::Path::new(&name)
            .file_name().and_then(|n| n.to_str()).unwrap_or("");

        let canonical = base_name.trim_end_matches(".exe");
        if canonical == "fuegod" || canonical == "walletd" {
            let target_name = if cfg!(target_os = "windows") {
                format!("{}.exe", canonical)
            } else {
                canonical.to_string()
            };
            let dest = base.join(&target_name);
            let mut data = Vec::new();
            file.read_to_end(&mut data).map_err(|e| format!("read zip: {}", e))?;
            std::fs::write(&dest, &data).map_err(|e| format!("write: {}", e))?;
            #[cfg(unix)] {
                use std::os::unix::fs::PermissionsExt;
                std::fs::set_permissions(&dest, std::fs::Permissions::from_mode(0o755)).ok();
            }
            log::info!("Extracted {} from release", base_name);
        }
    }

    Ok((fuegod_path, walletd_path))
}

async fn get_latest_tag() -> Result<String, String> {
    let client = reqwest::Client::new();
    let resp = client
        .get("https://api.github.com/repos/usexfg/fuego-suite/releases/latest")
        .header("User-Agent", "fuego-wallet")
        .send().await.map_err(|e| format!("api: {}", e))?;
    let json: serde_json::Value = resp.json().await.map_err(|e| format!("json: {}", e))?;
    json["tag_name"].as_str()
        .map(|s| s.to_string())
        .ok_or("no tag_name".into())
}

fn default_path() -> PathBuf {
    std::env::current_exe().ok()
        .and_then(|p| p.parent().map(|d| d.to_path_buf()))
        .unwrap_or_else(|| PathBuf::from("."))
}
