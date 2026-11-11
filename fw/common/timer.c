/* TIMER helpers: COUNT runs freely (EN = 1, AUTO = 0), time is measured by differences,
   so the wrap-around of the 32-bit counter does not matter. */
#include "fwlib.h"

void timer_init(void)
{
    TIMER_CTRL   = 0;
    TIMER_COUNT  = 0;
    TIMER_CMP    = 0xFFFFFFFFu;
    TIMER_STATUS = TIMER_STATUS_MATCH;
    TIMER_CTRL   = TIMER_CTRL_EN;
}

uint32_t timer_now(void)
{
    return TIMER_COUNT;
}

void delay_cycles(uint32_t n)
{
    uint32_t t0 = TIMER_COUNT;
    while (TIMER_COUNT - t0 < n)
        ;
}
