module mux_gating_switch_controller #(
    parameter int unsigned PREPARE_CYCLES      = 4,
    parameter int unsigned SWITCH_GUARD_CYCLES = 50
) (
    input  logic clk,
    input  logic reset_n,
    input  logic requested_10mhz,
    output logic gate_50_enable,
    output logic gate_10_enable,
    output logic mux_select_10mhz,
    output logic prepare_marker,
    output logic transition_marker,
    output logic busy,
    output logic active_10mhz
);
    typedef enum logic [3:0] {
        RUN_50,
        ENABLE_10,
        WAIT_PREPARE_10,
        WAIT_SWITCH_10,
        RUN_10,
        ENABLE_50,
        WAIT_PREPARE_50,
        WAIT_SWITCH_50
    } state_t;

    localparam int unsigned MAX_COUNT =
        (PREPARE_CYCLES > SWITCH_GUARD_CYCLES) ?
        PREPARE_CYCLES : SWITCH_GUARD_CYCLES;
    localparam int unsigned COUNT_WIDTH =
        (MAX_COUNT < 2) ? 1 : $clog2(MAX_COUNT + 1);

    state_t state;
    logic [COUNT_WIDTH-1:0] cycle_count;

    // The raw IOPLL C0/C1 outputs do not enter this controller. They run
    // continuously. These enables only control dedicated clock-path gates.
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state                 <= RUN_50;
            gate_50_enable        <= 1'b1;
            gate_10_enable        <= 1'b0;
            mux_select_10mhz      <= 1'b0;
            prepare_marker        <= 1'b0;
            transition_marker     <= 1'b0;
            busy                  <= 1'b0;
            active_10mhz          <= 1'b0;
            cycle_count           <= '0;
        end else begin
            case (state)
                RUN_50: begin
                    busy              <= 1'b0;
                    active_10mhz      <= 1'b0;
                    prepare_marker    <= 1'b0;
                    transition_marker <= 1'b0;
                    if (requested_10mhz) begin
                        busy  <= 1'b1;
                        state <= ENABLE_10;
                    end
                end

                ENABLE_10: begin
                    gate_10_enable <= 1'b1;
                    prepare_marker <= 1'b1;
                    cycle_count    <= '0;
                    if (PREPARE_CYCLES == 0) begin
                        transition_marker <= 1'b1;
                        mux_select_10mhz  <= 1'b1;
                        state             <= WAIT_SWITCH_10;
                    end else begin
                        state <= WAIT_PREPARE_10;
                    end
                end

                WAIT_PREPARE_10: begin
                    if (cycle_count == PREPARE_CYCLES-1) begin
                        transition_marker <= 1'b1;
                        mux_select_10mhz  <= 1'b1;
                        cycle_count       <= '0;
                        state             <= WAIT_SWITCH_10;
                    end else begin
                        cycle_count <= cycle_count + 1'b1;
                    end
                end

                WAIT_SWITCH_10: begin
                    if ((SWITCH_GUARD_CYCLES == 0) ||
                        (cycle_count == SWITCH_GUARD_CYCLES-1)) begin
                        gate_50_enable     <= 1'b0;
                        prepare_marker     <= 1'b0;
                        transition_marker  <= 1'b0;
                        active_10mhz       <= 1'b1;
                        cycle_count        <= '0;
                        state              <= RUN_10;
                    end else begin
                        cycle_count <= cycle_count + 1'b1;
                    end
                end

                RUN_10: begin
                    busy <= 1'b0;
                    if (!requested_10mhz) begin
                        busy  <= 1'b1;
                        state <= ENABLE_50;
                    end
                end

                ENABLE_50: begin
                    gate_50_enable <= 1'b1;
                    prepare_marker <= 1'b1;
                    cycle_count    <= '0;
                    if (PREPARE_CYCLES == 0) begin
                        transition_marker <= 1'b1;
                        mux_select_10mhz  <= 1'b0;
                        state             <= WAIT_SWITCH_50;
                    end else begin
                        state <= WAIT_PREPARE_50;
                    end
                end

                WAIT_PREPARE_50: begin
                    if (cycle_count == PREPARE_CYCLES-1) begin
                        transition_marker <= 1'b1;
                        mux_select_10mhz  <= 1'b0;
                        cycle_count       <= '0;
                        state             <= WAIT_SWITCH_50;
                    end else begin
                        cycle_count <= cycle_count + 1'b1;
                    end
                end

                WAIT_SWITCH_50: begin
                    if ((SWITCH_GUARD_CYCLES == 0) ||
                        (cycle_count == SWITCH_GUARD_CYCLES-1)) begin
                        gate_10_enable     <= 1'b0;
                        prepare_marker     <= 1'b0;
                        transition_marker  <= 1'b0;
                        active_10mhz       <= 1'b0;
                        cycle_count        <= '0;
                        state              <= RUN_50;
                    end else begin
                        cycle_count <= cycle_count + 1'b1;
                    end
                end

                default: begin
                    state                 <= RUN_50;
                    gate_50_enable        <= 1'b1;
                    gate_10_enable        <= 1'b0;
                    mux_select_10mhz      <= 1'b0;
                    prepare_marker        <= 1'b0;
                    transition_marker     <= 1'b0;
                    busy                  <= 1'b0;
                    active_10mhz          <= 1'b0;
                    cycle_count           <= '0;
                end
            endcase
        end
    end
endmodule
