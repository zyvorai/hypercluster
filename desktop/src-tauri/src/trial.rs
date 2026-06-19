//! 30-day trial for Hypercluster Desktop.
//!
//! Trial start is stored in the OS credential store (macOS Keychain, Windows Credential Manager,
//! Linux SecretService) via the `keyring` crate, with a `~/.hypercluster/trial.json` mirror.
//! Reinstalling the app does not reset the trial.

use crate::license;
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

pub const TRIAL_DAYS: i64 = 30;
pub const SALES_EMAIL: &str = "sales@zyvor.dev";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrialRecord {
    pub trial_started_at: String,
    pub trial_days: i64,
    pub machine_id: String,
    pub product: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CommercialLicense {
    pub license_id: String,
    pub issued_to: String,
    pub issued_at: String,
    pub product: String,
    pub licensor: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrialStatus {
    pub active: bool,
    pub expired: bool,
    pub licensed: bool,
    pub days_remaining: i64,
    pub trial_started_at: Option<String>,
    pub trial_ends_at: Option<String>,
    pub sales_email: String,
    pub trial_days: i64,
}

const KEYCHAIN_SERVICE: &str = "dev.zyvor.hypercluster.desktop.trial";
const KEYCHAIN_ACCOUNT: &str = "trial";

pub fn trial_dir() -> PathBuf {
    license::license_dir()
}

pub fn trial_record_path() -> PathBuf {
    trial_dir().join("trial.json")
}

pub fn commercial_license_path() -> PathBuf {
    trial_dir().join("commercial-license.json")
}

pub fn machine_id() -> String {
    #[cfg(target_os = "macos")]
    {
        if let Ok(out) = std::process::Command::new("ioreg")
            .args(["-rd1", "-c", "IOPlatformExpertDevice"])
            .output()
        {
            let text = String::from_utf8_lossy(&out.stdout);
            for line in text.lines() {
                if line.contains("IOPlatformUUID") {
                    if let Some(uuid) = line.split('"').nth(3) {
                        return uuid.to_string();
                    }
                }
            }
        }
    }
    #[cfg(target_os = "windows")]
    {
        if let Some(guid) = windows_machine_guid() {
            return guid;
        }
    }
    format!("host-{}", hostname())
}

#[cfg(target_os = "windows")]
fn windows_machine_guid() -> Option<String> {
    use winreg::enums::HKEY_LOCAL_MACHINE;
    use winreg::RegKey;
    let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
    let key = hklm
        .open_subkey("SOFTWARE\\Microsoft\\Cryptography")
        .ok()?;
    key.get_value("MachineGuid").ok()
}

fn hostname() -> String {
    std::env::var("HOSTNAME")
        .or_else(|_| std::process::Command::new("hostname").output().map(|o| {
            String::from_utf8_lossy(&o.stdout).trim().to_string()
        }))
        .unwrap_or_else(|_| "unknown".to_string())
}

fn read_keychain_trial() -> Option<TrialRecord> {
    let entry = keyring::Entry::new(KEYCHAIN_SERVICE, KEYCHAIN_ACCOUNT).ok()?;
    let raw = entry.get_password().ok()?;
    serde_json::from_str(&raw).ok()
}

fn write_keychain_trial(record: &TrialRecord) -> Result<(), String> {
    let json = serde_json::to_string(record).map_err(|e| e.to_string())?;
    let entry = keyring::Entry::new(KEYCHAIN_SERVICE, KEYCHAIN_ACCOUNT)
        .map_err(|e| e.to_string())?;
    entry.set_password(&json).map_err(|e| e.to_string())
}

fn read_file_trial() -> Option<TrialRecord> {
    let path = trial_record_path();
    let raw = fs::read_to_string(path).ok()?;
    serde_json::from_str(&raw).ok()
}

fn write_file_trial(record: &TrialRecord) -> Result<(), String> {
    fs::create_dir_all(trial_dir()).map_err(|e| e.to_string())?;
    let raw = serde_json::to_string_pretty(record).map_err(|e| e.to_string())?;
    fs::write(trial_record_path(), format!("{raw}\n")).map_err(|e| e.to_string())
}

fn load_trial_record() -> Option<TrialRecord> {
    match (read_keychain_trial(), read_file_trial()) {
        (Some(kc), Some(file)) => {
            let kc_start = parse_rfc3339(&kc.trial_started_at).ok()?;
            let file_start = parse_rfc3339(&file.trial_started_at).ok()?;
            if kc_start <= file_start {
                Some(kc)
            } else {
                Some(file)
            }
        }
        (Some(kc), None) => Some(kc),
        (None, Some(file)) => Some(file),
        (None, None) => None,
    }
}

fn persist_trial(record: &TrialRecord) -> Result<(), String> {
    write_file_trial(record)?;
    write_keychain_trial(record)?;
    Ok(())
}

fn parse_rfc3339(s: &str) -> Result<DateTime<Utc>, String> {
    DateTime::parse_from_rfc3339(s)
        .map(|dt| dt.with_timezone(&Utc))
        .map_err(|e| e.to_string())
}

pub fn commercial_license_valid() -> bool {
    let path = commercial_license_path();
    if !path.is_file() {
        return false;
    }
    let raw = match fs::read_to_string(&path) {
        Ok(r) => r,
        Err(_) => return false,
    };
    let lic: CommercialLicense = match serde_json::from_str(&raw) {
        Ok(l) => l,
        Err(_) => return false,
    };
    !lic.license_id.is_empty()
        && !lic.issued_to.is_empty()
        && lic.product == "Hypercluster Desktop"
}

/// Start the trial if none exists. Never resets an existing trial.
pub fn trial_ensure_started() -> Result<TrialRecord, String> {
    if let Some(existing) = load_trial_record() {
        // Repair mirror if one store is missing.
        let _ = persist_trial(&existing);
        return Ok(existing);
    }
    let record = TrialRecord {
        trial_started_at: Utc::now().to_rfc3339(),
        trial_days: TRIAL_DAYS,
        machine_id: machine_id(),
        product: "Hypercluster Desktop".into(),
    };
    persist_trial(&record)?;
    Ok(record)
}

pub fn trial_status() -> TrialStatus {
    if commercial_license_valid() {
        return TrialStatus {
            active: true,
            expired: false,
            licensed: true,
            days_remaining: TRIAL_DAYS,
            trial_started_at: None,
            trial_ends_at: None,
            sales_email: SALES_EMAIL.into(),
            trial_days: TRIAL_DAYS,
        };
    }

    let Some(record) = load_trial_record() else {
        return TrialStatus {
            active: true,
            expired: false,
            licensed: false,
            days_remaining: TRIAL_DAYS,
            trial_started_at: None,
            trial_ends_at: None,
            sales_email: SALES_EMAIL.into(),
            trial_days: TRIAL_DAYS,
        };
    };

    let started = match parse_rfc3339(&record.trial_started_at) {
        Ok(dt) => dt,
        Err(_) => {
            return TrialStatus {
                active: false,
                expired: true,
                licensed: false,
                days_remaining: 0,
                trial_started_at: Some(record.trial_started_at),
                trial_ends_at: None,
                sales_email: SALES_EMAIL.into(),
                trial_days: TRIAL_DAYS,
            };
        }
    };

    let ends = started + Duration::days(record.trial_days);
    let now = Utc::now();
    let remaining_ms = (ends - now).num_milliseconds();
    let days_remaining = if remaining_ms <= 0 {
        0
    } else {
        ((remaining_ms as f64) / (86_400_000.0)).ceil() as i64
    };
    let expired = now >= ends;

    TrialStatus {
        active: !expired,
        expired,
        licensed: false,
        days_remaining,
        trial_started_at: Some(record.trial_started_at),
        trial_ends_at: Some(ends.to_rfc3339()),
        sales_email: SALES_EMAIL.into(),
        trial_days: TRIAL_DAYS,
    }
}

pub fn trial_is_usable() -> bool {
    let status = trial_status();
    status.active || status.licensed
}

pub fn trial_require_active() -> Result<(), String> {
    if trial_is_usable() {
        return Ok(());
    }
    Err(format!(
        "Your {TRIAL_DAYS}-day trial has expired. Contact {SALES_EMAIL} for a license."
    ))
}

pub fn activate_commercial_license(license_id: String, issued_to: String) -> Result<(), String> {
    if license_id.trim().is_empty() || issued_to.trim().is_empty() {
        return Err("License ID and issued-to name are required".to_string());
    }
    fs::create_dir_all(trial_dir()).map_err(|e| e.to_string())?;
    let lic = CommercialLicense {
        license_id: license_id.trim().to_string(),
        issued_to: issued_to.trim().to_string(),
        issued_at: Utc::now().to_rfc3339(),
        product: "Hypercluster Desktop".into(),
        licensor: "ZyvorAI Labs Private Limited".into(),
    };
    let raw = serde_json::to_string_pretty(&lic).map_err(|e| e.to_string())?;
    fs::write(commercial_license_path(), format!("{raw}\n")).map_err(|e| e.to_string())
}

