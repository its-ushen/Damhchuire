import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { DaChainSide } from "../target/types/da_chain_side";
import { assert } from "chai";

describe("da-chain-side", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.daChainSide as Program<DaChainSide>;

  const [configPda] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from("config")],
    program.programId
  );

  it("Initializes config", async () => {
    await program.methods.initialize().rpc();

    const config = await program.account.config.fetch(configPda);
    assert.ok(config.authority.equals(provider.wallet.publicKey));
    assert.equal(config.taskCounter.toNumber(), 0);
  });

  it("Emits a task event", async () => {
    const data = Buffer.from([0xde, 0xad, 0xbe, 0xef]);

    const tx = await program.methods
      .emitTask(data)
      .rpc({ commitment: "confirmed" });

    // Verify counter incremented
    const config = await program.account.config.fetch(configPda);
    assert.equal(config.taskCounter.toNumber(), 1);

    // Verify event is in transaction logs
    const txDetails = await provider.connection.getTransaction(tx, {
      commitment: "confirmed",
      maxSupportedTransactionVersion: 0,
    });
    assert.ok(txDetails.meta.logMessages.some((log) => log.includes("Program data:")));
  });

  it("Rejects unauthorized emitter", async () => {
    const impostor = anchor.web3.Keypair.generate();

    // Airdrop SOL to impostor so they can sign
    const sig = await provider.connection.requestAirdrop(
      impostor.publicKey,
      1_000_000_000
    );
    await provider.connection.confirmTransaction(sig);

    try {
      await program.methods
        .emitTask(Buffer.from([0x00]))
        .accounts({
          authority: impostor.publicKey,
        })
        .signers([impostor])
        .rpc();
      assert.fail("Should have thrown");
    } catch (err) {
      assert.ok(err.toString().includes("ConstraintHasOne") || err.toString().includes("has_one"));
    }
  });
});
