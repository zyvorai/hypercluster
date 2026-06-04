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
    };

    let mut reg = Registry::load()?;
    reg.clusters.retain(|c| c.name != name);
    reg.clusters.push(entry.clone());
    reg.save()?;
    Ok(entry)
}

pub fn update_cluster_action(name: &str, action: &str) -> Result<(), String> {
    let mut reg = Registry::load()?;
    if let Some(c) = reg.clusters.iter_mut().find(|c| c.name == name) {
        c.last_action = Some(action.to_string());
        c.last_action_at = Some(Utc::now());
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
