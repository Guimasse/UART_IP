-- ==============================================================================================
-- Name of unit : UART_RX_TB
-- Author : Guillaume Massé
-- Description : Testbench of uart_rx block
-- ==============================================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.simu_pkg.all;
use work.uart_pkg.uart_rx;

entity testbench is
end testbench;

architecture description of testbench is

  --------------------------
  -- Constant declaraton
  --------------------------
  constant CLK_PERIOD : time := 20 ns; --50 MHz

  --------------------------
  -- Signal declaraton
  --------------------------
  signal int_clk      : std_logic;
  signal int_rst      : std_logic;

  signal int_m_tdata  : std_logic_vector(7 downto 0);
  signal int_m_tready : std_logic;
  signal int_m_tvalid : std_logic;

  signal int_uart_rx  : std_logic;

begin

  -- instantiation of UART_RX module
  inst_uart_rx: uart_rx
    port map (
        CLK       => int_clk,
        RST       => int_rst,
        M_TDATA   => int_m_tdata,
        M_TVALID  => int_m_tvalid,
        M_TREADY  => int_m_tready,
        UART_RX   => int_uart_rx 
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

  -- Process write on UART
  P_WRITE_UART: process
    variable seed_send    : integer := 987654321;
    variable random_byte  : std_logic_vector(7 downto 0);
  begin
    -- Initial reset
    int_uart_rx <= '1';
    wait until int_rst = '1'; -- wait reset
    wait for 167 ns;
    
    -- Send UART Trame
    for i in 0 to 10 loop
      -- Generate pseudo-random byte
      get_random_byte(seed_send, random_byte); 

      -- START bit
      wait for 104 us;      
      int_uart_rx <= '0';
      
      -- Send data
      report "Send data : x" & to_hstring(random_byte);
      for j in 0 to 7 loop
        wait for 104 us;
        int_uart_rx <= random_byte(j);
      end loop;

      -- STOP bit
      wait for 104 us;
      int_uart_rx <= '1';
      wait for 104 us;

    end loop;
    
    wait;
  end process;

  -- Process read AXIS bus
  P_READ_AXIS: process
    variable seed_receive : integer := 987654321;
    variable random_byte  : std_logic_vector(7 downto 0);
  begin
    -- Initial reset
    int_m_tready <= '0';
    wait until int_rst = '1'; -- wait reset
    
    -- Loop to read data
    for i in 0 to 10 loop
      wait until rising_edge(int_clk) and int_m_tvalid = '1';
      int_m_tready <= '1';
      wait until rising_edge(int_clk);
      int_m_tready <= '0';

      -- Generate pseudo-random byte
      get_random_byte(seed_receive, random_byte);

      -- Check if data received is correct
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

    wait for 1040 us;

    -- Stop simulation
    assert false report "Test finished" severity failure;

    wait;
  end process;

end description;
