library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =====================================================================================================

-- Wrapper to encapsulate the SRRC_Filter and fix the coefficients.
-- Useful for the synthesis and hardware implementation process, this wrapper
-- provides a pre-configured instance of the SRRC_Filter, with a simplified user interface.

-- N.B.: Since the SRRC_Filter implementation uses a "Pipeline" architecture, any
-- registers (Flip-Flops) necessary to ensure the synchronization of external signals to the circuit's clock,
-- which could have been managed in this wrapper, are already present in the filter's internal description
-- (See SRRC_Filter.vhd). Inserting input/output registers in the wrapper would introduce redundancy
-- and unnecessary extra latency, causing synchronization and verifiability issues, as well as confusing
-- the pipeline boundaries.
-- Since the filter is already correctly pipelined, the wrapper will simply
-- interface the external signals to the core without altering their timing.

-- The SRRC coefficients in Q1.14 format are declared here as constants, as they are often
-- fixed for a given hardware implementation of a FIR/SRRC filter.
-- Including them as CONSTANT within the wrapper and mapping them internally frees the user
-- of this wrapper from knowing the details of the coefficients, or worrying about setting them correctly.
-- The wrapper encapsulates this configuration.
-- (N.B. Two's complement used for negative values).

-- =====================================================================================================

entity SRRC_Filter_Wrapper is
    port (
        clk             : in  std_logic; -- Clock
        a_rst_n         : in  std_logic; -- Reset - Active Low (Asynchronous)
        SRRC_Filter_in  : in std_logic_vector(15 downto 0); -- Input
        SRRC_Filter_out : out std_logic_vector(15 downto 0) -- Output
    );
end entity;

architecture beh of SRRC_Filter_Wrapper is

    -- Declaration of the SRRC_Filter Component
    component SRRC_Filter is
        port (
            clk         : in  std_logic;
            reset_n     : in  std_logic; -- Active low (Asynchronous)
            x_in        : in  std_logic_vector(15 downto 0);
            y_out       : out std_logic_vector(15 downto 0);

            -- SRRC_Filter Coefficients
            coef_0_22   : in std_logic_vector(15 downto 0);
            coef_1_21   : in std_logic_vector(15 downto 0);
            coef_2_20   : in std_logic_vector(15 downto 0);
            coef_3_19   : in std_logic_vector(15 downto 0);
            coef_4_18   : in std_logic_vector(15 downto 0);
            coef_5_17   : in std_logic_vector(15 downto 0);
            coef_6_16   : in std_logic_vector(15 downto 0);
            coef_7_15   : in std_logic_vector(15 downto 0);
            coef_8_14   : in std_logic_vector(15 downto 0);
            coef_9_13   : in std_logic_vector(15 downto 0);
            coef_10_12  : in std_logic_vector(15 downto 0);
            coef_11_11  : in std_logic_vector(15 downto 0) -- Center coefficient
        );
    end component;

    constant C_0_22   : std_logic_vector(15 downto 0) := "1111111011110010"; -- (-0.0165 -  [Q1.14: -270]  )
    constant C_1_21   : std_logic_vector(15 downto 0) := "1111111100001011"; -- (-0.0150 -  [Q1.14: -245]  )
    constant C_2_20   : std_logic_vector(15 downto 0) := "0000000011111101"; -- (0.0155  -  [Q1.14: 253]   )
    constant C_3_19   : std_logic_vector(15 downto 0) := "0000001010110110"; -- (0.0424  -  [Q1.14: 694]   )
    constant C_4_18   : std_logic_vector(15 downto 0) := "0000000011111101"; -- (0.0155  -  [Q1.14: 253]   )
    constant C_5_17   : std_logic_vector(15 downto 0) := "1111101100110100"; -- (-0.0750 -  [Q1.14: -1228] )
    constant C_6_16   : std_logic_vector(15 downto 0) := "1111010111110111"; -- (-0.1568 -  [Q1.14: -2569] )
    constant C_7_15   : std_logic_vector(15 downto 0) := "1111100100110110"; -- (-0.1061 -  [Q1.14: -1738] )
    constant C_8_14   : std_logic_vector(15 downto 0) := "0000101000001001"; -- (0.1568  -  [Q1.14: 2569]  )
    constant C_9_13   : std_logic_vector(15 downto 0) := "0010010100000111"; -- (0.5786  -  [Q1.14: 9479]  )
    constant C_10_12  : std_logic_vector(15 downto 0) := "0011111001011110"; -- (0.9745  -  [Q1.14: 15966] )
    constant C_11_11  : std_logic_vector(15 downto 0) := "0100100010111110"; -- (1.1366  -  [Q1.14: 18622] )

begin
    -- Mapping of the SRRC_Filter instance
    SRRC_FILTER_INSTANCE : SRRC_Filter
    port map (
        clk         => clk,
        reset_n     => a_rst_n,           -- Map the wrapper's a_rst_n to the filter's reset_n
        x_in        => SRRC_Filter_in,    -- Map the wrapper's SRRC_Filter_in to the filter's x_in
        y_out       => SRRC_Filter_out,   -- Map the wrapper's SRRC_Filter_out to the filter's y_out

        -- Mapping of fixed coefficients to the SRRC_Filter ports
        coef_0_22   => C_0_22,
        coef_1_21   => C_1_21,
        coef_2_20   => C_2_20,
        coef_3_19   => C_3_19,
        coef_4_18   => C_4_18,
        coef_5_17   => C_5_17,
        coef_6_16   => C_6_16,
        coef_7_15   => C_7_15,
        coef_8_14   => C_8_14,
        coef_9_13   => C_9_13,
        coef_10_12  => C_10_12,
        coef_11_11  => C_11_11
    );
end architecture;