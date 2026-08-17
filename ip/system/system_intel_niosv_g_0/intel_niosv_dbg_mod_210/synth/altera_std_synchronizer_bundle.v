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


// $Id: //acds/rel/26.1/ip/iconnect/pd_components/altera_std_synchronizer/altera_std_synchronizer_bundle.v#1 $
// $Revision: #1 $
// $Date: 2026/02/05 $
//----------------------------------------------------------------
//
// File: altera_std_synchronizer_bundle.v
//
// Abstract: Bundle of bit synchronizers. 
//           WARNING: only use this to synchronize a bundle of 
//           *independent* single bit signals or a Gray encoded 
//           bus of signals. Also remember that pulses entering 
//           the synchronizer will be swallowed upon a metastable
//           condition if the pulse width is shorter than twice
//           the synchronizing clock period.
//
// Copyright (C) Altera Corporation 2008, All Rights Reserved
//----------------------------------------------------------------

module altera_std_synchronizer_bundle(
				     clk,
				     reset_n,
				     din,
				     dout
				     );
   parameter width = 1;
   parameter depth = 3;   
   
   input clk;
   input reset_n;
   input [width-1:0] din;
   output [width-1:0] dout;
   
   generate
      genvar i;
      for (i=0; i<width; i=i+1)
	begin : sync
	   altera_std_synchronizer #(.depth(depth))
                                   u (
				      .clk(clk), 
				      .reset_n(reset_n), 
				      .din(din[i]), 
				      .dout(dout[i])
				      );
	end
   endgenerate
   
endmodule 

`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "tNLVto8x0Tf4Lip5fMg95M3VdjpojU2ro7lzOHI1+WQ05xa1qLq4UMAqKQ3O3NY6ze2+BizjKlQgXh7JYNiYsL0jVDVyucyGYozQ9ZQ/84HiM+YXTE2AuQUCAZJBCCud2wHBFjR+xqzdSpcYK1G29V0DIXMSBo47K8UR5juIXONlh3NjLjTGGH1E9+deC2uXvMTWiwdZu2IsVpo1lKEfS8esrT4Q63nEwVFzcntSju8k8I7Alyc6rczBkBoNyDNRXKOwzlMUxnnhGTrz03UEh6UTFt3luINTehUbar3gapV8dZAzhMex3/CD3mznc/ntIDXZFHNE2Jkga97kuVrDyrsDECr4agkfcEy4E/vL9Xu9lH6unn+sX2Z4cqulIX4umQzwFmKKUxg3eLqzxAKC8W7SF98W6fIefDZKhrJ/Sh/U8Q6hr16/HXxHpZUE0cGKlaesITqaZfjJp4GScWge0FX4iZU1w6zLfYFzZ1h5AYDCctayX/IFuFOWKxfvsyWaOlbrAknhevUAsBWMYKfphqBMC8YCgsAJcvWQo1YdNZWZF7FaKVoH/v7F7H2HEa9F9HhpVWFBvnCKkN4IeiyCv7UGlJq8KIVJY44ncUu1xYUVrfn3ZqkNI78441Owvo4NDh7e0YEAWvbq8bgrbLWJZVGZ61Ppe6w6FFKjI9RbbqPAklY75655U4eEutlV5ENlP1bUvQEslHnrDJlheywb7+TMZq/t5i/TRaucznC4DVPecg+03bOfPm60sTGS7RFp1pA6IoHsqWpIZQtgOOvF/439dvWi8QGN0cD3AKlFD40OfUGGcIz8fDwZlseDH/oF2KEs9iqGcbNiBO6pKxkx/KI2Zd+utoJ9cvcBv0A7/ZUwYCJHgkiKrqHyog9mPd9XmPSTY4V4vqdcV6mDPexIKnPh7txku6RzBpeLd5ryOG6pROOz2NGU8RxiM+tZOaWSfR0qwNYuKN8vjp3ddRAMmsLn5AdqxcI5KL5oaobs1A7YPINs8WbebsI3bCqeFUwd"
`endif