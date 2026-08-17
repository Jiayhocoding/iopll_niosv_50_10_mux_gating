module system_nios_iopll_bridge_0 (
		input  wire        clk,                       //     clock.clk
		input  wire        rst_n,                     //     reset.reset_n
		input  wire [2:0]  avs_address,               //       avs.address
		input  wire        avs_read,                  //          .read
		input  wire        avs_write,                 //          .write
		input  wire [31:0] avs_writedata,             //          .writedata
		output wire [31:0] avs_readdata,              //          .readdata
		output wire        avs_waitrequest,           //          .waitrequest
		output wire        cmd_start,                 // iopll_cmd.cmd_start
		output wire        cmd_write,                 //          .cmd_write
		output wire [8:0]  cmd_address,               //          .cmd_address
		output wire [31:0] cmd_writedata,             //          .cmd_writedata
		input  wire [31:0] cmd_readdata,              //          .cmd_readdata
		input  wire        cmd_busy,                  //          .cmd_busy
		input  wire        cmd_done,                  //          .cmd_done
		input  wire        cmd_error,                 //          .cmd_error
		input  wire        pll_locked_async,          //          .pll_locked_async
		output wire        diagnostic_software_reset  //          .diagnostic_software_reset
	);
endmodule

