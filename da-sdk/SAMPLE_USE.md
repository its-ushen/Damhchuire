# Sample Use

This is a minimal end-to-end local flow for using the generated Rust SDK.

## 1. Generate Rust SDK from backend catalog

```bash
cd da-sdk
./bin/generate_rust_sdk.rb \
  --catalog-url http://127.0.0.1:3000/sdk/catalog.json \
  --output ./rust/src/generated/actions.rs
```

## 2. Run the sample Rust usage (standalone crate at repo root)

```bash
cd ../example-sdk-use
cargo run
```

The sample currently calls:
- `crypto_price_on_call(...)`
- `weather_now_on_call(...)`

and prints each generated `PendingRequest` payload.

## 3. Use in another crate

```toml
[dependencies]
damhchuire-sdk = { path = "../da-sdk/rust" }
```

```rust
use damhchuire_sdk::{OracleClient, WeatherNowParams};

let client = OracleClient::default();
let req = client.weather_now_on_call(WeatherNowParams {
    city: "Dublin".to_string(),
    unit: Some("metric".to_string()),
})?;

// submit req.action_slug + req.params_json to on_call
```
