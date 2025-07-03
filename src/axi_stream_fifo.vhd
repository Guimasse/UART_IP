-- ==============================================================================================
-- Name of unit : AXI_STREAM_FIFO
-- Author : Guillaume Massé
-- Description : FIFO (First In, First Out) block operating with AXI-Stream bus
-- ==============================================================================================
library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

entity axi_stream_fifo is
  generic(
    SYNC_RST      : boolean := false;
    RST_VALUE     : std_logic := '0';
    FIFO_DEPTH    : integer := 256;
    ADDR_WIDTH    : integer := 8 -- log2(256) = 8
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
end axi_stream_fifo;

architecture behavior of axi_stream_fifo is

  type fifo_type is array(0 to FIFO_DEPTH - 1) of std_logic_vector(7 downto 0);
  signal fifo_mem     : fifo_type;

  signal wr_ptr       : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal rd_ptr       : unsigned(ADDR_WIDTH - 1 downto 0) := (others => '0');
  signal fifo_count   : unsigned(ADDR_WIDTH downto 0) := (others => '0'); -- 9 bits to track 0..256

  signal empty        : std_logic;
  signal full         : std_logic;
  
  signal s_tready_int : std_logic;
  signal m_tvalid_int : std_logic;
  
  signal comp_s_m     : std_logic_vector(3 downto 0);

begin

  empty     <= '1' when fifo_count = 0 else '0';
  full      <= '1' when fifo_count = FIFO_DEPTH else '0';
  
  S_TREADY  <= s_tready_int;
  M_TVALID  <= m_tvalid_int;
  
  comp_s_m  <= S_TVALID & s_tready_int & m_tvalid_int & M_TREADY;

  -- Write Logic
  P_WRITE: process(CLK, RST)
  begin
  
    -- Async Reset
    if (not SYNC_RST) and (RST = RST_VALUE) then
      wr_ptr <= (others => '0');
    
    elsif rising_edge(CLK) then

      -- Sync Reset
      if SYNC_RST and (RST = RST_VALUE) then
        wr_ptr <= (others => '0');
      
      else
        if (S_TVALID = '1' and s_tready_int = '1') then
          fifo_mem(to_integer(wr_ptr))   <= S_TDATA;
          wr_ptr                         <= wr_ptr + 1;

        end if;
      end if;
    end if;
  end process;

  -- Read Logic
  P_READ: process(CLK, RST)
  begin
    
    -- Async Reset
    if (not SYNC_RST) and (RST = RST_VALUE) then
      rd_ptr <= (others => '0');

    elsif rising_edge(CLK) then  

      -- Sync Reset
      if SYNC_RST and (RST = RST_VALUE) then
        rd_ptr <= (others => '0');

      else
        if (m_tvalid_int = '1' and M_TREADY = '1') then
          rd_ptr <= rd_ptr + 1;

        end if;
      end if;
    end if;
  end process;

  -- FIFO Count Logic
  FIFO_CNT: process(CLK, RST)
  begin
  
    -- Async Reset
    if (not SYNC_RST) and (RST = RST_VALUE) then
        fifo_count <= (others => '0');
        
    elsif rising_edge(CLK) then

      -- Sync Reset
      if SYNC_RST and (RST = RST_VALUE) then
        fifo_count <= (others => '0');

      else
        if (S_TVALID = '1') and (s_tready_int = '1') and (m_tvalid_int = '1') and (M_TREADY = '1') then
          null;
        
        elsif S_TVALID = '1' and s_tready_int = '1' then
          if full = '0' then
            fifo_count <= fifo_count + 1;
          end if;
          
        elsif m_tvalid_int = '1' and M_TREADY = '1' then
          if empty = '0' then
            fifo_count <= fifo_count - 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Output logic
  M_TDATA       <= fifo_mem(to_integer(rd_ptr));
  m_tvalid_int  <= '1' when fifo_count > 0 else '0';
  s_tready_int  <= '1' when fifo_count < FIFO_DEPTH else '0';

end behavior;
