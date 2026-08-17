#include <stdint.h>
#include <stdio.h>

#include "system.h"
#include "io.h"
#include "priv/alt_busy_sleep.h"

#define IOPLL_BASE          NIOS_IOPLL_BRIDGE_0_BASE
#define BR_CONTROL          0x00
#define BR_ADDRESS          0x04
#define BR_WDATA            0x08
#define BR_RDATA            0x0C
#define BR_STATUS           0x10

#define CTRL_START          (1u << 0)
#define CTRL_WRITE          (1u << 1)
#define CTRL_CLEAR_DONE     (1u << 8)
#define CTRL_CLEAR_ERROR    (1u << 9)
#define CTRL_CLEAR_REJECTED (1u << 10)
#define STATUS_BUSY         (1u << 0)
#define STATUS_DONE         (1u << 1)
#define STATUS_ERROR        (1u << 2)
#define STATUS_PLL_LOCKED   (1u << 3)
#define STATUS_REJECTED     (1u << 4)

#define REG_ACCESS_ENABLE   0x004u
#define REG_RECAL_ENABLE    0x012u
#define REG_CAL_STATUS      0x016u
#define REG_DIVIDER_C0      0x017u
#define REG_PLL_RESET       0x020u
#define REG_RECAL_REQUEST   0x022u

#define ACCESS_ENABLE_MASK  0x00000001u
#define CAL_STATUS_MASK     0x00200080u
#define C0_ODD_MASK         0x80000000u
#define C0_LOW_COUNT_MASK   0x7F800000u
#define C0_BYPASS_MASK      0x00000100u
#define C0_HIGH_COUNT_MASK  0x000000FFu
#define C0_COUNT_MASK       (C0_ODD_MASK | C0_LOW_COUNT_MASK | \
                             C0_BYPASS_MASK | C0_HIGH_COUNT_MASK)
#define C0_PRESERVED_MASK   (~C0_COUNT_MASK)
#define PLL_RESET_MASK      0x00000004u
#define RECAL_ENABLE_MASK   0x00004000u
#define RECAL_REQUEST_MASK  0x00000800u
#define IO_TIMEOUT          1000000u

#define ERR_BUSY_TIMEOUT    (1u << 0)
#define ERR_DONE_TIMEOUT    (1u << 1)
#define ERR_BRIDGE          (1u << 2)
#define ERR_REJECTED        (1u << 3)
#define ERR_C0_READBACK     (1u << 4)
#define ERR_LOCK_TIMEOUT    (1u << 5)

volatile uint32_t c0_before;
volatile uint32_t c0_candidate;
volatile uint32_t c0_after_write;
volatile uint32_t c0_final;
volatile uint32_t access_before;
volatile uint32_t access_after;
volatile uint32_t calibration_status_before;
volatile uint32_t calibration_status_after;
volatile uint32_t recal_enable_value;
volatile uint32_t recal_request_value;
volatile uint32_t locked_before_reset;
volatile uint32_t locked_after_reset_assert;
volatile uint32_t locked_after_reset_release;
volatile uint32_t locked_after_request;
volatile uint32_t locked_final;
volatile uint32_t error_flags;
volatile uint32_t final_bridge_status;

static inline void gpio2_high(void)
{
    IOWR_32DIRECT(PIO_GPIO2_TRIGGER_BASE, 0x00, 1u);
}

static inline void gpio2_low(void)
{
    IOWR_32DIRECT(PIO_GPIO2_TRIGGER_BASE, 0x00, 0u);
}

static void record_status(uint32_t status)
{
    final_bridge_status = status;
    if (status & STATUS_ERROR)
        error_flags |= ERR_BRIDGE;
    if (status & STATUS_REJECTED)
        error_flags |= ERR_REJECTED;
}

static int transaction(uint16_t address, int write, uint32_t wdata,
                       volatile uint32_t *rdata)
{
    uint32_t status;
    uint32_t timeout = IO_TIMEOUT;

    do {
        status = IORD_32DIRECT(IOPLL_BASE, BR_STATUS);
        record_status(status);
        if ((status & STATUS_BUSY) == 0u)
            break;
    } while (--timeout != 0u);
    if (timeout == 0u) {
        error_flags |= ERR_BUSY_TIMEOUT;
        return -1;
    }

    IOWR_32DIRECT(IOPLL_BASE, BR_CONTROL,
                  CTRL_CLEAR_DONE | CTRL_CLEAR_ERROR | CTRL_CLEAR_REJECTED);
    IOWR_32DIRECT(IOPLL_BASE, BR_ADDRESS, address);
    if (write)
        IOWR_32DIRECT(IOPLL_BASE, BR_WDATA, wdata);
    IOWR_32DIRECT(IOPLL_BASE, BR_CONTROL,
                  CTRL_START | (write ? CTRL_WRITE : 0u));

    timeout = IO_TIMEOUT;
    do {
        status = IORD_32DIRECT(IOPLL_BASE, BR_STATUS);
        record_status(status);
        if (status & (STATUS_ERROR | STATUS_REJECTED))
            return -1;
        if (status & STATUS_DONE)
            break;
    } while (--timeout != 0u);
    if (timeout == 0u) {
        error_flags |= ERR_DONE_TIMEOUT;
        return -1;
    }

    if (!write)
        *rdata = IORD_32DIRECT(IOPLL_BASE, BR_RDATA);
    IOWR_32DIRECT(IOPLL_BASE, BR_CONTROL,
                  CTRL_CLEAR_DONE | CTRL_CLEAR_ERROR | CTRL_CLEAR_REJECTED);
    return 0;
}

static int read_reg(uint16_t address, volatile uint32_t *value)
{
    return transaction(address, 0, 0u, value);
}

static int write_reg(uint16_t address, uint32_t value)
{
    return transaction(address, 1, value, (volatile uint32_t *)0);
}

static uint32_t sample_locked(void)
{
    uint32_t status = IORD_32DIRECT(IOPLL_BASE, BR_STATUS);
    record_status(status);
    return (status & STATUS_PLL_LOCKED) != 0u;
}

static int wait_for_locked(void)
{
    uint32_t timeout = IO_TIMEOUT;

    do {
        if (sample_locked() != 0u)
            return 0;
    } while (--timeout != 0u);

    error_flags |= ERR_LOCK_TIMEOUT;
    return -1;
}

static int reconfigure_c0(uint32_t high_count, uint32_t low_count)
{
    uint32_t value;
    int rc = -1;

    c0_before = 0u;
    c0_candidate = 0u;
    c0_after_write = 0u;
    c0_final = 0u;
    access_before = 0u;
    access_after = 0u;
    calibration_status_before = 0u;
    calibration_status_after = 0u;
    recal_enable_value = 0u;
    recal_request_value = 0u;
    locked_before_reset = 0u;
    locked_after_reset_assert = 0u;
    locked_after_reset_release = 0u;
    locked_after_request = 0u;
    locked_final = 0u;
    error_flags = 0u;
    final_bridge_status = 0u;

    if (high_count > 0xffu || low_count > 0xffu)
        goto finished;

    /* Execute the complete documented manual sequence on every transition. */
    gpio2_high();
    if (read_reg(REG_ACCESS_ENABLE, &access_before) != 0 ||
        write_reg(REG_ACCESS_ENABLE,
                  access_before | ACCESS_ENABLE_MASK) != 0 ||
        read_reg(REG_ACCESS_ENABLE, &access_after) != 0)
        goto finished;

    if (read_reg(REG_CAL_STATUS, &calibration_status_before) != 0 ||
        write_reg(REG_CAL_STATUS,
                  calibration_status_before & ~CAL_STATUS_MASK) != 0 ||
        read_reg(REG_CAL_STATUS, &calibration_status_after) != 0)
        goto finished;

    if (read_reg(REG_DIVIDER_C0, &c0_before) != 0)
        goto finished;
    c0_candidate = (c0_before & C0_PRESERVED_MASK) |
                   ((low_count & 0xffu) << 23) |
                   (high_count & 0xffu);
    if (write_reg(REG_DIVIDER_C0, c0_candidate) != 0 ||
        read_reg(REG_DIVIDER_C0, &c0_after_write) != 0)
        goto finished;
    if (c0_after_write != c0_candidate) {
        error_flags |= ERR_C0_READBACK;
        goto finished;
    }

    locked_before_reset = sample_locked();
    if (read_reg(REG_PLL_RESET, &value) != 0 ||
        write_reg(REG_PLL_RESET, value | PLL_RESET_MASK) != 0)
        goto finished;
    locked_after_reset_assert = sample_locked();
    (void)alt_busy_sleep(1u); /* Safely longer than the required 10 ns. */
    if (write_reg(REG_PLL_RESET, value & ~PLL_RESET_MASK) != 0)
        goto finished;
    locked_after_reset_release = sample_locked();

    if (read_reg(REG_RECAL_ENABLE, &value) != 0 ||
        write_reg(REG_RECAL_ENABLE, value | RECAL_ENABLE_MASK) != 0 ||
        read_reg(REG_RECAL_ENABLE, &recal_enable_value) != 0)
        goto finished;

    if (read_reg(REG_RECAL_REQUEST, &value) != 0 ||
        write_reg(REG_RECAL_REQUEST, value | RECAL_REQUEST_MASK) != 0 ||
        read_reg(REG_RECAL_REQUEST, &recal_request_value) != 0)
        goto finished;

    /* Lock asserted is the documented recalibration completion condition. */
    locked_after_request = sample_locked();
    if (wait_for_locked() != 0)
        goto finished;
    locked_final = sample_locked();

    if (read_reg(REG_RECAL_ENABLE, &value) != 0 ||
        write_reg(REG_RECAL_ENABLE, value & ~RECAL_ENABLE_MASK) != 0)
        goto finished;

    if (read_reg(REG_DIVIDER_C0, &c0_final) != 0)
        goto finished;
    rc = 0;

finished:
    gpio2_low();
    record_status(IORD_32DIRECT(IOPLL_BASE, BR_STATUS));
    printf("C0 before                   = 0x%08lx\n", (unsigned long)c0_before);
    printf("C0 candidate                = 0x%08lx\n", (unsigned long)c0_candidate);
    printf("C0 immediate readback       = 0x%08lx\n\n", (unsigned long)c0_after_write);
    printf("locked before reset         = %lu\n", (unsigned long)locked_before_reset);
    printf("locked after reset assert   = %lu\n", (unsigned long)locked_after_reset_assert);
    printf("locked after reset release  = %lu\n\n", (unsigned long)locked_after_reset_release);
    printf("locked after recal request  = %lu\n", (unsigned long)locked_after_request);
    printf("locked final                = %lu\n\n", (unsigned long)locked_final);
    printf("C0 final readback           = 0x%08lx\n", (unsigned long)c0_final);
    printf("Bridge status               = 0x%08lx\n", (unsigned long)final_bridge_status);
    printf("Error flags                 = 0x%08lx\n\n", (unsigned long)error_flags);
    return rc;
}

int main(void)
{
    printf("\n=== Continuous Manual-Only HVIO IOPLL Frequency Toggle ===\n");
    printf("Static start: 100 MHz; VCO: 3.2 GHz; no M/N changes.\n");
    printf("Corrected word-addressed core_avl registers: "
           "0x004 0x012 0x016 0x017 0x020 0x022\n");
    printf("No diagnostic external reset or undocumented operation is used.\n\n");

    gpio2_low();

    while (1) {
        printf("Switching to 50 MHz (C0 divide 64)...\n");
        if (reconfigure_c0(32u, 32u) != 0) {
            printf("ERROR: reconfiguration to 50 MHz failed; halted.\n");
            break;
        }
        printf("Now expected: 50 MHz\n\n");
        (void)alt_busy_sleep(10000u);

        printf("Switching to 100 MHz (C0 divide 32)...\n");
        if (reconfigure_c0(16u, 16u) != 0) {
            printf("ERROR: reconfiguration to 100 MHz failed; halted.\n");
            break;
        }
        printf("Now expected: 100 MHz\n\n");
        (void)alt_busy_sleep(10000u);
    }

    while (1) { }
    return 0;
}
