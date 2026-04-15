# Local Changes Not Yet on Remote `main`

Snapshot of all uncommitted local work as of 2026-04-15.

---

## 1. New Anchor Program: `invoice-processor`

**Path:** `example-anchor-contract/programs/invoice-processor/`

A new Solana/Anchor program that:

- Accepts invoice text, sends it to an AI chat action (`openai/gpt-4o-mini`) to extract the payable SOL amount.
- Maintains a per-program config with an **allowlist** (up to 10 wallets), an **oracle authority**, and a **max payout cap**.
- Creates `Invoice` PDAs keyed by request ID to track submitted invoices and their parsed amounts.
- On oracle callback, parses the AI response, validates the amount against the cap, and transfers SOL from a program vault to the invoice submitter.
- Instructions: `initialize`, `add_to_allowlist`, `remove_from_allowlist`, `fund_vault`, `submit_invoice`, `callback`.

**New files (staged):**
- `programs/invoice-processor/Cargo.toml`
- `programs/invoice-processor/src/lib.rs` (+448 lines)

## 2. New Anchor Program: `ai-chat-client`

**Path:** `example-anchor-contract/programs/ai-chat-client/` (untracked)

A simpler example program that demonstrates calling the `ai_chat` DA action directly from an Anchor program. Hardcodes a model (`openai/gpt-4o-mini`) and prompt ("Summarize what Solana is in one sentence."), stores a config PDA with oracle authority and request counter.

## 3. E2E Test for Invoice Processor

**Path:** `example-anchor-contract/tests/e2e-invoice-processor.ts`

- Staged version: initial test scaffolding (+166 lines).
- Unstaged additions: expanded to +327 lines with full end-to-end flow covering initialize, allowlist management, vault funding, invoice submission, and oracle callback simulation.

## 4. SDK Updates (`da-sdk/rust`)

**Files:** `Cargo.toml`, `src/generated/actions.rs`

- Added `PendingRequest` struct for deserializing queued action requests.
- Added `OracleClient` struct (default-constructible).
- Added `AiChatParams` / `AiChatResponse` typed structs.
- Gated Anchor-specific code behind `#[cfg(feature = "anchor")]` so the SDK can be used without Anchor (e.g., in off-chain tooling).
- Added `ClientError::Deserialize` and `ClientError::UnknownActionSlug` variants.
- Regenerated catalog timestamp.

## 5. Backend: `DaTaskEmitter` Rework

**File:** `da-backend/app/services/da_task_emitter.rb`

- Removed the `on_call` method (no longer needed — on-chain programs emit events directly).
- Removed hardcoded `PROGRAM_ID` constant; now reads from `Solana::PROGRAM_ID` initializer.
- Rewrote `send_instruction` → `send_callback_instruction` to build transactions matching the `invoice_processor`'s `CallbackCtx` account layout:
  - `[0]` config PDA (readonly)
  - `[1]` oracle authority (signer/payer, writable)
  - `[2]` invoice PDA (writable, derived from request ID)
  - `[3]` program ID
- Added `derive_pda` helper that accepts arbitrary seeds + program ID (replaces the old single-purpose `derive_config_pda`).
- Updated `build_callback_message` to construct the correct account meta list.

## 6. Backend: Solana Program ID Update

**File:** `da-backend/config/initializers/solana.rb`

Default `SOLANA_PROGRAM_ID` changed from `91XcSJyr...` → `9JsLkqyR...` to match the new `invoice-processor` program's declared ID.

## 7. Backend: Actions Controller Fix

**File:** `da-backend/app/controllers/actions_controller.rb`

Simplified `action_params` — removed the `params[:action].presence || params` fallback; now reads directly from `params`.

## 8. Backend: Seeds Rewrite

**File:** `da-backend/db/seeds.rb`

Replaced the `ActionLibraryInstaller` call with explicit `find_or_create_by!` blocks seeding:
- `weather_now` — detailed weather via wttr.in
- `weather` — simple weather via wttr.in
- `crypto_price` — CoinGecko price lookup
- (and potentially more actions further in the file)

## 9. Backend: New Initializer

**File:** `da-backend/config/initializers/active_record_encryption.rb` (untracked)

New Active Record encryption configuration.

## 10. Backend: Credentials Update

**File:** `da-backend/config/credentials.yml.enc`

Encrypted credentials file changed (contents not inspectable).

## 11. Example Contract Config

**File:** `example-anchor-contract/Anchor.toml` (+4 lines), `Cargo.lock` (+19 lines)

Added workspace member for `invoice-processor`; lockfile updated with new dependencies.

## 12. Project Scaffolding (staged)

- `example-anchor-contract/package.json` — new, with Anchor/Solana test dependencies
- `example-anchor-contract/tsconfig.json` — TypeScript config for tests
- `example-anchor-contract/yarn.lock` — dependency lockfile

---

## Not Included (should stay local)

- `.surfpool/logs/` — local simnet log files
- `da-backend/vendor/bundle/` — vendored Ruby gems
- `.claude/` — Claude Code working state
