# Example Anchor Contracts Using `damhchuire-sdk`

This workspace now contains two program examples:

1. `action-signal-client` (payment + action request)
2. `minimal-action-client` (no payment, minimal request/callback shape)

## Minimal Example

Path: `example-anchor-contract/programs/minimal-action-client/src/lib.rs`

What it does:

- `initialize(oracle_authority)` stores oracle signer + request counter.
- `on_call()` emits an action request using SDK helper:
  - fixed city: `Dublin`
  - no unit override (`unit: None`)
- `callback(request_id, ok, result_json)` is oracle-gated and emits `ActionCompleted`.

No payment transfer and no on-call params.

## Payment Example

Path: `example-anchor-contract/programs/action-signal-client/src/lib.rs`

What it does:

- Transfers payment from caller to merchant.
- Emits weather request via SDK helper.
- Accepts oracle callback.

## Build Checks

```bash
cd example-anchor-contract
cargo check -p minimal-action-client
cargo check -p action-signal-client
```

For Anchor IDL feature checks:

```bash
cd example-anchor-contract
cargo check -p minimal-action-client --features idl-build
cargo check -p action-signal-client --features idl-build
```
