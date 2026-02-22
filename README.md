# Damhchuire

Solana can interface with the outside world through oracles, but building custom integrations is still a significant undertaking. If a developer wants their smart contract to call an API that isn't already served by an existing oracle, they have to build the entire pipeline themselves. Damhchuire abstracts that challenge away so that developers can create integrations from their smart contract using a few lines from our SDK.

## How it works

1. Define an action (URL template, headers, body, schemas) through the dashboard or API
2. Call that action from your smart contract using our SDK
3. The oracle picks up the on-chain event, executes the HTTP request, and writes the result back to the chain via a signed callback transaction

## Project structure

```
da-backend/              Rails 8.1 oracle backend (API, dashboard, event listener)
da-solana/               Anchor program (on-chain contract)
da-sdk/                  Generated Rust SDK for smart contract developers
example-anchor-contract/ Example Anchor programs using the SDK
```

## Quick start

### Backend

```bash
cd da-backend
bundle install
bin/rails db:setup
bin/rails server
```

### Install the action library

```bash
bin/rails action_oracle:install_library
```

This seeds 24 pre-built actions (Discord, Slack, GitHub, SendGrid, PagerDuty, HubSpot, Airtable, Notion, Datadog, OpsGenie).

### Generate the Rust SDK

```bash
cd da-sdk
./bin/generate_rust_sdk.rb \
  --catalog-url http://127.0.0.1:3000/sdk/catalog.json \
  --output ./rust/src/generated/actions.rs
```

### Build the Solana program

```bash
cd da-solana/da-chain-side
anchor build
```

### Example contracts

```bash
cd example-anchor-contract
cargo check -p minimal-action-client
cargo check -p action-signal-client
```

## Documentation

- [Backend README](da-backend/README.md) for action definitions, templates, and the Discord example
- [SDK README](da-sdk/README.md) for generating and using the Rust SDK
- [Example contracts README](example-anchor-contract/README.md) for the minimal and payment examples
