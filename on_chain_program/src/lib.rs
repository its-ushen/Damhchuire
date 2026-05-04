pub mod entrypoint {
    use solana_program::entrypoint::ProgramResult;

    use chord_core::{check_reentrancy, rpc_call, utils::log_u64};

    #[unsafe(no_mangle)]
    pub unsafe extern "C" fn entrypoint(_input: *mut u8) -> u64 {
        unsafe {
            check_reentrancy();
            process_instruction().unwrap();
            0
        }
    }

    #[inline(never)]
    pub fn process_instruction() -> ProgramResult {
        let r = rpc_call();
        log_u64(r);

        Ok(())
    }
}
