`timescale 1ns/1ps

module tb_hvio_master;

    // ============================================================
    // Clock / Reset
    // ============================================================

    logic clk   = 1'b0;
    logic rst_n = 1'b0;

    always #10 clk = ~clk;   // 50 MHz = 20 ns period


    // ============================================================
    // Command interface
    // ============================================================

    logic        cmd_start;
    logic        cmd_write;
    logic [8:0]  cmd_address;
    logic [31:0] cmd_writedata;

    logic [31:0] cmd_readdata;
    logic        busy;
    logic        done;
    logic        error;


    // ============================================================
    // HVIO side
    // ============================================================

    logic [8:0] core_avl_address;
    logic       core_avl_read;
    logic [7:0] core_avl_readdata;

    logic       core_avl_write;
    logic [7:0] core_avl_writedata;


    // ============================================================
    // DUT
    // ============================================================

    hvio_master dut (
        .clk                (clk),
        .rst_n              (rst_n),

        .cmd_start          (cmd_start),
        .cmd_write          (cmd_write),
        .cmd_address        (cmd_address),
        .cmd_writedata      (cmd_writedata),

        .cmd_readdata       (cmd_readdata),
        .busy               (busy),
        .done               (done),
        .error              (error),

        .core_avl_address   (core_avl_address),
        .core_avl_read      (core_avl_read),
        .core_avl_readdata  (core_avl_readdata),

        .core_avl_write     (core_avl_write),
        .core_avl_writedata (core_avl_writedata)
    );


    // ============================================================
    // Test counters
    // ============================================================

    integer write_beat;
    integer read_beat;

    logic [7:0] expected_write [0:9];


    // ============================================================
    // Read data model
    //
    // HVIO read:
    //
    // beat 0..4 = invalid
    // beat 5    = header
    // beat 6    = D0 = 0x78
    // beat 7    = D1 = 0x56
    // beat 8    = D2 = 0x34
    // beat 9    = D3 = 0x12
    //
    // Expected final 32-bit value:
    //
    //      0x12345678
    //
    // ============================================================

    always @(negedge clk) begin
        if (!rst_n) begin
            read_beat          <= 0;
            core_avl_readdata  <= 8'h00;
        end
        else if (core_avl_read) begin

            case (read_beat)

                0: core_avl_readdata <= 8'hAA;
                1: core_avl_readdata <= 8'hBB;
                2: core_avl_readdata <= 8'hCC;
                3: core_avl_readdata <= 8'hDD;
                4: core_avl_readdata <= 8'hEE;

                5: core_avl_readdata <= 8'h00;

                6: core_avl_readdata <= 8'h78;
                7: core_avl_readdata <= 8'h56;
                8: core_avl_readdata <= 8'h34;
                9: core_avl_readdata <= 8'h12;

                default:
                    core_avl_readdata <= 8'h00;

            endcase

            read_beat <= read_beat + 1;
        end
        else begin
            core_avl_readdata <= 8'h00;
        end
    end


    // ============================================================
    // Write checker
    // ============================================================

    always @(negedge clk) begin
        if (!rst_n) begin
            write_beat <= 0;
        end
        else if (core_avl_write) begin

            if (write_beat > 9) begin
                $fatal(1,
                    "Too many write beats. beat=%0d",
                    write_beat
                );
            end

            if (core_avl_writedata !== expected_write[write_beat]) begin
                $fatal(1,
                    "WRITE DATA ERROR: beat=%0d expected=%02h actual=%02h",
                    write_beat,
                    expected_write[write_beat],
                    core_avl_writedata
                );
            end

            if (core_avl_address !== 9'h05C) begin
                $fatal(1,
                    "WRITE ADDRESS ERROR: expected=05C actual=%03h",
                    core_avl_address
                );
            end

            $display(
                "[WRITE] beat=%0d address=%03h data=%02h",
                write_beat,
                core_avl_address,
                core_avl_writedata
            );

            write_beat <= write_beat + 1;
        end
    end


    // ============================================================
    // Command helper
    // ============================================================

    task automatic issue_command(
        input logic        is_write,
        input logic [8:0]  address,
        input logic [31:0] data
    );
    begin

        @(negedge clk);

        cmd_write     = is_write;
        cmd_address   = address;
        cmd_writedata = data;
        cmd_start     = 1'b1;

        @(negedge clk);

        cmd_start = 1'b0;

    end
    endtask


    // ============================================================
    // Wait for done with timeout
    // ============================================================

    task automatic wait_for_done;
        integer timeout;
    begin

        timeout = 0;

        while (!done) begin
            @(posedge clk);

            timeout = timeout + 1;

            if (timeout > 30) begin
                $fatal(1, "TIMEOUT waiting for done");
            end
        end

    end
    endtask


    // ============================================================
    // Main test
    // ============================================================

    initial begin

        cmd_start          = 1'b0;
        cmd_write          = 1'b0;
        cmd_address        = 9'd0;
        cmd_writedata      = 32'd0;
        core_avl_readdata  = 8'h00;

        write_beat = 0;
        read_beat  = 0;


        // --------------------------------------------------------
        // Expected WRITE stream for 0x12345678
        // --------------------------------------------------------

        expected_write[0] = 8'h00;
        expected_write[1] = 8'h00;
        expected_write[2] = 8'h00;
        expected_write[3] = 8'h00;
        expected_write[4] = 8'h00;

        expected_write[5] = 8'h78;  // D0
        expected_write[6] = 8'h56;  // D1
        expected_write[7] = 8'h34;  // D2
        expected_write[8] = 8'h12;  // D3
        expected_write[9] = 8'h12;  // D3 repeat


        // ========================================================
        // RESET
        // ========================================================

        repeat (5)
            @(posedge clk);

        rst_n = 1'b1;

        repeat (2)
            @(posedge clk);


        // ========================================================
        // TEST 1: WRITE
        // ========================================================

        $display("");
        $display("========================================");
        $display("TEST 1: HVIO WRITE");
        $display("========================================");

        issue_command(
            1'b1,
            9'h05C,
            32'h12345678
        );

        if (!busy)
            $fatal(1, "busy did not assert after WRITE command");

        wait_for_done();

        @(negedge clk);

        if (write_beat != 10) begin
            $fatal(1,
                "WRITE beat count incorrect. expected=10 actual=%0d",
                write_beat
            );
        end

        if (error)
            $fatal(1, "Unexpected WRITE error");

        $display("WRITE TEST PASSED");


        // ========================================================
        // TEST 2: READ
        // ========================================================

        repeat (3)
            @(posedge clk);

        read_beat = 0;

        $display("");
        $display("========================================");
        $display("TEST 2: HVIO READ");
        $display("========================================");

        issue_command(
            1'b0,
            9'h05C,
            32'h00000000
        );

        if (!busy)
            $fatal(1, "busy did not assert after READ command");

        wait_for_done();

        @(negedge clk);


        if (read_beat != 10) begin
            $fatal(1,
                "READ beat count incorrect. expected=10 actual=%0d",
                read_beat
            );
        end


        if (cmd_readdata !== 32'h12345678) begin
            $fatal(1,
                "READ DATA ERROR: expected=12345678 actual=%08h",
                cmd_readdata
            );
        end


        if (core_avl_address !== 9'h05C) begin
            $fatal(1,
                "READ ADDRESS ERROR: expected=05C actual=%03h",
                core_avl_address
            );
        end


        if (error)
            $fatal(1, "Unexpected READ error");


        $display(
            "READ DATA = 0x%08h",
            cmd_readdata
        );

        $display("READ TEST PASSED");


        // ========================================================
        // COMPLETE
        // ========================================================

        $display("");
        $display("========================================");
        $display("ALL HVIO MASTER TESTS PASSED");
        $display("========================================");

        #100;

        $finish;

    end

endmodule
