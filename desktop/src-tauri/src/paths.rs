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

pub fn bundled_hypercluster_bin() -> Option<PathBuf> {
    let exe = env::current_exe().ok()?;
    let candidate = exe
        .parent()?
        .parent()?
        .join("Resources/hypercluster-runtime/hypercluster");
    if candidate.is_file() {
        Some(candidate)
    } else {
        None
    }
}

pub fn resolve_hypercluster_bin(settings_bin: Option<&str>) -> PathBuf {
    if let Some(b) = settings_bin {
        if !b.is_empty() && Path::new(b).exists() {
            return PathBuf::from(b);
        }
    }
    if let Some(b) = bundled_hypercluster_bin() {
        return b;
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

/// Homebrew bash 5 on Apple Silicon, then Intel Homebrew, then system bash.
pub fn resolve_bash() -> PathBuf {
    if cfg!(target_os = "macos") {
        for candidate in ["/opt/homebrew/bin/bash", "/usr/local/bin/bash"] {
            let p = PathBuf::from(candidate);
            if p.is_file() {
                return p;
            }
        }
    }
    PathBuf::from("/bin/bash")
}

/// PATH for hypercluster subprocesses when launched from the GUI (Finder/Dock).
/// macOS GUI apps inherit a minimal PATH — Homebrew tools are often missing.
#[cfg(target_os = "macos")]
pub fn macos_subprocess_path() -> String {
    let mut parts: Vec<String> = Vec::new();
    for p in [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/local/sbin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
    ] {
        if Path::new(p).is_dir() {
            parts.push(p.to_string());
        }
    }
    if let Ok(existing) = env::var("PATH") {
        for seg in existing.split(':').filter(|s| !s.is_empty()) {
            if !parts.iter().any(|p| p == seg) {
                parts.push(seg.to_string());
            }
        }
    }
    parts.join(":")
}

#[cfg(not(target_os = "macos"))]
pub fn macos_subprocess_path() -> String {
    env::var("PATH").unwrap_or_default()
}

/// Env vars applied to every hypercluster shell spawn (PATH, SSH agent, HOME).
pub fn shell_spawn_env() -> Vec<(String, String)> {
    let mut vars = vec![("PATH".into(), macos_subprocess_path())];
    if let Ok(sock) = env::var("SSH_AUTH_SOCK") {
        if !sock.is_empty() {
            vars.push(("SSH_AUTH_SOCK".into(), sock));
        }
    }
    if let Some(home) = dirs::home_dir() {
        vars.push(("HOME".into(), home.to_string_lossy().into_owned()));
    }
    vars
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn macos_path_includes_standard_prefixes() {
        let p = macos_subprocess_path();
        assert!(
            p.contains("/usr/bin") && p.contains("/bin"),
            "expected standard macOS PATH segments, got: {p}"
        );
        #[cfg(target_os = "macos")]
        assert!(
            p.contains("/opt/homebrew/bin") || p.contains("/usr/local/bin"),
            "expected Homebrew prefix in PATH, got: {p}"
        );
    }

    #[test]
    fn resolve_bash_prefers_homebrew_on_macos() {
        let bash = resolve_bash();
        #[cfg(target_os = "macos")]
        {
            let s = bash.to_string_lossy();
            assert!(
                s.contains("homebrew") || s == "/bin/bash",
                "unexpected bash path: {s}"
            );
        }
    }
}
