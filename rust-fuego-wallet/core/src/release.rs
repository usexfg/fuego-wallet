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

/// Candidate directories for bundled backend binaries.
///
/// Covers every layout the app can be shipped in:
/// - Standalone binary next to the main executable (dev builds, `flutter run`)
/// - macOS app bundle helper dir: `Contents/Resources/bin`
/// - Conventional `bin/` sibling of the executable
/// - Current working directory (worst case)
/// - Every directory on `PATH` (dev machines where `fuegod` is installed
///   system-wide, e.g. `/opt/homebrew/bin`, or lives in build dirs)
fn candidate_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    let exe = exe_dir();

    dirs.push(exe.clone());                    // exe dir (target/release, Contents/MacOS)
    dirs.push(exe.join("../Resources/bin"));   // macOS bundle: Contents/Resources/bin
    dirs.push(exe.join("../bin"));             // generic bundle layout
    dirs.push(PathBuf::from("."));             // cwd

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

/// Legacy pair lookup used by old call sites; maps to the new discovery.
pub async fn ensure_binaries() -> Result<(PathBuf, PathBuf), String> {
    Ok((find_fuegod()?, find_walletd()?))
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