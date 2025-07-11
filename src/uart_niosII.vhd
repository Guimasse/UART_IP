-- ==============================================================================================
-- Name of unit : UART_NIOSII
-- Author : Guillaume Massé
-- Description : UART block to send data from Avalon bus to UART
--               or receive from UART to Avalon bus
-- ==============================================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.uart_pkg.all;

entity uart_niosII is
  generic(
    ASYNC_RST         : boolean := false;
    RST_VALUE         : std_logic := '0';
    DEFAULT_BAUD_RATE : integer range 0 to 115200 := 9600
  );
  port(
    CLK           : in  std_logic;
    RST           : in  std_logic;
    
    -- Avalon Bus
    CHIPSELECT    : in  std_logic;
    ADDRESS       : in  std_logic_vector(1 downto 0);
    WRITE         : in  std_logic;
    WRITEDATA     : in  std_logic_vector(31 downto 0);
    READ          : in  std_logic;
    READDATA      : out std_logic_vector(31 downto 0);
    WAITREQUEST   : out std_logic;
    
    -- External signals
    EXT_UART_TX   : out std_logic;
    EXT_UART_RX   : in  std_logic;

    -- Interruption
    IRQ           : out std_logic
  );
end uart_niosII;

architecture behavior of uart_niosII is

  --------------------------
  -- Constant declaraton
  --------------------------
  constant ADDR_TX       : std_logic_vector(1 downto 0) := b"00";
  constant ADDR_RX       : std_logic_vector(1 downto 0) := b"01";
  constant ADDR_CONFIG   : std_logic_vector(1 downto 0) := b"10";
  
  --------------------------
  -- Signal declaraton
  --------------------------
  signal uart_tx_s_tdata  : std_logic_vector(7 downto 0);
  signal uart_tx_s_tvalid : std_logic;
  signal uart_tx_s_tready : std_logic;

  signal uart_rx_m_tdata  : std_logic_vector(7 downto 0);
  signal uart_rx_m_tvalid : std_logic;
  signal uart_rx_m_tready : std_logic;

begin

  -- instantiation of UART module
  inst_uart : uart
    generic map(
      SYNC_RST          => false,
      RST_VALUE         => '0',
      DEFAULT_BAUD_RATE => 9600
    )
    port map(
      CLK        => CLK,  
      RST        => RST,

      -- Slave AXI Stream (TX side)
      S_TDATA    => uart_tx_s_tdata,
      S_TVALID   => uart_tx_s_tvalid,
      S_TREADY   => uart_tx_s_tready,
      
      -- Master AXI Stream (RX side)
      M_TDATA    => uart_rx_m_tdata,
      M_TVALID   => uart_rx_m_tvalid,
      M_TREADY   => uart_rx_m_tready,

      -- UART communication
      EXT_UART_TX    => EXT_UART_TX,
      EXT_UART_RX    => EXT_UART_RX
    );
  
  -- Process to manage TX
  P_TX : process(CLK)
  begin
    if RST = '0' then
      uart_tx_s_tdata   <= (others => '0');
      uart_tx_s_tvalid  <= '0';
    elsif rising_edge(CLK) then
      if (WRITE = '1') then
        if (ADDRESS = ADDR_TX) then
          uart_tx_s_tdata   <= WRITEDATA(7 downto 0);
          uart_tx_s_tvalid  <= '1';
        else
          uart_tx_s_tvalid  <= '0';
        end if;             
      else
        uart_tx_s_tvalid <= '0';
      end if;
    end if; 
  end process;

  -- Process to manage RX
  P_RX : process(CLK)
  begin
    if RST = '0' then
      uart_rx_m_tready  <= '0';
      READDATA          <= (others => '0');
    else
      if (READ = '1') then
        if (ADDRESS = ADDR_TX) then
          READDATA          <= x"000000" & uart_rx_m_tdata(7 downto 0);
          uart_rx_m_tready  <= '1';
        else
          uart_rx_m_tready  <= '0';
        end if;             
      else
        uart_rx_m_tready <= '0';
      end if;
    end if; 
  end process;

  WAITREQUEST <= not(uart_tx_s_tready);
  IRQ         <= uart_rx_m_tvalid;
    
end behavior;