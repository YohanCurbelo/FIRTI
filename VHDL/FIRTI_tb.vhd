library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     ieee.math_real.all;
use		ieee.std_logic_textio.all;

library std;
use 	std.textio.all;

entity FIRTI_tb is
    generic (
        DATA_LENGTH     :   positive    :=  800;
        INPUT_WIDTH     :   positive    :=  12;
        COEFF_WIDTH     :   positive    :=  10;
        ADD_WIDTH       :   positive    :=  12;
        MULT_WIDTH      :   positive    :=  12;
        OUTPUT_WIDTH    :   positive    :=  12;
        FILTER_ORDER    :   positive    :=  50;
        COEFF_FILE      :   string      :=  "coefficients_python.txt"
    );
end FIRTI_tb;

architecture Behavioral of FIRTI_tb is

    -- clock and reset
    signal clk      :   std_logic;
    signal rst      :   std_logic;
    signal  Tclk    :   time        :=  1 us;
    signal stop_clk :   boolean     :=  false;
    


    
    -- Internal signals
    signal stop_stimuli :   boolean :=  false;
    signal i_en         :   std_logic;
    signal counter      :   integer;
    signal latency      :   integer :=  3;
    signal i_data       :   std_logic_vector(INPUT_WIDTH-1 downto 0);
    signal out_data     :   std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    signal o_matlab     :   std_logic_vector(OUTPUT_WIDTH-1 downto 0);
    
    component FIRTI
        generic (
            INPUT_WIDTH     :   positive;
            COEFF_WIDTH     :   positive;
            ADD_WIDTH       :   positive;
            MULT_WIDTH      :   positive;
            OUTPUT_WIDTH    :   positive;
            FILTER_ORDER    :   positive;
            COEFF_FILE      :   string
        );
        port (
            clk             :   in  std_logic;
            rst             :   in  std_logic;
            i_enable        :   in  std_logic;
            i_data          :   in  std_logic_vector(INPUT_WIDTH-1 downto 0);
            o_data          :   out std_logic_vector(OUTPUT_WIDTH-1 downto 0)
        );
    end component;
    
begin

    DUT :   FIRTI
        generic map(
            INPUT_WIDTH     =>  INPUT_WIDTH,
            COEFF_WIDTH     =>  COEFF_WIDTH,
            ADD_WIDTH       =>  ADD_WIDTH,
            MULT_WIDTH      =>  MULT_WIDTH,
            OUTPUT_WIDTH    =>  OUTPUT_WIDTH,
            FILTER_ORDER    =>  FILTER_ORDER,
            COEFF_FILE      =>  COEFF_FILE
        )
        port map(
            clk         => clk,
            rst         => rst,
            i_enable    => i_en,
            i_data      => i_data,
            o_data      => out_data
        );

---------------------------------------------------------------------------------------------------------------------	
-- 	Stimuli from txt
	stimuli_txt	:	process
		file		i_file		:	text is in "stimuli_python.txt";
		variable	file_line	:	line;
		variable	i_matlab	:	std_logic_vector(INPUT_WIDTH-1 downto 0);
	begin
	    wait until clk = '1';
	    wait until i_en = '1';
		while not endfile(i_file) loop			    	
			readline(i_file,file_line);
			read(file_line,i_matlab);
			i_data	<=	i_matlab;
			wait until clk = '1';	
		end loop;
		file_close(i_file);
		wait;
	end process;

---------------------------------------------------------------------------------------------------------------------	
-- 	Response from txt
	reponse_txt	:	process
		file		o_file		:	text is in "response_matlab.txt";
		variable 	file_line	:	line;
		variable	out_matlab	:	std_logic_vector(OUTPUT_WIDTH-1 downto 0);
	begin
	    wait until clk = '1';
	    wait until i_en = '1';
	    wait for latency*Tclk;	
		while not endfile(o_file) loop			    
			readline(o_file,file_line);
			read(file_line,out_matlab);
			o_matlab	<=	out_matlab;
			wait until clk = '1';
		end loop;
		file_close(o_file);
		wait;
	end process;	        

    clk_p   :  process
    begin
        while not stop_clk loop
            clk <=  '1';
            wait for Tclk/2;
            clk <=  '0';
            wait for Tclk/2;
        end loop;
        wait for 20 us;
        wait;
    end process;
    
    rst_p   :   process
    begin
        rst <=  '0';
        wait for 17 us;
        rst <=  '1';
        wait;
    end process;

    -- Stimuli
    stimuli_p   :   process
    begin
        while not stop_stimuli loop            
            if rst = '0' then
                i_en    <=  '0';
                counter <=  0;
                wait until clk = '1';
            else                  
                if counter < DATA_LENGTH then
                    i_en    <=  '1';
                    counter <=  counter + 1;
                else
                    stop_stimuli    <=  true;
                    i_en    <=  '0';
                    counter <=  0;
                end if;
                wait until clk = '1';
           end if;
        end loop;
        wait for 30 us;
        stop_clk    <=  true;
        wait;
    end process;    
end Behavioral;
