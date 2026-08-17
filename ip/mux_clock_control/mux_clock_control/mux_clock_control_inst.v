	mux_clock_control u0 (
		.inclk0x   (_connected_to_inclk0x_),   //   input,  width = 1,   inclk0x.clk
		.inclk1x   (_connected_to_inclk1x_),   //   input,  width = 1,   inclk1x.clk
		.clkselect (_connected_to_clkselect_), //   input,  width = 1, clkselect.export
		.outclk    (_connected_to_outclk_)     //  output,  width = 1,    outclk.clk
	);

