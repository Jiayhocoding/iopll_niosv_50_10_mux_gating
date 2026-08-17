`timescale 1ns/1ps

module tb_c0_mapping_probe;

    localparam logic [8:0]  C0_ADDRESS  = 9'h05C;
    localparam logic [31:0] C0_BASELINE = 32'h00800D01;
    localparam logic [31:0] C0_TARGET   = 32'h10000C20;
    localparam logic [31:0] C0_ODD_MASK       = 32'h80000000;
    localparam logic [31:0] C0_LOW_MASK       = 32'h7F800000;
    localparam logic [31:0] C0_BYPASS_MASK    = 32'h00000100;
    localparam logic [31:0] C0_HIGH_MASK      = 32'h000000FF;
    localparam logic [31:0] C0_MODIFIED_MASK  =
        C0_ODD_MASK | C0_LOW_MASK | C0_BYPASS_MASK | C0_HIGH_MASK;
    localparam logic [31:0] C0_PRESERVED_MASK = ~C0_MODIFIED_MASK;
    localparam logic [31:0] CLEAR_STICKY = 32'h00000700;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #10 clk = ~clk;

    logic [2:0] avs_address;
    logic avs_read, avs_write;
    logic [31:0] avs_writedata, avs_readdata;
    logic avs_waitrequest;
    logic cmd_start, cmd_write;
    logic [8:0] cmd_address;
    logic [31:0] cmd_writedata, cmd_readdata;
    logic cmd_busy, cmd_done, cmd_error;
    logic [8:0] core_avl_address;
    logic core_avl_read, core_avl_write;
    logic [7:0] core_avl_readdata, core_avl_writedata;

    logic [31:0] mock_c0 = C0_BASELINE;
    logic [31:0] write_capture = 32'd0;
    integer write_beat = 0;
    integer read_beat = 0;
    integer sticky_clear_checks = 0;
    integer failures = 0;

    logic [31:0] calculated_target;
    logic [31:0] initial_readback;
    logic [31:0] final_readback;
    logic [7:0] actual_write_bytes [0:9];
    integer actual_write_beats = 0;
    integer actual_preamble_zeros = 0;
    integer actual_d3_hold_cycles = 0;
    integer actual_idle_cycles = 0;
    logic saw_error = 1'b0;
    logic saw_rejected = 1'b0;

    nios_iopll_bridge u_bridge (
        .clk(clk), .rst_n(rst_n),
        .avs_address(avs_address), .avs_read(avs_read),
        .avs_write(avs_write), .avs_writedata(avs_writedata),
        .avs_readdata(avs_readdata), .avs_waitrequest(avs_waitrequest),
        .cmd_start(cmd_start), .cmd_write(cmd_write),
        .cmd_address(cmd_address), .cmd_writedata(cmd_writedata),
        .cmd_readdata(cmd_readdata), .cmd_busy(cmd_busy),
        .cmd_done(cmd_done), .cmd_error(cmd_error),
        .pll_locked_async(1'b0)
    );

    hvio_master u_master (
        .clk(clk), .rst_n(rst_n),
        .cmd_start(cmd_start), .cmd_write(cmd_write),
        .cmd_address(cmd_address), .cmd_writedata(cmd_writedata),
        .cmd_readdata(cmd_readdata), .busy(cmd_busy),
        .done(cmd_done), .error(cmd_error),
        .core_avl_address(core_avl_address),
        .core_avl_read(core_avl_read),
        .core_avl_readdata(core_avl_readdata),
        .core_avl_write(core_avl_write),
        .core_avl_writedata(core_avl_writedata)
    );

    task automatic check(input logic condition, input string message);
    begin
        assert (condition) else begin
            failures = failures + 1;
            $error("%s", message);
        end
    end
    endtask

    task automatic avalon_write(input logic [2:0] address,
                                input logic [31:0] data);
    begin
        @(negedge clk);
        avs_address = address;
        avs_writedata = data;
        avs_write = 1'b1;
        @(negedge clk);
        avs_write = 1'b0;
        avs_writedata = 32'd0;
    end
    endtask

    task automatic avalon_read(input logic [2:0] address,
                               output logic [31:0] data);
    begin
        @(negedge clk);
        avs_address = address;
        avs_read = 1'b1;
        #1 data = avs_readdata;
        @(negedge clk);
        avs_read = 1'b0;
    end
    endtask

    task automatic prepare_command;
        logic [31:0] status;
        integer timeout;
    begin
        timeout = 0;
        do begin
            avalon_read(3'd4, status);
            timeout = timeout + 1;
            check(timeout < 100, "BUSY timeout before command");
        end while (status[0] && timeout < 100);

        avalon_write(3'd0, CLEAR_STICKY);
        avalon_read(3'd4, status);
        check(status[4:1] == 4'b0000,
              "sticky DONE/ERROR/REJECTED did not clear before command");
        sticky_clear_checks = sticky_clear_checks + 1;
    end
    endtask

    task automatic wait_new_done(output logic [31:0] completion_status);
        logic [31:0] status;
        integer timeout;
    begin
        timeout = 0;
        status = 32'd0;
        while (!status[1] && timeout < 100) begin
            avalon_read(3'd4, status);
            if (status[2]) saw_error = 1'b1;
            if (status[4]) saw_rejected = 1'b1;
            timeout = timeout + 1;
        end
        check(status[1], "DONE timeout");
        while (status[0] && timeout < 120) begin
            avalon_read(3'd4, status);
            timeout = timeout + 1;
        end
        check(!status[0], "BUSY remained set after DONE");
        if (status[2]) saw_error = 1'b1;
        if (status[4]) saw_rejected = 1'b1;
        completion_status = status;
    end
    endtask

    task automatic bridge_read_c0(output logic [31:0] value);
        logic [31:0] status;
    begin
        prepare_command();
        avalon_write(3'd1, {23'd0, C0_ADDRESS});
        avalon_write(3'd0, 32'h00000001);
        wait_new_done(status);
        avalon_read(3'd3, value);
    end
    endtask

    task automatic bridge_write_c0(input logic [31:0] value);
        logic [31:0] status;
        integer beat;
        integer idle;
        logic [7:0] expected [0:9];
    begin
        expected[0] = 8'h00; expected[1] = 8'h00;
        expected[2] = 8'h00; expected[3] = 8'h00;
        expected[4] = 8'h00; expected[5] = value[7:0];
        expected[6] = value[15:8]; expected[7] = value[23:16];
        expected[8] = value[31:24]; expected[9] = value[31:24];

        prepare_command();
        avalon_write(3'd1, {23'd0, C0_ADDRESS});
        avalon_write(3'd2, value);
        avalon_write(3'd0, 32'h00000003);

        while (core_avl_write !== 1'b1) @(negedge clk);
        for (beat = 0; beat < 10; beat = beat + 1) begin
            check(core_avl_write === 1'b1, "core_avl_write deasserted early");
            check(core_avl_address === C0_ADDRESS,
                  "core_avl_address changed during write");
            check(core_avl_writedata === expected[beat],
                  "fixed-cycle write byte mismatch");
            actual_write_bytes[beat] = core_avl_writedata;
            actual_write_beats = actual_write_beats + 1;
            if (beat < 5 && core_avl_writedata == 8'h00)
                actual_preamble_zeros = actual_preamble_zeros + 1;
            if (beat == 9 && core_avl_writedata == value[31:24])
                actual_d3_hold_cycles = actual_d3_hold_cycles + 1;
            @(negedge clk);
        end

        for (idle = 0; idle < 5; idle = idle + 1) begin
            check(core_avl_write === 1'b0, "write asserted during idle window");
            actual_idle_cycles = actual_idle_cycles + 1;
            @(negedge clk);
        end
        wait_new_done(status);
    end
    endtask

    // Mock C0 register accepts the exact byte stream driven by hvio_master.
    always @(negedge clk) begin
        if (!rst_n) begin
            mock_c0 = C0_BASELINE;
            write_capture = 32'd0;
            write_beat = 0;
        end else if (core_avl_write) begin
            if (write_beat == 5) write_capture[7:0]   = core_avl_writedata;
            if (write_beat == 6) write_capture[15:8]  = core_avl_writedata;
            if (write_beat == 7) write_capture[23:16] = core_avl_writedata;
            if (write_beat == 8) write_capture[31:24] = core_avl_writedata;
            if (write_beat == 9) begin
                check(core_avl_writedata == write_capture[31:24],
                      "D3 hold byte differs from D3");
                if (core_avl_address == C0_ADDRESS)
                    mock_c0 = write_capture;
            end
            write_beat = write_beat + 1;
        end else begin
            write_beat = 0;
        end
    end

    // Mock fixed-cycle read response: five invalid cycles, header, D0..D3.
    always @(negedge clk) begin
        if (!rst_n) begin
            read_beat = 0;
            core_avl_readdata <= 8'h00;
        end else if (core_avl_read) begin
            case (read_beat)
                0,1,2,3,4: core_avl_readdata <= 8'hA5;
                5: core_avl_readdata <= 8'h00;
                6: core_avl_readdata <= mock_c0[7:0];
                7: core_avl_readdata <= mock_c0[15:8];
                8: core_avl_readdata <= mock_c0[23:16];
                9: core_avl_readdata <= mock_c0[31:24];
                default: core_avl_readdata <= 8'h00;
            endcase
            read_beat = read_beat + 1;
        end else begin
            read_beat = 0;
            core_avl_readdata <= 8'h00;
        end
    end

    task automatic print_result(input string test_name,
                                input string expected,
                                input logic [31:0] actual,
                                input logic passed);
    begin
        $display("%-24s | %-18s | 0x%08h | %s", test_name, expected,
                 actual, passed ? "PASS" : "FAIL");
    end
    endtask

    initial begin
        avs_address = 3'd0;
        avs_read = 1'b0;
        avs_write = 1'b0;
        avs_writedata = 32'd0;

        // Independently encode low=32 at [30:23], high=32 at [7:0],
        // clear odd/bypass, and preserve every other baseline bit.
        calculated_target = (C0_BASELINE & C0_PRESERVED_MASK) |
                            (32'd32 << 23) | 32'd32;
        check(calculated_target == C0_TARGET,
              "independent C0 RMW result is not 0x10000C20");

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);

        bridge_read_c0(initial_readback);
        check(initial_readback == C0_BASELINE, "initial mock C0 read mismatch");
        bridge_write_c0(calculated_target);
        bridge_read_c0(final_readback);

        check(mock_c0 == C0_TARGET, "mock C0 write mismatch");
        check(final_readback == C0_TARGET, "32-bit C0 readback mismatch");
        check(final_readback[7:0] == 8'd32, "high_count decode mismatch");
        check(final_readback[30:23] == 8'd32, "low_count decode mismatch");
        check(final_readback[8] == 1'b0, "bypass decode mismatch");
        check(final_readback[31] == 1'b0, "odd decode mismatch");
        check((final_readback & C0_PRESERVED_MASK) ==
              (C0_BASELINE & C0_PRESERVED_MASK),
              "phase/preset/reserved fields changed");
        check(sticky_clear_checks == 3,
              "sticky flags were not cleared before every command");

        $display("\nTEST                     | EXPECTED           | ACTUAL     | PASS/FAIL");
        $display("-------------------------+--------------------+------------+----------");
        print_result("RMW calculation", "0x10000C20", calculated_target,
                     calculated_target == C0_TARGET);
        print_result("address", "0x0000005C", {23'd0, C0_ADDRESS},
                     C0_ADDRESS == 9'h05C);
        print_result("byte order", "20 0C 00 10", {actual_write_bytes[8],
                     actual_write_bytes[7], actual_write_bytes[6],
                     actual_write_bytes[5]},
                     actual_write_bytes[5] == 8'h20 &&
                     actual_write_bytes[6] == 8'h0C &&
                     actual_write_bytes[7] == 8'h00 &&
                     actual_write_bytes[8] == 8'h10);
        print_result("preamble timing", "5 zero cycles", actual_preamble_zeros,
                     actual_write_beats == 10 &&
                     actual_write_bytes[0] == 0 && actual_write_bytes[1] == 0 &&
                     actual_write_bytes[2] == 0 && actual_write_bytes[3] == 0 &&
                     actual_write_bytes[4] == 0);
        print_result("D3 hold timing", "1 extra cycle", actual_d3_hold_cycles,
                     actual_d3_hold_cycles == 1 &&
                     actual_write_bytes[9] == 8'h10);
        print_result("idle timing", ">=5 cycles", actual_idle_cycles,
                     actual_idle_cycles >= 5);
        print_result("mock register write", "0x10000C20", mock_c0,
                     mock_c0 == C0_TARGET);
        print_result("32-bit readback", "0x10000C20", final_readback,
                     final_readback == C0_TARGET);
        print_result("high_count", "32", final_readback[7:0],
                     final_readback[7:0] == 8'd32);
        print_result("low_count", "32", final_readback[30:23],
                     final_readback[30:23] == 8'd32);
        print_result("bypass", "0", final_readback[8], !final_readback[8]);
        print_result("odd", "0", final_readback[31], !final_readback[31]);
        print_result("preserved fields", "0x00000C00",
                     final_readback & C0_PRESERVED_MASK,
                     (final_readback & C0_PRESERVED_MASK) ==
                     (C0_BASELINE & C0_PRESERVED_MASK));
        print_result("sticky clear/new DONE", "3 commands", sticky_clear_checks,
                     sticky_clear_checks == 3);
        print_result("no ERROR", "0", saw_error, !saw_error);
        print_result("no REJECTED", "0", saw_rejected, !saw_rejected);

        if (failures != 0)
            $fatal(1, "C0 mapping simulation failed with %0d errors", failures);
        $display("\nC0 MAPPING SIMULATION PASSED (representation/transaction only)");
        $finish;
    end

endmodule
