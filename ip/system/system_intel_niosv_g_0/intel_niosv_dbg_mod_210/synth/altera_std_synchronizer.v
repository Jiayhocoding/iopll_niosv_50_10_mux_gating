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


// $Id: //acds/rel/26.1/ip/iconnect/pd_components/altera_std_synchronizer/altera_std_synchronizer.v#1 $
// $Revision: #1 $
// $Date: 2026/02/05 $
// $Author: psgswbuild $
//-----------------------------------------------------------------------------
//
// File: altera_std_synchronizer.v
//
// Abstract: Single bit clock domain crossing synchronizer. 
//           Composed of two or more flip flops connected in series.
//           Random metastable condition is simulated when the 
//           __ALTERA_STD__METASTABLE_SIM macro is defined.
//           Use +define+__ALTERA_STD__METASTABLE_SIM argument 
//           on the Verilog simulator compiler command line to 
//           enable this mode. In addition, dfine the macro
//           __ALTERA_STD__METASTABLE_SIM_VERBOSE to get console output 
//           with every metastable event generated in the synchronizer.
//
// Copyright (C) Altera Corporation 2009, All Rights Reserved
//-----------------------------------------------------------------------------

`timescale 1ns / 1ns

module altera_std_synchronizer (
				clk, 
				reset_n, 
				din, 
				dout
				);

   parameter depth = 3; // This value must be >= 2 !
     
   input   clk;
   input   reset_n;    
   input   din;
   output  dout;

   // QuartusII synthesis directives:
   //     1. Preserve all registers ie. do not touch them.
   //     2. Do not merge other flip-flops with synchronizer flip-flops.
   // QuartusII TimeQuest directives:
   //     1. Identify all flip-flops in this module as members of the synchronizer 
   //        to enable automatic metastability MTBF analysis.
   //     2. Cut all timing paths terminating on data input pin of the first flop din_s1.

   (* altera_attribute = {"-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON; -name SDC_STATEMENT \"set_false_path -to [get_keepers {*altera_std_synchronizer:*|din_s1}]\" "} *) reg din_s1;

   (* altera_attribute = {"-name ADV_NETLIST_OPT_ALLOWED NEVER_ALLOW; -name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name DONT_MERGE_REGISTER ON; -name PRESERVE_REGISTER ON"} *) reg [depth-2:0] dreg;    
   
   //synthesis translate_off
   initial begin
      if (depth <2) begin
	 $display("%m: Error: synchronizer length: %0d less than 2.", depth);
      end
   end

   // the first synchronizer register is either a simple D flop for synthesis
   // and non-metastable simulation or a D flop with a method to inject random
   // metastable events resulting in random delay of [0,1] cycles
   
`ifdef __ALTERA_STD__METASTABLE_SIM

   reg[31:0]  RANDOM_SEED = 123456;      
   wire  next_din_s1;
   wire  dout;
   reg   din_last;
   reg 	 random;
   event metastable_event; // hook for debug monitoring

   initial begin
      $display("%m: Info: Metastable event injection simulation mode enabled");
   end
   
   always @(posedge clk) begin
      if (reset_n == 0)
	random <= $random(RANDOM_SEED);
      else
	random <= $random;
   end

   assign next_din_s1 = (din_last ^ din) ? random : din;   

   always @(posedge clk or negedge reset_n) begin
       if (reset_n == 0) 
	 din_last <= 1'b0;
       else
	 din_last <= din;
   end

   always @(posedge clk or negedge reset_n) begin
       if (reset_n == 0) 
	 din_s1 <= 1'b0;
       else
	 din_s1 <= next_din_s1;
   end
   
`else 

   //synthesis translate_on   
   always @(posedge clk or negedge reset_n) begin
       if (reset_n == 0) 
	 din_s1 <= 1'b0;
       else
	 din_s1 <= din;
   end
   //synthesis translate_off      

`endif

`ifdef __ALTERA_STD__METASTABLE_SIM_VERBOSE
   always @(*) begin
      if (reset_n && (din_last != din) && (random != din)) begin
	 $display("%m: Verbose Info: metastable event @ time %t", $time);
	 ->metastable_event;
      end
   end      
`endif

   //synthesis translate_on

   // the remaining synchronizer registers form a simple shift register
   // of length depth-1
   generate
      if (depth < 3) begin
	 always @(posedge clk or negedge reset_n) begin
	    if (reset_n == 0) 
	      dreg <= {depth-1{1'b0}};	    
	    else
	      dreg <= din_s1;
	 end	 
      end else begin
	 always @(posedge clk or negedge reset_n) begin
	    if (reset_n == 0) 
	      dreg <= {depth-1{1'b0}};
	    else
	      dreg <= {dreg[depth-3:0], din_s1};
	 end
      end
   endgenerate

   assign dout = dreg[depth-2];
   
endmodule 


			
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "tNLVto8x0Tf4Lip5fMg95M3VdjpojU2ro7lzOHI1+WQ05xa1qLq4UMAqKQ3O3NY6ze2+BizjKlQgXh7JYNiYsL0jVDVyucyGYozQ9ZQ/84HiM+YXTE2AuQUCAZJBCCud2wHBFjR+xqzdSpcYK1G29V0DIXMSBo47K8UR5juIXONlh3NjLjTGGH1E9+deC2uXvMTWiwdZu2IsVpo1lKEfS8esrT4Q63nEwVFzcntSju9FTNSg05VEVTXzwB7FTEaFFdODaeWc5z6GJ3JrgyZwCIdFZH7pIq/K8YuzBzbhawwOE1aHF4JoMd9SZNnb7I7Z+A2Ydfg+uWtOIU0rWwLaWZAowcz6VJN6kNKb60KQr0dd5aA0zs//JwLu5vQ/jF4HRPwBnOC8rJ01SEtzu59ChE3XtcyUMrcwgPtEhLMTnve8/CNvq8uH85eVBN2E3Q7MVfCzY0sefB06UsRYRz9PNuNUwZxe9imEXdhBTu75ZzHZtNLheikOQcuMpz7SJ7AAx0K0gtosUrdV8GdXNPjAtINAGSxr6o8HDpO8u+w/GnKzHbdj73bFdsTz7OZHQe4TiAFjp6If0jPe9CdE5NGsAJ6WNTIbTvdKiq+0cA5/rMdQuwRs492LAh60Cqf6K/O98XYkE2rQE5wjGpPnE9uvPNT4K9+INahLHrRLdDLTnEaRxG7c/r64/VPt0fnCQPFr7xgRw3KMvk4ztdJBEUBqKsHRbc82CS4hJg5lJ6+X5qSblAKzy3pzuVtvIfgP+5Rh6D0C8sOisl0xKD+K9kEPc3uizwGgISYgxMMcGndZBvFvrS043jdr5+rPlLpkfJdjnXhABZ4p/nlCLrhmGeA0EgezmDVWMKKpicGPPyS9cdGBBznqIjy6BFiZ3h4N8XRanPuNyywCqoeNTy8sUDUTQUUM3zURY9wqrGPbQWwBkx8YtlQ/ZddCVkQRdL0tJA38fLEK/SgIgMzQgwYyPenipCm2/MZMezo6yQd+/oH0XjmCxmGp3o3fS7MBLyKKil/F"
`endif