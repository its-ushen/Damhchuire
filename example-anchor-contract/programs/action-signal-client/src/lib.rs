use anchor_lang::prelude::*;
use anchor_lang::system_program;
use damhchuire_sdk::{
    call_weather_now_action_from, AnchorEmitError, HasRequestCounter, WeatherNowParams,
};

declare_id!("EbAzCoVqhvdxhoTit1puKFHKLUQzftrLzTTgQDuspMEG");
const PREDEFINED_CITY: &str = "Dublin";

#[program]
pub mod action_signal_client {
    use super::*;

    pub fn initialize(
        ctx: Context<Initialize>,
        oracle_authority: Pubkey,
        merchant: Pubkey,
    ) -> Result<()> {
        let config = &mut ctx.accounts.config;
        config.authority = ctx.accounts.authority.key();
        config.oracle_authority = oracle_authority;
        config.merchant = merchant;
        config.request_counter = 0;
        Ok(())
    }

    pub fn on_call(ctx: Context<OnCall>, params: OnCallParams) -> Result<()> {
        let OnCallParams {
            amount_lamports,
            payment_reference,
            action_params_json: _,
        } = params;

        require!(amount_lamports > 0, ClientProgramError::InvalidPaymentAmount);
        require!(
            !payment_reference.trim().is_empty(),
            ClientProgramError::MissingPaymentReference
        );
        require!(
            payment_reference.len() <= 64,
            ClientProgramError::PaymentReferenceTooLong
        );

        let transfer_accounts = system_program::Transfer {
            from: ctx.accounts.caller.to_account_info(),
            to: ctx.accounts.merchant.to_account_info(),
        };
        let transfer_ctx =
            CpiContext::new(ctx.accounts.system_program.to_account_info(), transfer_accounts);
        system_program::transfer(transfer_ctx, amount_lamports)?;

        let weather_params = WeatherNowParams {
            city: PREDEFINED_CITY.to_string(),
            unit: None,
        };

        let request_id = call_weather_now_action_from(&mut ctx.accounts.config, weather_params)
        .map_err(map_sdk_emit_error)?;

        emit!(PaymentCompleted {
            payer: ctx.accounts.caller.key(),
            merchant: ctx.accounts.merchant.key(),
            amount_lamports,
            payment_reference,
            weather_request_id: request_id,
        });

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

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Debug)]
pub struct OnCallParams {
    pub amount_lamports: u64,
    pub payment_reference: String,
    pub action_params_json: Vec<u8>,
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
    #[account(
        mut,
        seeds = [b"config"],
        bump,
        has_one = merchant @ ClientProgramError::InvalidMerchant
    )]
    pub config: Account<'info, Config>,
    #[account(mut)]
    pub caller: Signer<'info>,
    #[account(mut)]
    pub merchant: SystemAccount<'info>,
    pub system_program: Program<'info, System>,
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
    pub merchant: Pubkey,
    pub request_counter: u64,
}

impl Config {
    pub const INIT_SPACE: usize = 32 + 32 + 32 + 8;
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

#[event]
pub struct PaymentCompleted {
    pub payer: Pubkey,
    pub merchant: Pubkey,
    pub amount_lamports: u64,
    pub payment_reference: String,
    pub weather_request_id: u64,
}

#[error_code]
pub enum ClientProgramError {
    #[msg("SDK primitive failed")]
    SdkPrimitiveFailed,
    #[msg("Invalid weather params")]
    InvalidActionParams,
    #[msg("payment_reference is required")]
    MissingPaymentReference,
    #[msg("payment_reference must be <= 64 chars")]
    PaymentReferenceTooLong,
    #[msg("amount_lamports must be > 0")]
    InvalidPaymentAmount,
    #[msg("merchant account does not match configured merchant")]
    InvalidMerchant,
    #[msg("Only configured oracle authority can submit callbacks")]
    UnauthorizedOracle,
    #[msg("Request counter overflowed")]
    CounterOverflow,
}
