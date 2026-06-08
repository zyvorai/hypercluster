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

#[cfg(target_os = "macos")]
fn macos_path_prefixes() -> Vec<&'static str> {
    vec![
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/opt/homebrew/opt/python@3.13/bin",
        "/opt/homebrew/opt/python@3.12/bin",
        "/opt/homebrew/opt/python@3.11/bin",
        "/opt/homebrew/opt/ansible/bin",
        "/usr/local/bin",
        "/usr/local/sbin",
        "/usr/local/opt/python@3.13/bin",
        "/usr/local/opt/python@3.12/bin",
        "/usr/local/opt/python@3.11/bin",
        "/usr/local/opt/ansible/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
    ]
}

#[cfg(not(target_os = "macos"))]
fn macos_path_prefixes() -> Vec<&'static str> {
    vec![]
}

/// Prefer Homebrew / modern Python (3.11+) for Kubespray/Ansible subprocesses.
pub fn resolve_python() -> Option<PathBuf> {
    if let Ok(p) = env::var("HYPERCLUSTER_PYTHON") {
        let pb = PathBuf::from(&p);
        if pb.is_file() {
            return Some(pb);
        }
    }

    #[cfg(target_os = "macos")]
    {
        let mut candidates: Vec<PathBuf> = Vec::new();
        for prefix in ["/opt/homebrew", "/usr/local"] {
            let base = PathBuf::from(prefix);
            for rel in [
                "bin/python3",
                "opt/python@3.13/bin/python3",
                "opt/python@3.12/bin/python3",
                "opt/python@3.11/bin/python3",
            ] {
                candidates.push(base.join(rel));
            }
        }
        for c in candidates {
            if c.is_file() {
                return Some(c);
            }
        }
    }

    for seg in env::var("PATH")
        .unwrap_or_default()
        .split(':')
        .filter(|s| !s.is_empty())
    {
        let p = PathBuf::from(seg).join("python3");
        if p.is_file() {
            return Some(p);
        }
    }
    None
}

/// PATH for hypercluster subprocesses when launched from the GUI (Finder/Dock).
/// macOS GUI apps inherit a minimal PATH — Homebrew tools are often missing.
pub fn macos_subprocess_path() -> String {
    let mut parts: Vec<String> = Vec::new();
    for p in macos_path_prefixes() {
        if Path::new(p).is_dir() {
            parts.push(p.to_string());
        }
    }
    if let Some(home) = dirs::home_dir() {
        for ver in ["3.13", "3.12", "3.11"] {
            let user_bin = home.join(format!("Library/Python/{ver}/bin"));
            if user_bin.is_dir() {
                let s = user_bin.to_string_lossy().into_owned();
                if !parts.iter().any(|p| p == &s) {
                    parts.push(s);
                }
            }
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
    let mut path = macos_subprocess_path();
    if let Some(py) = resolve_python() {
        if let Some(bin_dir) = py.parent() {
            let bin = bin_dir.to_string_lossy().into_owned();
            if !path.split(':').any(|seg| seg == bin) {
                path = format!("{bin}:{path}");
            }
        }
    }

    let mut vars = vec![("PATH".into(), path)];

    #[cfg(target_os = "macos")]
    {
        let data = app_data_dir();
        vars.push((
            "HYPERCLUSTER_DATA_DIR".into(),
            data.to_string_lossy().into_owned(),
        ));
    }

    if let Some(py) = resolve_python() {
        vars.push((
            "HYPERCLUSTER_PYTHON".into(),
            py.to_string_lossy().into_owned(),
        ));
    }

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
    fn macos_path_prefers_homebrew_before_system() {
        #[cfg(target_os = "macos")]
        {
            let p = macos_subprocess_path();
            if p.contains("/opt/homebrew/bin") {
                let brew = p.find("/opt/homebrew/bin").unwrap();
                let usr = p.find("/usr/bin").unwrap_or(usize::MAX);
                assert!(brew < usr, "Homebrew should precede /usr/bin, got: {p}");
            }
        }
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

    #[test]
    fn shell_spawn_env_sets_data_dir_on_macos() {
        let vars = shell_spawn_env();
        assert!(vars.iter().any(|(k, _)| k == "PATH"));
        #[cfg(target_os = "macos")]
        assert!(
            vars.iter()
                .any(|(k, v)| k == "HYPERCLUSTER_DATA_DIR" && v.contains("Hypercluster")),
            "expected HYPERCLUSTER_DATA_DIR in shell env"
        );
    }
}
