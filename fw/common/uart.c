/* UART driver (polling). Works the same with the 1-byte buffer and a later FIFO:
   TX_FULL means "cannot take a new byte" in both cases (design.md sec. 5.3). */
#include "fwlib.h"

void uart_init(uint32_t bauddiv)
{
    uart_flush();
    UART_BAUDDIV = bauddiv;
    (void)UART_STATUS;                    /* clear old RX_OVERRUN / RX_FRAME */
}

void uart_putc(char c)
{
    while (UART_STATUS & UART_TX_FULL)
        ;
    UART_TXDATA = (uint8_t)c;
}

void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

int uart_getc(void)
{
    if (!(UART_STATUS & UART_RX_VALID))
        return -1;
    return (int)(UART_RXDATA & 0xFF);
}

void uart_flush(void)
{
    while (!(UART_STATUS & UART_TX_IDLE))
        ;
}
