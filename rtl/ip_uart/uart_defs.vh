// UART IP register offsets and ISR bit positions (03_chapters/ip_uart/design.md sec. 3)
`ifndef UART_DEFS_VH
`define UART_DEFS_VH

`define UART_OFS_TXDATA   12'h000
`define UART_OFS_RXDATA   12'h004
`define UART_OFS_STATUS   12'h008
`define UART_OFS_CTRL     12'h00C
`define UART_OFS_BAUD     12'h010
`define UART_OFS_FIFO_THR 12'h014
`define UART_OFS_IER      12'h018
`define UART_OFS_ISR      12'h01C

// ISR / IER bits
`define UART_ISR_RXTHR    0     // level: RX count >= RX threshold
`define UART_ISR_TXTHR    1     // level: TX count <= TX threshold
`define UART_ISR_TXDONE   2     // level: TX FIFO empty and shifter idle
`define UART_ISR_RXTO     3     // level: RX timeout (4 character times without a new start bit)
`define UART_ISR_RXOVR    4     // sticky, W1C: a byte was dropped because the RX FIFO was full
`define UART_ISR_PERR     5     // sticky, W1C: a received byte had a parity error
`define UART_ISR_FERR     6     // sticky, W1C: a received byte had a framing error (stop bit 0)
`define UART_ISR_TXOVR    7     // sticky, W1C: TXDATA written while the TX FIFO was full

`endif
