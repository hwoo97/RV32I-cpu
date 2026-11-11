/* Peripheral registers of the stage 4 MCU (03_chapters/ch14a_mcu/design.md sec. 5)
   Base addresses come from memmap.h (generated from memmap.txt).
   All peripheral registers are 32-bit and must be accessed as words (lw/sw):
   a byte or halfword store to the APB window is an error (bus_err) and does nothing. */
#ifndef MCU_H
#define MCU_H

#include <stdint.h>
#include "memmap.h"

#define REG32(addr)        (*(volatile uint32_t *)(addr))

/* GPIO (0x4000_0000) */
#define GPIO_DATA_OUT      REG32(GPIO_BASE + 0x00)   /* R/W output value */
#define GPIO_DATA_IN       REG32(GPIO_BASE + 0x04)   /* R   input pins (synchronized) */
#define GPIO_DIR           REG32(GPIO_BASE + 0x08)   /* R/W 1 = output */

/* TIMER (0x4000_1000) */
#define TIMER_CTRL         REG32(TIMER_BASE + 0x00)
#define TIMER_COUNT        REG32(TIMER_BASE + 0x04)
#define TIMER_CMP          REG32(TIMER_BASE + 0x08)
#define TIMER_STATUS       REG32(TIMER_BASE + 0x0C)  /* W1C */
#define TIMER_CTRL_EN      (1u << 0)
#define TIMER_CTRL_AUTO    (1u << 1)
#define TIMER_CTRL_IE      (1u << 2)
#define TIMER_STATUS_MATCH (1u << 0)

/* UART (0x4000_2000), 8N1 */
#define UART_TXDATA        REG32(UART_BASE + 0x00)   /* W */
#define UART_RXDATA        REG32(UART_BASE + 0x04)   /* R, clears RX_VALID */
#define UART_STATUS        REG32(UART_BASE + 0x08)   /* R, clears RX_OVERRUN and RX_FRAME */
#define UART_BAUDDIV       REG32(UART_BASE + 0x0C)   /* R/W clocks per bit - 1 */
#define UART_TX_FULL       (1u << 0)
#define UART_RX_VALID      (1u << 1)
#define UART_RX_OVERRUN    (1u << 2)
#define UART_TX_IDLE       (1u << 3)
#define UART_RX_FRAME      (1u << 4)

/* SIMCTL (0x4000_F000) - exists only in the simulation testbench */
#define SIMCTL_FINISH      REG32(SIMCTL_BASE + 0x00) /* 1 = PASS, (n << 1) | 1 = FAIL n */
#define SIMCTL_PUTC        REG32(SIMCTL_BASE + 0x04)

/* Clock and baud rate. The board clock is 50 MHz (to be confirmed with the board data).
   Simulation builds (-DSIM) use a short bit time so that printf output is fast to simulate. */
#ifndef CPU_HZ
#define CPU_HZ             50000000u
#endif
#ifndef UART_BAUDDIV_INIT
#define UART_BAUDDIV_INIT  433u                      /* 50 MHz / 115200 - 1 */
#endif

#endif
