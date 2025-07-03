-- ==============================================================================================
-- Name of unit : UART_RX
-- Author : Guillaume Massé
-- Description : UART frame receiver block
-- ==============================================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
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
end uart_rx;

architecture behavior of uart_rx is

  Component axi_stream_fifo is
    generic(
      SYNC_RST    : boolean := false;
      RST_VALUE   : std_logic := '0';
      FIFO_DEPTH  : integer := 256;
      ADDR_WIDTH  : integer := 8 -- log2(256) = 8
    );
    Port (
      CLK       : in  std_logic;
      RST       : in  std_logic;

      -- AXI-Stream Slave Interface (input)
      S_TDATA   : in  std_logic_vector(7 downto 0);
      S_TVALID  : in  std_logic;
      S_TREADY  : out std_logic;

      -- AXI-Stream Master Interface (output)
      M_TDATA   : out std_logic_vector(7 downto 0);
      M_TVALID  : out std_logic;
      M_TREADY  : in  std_logic
    );
  end component;

  type state_type is (IDLE, START, RECEIVE, END_ST);
  signal uart_state           : state_type;
  
  signal uart_data            : std_logic_vector(7 downto 0);
  signal int_fifo_s_tdata     : std_logic_vector(7 downto 0);
  signal int_fifo_s_tvalid    : std_logic;
  signal int_fifo_s_tready    : std_logic;
      
  signal uart_rx_reg          : std_logic; 
  signal start_rate           : std_logic;
  signal receive_data_cnt     : integer range 0 to 7;
      
  signal uart_tick            : std_logic;
  signal uart_cnt             : integer range 0 to 5208; -- maximum value of the counter if the baud rate is 9600
  signal max_value_uart_cnt   : integer range 0 to 5208;
  
  signal sampling_cnt         : integer range 0 to 2604;

begin

  inst_axi_stream_fifo : axi_stream_fifo
    generic map(
      SYNC_RST      => SYNC_RST,
      RST_VALUE     => RST_VALUE,
      FIFO_DEPTH    => 256,
      ADDR_WIDTH    => 8
    )
    port map(
      CLK       => CLK,
      RST       => RST,

      -- AXI-Stream Slave Interface (input)
      S_TDATA   => int_fifo_s_tdata,
      S_TVALID  => int_fifo_s_tvalid,
      S_TREADY  => int_fifo_s_tready,

      -- AXI-Stream Master Interface (output)
      M_TDATA   => M_TDATA,
      M_TVALID  => M_TVALID,
      M_TREADY  => M_TREADY
    );

  max_value_uart_cnt   <= 5208; --50_000_000/DEFAULT_BAUD_RATE;

  -- process of generating a UART tick to pace the reception
  P_RATE: process (CLK, RST)
  begin
    
    -- Async Reset
    if (not SYNC_RST) and (RST = RST_VALUE) then
      uart_cnt   <= 0;
      uart_tick  <= '0';
      
    elsif rising_edge(CLK) then

      -- Sync Reset
      if SYNC_RST and (RST = RST_VALUE) then
        uart_cnt   <= 0;
        uart_tick  <= '0';

      else
        -- If FSM is not in IDLE state
        if start_rate = '1' then
          if uart_cnt < max_value_uart_cnt then
            uart_cnt  <= uart_cnt + 1;
            uart_tick <= '0';
          else
            uart_tick <= '1';
            uart_cnt  <= 0;
          end if;
        -- IDLE state
        else
          uart_cnt <= 0;

        end if;
      end if;
    end if;
  end process P_RATE;


  -- Process with FSM to receive UART trame
  P_RECEIVED: Process(CLK, RST)
  begin
  
    -- Async Reset
    if (not SYNC_RST) and (RST = RST_VALUE) then
      uart_state         <= IDLE;
      sampling_cnt       <=  0;
      receive_data_cnt   <=  0;
      uart_rx_reg        <= '0';
      start_rate         <= '0';
      int_fifo_s_tvalid  <= '0';
      uart_data          <= (others => '0');
      int_fifo_s_tdata   <= (others => '0');
      
    elsif rising_edge(CLK) then

      -- Sync Reset
      if SYNC_RST and (RST = RST_VALUE) then
        uart_state         <= IDLE;
        sampling_cnt       <=  0;
        receive_data_cnt   <=  0;
        uart_rx_reg        <= '0';
        start_rate         <= '0';
        int_fifo_s_tvalid  <= '0';
        uart_data          <= (others => '0');
        int_fifo_s_tdata   <= (others => '0');

      else

        -- FSM for UART reception
        case uart_state is

          -- START bit detection
          when IDLE =>
            uart_rx_reg       <= UART_RX;
            int_fifo_s_tvalid <= '0';
            if (uart_rx_reg = '1' and not(UART_RX = '1')) then
              uart_state <= START;
            else
              uart_state <= IDLE;
            end if;
            
          -- sampling calibration
          when START =>
            sampling_cnt <= sampling_cnt + 1;
            if sampling_cnt = 2603 then
              start_rate   <= '1';
              uart_state   <= RECEIVE;
            end if;
            
          -- Read data from UART
          when RECEIVE =>
            if uart_tick = '1' then
              if (receive_data_cnt <7) then
                uart_data(receive_data_cnt)     <= UART_RX; -- receiving bits in serial
                receive_data_cnt                <= receive_data_cnt + 1;
              else
                uart_data(receive_data_cnt)     <= UART_RX;      
                uart_state                      <= END_ST;
                receive_data_cnt                <=  0;
              end if;
            end if;
            
          -- Reset state
          when END_ST =>
            if uart_tick = '1' then
              uart_state         <= IDLE;
              start_rate         <= '0';
              receive_data_cnt   <=  0;
              sampling_cnt       <=  0;
              int_fifo_s_tdata   <= uart_data;
              int_fifo_s_tvalid  <= '1';

            end if;
          end case;
        end if;
    end if;
  end Process P_RECEIVED;
  
end behavior;