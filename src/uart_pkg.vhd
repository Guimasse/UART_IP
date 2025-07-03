library ieee;
use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

package uart_pkg is
  --------------------------
  -- Component declaraton
  --------------------------

  -- UART_TX
  component uart_tx is
    generic(
      SYNC_RST          : boolean := false;
      RST_VALUE         : std_logic := '0';
      DEFAULT_BAUD_RATE : integer range 0 to 115200 := 9600
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
  end component uart_tx;

  -- UART_RX
  component uart_rx is
    generic(
      SYNC_RST          : boolean := false;
      RST_VALUE         : std_logic := '0';
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
  end component uart_rx;

  -- UART
  Component uart is
    generic(
      SYNC_RST          : boolean := false;
      RST_VALUE         : std_logic := '0';
      DEFAULT_BAUD_RATE : integer range 0 to 115200 := 9600
    );
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

      -- UART communication
      EXT_UART_TX       : out std_logic;
      EXT_UART_RX       : in  std_logic
    );
  end component;

end package uart_pkg;

package body uart_pkg is
end package body uart_pkg;