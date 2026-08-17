module target_iopll (
		input  wire       refclk,             //             refclk.clk,                The reference clock source that drives the I/O PLL.
		output wire       locked,             //             locked.export,             The IOPLL IP core drives this port high when the PLL acquires lock. The port remains high as long as the I/O PLL is locked. The I/O PLL asserts the locked port when the phases and frequencies of the reference clock and feedback clock are the same or within the lock circuit tolerance. When the difference between the two clock signals exceeds the lock circuit tolerance, the I/O PLL loses lock.
		input  wire       rst,                //              reset.reset,              The asynchronous reset port for the output clocks. Drive this port high to reset all output clocks to the value of 0.
		input  wire [8:0] core_avl_address,   //   core_avl_address.core_avl_address,   AVL interface address port from IOSSM.
		input  wire       core_avl_clk,       //       core_avl_clk.clk,                AVL interface clock from IOSSM.
		input  wire       core_avl_read,      //      core_avl_read.core_avl_read,      AVL interface read enable signal from IOSSM.
		output wire [7:0] core_avl_readdata,  //  core_avl_readdata.core_avl_readdata,  AVL interface read data port to IOSSM.
		input  wire       core_avl_write,     //     core_avl_write.core_avl_write,     AVL interface write enable signal from IOSSM.
		input  wire [7:0] core_avl_writedata, // core_avl_writedata.core_avl_writedata, AVL interface write data port from IOSSM.
		output wire       outclk_0,           //            outclk0.clk,                Output clock Channel 0 from I/O PLL.
		output wire       outclk_1            //            outclk1.clk,                Output clock Channel 1 from I/O PLL.
	);
endmodule

