# ch6 trap test: external interrupt (ext_irq -> mip.MEIP) and interrupt enables / priority
#  - The testbench connects ext_irq = gpio_out[15]: the program raises its own external interrupt
#  1 MEIE + MIE: setting GPIO bit 15 gives one interrupt with mcause 0x8000000B; the handler lowers the pin
#  2 MIE = 0: the request is seen in mip.MEIP but not taken
#  3 external and timer pending together, then MIE = 1: external first, then timer
# Built with the original riscv-tests environment for the MCU (env mcu_p)
#include "riscv_test.h"
#include "test_macros.h"
#include "memmap.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  li s1, GPIO_BASE
  li s2, TIMER_BASE
  li s10, 0                         # order of causes seen by the handler (shifted in, 4 bits each)
  li s11, 0                         # interrupt count
  li t0, 0x8000
  sw t0, 8(s1)                      # GPIO DIR: bit 15 output

  # ---- 1: one external interrupt ----
  li TESTNUM, 2
  li t0, MIP_MEIP
  csrw mie, t0
  csrsi mstatus, MSTATUS_MIE
  li t0, 0x8000
  sw t0, 0(s1)                      # raise ext_irq
  li t1, 50
1:addi t1, t1, -1                   # wait (2-flop synchronizer + APB)
  bnez t1, 1b
  li t2, 1
  bne s11, t2, fail
  li t2, 0xB
  bne s10, t2, fail

  # ---- 2: MIE = 0 -> pending but not taken ----
  li TESTNUM, 3
  csrci mstatus, MSTATUS_MIE
  li t0, 0x8000
  sw t0, 0(s1)                      # raise again
  li t1, 50
1:addi t1, t1, -1
  bnez t1, 1b
  li t2, 1
  bne s11, t2, fail                 # still one
  csrr t0, mip
  li t2, MIP_MEIP
  and t0, t0, t2
  beqz t0, fail                     # but visible in mip

  # ---- 3: external + timer pending together -> external first ----
  li TESTNUM, 4
  sw zero, 4(s2)                    # COUNT = 0
  li t0, 5
  sw t0, 8(s2)                      # CMP = 5
  li t0, 5
  sw t0, 0(s2)                      # CTRL = IE | EN (no AUTO)
  li t1, 30
1:addi t1, t1, -1                   # let the timer match
  bnez t1, 1b
  li s10, 0
  li t0, MIP_MEIP | MIP_MTIP
  csrw mie, t0
  csrsi mstatus, MSTATUS_MIE        # both pending -> two interrupts
  li t1, 50
1:addi t1, t1, -1
  bnez t1, 1b
  li t2, 3
  bne s11, t2, fail
  li t2, 0xB7                       # first 0xB (external), then 0x7 (timer)
  bne s10, t2, fail
  csrci mstatus, MSTATUS_MIE

  TEST_PASSFAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  csrr t5, mcause
  bgez t5, fail                     # must be an interrupt
  andi t6, t5, 0x1F
  slli s10, s10, 4
  or s10, s10, t6                   # record the cause
  li t4, 0xB
  bne t6, t4, 2f
  sw zero, 0(s1)                    # external: lower the pin (the request goes away 2 clocks later)
  j 3f
2:li t4, 1
  sw t4, 12(s2)                     # timer: clear MATCH
  sw zero, 0(s2)                    #        and stop
3:addi s11, s11, 1
  # wait until the external request has really gone (synchronizer delay) before returning
  li t4, 4
4:addi t4, t4, -1
  bnez t4, 4b
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
