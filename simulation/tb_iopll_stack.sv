`timescale 1ns/1ps

module tb_iopll_stack;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    always #10 clk = ~clk; // 50 MHz

    // ============================================================
    // Avalon-MM side
    // ============================================================

    logic [2:0]  avs_address;
    logic        avs_read;
    logic        avs_write;
    logic [31:0] avs_writedata;
    logic [31:0] avs_readdata;
    logic        avs_waitrequest;

    // ============================================================
    // Bridge <-> master command interface
    // ============================================================

    logic        cmd_start;
    logic        cmd_write;
    logic [8:0]  cmd_address;
    logic [31:0] cmd_writedata;

    logic [31:0] cmd_readdata;
    logic        cmd_busy;
    logic        cmd_done;
    logic        cmd_error;

    // ============================================================
    // Fake IOPLL interface
    // ============================================================

    logic [8:0] core_avl_address;
    logic       core_avl_read;
    logic [7:0] core_avl_readdata;

    logic       core_avl_write;
    logic [7:0] core_avl_writedata;

    logic pll_locked_async;

    // ============================================================
    // DUT 1: Nios bridge
    // ============================================================

    nios_iopll_bridge u_bridge (
        .clk                (clk),
        .rst_n              (rst_n),

        .avs_address        (avs_address),
        .avs_read           (avs_read),
        .avs_write          (avs_write),
        .avs_writedata      (avs_writedata),
        .avs_readdata       (avs_readdata),
        .avs_waitrequest    (avs_waitrequest),

        .cmd_start          (cmd_start),
        .cmd_write          (cmd_write),
        .cmd_address        (cmd_address),
        .cmd_writedata      (cmd_writedata),

        .cmd_readdata       (cmd_readdata),
        .cmd_busy           (cmd_busy),
        .cmd_done           (cmd_done),
        .cmd_error          (cmd_error),

        .pll_locked_async   (pll_locked_async)
    );

    // ============================================================
    // DUT 2: HVIO master
    // ============================================================

    hvio_master u_master (
        .clk                (clk),
        .rst_n              (rst_n),

        .cmd_start          (cmd_start),
        .cmd_write          (cmd_write),
        .cmd_address        (cmd_address),
        .cmd_writedata      (cmd_writedata),

        .cmd_readdata       (cmd_readdata),
        .busy               (cmd_busy),
        .done               (cmd_done),
        .error              (cmd_error),

        .core_avl_address   (core_avl_address),
        .core_avl_read      (core_avl_read),
        .core_avl_readdata  (core_avl_readdata),

        .core_avl_write     (core_avl_write),
        .core_avl_writedata (core_avl_writedata)
    );

    // ============================================================
    // Avalon helper tasks
    // ============================================================

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


    // ============================================================
    // Fake IOPLL READ response
    //
    // We pretend register 0x5C contains:
    //
    //      0x89ABCDEF
    //
    // Manual fixed-cycle response:
    //
    // first 5 = invalid
    // then     = 00 header
    // D0       = EF
    // D1       = CD
    // D2       = AB
    // D3       = 89
    // ============================================================

    integer read_beat;

    always @(negedge clk) begin

        if (!rst_n) begin
            read_beat         <= 0;
            core_avl_readdata <= 8'h00;
        end
        else if (core_avl_read) begin

            case (read_beat)

                0: core_avl_readdata <= 8'h11;
                1: core_avl_readdata <= 8'h22;
                2: core_avl_readdata <= 8'h33;
                3: core_avl_readdata <= 8'h44;
                4: core_avl_readdata <= 8'h55;

                5: core_avl_readdata <= 8'h00;

                6: core_avl_readdata <= 8'hEF;
                7: core_avl_readdata <= 8'hCD;
                8: core_avl_readdata <= 8'hAB;
                9: core_avl_readdata <= 8'h89;

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
    // WRITE checker
    // ============================================================

    integer write_beat;

    logic [7:0] expected_write [0:9];

    always @(negedge clk) begin

        if (!rst_n) begin
            write_beat <= 0;
        end
        else if (core_avl_write) begin

            if (core_avl_address !== 9'h05C)
                $fatal(1,
                    "WRITE ADDRESS ERROR expected=05C actual=%03h",
                    core_avl_address
                );

            if (core_avl_writedata !== expected_write[write_beat])
                $fatal(1,
                    "WRITE BYTE ERROR beat=%0d expected=%02h actual=%02h",
                    write_beat,
                    expected_write[write_beat],
                    core_avl_writedata
                );

            $display(
                "[STACK WRITE] beat=%0d addr=%03h data=%02h",
                write_beat,
                core_avl_address,
                core_avl_writedata
            );

            write_beat <= write_beat + 1;
        end
    end

	task automatic wait_done;
		 logic [31:0] status;
		 integer timeout;
	begin

		 timeout = 0;
		 status  = 32'd0;

		 while (!status[1]) begin

			  avalon_read(3'd4, status);

			  if (status[2])
					$fatal(1, "STATUS.ERROR asserted");

			  timeout = timeout + 1;

			  if (timeout > 30)
					$fatal(1, "TIMEOUT waiting for DONE");

		 end

	end
	endtask

   

    logic [31:0] value;


    // ============================================================
    // Main
    // ============================================================

    initial begin

        avs_address       = 3'd0;
        avs_read          = 1'b0;
        avs_write         = 1'b0;
        avs_writedata     = 32'd0;

        pll_locked_async  = 1'b1;

        read_beat         = 0;
        write_beat        = 0;

        // WRITE expected stream for 0x12345678

        expected_write[0] = 8'h00;
        expected_write[1] = 8'h00;
        expected_write[2] = 8'h00;
        expected_write[3] = 8'h00;
        expected_write[4] = 8'h00;

        expected_write[5] = 8'h78;
        expected_write[6] = 8'h56;
        expected_write[7] = 8'h34;
        expected_write[8] = 8'h12;
        expected_write[9] = 8'h12;


        // ========================================================
        // Reset
        // ========================================================

        repeat (5)
            @(posedge clk);

        rst_n = 1'b1;

        repeat (3)
            @(posedge clk);


        // ========================================================
        // TEST 1:
        // CPU-style WRITE all the way through bridge + master
        // ========================================================

        $display("");
        $display("========================================");
        $display("TEST 1: FULL STACK WRITE");
        $display("========================================");

        // ADDRESS = 0x5C
        avalon_write(3'd1, 32'h0000005C);

        // WDATA = 0x12345678
        avalon_write(3'd2, 32'h12345678);

        // CONTROL:
        // START=1, WRITE=1
        avalon_write(3'd0, 32'h00000003);

        wait_done();

        if (write_beat != 10)
            $fatal(1,
                "WRITE beat count incorrect expected=10 actual=%0d",
                write_beat
            );

        $display("FULL STACK WRITE PASSED");


        // Clear DONE
        avalon_write(3'd0, 32'h00000100);


        // ========================================================
        // TEST 2:
        // CPU-style READ all the way through bridge + master
        // ========================================================

        $display("");
        $display("========================================");
        $display("TEST 2: FULL STACK READ");
        $display("========================================");

        read_beat = 0;

        // ADDRESS = 0x5C
        avalon_write(3'd1, 32'h0000005C);

        // CONTROL:
        // START=1
        // WRITE=0
        avalon_write(3'd0, 32'h00000001);

        wait_done();

        // Read RDATA register
        avalon_read(3'd3, value);

        if (value !== 32'h89ABCDEF)
            $fatal(1,
                "FULL STACK READ ERROR expected=89ABCDEF actual=%08h",
                value
            );

        $display(
            "RDATA = 0x%08h",
            value
        );

        $display("FULL STACK READ PASSED");


        // ========================================================
        // TEST 3: STATUS PLL_LOCKED
        // ========================================================

        $display("");
        $display("========================================");
        $display("TEST 3: STATUS");
        $display("========================================");

        repeat (3)
            @(posedge clk);

        avalon_read(3'd4, value);

        if (!value[3])
            $fatal(1, "PLL_LOCKED not visible through STATUS");

        $display(
            "STATUS = 0x%08h",
            value
        );

        $display("STATUS TEST PASSED");


        // ========================================================
        // Complete
        // ========================================================

        $display("");
        $display("========================================");
        $display("ALL FULL STACK TESTS PASSED");
        $display("========================================");

        #100;

        $finish;

    end

endmodule
