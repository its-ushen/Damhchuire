import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { InvoiceProcessor } from "../target/types/invoice_processor";
import { assert } from "chai";

// ── Pretty-print helpers ─────────────────────────────────────────────

const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const MAGENTA = "\x1b[35m";
const DIM = "\x1b[2m";
const BOLD = "\x1b[1m";
const RESET = "\x1b[0m";

function banner(title: string) {
  const line = "─".repeat(60);
  console.log(`\n${CYAN}${line}${RESET}`);
  console.log(`${CYAN}  ${BOLD}${title}${RESET}`);
  console.log(`${CYAN}${line}${RESET}`);
}

function field(label: string, value: string | number) {
  console.log(`  ${DIM}${label}:${RESET} ${value}`);
}

function success(msg: string) {
  console.log(`  ${GREEN}✔${RESET} ${msg}`);
}

function highlight(msg: string) {
  console.log(`  ${YELLOW}→${RESET} ${msg}`);
}

function solFromLamports(lamports: number): string {
  return `${(lamports / 1_000_000_000).toFixed(4)} SOL ${DIM}(${lamports.toLocaleString()} lamports)${RESET}`;
}

const STATUS_LABELS: Record<number, string> = {
  0: `${YELLOW}Pending${RESET}`,
  1: `${GREEN}Approved${RESET}`,
  2: `${MAGENTA}Settled${RESET}`,
  3: `${DIM}Rejected${RESET}`,
};

// ── Test Suite ────────────────────────────────────────────────────────

describe("e2e: invoice-processor", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace
    .invoiceProcessor as Program<InvoiceProcessor>;

  const oracleAuthority = provider.wallet.publicKey;

  const MAX_PAYOUT = new anchor.BN(1_000_000_000); // 1 SOL
  const FUND_AMOUNT = new anchor.BN(5_000_000_000); // 5 SOL

  const [configPda] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from("config")],
    program.programId
  );

  const [vaultPda] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from("vault")],
    program.programId
  );

  // We'll track the request ID across tests
  let requestId: anchor.BN;
  let invoicePda: anchor.web3.PublicKey;

  // ── Step 1 ─────────────────────────────────────────────────────────

  it("Step 1 · Initialize config", async () => {
    banner("STEP 1 — Initialize Config");

    // Skip if already initialized
    try {
      const existing = await program.account.config.fetch(configPda);
      highlight("Config already initialized, skipping.");
      field("Request counter", existing.requestCounter.toNumber());
      return;
    } catch {
      // Not initialized yet — proceed
    }

    await program.methods
      .initialize(oracleAuthority, MAX_PAYOUT)
      .accounts({
        authority: provider.wallet.publicKey,
      })
      .rpc();

    const config = await program.account.config.fetch(configPda);
    assert.ok(config.authority.equals(provider.wallet.publicKey));
    assert.ok(config.oracleAuthority.equals(oracleAuthority));
    assert.equal(config.requestCounter.toNumber(), 0);

    field("Program ID", program.programId.toBase58());
    field("Config PDA", configPda.toBase58());
    field("Vault PDA", vaultPda.toBase58());
    field("Oracle authority", oracleAuthority.toBase58());
    field("Max payout", solFromLamports(MAX_PAYOUT.toNumber()));
    success("Config account created on-chain");
  });

  // ── Step 2 ─────────────────────────────────────────────────────────

  it("Step 2 · Allowlist the submitter wallet", async () => {
    banner("STEP 2 — Allowlist Submitter");

    const wallet = provider.wallet.publicKey;

    await program.methods
      .addToAllowlist(wallet)
      .accounts({
        authority: provider.wallet.publicKey,
      })
      .rpc();

    const config = await program.account.config.fetch(configPda);
    assert.equal(config.allowlistLen, 1);
    assert.ok(config.allowlist[0].equals(wallet));

    field("Wallet", wallet.toBase58());
    field("Allowlist size", config.allowlistLen);
    success("Wallet added to allowlist");
  });

  // ── Step 3 ─────────────────────────────────────────────────────────

  it("Step 3 · Fund the vault", async () => {
    banner("STEP 3 — Fund Vault");

    const balanceBefore = await provider.connection.getBalance(vaultPda);

    await program.methods
      .fund(FUND_AMOUNT)
      .accounts({
        depositor: provider.wallet.publicKey,
      })
      .rpc();

    const balanceAfter = await provider.connection.getBalance(vaultPda);
    assert.equal(balanceAfter - balanceBefore, FUND_AMOUNT.toNumber());

    field("Deposited", solFromLamports(FUND_AMOUNT.toNumber()));
    field("Vault balance", solFromLamports(balanceAfter));
    success("Vault funded and ready for payouts");
  });

  // ── Step 4 ─────────────────────────────────────────────────────────

  it("Step 4 · Submit invoice → emits ActionRequested", async () => {
    banner("STEP 4 — Submit Invoice");

    const invoiceText =
      "Invoice #001: Web development services - 0.5 SOL";

    const configBefore = await program.account.config.fetch(configPda);
    requestId = configBefore.requestCounter;

    [invoicePda] = anchor.web3.PublicKey.findProgramAddressSync(
      [
        Buffer.from("invoice"),
        requestId.toArrayLike(Buffer, "le", 8),
      ],
      program.programId
    );

    field("Invoice text", `"${invoiceText}"`);
    console.log();

    const tx = await program.methods
      .submitInvoice(invoiceText)
      .accounts({
        submitter: provider.wallet.publicKey,
      })
      .rpc({ commitment: "confirmed" });

    const invoice = await program.account.invoice.fetch(invoicePda);
    assert.equal(invoice.requestId.toNumber(), requestId.toNumber());
    assert.equal(invoice.status, 0); // Pending

    field("TX signature", tx);
    field("Invoice PDA", invoicePda.toBase58());
    field("Request ID", requestId.toNumber());
    field("Status", STATUS_LABELS[invoice.status]);
    console.log();
    highlight(
      `ActionRequested event emitted on-chain`
    );
    highlight(
      `Oracle picks this up → sends to LLM → parses amount`
    );
    success("Invoice submitted, waiting for oracle callback...");
  });

  // ── Step 5 ─────────────────────────────────────────────────────────

  it("Step 5 · Wait for oracle callback → invoice approved", async () => {
    banner("STEP 5 — Waiting for Oracle Callback");

    highlight("Listening for on-chain status change...");
    highlight(
      `Make sure the oracle is running: ${BOLD}rake solana:listen${RESET}`
    );
    console.log();

    const POLL_INTERVAL_MS = 2_000;
    const MAX_WAIT_MS = 120_000; // 2 minutes
    const start = Date.now();
    let invoice: any;

    while (Date.now() - start < MAX_WAIT_MS) {
      invoice = await program.account.invoice.fetch(invoicePda);

      if (invoice.status !== 0) {
        // No longer Pending — oracle has responded
        break;
      }

      const elapsed = ((Date.now() - start) / 1000).toFixed(0);
      process.stdout.write(
        `\r  ${DIM}Polling invoice... ${elapsed}s elapsed${RESET}   `
      );

      await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
    }

    // Clear the polling line
    process.stdout.write("\r" + " ".repeat(60) + "\r");

    assert.notEqual(
      invoice!.status,
      0,
      `Invoice still Pending after ${MAX_WAIT_MS / 1000}s — is the oracle running?`
    );

    field("Status", STATUS_LABELS[invoice!.status]);

    if (invoice!.status === 1) {
      // Approved
      field(
        "Approved amount",
        solFromLamports(invoice!.amountLamports.toNumber())
      );
      success("Oracle approved the invoice!");
    } else if (invoice!.status === 3) {
      // Rejected
      highlight("Oracle rejected the invoice (amount_sol was 0 or parse failed)");
    }

    const elapsed = ((Date.now() - start) / 1000).toFixed(1);
    field("Round-trip time", `${elapsed}s`);

    // ── Extract raw LLM output from the callback transaction ──────
    try {
      const sigs = await provider.connection.getSignaturesForAddress(
        invoicePda,
        { limit: 5 },
        "confirmed"
      );

      // Find the callback tx (the most recent tx that isn't the submit)
      for (const sigInfo of sigs) {
        const tx = await provider.connection.getTransaction(
          sigInfo.signature,
          { commitment: "confirmed", maxSupportedTransactionVersion: 0 }
        );
        if (!tx?.meta || !tx.transaction.message) continue;

        // Look through instructions for the callback
        const message = tx.transaction.message;
        const accountKeys =
          "staticAccountKeys" in message
            ? (message as any).staticAccountKeys
            : (message as any).accountKeys;

        for (const ix of message.compiledInstructions ?? (message as any).instructions ?? []) {
          const programIdx = "programIdIndex" in ix ? ix.programIdIndex : ix.programIdIndex;
          const programKey = accountKeys[programIdx];
          if (!programKey || !programKey.equals(program.programId)) continue;

          // Decode instruction data
          const data = Buffer.from("data" in ix ? ix.data : ix.data);
          // Anchor discriminator = 8 bytes, then request_id (u64 = 8), ok (bool = 1), then result_json (Vec<u8>: 4-byte len + bytes)
          if (data.length < 21) continue; // too short for callback

          const offset = 8 + 8 + 1; // skip discriminator + request_id + ok
          const vecLen = data.readUInt32LE(offset);
          if (offset + 4 + vecLen > data.length) continue;

          const resultJsonBytes = data.subarray(offset + 4, offset + 4 + vecLen);
          const resultJsonStr = Buffer.from(resultJsonBytes).toString("utf-8");

          // Parse and extract LLM content
          try {
            const outer = JSON.parse(resultJsonStr);
            const content = outer?.choices?.[0]?.message?.content;
            if (content) {
              console.log();
              banner("RAW LLM OUTPUT");
              console.log(`\n${MAGENTA}${content}${RESET}\n`);
              field("Full response JSON (truncated)", resultJsonStr.slice(0, 500));
            }
          } catch {
            // Not a valid callback payload, skip
          }
        }
      }
    } catch (err) {
      highlight(`Could not extract raw LLM output: ${err}`);
    }
  });

  // ── Step 6 ─────────────────────────────────────────────────────────

  it("Step 6 · Settle → SOL paid to submitter", async () => {
    banner("STEP 6 — Settle Invoice");

    // Check if invoice was approved (skip settle if rejected)
    const invoiceBefore = await program.account.invoice.fetch(invoicePda);
    if (invoiceBefore.status !== 1) {
      highlight("Invoice was not approved — skipping settlement");
      return;
    }

    const payoutAmount = invoiceBefore.amountLamports.toNumber();
    const submitter = provider.wallet.publicKey;

    const submitterBefore = await provider.connection.getBalance(submitter);
    const vaultBefore = await provider.connection.getBalance(vaultPda);

    field("Submitter balance (before)", solFromLamports(submitterBefore));
    field("Vault balance (before)", solFromLamports(vaultBefore));
    field("Payout amount", solFromLamports(payoutAmount));
    console.log();

    const tx = await program.methods
      .settle()
      .accounts({
        invoice: invoicePda,
        submitter: submitter,
      })
      .rpc({ commitment: "confirmed" });

    const submitterAfter = await provider.connection.getBalance(submitter);
    const vaultAfter = await provider.connection.getBalance(vaultPda);
    const invoice = await program.account.invoice.fetch(invoicePda);

    assert.equal(invoice.status, 2); // Settled

    field("TX signature", tx);
    field("Status", STATUS_LABELS[invoice.status]);
    field("Submitter balance (after)", solFromLamports(submitterAfter));
    field("Vault balance (after)", solFromLamports(vaultAfter));
    console.log();
    success(
      `Submitter received ${BOLD}${solFromLamports(payoutAmount)}${RESET}`
    );

    // ── Final summary ──────────────────────────────────────────────
    banner("DEMO COMPLETE");
    console.log(`
  ${DIM}Full lifecycle:${RESET}
    1. Config initialized with oracle authority + max payout cap
    2. Submitter wallet added to allowlist
    3. Vault funded with ${solFromLamports(FUND_AMOUNT.toNumber())}
    4. Invoice submitted → ${CYAN}ActionRequested${RESET} emitted on-chain
    5. Oracle picked up event → called LLM → ${GREEN}Approved${RESET} for ${solFromLamports(payoutAmount)}
    6. Settlement executed → ${MAGENTA}${solFromLamports(payoutAmount)}${RESET} transferred to submitter
`);
  });
});
