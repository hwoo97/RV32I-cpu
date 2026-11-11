// Minimal test environment for riscv-tests - for the stage 3 RV32I single-cycle CPU without CSRs/traps
// The default riscv-tests environment (env/p/riscv_test.h) uses CSRs (mtvec, mstatus ...) and mret at startup
// and ecall on PASS. This CPU has none of these yet, so the same macro names are defined with simple behavior.
//  - Start: clear x1..x31 and jump straight into the test
//  - Result: write to the tohost address and loop in place (1 = PASS, (failed test number << 1) | 1 = FAIL)
//  - The testbench watches writes to tohost to decide pass/fail
// After ch6 (CSRs, traps), re-check with the default riscv-tests environment (env/p).
#ifndef _ENV_RV32I_MINIMAL_H
#define _ENV_RV32I_MINIMAL_H

#define TESTNUM gp

#define RVTEST_RV32U  .macro init; .endm
#define RVTEST_RV64U  RVTEST_RV32U

#define INIT_XREG                                               \
  li x1, 0;  li x2, 0;  li x3, 0;  li x4, 0;  li x5, 0;         \
  li x6, 0;  li x7, 0;  li x8, 0;  li x9, 0;  li x10, 0;        \
  li x11, 0; li x12, 0; li x13, 0; li x14, 0; li x15, 0;        \
  li x16, 0; li x17, 0; li x18, 0; li x19, 0; li x20, 0;        \
  li x21, 0; li x22, 0; li x23, 0; li x24, 0; li x25, 0;        \
  li x26, 0; li x27, 0; li x28, 0; li x29, 0; li x30, 0;        \
  li x31, 0;

#define RVTEST_CODE_BEGIN                                       \
        .section .text.init;                                    \
        .align  6;                                              \
        .globl _start;                                          \
_start:                                                         \
        INIT_XREG;                                              \
        init;

#define RVTEST_CODE_END                                         \
1:      j 1b;

#define RVTEST_PASS                                             \
        fence;                                                  \
        li TESTNUM, 1;                                          \
        la t5, tohost;                                          \
        sw TESTNUM, 0(t5);                                      \
1:      j 1b;

#define RVTEST_FAIL                                             \
        fence;                                                  \
1:      beqz TESTNUM, 1b;                                       \
        sll TESTNUM, TESTNUM, 1;                                \
        or TESTNUM, TESTNUM, 1;                                 \
        la t5, tohost;                                          \
        sw TESTNUM, 0(t5);                                      \
1:      j 1b;

#define EXTRA_DATA

#define RVTEST_DATA_BEGIN                                       \
        EXTRA_DATA                                              \
        .pushsection .tohost,"aw",@progbits;                    \
        .align 6; .global tohost; tohost: .word 0; .word 0;     \
        .align 6; .global fromhost; fromhost: .word 0; .word 0; \
        .popsection;                                            \
        .align 4; .global begin_signature; begin_signature:

#define RVTEST_DATA_END .align 4; .global end_signature; end_signature:

#endif
