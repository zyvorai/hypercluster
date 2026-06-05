//! Cluster registry and cluster.conf I/O.

use crate::paths;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClusterEntry {
    pub id: String,
    pub name: String,
    pub config_path: String,
    pub distro: String,
    pub created_at: DateTime<Utc>,
    pub last_action: Option<String>,
    pub last_action_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub last_action_ok: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AppSettings {
    pub hypercluster_binary: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Registry {
    pub clusters: Vec<ClusterEntry>,
    pub settings: AppSettings,
}

impl Registry {
    pub fn load() -> Result<Self, String> {
        let path = paths::registry_path();
        if !path.exists() {
            return Ok(Self::default());
        }
        let raw = fs::read_to_string(&path).map_err(|e| e.to_string())?;
        serde_json::from_str(&raw).map_err(|e| e.to_string())
    }

    pub fn save(&self) -> Result<(), String> {
        let dir = paths::app_data_dir();
        fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
        let raw = serde_json::to_string_pretty(self).map_err(|e| e.to_string())?;
        fs::write(paths::registry_path(), raw).map_err(|e| e.to_string())
    }
}

pub fn read_cluster_conf(path: &str) -> Result<String, String> {
    fs::read_to_string(path).map_err(|e| e.to_string())
}

pub fn write_cluster_conf(path: &str, content: &str) -> Result<(), String> {
    if let Some(parent) = PathBuf::from(path).parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    fs::write(path, content).map_err(|e| e.to_string())
}

pub fn parse_cluster_name(conf: &str) -> Option<String> {
    for line in conf.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix("CLUSTER_NAME=") {
            let val = rest.trim().trim_matches('"').trim_matches('\'');
            if !val.is_empty() {
                return Some(val.to_string());
            }
        }
    }
    None
}

fn parse_distro(conf: &str) -> String {
    for line in conf.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix("K8S_DISTRO=") {
            let val = rest.trim().trim_matches('"').trim_matches('\'');
            return val.to_string();
        }
    }
    "k3s".to_string()
}

pub fn import_cluster_from_path(source: &str, name_override: Option<&str>) -> Result<ClusterEntry, String> {
    let content = fs::read_to_string(source).map_err(|e| format!("read {source}: {e}"))?;
    let name = name_override
        .map(|s| s.to_string())
        .or_else(|| parse_cluster_name(&content))
        .ok_or_else(|| "CLUSTER_NAME not found in cluster.conf".to_string())?;
    let distro = parse_distro(&content);
    create_cluster(&name, &content, &distro)
}

pub fn auto_import_repo_cluster(bin: &std::path::Path) -> Result<Option<ClusterEntry>, String> {
    let repo = bin.parent().ok_or("invalid hypercluster binary path")?;
    let conf = repo.join("cluster.conf");
    if !conf.is_file() {
        return Ok(None);
    }
    let content = fs::read_to_string(&conf).map_err(|e| e.to_string())?;
    let name = parse_cluster_name(&content).ok_or("CLUSTER_NAME missing in repo cluster.conf")?;
    let reg = Registry::load()?;
    if reg.clusters.iter().any(|c| c.name == name) {
        return Ok(None);
    }
    Ok(Some(import_cluster_from_path(
        conf.to_str().ok_or("invalid cluster.conf path")?,
        None,
    )?))
}

pub fn create_cluster(name: &str, conf_content: &str, distro: &str) -> Result<ClusterEntry, String> {
    let cluster_dir = paths::clusters_dir().join(name);
    fs::create_dir_all(&cluster_dir).map_err(|e| e.to_string())?;
    let conf_path = cluster_dir.join("cluster.conf");
    fs::write(&conf_path, conf_content).map_err(|e| e.to_string())?;

    let entry = ClusterEntry {
        id: Uuid::new_v4().to_string(),
        name: name.to_string(),
        config_path: conf_path.to_string_lossy().to_string(),
        distro: distro.to_string(),
        created_at: Utc::now(),
        last_action: None,
        last_action_at: None,
        last_action_ok: None,
    };

    let mut reg = Registry::load()?;
    reg.clusters.retain(|c| c.name != name);
    reg.clusters.push(entry.clone());
    reg.save()?;
    Ok(entry)
}

/// Update an existing registry cluster in place (preserves id and created_at).
pub fn update_cluster_by_path(
    config_path: &str,
    conf_content: &str,
    name: &str,
    distro: &str,
) -> Result<ClusterEntry, String> {
    write_cluster_conf(config_path, conf_content)?;
    let mut reg = Registry::load()?;
    let entry = reg
        .clusters
        .iter_mut()
        .find(|c| c.config_path == config_path)
        .ok_or_else(|| format!("No registry entry for config: {config_path}"))?;
    entry.name = name.to_string();
    entry.distro = distro.to_string();
    let out = entry.clone();
    reg.save()?;
    Ok(out)
}

pub fn update_cluster_action(name: &str, action: &str, ok: bool) -> Result<(), String> {
    let mut reg = Registry::load()?;
    if let Some(c) = reg.clusters.iter_mut().find(|c| c.name == name) {
        c.last_action = Some(action.to_string());
        c.last_action_at = Some(Utc::now());
        c.last_action_ok = Some(ok);
    }
    reg.save()
}

pub fn delete_cluster(name: &str) -> Result<(), String> {
    let mut reg = Registry::load()?;
    reg.clusters.retain(|c| c.name != name);
    reg.save()?;
    let dir = paths::clusters_dir().join(name);
    if dir.exists() {
        fs::remove_dir_all(&dir).map_err(|e| e.to_string())?;
    }
    Ok(())
}

pub fn save_settings(settings: AppSettings) -> Result<(), String> {
    let mut reg = Registry::load()?;
    reg.settings = settings;
    reg.save()
}

pub fn load_settings() -> AppSettings {
    Registry::load()
        .map(|r| r.settings)
        .unwrap_or_default()
}
