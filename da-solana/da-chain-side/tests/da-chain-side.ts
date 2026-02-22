import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { DaChainSide } from "../target/types/da_chain_side";
import { assert } from "chai";

describe("da-chain-side", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.daChainSide as Program<DaChainSide>;
  const oracle = anchor.web3.Keypair.generate();

  const [configPda] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from("config")],
    program.programId
  );

  it("Initializes config", async () => {
    await program.methods.initialize(oracle.publicKey).rpc();

    const config = await program.account.config.fetch(configPda);
    assert.ok(config.authority.equals(provider.wallet.publicKey));
    assert.ok(config.oracleAuthority.equals(oracle.publicKey));
    assert.equal(config.requestCounter.toNumber(), 0);
  });

  it("Emits an action request event", async () => {
    const params = Buffer.from(JSON.stringify({ city: "Dublin" }), "utf-8");

    const tx = await program.methods
      .onCall("weather", params)
      .accounts({
        caller: provider.wallet.publicKey,
      })
      .rpc({ commitment: "confirmed" });

    // Verify counter incremented
    const config = await program.account.config.fetch(configPda);
    assert.equal(config.requestCounter.toNumber(), 1);

    // Verify event is in transaction logs
    const txDetails = await provider.connection.getTransaction(tx, {
      commitment: "confirmed",
      maxSupportedTransactionVersion: 0,
    });
    assert.ok(txDetails.meta.logMessages.some((log) => log.includes("Program data:")));
  });

  it("Rejects unauthorized callback signer", async () => {
    const impostor = anchor.web3.Keypair.generate();

    try {
      await program.methods
        .callback(new anchor.BN(0), false, Buffer.from("{}"))
        .accounts({
          oracleAuthority: impostor.publicKey,
        })
        .signers([impostor])
        .rpc();
      assert.fail("Should have thrown");
    } catch (err) {
      assert.ok(err.toString().includes("UnauthorizedOracle"));
    }
  });

  it("Allows configured oracle callback", async () => {
    const tx = await program.methods
      .callback(new anchor.BN(1), true, Buffer.from(JSON.stringify({ temp_c: 11.2 })))
      .accounts({
        oracleAuthority: oracle.publicKey,
      })
      .signers([oracle])
      .rpc({ commitment: "confirmed" });

    const txDetails = await provider.connection.getTransaction(tx, {
      commitment: "confirmed",
      maxSupportedTransactionVersion: 0,
    });
    assert.ok(txDetails.meta.logMessages.some((log) => log.includes("Program data:")));
  });
});
