library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

-- Fixed-Point Formats for SRRC_Filter (Order 22)
-- Qx.y format: 1 sign bit, x integer bits, y fractional bits. Total bits: (1 + x + y).

-- x_in: Q8.7 (16 bits)
-- coef_i: Q1.14 (16 bits)
-- y_out: Q11.4 (16 bits)

entity SRRC_Filter is
    port (
        clk         : in  std_logic; -- Clock
        reset_n     : in  std_logic; -- Active low reset (Asynchronous)
        x_in        : in  std_logic_vector(15 downto 0); -- Input in Q8.7 format
        y_out       : out std_logic_vector(15 downto 0); -- Output in Q11.4 format

        -- Coefficients (symmetric, 16-bit, Q1.14 format)
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
        coef_11_11  : in std_logic_vector(15 downto 0) -- Central coefficient (c_11)
    );
end entity;

architecture struct of SRRC_Filter is

    component DFF_N is
        generic (Nbit : natural := 16);
        port (
            clk      : in  std_logic;
            a_rst_n  : in  std_logic;
            d        : in  std_logic_vector(Nbit-1 downto 0);
            q        : out std_logic_vector(Nbit-1 downto 0)
        );
    end component;

    -- === Constants ===
    constant N_BIT             : integer := 16;
    constant FILTER_ORDER_VAL  : integer := 22; -- Filter order (N)
    constant SIGNAL_SAMPLES    : integer := FILTER_ORDER_VAL + 1; -- Total number of taps (23)
    constant COEFFS_SIZE       : integer := (FILTER_ORDER_VAL / 2) + 1; -- Number of distinct coefficients (12)
    constant MID               : integer := FILTER_ORDER_VAL / 2; -- Index of the central coefficient (11)
    constant SYM_SUM_WIDTH     : integer := 17; -- Q9.7 (Input Q8.7 + Input Q8.7 = Q9.7) -> 1 more for overflow
    constant PRODUCT_WIDTH     : integer := 32; -- Q11.21 (Coef Q2.14 * SymSum Q9.7 = Q11.21)
    constant ACC_WIDTH         : integer := 35; -- Q14.21 (Accumulator: sum of 12 terms, 1 sign, 12 int, 21 frac, 1 overflow)
    
    -- === Signals ===
    type coeff_map_array is array (0 to COEFFS_SIZE-1) of std_logic_vector(N_BIT-1 downto 0);
    signal c_map           : coeff_map_array;          -- Mapped coefficients for filter taps.
    signal c_map_reg       : coeff_map_array;          -- Registered mapped coefficients for pipelining.

    type data_reg_array is array (0 to SIGNAL_SAMPLES-1) of std_logic_vector(N_BIT-1 downto 0);
    signal x_reg : data_reg_array;                   -- Shift register for input data samples.

    type sym_sum_array is array (0 to MID-1) of std_logic_vector(SYM_SUM_WIDTH-1 downto 0);
    signal sym_sum_out     : sym_sum_array;          -- Output of symmetric sum operations.
    signal sym_sum_reg_out : sym_sum_array;          -- Registered output of symmetric sum operations.

    type prod_array is array (0 to MID-1) of std_logic_vector(PRODUCT_WIDTH-1 downto 0);
    signal prod_out        : prod_array;               -- Output of symmetric product operations.
    signal prod_reg_out    : prod_array;               -- Registered output of symmetric product operations.

    -- Pipelined middle element of input shift register.
    signal x_reg_mid_pipelined   : std_logic_vector(N_BIT-1 downto 0);
    -- Output of the central tap product.
    signal center_prod_out       : std_logic_vector(PRODUCT_WIDTH-1 downto 0);      
    -- Registered output of the central tap product.
    signal center_prod_reg_out   : std_logic_vector(PRODUCT_WIDTH-1 downto 0);      

    -- Adder Stages (width of ACC_WIDTH)
    type adder_stage1_array is array (0 to 5) of std_logic_vector(ACC_WIDTH-1 downto 0);
    signal adder_stage1_out      : adder_stage1_array; -- Outputs of the first stage of the adder tree.
    signal adder_stage1_reg_out  : adder_stage1_array; -- Registered outputs of the first adder stage.

    type adder_stage2_array is array (0 to 2) of std_logic_vector(ACC_WIDTH-1 downto 0);
    signal adder_stage2_out      : adder_stage2_array; -- Outputs of the second stage of the adder tree.
    signal adder_stage2_reg_out  : adder_stage2_array; -- Registered outputs of the second adder stage.

    type adder_stage3_array is array (0 to 1) of std_logic_vector(ACC_WIDTH-1 downto 0);
    signal adder_stage3_out      : adder_stage3_array; -- Outputs of the third stage of the adder tree.
    signal adder_stage3_reg_out  : adder_stage3_array; -- Registered outputs of the third adder stage.

    signal final_accumulator_out : std_logic_vector(ACC_WIDTH-1 downto 0); -- Final sum from the accumulator tree.
    signal output_trunc_val      : std_logic_vector(N_BIT-1 downto 0); -- Truncated final output value.

begin
    -- Map input coefficients to internal array
    c_map(0)    <= coef_0_22;
    c_map(1)    <= coef_1_21;
    c_map(2)    <= coef_2_20;
    c_map(3)    <= coef_3_19;
    c_map(4)    <= coef_4_18;
    c_map(5)    <= coef_5_17;
    c_map(6)    <= coef_6_16;
    c_map(7)    <= coef_7_15;
    c_map(8)    <= coef_8_14;
    c_map(9)    <= coef_9_13;
    c_map(10)   <= coef_10_12;
    c_map(11)   <= coef_11_11;

    ---
    -- Shift Register (Pipeline Stage 1)
    -- Implements x[n], x[n-1], ..., x[n-22]
    ---
    GEN_SHIFT_REG: for i in 0 to SIGNAL_SAMPLES-1 generate
        FIRST_REG: if i = 0 generate
            DFF_X0: DFF_N
            generic map (Nbit => N_BIT)
            port map (
                clk     => clk,
                a_rst_n => reset_n,
                d       => x_in,
                q       => x_reg(0)
                );
        end generate FIRST_REG;

        INTERNAL_REGS: if i > 0 and i < SIGNAL_SAMPLES-1 generate
            DFF_Xi: DFF_N
            generic map (Nbit => N_BIT)
            port map (
                clk     => clk,
                a_rst_n => reset_n,
                d       => x_reg(i-1),
                q       => x_reg(i)
                );
        end generate INTERNAL_REGS;

        LAST_REG: if i = SIGNAL_SAMPLES-1 generate
            DFF_X_LAST: DFF_N
            generic map (Nbit => N_BIT)
            port map (
                clk     => clk,
                a_rst_n => reset_n,
                d       => x_reg(SIGNAL_SAMPLES-2),
                q       => x_reg(SIGNAL_SAMPLES-1)
                );
        end generate LAST_REG;
    end generate GEN_SHIFT_REG;

    ---
    -- Coefficient Registers (Pipeline Stage 2)
    -- Registers all coefficients (c_0_22 to c_11_11)
    ---
    GEN_COEFF_REGS: for i in 0 to COEFFS_SIZE-1 generate
        REG_COEF_i: DFF_N
        generic map (Nbit => N_BIT)
        port map (
            clk     => clk,
            a_rst_n => reset_n,
            d       => c_map(i),
            q       => c_map_reg(i)
            );
    end generate GEN_COEFF_REGS;

    ---
    -- Symmetric Sums (Pipeline Stage 3)
    -- Implements (x[n-i] + x[n-(N-i)])
    ---
    SYM_SUM_PROCESS : process (x_reg)
    BEGIN
        --Initialization
        for i in 0 to MID-1 loop
            sym_sum_out(i) <= (others => '0');
        end loop;

        -- Sums symmetric inputs
        for k in 0 to MID-1 loop
            sym_sum_out(k) <= std_logic_vector(resize(signed(x_reg(k)), SYM_SUM_WIDTH)
                                  + resize(signed(x_reg(FILTER_ORDER_VAL-k)), SYM_SUM_WIDTH));
        end loop;
    end process;

    GEN_SYMMETRIC_SUMS: for i in 0 to MID-1 generate
        -- Register symmetric sums for pipelining
        REG_SYM_SUM_i: DFF_N
        generic map (Nbit => SYM_SUM_WIDTH)
        port map (
            clk     => clk,
            a_rst_n => reset_n,
            d       => sym_sum_out(i),
            q       => sym_sum_reg_out(i)
            );
    end generate GEN_SYMMETRIC_SUMS;

    -- Register the central tap (x_reg(MID)) for pipeline alignment
    DFF_X_REG_MID_PIPE: DFF_N
    generic map (Nbit => N_BIT)
    port map (
        clk     => clk,
        a_rst_n => reset_n,
        d       => x_reg(MID),
        q       => x_reg_mid_pipelined
        );

    ---
    -- Product Section (Pipeline Stage 4)
    -- Implements c_i * (x[n-i] + x[n-(N-i)])
    ---
    MUL_PROCESS : process (sym_sum_reg_out, c_map_reg)
    BEGIN
    -- Multiply registered coefficients with symmetric sums (32-bit, Q10.21)
    
        --Initialization
        for i in 0 to MID-1 loop
            prod_out(i) <= (others => '0');
        end loop;

        --Multiplication
        for k in 0 to MID-1 loop
            prod_out(k) <= std_logic_vector(resize(signed(c_map_reg(k)) * signed(sym_sum_reg_out(k)), PRODUCT_WIDTH));
        end loop;
    end process;

    -- Register products for pipelining
    GEN_PRODUCTS: for i in 0 to MID-1 generate
        REG_PROD_i: DFF_N
        generic map (Nbit => PRODUCT_WIDTH)
        port map (
            clk     => clk,
            a_rst_n => reset_n,
            d       => prod_out(i),
            q       => prod_reg_out(i)
            );
    end generate GEN_PRODUCTS;

    -- Calculate central product
    center_prod_out <= std_logic_vector(signed(c_map_reg(MID)) * signed(x_reg_mid_pipelined));

    -- Register central product for pipelining
    REG_CENTER_PROD: DFF_N
    generic map (Nbit => PRODUCT_WIDTH)
    port map (
        clk     => clk,
        a_rst_n => reset_n,
        d       => center_prod_out,
        q       => center_prod_reg_out
        );


    ---
    -- Adder Tree (Pipeline Stages 5, 6, 7, 8)
    -- Sums the 12 products in a binary tree structure.
    -- All sums are extended to ACC_WIDTH (35-bit, Q14.21) to prevent overflow during accumulation.
    ---

    -- Stage 1: 6 additions (Pipeline Stage 5). Results are ACC_WIDTH (35-bit, Q14.21).
    adder_stage1_out(0) <= std_logic_vector(resize(signed(prod_reg_out(0)), ACC_WIDTH) + resize(signed(prod_reg_out(1)), ACC_WIDTH));
    adder_stage1_out(1) <= std_logic_vector(resize(signed(prod_reg_out(2)), ACC_WIDTH) + resize(signed(prod_reg_out(3)), ACC_WIDTH));
    adder_stage1_out(2) <= std_logic_vector(resize(signed(prod_reg_out(4)), ACC_WIDTH) + resize(signed(prod_reg_out(5)), ACC_WIDTH));
    adder_stage1_out(3) <= std_logic_vector(resize(signed(prod_reg_out(6)), ACC_WIDTH) + resize(signed(prod_reg_out(7)), ACC_WIDTH));
    adder_stage1_out(4) <= std_logic_vector(resize(signed(prod_reg_out(8)), ACC_WIDTH) + resize(signed(prod_reg_out(9)), ACC_WIDTH));
    -- The last sum includes the central product
    adder_stage1_out(5) <= std_logic_vector(resize(signed(prod_reg_out(10)), ACC_WIDTH) + resize(signed(center_prod_reg_out), ACC_WIDTH));

    -- Register Stage 1 additions
    GEN_ADDER_STAGE1_REGS: for i in 0 to 5 generate
        REG_ADD_S1_i: DFF_N
        generic map (Nbit => ACC_WIDTH)
        port map (
            clk     => clk,
            a_rst_n => reset_n,
            d       => adder_stage1_out(i),
            q       => adder_stage1_reg_out(i)
            );
    end generate GEN_ADDER_STAGE1_REGS;

    -- Stage 2: 3 additions (Pipeline Stage 6). Results are ACC_WIDTH (35-bit, Q14.21).
    adder_stage2_out(0) <= std_logic_vector(resize(signed(adder_stage1_reg_out(0)), ACC_WIDTH) + resize(signed(adder_stage1_reg_out(1)), ACC_WIDTH));
    adder_stage2_out(1) <= std_logic_vector(resize(signed(adder_stage1_reg_out(2)), ACC_WIDTH) + resize(signed(adder_stage1_reg_out(3)), ACC_WIDTH));
    adder_stage2_out(2) <= std_logic_vector(resize(signed(adder_stage1_reg_out(4)), ACC_WIDTH) + resize(signed(adder_stage1_reg_out(5)), ACC_WIDTH));

    -- Register Stage 2 additions
    GEN_ADDER_STAGE2_REGS: for i in 0 to 2 generate
        REG_ADD_S2_i: DFF_N
        generic map (Nbit => ACC_WIDTH)
        port map (
            clk     => clk,
            a_rst_n => reset_n,
            d       => adder_stage2_out(i),
            q       => adder_stage2_reg_out(i)
            );
    end generate GEN_ADDER_STAGE2_REGS;

    -- Stage 3: 2 additions (Pipeline Stage 7). Results are ACC_WIDTH (35-bit, Q14.21).
    adder_stage3_out(0) <= std_logic_vector(resize(signed(adder_stage2_reg_out(0)), ACC_WIDTH) + resize(signed(adder_stage2_reg_out(1)), ACC_WIDTH));
    adder_stage3_out(1) <= std_logic_vector(resize(signed(adder_stage2_reg_out(2)), ACC_WIDTH));

    -- Register Stage 3 additions
    GEN_ADDER_STAGE3_REGS: for i in 0 to 1 generate
        REG_ADD_S3_i: DFF_N
        generic map (Nbit => ACC_WIDTH)
        port map (
            clk     => clk,
            a_rst_n => reset_n,
            d       => adder_stage3_out(i),
            q       => adder_stage3_reg_out(i)
            );
    end generate GEN_ADDER_STAGE3_REGS;

    -- Final Accumulator (Pipeline Stage 8). Result is ACC_WIDTH (35-bit, Q14.21).
    final_accumulator_out <= std_logic_vector(resize(signed(adder_stage3_reg_out(0)), ACC_WIDTH) + resize(signed(adder_stage3_reg_out(1)), ACC_WIDTH));

    ---
    -- Output Truncation (Pipeline Stage 9)
    -- Truncate accumulator (Q14.21, 35-bit) to output (16-bit).
    ---  

    -- Output in Q11.4 format (16 bit)
    -- We take bits [32 DOWNTO 17] from the 35-bit accumulator.
    -- Truncate the last "17" bits for the fractional part -> (right shift)
    -- Final scaling from Q14.21 to Q12.4 --> Q11.4
    output_trunc_val <= final_accumulator_out(32 downto 17);

    -- Register final output
    REG_OUTPUT: DFF_N
    generic map (Nbit => N_BIT)
    port map (
        clk     => clk,
        a_rst_n => reset_n,
        d       => output_trunc_val,
        q       => y_out
        );

end architecture;