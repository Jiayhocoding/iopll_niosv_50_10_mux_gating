module mux_clock_control (
		input  wire  inclk0x,   //   inclk0x.clk,    Input 0 signal to the clock network.
		input  wire  inclk1x,   //   inclk1x.clk,    Input 1 signal to the clock network.
		input  wire  clkselect, // clkselect.export, Input that dynamically selects the clock source to drive the clock network
		output wire  outclk     //    outclk.clk,    Output of the Clock Control IP core.
	);
endmodule

