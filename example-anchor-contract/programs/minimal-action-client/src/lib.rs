use anchor_lang::prelude::*;
use damhchuire_sdk::{
    call_weather_now_action_from, AnchorEmitError, HasRequestCounter, WeatherNowParams,
};

declare_id!("EKREuFxufeoy2uyw5GKcwwMonYQipmnoVtCKcpGzr55U");

const PREDEFINED_CITY: &str = "Dublin";

#[program]
pub mod minimal_action_client {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, oracle_authority: Pubkey) -> Result<()> {
        let config = &mut ctx.accounts.config;
        config.authority = ctx.accounts.authority.key();
        config.oracle_authority = oracle_authority;
        config.request_counter = 0;
        Ok(())
    }

    pub fn on_call(ctx: Context<OnCall>) -> Result<()> {
        let weather_params = WeatherNowParams {
            city: PREDEFINED_CITY.to_string(),
            unit: None,
        };

        call_weather_now_action_from(&mut ctx.accounts.config, weather_params)
            .map_err(map_sdk_emit_error)?;

        Ok(())
    }

    pub fn callback(
        _ctx: Context<Callback>,
        request_id: u64,
        ok: bool,
        result_json: Vec<u8>,
    ) -> Result<()> {
        emit!(ActionCompleted {
            request_id,
            ok,
            result_json,
        });
        Ok(())
    }
}

fn map_sdk_emit_error(error: AnchorEmitError) -> Error {
    match error {
        AnchorEmitError::CounterOverflow => error!(ClientProgramError::CounterOverflow),
        AnchorEmitError::Client(_) => error!(ClientProgramError::SdkPrimitiveFailed),
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + Config::INIT_SPACE,
        seeds = [b"config"],
        bump
    )]
    pub config: Account<'info, Config>,
    #[account(mut)]
    pub authority: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct OnCall<'info> {
    #[account(mut, seeds = [b"config"], bump)]
    pub config: Account<'info, Config>,
}

#[derive(Accounts)]
pub struct Callback<'info> {
    #[account(
        seeds = [b"config"],
        bump,
        has_one = oracle_authority @ ClientProgramError::UnauthorizedOracle
    )]
    pub config: Account<'info, Config>,
    pub oracle_authority: Signer<'info>,
}

#[account]
pub struct Config {
    pub authority: Pubkey,
    pub oracle_authority: Pubkey,
    pub request_counter: u64,
}

impl Config {
    pub const INIT_SPACE: usize = 32 + 32 + 8;
}

impl HasRequestCounter for Config {
    fn request_counter_mut(&mut self) -> &mut u64 {
        &mut self.request_counter
    }
}

#[event]
pub struct ActionCompleted {
    pub request_id: u64,
    pub ok: bool,
    pub result_json: Vec<u8>,
}

#[error_code]
pub enum ClientProgramError {
    #[msg("SDK primitive failed")]
    SdkPrimitiveFailed,
    #[msg("Only configured oracle authority can submit callbacks")]
    UnauthorizedOracle,
    #[msg("Request counter overflowed")]
    CounterOverflow,
}
