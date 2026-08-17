module nios_iopll_bridge (
    input  logic        clk,
    input  logic        rst_n,

    // ============================================================
    // Avalon-MM Slave
    // Address is WORD address:
    //   0 = 0x00 CONTROL
    //   1 = 0x04 ADDRESS
    //   2 = 0x08 WDATA
    //   3 = 0x0C RDATA
    //   4 = 0x10 STATUS
    // ============================================================
    input  logic [2:0]  avs_address,
    input  logic        avs_read,
    input  logic        avs_write,
    input  logic [31:0] avs_writedata,
    output logic [31:0] avs_readdata,
    output logic        avs_waitrequest,

    // ============================================================
    // Command interface to hvio_master
    // ============================================================
    output logic        cmd_start,
    output logic        cmd_write,
    output logic [8:0]  cmd_address,
    output logic [31:0] cmd_writedata,

    input  logic [31:0] cmd_readdata,
    input  logic        cmd_busy,
    input  logic        cmd_done,
    input  logic        cmd_error,

    // IOPLL lock input and diagnostic-only external reset control
    input  logic        pll_locked_async,
    output logic        diagnostic_software_reset
);



    /*============================================================
    // Register map
    //
    // Byte offset:
    //
    // 0x00 CONTROL
    //      bit 0  START
    //      bit 1  WRITE
    //      bit 8  CLEAR_DONE
    //      bit 9  CLEAR_ERROR
    //      bit 10 CLEAR_REJECTED
    //
    // 0x04 ADDRESS
    //      bit [8:0] IOPLL register address
    //
    // 0x08 WDATA
    //      bit [31:0] write data
    //
    // 0x0C RDATA
    //      bit [31:0] last read data
    //
    // 0x10 STATUS
    //      bit 0 BUSY
    //      bit 1 DONE
    //      bit 2 ERROR
    //      bit 3 PLL_LOCKED
    //      bit 4 REJECTED
    //
    // 0x14 DIAG_IOPLL_RST (diagnostic use only)
    //      bit 0  software-controlled target_iopll.rst
    // ============================================================
	 */

    localparam logic [2:0] REG_CONTROL = 3'd0;
    localparam logic [2:0] REG_ADDRESS = 3'd1;
    localparam logic [2:0] REG_WDATA   = 3'd2;
    localparam logic [2:0] REG_RDATA   = 3'd3;
    localparam logic [2:0] REG_STATUS  = 3'd4;
    localparam logic [2:0] REG_DIAG_IOPLL_RST = 3'd5;

    logic [8:0]  address_reg;
    logic [31:0] wdata_reg;
    logic [31:0] rdata_reg;

    logic done_sticky;
    logic error_sticky;
    logic rejected_sticky;

    logic pll_locked_meta;
    logic pll_locked_sync;

    // ============================================================
    // Avalon interface never stalls the CPU.
    //
    // A START command received while cmd_busy=1 is rejected instead
    // of holding waitrequest for the whole IOPLL transaction.
    // ============================================================

    assign avs_waitrequest = 1'b0;

    // ============================================================
    // Synchronize IOPLL locked into bridge clock domain
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pll_locked_meta <= 1'b0;
            pll_locked_sync <= 1'b0;
        end
        else begin
            pll_locked_meta <= pll_locked_async;
            pll_locked_sync <= pll_locked_meta;
        end
    end

    // ============================================================
    // Main register / command logic
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            address_reg      <= 9'd0;
            wdata_reg        <= 32'd0;
            rdata_reg        <= 32'd0;

            cmd_start        <= 1'b0;
            cmd_write        <= 1'b0;
            cmd_address      <= 9'd0;
            cmd_writedata    <= 32'd0;

            done_sticky      <= 1'b0;
            error_sticky     <= 1'b0;
            rejected_sticky  <= 1'b0;
            diagnostic_software_reset <= 1'b0;
        end
        else begin

            // cmd_start must only be one clock cycle.
            cmd_start <= 1'b0;

            // ----------------------------------------------------
            // Responses from HVIO master
            // ----------------------------------------------------

            if (cmd_done) begin
                done_sticky <= 1'b1;
                rdata_reg   <= cmd_readdata;
            end

            if (cmd_error) begin
                error_sticky <= 1'b1;
            end

            // ----------------------------------------------------
            // Avalon writes
            // ----------------------------------------------------

            if (avs_write) begin
                case (avs_address)

                    // --------------------------------------------
                    // CONTROL
                    // --------------------------------------------
                    REG_CONTROL: begin

                        // Clear sticky flags
                        if (avs_writedata[8])
                            done_sticky <= 1'b0;

                        if (avs_writedata[9])
                            error_sticky <= 1'b0;

                        if (avs_writedata[10])
                            rejected_sticky <= 1'b0;

                        // START
                        if (avs_writedata[0]) begin
                            if (!cmd_busy) begin

                                // Snapshot command parameters
                                cmd_write     <= avs_writedata[1];
                                cmd_address   <= address_reg;
                                cmd_writedata <= wdata_reg;

                                // One-cycle command pulse
                                cmd_start <= 1'b1;
                            end
                            else begin
                                // Do not queue commands.
                                rejected_sticky <= 1'b1;
                            end
                        end
                    end

                    // --------------------------------------------
                    // ADDRESS
                    // --------------------------------------------
                    REG_ADDRESS: begin
                        address_reg <= avs_writedata[8:0];
                    end

                    // --------------------------------------------
                    // WDATA
                    // --------------------------------------------
                    REG_WDATA: begin
                        wdata_reg <= avs_writedata;
                    end

                    REG_DIAG_IOPLL_RST: begin
                        diagnostic_software_reset <= avs_writedata[0];
                    end

                    default: begin
                    end

                endcase
            end
        end
    end

    // ============================================================
    // Avalon reads
    // ============================================================

    always_comb begin
        avs_readdata = 32'd0;

        if (avs_read) begin
            case (avs_address)

                REG_CONTROL: begin
                    avs_readdata = 32'd0;
                end

                REG_ADDRESS: begin
                    avs_readdata = {23'd0, address_reg};
                end

                REG_WDATA: begin
                    avs_readdata = wdata_reg;
                end

                REG_RDATA: begin
                    avs_readdata = rdata_reg;
                end

                REG_STATUS: begin
                    avs_readdata[0] = cmd_busy;
                    avs_readdata[1] = done_sticky;
                    avs_readdata[2] = error_sticky;
                    avs_readdata[3] = pll_locked_sync;
                    avs_readdata[4] = rejected_sticky;
                end

                REG_DIAG_IOPLL_RST: begin
                    avs_readdata[0] = diagnostic_software_reset;
                end

                default: begin
                    avs_readdata = 32'd0;
                end

            endcase
        end
    end

endmodule
