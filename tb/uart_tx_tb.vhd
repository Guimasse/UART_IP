-- ==============================================================================================
-- Name of unit : UART_TX_TB
-- Author : Guillaume Massé
-- Description : Testbench of uart_tx block
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
  component uart_tx is
    generic(
      RESET_VALUE     : std_logic := '0';
      DEFAULT_BAUD_RATE   : integer range 0 to 115200 := 9600
    );
    port
    (
      CLK       : in  std_logic;
      RST       : in  std_logic;

            -- AXI-Stream bus
      S_TDATA     : in  std_logic_vector(7 downto 0);
      S_TVALID    : in  std_logic; -- input to start the process
      S_TREADY    : out std_logic;

            -- UART
      UART_TX     : out std_logic
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

  signal int_uart_tx    : std_logic;
  signal int_uart_tx_reg    : std_logic;

  signal stop_read      : std_logic;

begin

  -- Instantiation of UART_TX module
  inst_uart_tx: uart_tx
    port map (
      CLK         => int_clk,
      RST         => int_rst,
      S_TDATA     => int_s_tdata,
      S_TVALID    => int_s_tvalid,
      S_TREADY    => int_s_tready,
      UART_TX     => int_uart_tx
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

    wait for 17 ms;
    int_rst <= '0';
    wait for 45 ns;
    int_rst <= '1';

    wait;
  end process;

  -- Process to generate signal to informe other process of resert assertion
  P_CHECK_RESET: process
  begin

    -- initial value
    stop_read <= '0';
    -- wait intial reset
    wait until rising_edge(int_rst);

    -- wait reset assert
    wait until falling_edge(int_rst);

    -- Inform other process when reset assert
    stop_read <= '1';
    report "reset assert" severity note;

    wait;
  end process;

  -- Process to write on AXIS bus
  P_WRITE: process
    variable seed_send    : integer := 987654321;
    variable random_byte  : std_logic_vector(7 downto 0);
  begin
  
    -- Initial reset
    int_s_tvalid <= '0';
    int_s_tdata  <= (others => '0');
  
    wait until int_rst = '1';

    -- Send data into FIFO
    for i in 0 to 260 loop
      wait until rising_edge(int_clk) and int_s_tready = '1';

      -- Generate pseudo-random byte
      get_random_byte(seed_send, random_byte); 

      int_s_tdata   <= random_byte;
      int_s_tvalid  <= '1';
    end loop;

    int_s_tvalid <= '0';
    int_s_tdata  <= (others => '0');

    wait until int_rst = '0';
    wait until int_rst = '1';

    -- Wait a few cycles
    wait for 1 ms;

    seed_send := 987654321;
  
    -- Send data into FIFO
    for i in 1 to 10 loop
      wait until rising_edge(int_clk) and int_s_tready = '1';
      
      -- Generate pseudo-random byte
      get_random_byte(seed_send, random_byte);
      
      int_s_tdata   <= random_byte;
      int_s_tvalid  <= '1';
    end loop;

    wait until rising_edge(int_clk);
  
    int_s_tvalid    <= '0';
    int_s_tdata   <= (others => '0');

    wait;
  end process;

  -- Process to read UART trame
  P_READ: process
    variable seed_receive : integer := 987654321;
    variable random_byte  : std_logic_vector(7 downto 0);
    variable data_read    : std_logic_vector(7 downto 0);
    variable i            : integer;
  begin

    int_uart_tx_reg <= '1';
    wait until rising_edge(int_rst);

    -- Read phase 1
    i := 0;
    while true loop
      wait until falling_edge(int_uart_tx);

      wait for 156 us;
      -- Read data from UART bus
      for j in 0 to 7 loop
        -- report "sampling" severity note;
        data_read(j) := int_uart_tx;
        wait for 104 us;
      end loop;
        
      wait for 52 us;

      -- Generate pseudo-random byte
      get_random_byte(seed_receive, random_byte);

      -- Check if data received is correct
      if stop_read = '1' then
        exit;
      elsif data_read = random_byte then
        assert false
          report "Octet #" & integer'image(i) & " : x" & 
            to_hstring(data_read) & " | expected : x" & to_hstring(random_byte) & ""
          severity note;
      else
        assert false
          report "Octet #" & integer'image(i) & " : x" & 
            to_hstring(data_read) & " | expected : x" & to_hstring(random_byte) & ""
          severity error;
      end if;
      i := i + 1;
    end loop;

    seed_receive := 987654321;

    -- Read phase 2
    for i in 1 to 10 loop
      wait until falling_edge(int_uart_tx);

      wait for 156 us;
      -- Read data from UART bus
      for j in 0 to 7 loop
        -- report "sampling" severity note;
        data_read(j) := int_uart_tx;
        wait for 104 us;
      end loop;
        
      wait for 52 us;

      -- Generate pseudo-random byte
      get_random_byte(seed_receive, random_byte);

      -- Check if data received is correct
      if data_read = random_byte then
        assert false
          report "Octet #" & integer'image(i) & " : x" & 
            to_hstring(data_read) & " | expected : x" & to_hstring(random_byte) & ""
          severity note;
      else
        assert false
          report "Octet #" & integer'image(i) & " : x" & 
            to_hstring(data_read) & " | expected : x" & to_hstring(random_byte) & ""
          severity error;
      end if;
    end loop;

    -- Stop simulation
    assert false report "Test finished" severity failure;
    wait;
  end process;

end description;
