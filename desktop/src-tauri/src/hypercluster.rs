//! Spawn hypercluster CLI and stream output to the UI.

use crate::config::{load_settings, update_cluster_action};
use crate::log_parser::{parse_stage_line, strip_ansi};
use crate::paths;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Stdio;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use tauri::{AppHandle, Emitter};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::Mutex as AsyncMutex;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunRequest {
    pub cluster_name: String,
    pub config_path: String,
    pub command: String,
    pub args: Vec<String>,
    pub force: bool,
    pub verbose: bool,
    pub dry_run: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunStatus {
    pub cluster_name: String,
    pub running: bool,
    pub exit_code: Option<i32>,
    pub stage: Option<crate::log_parser::ParsedStage>,
}

struct JobHandle {
    cancel: Arc<AtomicBool>,
    child_id: Option<u32>,
}

#[derive(Clone)]
pub struct ProcessManager {
    jobs: Arc<Mutex<HashMap<String, JobHandle>>>,
    statuses: Arc<AsyncMutex<HashMap<String, RunStatus>>>,
}

impl ProcessManager {
    pub fn new() -> Self {
        Self {
            jobs: Arc::new(Mutex::new(HashMap::new())),
            statuses: Arc::new(AsyncMutex::new(HashMap::new())),
        }
    }
}

fn hypercluster_bin() -> PathBuf {
    let settings = load_settings();
    paths::resolve_hypercluster_bin(settings.hypercluster_binary.as_deref())
}

fn build_shell_command(req: &RunRequest, bin: &PathBuf) -> String {
    let mut parts = vec![
        format!("\"{}\"", bin.display()),
        "-c".into(),
        format!("\"{}\"", req.config_path),
    ];
    if req.dry_run {
        parts.push("-n".into());
    }
    if req.verbose {
        parts.push("-v".into());
    }
    if req.force {
        parts.push("-f".into());
    }
    parts.push(req.command.clone());
    parts.extend(req.args.clone());
    format!("exec {}", parts.join(" "))
}

pub async fn run_hypercluster(
    app: AppHandle,
    manager: ProcessManager,
    req: RunRequest,
) -> Result<(), String> {
    {
        let jobs = manager.jobs.lock().map_err(|e| e.to_string())?;
        if jobs.contains_key(&req.cluster_name) {
            return Err(format!(
                "Cluster '{}' already has a running job",
                req.cluster_name
            ));
        }
    }

    let bin = hypercluster_bin();
    if !bin.exists() {
        return Err(format!(
            "hypercluster binary not found at {}. Set path in Settings.",
            bin.display()
        ));
    }

    let bash = paths::resolve_bash();
    let shell_cmd = build_shell_command(&req, &bin);

    let mut child = Command::new(&bash)
        .arg("-lc")
        .arg(&shell_cmd)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true)
        .spawn()
        .map_err(|e| format!("Failed to spawn hypercluster: {e}"))?;

    let pid = child.id();
    let cancel = Arc::new(AtomicBool::new(false));
    {
        let mut jobs = manager.jobs.lock().map_err(|e| e.to_string())?;
        jobs.insert(
            req.cluster_name.clone(),
            JobHandle {
                cancel: cancel.clone(),
                child_id: pid,
            },
        );
    }
    {
        let mut st = manager.statuses.lock().await;
        st.insert(
            req.cluster_name.clone(),
            RunStatus {
                cluster_name: req.cluster_name.clone(),
                running: true,
                exit_code: None,
                stage: None,
            },
        );
    }

    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    let cluster = req.cluster_name.clone();
    let cluster_action = req.command.clone();
    let app_out = app.clone();
    let app_err = app.clone();
    let cancel_out = cancel.clone();
    let statuses = Arc::clone(&manager.statuses);

    if let Some(out) = stdout {
        let cname = cluster.clone();
        tokio::spawn(async move {
            let reader = BufReader::new(out);
            let mut lines = reader.lines();
            while let Ok(Some(line)) = lines.next_line().await {
                if cancel_out.load(Ordering::Relaxed) {
                    break;
                }
                if let Some(stage) = parse_stage_line(&line) {
                    let _ = app_out.emit("hc-stage", &stage);
                    let mut st = statuses.lock().await;
                    if let Some(s) = st.get_mut(&cname) {
                        s.stage = Some(stage);
                    }
                }
                let _ = app_out.emit(
                    "hc-log-line",
                    serde_json::json!({
                        "cluster": cname,
                        "stream": "stdout",
                        "line": line,
                        "plain": strip_ansi(&line),
                    }),
                );
            }
        });
    }

    if let Some(err) = stderr {
        let cname = cluster.clone();
        let cancel_err = cancel.clone();
        tokio::spawn(async move {
            let reader = BufReader::new(err);
            let mut lines = reader.lines();
            while let Ok(Some(line)) = lines.next_line().await {
                if cancel_err.load(Ordering::Relaxed) {
                    break;
                }
                let _ = app_err.emit(
                    "hc-log-line",
                    serde_json::json!({
                        "cluster": cname,
                        "stream": "stderr",
                        "line": line,
                        "plain": strip_ansi(&line),
                    }),
                );
            }
        });
    }

    let exit = child.wait().await.map_err(|e| e.to_string())?;
    let code = exit.code();

    {
        let mut jobs = manager.jobs.lock().map_err(|e| e.to_string())?;
        jobs.remove(&req.cluster_name);
    }
    {
        let mut st = manager.statuses.lock().await;
        if let Some(s) = st.get_mut(&req.cluster_name) {
            s.running = false;
            s.exit_code = code;
        }
    }

    let _ = update_cluster_action(&req.cluster_name, &cluster_action);

    let success = code == Some(0);
    let _ = app.emit(
        "hc-exit",
        serde_json::json!({
            "cluster": req.cluster_name,
            "exitCode": code,
            "command": req.command,
            "success": success,
        }),
    );

    if !success {
        return Err(format!(
            "hypercluster {} exited with code {:?}",
            req.command, code
        ));
    }
    Ok(())
}

pub fn cancel_run(manager: &ProcessManager, cluster_name: &str) -> Result<(), String> {
    let mut jobs = manager.jobs.lock().map_err(|e| e.to_string())?;
    if let Some(job) = jobs.remove(cluster_name) {
        job.cancel.store(true, Ordering::Relaxed);
        if let Some(pid) = job.child_id {
            #[cfg(unix)]
            unsafe {
                libc::kill(pid as i32, libc::SIGTERM);
            }
        }
        Ok(())
    } else {
        Err(format!("No running job for cluster '{cluster_name}'"))
    }
}

pub async fn get_run_status(
    manager: &ProcessManager,
    cluster_name: String,
) -> Result<Option<RunStatus>, String> {
    let st = manager.statuses.lock().await;
    Ok(st.get(&cluster_name).cloned())
}

pub async fn run_sync(
    config_path: &str,
    command: &str,
    args: &[String],
    json: bool,
) -> Result<String, String> {
    let bin = hypercluster_bin();
    let bash = paths::resolve_bash();
    let mut parts = vec![
        format!("\"{}\"", bin.display()),
        "-c".into(),
        format!("\"{}\"", config_path),
        command.into(),
    ];
    if json {
        parts.push("--json".into());
    }
    parts.extend(args.iter().cloned());
    let shell_cmd = format!("exec {}", parts.join(" "));
    let output = Command::new(&bash)
        .arg("-lc")
        .arg(&shell_cmd)
        .output()
        .await
        .map_err(|e| e.to_string())?;
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).to_string())
    } else {
        Err(String::from_utf8_lossy(&output.stderr).to_string())
    }
}

pub fn resolve_binary_path() -> String {
    hypercluster_bin().to_string_lossy().to_string()
}
