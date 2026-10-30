use clap::Parser;
use pankosmia_web;
use rocket::fs::relative;
use serde_json::json;
use std::env;

/// The Pithekos local server, based on Pankosmia Web
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Params {
    /// Path to file for logging
    #[arg(short, long)]
    log_path: Option<String>,

    /// Path to working directory
    #[arg(default_value = None)]
    working_dir: Option<String>,
}

#[rocket::main]
pub async fn main() -> Result<(), rocket::Error> {
    let params = Params::parse();
    let working_dir = params.working_dir.unwrap_or("".to_string());
    let log_path = params.log_path.unwrap_or("".to_string());
    let mut app_resources_path = relative!("").to_string();
    if env::var("APP_RESOURCES_DIR").is_ok() {
        app_resources_path = env::var("APP_RESOURCES_DIR").unwrap();
    }
    let webfont_path = format!("{}webfonts", app_resources_path);
    let app_setup_path = format!("{}setup/app_setup.json", app_resources_path);
    let local_setup_path = format!("{}setup/local_setup.json", app_resources_path);
    let conf = json!({
        "working_dir": working_dir,
        "webfont_path": webfont_path,
        "app_setup_path": app_setup_path,
        "local_setup_path": local_setup_path,
        "app_resources_path": app_resources_path,
        "log_path": log_path
    });
    pankosmia_web::rocket(conf).launch().await?;
    Ok(())
}

#[cfg(test)]
mod tests;
