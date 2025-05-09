use std::env;
use serde_json::json;
use serde_json::Value;
use rocket::fs::relative;
use tokio::runtime::Runtime;

use pankosmia_web;

fn do_rocket(conf: Value) {
    let rt = Runtime::new().unwrap();
    let builder = pankosmia_web::rocket(conf);
    rt.block_on(
        async move {
            println!("Before");
            let _ = builder.launch().await;
        }
    );
}

pub fn main() {
    let args: Vec<String> = env::args().collect();
    let mut working_dir = "".to_string();
    if args.len() == 2 {
        working_dir = args[1].clone();
    };
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
    });
    let _ = do_rocket(conf);
}