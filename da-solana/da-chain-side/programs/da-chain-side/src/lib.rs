use anchor_lang::prelude::*;

declare_id!("91XcSJyrQZpmJifL9TggBXHrXELtNrP3xSZ217DVGjWs");

#[program]
pub mod da_chain_side {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>, oracle_authority: Pubkey) -> Result<()> {
        let config = &mut ctx.accounts.config;
        config.authority = ctx.accounts.authority.key();
        config.oracle_authority = oracle_authority;
        config.request_counter = 0;
        Ok(())
    }

    pub fn on_call(ctx: Context<OnCall>, action_slug: String, params_json: Vec<u8>) -> Result<()> {
        let config = &mut ctx.accounts.config;
        let request_id = config.request_counter;
        config.request_counter = config
            .request_counter
            .checked_add(1)
            .ok_or(ErrorCode::CounterOverflow)?;

        emit!(ActionRequested {
            request_id,
            action_slug,
            params_json,
        });

        Ok(())
    }

    pub fn callback(
        ctx: Context<Callback>,
        request_id: u64,
        ok: bool,
        result_json: Vec<u8>,
    ) -> Result<()> {
        require_keys_eq!(
            ctx.accounts.oracle_authority.key(),
            ctx.accounts.config.oracle_authority,
            ErrorCode::UnauthorizedOracle
        );

        emit!(ActionCompleted {
            request_id,
            ok,
            result_json,
        });

        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + 32 + 32 + 8,
        seeds = [b"config"],
        bump,
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
    )]
    pub config: Account<'info, Config>,
    pub caller: Signer<'info>,
}

#[derive(Accounts)]
pub struct Callback<'info> {
    #[account(
        seeds = [b"config"],
        bump,
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

#[event]
pub struct ActionRequested {
    pub request_id: u64,
    pub action_slug: String,
    pub params_json: Vec<u8>,
}

#[event]
pub struct ActionCompleted {
    pub request_id: u64,
    pub ok: bool,
    pub result_json: Vec<u8>,
}

#[error_code]
pub enum ErrorCode {
    #[msg("Only configured oracle authority can submit callbacks")]
    UnauthorizedOracle,
    #[msg("Request counter overflowed")]
    CounterOverflow,
}
