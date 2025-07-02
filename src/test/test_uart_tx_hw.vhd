library ieee;
Use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

entity test_uart_tx_hw is
	port
	(
		SW 					: in  std_logic_vector(9 downto 0); -- SW represents the switches
		LED 				: out std_logic_vector(9 downto 0); -- LED represents the leds
		MAX10_CLK1_50 		: in  std_logic; 							-- clock
		KEY 				: in  std_logic_vector(1 downto 0); -- push buttons: KEY(0) is used for reset
		HEX0				: out std_logic_vector(6 downto 0); -- 7seg(0)
		HEX1				: out std_logic_vector(6 downto 0); -- 7seg(1)
		HEX2				: out std_logic_vector(6 downto 0);	-- 7seg(2)
		HEX3				: out std_logic_vector(6 downto 0);	-- 7seg(3)
		HEX4				: out std_logic_vector(6 downto 0); -- 7seg(4)
		HEX5				: out std_logic_vector(6 downto 0);	-- 7seg(5)
		GPIO_UART_TX 		: out std_logic
	);
end test_uart_tx_hw ;

architecture RTL of test_uart_tx_hw is

	component uart_tx is
		generic(
			RESET_VALUE 		: std_logic := '0';
			DEFAULT_BAUD_RATE 	: integer range 0 to 115200 := 9600
		);
		port
		(
			CLK 		 : in  std_logic;
			RST 		 : in  std_logic;
			S_TVALID : in  std_logic; -- input to start the process
			S_TDATA  : in  std_logic_vector(7 downto 0);
			UART_TX  : out std_logic
		);
	end component;
	
	signal ascii : std_logic_vector(7 downto 0);

begin	

	ascii <= std_logic_vector(unsigned(SW(7 downto 0)) + x"30");

	inst_uart_tx : uart_tx
		port map(
			CLK	 			=> MAX10_CLK1_50,
			RST	 			=> KEY(0),
			S_TVALID	=> KEY(1),
			S_TDATA 	=> ascii,
			UART_TX 	=> GPIO_UART_TX
		);

end RTL;