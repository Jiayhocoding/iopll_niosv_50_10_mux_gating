	component target_iopll is
		port (
			refclk             : in  std_logic                    := 'X';             -- clk
			locked             : out std_logic;                                       -- export
			rst                : in  std_logic                    := 'X';             -- reset
			core_avl_address   : in  std_logic_vector(8 downto 0) := (others => 'X'); -- core_avl_address
			core_avl_clk       : in  std_logic                    := 'X';             -- clk
			core_avl_read      : in  std_logic                    := 'X';             -- core_avl_read
			core_avl_readdata  : out std_logic_vector(7 downto 0);                    -- core_avl_readdata
			core_avl_write     : in  std_logic                    := 'X';             -- core_avl_write
			core_avl_writedata : in  std_logic_vector(7 downto 0) := (others => 'X'); -- core_avl_writedata
			outclk_0           : out std_logic;                                       -- clk
			outclk_1           : out std_logic                                        -- clk
		);
	end component target_iopll;

	u0 : component target_iopll
		port map (
			refclk             => CONNECTED_TO_refclk,             --             refclk.clk
			locked             => CONNECTED_TO_locked,             --             locked.export
			rst                => CONNECTED_TO_rst,                --              reset.reset
			core_avl_address   => CONNECTED_TO_core_avl_address,   --   core_avl_address.core_avl_address
			core_avl_clk       => CONNECTED_TO_core_avl_clk,       --       core_avl_clk.clk
			core_avl_read      => CONNECTED_TO_core_avl_read,      --      core_avl_read.core_avl_read
			core_avl_readdata  => CONNECTED_TO_core_avl_readdata,  --  core_avl_readdata.core_avl_readdata
			core_avl_write     => CONNECTED_TO_core_avl_write,     --     core_avl_write.core_avl_write
			core_avl_writedata => CONNECTED_TO_core_avl_writedata, -- core_avl_writedata.core_avl_writedata
			outclk_0           => CONNECTED_TO_outclk_0,           --            outclk0.clk
			outclk_1           => CONNECTED_TO_outclk_1            --            outclk1.clk
		);

