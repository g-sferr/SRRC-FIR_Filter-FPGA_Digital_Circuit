library ieee;
use ieee.std_logic_1164.all;

--D Flip-Flop positive edge triggered, asynchronous reset
entity DFF_N is

	--Number of bits
	generic (Nbit : natural := 8);

	port (
		clk     	: in std_logic; -- Clock
		a_rst_n 	: in std_logic; -- Reset
		d       	: in std_logic_vector (Nbit-1 downto 0); -- Input
		q       	: out std_logic_vector (Nbit-1 downto 0) -- Output
	);
end entity;

architecture Structural of DFF_N is
begin

	ddf_n_proc : process (clk, a_rst_n)
	begin
		-- asynchronous reset (negative)
		if (a_rst_n = '0') then
			q <= (others => '0');
		elsif (rising_edge(clk)) then
			q <= d;
		end if;
	end process;

end architecture;