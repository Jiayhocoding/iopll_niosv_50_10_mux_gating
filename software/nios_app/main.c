#include <stdio.h>
#include <stdint.h>

#include "system.h"
#include "io.h"

// ============================================================
// Nios-visible bridge register offsets
// ============================================================
#define IOPLL_REG_CONTROL   0x00
#define IOPLL_REG_ADDRESS   0x04
#define IOPLL_REG_WDATA     0x08
#define IOPLL_REG_RDATA     0x0C
#define IOPLL_REG_STATUS    0x10

// CONTROL bits
#define CTRL_START          (1u << 0)
#define CTRL_WRITE          (1u << 1)
#define CTRL_CLEAR_DONE     (1u << 8)
#define CTRL_CLEAR_ERROR    (1u << 9)
#define CTRL_CLEAR_REJECTED (1u << 10)

// STATUS bits
#define STATUS_BUSY         (1u << 0)
#define STATUS_DONE         (1u << 1)
#define STATUS_ERROR        (1u << 2)
#define STATUS_PLL_LOCKED   (1u << 3)
#define STATUS_REJECTED     (1u << 4)

#define IOPLL_BASE          NIOS_IOPLL_BRIDGE_0_BASE

// ============================================================
// IOPLL reconfiguration register addresses
// ============================================================
#define REG_ACCESS_ENABLE   0x010
#define REG_RECAL_ENABLE    0x048
#define REG_CAL_STATUS      0x058
#define REG_FREQ_SELECT     0x064
#define REG_PLL_RESET       0x080
#define REG_RECAL_REQUEST   0x088

// Masks
#define ACCESS_ENABLE_MASK  0x00000001u
#define CAL_STATUS_MASK     0x00200080u   // bit[21] + bit[7]
#define FREQ_SELECT_MASK    0x00000001u   // experimental diff: 100 MHz=0, 50 MHz=1
#define PLL_RESET_MASK      0x00000004u   // bit[2]
#define RECAL_ENABLE_MASK   0x00004000u   // bit[14]
#define RECAL_REQUEST_MASK  0x00000800u   // bit[11]

// ============================================================
// Bridge helpers
// ============================================================
static void bridge_clear_status(void)
{
    IOWR_32DIRECT(
        IOPLL_BASE,
        IOPLL_REG_CONTROL,
        CTRL_CLEAR_DONE |
        CTRL_CLEAR_ERROR |
        CTRL_CLEAR_REJECTED
    );
}

static int bridge_wait_done(const char *op_name)
{
    uint32_t status = 0;
    uint32_t timeout = 1000000;

    do {
        status = IORD_32DIRECT(
            IOPLL_BASE,
            IOPLL_REG_STATUS
        );

        if (((status & STATUS_BUSY) == 0) &&
            ((status & STATUS_DONE) != 0)) {
            break;
        }

        timeout--;
    } while (timeout != 0);

    if (timeout == 0) {
        printf("ERROR: timeout waiting for IOPLL %s\n", op_name);
        printf("STATUS = 0x%08lx\n", (unsigned long)status);
        return -1;
    }

    if (status & STATUS_ERROR) {
        printf("ERROR: HVIO transaction error during %s\n", op_name);
        printf("STATUS = 0x%08lx\n", (unsigned long)status);
        return -2;
    }

    if (status & STATUS_REJECTED) {
        printf("ERROR: bridge command rejected during %s\n", op_name);
        printf("STATUS = 0x%08lx\n", (unsigned long)status);
        return -3;
    }

    return 0;
}

static int iopll_read_reg(uint16_t address, uint32_t *value)
{
    int rc;

    bridge_clear_status();

    IOWR_32DIRECT(
        IOPLL_BASE,
        IOPLL_REG_ADDRESS,
        (uint32_t)address
    );

    // START=1, WRITE=0
    IOWR_32DIRECT(
        IOPLL_BASE,
        IOPLL_REG_CONTROL,
        CTRL_START
    );

    rc = bridge_wait_done("read");
    if (rc != 0) {
        return rc;
    }

    *value = IORD_32DIRECT(
        IOPLL_BASE,
        IOPLL_REG_RDATA
    );

    return 0;
}

static int iopll_write_reg(uint16_t address, uint32_t value)
{
    int rc;

    bridge_clear_status();

    IOWR_32DIRECT(
        IOPLL_BASE,
        IOPLL_REG_ADDRESS,
        (uint32_t)address
    );

    IOWR_32DIRECT(
        IOPLL_BASE,
        IOPLL_REG_WDATA,
        value
    );

    // START=1, WRITE=1
    IOWR_32DIRECT(
        IOPLL_BASE,
        IOPLL_REG_CONTROL,
        CTRL_START | CTRL_WRITE
    );

    rc = bridge_wait_done("write");
    if (rc != 0) {
        return rc;
    }

    return 0;
}

static int wait_until_locked(void)
{
    uint32_t status = 0;
    uint32_t timeout = 1000000;

    while (timeout != 0) {
        status = IORD_32DIRECT(
            IOPLL_BASE,
            IOPLL_REG_STATUS
        );

        if (status & STATUS_PLL_LOCKED) {
            return 0;
        }

        timeout--;
    }

    printf("ERROR: timeout waiting for PLL locked = 1\n");
    printf("STATUS = 0x%08lx\n", (unsigned long)status);

    return -1;
}

// ============================================================
// Main
//
// Experimental basis from static design diff:
//   100 MHz: REG 0x064 = 0xC0008E00
//    50 MHz: REG 0x064 = 0xC0008E01
//
// Only difference: bit[0]
//
// Sequence follows the PPT flow:
//   1. enable access        0x10 bit0 = 1
//   2. clear cal status     0x58 bit7/21 = 1
//   3. RMW 0x64 bit0 = 1
//   4. reset pulse          0x80 bit2
//   5. enable recal         0x48 bit14 = 1
//   6. request recal        0x88 bit11 = 1
//   7. wait locked = 1
//   8. clear recal enable   0x48 bit14 = 0
// ============================================================
int main(void)
{
    uint32_t status;
    uint32_t reg10;
    uint32_t reg58;
    uint32_t reg64_old;
    uint32_t reg64_new;
    uint32_t reg64_after;
    uint32_t reg80;
    uint32_t reg48;
    uint32_t reg88;

    int rc;

    printf("\n");
    printf("========================================\n");
    printf(" Agilex 5 IOPLL Runtime Experiment\n");
    printf(" REG 0x064 bit[0]: 100 MHz -> 50 MHz\n");
    printf("========================================\n");

    printf("Bridge BASE = 0x%08x\n",
           (unsigned int)IOPLL_BASE);

    status = IORD_32DIRECT(
        IOPLL_BASE,
        IOPLL_REG_STATUS
    );

    printf("Initial STATUS = 0x%08lx\n",
           (unsigned long)status);

    printf("PLL locked = %s\n",
           (status & STATUS_PLL_LOCKED) ? "YES" : "NO");

    // --------------------------------------------------------
    // 1. Enable register access
    // --------------------------------------------------------
    printf("\n[1] Enable register access: 0x010 bit[0] = 1\n");

    rc = iopll_read_reg(REG_ACCESS_ENABLE, &reg10);
    if (rc != 0) {
        printf("FAILED: READ 0x010, rc=%d\n", rc);
        goto test_end;
    }

    printf("0x010 old = 0x%08lx\n", (unsigned long)reg10);

    reg10 |= ACCESS_ENABLE_MASK;

    rc = iopll_write_reg(REG_ACCESS_ENABLE, reg10);
    if (rc != 0) {
        printf("FAILED: WRITE 0x010, rc=%d\n", rc);
        goto test_end;
    }

    // --------------------------------------------------------
    // 2. Clear previous calibration status
    // --------------------------------------------------------
    printf("\n[2] Clear calibration status: 0x058 bit[7], bit[21] = 1\n");

    rc = iopll_read_reg(REG_CAL_STATUS, &reg58);
    if (rc != 0) {
        printf("FAILED: READ 0x058, rc=%d\n", rc);
        goto test_end;
    }

    printf("0x058 old = 0x%08lx\n", (unsigned long)reg58);

    reg58 |= CAL_STATUS_MASK;

    rc = iopll_write_reg(REG_CAL_STATUS, reg58);
    if (rc != 0) {
        printf("FAILED: WRITE 0x058, rc=%d\n", rc);
        goto test_end;
    }

    printf("0x058 new = 0x%08lx\n", (unsigned long)reg58);

    // --------------------------------------------------------
    // 3. Read and modify REG 0x064 bit[0]
    // --------------------------------------------------------
    printf("\n[3] Read REG 0x064\n");

    rc = iopll_read_reg(REG_FREQ_SELECT, &reg64_old);
    if (rc != 0) {
        printf("FAILED: READ 0x064, rc=%d\n", rc);
        goto test_end;
    }

    printf("0x064 old = 0x%08lx\n",
           (unsigned long)reg64_old);

    reg64_new = reg64_old | FREQ_SELECT_MASK;

    printf("0x064 new = 0x%08lx\n",
           (unsigned long)reg64_new);

    printf("\n[4] Write REG 0x064 bit[0] = 1\n");

    rc = iopll_write_reg(REG_FREQ_SELECT, reg64_new);
    if (rc != 0) {
        printf("FAILED: WRITE 0x064, rc=%d\n", rc);
        goto test_end;
    }

    // Immediate readback
    rc = iopll_read_reg(REG_FREQ_SELECT, &reg64_after);
    if (rc != 0) {
        printf("FAILED: immediate READ 0x064, rc=%d\n", rc);
        goto test_end;
    }

    printf("0x064 immediate readback = 0x%08lx\n",
           (unsigned long)reg64_after);

    // --------------------------------------------------------
    // 5. Reset pulse: 0x80 bit[2]
    // --------------------------------------------------------
    printf("\n[5] Reset pulse: 0x080 bit[2]\n");

    rc = iopll_read_reg(REG_PLL_RESET, &reg80);
    if (rc != 0) {
        printf("FAILED: READ 0x080, rc=%d\n", rc);
        goto test_end;
    }

    printf("0x080 old = 0x%08lx\n",
           (unsigned long)reg80);

    rc = iopll_write_reg(
        REG_PLL_RESET,
        reg80 | PLL_RESET_MASK
    );
    if (rc != 0) {
        printf("FAILED: assert reset, rc=%d\n", rc);
        goto test_end;
    }

    for (volatile uint32_t i = 0; i < 1000; i++) {
        __asm__ volatile ("nop");
    }

    rc = iopll_write_reg(
        REG_PLL_RESET,
        reg80 & ~PLL_RESET_MASK
    );
    if (rc != 0) {
        printf("FAILED: deassert reset, rc=%d\n", rc);
        goto test_end;
    }

    printf("Reset pulse completed.\n");

    // --------------------------------------------------------
    // 6. Enable recalibration
    // --------------------------------------------------------
    printf("\n[6] Enable recalibration: 0x048 bit[14] = 1\n");

    rc = iopll_read_reg(REG_RECAL_ENABLE, &reg48);
    if (rc != 0) {
        printf("FAILED: READ 0x048, rc=%d\n", rc);
        goto test_end;
    }

    printf("0x048 old = 0x%08lx\n",
           (unsigned long)reg48);

    rc = iopll_write_reg(
        REG_RECAL_ENABLE,
        reg48 | RECAL_ENABLE_MASK
    );
    if (rc != 0) {
        printf("FAILED: WRITE 0x048, rc=%d\n", rc);
        goto test_end;
    }

    // --------------------------------------------------------
    // 7. Request recalibration
    // --------------------------------------------------------
    printf("\n[7] Request recalibration: 0x088 bit[11] = 1\n");

    rc = iopll_read_reg(REG_RECAL_REQUEST, &reg88);
    if (rc != 0) {
        printf("FAILED: READ 0x088, rc=%d\n", rc);
        goto test_end;
    }

    printf("0x088 old = 0x%08lx\n",
           (unsigned long)reg88);

    rc = iopll_write_reg(
        REG_RECAL_REQUEST,
        reg88 | RECAL_REQUEST_MASK
    );
    if (rc != 0) {
        printf("FAILED: WRITE 0x088, rc=%d\n", rc);
        goto test_end;
    }

    // --------------------------------------------------------
    // 8. Wait locked = 1
    // --------------------------------------------------------
    printf("\n[8] Wait locked = 1\n");

    rc = wait_until_locked();
    if (rc != 0) {
        goto test_end;
    }

    printf("PLL locked = 1\n");

    // --------------------------------------------------------
    // 9. Clear recalibration enable
    // --------------------------------------------------------
    printf("\n[9] Clear recalibration enable: 0x048 bit[14] = 0\n");

    rc = iopll_write_reg(
        REG_RECAL_ENABLE,
        reg48 & ~RECAL_ENABLE_MASK
    );
    if (rc != 0) {
        printf("FAILED: clear 0x048 bit[14], rc=%d\n", rc);
        goto test_end;
    }

    // --------------------------------------------------------
    // 10. Final readback
    // --------------------------------------------------------
    printf("\n[10] Final REG 0x064 readback\n");

    rc = iopll_read_reg(REG_FREQ_SELECT, &reg64_after);
    if (rc != 0) {
        printf("FAILED: final READ 0x064, rc=%d\n", rc);
        goto test_end;
    }

    printf("0x064 old    = 0x%08lx\n",
           (unsigned long)reg64_old);
    printf("0x064 target = 0x%08lx\n",
           (unsigned long)reg64_new);
    printf("0x064 after  = 0x%08lx\n",
           (unsigned long)reg64_after);

    status = IORD_32DIRECT(
        IOPLL_BASE,
        IOPLL_REG_STATUS
    );

    printf("Final STATUS = 0x%08lx\n",
           (unsigned long)status);

    printf("Final PLL locked = %s\n",
           (status & STATUS_PLL_LOCKED) ? "YES" : "NO");

    printf("\n========================================\n");

    if (reg64_after == reg64_new) {
        printf(" REG 0x064 RMW PASS\n");
        printf(" Expected runtime target: about 50 MHz / 20 ns\n");
        printf(" Measure GPIO_D[0] now.\n");
    } else {
        printf(" WARNING: REG 0x064 READBACK MISMATCH\n");
    }

    printf("========================================\n");

test_end:
    printf("\nTest complete.\n");

    while (1) {
    }

    return 0;
}

