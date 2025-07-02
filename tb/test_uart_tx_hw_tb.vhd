-- ==============================================================================================
-- Name of unit : TEST_UART_TX_HW_TB
-- Author : Guillaume Massé
-- Description : Testbench of test_uart_tx_hw
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
	constant CLK_PERIOD : time := 20 ns; -- 50 MHz

  --------------------------
  -- Component declaraton
  --------------------------
  component test_uart_tx_hw is
    port(
      SW 					    : in  std_logic_vector(9 downto 0); -- SW represents the switches
      LED 				    : out std_logic_vector(9 downto 0); -- LED represents the leds
      MAX10_CLK1_50 	: in  std_logic; 							      -- clock
      KEY 				    : in  std_logic_vector(1 downto 0); -- push buttons: KEY(0) is used for reset
      HEX0				    : out std_logic_vector(6 downto 0); -- 7seg(0)
      HEX1				    : out std_logic_vector(6 downto 0); -- 7seg(1)
      HEX2				    : out std_logic_vector(6 downto 0);	-- 7seg(2)
      HEX3				    : out std_logic_vector(6 downto 0);	-- 7seg(3)
      HEX4				    : out std_logic_vector(6 downto 0); -- 7seg(4)
      HEX5				    : out std_logic_vector(6 downto 0);	-- 7seg(5)
      GPIO_UART_TX 		: out std_logic
    );
  end component ;
	
  --------------------------
  -- Signal declaraton
  --------------------------
	type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);
	constant test_input : byte_array := (x"30", x"35");

	signal int_sw 					  : std_logic_vector(9 downto 0);
  signal int_led 				    : std_logic_vector(9 downto 0);
  signal int_max10_clk1_50  : std_logic; 							   
  signal int_rst 				    : std_logic;
  signal int_key 				    : std_logic;
  signal int_gpio_uart_tx   : std_logic;
	
begin

  -- Instantiation of test_uart_tx_hw module
  ints_test_uart_tx_hw : test_uart_tx_hw
    port map (
      SW 					    => int_sw, 					
      LED 				    => int_led, 				  
      MAX10_CLK1_50 	=> int_max10_clk1_50,
      KEY(0)			    => int_rst, 				  
      KEY(1)			    => int_key, 	
      HEX0				    => open,				  
      HEX1				    => open,				  
      HEX2				    => open,				  
      HEX3				    => open,				  
      HEX4				    => open,				  
      HEX5				    => open,				  
      GPIO_UART_TX 		=> int_gpio_uart_tx 
    );

  -- Process to manage clock
  P_CLK: process
  begin
      int_max10_clk1_50 <= '0';
      wait for CLK_PERIOD/2;
      int_max10_clk1_50 <= '1';
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

  -- Process to push button
  P_KEY: process
  begin
    
    -- Initial reset
    int_key <= '0';
    int_sw  <= (others => '0');
  
    wait until int_rst = '1';

    int_key <= '1';

    -- Wait a few cycles
    wait for CLK_PERIOD;
  
    int_key <= '0';

    wait for 1 ms;

    int_sw(3 downto 0)  <= x"5";
    int_key             <= '1';

    wait for CLK_PERIOD;

    int_key <= '0';
  
    wait;
  end process;

  -- Process to read UART trame
  P_READ: process
    variable seed_receive : integer := 987654321;
    variable random_byte  : std_logic_vector(7 downto 0);
    variable data_read    : std_logic_vector(7 downto 0);
  begin

    wait until rising_edge(int_rst);

    -- Read
    for i in 0 to 1 loop
      wait until falling_edge(int_gpio_uart_tx);

      wait for 156 us;
      -- Read data from UART bus
      for j in 0 to 7 loop
        -- report "sampling" severity note;
        data_read(j) := int_gpio_uart_tx;
        wait for 104 us;
      end loop;
        
      wait for 52 us;

      -- Check if data received is correct
      if data_read = test_input(i) then
        assert false
          report "Octet #" & integer'image(i) & " : x" & 
            to_hstring(data_read) & " | expected : x" & to_hstring(test_input(i)) & ""
          severity note;
      else
        assert false
          report "Octet #" & integer'image(i) & " : x" & 
            to_hstring(data_read) & " | expected : x" & to_hstring(test_input(i)) & ""
          severity error;
      end if;
    end loop;
    
    -- Stop simulation
    assert false report "Test finished" severity failure;
    wait;
  end process;

end description;
