	system_nios_iopll_bridge_0 u0 (
		.clk                       (_connected_to_clk_),                       //   input,   width = 1,     clock.clk
		.rst_n                     (_connected_to_rst_n_),                     //   input,   width = 1,     reset.reset_n
		.avs_address               (_connected_to_avs_address_),               //   input,   width = 3,       avs.address
		.avs_read                  (_connected_to_avs_read_),                  //   input,   width = 1,          .read
		.avs_write                 (_connected_to_avs_write_),                 //   input,   width = 1,          .write
		.avs_writedata             (_connected_to_avs_writedata_),             //   input,  width = 32,          .writedata
		.avs_readdata              (_connected_to_avs_readdata_),              //  output,  width = 32,          .readdata
		.avs_waitrequest           (_connected_to_avs_waitrequest_),           //  output,   width = 1,          .waitrequest
		.cmd_start                 (_connected_to_cmd_start_),                 //  output,   width = 1, iopll_cmd.cmd_start
		.cmd_write                 (_connected_to_cmd_write_),                 //  output,   width = 1,          .cmd_write
		.cmd_address               (_connected_to_cmd_address_),               //  output,   width = 9,          .cmd_address
		.cmd_writedata             (_connected_to_cmd_writedata_),             //  output,  width = 32,          .cmd_writedata
		.cmd_readdata              (_connected_to_cmd_readdata_),              //   input,  width = 32,          .cmd_readdata
		.cmd_busy                  (_connected_to_cmd_busy_),                  //   input,   width = 1,          .cmd_busy
		.cmd_done                  (_connected_to_cmd_done_),                  //   input,   width = 1,          .cmd_done
		.cmd_error                 (_connected_to_cmd_error_),                 //   input,   width = 1,          .cmd_error
		.pll_locked_async          (_connected_to_pll_locked_async_),          //   input,   width = 1,          .pll_locked_async
		.diagnostic_software_reset (_connected_to_diagnostic_software_reset_)  //  output,   width = 1,          .diagnostic_software_reset
	);

