use solana_program::log::sol_log;

pub fn hex_nibble(v: u8) -> u8 {
    if v < 10 { v + 0x30 } else { (v - 10) + 0x41 }
}

#[inline(never)]
pub fn log_u64(v: u64) {
    let bytes = u64::to_le_bytes(v);

    let msg = &[
        0x30,
        0x78,
        hex_nibble((bytes[3] >> 4) & 0xf),
        hex_nibble(bytes[3] & 0x0f),
        hex_nibble((bytes[2] >> 4) & 0xf),
        hex_nibble(bytes[2] & 0x0f),
        hex_nibble((bytes[1] >> 4) & 0xf),
        hex_nibble(bytes[1] & 0x0f),
        hex_nibble((bytes[0] >> 4) & 0xf),
        hex_nibble(bytes[0] & 0x0f),
    ];

    unsafe {
        sol_log(str::from_utf8_unchecked(msg));
    }
}
