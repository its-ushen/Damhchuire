use damhchuire_sdk::{ClientError, OracleClient, PendingRequest, TypedOnCallParams};

#[test]
fn oracle_client_default_is_constructible() {
    let _client = OracleClient::default();
}

#[test]
fn pending_request_payload_roundtrip() {
    let req = PendingRequest {
        action_slug: "example",
        params_json: br#"{"city":"Dublin"}"#.to_vec(),
    };

    let json: serde_json::Value = serde_json::from_slice(&req.params_json).expect("valid json payload");
    assert_eq!(json["city"], "Dublin");
}

#[test]
fn typed_on_call_params_parse_known_slug() {
    let raw = br#"{"city":"Dublin","unit":"metric"}"#;
    let typed = TypedOnCallParams::from_on_call("weather_now", raw).expect("typed parse");

    match typed {
        TypedOnCallParams::WeatherNow(params) => {
            assert_eq!(params.city, "Dublin");
            assert_eq!(params.unit.as_deref(), Some("metric"));
        }
        _ => panic!("unexpected typed action variant"),
    }
}

#[test]
fn typed_on_call_params_unknown_slug_errors() {
    let err = TypedOnCallParams::from_on_call("does_not_exist", br#"{}"#).expect_err("should fail");
    assert!(matches!(err, ClientError::UnknownActionSlug(_)));
}
