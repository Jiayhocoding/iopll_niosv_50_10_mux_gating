	target_iopll u0 (
		.refclk             (_connected_to_refclk_),             //   input,  width = 1,             refclk.clk
		.locked             (_connected_to_locked_),             //  output,  width = 1,             locked.export
		.rst                (_connected_to_rst_),                //   input,  width = 1,              reset.reset
		.core_avl_address   (_connected_to_core_avl_address_),   //   input,  width = 9,   core_avl_address.core_avl_address
		.core_avl_clk       (_connected_to_core_avl_clk_),       //   input,  width = 1,       core_avl_clk.clk
		.core_avl_read      (_connected_to_core_avl_read_),      //   input,  width = 1,      core_avl_read.core_avl_read
		.core_avl_readdata  (_connected_to_core_avl_readdata_),  //  output,  width = 8,  core_avl_readdata.core_avl_readdata
		.core_avl_write     (_connected_to_core_avl_write_),     //   input,  width = 1,     core_avl_write.core_avl_write
		.core_avl_writedata (_connected_to_core_avl_writedata_), //   input,  width = 8, core_avl_writedata.core_avl_writedata
		.outclk_0           (_connected_to_outclk_0_),           //  output,  width = 1,            outclk0.clk
		.outclk_1           (_connected_to_outclk_1_)            //  output,  width = 1,            outclk1.clk
	);

