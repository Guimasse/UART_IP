-- ==============================================================================================
-- Name of unit : UART
-- Author : Guillaume Massé
-- Description : UART block to send data from AXIS bus to UART
--               or receive from UART to AXIS bus
-- ==============================================================================================
library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

entity uart is
  port(
    CLK           : in  std_logic;
    RST           : in  std_logic;
    
    -- Slave AXI Stream (TX side)
    S_TDATA       : in  std_logic_vector(7 downto 0);
    S_TVALID      : in  std_logic;
    S_TREADY      : OUT std_logic;
    
    -- Master AXI Stream (RX side)
    M_TDATA       : out std_logic_vector(7 downto 0);
    M_TVALID      : out std_logic;
    M_TREADY      : in  std_logic;

    -- External signals
    EXT_UART_TX   : out std_logic;
    EXT_UART_RX   : in  std_logic;

    IRQ           : out std_logic
  );
end uart;

architecture behavior of uart is

  --------------------------
  -- Component declaraton
  --------------------------
  component uart_tx is
    generic(
      RESET_VALUE       : std_logic := '0';
      DEFAULT_BAUD_RATE : integer range 0 to 115200 := 115200
    );
    port(
      CLK         : in  std_logic;
      RST         : in  std_logic;

      -- AXI-Stream bus
      S_TDATA     : in  std_logic_vector(7 downto 0);
      S_TVALID    : in  std_logic; -- input to start the process
      S_TREADY    : out std_logic;

      -- UART
      UART_TX     : out std_logic
    );
  end component;

  component uart_rx is
    generic(
      RESET_VALUE       : std_logic := '0';
      DEFAULT_BAUD_RATE : integer range 0 to 115200 := 9600
    );
    port
    (
      CLK         : in  std_logic;
      RST         : in  std_logic;

      -- AXI-Stream bus
      M_TDATA     : out std_logic_vector(7 downto 0);
      M_TVALID    : out std_logic; -- IRQ REQUEST
      M_TREADY    : in  std_logic;

      -- UART
      UART_RX     : in  std_logic
    );
  end component;

begin
  
  -- instantiation of UART_TX module
  inst_uart_tx : uart_tx
    port map(
      CLK        => CLK,  
      RST        => RST,
      S_TDATA    => S_TDATA,
      S_TVALID   => S_TVALID,
      S_TREADY   => S_TREADY,
      UART_TX    => EXT_UART_TX
    );

  -- instantiation of UART_RX module
  inst_uart_rx: uart_rx
    port map (
        CLK       => CLK,
        RST       => RST,
        M_TDATA   => M_TDATA,
        M_TVALID  => M_TVALID,
        M_TREADY  => M_TREADY,
        UART_RX   => EXT_UART_RX 
    );
    
end behavior;