//! Resolve hypercluster binary and app data directories.

use std::env;
use std::path::{Path, PathBuf};

pub fn app_data_dir() -> PathBuf {
    if cfg!(target_os = "macos") {
        dirs::home_dir()
            .map(|h| h.join("Library/Application Support/Hypercluster"))
            .unwrap_or_else(|| PathBuf::from(".hypercluster"))
    } else {
        dirs::data_dir()
            .unwrap_or_else(|| PathBuf::from("."))
            .join("Hypercluster")
    }
}

pub fn registry_path() -> PathBuf {
    app_data_dir().join("clusters.json")
}

pub fn clusters_dir() -> PathBuf {
    app_data_dir().join("clusters")
}

pub fn settings_path() -> PathBuf {
    app_data_dir().join("settings.json")
}

pub fn resolve_hypercluster_bin(settings_bin: Option<&str>) -> PathBuf {
    if let Some(b) = settings_bin {
        if !b.is_empty() && Path::new(b).exists() {
            return PathBuf::from(b);
        }
    }
    if let Ok(b) = env::var("HYPERCLUSTER_BIN") {
        if Path::new(&b).exists() {
            return PathBuf::from(b);
        }
    }
    if let Ok(cwd) = env::current_dir() {
        for candidate in [
            cwd.join("../hypercluster"),
            cwd.join("../../hypercluster"),
            cwd.join("hypercluster"),
        ] {
            if candidate.exists() {
                return candidate;
            }
        }
    }
    if let Some(home) = dirs::home_dir() {
        let local = home.join("tt/hypercluster/hypercluster");
        if local.exists() {
            return local;
        }
    }
    PathBuf::from("hypercluster")
}

pub fn resolve_bash() -> PathBuf {
    if cfg!(target_os = "macos") {
        let brew = PathBuf::from("/opt/homebrew/bin/bash");
        if brew.exists() {
            return brew;
        }
    }
    PathBuf::from("/bin/bash")
}
