#include <stdint.h>
#include <stdio.h>

#include "system.h"
#include "io.h"
#include "priv/alt_busy_sleep.h"

#ifndef POST_RESET_SETTLE_US
#define POST_RESET_SETTLE_US 0u
#endif

#if (POST_RESET_SETTLE_US != 0u) && \
    (POST_RESET_SETTLE_US != 1u) && \
    (POST_RESET_SETTLE_US != 10u) && \
    (POST_RESET_SETTLE_US != 100u)
#error "POST_RESET_SETTLE_US must be 0, 1, 10, or 100"
#endif

#ifndef RECAL_ENABLE_HOLD_US
#define RECAL_ENABLE_HOLD_US 0u
#endif

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

#define REG_ACCESS_ENABLE   0x010u
#define REG_RECAL_ENABLE    0x048u
#define REG_CAL_STATUS      0x058u
#define REG_DIVIDER_C0      0x05Cu
#define REG_PLL_RESET       0x080u
#define REG_RECAL_REQUEST   0x088u

#define ACCESS_ENABLE_MASK  0x00000001u
#define CAL_STATUS_MASK     0x00200080u
#define C0_ODD_MASK         0x80000000u
#define C0_LOW_COUNT_MASK   0x7F800000u
#define C0_BYPASS_MASK      0x00000100u
#define C0_HIGH_COUNT_MASK  0x000000FFu
#define C0_MODIFIED_MASK    (C0_ODD_MASK | C0_LOW_COUNT_MASK | \
                             C0_BYPASS_MASK | C0_HIGH_COUNT_MASK)
#define C0_PRESERVED_MASK   (~C0_MODIFIED_MASK)
#define C0_TARGET_HIGH      32u
#define C0_TARGET_LOW       32u
#define PLL_RESET_MASK      0x00000004u
#define RECAL_ENABLE_MASK   0x00004000u
#define RECAL_REQUEST_MASK  0x00000800u
#define IO_TIMEOUT          1000000u
#define RESET_HOLD_DELAY    100u
#define OBSERVE_DELAY       100000u

#define CAP_ERR_BUSY_TIMEOUT   (1u << 0)
#define CAP_ERR_CLEAR_TIMEOUT  (1u << 1)
#define CAP_ERR_DONE_TIMEOUT   (1u << 2)
#define CAP_ERR_BRIDGE_ERROR   (1u << 3)
#define CAP_ERR_REJECTED       (1u << 4)
#define CAP_ERR_C0_READBACK    (1u << 5)

/* Volatile capture variables are intentionally easy to inspect in a debugger. */
volatile uint32_t capture_state = 0u;
volatile uint32_t capture_error_flags = 0u;
volatile uint32_t capture_last_status = 0u;
volatile uint32_t capture_status_before_clear = 0u;
volatile uint32_t capture_status_after_clear = 0u;
volatile uint32_t capture_status_after_start = 0u;
volatile uint32_t capture_status_at_completion = 0u;
volatile uint32_t capture_error_status = 0u;

volatile uint32_t capture_access_old = 0u;
volatile uint32_t capture_cal_before = 0u;
volatile uint32_t capture_cal_clear_value = 0u;
volatile uint32_t capture_cal_after_clear = 0u;
volatile uint32_t capture_cal_after_request = 0u;
volatile uint32_t capture_cal_delayed = 0u;
volatile uint32_t capture_c0_before = 0u;
volatile uint32_t capture_c0_target = 0u;
volatile uint32_t capture_c0_immediate = 0u;
volatile uint32_t capture_c0_final = 0u;
volatile uint32_t capture_reset_old = 0u;
volatile uint32_t capture_recal_enable_old = 0u;
volatile uint32_t capture_recal_enable_current = 0u;
volatile uint32_t capture_recal_request_old = 0u;
volatile uint32_t capture_final_locked = 0u;
volatile uint32_t capture_post_reset_settle_us = POST_RESET_SETTLE_US;
volatile uint32_t capture_recal_hold_us = RECAL_ENABLE_HOLD_US;
volatile uint32_t capture_hold_samples = 0u;
volatile uint32_t capture_hold_status_or = 0u;
volatile uint32_t capture_hold_locked_high_samples = 0u;
volatile uint32_t capture_hold_locked_low_samples = 0u;

static void record_error(uint32_t flag, uint32_t status)
{
    capture_error_flags |= flag;
    capture_error_status = status;
    capture_last_status = status;
}

static int wait_busy_clear(uint32_t *status)
{
    uint32_t timeout = IO_TIMEOUT;

    do {
        *status = IORD_32DIRECT(IOPLL_BASE, BR_STATUS);
        capture_last_status = *status;
        if ((*status & STATUS_BUSY) == 0u)
            return 0;
    } while (--timeout != 0u);

    record_error(CAP_ERR_BUSY_TIMEOUT, *status);
    return -1;
}

static int clear_and_verify_status(uint32_t *status)
{
    uint32_t timeout = IO_TIMEOUT;

    IOWR_32DIRECT(IOPLL_BASE, BR_CONTROL,
                  CTRL_CLEAR_DONE | CTRL_CLEAR_ERROR | CTRL_CLEAR_REJECTED);
    do {
        *status = IORD_32DIRECT(IOPLL_BASE, BR_STATUS);
        capture_last_status = *status;
        if ((*status & (STATUS_DONE | STATUS_ERROR | STATUS_REJECTED)) == 0u)
            return 0;
    } while (--timeout != 0u);

    record_error(CAP_ERR_CLEAR_TIMEOUT, *status);
    return -1;
}

static int iopll_transaction(uint16_t address, int is_write,
                             uint32_t write_data, volatile uint32_t *read_data)
{
    uint32_t status;
    uint32_t timeout = IO_TIMEOUT;

    if (wait_busy_clear(&status) != 0)
        return -1;
    capture_status_before_clear = status;

    if (clear_and_verify_status(&status) != 0)
        return -1;
    capture_status_after_clear = status;

    IOWR_32DIRECT(IOPLL_BASE, BR_ADDRESS, address);
    if (is_write)
        IOWR_32DIRECT(IOPLL_BASE, BR_WDATA, write_data);
    IOWR_32DIRECT(IOPLL_BASE, BR_CONTROL,
                  CTRL_START | (is_write ? CTRL_WRITE : 0u));

    status = IORD_32DIRECT(IOPLL_BASE, BR_STATUS);
    capture_status_after_start = status;
    capture_last_status = status;

    while ((status & STATUS_DONE) == 0u) {
        if ((status & STATUS_ERROR) != 0u) {
            record_error(CAP_ERR_BRIDGE_ERROR, status);
            return -1;
        }
        if ((status & STATUS_REJECTED) != 0u) {
            record_error(CAP_ERR_REJECTED, status);
            return -1;
        }
        if (--timeout == 0u) {
            record_error(CAP_ERR_DONE_TIMEOUT, status);
            return -1;
        }
        status = IORD_32DIRECT(IOPLL_BASE, BR_STATUS);
        capture_last_status = status;
    }

    if (wait_busy_clear(&status) != 0)
        return -1;
    capture_status_at_completion = status;
    capture_last_status = status;

    if ((status & STATUS_ERROR) != 0u) {
        record_error(CAP_ERR_BRIDGE_ERROR, status);
        return -1;
    }
    if ((status & STATUS_REJECTED) != 0u) {
        record_error(CAP_ERR_REJECTED, status);
        return -1;
    }

    if (!is_write)
        *read_data = IORD_32DIRECT(IOPLL_BASE, BR_RDATA);

    IOWR_32DIRECT(IOPLL_BASE, BR_CONTROL,
                  CTRL_CLEAR_DONE | CTRL_CLEAR_ERROR | CTRL_CLEAR_REJECTED);
    return 0;
}

static int iopll_read(uint16_t address, volatile uint32_t *value)
{
    return iopll_transaction(address, 0, 0u, value);
}

static int iopll_write(uint16_t address, uint32_t value)
{
    return iopll_transaction(address, 1, value, (volatile uint32_t *)0);
}

static void delay_cycles(uint32_t count)
{
    volatile uint32_t i;

    for (i = 0u; i < count; ++i)
        __asm__ volatile ("nop");
}

int main(void)
{
    uint32_t status;

    /* Sequence starts here. No printf or JTAG UART access until state 4. */
    if (iopll_read(REG_ACCESS_ENABLE, &capture_access_old) != 0 ||
        iopll_write(REG_ACCESS_ENABLE,
                    capture_access_old | ACCESS_ENABLE_MASK) != 0)
        goto sequence_finished;

    if (iopll_read(REG_CAL_STATUS, &capture_cal_before) != 0)
        goto sequence_finished;
    capture_cal_clear_value = capture_cal_before & ~CAL_STATUS_MASK;
    if (iopll_write(REG_CAL_STATUS, capture_cal_clear_value) != 0 ||
        iopll_read(REG_CAL_STATUS, &capture_cal_after_clear) != 0)
        goto sequence_finished;

    if (iopll_read(REG_DIVIDER_C0, &capture_c0_before) != 0)
        goto sequence_finished;
    capture_c0_target = (capture_c0_before & C0_PRESERVED_MASK) |
                        (C0_TARGET_LOW << 23) | C0_TARGET_HIGH;
    if (iopll_write(REG_DIVIDER_C0, capture_c0_target) != 0 ||
        iopll_read(REG_DIVIDER_C0, &capture_c0_immediate) != 0)
        goto sequence_finished;
    if (capture_c0_immediate != capture_c0_target) {
        capture_error_flags |= CAP_ERR_C0_READBACK;
        goto sequence_finished;
    }

    if (iopll_read(REG_PLL_RESET, &capture_reset_old) != 0 ||
        iopll_write(REG_PLL_RESET,
                    capture_reset_old | PLL_RESET_MASK) != 0)
        goto sequence_finished;
    delay_cycles(RESET_HOLD_DELAY);
    if (iopll_write(REG_PLL_RESET,
                    capture_reset_old & ~PLL_RESET_MASK) != 0)
        goto sequence_finished;

#if POST_RESET_SETTLE_US != 0u
    (void)alt_busy_sleep(POST_RESET_SETTLE_US);
#endif

    capture_state = 1u;
    if (iopll_read(REG_RECAL_ENABLE, &capture_recal_enable_old) != 0 ||
        iopll_write(REG_RECAL_ENABLE,
                    capture_recal_enable_old | RECAL_ENABLE_MASK) != 0)
        goto sequence_finished;

    capture_state = 2u;
    /* Only the required 0x088 RMW transactions occur in this interval. */
    if (iopll_read(REG_RECAL_REQUEST, &capture_recal_request_old) != 0 ||
        iopll_write(REG_RECAL_REQUEST,
                    capture_recal_request_old | RECAL_REQUEST_MASK) != 0)
        goto sequence_finished;
    capture_state = 3u;

    if (iopll_read(REG_CAL_STATUS, &capture_cal_after_request) != 0)
        goto sequence_finished;
#if RECAL_ENABLE_HOLD_US != 0u
    {
        uint32_t elapsed_us;

        for (elapsed_us = 0u; elapsed_us < RECAL_ENABLE_HOLD_US;
             elapsed_us += 100u) {
            status = IORD_32DIRECT(IOPLL_BASE, BR_STATUS);
            capture_last_status = status;
            capture_hold_status_or |= status;
            ++capture_hold_samples;
            if ((status & STATUS_PLL_LOCKED) != 0u)
                ++capture_hold_locked_high_samples;
            else
                ++capture_hold_locked_low_samples;
            (void)alt_busy_sleep(100u);
        }
    }
#endif
    delay_cycles(OBSERVE_DELAY);
    if (iopll_read(REG_CAL_STATUS, &capture_cal_delayed) != 0)
        goto sequence_finished;
    status = IORD_32DIRECT(IOPLL_BASE, BR_STATUS);
    capture_last_status = status;
    capture_final_locked = ((status & STATUS_PLL_LOCKED) != 0u);

    if (iopll_read(REG_RECAL_ENABLE, &capture_recal_enable_current) != 0 ||
        iopll_write(REG_RECAL_ENABLE,
                    capture_recal_enable_current & ~RECAL_ENABLE_MASK) != 0)
        goto sequence_finished;

    if (iopll_read(REG_DIVIDER_C0, &capture_c0_final) != 0)
        goto sequence_finished;

sequence_finished:
    capture_state = 4u;

    printf("C0 before               = 0x%08lx\n", (unsigned long)capture_c0_before);
    printf("C0 target               = 0x%08lx\n", (unsigned long)capture_c0_target);
    printf("Immediate C0            = 0x%08lx\n", (unsigned long)capture_c0_immediate);
    printf("Final C0                = 0x%08lx\n", (unsigned long)capture_c0_final);
    printf("Calibration before      = 0x%08lx\n", (unsigned long)capture_cal_before);
    printf("Calibration clear value = 0x%08lx\n", (unsigned long)capture_cal_clear_value);
    printf("Calibration after clear = 0x%08lx (observation)\n",
           (unsigned long)capture_cal_after_clear);
    printf("Calibration after req   = 0x%08lx\n", (unsigned long)capture_cal_after_request);
    printf("Calibration delayed     = 0x%08lx\n", (unsigned long)capture_cal_delayed);
    printf("Final locked            = %lu\n", (unsigned long)capture_final_locked);
    printf("Error flags             = 0x%08lx\n", (unsigned long)capture_error_flags);
    printf("Error/status snapshot   = 0x%08lx\n", (unsigned long)capture_error_status);
    printf("Final bridge status     = 0x%08lx\n", (unsigned long)capture_last_status);
    printf("Post-reset settle       = %lu us\n",
           (unsigned long)capture_post_reset_settle_us);
    printf("Recal-enable hold       = %lu us\n",
           (unsigned long)capture_recal_hold_us);
    printf("Hold samples            = %lu (locked high=%lu low=%lu)\n",
           (unsigned long)capture_hold_samples,
           (unsigned long)capture_hold_locked_high_samples,
           (unsigned long)capture_hold_locked_low_samples);
    printf("Hold STATUS OR          = 0x%08lx\n",
           (unsigned long)capture_hold_status_or);

    while (1) { }
    return 0;
}
