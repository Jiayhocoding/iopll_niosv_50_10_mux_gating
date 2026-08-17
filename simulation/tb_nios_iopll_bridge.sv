`timescale 1ns/1ps

module tb_nios_iopll_bridge;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    always #10 clk = ~clk;  // 50 MHz

    // Avalon-MM
    logic [2:0]  avs_address;
    logic        avs_read;
    logic        avs_write;
    logic [31:0] avs_writedata;
    logic [31:0] avs_readdata;
    logic        avs_waitrequest;

    // Command interface
    logic        cmd_start;
    logic        cmd_write;
    logic [8:0]  cmd_address;
    logic [31:0] cmd_writedata;

    logic [31:0] cmd_readdata;
    logic        cmd_busy;
    logic        cmd_done;
    logic        cmd_error;

    logic pll_locked_async;

    nios_iopll_bridge dut (
        .clk(clk),
        .rst_n(rst_n),

        .avs_address(avs_address),
        .avs_read(avs_read),
        .avs_write(avs_write),
        .avs_writedata(avs_writedata),
        .avs_readdata(avs_readdata),
        .avs_waitrequest(avs_waitrequest),

        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_address(cmd_address),
        .cmd_writedata(cmd_writedata),

        .cmd_readdata(cmd_readdata),
        .cmd_busy(cmd_busy),
        .cmd_done(cmd_done),
        .cmd_error(cmd_error),

        .pll_locked_async(pll_locked_async)
    );

    task automatic avalon_write(
        input logic [2:0] address,
        input logic [31:0] data
    );
    begin
        @(negedge clk);
        avs_address   = address;
        avs_writedata = data;
        avs_write     = 1'b1;

        @(negedge clk);
        avs_write     = 1'b0;
        avs_writedata = 32'd0;
    end
    endtask

    task automatic avalon_read(
        input  logic [2:0] address,
        output logic [31:0] data
    );
    begin
        @(negedge clk);
        avs_address = address;
        avs_read    = 1'b1;

        #1;
        data = avs_readdata;

        @(negedge clk);
        avs_read = 1'b0;
    end
    endtask

    logic [31:0] read_value;

    initial begin

        avs_address        = 3'd0;
        avs_read           = 1'b0;
        avs_write          = 1'b0;
        avs_writedata      = 32'd0;

        cmd_readdata       = 32'd0;
        cmd_busy           = 1'b0;
        cmd_done           = 1'b0;
        cmd_error          = 1'b0;

        pll_locked_async   = 1'b0;

        repeat (5)
            @(posedge clk);

        rst_n = 1'b1;

        repeat (3)
            @(posedge clk);

        // =====================================================
        // TEST 1: ADDRESS register
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 1: ADDRESS REGISTER");
        $display("========================================");

        avalon_write(3'd1, 32'h0000005C);
        avalon_read(3'd1, read_value);

        if (read_value[8:0] !== 9'h05C)
            $fatal(1,
                "ADDRESS REGISTER ERROR expected=05C actual=%03h",
                read_value[8:0]
            );

        $display("ADDRESS REGISTER PASSED");


        // =====================================================
        // TEST 2: WDATA register
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 2: WDATA REGISTER");
        $display("========================================");

        avalon_write(3'd2, 32'h12345678);
        avalon_read(3'd2, read_value);

        if (read_value !== 32'h12345678)
            $fatal(1,
                "WDATA ERROR expected=12345678 actual=%08h",
                read_value
            );

        $display("WDATA REGISTER PASSED");


        // =====================================================
        // TEST 3: START WRITE command
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 3: WRITE COMMAND");
        $display("========================================");

        // CONTROL:
        // bit0 = START
        // bit1 = WRITE
        avalon_write(3'd0, 32'h00000003);

        @(posedge clk);

        if (!cmd_start)
            $fatal(1, "cmd_start was not asserted");

        if (!cmd_write)
            $fatal(1, "cmd_write was not asserted");

        if (cmd_address !== 9'h05C)
            $fatal(1,
                "cmd_address error expected=05C actual=%03h",
                cmd_address
            );

        if (cmd_writedata !== 32'h12345678)
            $fatal(1,
                "cmd_writedata error expected=12345678 actual=%08h",
                cmd_writedata
            );

        $display("WRITE COMMAND PASSED");


        // =====================================================
        // TEST 4: DONE + RDATA
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 4: DONE + RDATA");
        $display("========================================");

        cmd_readdata = 32'hCAFEBABE;

        @(negedge clk);
        cmd_done = 1'b1;

        @(negedge clk);
        cmd_done = 1'b0;

        repeat (1)
            @(posedge clk);

        avalon_read(3'd3, read_value);

        if (read_value !== 32'hCAFEBABE)
            $fatal(1,
                "RDATA ERROR expected=CAFEBABE actual=%08h",
                read_value
            );

        avalon_read(3'd4, read_value);

        if (!read_value[1])
            $fatal(1, "DONE sticky bit was not set");

        $display("DONE + RDATA PASSED");


        // =====================================================
        // TEST 5: BUSY command rejection
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 5: BUSY REJECTION");
        $display("========================================");

        cmd_busy = 1'b1;

        avalon_write(3'd0, 32'h00000001);

        cmd_busy = 1'b0;

        avalon_read(3'd4, read_value);

        if (!read_value[4])
            $fatal(1, "REJECTED sticky bit was not set");

        $display("BUSY REJECTION PASSED");


        // =====================================================
        // TEST 6: PLL lock synchronizer
        // =====================================================

        $display("");
        $display("========================================");
        $display("TEST 6: PLL LOCK SYNC");
        $display("========================================");

        pll_locked_async = 1'b1;

        repeat (3)
            @(posedge clk);

        avalon_read(3'd4, read_value);

        if (!read_value[3])
            $fatal(1, "PLL_LOCKED status bit was not set");

        $display("PLL LOCK SYNC PASSED");


        // =====================================================
        // COMPLETE
        // =====================================================

        $display("");
        $display("========================================");
        $display("ALL NIOS IOPLL BRIDGE TESTS PASSED");
        $display("========================================");

        #100;
        $finish;

    end

endmodule
