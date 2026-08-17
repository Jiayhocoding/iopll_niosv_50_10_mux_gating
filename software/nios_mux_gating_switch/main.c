#include <stdint.h>

#include "system.h"
#include "io.h"
#include "priv/alt_busy_sleep.h"

#define BR_STATUS          0x10
#define STATUS_PLL_LOCKED  (1u << 3)
#define HOLD_TIME_US       1000000u

/* The inherited one-bit PIO is the request register, not a direct mux control. */
static inline void request_frequency(uint32_t request_10mhz)
{
    IOWR_32DIRECT(PIO_MUX_SEL_BASE, 0, request_10mhz & 1u);
}

static inline int pll_is_locked(void)
{
    return (IORD_32DIRECT(NIOS_IOPLL_BRIDGE_0_BASE, BR_STATUS) &
            STATUS_PLL_LOCKED) != 0u;
}

int main(void)
{
    request_frequency(0u); /* reset/default: 50 MHz */
    while (!pll_is_locked()) {
        /* No PLL write, reset, reconfiguration, or recalibration is issued. */
    }

    for (;;) {
        alt_busy_sleep(HOLD_TIME_US);
        request_frequency(1u); /* RTL performs enable/guard/mux/gate sequence. */
        alt_busy_sleep(HOLD_TIME_US);
        request_frequency(0u);
    }
}
