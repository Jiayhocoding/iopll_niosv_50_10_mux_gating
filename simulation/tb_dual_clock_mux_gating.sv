`timescale 1ns/1ps

module tb_dual_clock_mux_gating;
    parameter integer PREPARE_CYCLES = 4;
    parameter integer SWITCH_GUARD_CYCLES = 50;

    logic sys_clk = 0, raw_clk_50 = 0, raw_clk_10 = 0;
    logic reset_n = 1, requested_10mhz = 0, pll_locked = 1;
    logic gate_50_enable, gate_10_enable, mux_select_10mhz;
    logic prepare_marker, transition_marker, busy, active_10mhz;
    logic gate50_latched = 0, gate10_latched = 0;
    wire gated_clk_50 = raw_clk_50 & gate50_latched;
    wire gated_clk_10 = raw_clk_10 & gate10_latched;
    wire mux_out;

    integer raw50_edges = 0, raw10_edges = 0;
    integer raw50_at_gate_off = 0, raw10_at_gate_off = 0;
    integer prepare_wait_count;
    integer switch_wait_count;
    time last_out_transition = 0;
    logic monitor_output_pulses = 0;
    logic previous_mux_select;

    always #10 sys_clk = ~sys_clk;
    always #10 raw_clk_50 = ~raw_clk_50;
    always #50 raw_clk_10 = ~raw_clk_10;
    always @(posedge raw_clk_50) raw50_edges++;
    always @(posedge raw_clk_10) raw10_edges++;

    // Simulation-only behavioral models of the dedicated IP's negative-latched
    // root clock gates. No combinational RTL gate exists in the synthesized DUT.
    always_latch if (!raw_clk_50) gate50_latched <= gate_50_enable;
    always_latch if (!raw_clk_10) gate10_latched <= gate_10_enable;

    mux_gating_switch_controller #(
        .PREPARE_CYCLES(PREPARE_CYCLES),
        .SWITCH_GUARD_CYCLES(SWITCH_GUARD_CYCLES)
    ) dut (
        .clk(sys_clk),
        .reset_n(reset_n),
        .requested_10mhz(requested_10mhz),
        .gate_50_enable(gate_50_enable),
        .gate_10_enable(gate_10_enable),
        .mux_select_10mhz(mux_select_10mhz),
        .prepare_marker(prepare_marker),
        .transition_marker(transition_marker),
        .busy(busy),
        .active_10mhz(active_10mhz)
    );

    mux_clock_control u_mux_model (
        .inclk0x(gated_clk_50),
        .inclk1x(gated_clk_10),
        .clkselect(mux_select_10mhz),
        .outclk(mux_out)
    );

    // Control-safety assertions: the selected source is always enabled and the
    // old path remains enabled until after the MUX selection command.
    always @(posedge sys_clk) begin
        if (reset_n) begin
            assert (gate_50_enable || gate_10_enable)
                else $fatal(1, "both gated paths disabled");
            assert (!mux_select_10mhz || gate_10_enable)
                else $fatal(1, "MUX selected disabled 10 MHz path");
            assert (mux_select_10mhz || gate_50_enable)
                else $fatal(1, "MUX selected disabled 50 MHz path");
            if (!gate_50_enable)
                assert (mux_select_10mhz)
                    else $fatal(1, "50 MHz path disabled before MUX command");
            if (!gate_10_enable)
                assert (!mux_select_10mhz)
                    else $fatal(1, "10 MHz path disabled before MUX command");
            assert (pll_locked)
                else $fatal(1, "PLL lock changed during path switching");

            if (mux_select_10mhz != previous_mux_select) begin
                assert (transition_marker)
                    else $fatal(1, "MUX selection changed without transition marker");
                assert (prepare_marker)
                    else $fatal(1, "MUX changed before target preparation");
                if (mux_select_10mhz)
                    assert (gate_50_enable && gate_10_enable)
                        else $fatal(1, "50->10 MUX command without both paths enabled");
                else
                    assert (gate_50_enable && gate_10_enable)
                        else $fatal(1, "10->50 MUX command without both paths enabled");
            end
            previous_mux_select <= mux_select_10mhz;
        end
    end

    // Digital sanity check only; dedicated clock IP and silicon must provide
    // the hardware pulse-integrity guarantee.
    always @(mux_out) begin
        if (monitor_output_pulses && last_out_transition != 0)
            assert (($time - last_out_transition) >= 10ns)
                else $fatal(1, "digital runt pulse: %0t", $time-last_out_transition);
        last_out_transition = $time;
    end

    task automatic check_prepare_to_10;
        begin
            requested_10mhz = 1;
            @(posedge gate_10_enable);
            assert (prepare_marker && gate_50_enable &&
                    ((PREPARE_CYCLES == 0) || !mux_select_10mhz))
                else $fatal(1, "invalid 50->10 preparation start");
            prepare_wait_count = 0;
            while (!transition_marker) begin
                @(posedge sys_clk);
                #1;
                prepare_wait_count++;
            end
            assert (prepare_wait_count == PREPARE_CYCLES)
                else $fatal(1, "50->10 prepare count %0d, expected %0d",
                            prepare_wait_count, PREPARE_CYCLES);
            #1 assert (mux_select_10mhz && gate_50_enable && gate_10_enable)
                else $fatal(1, "invalid 50->10 MUX command");
            switch_wait_count = 0;
            while (gate_50_enable) begin
                @(posedge sys_clk);
                #1;
                switch_wait_count++;
            end
            assert (switch_wait_count == SWITCH_GUARD_CYCLES)
                else $fatal(1, "50->10 switch guard %0d, expected %0d",
                            switch_wait_count, SWITCH_GUARD_CYCLES);
            wait (active_10mhz && !busy);
        end
    endtask

    task automatic check_prepare_to_50;
        begin
            requested_10mhz = 0;
            @(posedge gate_50_enable);
            assert (prepare_marker && gate_10_enable &&
                    ((PREPARE_CYCLES == 0) || mux_select_10mhz))
                else $fatal(1, "invalid 10->50 preparation start");
            prepare_wait_count = 0;
            while (!transition_marker) begin
                @(posedge sys_clk);
                #1;
                prepare_wait_count++;
            end
            assert (prepare_wait_count == PREPARE_CYCLES)
                else $fatal(1, "10->50 prepare count %0d, expected %0d",
                            prepare_wait_count, PREPARE_CYCLES);
            #1 assert (!mux_select_10mhz && gate_50_enable && gate_10_enable)
                else $fatal(1, "invalid 10->50 MUX command");
            switch_wait_count = 0;
            while (gate_10_enable) begin
                @(posedge sys_clk);
                #1;
                switch_wait_count++;
            end
            assert (switch_wait_count == SWITCH_GUARD_CYCLES)
                else $fatal(1, "10->50 switch guard %0d, expected %0d",
                            switch_wait_count, SWITCH_GUARD_CYCLES);
            wait (!active_10mhz && !busy);
        end
    endtask

    initial begin
        $dumpfile("tb_dual_clock_mux_gating.vcd");
        $dumpvars(0, tb_dual_clock_mux_gating);
        #1 reset_n = 0;
        #74 reset_n = 1;
        #300;
        assert (gate_50_enable && !gate_10_enable && !mux_select_10mhz);
        previous_mux_select = mux_select_10mhz;
        monitor_output_pulses = 1;

        raw10_at_gate_off = raw10_edges;
        check_prepare_to_10();
        // The raw 10 MHz IOPLL-model clock continued while its path was gated.
        assert (raw10_edges > raw10_at_gate_off)
            else $fatal(1, "raw 10 MHz generation stopped while gate disabled");
        assert (!gate_50_enable && gate_10_enable && mux_select_10mhz);

        #800;
        raw50_at_gate_off = raw50_edges;
        check_prepare_to_50();
        // The raw 50 MHz IOPLL-model clock continued while its path was gated.
        assert (raw50_edges > raw50_at_gate_off)
            else $fatal(1, "raw 50 MHz generation stopped while gate disabled");
        assert (gate_50_enable && !gate_10_enable && !mux_select_10mhz);

        #500;
        $display("PASS PREPARE_CYCLES=%0d SWITCH_GUARD_CYCLES=%0d",
                 PREPARE_CYCLES, SWITCH_GUARD_CYCLES);
        $finish;
    end

    initial begin
        #30000 $fatal(1, "simulation timeout");
    end
endmodule
