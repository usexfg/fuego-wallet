use std::io::Read;
use std::path::{Path, PathBuf};

fn bin_name(name: &str) -> String {
    if cfg!(target_os = "windows") {
        format!("{}.exe", name)
    } else {
        name.to_string()
    }
}

fn exe_dir() -> PathBuf {
    std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|d| d.to_path_buf()))
        .unwrap_or_else(|| PathBuf::from("."))
}

/// Per-OS/arch asset prefix used by fuego-suite release archives
/// (e.g. `fuego-cli-macOS-apple-v1.10.12.zip`).
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

/// User-writable directory where missing binaries are downloaded on first run.
fn download_dir() -> Option<PathBuf> {
    let home = std::env::var_os("HOME").map(PathBuf::from)?;
    #[cfg(target_os = "macos")]
    {
        Some(home.join("Library/Application Support/fuego-wallet/bin"))
    }
    #[cfg(not(target_os = "macos"))]
    {
        Some(home.join(".fuego-wallet/bin"))
    }
}

/// Candidate directories for bundled backend binaries.
///
/// Covers every layout the app can be shipped in:
/// - Standalone binary next to the main executable (dev builds, `flutter run`)
/// - macOS app bundle helper dir: `Contents/Resources/bin`
/// - Conventional `bin/` sibling of the executable
/// - Current working directory (worst case)
/// - The first-run download directory
/// - Every directory on `PATH` (dev machines where `fuegod` is installed
///   system-wide, e.g. `/opt/homebrew/bin`, or lives in build dirs)
fn candidate_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    let exe = exe_dir();

    dirs.push(exe.clone());                    // exe dir (target/release, Contents/MacOS)
    dirs.push(exe.join("../Resources/bin"));   // macOS bundle: Contents/Resources/bin
    dirs.push(exe.join("../bin"));             // generic bundle layout
    dirs.push(PathBuf::from("."));             // cwd

    if let Some(dir) = download_dir() {
        dirs.push(dir);                        // first-run download location
    }

    if let Some(path) = std::env::var_os("PATH") {
        for entry in std::env::split_paths(&path) {
            if !entry.as_os_str().is_empty() && !dirs.contains(&entry) {
                dirs.push(entry);
            }
        }
    }

    dirs
}

fn find_binary(name: &str, env_key: &str) -> Option<PathBuf> {
    // 1. Explicit override (used by the wallet app to point at the bundled copy).
    if let Ok(v) = std::env::var(env_key) {
        let p = PathBuf::from(&v);
        if p.is_file() {
            log::info!("Using {} from {}: {}", env_key, v, p.display());
            return Some(p);
        }
        log::warn!("{} set to {} but no file exists there", env_key, v);
    }

    // 2. Bundle-aware search.
    for dir in candidate_dirs() {
        let candidate = dir.join(bin_name(name));
        if candidate.is_file() {
            log::info!("Found {} at {}", name, candidate.display());
            return Some(candidate);
        }
    }

    // 3. Fallback: plain PATH lookup (e.g. fuegod installed via brew or in a build dir).
    if let Some(found) = find_binary_on_path(name) {
        log::info!("Found {} via PATH at {}", name, found.display());
        return Some(found);
    }
    None
}

/// Locate `name` in the directories listed in `PATH`.
fn find_binary_on_path(name: &str) -> Option<PathBuf> {
    let path = std::env::var_os("PATH")?;
    for entry in std::env::split_paths(&path) {
        let candidate = entry.join(bin_name(name));
        if candidate.is_file() {
            return Some(candidate);
        }
    }
    None
}

fn search_report(name: &str) -> String {
    let dirs = candidate_dirs()
        .into_iter()
        .map(|d| d.display().to_string())
        .collect::<Vec<_>>()
        .join(", ");
    format!(
        "{} not found (searched: {}). \
         Ship it next to the wallet binary, or set env {} to its absolute path.",
        name, dirs, format!("FUEGO_{}_BIN", name.to_uppercase())
    )
}

/// Locate the `fuegod` chain daemon binary. Never downloads anything.
pub fn find_fuegod() -> Result<PathBuf, String> {
    const ENV_KEY: &str = "FUEGO_FUEGOD_BIN";
    find_binary("fuegod", ENV_KEY).ok_or_else(|| search_report("fuegod"))
}

/// Locate the legacy C++ `walletd` binary (only needed by the legacy walletd path).
pub fn find_walletd() -> Result<PathBuf, String> {
    const ENV_KEY: &str = "FUEGO_WALLETD_BIN";
    // In the unified Rust architecture walletd == the running process itself;
    // accept "fuego_walletd" under either name.
    if let Ok(v) = std::env::var(ENV_KEY) {
        let p = PathBuf::from(&v);
        if p.is_file() {
            log::info!("Using walletd from {}: {}", ENV_KEY, v);
            return Ok(p);
        }
    }
    if let Some(p) = find_binary("fuego_walletd", "FUEGO_WALLETD_BIN") {
        return Ok(p);
    }
    if let Some(p) = find_binary("walletd", "FUEGO_WALLETD_BIN") {
        return Ok(p);
    }
    Err(search_report("walletd"))
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
        .ok_or_else(|| "no tag_name in latest release".into())
}

/// Download the fuego-suite release archive and extract `fuegod` + `walletd`
/// into `dest` (executable bit set). Never fails the caller silently: a
/// missing archive entry leaves the file absent, which the caller checks.
async fn download_and_extract(dest: &Path, tag: &str) -> Result<(), String> {
    let asset_name = format!("{}-v{}.zip", release_asset_name(), tag);
    let url = format!(
        "https://github.com/usexfg/fuego-suite/releases/download/{}/{}",
        tag, asset_name
    );
    log::info!("Downloading {}", url);

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
            let target_name = bin_name(canonical);
            let dest_path = dest.join(&target_name);
            let mut data = Vec::new();
            file.read_to_end(&mut data).map_err(|e| format!("read zip: {}", e))?;
            std::fs::write(&dest_path, &data).map_err(|e| format!("write: {}", e))?;
            mark_executable(&dest_path);
            log::info!("Extracted {} from release", base_name);
        }
    }
    Ok(())
}

/// Resolve `fuegod` + `walletd` from the bundle/PATH, and fall back to
/// downloading the fuego-suite release into the user-writable bin dir when
/// either is missing (clean machines without a bundled backend).
pub async fn ensure_binaries() -> Result<(PathBuf, PathBuf), String> {
    let fuegod = find_fuegod().ok();
    let walletd = find_walletd().ok();
    if let (Some(f), Some(w)) = (&fuegod, &walletd) {
        return Ok((f.clone(), w.clone()));
    }

    log::info!("Binaries not found locally — downloading fuego-suite release…");
    let dir = download_dir().ok_or("no HOME directory to store binaries")?;
    std::fs::create_dir_all(&dir).map_err(|e| format!("mkdir: {}", e))?;
    let tag = get_latest_tag().await?;
    download_and_extract(&dir, &tag).await?;

    let f = fuegod.unwrap_or_else(|| dir.join(bin_name("fuegod")));
    let w = walletd.unwrap_or_else(|| dir.join(bin_name("walletd")));
    if !f.is_file() || !w.is_file() {
        return Err(format!(
            "release archive for {} did not contain fuegod/walletd", tag
        ));
    }
    Ok((f, w))
}

/// True when a usable `fuegod` is discoverable right now.
pub fn fuegod_available() -> bool {
    find_binary("fuegod", "FUEGO_FUEGOD_BIN").is_some()
}

/// Ensure a file is executable on unix targets.
pub fn mark_executable(path: &Path) {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o755));
    }
}
