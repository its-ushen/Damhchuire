import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { DaChainSide } from "../target/types/da_chain_side";
import { assert } from "chai";

describe("e2e: ai_chat via oracle", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.daChainSide as Program<DaChainSide>;

  // Use the provider wallet as oracle_authority so the Rails backend
  // (which uses the same ~/.config/solana/id.json) can send callbacks.
  const oracleAuthority = provider.wallet.publicKey;

  const [configPda] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from("config")],
    program.programId
  );

  it("Initializes config (wallet = oracle_authority)", async () => {
    // Skip if already initialized
    try {
      const existing = await program.account.config.fetch(configPda);
      console.log("  Config already initialized, request_counter:", existing.requestCounter.toNumber());
      return;
    } catch {
      // Not initialized yet — proceed
    }

    await program.methods.initialize(oracleAuthority).rpc();

    const config = await program.account.config.fetch(configPda);
    assert.ok(config.authority.equals(provider.wallet.publicKey));
    assert.ok(config.oracleAuthority.equals(oracleAuthority));
    console.log("  Config PDA:", configPda.toBase58());
    console.log("  Oracle authority:", oracleAuthority.toBase58());
  });

  it("Fires ai_chat ActionRequested event", async () => {
    const params = JSON.stringify({
      model: "openai/gpt-4o-mini",
      messages: [
        { role: "user", content: "Summarize what Solana is in one sentence." },
      ],
    });

    const tx = await program.methods
      .onCall("ai_chat", Buffer.from(params, "utf-8"))
      .accounts({
        caller: provider.wallet.publicKey,
      })
      .rpc({ commitment: "confirmed" });

    console.log("  TX signature:", tx);

    const config = await program.account.config.fetch(configPda);
    console.log("  Request counter:", config.requestCounter.toNumber());

    // Verify the event was emitted in logs
    const txDetails = await provider.connection.getTransaction(tx, {
      commitment: "confirmed",
      maxSupportedTransactionVersion: 0,
    });
    const hasEvent = txDetails.meta.logMessages.some((log) =>
      log.includes("Program data:")
    );
    assert.ok(hasEvent, "ActionRequested event should be in logs");

    console.log("\n  ✓ ActionRequested emitted on-chain.");
    console.log("  → If `rake solana:listen` is running, the oracle will:");
    console.log("    1. Pick up this event");
    console.log("    2. POST to OpenRouter (ai_chat action)");
    console.log("    3. Send callback TX with the LLM response");
    console.log("    4. Emit ActionCompleted event");
  });
});
