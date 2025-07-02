-- ==============================================================================================
-- Name of unit : UART_TX
-- Author : Guillaume Massé
-- Description : UART frame sending block
-- ==============================================================================================
library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

entity uart_tx is
  generic(
    RESET_VALUE       : std_logic := '0';
    DEFAULT_BAUD_RATE : integer range 0 to 115200 := 9600
  );
  port
  (
    CLK          : in  std_logic;
    RST          : in  std_logic;

    -- AXI-Stream bus
    S_TDATA      : in  std_logic_vector(7 downto 0);
    S_TVALID     : in  std_logic; -- input to start the process
    S_TREADY     : out std_logic;

    -- UART
    UART_TX      : out std_logic
  );
end uart_tx;

architecture behavior of uart_tx is

  Component axi_stream_fifo is
    generic(
      RESET_VALUE : std_logic := '0';
      FIFO_DEPTH   : integer := 256;
      ADDR_WIDTH   : integer := 8 -- log2(256) = 8
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

  -- signal for FSM state
  type state_type is (IDLE, START, SEND, END_ST);
  signal uart_state              : state_type;
      
  -- AXI-Stream signals 
  signal int_fifo_m_tdata        : std_logic_vector(7 downto 0);
  signal int_fifo_m_tdata_reg    : std_logic_vector(7 downto 0); -- tdata register
  signal int_fifo_m_tvalid       : std_logic;
  signal int_fifo_m_tready       : std_logic;
      
  signal start_rate              : std_logic;
  signal send_data_cnt           : integer range 0 to 7;
  
  signal uart_tick               : std_logic;
  signal uart_cnt                : integer range 0 to 5208; -- maximum value of the counter if the baud rate is 9600
  signal max_value_uart_cnt      : integer range 0 to 5208;

begin

  inst_axi_stream_fifo : axi_stream_fifo
    port map(
      CLK       => CLK,
      RST       => RST,

      -- AXI-Stream Slave Interface (input)
      S_TDATA   => S_TDATA,
      S_TVALID  => S_TVALID,
      S_TREADY  => S_TREADY,

      -- AXI-Stream Master Interface (output)
      M_TDATA   => int_fifo_m_tdata,
      M_TVALID  => int_fifo_m_tvalid,
      M_TREADY  => int_fifo_m_tready
    );

  max_value_uart_cnt <= 5208; --50_000_000/DEFAULT_BAUD_RATE;

  -- Process of generating a UART tick to pace the sending
  P_RATE: process (CLK, RST)
  begin
    if (RST = RESET_VALUE) then
      uart_cnt   <=  0;
      uart_tick  <= '0';
      
    elsif rising_edge(CLK) then
      -- If FSM is not in IDLE state
      if start_rate = '1' then
        if uart_cnt  < max_value_uart_cnt then
          uart_cnt   <= uart_cnt + 1;
          uart_tick  <= '0';
        else
          uart_tick  <= '1';
          uart_cnt   <=  0;
        end if;
      -- IDLE state
      else
        uart_tick  <= '0';
        uart_cnt   <= 0;
      end if;
    end if;
  end process P_RATE;

  -- Process with FSM to send UART trame
  P_SEND: Process(CLK, RST)
  begin
  
    -- Reset
    if RST = RESET_VALUE then
      UART_TX            <= '1';
      uart_state         <= IDLE;
      start_rate         <= '0';
      int_fifo_m_tready  <= '1';
      send_data_cnt      <=  0;
      
    elsif rising_edge(CLK) then
    
        -- FSM for UART sending
        case uart_state is
        
          -- Waiting state to waite available data
          when IDLE =>
            if int_fifo_m_tvalid = '1' then
              UART_TX                <= '1';
              uart_state             <= START;
              start_rate             <= '1';
              int_fifo_m_tready      <= '0';
              int_fifo_m_tdata_reg   <= int_fifo_m_tdata;
            else
              uart_state             <= IDLE;
            end if;
            
          -- State to send START bit
          when START =>
            if uart_tick = '1' then
              UART_TX      <='0'; -- sending bit 'start'
              uart_state   <= SEND;
            end if;
            
          -- State with counter to send one byte
          when SEND =>
            if uart_tick = '1' then
              if send_data_cnt < 7 then
                UART_TX        <= int_fifo_m_tdata_reg(send_data_cnt); -- sending bits in serial
                send_data_cnt  <= send_data_cnt + 1;
                uart_state     <= SEND;
              else
                UART_TX        <= int_fifo_m_tdata_reg(send_data_cnt);
                send_data_cnt  <= 0;
                uart_state     <= END_ST;
              end if;
            end if;
            
          -- End state (stop process to generate uart tick)
          when END_ST =>
            if uart_tick = '1' then
              uart_state        <= IDLE;
              int_fifo_m_tready <= '1';
              UART_TX           <= '1'; -- sending bit 'end'
              start_rate        <= '0';
            end if;
            
        end case;
      
    end if;
    
  end Process P_SEND;
  
end behavior;