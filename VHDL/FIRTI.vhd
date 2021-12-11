----------------------------------------------------------------------------------
-- Engineer: Yohan Curbelo Angles
-- 
-- Module Name: FIRTI (FIR Filter Type I)
--
-- Description: 
-- 1. Customazible and optimized FIR Filter.
-- 2. The order of the filter has to be even (odd number of coefficients) 
-- and its coefficients symmetric.
-- 3. Customizable: The widths of input, output, and internal signals are 
-- configurable, making natual growth and truncation of data possible. 
-- 4. Optimized: As filter coefficients are symmetric, only half of them are 
-- loaded into the ROM and a sum of values that are symmetric to the middle 
-- address of the shift register is made.
--
--
-- Descripcion:
-- 1. Filtro FIR personalizable.
-- 2. El orden del filtro tiene que ser par (cantidad impar de coeficientes)
-- y sus coeficientes simetricos.
-- 3. Personalizable: El ancho de la senyal de entrada, salida, e internas son 
-- configurables, haciendo posible el truncado y el crecimiento natural de los 
-- datos internos.
-- 4. Optimizado: Como el filtro es simetrico solo se cargan en la ROM la mitad
-- de los coeficientes y se realiza una suma de los valores que son simetricos 
-- respecto a la direccion central del registro de desplazamiento.
--
----------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;
use		ieee.std_logic_textio.all;

library std;
use 	std.textio.all;

entity FIRTI is
    generic (
        INPUT_WIDTH     :   positive    :=  12;
        COEFF_WIDTH     :   positive    :=  10;
        ADD_WIDTH       :   positive    :=  12;
        MULT_WIDTH      :   positive    :=  12;
        OUTPUT_WIDTH    :   positive    :=  12;
        FILTER_ORDER    :   positive    :=  50;
        COEFF_FILE      :   string      :=  "coefficients_python.txt"
    );
    port (
        clk         :   in  std_logic;
        rst         :   in  std_logic;
        i_enable    :   in  std_logic;
        i_data      :   in  std_logic_vector(INPUT_WIDTH-1 downto 0);   
        o_enable    :   out std_logic;     
        o_data      :   out std_logic_vector(OUTPUT_WIDTH-1 downto 0)
    );
end FIRTI;

architecture Behavioral of FIRTI is

    -- Coefficientes signals and function to load coefficients from txt
    type luts    is array (0 to FILTER_ORDER/2) of std_logic_vector(COEFF_WIDTH-1 downto 0);
    
    impure function read_file (file_name : in string) return luts is
        file		rom_file		:	text is in file_name;
        variable	rom_file_line	:   line;
        variable	rom_data		:   luts;
    begin
        for i in 0 to FILTER_ORDER/2 loop   
            readline(rom_file, rom_file_line);
            read(rom_file_line, rom_data(i));                      
        end loop;
        return rom_data;
    end function;    
    
    signal coefficients :   luts     :=  read_file(COEFF_FILE);

    -- Latency of the filter
    constant lat_sr     :   positive    :=  1;
    constant lat_mult   :   positive    :=  1;    
    constant lat_out    :   positive    :=  1;
    constant LATENCY    :   positive    :=  lat_sr + lat_mult + lat_out;
    signal delay_en     :   std_logic_vector(0 to LATENCY-1);
    signal mult_en      :   std_logic;    
    
    -- Shift Register signals
    type shift_reg  is array (0 to FILTER_ORDER) of std_logic_vector(INPUT_WIDTH-1 downto 0);
    signal sr           :   shift_reg;
    
    -- Internal signals
    constant SUM_GROWTH :   positive    :=  positive(ceil(log2(real(FILTER_ORDER)/real(2))));
    type adders         is array (0 to FILTER_ORDER/2) of signed(INPUT_WIDTH downto 0);
    type multipliers    is array (0 to FILTER_ORDER/2) of signed(COEFF_WIDTH+ADD_WIDTH-1 downto 0);    
    type summatory      is array (0 to FILTER_ORDER/2-1) of signed(MULT_WIDTH+SUM_GROWTH-1 downto 0);
    signal adder        :   adders;
    signal mult_reg     :   multipliers;
    signal summation    :   summatory;    
    
begin

    sr_p    :   process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then
                sr      <=  (others => (others => '0'));
            elsif i_enable = '1' then
                sr      <=  i_data & sr(0 to FILTER_ORDER-1);
            end if;
        end if;
    end process;
    
    delay_enable_p   :   process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then            
                delay_en    <=  (others => '0');
                o_data      <=  (others => '0');
            else   
                -- Internal enables of te filter for pipeline (adders, multiplication, delay of lines, and summation)
                delay_en(0) <=  i_enable;
                for k in 0 to LATENCY-2 loop
                    delay_en(k+1) <=  delay_en(k);  
                end loop;      
                    
                if delay_en(LATENCY-2) = '1' then
                    o_data  <=  std_logic_vector(summation(FILTER_ORDER/2-1)(MULT_WIDTH+SUM_GROWTH-1 downto MULT_WIDTH+SUM_GROWTH-OUTPUT_WIDTH));
                end if;

            end if;
        end if;
    end process;   
    mult_en     <=  delay_en(0);                -- Delay input enable 2 cycles
    o_enable    <=  delay_en(LATENCY-1);        -- Delay input enable LATENCY cycles

    add_p   :   process(sr)
    begin               
        for k in 0 to FILTER_ORDER/2-1 loop
            adder(k)  <=  resize(signed(sr(k)), INPUT_WIDTH+1) + resize(signed(sr(FILTER_ORDER-k)), INPUT_WIDTH+1);
        end loop;
        adder(FILTER_ORDER/2)   <=  resize(signed(sr(FILTER_ORDER/2)), INPUT_WIDTH+1); 
    end process;
    
    mult_p  :   process(clk)
    begin
        if rising_edge(clk) then
            if rst = '0' then
                mult_reg    <=  (others => (others => '0'));
            elsif mult_en = '1' then      
                -- Product of every sum with its same index coefficient              
                for k in 0 to FILTER_ORDER/2 loop
                    mult_reg(k)    <=  signed(coefficients(k)) * adder(k)(INPUT_WIDTH downto INPUT_WIDTH+1-ADD_WIDTH);
                end loop;            
            end if;
        end if;
    end process;
    
    sum_p    :   process(summation, mult_reg)
    begin
        -- Summatory of all products
        summation(0)  <=  resize(mult_reg(0)(COEFF_WIDTH+ADD_WIDTH-1 downto COEFF_WIDTH+ADD_WIDTH-MULT_WIDTH), MULT_WIDTH+SUM_GROWTH) + resize(mult_reg(1)(COEFF_WIDTH+ADD_WIDTH-1 downto COEFF_WIDTH+ADD_WIDTH-MULT_WIDTH), MULT_WIDTH+SUM_GROWTH);
        for k in 1 to FILTER_ORDER/2-1 loop      
            summation(k)  <=  summation(k-1) + resize(mult_reg(k+1)(COEFF_WIDTH+ADD_WIDTH-1 downto COEFF_WIDTH+ADD_WIDTH-MULT_WIDTH), MULT_WIDTH+SUM_GROWTH);
        end loop;              
    end process;                 
   
end Behavioral;