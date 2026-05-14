use futures_util::StreamExt;
use solana_client::{
    client_error::reqwest,
    nonblocking::{pubsub_client::PubsubClient, rpc_client::RpcClient},
    rpc_config::{RpcSendTransactionConfig, RpcTransactionLogsConfig, RpcTransactionLogsFilter},
};
use solana_sbpf::{
    aligned_memory::AlignedMemory,
    declare_builtin_function, ebpf,
    elf::Executable,
    error::{EbpfError, StableResult},
    memory_region::{MemoryMapping, MemoryRegion},
    program::{BuiltinFunctionDefinition, BuiltinProgram},
    verifier::RequisiteVerifier,
    vm::{CallFrame, Config, EbpfVm, ExecutionMode},
};
use solana_sdk::{
    message::{Instruction, Message},
    pubkey::Pubkey,
    signer::{Signer, keypair},
    transaction::Transaction,
};

use std::{str::FromStr, sync::Arc};

use serde::{Deserialize, Serialize};
use test_utils::{TestContextObject, syscalls};

use anyhow::Result;

const WEB_UI_RPC_URL: &'static str = "http://localhost:3000/rpc";

declare_builtin_function!(
    SyscallPanic,
    fn rust(
        context_object: &mut TestContextObject,
        arg1: u64,
        arg2: u64,
        arg3: u64,
        arg4: u64,
        arg5: u64,
    ) -> Result<u64, Box<dyn std::error::Error>> {
        Err(Box::new(EbpfError::JitNotCompiled))
    }
);

#[derive(Serialize, Deserialize)]
struct RPCCallParameters {
    caller: String,
    action_id: String,
    text: String,
}

async fn rpc_call() -> Result<u64> {
    let client = reqwest::Client::new();

    // TODO - pass in actual parameters
    let res = client
        .post(WEB_UI_RPC_URL)
        .json(&RPCCallParameters {
            caller: "1".to_string(),
            action_id: "1".to_string(),
            text: "8".to_string(),
        })
        .send()
        .await?;

    // TODO - return correct value
    Ok(0x42)
}

fn run_program_with_input(
    elf_bytes: &[u8],
    input: &[u8],
) -> (Vec<CallFrame>, StableResult<u64, EbpfError>, [u64; 12]) {
    let mut owned_input = input.to_vec();

    let mut _loader = BuiltinProgram::new_loader(Config {
        enable_register_tracing: false,
        enable_symbol_and_section_labels: true,
        ..Config::default()
    });

    syscalls::SyscallString::register(&mut _loader, "sol_log_").unwrap();
    syscalls::SyscallU64::register(&mut _loader, "sol_log_64_").unwrap();
    SyscallPanic::register(&mut _loader, "sol_panic_").unwrap();

    let loader = Arc::new(_loader);

    let executable = Executable::<TestContextObject>::from_elf(elf_bytes, loader)
        .map_err(|err| format!("Executable constructor failed: {err:?}"))
        .unwrap();

    executable.verify::<RequisiteVerifier>().unwrap();

    let mut mode = ExecutionMode::Interpreted;

    let mut context_object = TestContextObject::new(20000);

    let config = executable.get_config();
    let sbpf_version = executable.get_sbpf_version();
    let mut stack = AlignedMemory::<{ ebpf::HOST_ALIGN }>::zero_filled(config.stack_size());
    let stack_len = stack.len();
    let mut heap = AlignedMemory::<{ ebpf::HOST_ALIGN }>::zero_filled(0);

    let regions: Vec<MemoryRegion> = vec![
        executable.get_ro_region(),
        MemoryRegion::new_gapped(
            &raw mut *stack.as_slice_mut(),
            ebpf::MM_STACK_START,
            if sbpf_version.stack_frame_gaps() && config.enable_stack_frame_gaps {
                config.stack_frame_size as u64
            } else {
                0
            },
        ),
        MemoryRegion::new(&raw mut *heap.as_slice_mut(), ebpf::MM_HEAP_START),
    ];

    context_object.memory_mapping =
        unsafe { MemoryMapping::new(regions, config, sbpf_version).unwrap() };

    let mut vm = EbpfVm::new(
        executable.get_loader().clone(),
        executable.get_sbpf_version(),
        &mut context_object,
        stack_len,
    );

    let mut call_frames = vec![CallFrame::default(); config.max_call_depth];
    let (_, result) = vm.execute_program(&executable, &mut mode, &mut call_frames);

    return (call_frames, result, vm.registers);
}

// todo - we can type this better
struct ReinvokingInput<'a> {
    should_reinvoke: bool,
    rpc_return_val: u64,
    registers: &'a [u64],
    frame_return_addresses: &'a [u64],
}

impl<'a> ReinvokingInput<'a> {
    pub fn new(
        should_reinvoke: bool,
        rpc_return_val: u64,
        registers: &'a [u64],
        frame_return_addresses: &'a [u64],
    ) -> Self {
        Self {
            should_reinvoke,
            rpc_return_val,
            registers,
            frame_return_addresses,
        }
    }

    pub fn serialize(&self) -> Vec<u8> {
        // this is in place of the program address
        // 16 program address bytes
        let input_padding = vec![0u8; 16];

        let registers_copy = self.registers;

        [
            // input_padding,
            vec![
                self.should_reinvoke as u8,
                self.frame_return_addresses.len() as u8,
            ],
            vec![0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
            u64::to_le_bytes(self.rpc_return_val).to_vec(),
            registers_copy[1..10]
                .iter()
                .flat_map(|i| u64::to_le_bytes(*i))
                .collect::<Vec<_>>(),
            self.frame_return_addresses
                .iter()
                .flat_map(|i| u64::to_le_bytes(*i))
                .collect::<Vec<_>>(),
        ]
        .concat()
    }
}

async fn reinvocation_demo(rpc: &RpcClient) -> Result<()> {
    let pubkey = Pubkey::from_str(PROGRAM_ADDRESS).unwrap();
    let elf_bytes = fetch_program_elf_data(&rpc, &pubkey).await?;

    let non_reentering_input =
        ReinvokingInput::new(false, 0, &[0, 0, 0, 0, 0, 0, 0, 0, 0, 0], &[]).serialize();

    let (call_frames, result, registers) =
        run_program_with_input(&elf_bytes, &mut non_reentering_input.clone());

    match result {
        StableResult::Ok(_) => panic!("shouldn't be okay!"),
        StableResult::Err(e) => match e {
            EbpfError::SyscallError(_) => {}
            _ => panic!("should be a ebpferror syscallerror!"),
        },
    }

    // the magic!
    let rpc_result = rpc_call().await?;

    let num_call_frames = call_frames.iter().position(|i| i.target_pc == 0).unwrap();

    // TODO - why do we need to copy in the caller saved registers?
    let mut registers_copy = registers.clone();
    let caller_saved_registers = call_frames[num_call_frames - 1].caller_saved_registers;
    registers_copy[6..10].copy_from_slice(&caller_saved_registers);

    let callx_frame_return_addresses = call_frames
        .iter()
        .take(num_call_frames)
        .map(|i| (i.target_pc * 8) + 0x100000120)
        .collect::<Vec<_>>();

    let reinvoking_inputs = ReinvokingInput::new(
        true,
        rpc_result,
        &registers_copy,
        &callx_frame_return_addresses,
    )
    .serialize();

    let user_keypair = keypair::read_keypair_file("/home/violet/.config/solana/id.json").unwrap();

    let initialize_instruction = Instruction::new_with_bytes(pubkey, &reinvoking_inputs, vec![]);

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

    println!("{:?}", &signature);
    Ok(())
}

const PROGRAM_ADDRESS: &'static str = "VtdLC5QQeCmpzzCMtgtoABtrPvmsKtrMFuw3hKPhNX6";

async fn fetch_program_elf_data(rpc: &RpcClient, pubkey: &Pubkey) -> Result<Vec<u8>> {
    // TODO - better checking this is a program account
    let program_metadata = rpc.get_account(pubkey).await?.data;
    let program_data_address = Pubkey::new_from_array(program_metadata[4..].try_into().unwrap());

    let program_data = rpc.get_account(&program_data_address).await?.data;

    // Fixed by a constant in bpf_loader_upgradeable. TODO - pull this in instead of hard coding
    Ok(program_data[45..].to_vec())
}

#[tokio::main]
async fn main() -> Result<()> {
    let rpc = RpcClient::new("https://api.devnet.solana.com".to_string());
    let pubsub_client = PubsubClient::new("ws://api.devnet.solana.com").await?;

    let (mut log_notifications, unsubscribe) = pubsub_client
        .logs_subscribe(
            RpcTransactionLogsFilter::Mentions(vec![PROGRAM_ADDRESS.to_string()]),
            RpcTransactionLogsConfig { commitment: None },
        )
        .await?;

    while let Some(logs) = log_notifications.next().await {
        println!("{:?}", logs.value.logs);

        if !logs.value.logs[logs.value.logs.len() - 1].contains("Panicked") {
            continue;
        }

        reinvocation_demo(&rpc).await?;
    }

    Ok(())
}
