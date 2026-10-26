use serde_json::json;
use rocket::fs::relative;
use serde_json::Value;

pub(crate) fn make_test_conf() -> Value {
let app_resources_parent_path = relative!("../linux/build/lib/").to_string();
    let app_resources_path = format!("{}/app_resources/", &app_resources_parent_path);
    let working_dir = "/home/mark/pankosmia/pithekos".to_string();
    let webfont_path = format!("{}webfonts", app_resources_path);
    let app_setup_path = format!("{}setup/app_setup.json", app_resources_parent_path);
    let local_setup_path = relative!("local_test_setup.json");
    json!({
        "working_dir": working_dir,
        "webfont_path": webfont_path,
        "app_setup_path": app_setup_path,
        "local_setup_path": local_setup_path,
        "app_resources_path": app_resources_path,
    })
}