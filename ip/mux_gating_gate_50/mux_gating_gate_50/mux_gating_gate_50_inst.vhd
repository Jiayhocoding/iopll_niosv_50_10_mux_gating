	component mux_gating_gate_50 is
		port (
			ena    : in  std_logic := 'X'; -- export
			inclk  : in  std_logic := 'X'; -- clk
			outclk : out std_logic         -- clk
		);
	end component mux_gating_gate_50;

	u0 : component mux_gating_gate_50
		port map (
			ena    => CONNECTED_TO_ena,    --    ena.export
			inclk  => CONNECTED_TO_inclk,  --  inclk.clk
			outclk => CONNECTED_TO_outclk  -- outclk.clk
		);

