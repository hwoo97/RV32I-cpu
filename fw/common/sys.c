/* End of the program (called by crt0 with the return value of main)
   - waits until the UART has sent everything
   - simulation build (-DSIM): reports the result to the SIMCTL slave, 0 -> PASS, n -> FAIL n
   - board build: stays in a loop (nothing to report to) */
#include "fwlib.h"

void fw_exit(int code)
{
    uart_flush();
#ifdef SIM
    SIMCTL_FINISH = (code == 0) ? 1u : (((uint32_t)code << 1) | 1u);
#else
    (void)code;
#endif
    for (;;)
        ;
}
