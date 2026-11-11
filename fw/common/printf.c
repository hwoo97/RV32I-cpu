/* Minimal printf to the UART: %d %i %u %x %X %c %s %p %%
   Flags '0' and '-', a field width, and the 'l' modifier (ignored, int = long on RV32) are accepted.
   RV32I has no divide instruction: the decimal conversion uses libgcc (__udivsi3, __umodsi3, link with -lgcc). */
#include <stdarg.h>
#include "fwlib.h"

static int put_field(const char *s, int len, int width, int left, char pad)
{
    int n = 0;
    if (!left)
        for (; len + n < width; n++)
            uart_putc(pad);
    for (int i = 0; i < len; i++)
        uart_putc(s[i]);
    n += len;
    if (left)
        for (; n < width; n++)
            uart_putc(' ');
    return n;
}

/* convert v to text in buf (filled from the end), returns the start pointer */
static char *utoa_rev(uint32_t v, unsigned base, int upper, char *end)
{
    const char *digits = upper ? "0123456789ABCDEF" : "0123456789abcdef";
    char *p = end;
    do {
        *--p = digits[v % base];
        v /= base;
    } while (v);
    return p;
}

int printf(const char *fmt, ...)
{
    va_list ap;
    char buf[12];                         /* "-2147483648" + spare */
    char *end = buf + sizeof buf;
    int count = 0;

    va_start(ap, fmt);
    for (; *fmt; fmt++) {
        if (*fmt != '%') {
            uart_putc(*fmt);
            count++;
            continue;
        }
        fmt++;
        int left = 0;
        char pad = ' ';
        for (;; fmt++) {
            if (*fmt == '-')      left = 1;
            else if (*fmt == '0') pad = '0';
            else break;
        }
        int width = 0;
        while (*fmt >= '0' && *fmt <= '9')
            width = width * 10 + (*fmt++ - '0');
        while (*fmt == 'l')
            fmt++;
        if (left)
            pad = ' ';

        char *s;
        switch (*fmt) {
        case 'd':
        case 'i': {
            int32_t v = va_arg(ap, int32_t);
            uint32_t u = v < 0 ? 0u - (uint32_t)v : (uint32_t)v;
            s = utoa_rev(u, 10, 0, end);
            if (v < 0) {
                if (pad == '0' && width > 0) {        /* sign before the zero padding */
                    uart_putc('-');
                    count++;
                    width--;
                } else {
                    *--s = '-';
                }
            }
            count += put_field(s, end - s, width, left, pad);
            break;
        }
        case 'u':
            s = utoa_rev(va_arg(ap, uint32_t), 10, 0, end);
            count += put_field(s, end - s, width, left, pad);
            break;
        case 'x':
        case 'X':
            s = utoa_rev(va_arg(ap, uint32_t), 16, *fmt == 'X', end);
            count += put_field(s, end - s, width, left, pad);
            break;
        case 'p':
            uart_puts("0x");
            s = utoa_rev((uint32_t)(uintptr_t)va_arg(ap, void *), 16, 0, end);
            count += 2 + put_field(s, end - s, 8, 0, '0');
            break;
        case 'c':
            buf[0] = (char)va_arg(ap, int);
            count += put_field(buf, 1, width, left, ' ');
            break;
        case 's':
            s = va_arg(ap, char *);
            if (!s)
                s = "(null)";
            count += put_field(s, (int)strlen(s), width, left, ' ');
            break;
        case '%':
            uart_putc('%');
            count++;
            break;
        case '\0':
            fmt--;                                     /* '%' at the end of the string */
            break;
        default:                                       /* unknown: print as is */
            uart_putc('%');
            uart_putc(*fmt);
            count += 2;
            break;
        }
    }
    va_end(ap);
    return count;
}
