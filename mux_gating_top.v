// ============================================================================
// Copyright (c) 2025 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development
//   Kits made by Terasic.  Other use of this code, including the selling
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use
//   or functionality of this code.
//
// ============================================================================
//
//  Terasic Technologies Inc
//  No.80, Fenggong Rd., Hukou Township, Hsinchu County 303035. Taiwan
//
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Wed Jun  4 17:29:13 2025
// ============================================================================

//`define ENABLE_DDR4
//`define ENABLE_HPS
//`define ENABLE_HDMI
//`define ENABLE_HSMC
//`define ENABLE_CAM

module mux_gating_top(

      ///////// CLOCK /////////
      input              CLOCK0_50,
      input              CLOCK1_50,
      input              CLOCK2_50,

      ///////// KEY /////////
      input              CPU_RESET_n,
      input    [ 3: 0]   KEY,

      ///////// SW /////////
      input    [ 9: 0]   SW,

      ///////// LED /////////
      output   [ 9: 0]   LEDR,

      ///////// Seg7 /////////
      output   [ 6: 0]   HEX0,
      output   [ 6: 0]   HEX1,
      output   [ 6: 0]   HEX2,
      output   [ 6: 0]   HEX3,
      output   [ 6: 0]   HEX4,
      output   [ 6: 0]   HEX5,

      ///////// SDRAM /////////
      output             DRAM_CLK,
      output             DRAM_CKE,
      output   [12: 0]   DRAM_ADDR,
      output   [ 1: 0]   DRAM_BA,
      inout    [15: 0]   DRAM_DQ,
      output             DRAM_LDQM,
      output             DRAM_UDQM,
      output             DRAM_CS_n,
      output             DRAM_WE_n,
      output             DRAM_CAS_n,
      output             DRAM_RAS_n,

`ifdef ENABLE_DDR4
      ///////// DDR4 /////////
      input              DDR4_REFCLK_p,
      output   [16: 0]   DDR4_A,
      output   [ 1: 0]   DDR4_BA,
      output   [ 0: 0]   DDR4_BG,
      output             DDR4_CK,
      output             DDR4_CK_n,
      output             DDR4_CKE,
      inout    [ 3: 0]   DDR4_DQS,
      inout    [ 3: 0]   DDR4_DQS_n,
      inout    [31: 0]   DDR4_DQ,
      inout    [ 3: 0]   DDR4_DBI_n,
      output             DDR4_CS_n,
      output             DDR4_RESET_n,
      output             DDR4_ODT,
      output             DDR4_PAR,
      input              DDR4_ALERT_n,
      output             DDR4_ACT_n,
      input              DDR4_RZQ,
`endif /*ENABLE_DDR4*/

      ///////// Video-In /////////
      input              TD_CLK27,
      input              TD_HS,
      input              TD_VS,
      input    [ 7: 0]   TD_DATA,
      output             TD_RESET_n,

`ifdef ENABLE_HDMI
      ///////// HDMI /////////
      inout              HDMI_LRCLK,
      inout              HDMI_MCLK,
      inout              HDMI_SCLK,
      output             HDMI_TX_CLK,
      output             HDMI_TX_HS,
      output             HDMI_TX_VS,
      output   [23: 0]   HDMI_TX_D,
      output             HDMI_TX_DE,
      input              HDMI_TX_INT,
      inout              HDMI_I2S,
`endif /*ENABLE_HDMI*/

      ///////// Audio /////////
      inout              AUD_BCLK,
      output             AUD_XCK,
      inout              AUD_ADCLRCK,
      input              AUD_ADCDAT,
      inout              AUD_DACLRCK,
      output             AUD_DACDAT,

      ///////// ADC /////////
      output             ADC_SCK,
      input              ADC_SDO,
      output             ADC_SDI,
      output             ADC_CS_n,

      ///////// I2C for Camera, Audio, Video-In, Temerature Sensor and Fan Control /////////
      inout              FPGA_I2C_SCLK,
      inout              FPGA_I2C_SDAT,

      ///////// GPIO /////////
      inout    [35: 0]   GPIO_D,

`ifdef ENABLE_HSMC
      ///////// HSMC /////////
      output   [ 3: 0]   HSMC_GTS_TX_p,
      output   [ 3: 0]   HSMC_GTS_TX_n,
      input    [ 3: 0]   HSMC_GTS_RX_p,
      input    [ 3: 0]   HSMC_GTS_RX_n,
      input              HSMC_GTS_RX_REFCLK_p,
      output             HSMC_I2C_SCL,
      inout              HSMC_I2C_SDA,
      input    [ 2: 0]   HSMC_CLK_IN,
      input              HSMC_GTS_REFCLK_p,
      inout    [ 1: 0]   HSMC_B5B_D,
      inout    [76: 0]   HSMC_D,
`endif /*ENABLE_HSMC*/

`ifdef ENABLE_CAM
      ///////// CAM /////////
      input              CAM_CLK_p,
      input              CAM_CLK_n,
      input    [ 1: 0]   CAM_D_p,
      input    [ 1: 0]   CAM_D_n,
      inout              CAM_GPIO,
      input              CAM_RZQ1,
`endif /*ENABLE_CAM*/

`ifdef ENABLE_HPS
      ///////// HPS /////////
      input              HPS_CLK_25,
      output             HPS_ENET_MDC,
      inout              HPS_ENET_MDIO,
      input              HPS_ENET_RX_CLK,
      input              HPS_ENET_RX_CTL,
      input    [ 3: 0]   HPS_ENET_RX_DATA,
      output             HPS_ENET_TX_CLK,
      output             HPS_ENET_TX_CTL,
      output   [ 3: 0]   HPS_ENET_TX_DATA,
      inout    [ 1: 0]   HPS_GPIO,
      inout              HPS_GSENSOR_INT,
      inout              HPS_I2C_SCL,
      inout              HPS_I2C_SDA,
      inout              HPS_KEY,
      inout              HPS_LCM_BK,
      inout              HPS_LCM_D_C,
      inout              HPS_LCM_RST_n,
      output             HPS_LCM_SPIM_CLK,
      output             HPS_LCM_SPIM_MOSI,
      output             HPS_LCM_SPIM_SS,
      inout              HPS_LED,
      output             HPS_SD_CLK,
      inout              HPS_SD_CMD,
      inout    [ 3: 0]   HPS_SD_DATA,
      input              HPS_UART_RX,
      output             HPS_UART_TX,
      input              HPS_USB_CLK,
      inout    [ 7: 0]   HPS_USB_DATA,
      input              HPS_USB_DIR,
      input              HPS_USB_NXT,
      output             HPS_USB_STP,
`endif /*ENABLE_HPS*/

      ///////// IR /////////
      output             IRDA_TXD,
      input              IRDA_RXD



);


//=======================================================
//  REG/WIRE declarations
//=======================================================




//=======================================================
//  Structural coding
//=======================================================

wire clk_50;
wire sys_reset_n;

//=======================================================
//  Nios V -> IOPLL runtime reconfiguration
//=======================================================
wire        iopll_cmd_start;
wire        iopll_cmd_write;
wire [8:0]  iopll_cmd_address;
wire [31:0] iopll_cmd_writedata;
wire [31:0] iopll_cmd_readdata;
wire        iopll_cmd_busy;
wire        iopll_cmd_done;
wire        iopll_cmd_error;

(* keep = "true" *) wire [8:0]  core_avl_address;
wire        core_avl_read;
wire [7:0]  core_avl_readdata;
(* keep = "true" *) wire        core_avl_write;
(* keep = "true" *) wire [7:0]  core_avl_writedata;

(* keep = "true" *) wire        target_iopll_locked;
(* keep = "true" *) wire        target_iopll_outclk0;
(* keep = "true" *) wire        target_iopll_outclk1;
(* keep = "true" *) wire        mux_gating_clock_out;
(* keep = "true" *) wire        target_iopll_rst;


wire signed [15:0]FPGA_Temperature  ;// unit: C
wire signed [15:0]Board_Temperature ;// unit: C
wire signed [15:0]Board2_Temperature;// unit: C
wire [15:0]Fan_Speed         ;// unit: RPM
wire       Auto_Fan_Speed    ;// 1: enable audo speed control.0: user specify fan speed
wire [15:0]Set_Fan_Speed     ;// used when Auto_Fan_Speedis low
wire       I2C_READY         ;// 1:I2C BUS ready 0:I2C BUS no ready
wire       requested_10mhz;
wire       gate_50_enable, gate_10_enable;
wire       gated_clk_50, gated_clk_10;
wire       mux_select_10mhz, prepare_marker, transition_marker;
wire       mux_gating_busy, active_10mhz;



//=======================================================
//  Structural coding
//=======================================================


/////////////////////////// Reset Release IP ////////////////////////////////

wire ninit_done;
reset_release reset_release_int (
    .ninit_done (ninit_done)    //  output,  width = 1, ninit_done.ninit_done
);

assign clk_50 = CLOCK0_50;
assign sys_reset_n = ~ninit_done & CPU_RESET_n;

// target_iopll.rst is active-high; this design reset is active-low.
assign target_iopll_rst = ~sys_reset_n;

/////////////////////////// Qsys - NiosV ////////////////////////////////



   mux_gating_control_system u0 (
    .clock_in_clk                                  (clk_50),
    .reset_n_reset_n                               (sys_reset_n),

    .fan_speed_export                              (Fan_Speed),
    .temperature_board1_export                     (Board_Temperature),
    .temperature_board2_export                     (Board2_Temperature),
    .temperature_fpga_export                       (FPGA_Temperature),
    .pio_auto_fan_speed_external_connection_export (Auto_Fan_Speed),
    .pio_set_fan_speed_external_connection_export  (Set_Fan_Speed),
    .pio_i2c_ready_external_connection_export      (I2C_READY),
    .pio_gpio2_trigger_external_connection_export  (),
    .mux_sel_export                                (requested_10mhz),

    // Nios IOPLL bridge -> HVIO master
    .iopll_cmd_cmd_start                           (iopll_cmd_start),
    .iopll_cmd_cmd_write                           (iopll_cmd_write),
    .iopll_cmd_cmd_address                         (iopll_cmd_address),
    .iopll_cmd_cmd_writedata                       (iopll_cmd_writedata),

    // HVIO master -> Nios IOPLL bridge
    .iopll_cmd_cmd_readdata                        (iopll_cmd_readdata),
    .iopll_cmd_cmd_busy                            (iopll_cmd_busy),
    .iopll_cmd_cmd_done                            (iopll_cmd_done),
    .iopll_cmd_cmd_error                           (iopll_cmd_error),

    // Target IOPLL -> bridge STATUS bit[3]
    .iopll_cmd_pll_locked_async                    (target_iopll_locked)
);

// Legacy bridge ports remain in Platform Designer only for comparison.  They
// are not connected to the IOPLL and cannot affect a frequency transition.
assign iopll_cmd_readdata = 32'd0;
assign iopll_cmd_busy     = 1'b0;
assign iopll_cmd_done     = 1'b0;
assign iopll_cmd_error    = 1'b0;

// Hold the IOPLL register interface idle.  M/N/C0/C1 stay fixed at run time.
assign core_avl_address   = 9'd0;
assign core_avl_read      = 1'b0;
assign core_avl_write     = 1'b0;
assign core_avl_writedata = 8'd0;

target_iopll u_target_iopll (
    .refclk              (clk_50),
    .locked              (target_iopll_locked),
    .rst                 (target_iopll_rst),

    .core_avl_address    (core_avl_address),
    .core_avl_clk        (clk_50),
    .core_avl_read       (core_avl_read),
    .core_avl_readdata   (core_avl_readdata),
    .core_avl_write      (core_avl_write),
    .core_avl_writedata  (core_avl_writedata),

    .outclk_0            (target_iopll_outclk0),
    .outclk_1            (target_iopll_outclk1)
);

// Quartus 26.1 Clock Control IP root gates with negative-latched enables.
mux_gating_gate_50 u_mux_gating_gate_50 (
    .ena (gate_50_enable), .inclk (target_iopll_outclk0), .outclk (gated_clk_50)
);
mux_gating_gate_10 u_mux_gating_gate_10 (
    .ena (gate_10_enable), .inclk (target_iopll_outclk1), .outclk (gated_clk_10)
);

// Supported two-input glitch-free Clock Control IP, after the two gates.
mux_clock_control u_mux_clock_control (
    .inclk0x   (gated_clk_50),
    .inclk1x   (gated_clk_10),
    .clkselect (mux_select_10mhz),
    .outclk    (mux_gating_clock_out)
);

mux_gating_switch_controller u_mux_gating_switch_controller (
    .clk (clk_50), .reset_n (sys_reset_n), .requested_10mhz (requested_10mhz),
    .gate_50_enable (gate_50_enable), .gate_10_enable (gate_10_enable),
    .mux_select_10mhz (mux_select_10mhz), .prepare_marker (prepare_marker),
    .transition_marker (transition_marker),
    .busy (mux_gating_busy), .active_10mhz (active_10mhz)
);


// Export target IOPLL clock to GPIO for scope measurement.
assign GPIO_D[0] = mux_gating_clock_out;

// Export the target IOPLL's actual hardware lock output directly to GPIO.
assign GPIO_D[1] = target_iopll_locked;

// Direct MUX selection level for oscilloscope correlation:
// 0 selects the gated 50 MHz path; 1 selects the gated 10 MHz path.
assign GPIO_D[2] = mux_select_10mhz;

assign GPIO_D[3] = gated_clk_50;
assign GPIO_D[4] = gated_clk_10;
assign GPIO_D[5] = prepare_marker;

/////////////////////////// System Monitor IP ////////////////////////////////







BOARD_MANAGEMENT u_BOARD_MANAGEMENT(
                     .I2C_READY(I2C_READY),
    /*input*/        .clk_50 ( clk_50     ),
    /*input*/        .reset_n( sys_reset_n  ),

    // device i2c interface
    /*inout*/        .I2C_SCL( FPGA_I2C_SCLK ),
    /*inout*/        .I2C_SDA( FPGA_I2C_SDAT ),

    // board info and control
    /*output [15:0]*/.FPGA_Temperature  (FPGA_Temperature  ), // unit: C
    /*output [15:0]*/.Board_Temperature (Board_Temperature ), // unit: C
    /*output [15:0]*/.Board2_Temperature(Board2_Temperature), // unit: C
    /*output [15:0]*/.Fan_Speed         (Fan_Speed         ), // unit: RPM

    /*input        */.Auto_Fan_Speed    (Auto_Fan_Speed    ) ,// 1: enable audo speed control.0: user specify fan speed
    /*input  [15:0]*/.Set_Fan_Speed     (Set_Fan_Speed     )  // used when Auto_Fan_Speedis low
);







/////////////////////////////////////////////////
// User LED Blink

wire blink;

heart_beat led_blink(
	.clk(clk_50),
	.led(blink)
);

assign LEDR[0] = sys_reset_n?{blink}:1'b0;
//assign LEDR[1] = blink;
//assign LEDR[2] = ninit_done;
//assign LEDR[3] = CPU_RESET_N;
//assign LEDR[4] = sys_reset_n;


endmodule
