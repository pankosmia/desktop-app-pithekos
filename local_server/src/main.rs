use clap::{ArgAction, Parser};
use rocket::fs::relative;
use serde::Deserialize;
use serde_json::json;
use std::env;
use std::io::BufReader;

/// A Pankosmia local server, based on Pankosmia Web
#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
struct Params {
    /// Read config from JSON file at given path
    #[arg(short, long)]
    config_path: Option<String>,

    /// Path to file for logging
    #[arg(short, long)]
    log_path: Option<String>,

    /// Truncate log file on startup?
    #[arg(short, long, action=ArgAction::SetFalse)]
    truncate_log: Option<bool>,

    /// Verbose startup?
    #[arg(short, long, action=ArgAction::SetTrue)]
    verbose: bool,

    /// Path to working directory
    #[arg(default_value = None)]
    working_dir: Option<String>,
}

#[derive(Deserialize, Debug, Clone)]
struct ConfigJson {
    working_dir: String,
    webfont_path: String,
    app_setup_path: String,
    local_setup_path: String,
    app_resources_path: String,
    log_path: String,
    truncate_log: bool,
}

#[rocket::main]
pub async fn main() -> Result<(), rocket::Error> {
    let params = Params::parse();

    if params.verbose {
        println!("Pankosmia local server launching!");
    };

    // Read config path JSON if provided, use as defaults for other options
    // JSON must conform to ConfigJson struct, should panic informatively if not
    let loaded_conf: Option<ConfigJson>;
    if params.config_path.is_some() {
        if params.verbose {
            println!("   Loading from config_path");
        };
        let file = match std::fs::File::open(params.config_path.clone().unwrap()) {
            Ok(fh) => fh,
            Err(e) => panic!(
                "Could not read supplied config JSON at {}: {}",
                &params.config_path.clone().unwrap(),
                e
            ),
        };
        let file_reader = BufReader::new(file);
        loaded_conf = match serde_json::from_reader(file_reader) {
            Ok(j) => j,
            Err(e) => panic!(
                "Could not parse supplied config JSON from {}: {}",
                &params.config_path.unwrap(),
                e
            ),
        };
    } else {
        loaded_conf = None;
    }
    // App resources path is from config path JSON or env var or hardcoded default
    let mut app_resources_path = relative!("").to_string();
    if loaded_conf.is_some() {
        app_resources_path = loaded_conf.clone().unwrap().app_resources_path.clone();
    } else if env::var("APP_RESOURCES_DIR").is_ok() {
        app_resources_path = env::var("APP_RESOURCES_DIR").unwrap();
    }
    if params.verbose {
        println!("   app_resources_path: '{}'", &app_resources_path);
    };

    // Working dir is from CLI or config path JSON or hardcoded default
    let working_dir = match params.working_dir {
        Some(v) => v,
        None => match loaded_conf.clone() {
            Some(c) => c.working_dir.clone(),
            None => "".to_string(),
        },
    };
    if params.verbose {
        println!("   working_dir: '{}'", &working_dir);
    };

    // Log path is from CLI or config path JSON or hardcoded default
    let log_path = match params.log_path {
        Some(v) => v,
        None => match loaded_conf.clone() {
            Some(c) => c.log_path.clone(),
            None => "".to_string(),
        },
    };
    if params.verbose {
        println!("   log_path: '{}'", &log_path);
    };

    // Webfont path is from config path JSON or derived from app resources path
    let webfont_path = match loaded_conf.clone() {
        Some(c) => c.webfont_path.clone(),
        None => format!("{}webfonts", app_resources_path),
    };
    if params.verbose {
        println!("   webfont_path: '{}'", &webfont_path);
    };

    // App setup path is from config path JSON or derived from app resources path
    let app_setup_path = match loaded_conf.clone() {
        Some(c) => c.app_setup_path.clone(),
        None => format!("{}setup/app_setup.json", app_resources_path),
    };
    if params.verbose {
        println!("   app_setup_path: '{}'", &app_setup_path);
    };

    // Local setup path is from config path JSON or derived from app resources path
    let local_setup_path = match loaded_conf.clone() {
        Some(c) => c.local_setup_path.clone(),
        None => format!("{}setup/local_setup.json", app_resources_path),
    };
    if params.verbose {
        println!("   local_setup_path: '{}'", &local_setup_path);
    };

    // Truncate log flag is from CLI or config path JSON or hardcoded default (true)
    let truncate_log = match params.truncate_log {
        Some(v) => v,
        None => match loaded_conf.clone() {
            Some(c) => c.truncate_log,
            None => true,
        },
    };
    if params.verbose {
        println!("   truncate_log: {}", &truncate_log);
    };

    // Build untyped JSON of settings
    let conf = json!({
        "working_dir": working_dir,
        "webfont_path": webfont_path,
        "app_setup_path": app_setup_path,
        "local_setup_path": local_setup_path,
        "app_resources_path": app_resources_path,
        "log_path": log_path,
        "truncate_log": truncate_log
    });

    // Launch Rocket server asynchronously using config
    if params.verbose {
        println!("   Launched!\n");
    };
    pankosmia_web::rocket(conf).launch().await?;

    // Our work here (in this thread) is done
    Ok(())
}
