module hvio_master (
    input  logic        clk,
    input  logic        rst_n,

    // ============================================================
    // Command interface from nios_iopll_bridge
    // ============================================================
    input  logic        cmd_start,
    input  logic        cmd_write,
    input  logic [8:0]  cmd_address,
    input  logic [31:0] cmd_writedata,

    output logic [31:0] cmd_readdata,
    output logic        busy,
    output logic        done,
    output logic        error,

    // ============================================================
    // Agilex 5 IOPLL HVIO reconfiguration interface
    // ============================================================
    output logic [8:0]  core_avl_address,
    output logic        core_avl_read,
    input  logic [7:0]  core_avl_readdata,

    output logic        core_avl_write,
    output logic [7:0]  core_avl_writedata
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_WRITE,
        ST_READ
    } state_t;

    state_t state;

    logic [4:0] cycle_count;

    logic        command_write_reg;
    logic [8:0]  command_address_reg;
    logic [31:0] command_writedata_reg;

    logic [31:0] read_shift_reg;

    // ============================================================
    // Outputs
    // ============================================================

    assign busy = (state != ST_IDLE);

    // Address is fixed for the complete transaction.
    assign core_avl_address = command_address_reg;

    // ============================================================
    // Sequential control
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                  <= ST_IDLE;
            cycle_count            <= 5'd0;

            command_write_reg      <= 1'b0;
            command_address_reg    <= 9'd0;
            command_writedata_reg  <= 32'd0;

            cmd_readdata           <= 32'd0;
            read_shift_reg         <= 32'd0;

            done                   <= 1'b0;
            error                  <= 1'b0;
        end
        else begin
            // one-cycle response pulses
            done  <= 1'b0;
            error <= 1'b0;

            case (state)

                // =================================================
                // IDLE
                // =================================================
                ST_IDLE: begin
                    cycle_count <= 5'd0;

                    if (cmd_start) begin
                        command_write_reg     <= cmd_write;
                        command_address_reg   <= cmd_address;
                        command_writedata_reg <= cmd_writedata;

                        read_shift_reg <= 32'd0;

                        if (cmd_write)
                            state <= ST_WRITE;
                        else
                            state <= ST_READ;
                    end
                end

                // =================================================
                // WRITE
                //
                // Fixed-cycle sequence:
                //
                // cycle 0..4 : write 0x00 preamble
                // cycle 5    : D0
                // cycle 6    : D1
                // cycle 7    : D2
                // cycle 8    : D3
                // cycle 9    : D3 again
                // cycle 10..14: idle
                //
                // =================================================
                ST_WRITE: begin
                    if (cycle_count == 5'd14) begin
                        state       <= ST_IDLE;
                        cycle_count <= 5'd0;
                        done        <= 1'b1;
                    end
                    else begin
                        cycle_count <= cycle_count + 5'd1;
                    end
                end

                // =================================================
                // READ
                //
                // Fixed-cycle sequence:
                //
                // cycle 0..4 : discard invalid bytes
                // cycle 5    : header / discard
                // cycle 6    : D0
                // cycle 7    : D1
                // cycle 8    : D2
                // cycle 9    : D3
                // cycle 10..14: idle
                //
                // =================================================
                ST_READ: begin

                    case (cycle_count)
                        5'd6:
                            read_shift_reg[7:0]   <= core_avl_readdata;

                        5'd7:
                            read_shift_reg[15:8]  <= core_avl_readdata;

                        5'd8:
                            read_shift_reg[23:16] <= core_avl_readdata;

                        5'd9: begin
                            read_shift_reg[31:24] <= core_avl_readdata;
                            cmd_readdata[7:0]     <= read_shift_reg[7:0];
                            cmd_readdata[15:8]    <= read_shift_reg[15:8];
                            cmd_readdata[23:16]   <= read_shift_reg[23:16];
                            cmd_readdata[31:24]   <= core_avl_readdata;
                        end

                        default: begin
                        end
                    endcase

                    if (cycle_count == 5'd14) begin
                        state       <= ST_IDLE;
                        cycle_count <= 5'd0;
                        done        <= 1'b1;
                    end
                    else begin
                        cycle_count <= cycle_count + 5'd1;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                    error <= 1'b1;
                end

            endcase
        end
    end

    // ============================================================
    // HVIO output generation
    // ============================================================

    always_comb begin
        core_avl_read      = 1'b0;
        core_avl_write     = 1'b0;
        core_avl_writedata = 8'h00;

        case (state)

            // ====================================================
            // WRITE transaction
            // ====================================================
            ST_WRITE: begin
                core_avl_write = 1'b1;

                case (cycle_count)

                    5'd0,
                    5'd1,
                    5'd2,
                    5'd3,
                    5'd4:
                        core_avl_writedata = 8'h00;

                    5'd5:
                        core_avl_writedata =
                            command_writedata_reg[7:0];

                    5'd6:
                        core_avl_writedata =
                            command_writedata_reg[15:8];

                    5'd7:
                        core_avl_writedata =
                            command_writedata_reg[23:16];

                    5'd8,
                    5'd9:
                        core_avl_writedata =
                            command_writedata_reg[31:24];

                    default: begin
                        core_avl_write     = 1'b0;
                        core_avl_writedata = 8'h00;
                    end

                endcase
            end

            // ====================================================
            // READ transaction
            // ====================================================
            ST_READ: begin
                if (cycle_count <= 5'd9)
                    core_avl_read = 1'b1;
            end

            default: begin
            end

        endcase
    end

endmodule