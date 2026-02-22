import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { InvoiceProcessor } from "../target/types/invoice_processor";
import { assert } from "chai";

describe("e2e: invoice-processor", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace
    .invoiceProcessor as Program<InvoiceProcessor>;

  // Use the provider wallet as oracle_authority so the Rails backend
  // (which uses the same ~/.config/solana/id.json) can send callbacks.
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

  it("Initializes config with oracle_authority + max_payout", async () => {
    // Skip if already initialized
    try {
      const existing = await program.account.config.fetch(configPda);
      console.log(
        "  Config already initialized, request_counter:",
        existing.requestCounter.toNumber()
      );
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
    assert.equal(
      config.maxPayoutLamports.toNumber(),
      MAX_PAYOUT.toNumber()
    );
    assert.equal(config.allowlistLen, 0);

    console.log("  Config PDA:", configPda.toBase58());
    console.log("  Vault PDA:", vaultPda.toBase58());
    console.log("  Oracle authority:", oracleAuthority.toBase58());
    console.log("  Max payout:", MAX_PAYOUT.toNumber(), "lamports");
  });

  it("Adds test wallet to allowlist", async () => {
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

    console.log("  Allowlisted:", wallet.toBase58());
  });

  it("Funds vault with SOL", async () => {
    const balanceBefore = await provider.connection.getBalance(vaultPda);

    await program.methods
      .fund(FUND_AMOUNT)
      .accounts({
        depositor: provider.wallet.publicKey,
      })
      .rpc();

    const balanceAfter = await provider.connection.getBalance(vaultPda);
    assert.equal(
      balanceAfter - balanceBefore,
      FUND_AMOUNT.toNumber()
    );

    console.log("  Vault balance:", balanceAfter, "lamports");
  });

  it("Submits invoice and emits ActionRequested", async () => {
    const invoiceText =
      "Invoice #001: Web development services - 0.5 SOL";

    const configBefore = await program.account.config.fetch(configPda);
    const requestId = configBefore.requestCounter;

    const [invoicePda] = anchor.web3.PublicKey.findProgramAddressSync(
      [
        Buffer.from("invoice"),
        requestId.toArrayLike(Buffer, "le", 8),
      ],
      program.programId
    );

    const tx = await program.methods
      .submitInvoice(invoiceText)
      .accounts({
        submitter: provider.wallet.publicKey,
      })
      .rpc({ commitment: "confirmed" });

    console.log("  TX signature:", tx);

    // Verify Invoice PDA was created
    const invoice = await program.account.invoice.fetch(invoicePda);
    assert.equal(invoice.requestId.toNumber(), requestId.toNumber());
    assert.ok(invoice.submitter.equals(provider.wallet.publicKey));
    assert.equal(invoice.status, 0); // Pending
    assert.equal(invoice.amountLamports.toNumber(), 0);

    console.log("  Invoice PDA:", invoicePda.toBase58());
    console.log("  Request ID:", requestId.toNumber());
    console.log("  Status: Pending");

    // Verify request_counter incremented
    const configAfter = await program.account.config.fetch(configPda);
    assert.equal(
      configAfter.requestCounter.toNumber(),
      requestId.toNumber() + 1
    );

    // Verify ActionRequested event was emitted in logs
    const txDetails = await provider.connection.getTransaction(tx, {
      commitment: "confirmed",
      maxSupportedTransactionVersion: 0,
    });
    const hasEvent = txDetails.meta.logMessages.some((log) =>
      log.includes("Program data:")
    );
    assert.ok(hasEvent, "ActionRequested event should be in logs");

    console.log("\n  ActionRequested emitted on-chain.");
    console.log(
      "  If `SOLANA_PROGRAM_ID=" +
        program.programId.toBase58() +
        " rake solana:listen` is running, the oracle will:"
    );
    console.log("    1. Pick up this event");
    console.log("    2. POST to OpenRouter (ai_chat action)");
    console.log("    3. Send callback TX with the LLM response");
    console.log("    4. Parse amount and set invoice to Approved");
    console.log("    5. Anyone can then call settle() to pay out");
  });
});
