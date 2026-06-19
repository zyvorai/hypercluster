//! Zyvor license acceptance for Hypercluster Desktop.

use chrono::Utc;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LicenseRecord {
    pub accepted: bool,
    pub license_version: String,
    pub license_hash: String,
    pub accepted_at: String,
    pub accepted_by: String,
    pub product: String,
    pub licensor: String,
    pub brand: String,
}

pub fn license_dir() -> PathBuf {
    dirs::home_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join(".hypercluster")
}

pub fn license_record_path() -> PathBuf {
    license_dir().join("license-acceptance.json")
}

fn license_text_path() -> Option<PathBuf> {
    if let Ok(exe) = std::env::current_exe() {
        #[cfg(target_os = "macos")]
        // macOS .app bundle: exe is at Contents/MacOS/, resources at Contents/Resources/
        let resource_dirs: Vec<PathBuf> = exe
            .parent()
            .and_then(|p| p.parent())
            .map(|p| vec![p.join("Resources")])
            .unwrap_or_default();

        #[cfg(not(target_os = "macos"))]
        // NSIS (Windows): exe is at install_dir/, resources at install_dir/resources/
        // Linux AppImage / deb: exe is at usr/bin/, resources typically alongside
        let resource_dirs: Vec<PathBuf> = exe
            .parent()
            .map(|p| vec![p.to_path_buf(), p.join("resources")])
            .unwrap_or_default();

        for dir in &resource_dirs {
            let p = dir.join("HYPERCLUSTER-EULA.txt");
            if p.is_file() {
                return Some(p);
            }
        }
    }
    let dev = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../distribution/HYPERCLUSTER-EULA.txt");
    if dev.is_file() {
        return Some(dev);
    }
    None
}

pub fn license_hash() -> Result<String, String> {
    let path = license_text_path().ok_or_else(|| "EULA file not found".to_string())?;
    let bytes = fs::read(&path).map_err(|e| e.to_string())?;
    let digest = Sha256::digest(bytes);
    Ok(format!("{:x}", digest))
}

pub fn license_is_accepted() -> bool {
    let Ok(current) = license_hash() else {
        return false;
    };
    let path = license_record_path();
    if !path.is_file() {
        return false;
    }
    let raw = match fs::read_to_string(&path) {
        Ok(r) => r,
        Err(_) => return false,
    };
    let rec: LicenseRecord = match serde_json::from_str(&raw) {
        Ok(r) => r,
        Err(_) => return false,
    };
    rec.accepted && rec.license_hash == current
}

pub fn license_accept(actor: &str) -> Result<(), String> {
    let hash = license_hash()?;
    fs::create_dir_all(license_dir()).map_err(|e| e.to_string())?;
    let rec = LicenseRecord {
        accepted: true,
        license_version: "1.0".into(),
        license_hash: hash,
        accepted_at: Utc::now().to_rfc3339(),
        accepted_by: actor.to_string(),
        product: "Hypercluster Desktop".into(),
        licensor: "ZyvorAI Labs Private Limited".into(),
        brand: "zyvor.dev".into(),
    };
    let raw = serde_json::to_string_pretty(&rec).map_err(|e| e.to_string())?;
    fs::write(license_record_path(), format!("{raw}\n")).map_err(|e| e.to_string())
}

pub fn license_summary() -> Result<String, String> {
    let path = license_text_path().ok_or_else(|| "EULA file not found".to_string())?;
    let text = fs::read_to_string(&path).map_err(|e| e.to_string())?;
    Ok(text.lines().take(32).collect::<Vec<_>>().join("\n"))
}

#[cfg(target_os = "macos")]
pub fn host_cpu_arch() -> String {
    if macos_is_arm64_hardware() {
        return "arm64".to_string();
    }
    std::process::Command::new("uname")
        .arg("-m")
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|| "unknown".to_string())
}

#[cfg(target_os = "macos")]
fn macos_is_arm64_hardware() -> bool {
    let arm64_opt = std::process::Command::new("sysctl")
        .args(["-n", "hw.optional.arm64"])
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim() == "1")
        .unwrap_or(false);
    if arm64_opt {
        return true;
    }
    std::process::Command::new("sysctl")
        .args(["-n", "hw.machine"])
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim() == "arm64")
        .unwrap_or(false)
}

#[cfg(not(target_os = "macos"))]
pub fn host_cpu_arch() -> String {
    std::env::consts::ARCH.to_string()
}

pub fn macos_arm64_required() -> bool {
    #[cfg(target_os = "macos")]
    {
        !macos_is_arm64_hardware()
    }
    #[cfg(not(target_os = "macos"))]
    {
        false
    }
}
