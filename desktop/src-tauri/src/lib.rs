mod config;
mod hypercluster;
mod license;
mod log_parser;
mod paths;

use config::{
    auto_import_repo_cluster, create_cluster, delete_cluster, import_cluster_from_path,
    load_settings, read_cluster_conf, save_settings, update_cluster_by_path, write_cluster_conf,
    AppSettings, ClusterEntry, Registry,
};
use hypercluster::{
    cancel_run, get_run_status, resolve_binary_path, run_hypercluster, run_sync,
    run_sync_no_config, ProcessManager, RunRequest, RunStatus,
};
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Emitter, Manager,
};
use tauri_plugin_dialog::DialogExt;
use tauri_plugin_notification::NotificationExt;

#[tauri::command]
fn list_clusters() -> Result<Vec<ClusterEntry>, String> {
    Ok(Registry::load()?.clusters)
}

#[tauri::command]
fn get_settings() -> Result<AppSettings, String> {
    Ok(load_settings())
}

#[tauri::command]
fn set_settings(settings: AppSettings) -> Result<(), String> {
    save_settings(settings)
}

#[tauri::command]
fn create_cluster_cmd(
    name: String,
    conf_content: String,
    distro: String,
) -> Result<ClusterEntry, String> {
    create_cluster(&name, &conf_content, &distro)
}

#[tauri::command]
fn update_cluster_by_path_cmd(
    config_path: String,
    conf_content: String,
    name: String,
    distro: String,
) -> Result<ClusterEntry, String> {
    update_cluster_by_path(&config_path, &conf_content, &name, &distro)
}

#[tauri::command]
fn read_cluster_conf_cmd(path: String) -> Result<String, String> {
    read_cluster_conf(&path)
}

#[tauri::command]
fn write_cluster_conf_cmd(path: String, content: String) -> Result<(), String> {
    write_cluster_conf(&path, &content)
}

#[tauri::command]
fn delete_cluster_cmd(name: String) -> Result<(), String> {
    delete_cluster(&name)
}

#[tauri::command]
fn import_cluster_cmd(path: String) -> Result<ClusterEntry, String> {
    import_cluster_from_path(&path, None)
}

#[tauri::command]
async fn pick_cluster_conf(app: tauri::AppHandle) -> Result<Option<String>, String> {
    let file = app
        .dialog()
        .file()
        .add_filter("cluster.conf", &["conf"])
        .set_title("Import cluster.conf")
        .blocking_pick_file();
    Ok(file.map(|p| p.to_string()))
}

#[tauri::command]
fn resolve_hypercluster_binary() -> String {
    resolve_binary_path()
}

#[tauri::command]
async fn run_hypercluster_cmd(
    app: tauri::AppHandle,
    manager: tauri::State<'_, ProcessManager>,
    req: RunRequest,
) -> Result<(), String> {
    let cmd = req.command.clone();
    let mgr = manager.inner().clone();
    tokio::spawn(async move {
        match run_hypercluster(app.clone(), mgr, req).await {
            Ok(()) => {
                let _ = app
                    .notification()
                    .builder()
                    .title("Hypercluster")
                    .body(format!("{cmd} completed"))
                    .show();
            }
            Err(e) => {
                let _ = app
                    .notification()
                    .builder()
                    .title("Hypercluster")
                    .body(format!("{cmd} failed: {e}"))
                    .show();
            }
        }
    });
    Ok(())
}

#[tauri::command]
fn cancel_run_cmd(
    manager: tauri::State<'_, ProcessManager>,
    cluster_name: String,
) -> Result<(), String> {
    cancel_run(&manager, &cluster_name)
}

#[tauri::command]
async fn get_run_status_cmd(
    manager: tauri::State<'_, ProcessManager>,
    cluster_name: String,
) -> Result<Option<RunStatus>, String> {
    get_run_status(&manager, cluster_name).await
}

#[tauri::command]
async fn hc_status_json(config_path: String) -> Result<String, String> {
    run_sync(&config_path, "status", &[], true).await
}

#[tauri::command]
async fn hc_test_json(config_path: String, full: bool) -> Result<String, String> {
    let args = if full {
        vec!["--full".into()]
    } else {
        vec![]
    };
    run_sync(&config_path, "test", &args, true).await
}

#[tauri::command]
async fn hc_preflight_json(config_path: String) -> Result<String, String> {
    run_sync(&config_path, "preflight", &[], true).await
}

#[tauri::command]
async fn hc_discover_json(
    source: String,
    uri: Option<String>,
    host: Option<String>,
    cidr: Option<String>,
    csv: Option<String>,
    validate: Option<bool>,
    probe: Option<bool>,
    ssh_user: Option<String>,
    ssh_key: Option<String>,
    ssh_port: Option<u16>,
) -> Result<String, String> {
    let mut args = vec!["--json".into(), "--source".into(), source];
    if validate == Some(true) {
        args.push("--validate".into());
    }
    if probe == Some(true) {
        args.push("--probe".into());
    }
    if let Some(u) = uri {
        args.push("--uri".into());
        args.push(u);
    }
    if let Some(h) = host {
        args.push("--host".into());
        args.push(h);
    }
    if let Some(c) = cidr {
        args.push("--cidr".into());
        args.push(c);
    }
    if let Some(p) = csv {
        args.push("--csv".into());
        args.push(p);
    }
    if let Some(u) = ssh_user {
        args.push("--ssh-user".into());
        args.push(u);
    }
    if let Some(k) = ssh_key {
        args.push("--ssh-key".into());
        args.push(k);
    }
    if let Some(p) = ssh_port {
        args.push("--ssh-port".into());
        args.push(p.to_string());
    }
    run_sync_no_config("discover", &args).await
}

#[tauri::command]
async fn hc_vms_json(config_path: String) -> Result<String, String> {
    run_sync(&config_path, "vms", &[], true).await
}

#[tauri::command]
async fn hc_workloads_json(config_path: String) -> Result<String, String> {
    run_sync(&config_path, "workloads", &[], true).await
}

#[tauri::command]
async fn hc_vm_create_json(
    config_path: String,
    template: String,
    name: String,
    namespace: String,
) -> Result<String, String> {
    run_sync(
        &config_path,
        "vm",
        &[
            "create".into(),
            "--template".into(),
            template,
            "--name".into(),
            name,
            "--namespace".into(),
            namespace,
        ],
        true,
    )
    .await
}

#[tauri::command]
async fn pick_ssh_key(app: tauri::AppHandle) -> Result<Option<String>, String> {
    let file = app
        .dialog()
        .file()
        .add_filter("SSH private key", &["pem", ""])
        .set_title("Select SSH private key")
        .blocking_pick_file();
    Ok(file.map(|p| p.to_string()))
}

#[tauri::command]
fn reveal_config(config_path: String) -> Result<(), String> {
    let path = std::path::PathBuf::from(&config_path);
    if !path.exists() {
        return Err(format!("Config not found: {config_path}"));
    }
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg("-R")
            .arg(&config_path)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("explorer")
            .arg(format!("/select,{}", path.display()))
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "linux")]
    {
        let parent = path
            .parent()
            .ok_or_else(|| "invalid config path".to_string())?;
        std::process::Command::new("xdg-open")
            .arg(parent)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux")))]
    {
        return Err("Reveal in file manager is not supported on this OS".to_string());
    }
    Ok(())
}

#[tauri::command]
fn license_is_accepted_cmd() -> Result<bool, String> {
    Ok(license::license_is_accepted())
}

#[tauri::command]
fn license_summary_cmd() -> Result<String, String> {
    license::license_summary()
}

#[tauri::command]
fn license_accept_cmd(actor: Option<String>) -> Result<(), String> {
    license::license_accept(&actor.unwrap_or_else(|| {
        std::env::var("USER").unwrap_or_else(|_| "unknown".to_string())
    }))
}

#[tauri::command]
fn macos_arm64_required_cmd() -> bool {
    license::macos_arm64_required()
}

#[tauri::command]
fn host_cpu_arch_cmd() -> String {
    license::host_cpu_arch()
}

#[tauri::command]
fn open_data_dir() -> Result<(), String> {
    let dir = paths::app_data_dir();
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg(&dir)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("explorer")
            .arg(dir)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "linux")]
    {
        std::process::Command::new("xdg-open")
            .arg(dir)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux")))]
    {
        return Err("Open data directory is not supported on this OS".to_string());
    }
    Ok(())
}

fn setup_tray(app: &AppHandle) -> Result<(), Box<dyn std::error::Error>> {
    let show = MenuItem::with_id(app, "show", "Open Hypercluster", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
    let menu = Menu::with_items(app, &[&show, &quit])?;
    let icon = app
        .default_window_icon()
        .cloned()
        .ok_or("missing default window icon")?;
    let _tray = TrayIconBuilder::new()
        .icon(icon)
        .menu(&menu)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "show" => {
                if let Some(w) = app.get_webview_window("main") {
                    let _ = w.show();
                    let _ = w.set_focus();
                }
            }
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                let app = tray.app_handle();
                if let Some(w) = app.get_webview_window("main") {
                    let _ = w.show();
                    let _ = w.set_focus();
                }
            }
        })
        .build(app)?;
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .manage(ProcessManager::new())
        .setup(|app| {
            let _ = setup_tray(app.handle());
            let bin = paths::resolve_hypercluster_bin(load_settings().hypercluster_binary.as_deref());
            if let Ok(Some(entry)) = auto_import_repo_cluster(&bin) {
                let _ = app.emit("hc-cluster-imported", entry);
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            list_clusters,
            get_settings,
            set_settings,
            create_cluster_cmd,
            update_cluster_by_path_cmd,
            read_cluster_conf_cmd,
            write_cluster_conf_cmd,
            delete_cluster_cmd,
            import_cluster_cmd,
            pick_cluster_conf,
            resolve_hypercluster_binary,
            run_hypercluster_cmd,
            cancel_run_cmd,
            get_run_status_cmd,
            hc_status_json,
            hc_test_json,
            hc_preflight_json,
            hc_discover_json,
            hc_vms_json,
            hc_workloads_json,
            hc_vm_create_json,
            license_is_accepted_cmd,
            license_summary_cmd,
            license_accept_cmd,
            macos_arm64_required_cmd,
            host_cpu_arch_cmd,
            pick_ssh_key,
            reveal_config,
            open_data_dir,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Hypercluster Desktop");
}
