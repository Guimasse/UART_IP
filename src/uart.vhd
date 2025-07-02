-- ==============================================================================================
-- Name of unit : UART
-- Author : Guillaume Massé
-- Description : UART block to send data from Avalon bus to UART
--               or receive from UART to Avalon bus
-- ==============================================================================================
library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

entity uart is
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

    IRQ           : out std_logic
  );
end uart;

architecture behavior of uart is

  --------------------------
  -- Constant declaraton
  --------------------------
  constant ADDR_TX       : std_logic_vector(1 downto 0) := b"00";
  constant ADDR_RX       : std_logic_vector(1 downto 0) := b"01";
  constant ADDR_CONFIG   : std_logic_vector(1 downto 0) := b"10";

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
    -- elsif rising_edge(CLK) then
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
  
  -- instantiation of UART_TX module
  inst_uart_tx : uart_tx
    port map(
      CLK        => CLK,  
      RST        => RST,
      S_TDATA    => uart_tx_s_tdata,
      S_TVALID   => uart_tx_s_tvalid,
      S_TREADY   => uart_tx_s_tready,
      UART_TX    => EXT_UART_TX
    );

  -- instantiation of UART_RX module
  inst_uart_rx: uart_rx
    port map (
        CLK       => CLK,
        RST       => RST,
        M_TDATA   => uart_rx_m_tdata,
        M_TVALID  => uart_rx_m_tvalid,
        M_TREADY  => uart_rx_m_tready,
        UART_RX   => EXT_UART_RX 
    );

  WAITREQUEST <= not(uart_tx_s_tready);
  IRQ         <= uart_rx_m_tvalid;
    
end behavior;