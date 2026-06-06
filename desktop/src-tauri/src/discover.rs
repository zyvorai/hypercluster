//! Scan the filesystem for cluster.conf files and auto-import into the registry.

use crate::config::{import_cluster_from_path, parse_cluster_name, parse_distro, Registry};
use crate::paths;
use serde::Serialize;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DiscoveredCluster {
    pub path: String,
    pub name: String,
    pub distro: String,
    pub registered: bool,
}

fn push_candidate(paths: &mut HashSet<PathBuf>, candidate: PathBuf) {
    if candidate.is_file() {
        paths.insert(candidate);
    }
}

fn collect_config_paths(hypercluster_bin: Option<&Path>) -> HashSet<PathBuf> {
    let mut paths = HashSet::new();

    if let Some(home) = dirs::home_dir() {
        push_candidate(&mut paths, home.join("tt/hypercluster/cluster.conf"));
        push_candidate(&mut paths, home.join("cluster.conf"));
        let tt = home.join("tt");
        if let Ok(entries) = fs::read_dir(&tt) {
            for entry in entries.flatten() {
                push_candidate(&mut paths, entry.path().join("cluster.conf"));
            }
        }
    }

    if let Some(bin) = hypercluster_bin {
        if let Some(parent) = bin.parent() {
            push_candidate(&mut paths, parent.join("cluster.conf"));
            push_candidate(&mut paths, parent.join("../cluster.conf"));
        }
    }

    let clusters_dir = paths::clusters_dir();
    if clusters_dir.is_dir() {
        if let Ok(entries) = fs::read_dir(&clusters_dir) {
            for entry in entries.flatten() {
                push_candidate(&mut paths, entry.path().join("cluster.conf"));
            }
        }
    }

    paths
}

pub fn discover_cluster_configs(hypercluster_bin: Option<&Path>) -> Result<Vec<DiscoveredCluster>, String> {
    let registered: HashSet<String> = Registry::load()?
        .clusters
        .iter()
        .map(|c| c.config_path.clone())
        .collect();

    let mut out = Vec::new();
    for path in collect_config_paths(hypercluster_bin) {
        let path_str = path.to_string_lossy().to_string();
        let content = match fs::read_to_string(&path) {
            Ok(c) => c,
            Err(_) => continue,
        };
        let Some(name) = parse_cluster_name(&content) else {
            continue;
        };
        out.push(DiscoveredCluster {
            path: path_str.clone(),
            name,
            distro: parse_distro(&content),
            registered: registered.contains(&path_str),
        });
    }
    out.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(out)
}

pub fn auto_import_discovered(hypercluster_bin: Option<&Path>) -> Result<Vec<crate::config::ClusterEntry>, String> {
    let discovered = discover_cluster_configs(hypercluster_bin)?;
    let mut imported = Vec::new();
    for item in discovered {
        if item.registered {
            continue;
        }
        match import_cluster_from_path(&item.path, None) {
            Ok(entry) => imported.push(entry),
            Err(e) => eprintln!("auto-import skip {}: {e}", item.path),
        }
    }
    Ok(imported)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn discover_returns_sorted_unique() {
        let list = discover_cluster_configs(None).unwrap_or_default();
        for window in list.windows(2) {
            assert!(window[0].name <= window[1].name);
        }
    }
}
