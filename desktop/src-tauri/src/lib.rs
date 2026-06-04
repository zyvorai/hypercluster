mod config;
mod hypercluster;
mod log_parser;
mod paths;

use config::{
    create_cluster, delete_cluster, load_settings, read_cluster_conf, save_settings,
    write_cluster_conf, AppSettings, ClusterEntry, Registry,
};
use hypercluster::{
    cancel_run, get_run_status, resolve_binary_path, run_hypercluster, run_sync, ProcessManager,
    RunRequest, RunStatus,
};
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Manager,
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
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg("-R")
            .arg(&config_path)
            .spawn()
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}

#[tauri::command]
fn open_data_dir() -> Result<(), String> {
    let dir = paths::app_data_dir();
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg(dir)
            .spawn()
            .map_err(|e| e.to_string())?;
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
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            list_clusters,
            get_settings,
            set_settings,
            create_cluster_cmd,
            read_cluster_conf_cmd,
            write_cluster_conf_cmd,
            delete_cluster_cmd,
            resolve_hypercluster_binary,
            run_hypercluster_cmd,
            cancel_run_cmd,
            get_run_status_cmd,
            hc_status_json,
            hc_test_json,
            pick_ssh_key,
            reveal_config,
            open_data_dir,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Hypercluster Desktop");
}
