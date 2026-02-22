use damhchuire_sdk::{AnchorEmitError, CryptoPriceParams, WeatherNowParams};

#[test]
fn params_structs_are_constructible() {
    let _p = CryptoPriceParams { symbol: "BTC".to_string() };
}

#[test]
fn weather_now_params_serialize_roundtrip() {
    let params = WeatherNowParams {
        city: "Dublin".to_string(),
        unit: Some("metric".to_string()),
    };
    let json = serde_json::to_vec(&params).expect("serialize");
    let back: WeatherNowParams = serde_json::from_slice(&json).expect("deserialize");
    assert_eq!(back.city, "Dublin");
    assert_eq!(back.unit.as_deref(), Some("metric"));
}

#[test]
fn anchor_emit_error_variants() {
    let _e = AnchorEmitError::CounterOverflow;
}
