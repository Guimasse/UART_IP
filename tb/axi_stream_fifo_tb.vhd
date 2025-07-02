-- ==============================================================================================
-- Name of unit : AXI_STREAM_FIFO_TB
-- Author : Guillaume Massé
-- Description : Testbench of axi_stream_fifo
-- ==============================================================================================
library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

use work.simu_pkg.all;

entity testbench is
end testbench;

architecture description of testbench is

  --------------------------
  -- Constant declaraton
  --------------------------
  constant CLK_PERIOD : time := 20 ns; --50 MHz
	 
  --------------------------
  -- Component declaraton
  --------------------------
	component axi_stream_fifo is
		generic(
			RESET_VALUE : std_logic := '0';
			FIFO_DEPTH 	: integer := 256;
			ADDR_WIDTH 	: integer := 8 -- log2(256) = 8
		);
		Port (
			CLK           : in  std_logic;
			RST           : in  std_logic;

			-- AXI-Stream Slave Interface (input)
			int_s_tdata   : in  std_logic_vector(7 downto 0);
			int_s_tvalid  : in  std_logic;
			int_s_tready  : out std_logic;

			-- AXI-Stream Master Interface (output)
			int_m_tdata   : out std_logic_vector(7 downto 0);
			int_m_tvalid  : out std_logic;
			int_m_tready  : in  std_logic
		);
	end component;

  --------------------------
  -- Signal declaraton
  --------------------------
	signal int_clk        : std_logic;
	signal int_rst        : std_logic;

	signal int_s_tdata    : std_logic_vector(7 downto 0);
	signal int_s_tvalid   : std_logic;
	signal int_s_tready   : std_logic;

	signal int_m_tdata    : std_logic_vector(7 downto 0);
	signal int_m_tvalid   : std_logic;
	signal int_m_tready   : std_logic;

  signal sync_process   : std_logic;

begin

  -- instantiation of axi_stream_fifo
  inst_axi_stream_fifo: axi_stream_fifo
    port map (
      CLK          => int_clk, 
      RST          => int_rst, 
      int_s_tdata  => int_s_tdata, 
      int_s_tvalid => int_s_tvalid, 
      int_s_tready => int_s_tready,
      int_m_tdata  => int_m_tdata, 
      int_m_tvalid => int_m_tvalid, 
      int_m_tready => int_m_tready
    );

  -- Process to manage clock
  P_CLK: process
  begin
    int_clk <= '0';
    wait for CLK_PERIOD/2;
    int_clk <= '1';
    wait for CLK_PERIOD/2;
  end process;

  -- Process to manage reset
  P_RST: process
  begin
    int_rst <= '0';
    wait for 45 ns;
    int_rst <= '1';
    wait;
  end process;

  -- Process write into FIFO
  P_WRITE: process
    variable seed_send : integer := 987654321;
    variable random_byte  : std_logic_vector(7 downto 0);
  begin
    -- Initial reset
    int_s_tvalid <= '0';
    int_s_tdata  <= (others => '0');
    wait until int_rst = '1';

    -- Send data into FIFO
    for i in 0 to 270 loop
      get_random_byte(seed_send, random_byte);
      int_s_tdata <= random_byte;
      int_s_tvalid <= '1';
      wait until rising_edge(int_clk) and int_s_tready = '1';
    end loop;

    int_s_tvalid <= '0';

    wait until sync_process = '1';

    -- Send data into FIFO
    for i in 0 to 300 loop
      get_random_byte(seed_send, random_byte);
      int_s_tdata <= random_byte;
      int_s_tvalid <= '1';
      wait until rising_edge(int_clk) and int_s_tready = '1';
    end loop;
    int_s_tvalid <= '0';

  end process;

  -- Process read FIFO content
  P_READ: process
    variable seed_receive : integer := 987654321;
    variable random_byte  : std_logic_vector(7 downto 0);
  begin
    -- Initial reset
    int_m_tready <= '0';
    sync_process <= '0';
    wait until int_rst = '1';
    wait for 6 us;

    wait until rising_edge(int_clk);
    int_m_tready  <= '1';
    
    -- Send data into FIFO
    for i in 0 to 270 loop
      wait until rising_edge(int_clk) and int_m_tvalid = '1';
      get_random_byte(seed_receive, random_byte);
      if int_m_tdata = random_byte then
          assert false
            report "Octet #" & integer'image(i) & " : x" & 
              to_hstring(int_m_tdata) & " | expected : x" & to_hstring(random_byte) & ""
            severity note;
        else
          assert false
            report "Octet #" & integer'image(i) & " : x" & 
              to_hstring(int_m_tdata) & " | expected : x" & to_hstring(random_byte) & ""
            severity error;
        end if;
    end loop;

    int_m_tready  <= '0';

    wait for 1 us;
    sync_process <= '1';

    wait until rising_edge(int_clk);
    int_m_tready  <= '1';

    -- Send data into FIFO
    for i in 0 to 300 loop
      wait until rising_edge(int_clk) and int_m_tvalid = '1';
      
      -- Generate pseudo-random byte
      get_random_byte(seed_receive, random_byte);

      -- Check if data received is correct
      if int_m_tdata = random_byte then
          assert false
            report "Octet #" & integer'image(i) & " : x" & 
              to_hex_string(int_m_tdata) & " | expected : x" & to_hex_string(random_byte) & """"
            severity note;
        else
          assert false
            report "Octet #" & integer'image(i) & " : x" & 
              to_hex_string(int_m_tdata) & " | expected : x" & to_hex_string(random_byte) & """"
            severity error;
        end if;
    end loop;

    -- Stop simulation
    assert false report "Test finished" severity failure;
  end process;

end description;
