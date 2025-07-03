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

entity SRRC_Filter_waveform_tb is
end entity;

architecture test_bench_waveform_analysis of SRRC_Filter_waveform_tb is
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
  constant CLK_PERIOD           : time    := 8 ns;   -- Clock period (125Mhz)
  -- Filter latency in clock cycles for the impulse peak (based on hardware description)
  constant SRRC_FILTER_LATENCY  : integer := 18;
  constant SAMPLES_PER_SYMBOL   : integer := 4;      -- SPS = 4
  constant SINUSOID_LENGTH      : integer := 100;    -- Sinusoid length
  constant NUM_SYMBOLS_TEST2    : integer := 10;     -- Number of symbols for zero ISI test

  -- Signals
  signal clk                : std_logic := '0';
  signal reset_n_tb         : std_logic := '0';
  signal SRRC_Filter_in_tb  : std_logic_vector(15 downto 0) := (others => '0');
  signal SRRC_Filter_out_tb : std_logic_vector(15 downto 0);
  signal testing            : boolean   := true;

  type signed_array is array (natural range <>) of std_logic_vector(15 downto 0);

  -- Function to convert a real value to Q8.7 format (16-bit std_logic_vector)
  function real_to_q8_7(real_val : real) return std_logic_vector is
  begin
    return std_logic_vector(to_signed(integer(real_val * 2.0**7), 16));
  end function;

  -- Function to generate an array of sinusoidal samples in Q8.7 format (std_logic_vector)
  function generate_sinusoid(freq_normalized : real; n_samples : integer) return signed_array is
    variable result : signed_array(0 to n_samples-1);
    variable angle  : real;
  begin
    for i in 0 to n_samples-1 loop
      angle := 2.0 * MATH_PI * freq_normalized * real(i);
      result(i) := real_to_q8_7(sin(angle));
    end loop;
    return result;
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
    -- Temporary variable for the current symbol value in Test 2 - Zero ISI
    variable current_symbol_val : real;

    -- Variables for sinusoidal tests (Test 3 and 4)
    variable test3_samples : signed_array(0 to SINUSOID_LENGTH-1);
    variable test4_samples : signed_array(0 to SINUSOID_LENGTH-1);

  begin
    -- Initial reset of the input
    SRRC_Filter_in_tb   <= (others => '0');
    wait for 5*CLK_PERIOD;
    reset_n_tb <= '1';
    wait for 10*CLK_PERIOD;

    -- === Test 1: Impulse Response (Peak Verification) ===
    SRRC_Filter_in_tb <= real_to_q8_7(1.0);
    wait until rising_edge(clk);
    SRRC_Filter_in_tb <= (others => '0'); -- Resets the input to zero after one cycle (to see the symmetric waveform)

    -- Wait for the filter response to end for the last symbol input
    wait for (2 * SRRC_FILTER_LATENCY) * CLK_PERIOD;
    reset_n_tb <= '0'; -- Reset before the next test
    wait for 10 * CLK_PERIOD;
    reset_n_tb <= '1';


    -- === Test 2: Zero ISI with alternating symbols (+1/-1) ===
    wait until rising_edge(clk);
    for symbol_idx in 0 to NUM_SYMBOLS_TEST2-1 loop
        -- Determine the symbol value: +1.0 for even indices, -1.0 for odd indices
        if symbol_idx mod 2 = 0 then
            current_symbol_val := 1.0;
        else
            current_symbol_val := -1.0;
        end if;

        -- Apply the current symbol to the filter input
        SRRC_Filter_in_tb <= real_to_q8_7(current_symbol_val);
        wait until rising_edge(clk);

        -- Apply (SAMPLES_PER_SYMBOL - 1) zeros to simulate upsampling
        for zero_count in 1 to SAMPLES_PER_SYMBOL-1 loop
            SRRC_Filter_in_tb <= (others => '0'); -- Apply zero
            wait until rising_edge(clk);          -- Wait for one clock cycle
        end loop;
    end loop;

    -- Wait for the filter response to end for the last symbol input
    wait for SRRC_FILTER_LATENCY * CLK_PERIOD;
    reset_n_tb <= '0'; -- Reset before the next test
    wait for 10 * CLK_PERIOD;
    reset_n_tb <= '1';


    -- === Test 3: Out-of-band sinusoid (0.8/SPS = 0.2 normalized frequency) ===
    wait until rising_edge(clk);
    test3_samples := generate_sinusoid(0.8/real(SAMPLES_PER_SYMBOL), SINUSOID_LENGTH);

    for i in 0 to SINUSOID_LENGTH-1 loop
      SRRC_Filter_in_tb <= test3_samples(i);
      wait until rising_edge(clk);
    end loop;

    -- Wait for the filter response to end for the sinusoid
    wait for SRRC_FILTER_LATENCY * CLK_PERIOD;
    reset_n_tb <= '0'; -- Reset before the next test
    wait for 10 * CLK_PERIOD;
    reset_n_tb <= '1';


    -- === Test 4: In-band sinusoid (0.1/SPS = 0.025 normalized frequency) ===
    wait until rising_edge(clk);
    test4_samples := generate_sinusoid(0.1/real(SAMPLES_PER_SYMBOL), SINUSOID_LENGTH);

    for i in 0 to SINUSOID_LENGTH-1 loop
      SRRC_Filter_in_tb <= test4_samples(i);
      wait until rising_edge(clk);
    end loop;

    -- Wait for the filter response to end for the sinusoid
    wait for SRRC_FILTER_LATENCY * CLK_PERIOD;
    reset_n_tb <= '0'; -- Final reset
    wait for 10 * CLK_PERIOD;
    reset_n_tb <= '1';


    -- === Final simulation termination ===
    wait for 1000 ns; -- Extra time
    testing <= false; -- Stop clock generation (the clock_generation process will stop at the next edge)
    wait until rising_edge(clk); -- Wait for a final clock edge for safety

  end process;

end architecture;