/* hello - first C program on the stage 4 MCU
   Checks the whole path firmware -> core -> bus -> peripherals:
     - printf through the UART (strings in .rodata are read from IMEM through the irom port)
     - .data copied by crt0, .bss cleared by crt0
     - GPIO out/in (the testbench feeds gpio_in = {gpio_out[7:0], 8'hC3})
     - TIMER: a measured delay
   The simulation testbench (sim/ch14a_mcu/fw_tb.v) decodes the UART pin and compares it
   with expected.txt; the return value of main is the result (0 = PASS). */
#include "fwlib.h"

static int      data_val = 1234;          /* .data: initial value from IMEM */
static uint32_t bss_val;                  /* .bss : must start at 0 */
static const char banner[] = "Hello, RV32I MCU!";

int main(void)
{
    int errors = 0;

    timer_init();
    uart_init(UART_BAUDDIV_INIT);

    printf("%s\n", banner);
    printf("dec: %d %d %u %i\n", 12345, -678, 4000000000u, 0);
    printf("hex: %x %08X %p\n", 0xbeefu, 0x1234abcdu, (void *)UART_BASE);
    printf("fmt: [%5d] [%-5d] [%05d] [%c] [%s] 100%%\n", 42, 42, -42, 'Z', "ok");

    /* .data / .bss */
    printf("data: %d, bss: %u\n", data_val, (unsigned)bss_val);
    if (data_val != 1234 || bss_val != 0)
        errors++;
    data_val += 1;
    bss_val = 0xA5;
    if (data_val != 1235 || bss_val != 0xA5)
        errors++;

    /* GPIO: low byte as output; the testbench loops it back to the high byte of gpio_in */
    GPIO_DIR = 0x00FFu;
    GPIO_DATA_OUT = 0x5Au;
    delay_cycles(10);                     /* 2-FF input synchronizer */
    uint32_t in = GPIO_DATA_IN;
    printf("gpio: dir %04x out %04x in %04x\n",
           (unsigned)GPIO_DIR, (unsigned)GPIO_DATA_OUT, (unsigned)in);
    if (in != 0x5AC3u)
        errors++;

    /* TIMER: delay_cycles(1000) must take at least 1000 clocks and not much more */
    uint32_t t0 = timer_now();
    delay_cycles(1000);
    uint32_t dt = timer_now() - t0;
    printf("timer: %s\n", (dt >= 1000 && dt < 1100) ? "ok" : "bad");
    if (dt < 1000 || dt >= 1100)
        errors++;

    printf("errors: %d\n", errors);
    return errors;
}
