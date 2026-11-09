use clap::{ArgAction, Parser};
use pankosmia_web;
use rocket::fs::relative;
use serde_json::json;
use std::env;

/// The Pithekos local server, based on Pankosmia Web
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Params {
    /// Read config from JSON file at given path (overrides other CLI paths)
    #[arg(short, long)]
    config_path: Option<String>,

    /// Path to file for logging
    #[arg(short, long)]
    log_path: Option<String>,

    /// Truncate log file on startup?
    #[arg(short, long, action=ArgAction::SetFalse)]
    truncate_log: bool,

    /// Path to working directory
    #[arg(default_value = None)]
    working_dir: Option<String>,
}

#[rocket::main]
pub async fn main() -> Result<(), rocket::Error> {
    let params = Params::parse();
    let conf: serde_json::Value;
    if params.config_path.is_some() {
        let file = match std::fs::File::open(params.config_path.clone().unwrap()) {
            Ok(fh) => fh,
            Err(e) => panic!(
                "Could not read supplied config JSON at {}: {}",
                &params.config_path.clone().unwrap(),
                e
            ),
        };
        conf = match serde_json::from_reader(file) {
            Ok(j) => j,
            Err(e) => panic!(
                "Could not parse supplied config JSON from {}: {}",
                &params.config_path.unwrap(),
                e
            ),
        };
    } else {
        let working_dir = params.working_dir.unwrap_or("".to_string());
        let log_path = params.log_path.unwrap_or("".to_string());
        let mut app_resources_path = relative!("").to_string();
        if env::var("APP_RESOURCES_DIR").is_ok() {
            app_resources_path = env::var("APP_RESOURCES_DIR").unwrap();
        }
        let webfont_path = format!("{}webfonts", app_resources_path);
        let app_setup_path = format!("{}setup/app_setup.json", app_resources_path);
        let local_setup_path = format!("{}setup/local_setup.json", app_resources_path);
        conf = json!({
            "working_dir": working_dir,
            "webfont_path": webfont_path,
            "app_setup_path": app_setup_path,
            "local_setup_path": local_setup_path,
            "app_resources_path": app_resources_path,
            "log_path": log_path,
            "truncate_log": params.truncate_log
        });
    };
    pankosmia_web::rocket(conf).launch().await?;
    Ok(())
}

#[cfg(test)]
mod tests;
