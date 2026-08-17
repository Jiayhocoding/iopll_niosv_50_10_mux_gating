`timescale 1ns/1ps

// Focused diagnostic for the already-validated fixed-cycle HVIO writer.
// This test intentionally does not re-test reads, the bridge register map,
// or the PLL divider algorithm.
module tb_iopll_runtime_diag;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    always #10 clk = ~clk; // 50 MHz

    logic        cmd_start = 1'b0;
    logic        cmd_write = 1'b0;
    logic [8:0]  cmd_address = '0;
    logic [31:0] cmd_writedata = '0;
    logic [31:0] cmd_readdata;
    logic        busy, done, error;
    logic [8:0]  core_avl_address;
    logic        core_avl_read;
    logic [7:0]  core_avl_readdata = 8'h00;
    logic        core_avl_write;
    logic [7:0]  core_avl_writedata;

    time reset_assert_time;
    time reset_clear_time;
    integer pass_count = 0;

    hvio_master dut (
        .clk(clk), .rst_n(rst_n),
        .cmd_start(cmd_start), .cmd_write(cmd_write),
        .cmd_address(cmd_address), .cmd_writedata(cmd_writedata),
        .cmd_readdata(cmd_readdata), .busy(busy), .done(done), .error(error),
        .core_avl_address(core_avl_address), .core_avl_read(core_avl_read),
        .core_avl_readdata(core_avl_readdata),
        .core_avl_write(core_avl_write),
        .core_avl_writedata(core_avl_writedata)
    );

    task automatic check_write(
        input logic [8:0] address,
        input logic [31:0] data,
        input string test_name
    );
        logic [7:0] expected [0:9];
        integer beat;
        integer idle_cycle;
    begin
        expected[0] = 8'h00;
        expected[1] = 8'h00;
        expected[2] = 8'h00;
        expected[3] = 8'h00;
        expected[4] = 8'h00;
        expected[5] = data[7:0];
        expected[6] = data[15:8];
        expected[7] = data[23:16];
        expected[8] = data[31:24];
        expected[9] = data[31:24]; // mandatory D3 hold

        @(negedge clk);
        cmd_address   = address;
        cmd_writedata = data;
        cmd_write     = 1'b1;
        cmd_start     = 1'b1;
        @(negedge clk);
        cmd_start     = 1'b0;

        for (beat = 0; beat < 10; beat = beat + 1) begin
            assert (core_avl_write === 1'b1)
                else $fatal(1, "%s: write low at beat %0d", test_name, beat);
            assert (core_avl_address === address)
                else $fatal(1, "%s: address expected %03h actual %03h",
                            test_name, address, core_avl_address);
            assert (core_avl_writedata === expected[beat])
                else $fatal(1, "%s: beat %0d expected %02h actual %02h",
                            test_name, beat, expected[beat], core_avl_writedata);

            if ((address == 9'h080) && (beat == 5)) begin
                if (data[2]) reset_assert_time = $time;
                else         reset_clear_time  = $time;
            end
            @(negedge clk);
        end

        // cycle 10..14 must be idle: five complete cycles minimum.
        for (idle_cycle = 0; idle_cycle < 5; idle_cycle = idle_cycle + 1) begin
            assert (core_avl_write === 1'b0)
                else $fatal(1, "%s: idle cycle %0d still writing",
                            test_name, idle_cycle);
            @(negedge clk);
        end

        assert (done === 1'b1)
            else $fatal(1, "%s: done missing after five idle cycles", test_name);
        assert (error === 1'b0)
            else $fatal(1, "%s: unexpected error", test_name);

        pass_count = pass_count + 1;
        $display("PASS: %s addr=0x%03h data=0x%08h", test_name, address, data);
    end
    endtask

    initial begin
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        check_write(9'h080, 32'h00000004, "RESET ASSERT");
        check_write(9'h080, 32'h00000000, "RESET CLEAR");

        assert (reset_clear_time > reset_assert_time)
            else $fatal(1, "reset clear did not follow reset assert");
        assert ((reset_clear_time - reset_assert_time) >= 10ns)
            else $fatal(1, "reset interval %0t is less than 10 ns",
                        reset_clear_time - reset_assert_time);
        pass_count = pass_count + 1;
        $display("PASS: RESET INTERVAL actual=%0t expected>=10 ns",
                 reset_clear_time - reset_assert_time);

        check_write(9'h048, 32'h00004000, "RECAL ENABLE");
        check_write(9'h088, 32'h00000800, "RECAL REQUEST");

        assert (pass_count == 5)
            else $fatal(1, "pass count expected 5 actual %0d", pass_count);
        $display("ALL IOPLL RUNTIME DIAGNOSTIC RTL TESTS PASSED (%0d/5)",
                 pass_count);
        $finish;
    end

endmodule
