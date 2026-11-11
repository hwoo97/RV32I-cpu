// Minimal riscv-tests environment for the stage 4 MCU (rv32i_mcu, memory map in fw/common/memmap.txt)
// Same idea as ../riscv_test.h (stage 3), with the MCU memory map:
//  - Code, constants and the initial values of .data are in IMEM; .data runs in DMEM.
//    Start: copy .data from IMEM to DMEM (this uses the data-side IMEM read port), clear x1..x31.
//  - Result: write to the SIMCTL FINISH register (APB slot 15, testbench only) and loop in place
//    (1 = PASS, (failed test number << 1) | 1 = FAIL). This also exercises the APB path and core stall.
#ifndef _ENV_RV32I_MCU_H
#define _ENV_RV32I_MCU_H

#include "memmap.h"

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

/* copy .data (load address in IMEM) to its run address in DMEM, word by word */
#define COPY_DATA                                               \
        la t0, _data_lma;                                       \
        la t1, _data_start;                                     \
        la t2, _data_end;                                       \
1:      bgeu t1, t2, 2f;                                        \
        lw t3, 0(t0);                                           \
        sw t3, 0(t1);                                           \
        addi t0, t0, 4;                                         \
        addi t1, t1, 4;                                         \
        j 1b;                                                   \
2:

#define RVTEST_CODE_BEGIN                                       \
        .section .text.init;                                    \
        .align  6;                                              \
        .globl _start;                                          \
_start:                                                         \
        COPY_DATA;                                              \
        INIT_XREG;                                              \
        init;

#define RVTEST_CODE_END                                         \
1:      j 1b;

#define RVTEST_PASS                                             \
        fence;                                                  \
        li TESTNUM, 1;                                          \
        li t5, SIMCTL_BASE;                                     \
        sw TESTNUM, 0(t5);                                      \
1:      j 1b;

#define RVTEST_FAIL                                             \
        fence;                                                  \
1:      beqz TESTNUM, 1b;                                       \
        sll TESTNUM, TESTNUM, 1;                                \
        or TESTNUM, TESTNUM, 1;                                 \
        li t5, SIMCTL_BASE;                                     \
        sw TESTNUM, 0(t5);                                      \
1:      j 1b;

#define EXTRA_DATA

#define RVTEST_DATA_BEGIN                                       \
        EXTRA_DATA                                              \
        .align 4; .global begin_signature; begin_signature:

#define RVTEST_DATA_END .align 4; .global end_signature; end_signature:

#endif
