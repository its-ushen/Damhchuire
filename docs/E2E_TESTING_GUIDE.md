# E2E Manual Testing Guide — AI Chat Action (Surfpool)

This guide walks through the full on-chain flow: Solana contract emits
`ActionRequested` → Rails oracle picks it up → calls OpenRouter → writes the
LLM response back on-chain via `callback`.

## Prerequisites

- [Surfpool CLI](https://docs.surfpool.run/) installed (`surfpool --version`)
- Solana CLI (`solana --version`)
- Anchor CLI (`anchor --version`)
- Ruby/Rails deps installed (`cd da-backend && bundle install`)
- `OPENROUTER_API_KEY` env var set

---

## Step 1: Build the oracle program

```bash
cd da-solana/da-chain-side
anchor build
```

Note the program binary at `target/deploy/da_chain_side.so` and keypair at
`target/deploy/da_chain_side-keypair.json`.

## Step 2: Start Surfpool

```bash
surfpool start
```

This starts a local validator at `http://127.0.0.1:8899` (RPC) and
`ws://127.0.0.1:8900` (WebSocket). Surfpool Studio is at
`http://127.0.0.1:18488`.

## Step 3: Airdrop SOL to your wallet

```bash
solana airdrop 10
```

## Step 4: Deploy the oracle program

```bash
solana program deploy \
  da-solana/da-chain-side/target/deploy/da_chain_side.so \
  --program-id da-solana/da-chain-side/target/deploy/da_chain_side-keypair.json
```

Verify it deployed:
```bash
solana program show 91XcSJyrQZpmJifL9TggBXHrXELtNrP3xSZ217DVGjWs
```

## Step 5: Initialize the oracle program's config PDA

The `DaTaskEmitter` in Rails will handle this, but the config PDA must exist
first. Use a Rails runner:

```bash
cd da-backend
bundle exec bin/rails runner '
  emitter = DaTaskEmitter.new
  # The first on_call will fail if config is not initialized.
  # Initialize by sending the initialize instruction:
  puts "Wallet pubkey: #{Base64.strict_encode64(emitter.send(:signing_key).verify_key.to_bytes)}"
'
```

**Alternative:** Initialize via Anchor CLI from the da-chain-side project:

```bash
cd da-solana/da-chain-side

# Get your wallet pubkey (this will be the oracle_authority)
solana address

# Call initialize with your wallet as oracle_authority
# (Requires a small TypeScript snippet or anchor test — see below)
```

Quick initialize script (save as `init.ts` and run with `npx ts-node`):

```typescript
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { PublicKey, SystemProgram } from "@solana/web3.js";

const provider = anchor.AnchorProvider.env();
anchor.setProvider(provider);

const PROGRAM_ID = new PublicKey("91XcSJyrQZpmJifL9TggBXHrXELtNrP3xSZ217DVGjWs");
const idl = JSON.parse(require("fs").readFileSync("target/idl/da_chain_side.json", "utf8"));
const program = new Program(idl, provider);

(async () => {
  const [configPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("config")],
    PROGRAM_ID
  );

  // oracle_authority = your wallet (so Rails can send callbacks)
  const oracleAuthority = provider.wallet.publicKey;

  const tx = await program.methods
    .initialize(oracleAuthority)
    .accounts({
      config: configPda,
      authority: provider.wallet.publicKey,
      systemProgram: SystemProgram.programId,
    })
    .rpc();

  console.log("Initialized config PDA:", configPda.toBase58());
  console.log("TX:", tx);
})();
```

## Step 6: Seed the database

```bash
cd da-backend
OPENROUTER_API_KEY=your-key-here bundle exec bin/rails db:prepare db:seed
```

## Step 7: Start the Rails oracle listener

Terminal 1:
```bash
cd da-backend
ACTION_HTTP_READ_TIMEOUT=45 bundle exec rake solana:listen
```

You should see:
```
[solana:listen] Starting event listener...
[solana:listen] Program: 91XcSJyrQZpmJifL9TggBXHrXELtNrP3xSZ217DVGjWs
[solana:listen] WS URL:  ws://127.0.0.1:8900
```

## Step 8: Fire the AI Chat action on-chain

Terminal 2:
```bash
cd da-backend
ACTION_HTTP_READ_TIMEOUT=45 bundle exec bin/rails runner '
emitter = DaTaskEmitter.new

params = {
  "model" => "openai/gpt-4o-mini",
  "messages" => [
    { "role" => "user", "content" => "Summarize what Solana is in one sentence." }
  ]
}

sig = emitter.on_call(
  action_slug: "ai_chat",
  params_json: params
)

puts "Submitted on_call TX: #{sig}"
puts "Watch Terminal 1 for the oracle picking it up..."
'
```

## What happens next (automatically)

1. **Surfpool** confirms the transaction
2. **EventListener** (Terminal 1) sees the `ActionRequested` log:
   ```
   === ActionRequested Event ===
     request_id: 0
     action_slug: ai_chat
     params_json (raw): <N bytes>
     tx: <signature>
   =============================
   ```
3. **ProcessActionRequest** resolves `{{credential.ai_chat_api_key}}` from the
   Credential table and POSTs to `https://openrouter.ai/api/v1/chat/completions`
4. **OpenRouter returns** the LLM response
5. **DaTaskEmitter.callback** writes the result back on-chain
6. **EventListener** sees the `ActionCompleted` event:
   ```
   === ActionCompleted Event ===
     request_id: 0
     ok: true
     result_json (raw): <N bytes>
   =============================
   ```

## Step 9: Verify the invocation record

```bash
cd da-backend
bundle exec bin/rails runner '
inv = ActionInvocation.last
puts "Status: #{inv.status}"
puts "Action: #{inv.action_slug}"
puts "HTTP:   #{inv.http_status}"
puts "Response:"
puts JSON.pretty_generate(JSON.parse(inv.response_body))
'
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Missing Active Record encryption credential` | Ensure `config/master.key` exists (see main README) |
| `Net::ReadTimeout` on OpenRouter call | Set `ACTION_HTTP_READ_TIMEOUT=45` |
| `ProgramAccountNotFound` | Config PDA not initialized — run Step 5 |
| `UnauthorizedOracle` on callback | The wallet used by Rails must match the `oracle_authority` set during `initialize` |
| Listener not seeing events | Check `SOLANA_PROGRAM_ID` matches the deployed program |

---

## Quick smoke test (no blockchain)

Skip all Solana setup and test the HTTP call directly:

```bash
cd da-backend
ACTION_HTTP_READ_TIMEOUT=45 bundle exec bin/rails runner '
action = Action.find_by!(slug: "ai_chat")
params = {
  "model" => "openai/gpt-4o-mini",
  "messages" => [{ "role" => "user", "content" => "Say hello in 5 words." }]
}
result = ActionOracle::RestExecutor.new(action: action, params: params).call
puts "HTTP #{result[:status]}"
puts JSON.pretty_generate(result[:parsed_body])
'
```
