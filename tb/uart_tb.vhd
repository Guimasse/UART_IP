-- ==============================================================================================
-- Name of unit : UART_TB
-- Author : Guillaume Massé
-- Description : Testbench of uart ip
-- ==============================================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

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
  component uart is
    port(
      CLK 			    : in  std_logic;
      RST	 		      : in  std_logic;
      
      -- Avalon Bus
      CHIPSELECT 	  : in  std_logic;
      ADDRESS 		  : in  std_logic_vector(1 downto 0);
      WRITE 		    : in  std_logic;
      WRITEDATA 	  : in  std_logic_vector(31 downto 0);
      READ 			    : in  std_logic;
      READDATA 	    : out std_logic_vector(31 downto 0);
      WAITREQUEST	  : out std_logic;
      
      -- External signals
      EXT_UART_TX   : out std_logic;
      EXT_UART_RX   : in  std_logic;

      IRQ           : out std_logic
    );
  end component;

  --------------------------
  -- Signal declaraton
  --------------------------
  signal int_clk          : std_logic;
  signal int_rst          : std_logic;

  signal int_chipselect   : std_logic;
  signal int_address      : std_logic_vector(1 downto 0);
  signal int_write        : std_logic;
  signal int_writedata    : std_logic_vector(31 downto 0);
  signal int_read         : std_logic;
  signal int_readdata     : std_logic_vector(31 downto 0);
  signal int_waitrequest  : std_logic;

  signal int_ext_uart_tx  : std_logic;
  signal int_ext_uart_rx  : std_logic;
  signal int_irq          : std_logic;

  signal stop_read        : std_logic;

begin

  -- Instantiation of UART module
  inst_uart : uart
    port map (
      CLK 			    => int_clk,
      RST	 		      => int_rst,
      
      -- Avalon Bus
      CHIPSELECT 	  => int_chipselect,
      ADDRESS 		  => int_address,
      WRITE 		    => int_write,
      WRITEDATA 	  => int_writedata,
      READ 			    => int_read,
      READDATA 	    => int_readdata,
      WAITREQUEST	  => int_waitrequest,
      
      -- External signals
      EXT_UART_TX   => int_ext_uart_tx,
      EXT_UART_RX   => int_ext_uart_tx,

      IRQ           => int_irq
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

  -- Process to write on AXIS bus
  P_WRITE_AXIS : process
    variable seed_send    : integer := 987654321;
    variable random_byte  : std_logic_vector(7 downto 0);
  begin
  
    -- Initial reset
    int_address   <= "00";
    int_write     <= '0';
    int_writedata <= (others => '0');
  
    wait until int_rst = '1';
  
    -- Send data into FIFO
    for i in 1 to 10 loop
      wait until rising_edge(int_clk) and int_waitrequest = '0';
      
      -- Generate pseudo-random byte
      get_random_byte(seed_send, random_byte);
      
      int_writedata   <= x"000000" & random_byte;
      int_write       <= '1';
      int_chipselect  <= '1';
    end loop;

    wait until rising_edge(int_clk);
  
    int_write       <= '0';
    int_writedata   <= (others => '0');

    wait;
  end process;

  -- Process to read UART trame
  P_READ_UART : process
    variable seed_receive : integer := 987654321;
    variable random_byte  : std_logic_vector(7 downto 0);
    variable data_read    : std_logic_vector(7 downto 0);
  begin

    wait until rising_edge(int_rst);

    -- Read UART
    for i in 1 to 10 loop
      wait until falling_edge(int_ext_uart_tx);

      wait for 156 us;
      -- Read data from UART bus
      for j in 0 to 7 loop
        -- report "sampling" severity note;
        data_read(j) := int_ext_uart_tx;
        wait for 104 us;
      end loop;
        
      wait for 52 us;

      -- Generate pseudo-random byte
      get_random_byte(seed_receive, random_byte);

      -- Check if data received is correct
      if data_read = random_byte then
        assert false
          report "Read UART #" & integer'image(i) & " : x" & 
            to_hstring(data_read) & " | expected : x" & to_hstring(random_byte) & ""
          severity note;
      else
        assert false
          report "Read UART #" & integer'image(i) & " : x" & 
            to_hstring(data_read) & " | expected : x" & to_hstring(random_byte) & ""
          severity error;
      end if;
    end loop;

    -- -- Stop simulation
    -- assert false report "Test finished" severity failure;
    -- wait;
  end process;

  -- Process read AXIS bus
  P_READ_AXIS: process
    variable seed_receive : integer := 987654321;
    variable random_byte  : std_logic_vector(7 downto 0);
  begin
    -- Initial reset
    int_read <= '0';
    wait until int_rst = '1'; -- wait reset
    
    -- Loop to read data
    for i in 1 to 10 loop
      wait until rising_edge(int_clk) and int_irq = '1';
      int_read <= '1';
      wait until rising_edge(int_clk);
      int_read <= '0';

      -- Generate pseudo-random byte
      get_random_byte(seed_receive, random_byte);

      -- Check if data received is correct
      if int_readdata(7 downto 0) = random_byte then
        assert false
          report "Read AXIS #" & integer'image(i) & " : x" & 
            to_hstring(int_readdata(7 downto 0)) & " | expected : x" & to_hstring(random_byte) & ""
          severity note;
      else
        assert false
          report "Read AXIS #" & integer'image(i) & " : x" & 
            to_hstring(int_readdata(7 downto 0)) & " | expected : x" & to_hstring(random_byte) & ""
          severity error;
      end if;
    end loop;

    wait for 1040 us;

    -- Stop simulation
    assert false report "Test finished" severity failure;
    wait;
  end process;

end description;
