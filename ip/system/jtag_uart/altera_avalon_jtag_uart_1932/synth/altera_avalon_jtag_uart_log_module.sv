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


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10034 10035 10036 10037 10230 10240 10030 13469 16735 16788 

module altera_avalon_jtag_uart_log_module #(
  parameter FIFO_WIDTH = 8
  ) (
  // inputs:
   clk,
   data,
   strobe,
   valid
    )
;

  input                     clk;
  input   [FIFO_WIDTH-1: 0] data;
  input                     strobe;
  input                     valid;



//synthesis translate_off
//////////////// SIMULATION-ONLY CONTENTS
   reg [31:0] text_handle; // for $fopen
   initial text_handle = $fopen ("altera_avalon_jtag_uart_output_stream.dat");

   always @(posedge clk) begin
      if (valid && strobe) begin
	 // Send \n (linefeed) instead of \r (^M, Carriage Return)...
         $fwrite (text_handle, "%s", ((data == 8'hd) ? 8'ha : data));
	 // non-standard; poorly documented; required to get real data stream.
	 $fflush (text_handle);
      end
   end // clk


//////////////// END SIMULATION-ONLY CONTENTS

//synthesis translate_on

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "fs3MoWBgHCF39POOsRTSk9Of235Syebg6gnxSRl1C3eH9/q9SvVYcuvHV6n+ciNcw1ZgnLUuBtqkgc5BFhhjFnxbTVeuzHhPTudkRx35Y+NfPOUkDAugUZPKer0wXL9pRAwH3byzjlgXB2SHOxqIBOiiFdHFMWEzFqqitQSeTR0XsgNSEUtkjewHkaIdmB+gUPZtp91aSbp/tszSUSGSEr2Yzzd/T421QZLUt8TjkSBOJWjgddhu7OfJar/VtWj3psppK9mEqts6ZfDvfuMhsqnA79a2bjthgN5OeSclAsqSfJ8CW7pcx9RLW3TlOgUizfsSn8yMauyxZVFPVmGoAt2z8IJ+oK5D9dutL91i3yuzMUG4x1axMAckBxDR3I1fkkXY72HOUlY3jdDFaqixaTxuQ2rVgvHHsAA4jJv5TkQdiLGSNEwVGeAH/hRNHz/+W1I5CGi2LwmYC28S97EzekFzrAI38aWA12S31VjGXMvuH1RMHHPjqrtwmKq33t8oL+FJrZk9nGyCZ3Z7ybQGu6PtV0MB5wnF4bGsfb+FqBNPQeOGNNBKM6kcmNZGRFOYwabWVLwS+fqDW57i/0AMyUQmx0NgIPHzzTkh/AWtZ3ylDyndN+yUfGs1aNqamlqs0uxO1AY4vhob+iDAwpSwII06s84MYrpUQl7pQz0cJ5tCNddg5qfwEMelMEQFppJDQW2vV6w8E3FOe27fRqW+kCpR5cjRTC9J12QX4Jy8GeXnLdEV277sbyidQIzqt85fRjDhAXRwMMJefzEYYv+D6pdkxSZj6X6hh4HEuNYP/CTbE3uF4BLvA+Yp3GjtA2wtoJIvDNu5Jlbr46P3Uhu+Q2A4WKOpwX93YtOF/zd+yKvJfBbKVgdTvtASvgO2hR3L2hWbBxZmC02c1eSMUjL2NLHpu5fUzuKLOztQTIgo4O8AFTXjC0d1RB8h8xpLPsX/iSLHgt0Up9ytyQm3/f8s4CzpBlXi5ox+4qrmXynQvX5cphFCB+GYStPqd/LSdfdM"
`endif