use crate::tests::test_utils::make_test_conf;
use pankosmia_web;
use rocket::http::{ContentType, Status};
use rocket::local::blocking::Client;
use serde_json;

#[test]
fn version() {
    let conf = make_test_conf();
    let client = Client::tracked(pankosmia_web::rocket(conf)).unwrap();
    let response = client.get("/api/version").dispatch();
    assert_eq!(response.status(), Status::Ok);
    assert_eq!(response.content_type(), Some(ContentType::JSON));
    let response_string = response.into_string().expect("version response as string");
    let response_json = serde_json::from_str::<serde_json::Value>(&response_string)
        .expect("version response as json");
    assert_eq!(
        response_json["os"].as_str().expect("response os as str"),
        "linux"
    );
}
