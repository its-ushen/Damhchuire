# da-sdk

`da-sdk` provides a Rust SDK generated from backend action metadata.

## Generate Rust bindings

```bash
./bin/generate_rust_sdk.rb \
  --catalog-url http://127.0.0.1:3000/sdk/catalog.json \
  --output ./rust/src/generated/actions.rs
```

The generated module contains:
- Per-action `*Params` and `*Response` structs.
- `OracleClient::<slug>_on_call(...)` typed request builders.
- `PendingRequest` payload (`action_slug` + serialized `params_json`) for chain calls.

## Rust crate

The Rust crate lives in `da-sdk/rust`.

Build and test:

```bash
cd rust
cargo test
```

Example:

```bash
cd ../example-sdk-use
cargo run
```

Detailed walkthrough:
- See `da-sdk/SAMPLE_USE.md`.
