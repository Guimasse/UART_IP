library ieee;
use ieee.std_logic_1164.all;
Use ieee.numeric_std.all;

package simu_pkg is
  function to_hex_string(v : std_logic_vector) return string;

  procedure get_random_byte(
    seed           : inout integer;
    random_byte    : out std_logic_vector(7 downto 0)
  );
end package simu_pkg;

package body simu_pkg is
  function to_hex_string(v : std_logic_vector) return string is
    variable result : string(1 to (v'length+3)/4);
    variable nibble : std_logic_vector(3 downto 0);
    variable i : integer := 1;
  begin
    for j in v'left downto v'right loop
      nibble(3 - ((v'left - j) mod 4)) := v(j);
      if ((v'left - j) mod 4 = 3) or (j = v'right) then
        case nibble is
          when "0000" => result(i) := '0';
          when "0001" => result(i) := '1';
          when "0010" => result(i) := '2';
          when "0011" => result(i) := '3';
          when "0100" => result(i) := '4';
          when "0101" => result(i) := '5';
          when "0110" => result(i) := '6';
          when "0111" => result(i) := '7';
          when "1000" => result(i) := '8';
          when "1001" => result(i) := '9';
          when "1010" => result(i) := 'A';
          when "1011" => result(i) := 'B';
          when "1100" => result(i) := 'C';
          when "1101" => result(i) := 'D';
          when "1110" => result(i) := 'E';
          when "1111" => result(i) := 'F';
          when others => result(i) := '?';
        end case;
        i := i + 1;
      end if;
    end loop;
    return result;
  end function;

  procedure get_random_byte(
    seed           : inout integer;
    random_byte    : out std_logic_vector(7 downto 0)
  ) is
    constant a          : integer := 1103515245;
    constant c          : integer := 12345;
    constant m          : integer := 2**31;
    variable next_seed  : integer;
  begin
    -- Générateur linéaire congruentiel : seed = (a * seed + c) mod m
    next_seed := (a * seed + c) mod m;
    seed := next_seed;

    -- Extraction des bits 16 à 23 pour créer un pseudo-octet
    random_byte := std_logic_vector(to_unsigned((next_seed / 65536) mod 256, 8));
  end procedure;

end package body simu_pkg;