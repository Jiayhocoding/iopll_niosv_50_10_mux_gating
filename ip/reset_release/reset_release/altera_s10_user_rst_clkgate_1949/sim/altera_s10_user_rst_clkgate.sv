// (C) 2001-2025 Altera Corporation. All rights reserved.
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


`timescale 1 ns / 1 ns
module altera_s10_user_rst_clkgate (
	output logic ninit_done
);

	localparam USER_RESET_DELAY = 0;
	
	initial begin
		#0 ninit_done = 1;
		#1 ninit_done = 0;
	end
					
	
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "BfqIHX5jPZBjp297qyQnoddY/ZUy/a6P9WRLOPOfmf0u0plst+Bp5jXfJiNaTOCVXakwwTrEFblSY7a/xf5BFdWNRBCBRv9U4qfHa4V//puVI7hQNkrXX13e2aMl6uc6s/9+E1LxNWOtnFcB2x0G6sF4ZO3VDIbI3lHk7CilVtIVFXdauUq+rO8qIF3n/PvX1zVRrRBJbLmBjPQgI3HmNR2N7VPos5peQ/Z5PmBnqGtRpQBqw9hPEL/BsFv+ImWPSUOeQhnU9o1zPU8WaaZf22uhoACJ3lNWH1AfcPiDvP3WDvT9ZiNogo+DTrGqEwOESewzsm3b68YOD6u1WRIG+vgE/ZLPAidVvwxnM1H6+o6n5E6r+34dA+LBW0EA/xmV/z30sMXBxAXbtpxFWWJ5KfoRZFf/4/TsIHr7GVoEBcWTVmeu2v8Yex69IgsBP8b9RsS+hOlfjikuuCZvXmm/XAA7saWTE53r0LLdr+xzGWjuBYZZlNIKz8vhSzGexwLN0AVnfguBIjHjHMNGTUg27R1Ad7NvhobiQZh7oHrGa5+Cu2sE8HsAFECapRbFeokY0tNtCwFj5lOKM/zd973PDsqNBmeVeFNawjrm3gmGs3vtefYwYBCa5pgZmggcocremO1BwkWD+IbOo7DLrK2u4ZkduHx3CtEo+wtPwDsmEodeGiLzBpt1VDhpwmJwRdhLpVIPjsh1isCwL6LzMBdOu8iCGW4vgvY0ozj4bZ4YFyeiQJQv5OhKwmVcizdSGPBsAizOIJ+meavTbE/UGxLuiu4nXhXhsvISmVa88Dh1c624qM4DKA1vqCBNW82SuLK04JMlfvvVmTdv29Q+ibMdXaSeb1rssfHyLmuOw3bajfJvGY7gkDQ7TX8Lx+YmxTmQpHk0LnsTsLAG+Fv/11r9p6jwJ5CyCNdAIrljbGUNSsZc7mKww08zzQ1nZr8wtvhnckfouNb5fdOQZ8ieOqQfZ5GyU/5QxhgGZ34Ucek8osV8b3CqdSoc+K9hG/v/iBM8"
`endif