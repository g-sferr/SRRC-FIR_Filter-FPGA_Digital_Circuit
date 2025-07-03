library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- ============================================================================================
    -- ========================================================================================
    -- The latency for a symmetric filter like the SRRC_Filter is:

    -- Latency: (N-1) / 2 -> ; N = Filter Order

    -- In the case of the circuit implemented for this project,
    -- the various pipeline stages that can introduce delay must be considered, more precisely:
    -- = 1) Symmetric sums:        : 1 -> clock cycle latency
    -- = 2) Symmetric products      : 1 -> clock cycle latency
    -- = 3) Central product         : 1 -> clock cycle latency
    -- = 4) Sum tree (4 stages)    : 4 -> clock cycles latency
    -- = -- Total = 7 Cycles

    -- = -- N = 23
    -- = -- total_latency = 7 + [ (23-1) / 2 ] = 7 + 11 = 18
    -- ==========================================================================================
-- ==============================================================================================

entity SRRC_Filter_boundery_tb is
end entity;

architecture test_bench_filter_boundery of SRRC_Filter_boundery_tb is
  -- Declaration of the SRRC_Filter_Wrapper Component (SRRC_Filter + Coefficients)
  component SRRC_Filter_Wrapper
    port (
      clk             : in  std_logic;
      a_rst_n         : in  std_logic;
      SRRC_Filter_in  : in  std_logic_vector(15 downto 0);
      SRRC_Filter_out : out std_logic_vector(15 downto 0)
    );
  end component;

  -- Constants
  constant CLK_PERIOD           : time := 8 ns;   -- Clock period (125Mhz)
  -- Filter latency in clock cycles for the impulse peak (based on hardware description)
  constant SRRC_FILTER_LATENCY  : integer := 18;
  -- Signals
  signal clk                : std_logic := '0';
  signal reset_n_tb         : std_logic := '0';
  signal SRRC_Filter_in_tb  : std_logic_vector(15 downto 0) := (others => '0');
  signal SRRC_Filter_out_tb : std_logic_vector(15 downto 0);
  signal testing            : boolean   := true; -- Controls clock generation

  -- Function to convert a real value to Q8.7 format (16-bit std_logic_vector)
  function real_to_q8_7(real_val : real) return std_logic_vector is
  begin
    return std_logic_vector(to_signed(integer(real_val * 2.0**7), 16));
  end function;


begin

  -- Clock generation: generates a clock at half period for simulation (as in the circuit)
  clk <= not clk after CLK_PERIOD/2 when testing else '0';

  -- DUT (Device Under Test) instance: maps the SRRC_Filter_Wrapper filter to the testbench signals
  DUT: SRRC_Filter_Wrapper
    port map (
      clk             => clk,
      a_rst_n         => reset_n_tb,
      SRRC_Filter_in  => SRRC_Filter_in_tb,
      SRRC_Filter_out => SRRC_Filter_out_tb
    );

  -- Process containing the sequential logic for the tests
  STIMULUS: process
  begin
    -- Initial reset of the input
    SRRC_Filter_in_tb  <= (others => '0');
    reset_n_tb <= '0';

    -- == Check Reset and "All 1s input" == 
    wait until rising_edge(clk);
    SRRC_Filter_in_tb  <= real_to_q8_7(1.0);
    wait for 200 ns; -- during this period, it will be noted how as long as reset is 0, the output is null

    wait until rising_edge(clk);
    reset_n_tb <= '1'; -- from this moment on, the filter generates output because the reset has been deactivated
    -- Wait for filter response visualization
    wait for SRRC_FILTER_LATENCY * CLK_PERIOD;

    -- == Sequence 1 (previous input) and 2, 3, 4...23 as input (Sliding-Window Behavior) == 
    for i in 2 to 23 loop
        wait until rising_edge(clk);
        SRRC_Filter_in_tb <= STD_LOGIC_VECTOR(to_signed(i * 128, 16));
    end loop;

    -- Wait for filter response visualization
    wait for (SRRC_FILTER_LATENCY * 2) * CLK_PERIOD;
    SRRC_Filter_in_tb  <= (others => '0'); -- Reset input
    reset_n_tb <= '0';
    wait for (SRRC_FILTER_LATENCY * 2) * CLK_PERIOD;
    reset_n_tb <= '1';


    -- == Only "-1" as input ==
    wait until rising_edge(clk);
    SRRC_Filter_in_tb <= real_to_q8_7(-1.0);
    -- Wait for filter response visualization
    wait for (SRRC_FILTER_LATENCY *2) * CLK_PERIOD;

    -- == Sequence -1 (previous input) and -2 as input (Sliding-Window Behavior) ==
    for i in 2 to 23 loop
        wait until rising_edge(clk);
        if i mod 2 = 0 then
            SRRC_Filter_in_tb <= real_to_q8_7(-2.0);
        else
            SRRC_Filter_in_tb <= real_to_q8_7(-1.0);
        end if;
    end loop;

    wait for (SRRC_FILTER_LATENCY *2) * CLK_PERIOD; -- Minimum wait to display filter response
    SRRC_Filter_in_tb  <= (others => '0'); -- Reset input
    reset_n_tb <= '0';
    wait for (SRRC_FILTER_LATENCY *2) * CLK_PERIOD;
    reset_n_tb <= '1';


    -- == Only "-2" as input ==
    wait until rising_edge(clk);
    SRRC_Filter_in_tb <= real_to_q8_7(-2.0);
    wait for (SRRC_FILTER_LATENCY *2) * CLK_PERIOD;

    -- == Sequence -2 (previous input) and 4 as input (Sliding-Window Behavior) ==
    for i in 2 to 23 loop
        wait until rising_edge(clk);
        if i mod 2 = 0 then
            SRRC_Filter_in_tb <= real_to_q8_7(4.0);
        else
            SRRC_Filter_in_tb <= real_to_q8_7(-2.0);
        end if;
    end loop;

    -- == Wait for filter response visualization ==
    wait for (SRRC_FILTER_LATENCY *2) * CLK_PERIOD;
    SRRC_Filter_in_tb  <= (others => '0'); -- Reset input
    reset_n_tb <= '0';
    wait for (SRRC_FILTER_LATENCY *2) * CLK_PERIOD;
    reset_n_tb <= '1';


    -- == Only "2" as input ==
    wait until rising_edge(clk);
    SRRC_Filter_in_tb <= real_to_q8_7(2.0);

    -- Wait for filter response visualization
    wait for (SRRC_FILTER_LATENCY *2) * CLK_PERIOD;
    SRRC_Filter_in_tb   <= (others => '0');
    reset_n_tb <= '0';
    wait for (SRRC_FILTER_LATENCY *2) * CLK_PERIOD;
    reset_n_tb <= '1';

    -- == Minimum Negative as input: -256 (-32768) ==
    wait until rising_edge(clk);
    SRRC_Filter_in_tb <= real_to_q8_7(-256.0);

    -- == Wait for filter response visualization ==
    wait for (SRRC_FILTER_LATENCY *2) * CLK_PERIOD;
    SRRC_Filter_in_tb   <= (others => '0');
    reset_n_tb <= '0';
    wait for (SRRC_FILTER_LATENCY *2) * CLK_PERIOD;
    reset_n_tb <= '1';

    -- == Maximum Positive as input: 255.9921875 (32767) ==
    wait until rising_edge(clk);
    SRRC_Filter_in_tb <= real_to_q8_7(255.9921875);

    wait for 1000 ns; -- Extra time
    testing <= false; -- End simulation
    wait until rising_edge(clk); -- Wait for a final clock edge for safety

  end process;
end architecture;