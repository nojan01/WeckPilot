use std::process::Command;
use serde::{Deserialize, Serialize};

// ============================================================
// Sleep Prevention & Screen Wake
// ============================================================

/// Verhindert Schlafmodus mit macOS caffeinate
#[tauri::command]
fn prevent_sleep(minutes: u32) -> Result<String, String> {
    #[cfg(target_os = "macos")]
    {
        let seconds = minutes * 60;
        let output = Command::new("caffeinate")
            .args(["-d", "-t", &seconds.to_string()])
            .spawn();
        
        match output {
            Ok(_) => Ok(format!("Schlafmodus für {} Minuten deaktiviert", minutes)),
            Err(e) => Err(format!("Fehler: {}", e))
        }
    }
    
    #[cfg(not(target_os = "macos"))]
    {
        Err("Nur auf macOS unterstützt".to_string())
    }
}

/// Prüft ob die App Berechtigung hat, Schlaf zu verhindern
#[tauri::command]
fn check_sleep_permission() -> bool {
    #[cfg(target_os = "macos")]
    {
        true
    }
    
    #[cfg(not(target_os = "macos"))]
    {
        false
    }
}

/// Weckt den Bildschirm auf (beendet Bildschirmschoner)
#[tauri::command]
fn wake_screen() -> Result<String, String> {
    #[cfg(target_os = "macos")]
    {
        let output = Command::new("caffeinate")
            .args(["-u", "-t", "5"])
            .spawn();
        
        match output {
            Ok(_) => Ok("Bildschirm aufgeweckt".to_string()),
            Err(e) => Err(format!("Fehler: {}", e))
        }
    }
    
    #[cfg(not(target_os = "macos"))]
    {
        Err("Nur auf macOS unterstützt".to_string())
    }
}

// ============================================================
// Wake Helper Management
// ============================================================

const HELPER_BINARY: &str = "/usr/local/bin/AlarmMasterWakeHelper";
const HELPER_PLIST: &str = "/Library/LaunchDaemons/com.alarmmaster.wake-helper.plist";
const SHARED_DIR: &str = "/Users/Shared/AlarmMaster";
const SCHEDULE_FILE: &str = "/Users/Shared/AlarmMaster/schedule.json";

#[derive(Serialize, Deserialize)]
struct WakeSchedule {
    #[serde(rename = "nextWake")]
    next_wake: Option<String>,
    enabled: bool,
    #[serde(rename = "alarmTime")]
    alarm_time: Option<String>,
    label: Option<String>,
}

#[derive(Serialize)]
struct WakeHelperStatus {
    installed: bool,
    daemon_loaded: bool,
    has_schedule: bool,
    next_wake: Option<String>,
    log_tail: Option<String>,
}

/// Prüft ob der Wake Helper installiert ist
#[tauri::command]
fn is_wake_helper_installed() -> bool {
    #[cfg(target_os = "macos")]
    {
        std::path::Path::new(HELPER_BINARY).exists()
            && std::path::Path::new(HELPER_PLIST).exists()
    }
    
    #[cfg(not(target_os = "macos"))]
    false
}

/// Holt den detaillierten Status des Wake Helpers
#[tauri::command]
fn get_wake_helper_status() -> WakeHelperStatus {
    #[cfg(target_os = "macos")]
    {
        let installed = std::path::Path::new(HELPER_BINARY).exists()
            && std::path::Path::new(HELPER_PLIST).exists();
        
        // Check if daemon is loaded
        let daemon_loaded = Command::new("launchctl")
            .args(["list"])
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).contains("com.alarmmaster.wake-helper"))
            .unwrap_or(false);
        
        // Read current schedule
        let (has_schedule, next_wake) = if let Ok(data) = std::fs::read_to_string(SCHEDULE_FILE) {
            if let Ok(schedule) = serde_json::from_str::<WakeSchedule>(&data) {
                (schedule.enabled && schedule.next_wake.is_some(), schedule.next_wake)
            } else {
                (false, None)
            }
        } else {
            (false, None)
        };
        
        // Read last few lines of log
        let log_path = format!("{}/helper.log", SHARED_DIR);
        let log_tail = std::fs::read_to_string(&log_path)
            .ok()
            .map(|content| {
                let lines: Vec<&str> = content.lines().collect();
                let start = if lines.len() > 10 { lines.len() - 10 } else { 0 };
                lines[start..].join("\n")
            });
        
        WakeHelperStatus {
            installed,
            daemon_loaded,
            has_schedule,
            next_wake,
            log_tail,
        }
    }
    
    #[cfg(not(target_os = "macos"))]
    {
        WakeHelperStatus {
            installed: false,
            daemon_loaded: false,
            has_schedule: false,
            next_wake: None,
            log_tail: None,
        }
    }
}

/// Installiert den Wake Helper (erfordert Admin-Rechte)
#[tauri::command]
fn install_wake_helper(app: tauri::AppHandle) -> Result<String, String> {
    #[cfg(target_os = "macos")]
    {
        use tauri::Manager;
        
        let resource_dir = app.path().resource_dir().map_err(|e| format!("Resource dir error: {}", e))?;
        let helpers_dir = resource_dir.join("helpers");
        
        // Verify helper files exist
        let install_script = helpers_dir.join("install.sh");
        if !install_script.exists() {
            return Err(format!("Install script not found at: {}", install_script.display()));
        }
        
        // Run install script with admin privileges via osascript
        let script = format!(
            "do shell script \"bash '{}' '{}'\" with administrator privileges",
            install_script.display(),
            helpers_dir.display()
        );
        
        let output = Command::new("osascript")
            .args(["-e", &script])
            .output()
            .map_err(|e| format!("Failed to run installer: {}", e))?;
        
        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            Ok(format!("Wake Helper erfolgreich installiert.\n{}", stdout))
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr);
            if stderr.contains("User canceled") || stderr.contains("-128") {
                Err("Installation vom Benutzer abgebrochen.".to_string())
            } else {
                Err(format!("Installation fehlgeschlagen: {}", stderr))
            }
        }
    }
    
    #[cfg(not(target_os = "macos"))]
    {
        Err("Nur auf macOS unterstützt".to_string())
    }
}

/// Deinstalliert den Wake Helper
#[tauri::command]
fn uninstall_wake_helper(app: tauri::AppHandle) -> Result<String, String> {
    #[cfg(target_os = "macos")]
    {
        use tauri::Manager;
        
        let resource_dir = app.path().resource_dir().map_err(|e| format!("Resource dir error: {}", e))?;
        let helpers_dir = resource_dir.join("helpers");
        let uninstall_script = helpers_dir.join("uninstall.sh");
        
        if !uninstall_script.exists() {
            return Err(format!("Uninstall script not found at: {}", uninstall_script.display()));
        }
        
        let script = format!(
            "do shell script \"bash '{}'\" with administrator privileges",
            uninstall_script.display()
        );
        
        let output = Command::new("osascript")
            .args(["-e", &script])
            .output()
            .map_err(|e| format!("Failed to run uninstaller: {}", e))?;
        
        if output.status.success() {
            Ok("Wake Helper erfolgreich deinstalliert.".to_string())
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr);
            if stderr.contains("User canceled") || stderr.contains("-128") {
                Err("Deinstallation vom Benutzer abgebrochen.".to_string())
            } else {
                Err(format!("Deinstallation fehlgeschlagen: {}", stderr))
            }
        }
    }
    
    #[cfg(not(target_os = "macos"))]
    {
        Err("Nur auf macOS unterstützt".to_string())
    }
}

/// Aktualisiert den Wake-Schedule (schreibt schedule.json für den Helper)
#[tauri::command]
fn update_wake_schedule(
    next_wake: Option<String>,
    alarm_time: Option<String>,
    label: Option<String>,
) -> Result<String, String> {
    #[cfg(target_os = "macos")]
    {
        // Ensure shared directory exists
        std::fs::create_dir_all(SHARED_DIR)
            .map_err(|e| format!("Cannot create directory: {}", e))?;
        
        // Set directory permissions so both user and daemon can access
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let perms = std::fs::Permissions::from_mode(0o777);
            std::fs::set_permissions(SHARED_DIR, perms).ok();
        }
        
        let schedule = WakeSchedule {
            next_wake: next_wake.clone(),
            enabled: next_wake.is_some(),
            alarm_time,
            label,
        };
        
        let json = serde_json::to_string_pretty(&schedule)
            .map_err(|e| format!("JSON error: {}", e))?;
        
        std::fs::write(SCHEDULE_FILE, &json)
            .map_err(|e| format!("Cannot write schedule: {}", e))?;
        
        // Set file permissions
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let perms = std::fs::Permissions::from_mode(0o666);
            std::fs::set_permissions(SCHEDULE_FILE, perms).ok();
        }
        
        match &schedule.next_wake {
            Some(wake) => Ok(format!("Wake-Schedule aktualisiert: {}", wake)),
            None => Ok("Wake-Schedule deaktiviert".to_string()),
        }
    }
    
    #[cfg(not(target_os = "macos"))]
    {
        Err("Nur auf macOS unterstützt".to_string())
    }
}

/// Plant ein Systemaufwachen (Legacy-Funktion, nutzt jetzt den Helper-Mechanismus)
#[tauri::command]
fn schedule_wake(hour: u8, minute: u8) -> Result<String, String> {
    #[cfg(target_os = "macos")]
    {
        use chrono::{Local, Duration};
        
        let now = Local::now();
        let mut wake_time = now.date_naive().and_hms_opt(hour as u32, minute as u32, 0).unwrap();
        
        if wake_time.and_local_timezone(Local).unwrap() <= now {
            wake_time = wake_time + Duration::days(1);
        }
        
        let iso_formatted = wake_time.format("%Y-%m-%dT%H:%M:%S").to_string();
        let alarm_time = format!("{:02}:{:02}", hour, minute);
        
        // Write schedule file for the helper
        let schedule = WakeSchedule {
            next_wake: Some(iso_formatted.clone()),
            enabled: true,
            alarm_time: Some(alarm_time),
            label: None,
        };
        
        std::fs::create_dir_all(SHARED_DIR).ok();
        let json = serde_json::to_string_pretty(&schedule)
            .map_err(|e| format!("JSON error: {}", e))?;
        std::fs::write(SCHEDULE_FILE, &json)
            .map_err(|e| format!("Write error: {}", e))?;
        
        Ok(format!("Aufwachen geplant für {}", iso_formatted))
    }
    
    #[cfg(not(target_os = "macos"))]
    {
        Err("Nur auf macOS unterstützt".to_string())
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .enable_macos_default_menu(false)
        .menu(|app| {
            use tauri::menu::{AboutMetadataBuilder, Menu, PredefinedMenuItem};

            let menu = Menu::default(app)?;

            #[cfg(target_os = "macos")]
            if let Some(app_menu) = menu.items()?.first().and_then(|item| item.as_submenu()) {
                let about = AboutMetadataBuilder::new()
                    .name(Some("AlarmMaster"))
                    .version(Some(app.package_info().version.to_string()))
                    .copyright(Some("Copyright © 2026 Norbert Jander"))
                    .credits(Some(include_str!("../../LICENSE")))
                    .build();
                let about_item =
                    PredefinedMenuItem::about(app, Some("Über AlarmMaster"), Some(about))?;

                app_menu.remove_at(0)?;
                app_menu.insert(&about_item, 0)?;
            }

            Ok(menu)
        })
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            prevent_sleep,
            schedule_wake,
            check_sleep_permission,
            wake_screen,
            is_wake_helper_installed,
            get_wake_helper_status,
            install_wake_helper,
            uninstall_wake_helper,
            update_wake_schedule
        ])
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
