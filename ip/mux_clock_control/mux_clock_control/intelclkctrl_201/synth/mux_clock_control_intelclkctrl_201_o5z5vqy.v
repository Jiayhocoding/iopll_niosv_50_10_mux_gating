// (C) 2001-2026 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module  mux_clock_control_intelclkctrl_201_o5z5vqy  (
    inclk0x,
    inclk1x,
    clkselect,
    outclk
);

input inclk0x;
input inclk1x;
input clkselect;
output outclk;

wire inclk_muxout;

mux_clock_control_intelclkctrl_201_o5z5vqy_clksel_mux clksel_inst (
    .inclk0x(inclk0x),
    .inclk1x(inclk1x),
    .clkselect(clkselect),
    .clkout(inclk_muxout)
); 
GLOBAL global_inst(.in(inclk_muxout), .out(outclk));

endmodule


module mux_clock_control_intelclkctrl_201_o5z5vqy_clksel_mux (
    input inclk0x,
    input inclk1x,
    input clkselect,
    output clkout
);
	parameter num_clocks = 2;
	genvar i;
	wire [num_clocks-1:0] clk;
	wire [num_clocks-1:0] clk_select; // one hot
	reg [num_clocks-1:0] ena_r0;
	reg [num_clocks-1:0] ena_r1;
	reg [num_clocks-1:0] ena_r2;
	wire [num_clocks-1:0] qualified_sel;

	// A look-up-table (LUT) can glitch when multiple inputs 
	// change simultaneously. Use the keep attribute to
	// insert a hard logic cell buffer and prevent 
	// the unrelated clocks from appearing on the same LUT.

	assign clk[0] = inclk0x;
	assign clk[1] = inclk1x;
	
	// Decoder logic
	assign clk_select[0] = ~clkselect;
	assign clk_select[1] = clkselect;
	
	wire [num_clocks-1:0] gated_clks /* synthesis keep */;

	initial begin
		ena_r0 = 0;
		ena_r1 = 0;
		ena_r2 = 0;
	end

	generate
		for (i=0; i<num_clocks; i=i+1) 
		begin : lp0
			wire [num_clocks-1:0] tmp_mask;
			assign tmp_mask = {num_clocks{1'b1}} ^ (1 << i);

			assign qualified_sel[i] = clk_select[i] & (~|(ena_r2 & tmp_mask));

			always @(posedge clk[i]) begin
				ena_r0[i] <= qualified_sel[i];    	
				ena_r1[i] <= ena_r0[i];    	
			end

			always @(negedge clk[i]) begin
				ena_r2[i] <= ena_r1[i];    	
			end

			assign gated_clks[i] = clk[i] & ena_r2[i];
		end
	endgenerate
	// These will not exhibit simultaneous toggle by construction
	assign clkout = |gated_clks;

endmodule
   


