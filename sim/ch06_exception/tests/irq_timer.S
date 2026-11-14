# ch6 trap test: timer interrupt (TIMER irq -> mip.MTIP) on the ch6 MCU
#  - TIMER: CMP = 40, AUTO + EN + IE -> an interrupt request every 41 clocks
#  - The main loop runs DMEM stores/loads and APB reads while interrupts arrive. Two counters
#    (a1 += 1, a5 += 2) must stay a5 = 2 * a1: an interrupt that skipped or repeated an
#    instruction would break this. Interrupts must not abort an APB read (checked by the value read).
#  - Handler: mcause must be 0x80000007, mepc inside IMEM; clears TIMER STATUS.MATCH (W1C), counts in s11
#  - PASS after 8 interrupts
# Built with the original riscv-tests environment for the MCU (env mcu_p)
#include "riscv_test.h"
#include "test_macros.h"
#include "memmap.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  li TESTNUM, 2
  li s11, 0                         # interrupt count (handler)
  li s1, GPIO_BASE
  li t0, 0x5A5A
  sw t0, 0(s1)                      # GPIO DATA_OUT = 0x5A5A (read back in the loop through APB)
  li s2, TIMER_BASE
  sw zero, 0(s2)                    # CTRL = 0
  sw zero, 4(s2)                    # COUNT = 0
  li t0, 40
  sw t0, 8(s2)                      # CMP = 40
  li t0, 1
  sw t0, 12(s2)                     # clear MATCH
  li t0, MIP_MTIP
  csrw mie, t0                      # MTIE
  csrsi mstatus, MSTATUS_MIE
  li t0, 7
  sw t0, 0(s2)                      # CTRL = IE | AUTO | EN

  li TESTNUM, 3
  li a1, 0
  li a5, 0
  la a2, buf
loop:
  addi a1, a1, 1
  sw a1, 0(a2)
  lw a3, 0(a2)
  bne a1, a3, fail                  # DMEM store/load
  lw a4, 0(s1)
  li t1, 0x5A5A
  bne a4, t1, fail                  # APB read value
  addi a5, a5, 2
  li t2, 8
  blt s11, t2, loop

  li TESTNUM, 4
  slli t3, a1, 1
  bne a5, t3, fail                  # no skipped or repeated instruction
  sw zero, 0(s2)                    # stop the timer
  csrci mstatus, MSTATUS_MIE

  TEST_PASSFAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  csrr t5, mcause
  li t6, 0x80000007
  bne t5, t6, fail                  # only the timer interrupt is expected
  csrr t5, mepc
  li t6, IMEM_SIZE
  bgeu t5, t6, fail                 # mepc must point into IMEM
  li t6, 1
  sw t6, 12(s2)                     # TIMER STATUS: clear MATCH (removes the request)
  addi s11, s11, 1
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
buf: .word 0
RVTEST_DATA_END
