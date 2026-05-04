.globl check_reentrancy
.globl trigger_reinvoking_rpc
.globl rustc_cant_guess_this
rustc_cant_guess_this:
    mov64 r0, 1
    exit

trigger_reinvoking_rpc:
    lddw r1, aend
    lddw r2, 4
    lddw r3, 0
    lddw r4, 0
    call sol_panic_

check_reentrancy:
    lddw r1, 0x400000000
    ldxb r0, [r1 + 0x10] // Reentrancy byte
    jeq r0, 0x1, reinvoking_rpc_callback
    exit

reinvoking_rpc_callback:
    lddw r1, 0x400000000
    ldxb r0, [r1 + 0x18] // load the return value from the RPC call on the first loop

inner_loop:
    lddw r1, 0x400000000

    ldxb r2, [r1 + 0x11] // how many call stacks do we have left?
    sub64 r2, 1
    jeq r2, 0, exity

    stxb [r1 + 0x11], r2

    // what address should we go to next?
    mul64 r2, 0x8
    add64 r2, 0x68
    add64 r2, r1

    ldxdw r1, [r2 + 0]

    lddw r9, 0x400000000
    ldxdw r2, [r9 + 0x28]
    ldxdw r3, [r9 + 0x30]
    ldxdw r4, [r9 + 0x38]
    ldxdw r5, [r9 + 0x40]
    ldxdw r6, [r9 + 0x48]
    ldxdw r7, [r9 + 0x50]
    ldxdw r8, [r9 + 0x58]
    ldxdw r9, [r9 + 0x60]

    // For whatever reason: callx requires its address
    // to include the elf text section offset??
    // (also: this points at the instruction *before*)
    // the one that will get executed.
    callx r1

    ja inner_loop

exity:
    lddw r0, 0
    ldxdw r0, [r0 + 0]
    exit

.rodata
    aend: .ascii "aend"
