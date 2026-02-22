use anchor_lang::prelude::*;
use anchor_lang::system_program;
use damhchuire_sdk::{
    call_ai_chat_action_from, AiChatParams, AnchorEmitError, HasRequestCounter,
};

declare_id!("9JsLkqyRpEJxBXoGGtaRobMUyGvtxijVet7YGXCCsDD5");

const MODEL: &str = "openai/gpt-4o-mini";

const SYSTEM_PROMPT: &str = "You are an invoice parser. Given an invoice text, extract the total \
amount payable in SOL. Return ONLY a JSON object: {\"amount_sol\": <number>}. \
The number must be a positive decimal. If you cannot determine the amount, \
return {\"amount_sol\": 0}. Do not include any other text.";

const MAX_ALLOWLIST: usize = 10;

#[program]
pub mod invoice_processor {
    use super::*;

    pub fn initialize(
        ctx: Context<Initialize>,
        oracle_authority: Pubkey,
        max_payout_lamports: u64,
    ) -> Result<()> {
        let config = &mut ctx.accounts.config;
        config.authority = ctx.accounts.authority.key();
        config.oracle_authority = oracle_authority;
        config.request_counter = 0;
        config.max_payout_lamports = max_payout_lamports;
        config.vault_bump = ctx.bumps.vault;
        config.allowlist_len = 0;
        config.allowlist = [Pubkey::default(); MAX_ALLOWLIST];
        Ok(())
    }

    pub fn add_to_allowlist(ctx: Context<AddToAllowlist>, wallet: Pubkey) -> Result<()> {
        let config = &mut ctx.accounts.config;
        let len = config.allowlist_len as usize;
        require!(len < MAX_ALLOWLIST, InvoiceError::AllowlistFull);

        // Check for duplicates
        for i in 0..len {
            require!(config.allowlist[i] != wallet, InvoiceError::AlreadyAllowlisted);
        }

        config.allowlist[len] = wallet;
        config.allowlist_len += 1;
        Ok(())
    }

    pub fn fund(ctx: Context<Fund>, amount_lamports: u64) -> Result<()> {
        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: ctx.accounts.depositor.to_account_info(),
                    to: ctx.accounts.vault.to_account_info(),
                },
            ),
            amount_lamports,
        )?;
        Ok(())
    }

    pub fn submit_invoice(ctx: Context<SubmitInvoice>, invoice_text: String) -> Result<()> {
        let config = &mut ctx.accounts.config;
        let submitter_key = ctx.accounts.submitter.key();

        // Check allowlist
        let len = config.allowlist_len as usize;
        let mut found = false;
        for i in 0..len {
            if config.allowlist[i] == submitter_key {
                found = true;
                break;
            }
        }
        require!(found, InvoiceError::NotAllowlisted);

        // Build LLM prompt
        let params = AiChatParams {
            model: MODEL.to_string(),
            messages: vec![
                serde_json::json!({
                    "role": "system",
                    "content": SYSTEM_PROMPT
                }),
                serde_json::json!({
                    "role": "user",
                    "content": invoice_text
                }),
            ],
        };

        // Capture request_id before SDK increments counter
        let request_id = config.request_counter;

        // Emit ActionRequested via SDK
        call_ai_chat_action_from(&mut **config, params)
            .map_err(map_sdk_emit_error)?;

        // Initialize Invoice PDA
        let invoice = &mut ctx.accounts.invoice;
        invoice.request_id = request_id;
        invoice.submitter = submitter_key;
        invoice.status = InvoiceStatus::Pending as u8;
        invoice.amount_lamports = 0;
        invoice.bump = ctx.bumps.invoice;

        Ok(())
    }

    pub fn callback(
        ctx: Context<CallbackCtx>,
        request_id: u64,
        ok: bool,
        result_json: Vec<u8>,
    ) -> Result<()> {
        let invoice = &mut ctx.accounts.invoice;

        require!(
            invoice.status == InvoiceStatus::Pending as u8,
            InvoiceError::InvoiceNotPending
        );

        if !ok {
            invoice.status = InvoiceStatus::Rejected as u8;
            return Ok(());
        }

        let amount = parse_amount_from_response(&result_json)
            .map_err(|_| error!(InvoiceError::ParseFailed))?;

        if amount == 0 {
            invoice.status = InvoiceStatus::Rejected as u8;
            return Ok(());
        }

        require!(
            amount <= ctx.accounts.config.max_payout_lamports,
            InvoiceError::ExceedsMaxPayout
        );

        invoice.amount_lamports = amount;
        invoice.status = InvoiceStatus::Approved as u8;

        emit!(InvoiceApproved {
            request_id,
            amount_lamports: amount,
            submitter: invoice.submitter,
        });

        Ok(())
    }

    pub fn settle(ctx: Context<Settle>) -> Result<()> {
        let invoice = &mut ctx.accounts.invoice;

        require!(
            invoice.status == InvoiceStatus::Approved as u8,
            InvoiceError::InvoiceNotApproved
        );

        let amount = invoice.amount_lamports;
        let vault_balance = ctx.accounts.vault.lamports();

        require!(
            vault_balance >= amount,
            InvoiceError::InsufficientVaultBalance
        );

        // Transfer from vault PDA to submitter
        let vault_bump = ctx.accounts.config.vault_bump;
        let signer_seeds: &[&[u8]] = &[b"vault", &[vault_bump]];

        system_program::transfer(
            CpiContext::new_with_signer(
                ctx.accounts.system_program.to_account_info(),
                system_program::Transfer {
                    from: ctx.accounts.vault.to_account_info(),
                    to: ctx.accounts.submitter.to_account_info(),
                },
                &[signer_seeds],
            ),
            amount,
        )?;

        invoice.status = InvoiceStatus::Settled as u8;

        emit!(InvoiceSettled {
            request_id: invoice.request_id,
            amount_lamports: amount,
            submitter: invoice.submitter,
        });

        Ok(())
    }
}

fn map_sdk_emit_error(error: AnchorEmitError) -> Error {
    match error {
        AnchorEmitError::CounterOverflow => error!(InvoiceError::CounterOverflow),
        AnchorEmitError::Client(_) => error!(InvoiceError::SdkPrimitiveFailed),
    }
}

fn parse_amount_from_response(result_json: &[u8]) -> std::result::Result<u64, ()> {
    let outer: serde_json::Value = serde_json::from_slice(result_json).map_err(|_| ())?;
    let content = outer["choices"][0]["message"]["content"]
        .as_str()
        .ok_or(())?;

    // Strip markdown fences if LLM wraps in ```json ... ```
    let clean = content
        .trim()
        .trim_start_matches("```json")
        .trim_start_matches("```")
        .trim_end_matches("```")
        .trim();

    let inner: serde_json::Value = serde_json::from_str(clean).map_err(|_| ())?;
    let sol = inner["amount_sol"].as_f64().ok_or(())?;

    if sol < 0.0 {
        return Err(());
    }

    Ok((sol * 1_000_000_000.0) as u64)
}

// ── Account Structs ──────────────────────────────────────────────────

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

    /// CHECK: Vault is a PDA that just holds SOL, no data needed.
    #[account(
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,

    #[account(mut)]
    pub authority: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct AddToAllowlist<'info> {
    #[account(
        mut,
        seeds = [b"config"],
        bump,
        has_one = authority @ InvoiceError::Unauthorized
    )]
    pub config: Account<'info, Config>,
    pub authority: Signer<'info>,
}

#[derive(Accounts)]
pub struct Fund<'info> {
    /// CHECK: Vault PDA that holds SOL.
    #[account(
        mut,
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,

    #[account(mut)]
    pub depositor: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct SubmitInvoice<'info> {
    #[account(
        mut,
        seeds = [b"config"],
        bump
    )]
    pub config: Account<'info, Config>,

    #[account(
        init,
        payer = submitter,
        space = 8 + Invoice::INIT_SPACE,
        seeds = [b"invoice", config.request_counter.to_le_bytes().as_ref()],
        bump
    )]
    pub invoice: Account<'info, Invoice>,

    #[account(mut)]
    pub submitter: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
#[instruction(request_id: u64)]
pub struct CallbackCtx<'info> {
    #[account(
        seeds = [b"config"],
        bump,
        has_one = oracle_authority @ InvoiceError::UnauthorizedOracle
    )]
    pub config: Account<'info, Config>,

    pub oracle_authority: Signer<'info>,

    #[account(
        mut,
        seeds = [b"invoice", &request_id.to_le_bytes()],
        bump = invoice.bump
    )]
    pub invoice: Account<'info, Invoice>,
}

#[derive(Accounts)]
pub struct Settle<'info> {
    #[account(
        seeds = [b"config"],
        bump
    )]
    pub config: Account<'info, Config>,

    #[account(
        mut,
        constraint = invoice.submitter == submitter.key() @ InvoiceError::SubmitterMismatch
    )]
    pub invoice: Account<'info, Invoice>,

    /// CHECK: Vault PDA that holds SOL.
    #[account(
        mut,
        seeds = [b"vault"],
        bump
    )]
    pub vault: SystemAccount<'info>,

    /// CHECK: Must match invoice.submitter, receives SOL payout.
    #[account(mut)]
    pub submitter: SystemAccount<'info>,

    pub system_program: Program<'info, System>,
}

// ── Data Accounts ────────────────────────────────────────────────────

#[account]
pub struct Config {
    pub authority: Pubkey,          // 32
    pub oracle_authority: Pubkey,   // 32
    pub request_counter: u64,       // 8
    pub max_payout_lamports: u64,   // 8
    pub vault_bump: u8,             // 1
    pub allowlist_len: u8,          // 1
    pub allowlist: [Pubkey; 10],    // 320
}

impl Config {
    pub const INIT_SPACE: usize = 32 + 32 + 8 + 8 + 1 + 1 + (32 * 10); // 402
}

impl HasRequestCounter for Config {
    fn request_counter_mut(&mut self) -> &mut u64 {
        &mut self.request_counter
    }
}

#[account]
pub struct Invoice {
    pub request_id: u64,        // 8
    pub submitter: Pubkey,      // 32
    pub status: u8,             // 1
    pub amount_lamports: u64,   // 8
    pub bump: u8,               // 1
}

impl Invoice {
    pub const INIT_SPACE: usize = 8 + 32 + 1 + 8 + 1; // 50
}

#[repr(u8)]
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum InvoiceStatus {
    Pending = 0,
    Approved = 1,
    Settled = 2,
    Rejected = 3,
}

// ── Events ───────────────────────────────────────────────────────────

#[event]
pub struct InvoiceApproved {
    pub request_id: u64,
    pub amount_lamports: u64,
    pub submitter: Pubkey,
}

#[event]
pub struct InvoiceSettled {
    pub request_id: u64,
    pub amount_lamports: u64,
    pub submitter: Pubkey,
}

// ── Errors ───────────────────────────────────────────────────────────

#[error_code]
pub enum InvoiceError {
    #[msg("SDK primitive failed")]
    SdkPrimitiveFailed,
    #[msg("Only configured oracle authority can submit callbacks")]
    UnauthorizedOracle,
    #[msg("Request counter overflowed")]
    CounterOverflow,
    #[msg("Submitter is not on the allowlist")]
    NotAllowlisted,
    #[msg("Allowlist is full (max 10)")]
    AllowlistFull,
    #[msg("Wallet is already on the allowlist")]
    AlreadyAllowlisted,
    #[msg("Only the authority can perform this action")]
    Unauthorized,
    #[msg("Invoice is not in Pending status")]
    InvoiceNotPending,
    #[msg("Invoice is not in Approved status")]
    InvoiceNotApproved,
    #[msg("Failed to parse amount from LLM response")]
    ParseFailed,
    #[msg("Amount exceeds maximum payout cap")]
    ExceedsMaxPayout,
    #[msg("Vault has insufficient SOL balance")]
    InsufficientVaultBalance,
    #[msg("Submitter does not match invoice record")]
    SubmitterMismatch,
}
