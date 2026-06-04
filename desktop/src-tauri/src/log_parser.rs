//! Parse hypercluster progress and log lines for the desktop UI.

use regex::Regex;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedStage {
    pub current: u32,
    pub total: u32,
    pub label: String,
}

pub fn parse_stage_line(line: &str) -> Option<ParsedStage> {
    // [1/7] Preflight checks  or  🔷  [4/7] Fetch kubeconfig
    static RE: std::sync::OnceLock<Regex> = std::sync::OnceLock::new();
    let re = RE.get_or_init(|| Regex::new(r"\[(\d+)/(\d+)\]\s*(.+)").unwrap());
    let caps = re.captures(line)?;
    Some(ParsedStage {
        current: caps[1].parse().ok()?,
        total: caps[2].parse().ok()?,
        label: caps[3].trim().to_string(),
    })
}

pub fn strip_ansi(s: &str) -> String {
    static RE: std::sync::OnceLock<Regex> = std::sync::OnceLock::new();
    let re = RE.get_or_init(|| Regex::new(r"\x1b\[[0-9;]*m").unwrap());
    re.replace_all(s, "").to_string()
}
