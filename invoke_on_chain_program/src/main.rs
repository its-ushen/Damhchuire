use std::str::FromStr;

use solana_client::{nonblocking::rpc_client::RpcClient, rpc_config::RpcSendTransactionConfig};
use solana_sdk::{
    message::{Instruction, Message},
    pubkey::Pubkey,
    signer::{Signer, keypair},
    transaction::Transaction,
};

use anyhow::Result;

const PROGRAM_ADDRESS: &'static str = "VtdLC5QQeCmpzzCMtgtoABtrPvmsKtrMFuw3hKPhNX6";

#[tokio::main]
async fn main() -> Result<()> {
    let rpc = RpcClient::new("https://api.devnet.solana.com".to_string());
    let pubkey = Pubkey::from_str(PROGRAM_ADDRESS).unwrap();
    let user_keypair = keypair::read_keypair_file("/home/violet/.config/solana/id.json").unwrap();

    let input = vec![0x0];

    let initialize_instruction = Instruction::new_with_bytes(pubkey, &input, vec![]);

    let message = Message::new(&[initialize_instruction], Some(&user_keypair.pubkey()));
    let transaction =
        Transaction::new(&[&user_keypair], message, rpc.get_latest_blockhash().await?);

    let signature = rpc
        .send_transaction_with_config(
            &transaction,
            RpcSendTransactionConfig {
                skip_preflight: true,
                ..RpcSendTransactionConfig::default()
            },
        )
        .await?;

    Ok(())
}
