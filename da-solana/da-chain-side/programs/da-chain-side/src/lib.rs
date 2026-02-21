use anchor_lang::prelude::*;

declare_id!("91XcSJyrQZpmJifL9TggBXHrXELtNrP3xSZ217DVGjWs");

#[program]
pub mod da_chain_side {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let config = &mut ctx.accounts.config;
        config.authority = ctx.accounts.authority.key();
        config.task_counter = 0;
        Ok(())
    }

    pub fn emit_task(ctx: Context<EmitTask>, data: Vec<u8>) -> Result<()> {
        let config = &mut ctx.accounts.config;
        let task_id = config.task_counter;
        config.task_counter = task_id + 1;

        emit!(TaskEmitted {
            task_id,
            data,
        });

        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + 32 + 8,
        seeds = [b"config"],
        bump,
    )]
    pub config: Account<'info, Config>,
    #[account(mut)]
    pub authority: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct EmitTask<'info> {
    #[account(
        mut,
        seeds = [b"config"],
        bump,
        has_one = authority,
    )]
    pub config: Account<'info, Config>,
    pub authority: Signer<'info>,
}

#[account]
pub struct Config {
    pub authority: Pubkey,
    pub task_counter: u64,
}

#[event]
pub struct TaskEmitted {
    pub task_id: u64,
    pub data: Vec<u8>,
}
