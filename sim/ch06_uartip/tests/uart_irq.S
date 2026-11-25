# ch6 UART IP chip test: the UART IP (APB slot 2) on the chip pins and its interrupt -> mip.MEIP
#  - The testbench connects UART_RX = UART_TX at the chip pins (through the IO pads)
#  1 polled: a byte written to TXDATA comes back through the pins and is read from RXDATA
#  2 interrupt: IER = RXTHR, RX threshold 1 -> the received byte raises irq -> one external interrupt
#    (mcause 0x8000000B); the handler checks ISR.RXTHR and reads RXDATA, which removes the request
#  3 the same with MIE = 0: pending in mip.MEIP but not taken, then taken when MIE is set again
#  BAUD = 0: 16 clocks per bit, one 8N1 frame = 160 clocks
# Built with the original riscv-tests environment for the MCU (env mcu_p)
#include "riscv_test.h"
#include "test_macros.h"
#include "memmap.h"

#define U_TXDATA   0x00
#define U_RXDATA   0x04
#define U_STATUS   0x08
#define U_CTRL     0x0C
#define U_BAUD     0x10
#define U_THR      0x14
#define U_IER      0x18
#define U_ISR      0x1C

RVTEST_RV32M
RVTEST_CODE_BEGIN

  li s3, UART_BASE
  li s9, 0                          # byte read by the handler
  li s10, 0                         # cause seen by the handler
  li s11, 0                         # interrupt count
  sw zero, U_BAUD(s3)               # 16 clocks per bit
  li t0, 0x0F
  sw t0, U_CTRL(s3)                 # TX, RX on, 8 data bits, no parity, 1 stop (8N1)
  li t0, 0x0001
  sw t0, U_THR(s3)                  # RX threshold 1, TX threshold 0

  # ---- 1: polled loopback through the pins ----
  li TESTNUM, 2
  li t0, 0xA5
  sw t0, U_TXDATA(s3)
  li t1, 2000
1:lw t2, U_RXDATA(s3)
  bgez t2, 2f                       # bit 31 = 0: a byte was read
  addi t1, t1, -1
  bnez t1, 1b
  j fail                            # timeout
2:andi t2, t2, 0x3FF                # data + PERR + FERR
  li t3, 0xA5
  bne t2, t3, fail

  # ---- 2: RX threshold interrupt ----
  li TESTNUM, 3
  li t0, 1
  sw t0, U_IER(s3)                  # IER = RXTHR
  li t0, MIP_MEIP
  csrw mie, t0
  csrsi mstatus, MSTATUS_MIE
  li t0, 0x5A
  sw t0, U_TXDATA(s3)
  li t1, 2000
1:bnez s11, 2f                      # wait for the interrupt
  addi t1, t1, -1
  bnez t1, 1b
  j fail
2:li t1, 400                        # stay a while: no second interrupt may come
3:addi t1, t1, -1
  bnez t1, 3b
  li t2, 1
  bne s11, t2, fail
  li t2, 0x8000000B
  bne s10, t2, fail
  li t2, 0x5A
  bne s9, t2, fail

  # ---- 3: MIE = 0 -> pending only, then taken ----
  li TESTNUM, 4
  csrci mstatus, MSTATUS_MIE
  li t0, 0x3C
  sw t0, U_TXDATA(s3)
  li t1, 2000
  li t3, MIP_MEIP
1:csrr t0, mip
  and t0, t0, t3
  bnez t0, 2f                       # request visible in mip.MEIP
  addi t1, t1, -1
  bnez t1, 1b
  j fail
2:li t2, 1
  bne s11, t2, fail                 # not taken yet
  csrsi mstatus, MSTATUS_MIE        # now it is taken
  li t1, 50
3:addi t1, t1, -1
  bnez t1, 3b
  li t2, 2
  bne s11, t2, fail
  li t2, 0x3C
  bne s9, t2, fail
  csrci mstatus, MSTATUS_MIE
  sw zero, U_IER(s3)

  TEST_PASSFAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  csrr s10, mcause
  li t4, 0x8000000B
  bne s10, t4, fail                 # must be the external interrupt
  lw t5, U_ISR(s3)
  andi t5, t5, 1
  beqz t5, fail                     # cause: UART RXTHR
  lw t5, U_RXDATA(s3)               # take the byte -> RX count 0 -> irq goes low
  andi s9, t5, 0xFF
  addi s11, s11, 1
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN
  TEST_DATA
RVTEST_DATA_END
