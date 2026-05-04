pub mod utils;

unsafe extern "C" {
    pub fn check_reentrancy() -> u8;
    fn trigger_reinvoking_rpc(_fake_arg_to_force_r1_free: u64) -> u64;
    fn rustc_cant_guess_this() -> u64;
}

pub fn rpc_call() -> u64 {
    unsafe { trigger_reinvoking_rpc(0xff) }
}
