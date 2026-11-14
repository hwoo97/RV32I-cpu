# ch6 trap test: access faults from the MCU address decoder (bus_err -> exceptions)
#  For each case the handler records mcause, mtval and mepc and returns to s5 (set before the case):
#   2 load from an unmapped address           -> 5 load access fault,  mtval = address, rd unchanged
#   3 store to IMEM (read only)               -> 7 store access fault, IMEM unchanged
#   4 sb to a peripheral (APB is word only)   -> 7, GPIO DATA_OUT unchanged
#   5 load from an empty APB slot (PSLVERR)   -> 5, after the APB wait
#   6 jump outside IMEM                       -> 1 instruction access fault, mepc = mtval = target
#   7 jalr to a 2-byte aligned target          -> 0 instruction address misaligned, mepc = the jalr
# Built with the original riscv-tests environment for the MCU (env mcu_p)
#include "riscv_test.h"
#include "test_macros.h"
#include "memmap.h"

#define EXPECT(cause, tval, epc) \
  li t2, cause; bne s2, t2, fail; \
  li t2, tval;  bne s3, t2, fail; \
  la t2, epc;   bne s4, t2, fail;

RVTEST_RV32M
RVTEST_CODE_BEGIN

  li s1, GPIO_BASE
  li t0, 0x1234
  sw t0, 0(s1)                      # GPIO DATA_OUT = 0x1234

  li TESTNUM, 2
  la s5, 1f
  li a0, 0x55
  li t0, 0x20000000
c2: lw a0, 0(t0)                    # unmapped
1:EXPECT(5, 0x20000000, c2)
  li t2, 0x55
  bne a0, t2, fail                  # rd not written

  li TESTNUM, 3
  la s5, 1f
  la t0, c3
  lw a1, 0(t0)                      # the instruction word before
c3: sw zero, 0(t0)                  # store to IMEM
1:la t0, c3
  lw a2, 0(t0)
  bne a1, a2, fail                  # IMEM unchanged
  la t3, c3
  li t2, 7
  bne s2, t2, fail
  bne s3, t3, fail

  li TESTNUM, 4
  la s5, 1f
c4: sb zero, 0(s1)                  # byte store to GPIO
1:EXPECT(7, GPIO_BASE, c4)
  lw t0, 0(s1)
  li t2, 0x1234
  bne t0, t2, fail                  # not written

  li TESTNUM, 5
  la s5, 1f
  li t0, APB_BASE + 0x5000
c5: lw a0, 0(t0)                    # empty slot 5
1:EXPECT(5, APB_BASE + 0x5000, c5)

  li TESTNUM, 6
  la s5, 1f
  li t0, 0x20000000
  jalr x0, 0(t0)                    # fetch outside IMEM
1:li t2, 1
  bne s2, t2, fail
  li t2, 0x20000000
  bne s3, t2, fail
  bne s4, t2, fail                  # mepc = the address that could not be fetched

  li TESTNUM, 7
  la s5, 1f
  la t0, 1f
  addi t0, t0, 2
c7: jalr x0, 0(t0)                  # target not 4-byte aligned
1:li t2, 0
  bne s2, t2, fail
  la t3, 1b
  addi t3, t3, 2
  bne s3, t3, fail                  # mtval = target
  la t2, c7
  bne s4, t2, fail                  # mepc = the jump itself

  TEST_PASSFAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  csrr s2, mcause
  csrr s3, mtval
  csrr s4, mepc
  csrw mepc, s5
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
