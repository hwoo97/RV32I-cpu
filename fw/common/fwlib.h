/* Small firmware library for the stage 4 MCU (no C standard library, -nostdlib)
     uart.c     : uart_init, uart_putc, uart_puts, uart_getc, uart_flush
     printf.c   : printf (%d %i %u %x %X %c %s %p %%, flags '0' '-', width, 'l' accepted)
     timer.c    : timer_init, timer_now, delay_cycles
     sys.c      : fw_exit (called by crt0 after main)
     libc_min.c : memset, memcpy, memmove, memcmp, strlen (gcc may emit calls to these) */
#ifndef FWLIB_H
#define FWLIB_H

#include <stdint.h>
#include <stddef.h>
#include "mcu.h"

void     uart_init(uint32_t bauddiv);
void     uart_putc(char c);
void     uart_puts(const char *s);
int      uart_getc(void);                 /* -1 if nothing received */
void     uart_flush(void);                /* wait until the last byte has left the TX pin */

int      printf(const char *fmt, ...) __attribute__((format(printf, 1, 2)));

void     timer_init(void);                /* free-running COUNT */
uint32_t timer_now(void);
void     delay_cycles(uint32_t n);

void     fw_exit(int code) __attribute__((noreturn));

void    *memset(void *d, int c, size_t n);
void    *memcpy(void *d, const void *s, size_t n);
void    *memmove(void *d, const void *s, size_t n);
int      memcmp(const void *a, const void *b, size_t n);
size_t   strlen(const char *s);

#endif
