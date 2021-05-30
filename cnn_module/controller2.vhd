library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.std_logic_unsigned.all;

 Entity controller2 is 
		generic(
		ADDRESS_SIZE : integer := 16;
		WORDSIZE : integer := 16;
	-- * IMMEDIATE_START_ADDRESS = 3575 + 16 * 120 * 5 * 5 = 51575
		IMMEDIATE_START_ADDRESS : integer := 51575 
		);
		port(
		start : in std_logic;
		clk : in std_logic;
        reset : in std_logic; -- NEW everything is reset if =1
		we : out std_logic;
		EWF : out std_logic;
		EWB : out std_logic;
		out_conv : out std_logic;
		enable_conv : out std_logic;
		out_pool : out std_logic;
		done : out std_logic;   -- NEW  is set to 1 on done
		reset_accumulator : out std_logic;
		filterAddress : out  std_logic_vector(ADDRESS_SIZE-1 downto 0);
		BuffAddress : out  std_logic_vector(ADDRESS_SIZE-1 downto 0);
		MemAddress : out  std_logic_vector(ADDRESS_SIZE-1 downto 0);
		ConvAddress : out std_logic_vector(ADDRESS_SIZE-1 downto 0);
		PoolAddress : out  std_logic_vector(ADDRESS_SIZE-1 downto 0)
		);
end entity;

ARCHITECTURE controller2Arc OF controller2 is

	-- type small_rom is array (0 to 4) of std_logic_vector(WORDSIZE-1 downto 0);
	type small_rom is array (0 to 4) of integer range 0 to 2**WORDSIZE - 1;
	-- IMMEDIATE_START_ADDRESS = 3575 + 16 * 120 * 5 * 5 = 51575

 	signal total_layer_count : integer range 0 to 10 := 5;

	signal layer_type_rom : small_rom := (0,1,0,1,0); -- 0 is convolution 1 pooling

	signal input_start_address_rom : small_rom := (
	0,	-- input of conv
	IMMEDIATE_START_ADDRESS , -- input to pool
	IMMEDIATE_START_ADDRESS + 784*6, -- input to conv
	IMMEDIATE_START_ADDRESS + 784*6+196*6,	-- input to  pool 
	IMMEDIATE_START_ADDRESS + 784*6+196*6+16*100 -- input to conv
	);
	signal input_size_rom : small_rom := (1024,784,14*14,100,5*5); -- size of image in each layer
	signal window_input_size_rom : small_rom := (32,28,14,10,5); -- size of image in each layer
	
	signal output_size_rom : small_rom := (784,196,100,5*5,1);
	signal window_output_size_rom : small_rom := (28,14,10,5,1); -- size of output in each layer


	signal output_start_address_rom : small_rom := (
		IMMEDIATE_START_ADDRESS , -- conv reads from
		IMMEDIATE_START_ADDRESS +784*6, -- pooling start write
		IMMEDIATE_START_ADDRESS +784*6+196*6,-- convolution start write
		IMMEDIATE_START_ADDRESS +784*6+196*6+16*100,-- convolution start write
		IMMEDIATE_START_ADDRESS +784*6+196*6+16*100+ 25 * 16); -- last convolution start write

	signal filter_start_address_rom : small_rom := (1024,0,1174,0,3575);
	signal max_feature_maps_rom : small_rom := (6,6,16,16,120);
	signal max_depth_rom : small_rom := (1,0,6,0,16);
	--signal current_layer_sig : integer range 0 to 4 := 0;
	

	--these are the input to convolution and to pooling
	
	-- signal input_start_address : integer range 0 to 2**WORDSIZE - 1 := 0;  
	-- signal input_size : integer range 0 to 2**WORDSIZE - 1 := 0; -- this is the input of 2D Image or matrix
	-- signal output_start_address : integer range 0 to 2**WORDSIZE - 1 := 0; -- this the first place to write to the output
	-- signal output_size : integer range 0 to 2**WORDSIZE - 1 := 0; -- the output of 1 feature map convolved
	-- signal filter_start_address: integer range 0 to 2**WORDSIZE - 1 := 0; -- the address of the 1st filter
	-- signal max_feature_maps : integer range 0 to 2**WORDSIZE - 1 := 0;  -- eg. 16 
	-- signal max_depth : integer range 0 to 2**WORDSIZE - 1 := 0;
	--signal initiate : Integer := 0;

	begin 		
		process (start, clk, reset) is
			variable MemAddr : std_logic_vector(ADDRESS_SIZE-1 downto 0);
			variable BuffTempAddr : std_logic_vector(ADDRESS_SIZE-1 downto 0);
			variable layerCounter : Integer;
			variable wordsCount : Integer;
			variable feature : Integer;
			variable depth : Integer;
			variable image_loaded : Integer;
			variable filter_loaded : Integer;
			variable output_saved : Integer;
			variable initiate : Integer;
			variable temp_input_start_address : integer range 0 to 2**WORDSIZE - 1 := 0; 
			variable temp_filter_start_address : integer range 0 to 2**WORDSIZE - 1 := 0; 
			variable temp_output_start_address : integer range 0 to 2**WORDSIZE - 1 := 0;
			variable input_start_address : integer range 0 to 2**WORDSIZE - 1 := 0;  
			variable input_size : integer range 0 to 2**WORDSIZE - 1 := 0; -- this is the input of 2D Image or matrix
			variable output_start_address : integer range 0 to 2**WORDSIZE - 1 := 0; -- this the first place to write to the output
			variable output_size : integer range 0 to 2**WORDSIZE - 1 := 0; -- the output of 1 feature map convolved
			variable filter_start_address: integer range 0 to 2**WORDSIZE - 1 := 0; -- the address of the 1st filter
			variable max_feature_maps : integer range 0 to 2**WORDSIZE - 1 := 0;  -- eg. 16 
			variable max_depth : integer range 0 to 2**WORDSIZE - 1 := 0;
			variable current_layer_sig : integer range 0 to 5 := 0;
			variable tmp_done : std_logic;
			variable row  : integer range 0 to 2**WORDSIZE - 1 := 0;
			variable col  : integer range 0 to 2**WORDSIZE - 1 := 0;
			variable window_input_size : integer range 0 to 2**WORDSIZE - 1 := 0;
			variable window_output_size : integer range 0 to 2**WORDSIZE - 1 := 0;
			
			begin 

				if rising_edge(start) or rising_edge(reset) then -- TODO: add reset here
					--intialization
						current_layer_sig := 0;
						feature := 0;
						depth := 0;	
						image_loaded := 0;
						filter_loaded := 0;	
						output_saved := 1;	
						EWB <= '0';
						EWF	<= '0';
						wordsCount := 0;
						MemAddr := X"0000";
						BuffTempAddr := X"0000";
						row := 0;
						col := 0;
						done <= '0';
						initiate := 0;
						reset_accumulator <= '1';
						tmp_done := '0';

 				elsif start = '1' and  rising_edge(clk) and tmp_done = '0' then					
					if layer_type_rom(current_layer_sig) = 0 then 
					--intialization convolution
						if initiate = 0 then
							initiate := 1;
							-- enable_convolvution= 0
							enable_conv <=  '0';
							input_start_address := input_start_address_rom(current_layer_sig);
							temp_input_start_address := input_start_address_rom(current_layer_sig);
							input_size := input_size_rom(current_layer_sig);
							output_start_address := output_start_address_rom(current_layer_sig);
							output_size := output_size_rom(current_layer_sig);
							filter_start_address := filter_start_address_rom(current_layer_sig);
							temp_filter_start_address := filter_start_address_rom(current_layer_sig);
							max_feature_maps := max_feature_maps_rom(current_layer_sig);
							max_depth := max_depth_rom(current_layer_sig);
							output_saved := 1;
							window_input_size := window_input_size_rom(current_layer_sig);
							window_output_size := window_output_size_rom(current_layer_sig);
							row := 0;
							col := 0;

						elsif image_loaded = 0 then
							-- read from memory --
							we <= '0';
							-- Load Input from MemAddr = input_start_address + input_size * feature 
							EWB <= '1';
							MemAddress <= temp_input_start_address + MemAddr;
							BuffAddress <= BuffTempAddr;

							-- buffer address 
							if col = window_input_size - 1 then
								col := 0;
								row := row + 1;
								BuffTempAddr := std_logic_vector(to_unsigned((row * 32), ADDRESS_SIZE));
							else
								col  := col+ 1;
								BuffTempAddr := BuffTempAddr + X"0001";
								end if;
								
							-- memory location address	
							MemAddr := MemAddr + X"0001";
							wordsCount := wordsCount + 1;

							-- BuffAddr <= wordsCount  -- DONE:
							if wordsCount = input_size + 1 then 
								EWB <= '0' ;
								image_Loaded := 1;
								-- EWF <= '1';
								wordsCount := 0;
								MemAddr := X"0000";
								BuffTempAddr := X"0000";
							end if;
						elsif filter_loaded = 0 then
							EWF <= '1'; 
							MemAddress <= temp_filter_start_address + MemAddr ;
							filterAddress <= MemAddr;

							
							MemAddr := MemAddr + X"0001";
							wordsCount := wordsCount + 1;					
							
							if wordsCount = 5*5 + 1 then 
								EWF <= '0' ;
								filter_loaded := 1;
						 		wordsCount := 0;
								row := 0;
								col := 0;
								BuffTempAddr := X"0000";
								MemAddr := X"0000";
								enable_conv <= '1';
							end if;
						elsif output_saved = 0 then	--DONE: handle saving
							we <= '1';
							out_conv <= '1';
							-- Load Input from MemAddr = input_start_address + input_size * feature 
							MemAddress <= temp_output_start_address + MemAddr;
							ConvAddress <=  BuffTempAddr;

							-- convolution buffer address 
							if col = window_output_size - 1 then
								col := 0;
								row := row + 1;
								BuffTempAddr := std_logic_vector(to_unsigned((row * 28), ADDRESS_SIZE));
							else
								col  := col+ 1;
								BuffTempAddr := BuffTempAddr + X"0001";
							end if;

							-- memory address
							MemAddr := MemAddr + X"0001";
							wordsCount := wordsCount + 1;
							
                            -- BuffAddr <= wordsCount  -- DONE:
							if wordsCount = output_size + 1 then 
								output_saved := 1;
								wordsCount := 0;
								row := 0;
								col := 0;
								MemAddr := X"0000";
								BuffTempAddr := X"0000";
								out_conv <= '0';
								we <= '0';
								if current_layer_sig > 0 and feature < max_feature_maps then
									image_loaded := 0;	
									temp_input_start_address :=  input_start_address + input_size * depth;
								end if;
								if feature < max_feature_maps then
									filter_loaded := 0;	
									temp_filter_start_address :=  filter_start_address + feature * max_depth*25 +25 * depth;
								end if;
							end if;
						elsif feature < max_feature_maps then
							--reset_accumulator = 1
							if (depth) < max_depth then		
							--to read another input--------------------
							-- change input image with depth or with feature?
							-- DONE: this was incorrect (now correct)
							-- input_start_address shouldn't be updated depth update automatical updates the address
							--depth = depth + 1
								depth := depth + 1;		--TODO: think about depth in bigger layers
								if current_layer_sig > 0 and depth < max_depth then
									image_loaded := 0;	
									temp_input_start_address :=  input_start_address + input_size * depth;
								end if;
								---------------------------------------------
								---------------to read another	filter ---------------
								if depth < max_depth then
									filter_loaded := 0;	
									temp_filter_start_address :=  filter_start_address + feature * max_depth +25 * depth;
								end if;
								--filter_start_address	<= filter_start_address + max_depth * feature + filter_size(eg. 25)
							-----------------------------------------------------------------------
								-- reset_acummulator=0	// has no effect when accumulating
								
								-- DONE: signals are only update at the end of process
								reset_accumulator <=  '0';								
								-- enable_convolve= 0
								enable_conv <=  '0';						
								
								--depth = depth + 1
								--depth := depth + 1;
							else    -- depth is complet
                                depth := 0;
								output_saved := 0;
								row := 0;
								col := 0;
								enable_conv <= '0';
								--store output at MemAddr = output_start_address + output_size*feature
								temp_output_start_address := output_start_address + output_size*feature;
                                
								feature := feature + 1;
								reset_accumulator <= '1';
							end if;							
						else    -- feature is maximum
                            feature := 0; --reset featuers
							 --current_layer_counter+=1
                             -- TODO handle max feature
                            current_layer_sig := current_layer_sig + 1;
							initiate := 0;
                            if current_layer_sig = total_layer_count then
                                done <= '1'; -- now computation is done
								tmp_done := '1';
                            else
                                done <= '0';
								   := '0';
                            end if;
						end if;
					end if;
-- 						-- Pooling Handling
					elsif layer_type_rom(current_layer_sig) = 1 then
							--intialize pooling
							if initiate = 0 then
								initiate := 1;
								input_start_address := input_start_address_rom(current_layer_sig);
								temp_input_start_address := input_start_address_rom(current_layer_sig);
								input_size := input_size_rom(current_layer_sig);
								output_start_address := output_start_address_rom(current_layer_sig);
								output_size := output_size_rom(current_layer_sig);
								filter_start_address := filter_start_address_rom(current_layer_sig);
								temp_filter_start_address := filter_start_address_rom(current_layer_sig);
								max_feature_maps := max_feature_maps_rom(current_layer_sig);
								max_depth := max_depth_rom(current_layer_sig);
								output_saved := 1;	
								window_input_size := window_input_size_rom(current_layer_sig);
								window_output_size := window_output_size_rom(current_layer_sig);
								row := 0;
								col := 0;
							
							elsif image_loaded = 0 then
								-- read from memory --
								we <= '0';
								-- Load Input from MemAddr = input_start_address + input_size * feature 
								EWB <= '1';
								MemAddress <= temp_input_start_address + MemAddr ;
								BuffAddress <= BuffTempAddr;

								if col = window_input_size - 1 then
									col := 0;
									row := row + 1;
									BuffTempAddr := std_logic_vector(to_unsigned((row * 32), ADDRESS_SIZE));
								else
									col  := col+ 1;
									BuffTempAddr := BuffTempAddr + X"0001";
								end if;
								
								MemAddr := MemAddr + X"0001";
								
								wordsCount := wordsCount + 1;  
								if wordsCount = input_size + 1 then 
									EWB <= '0' ;
									image_loaded := 1;
									MemAddr := X"0000";
									row := 0;
									col := 0;
									BuffTempAddr := X"0000";
									wordsCount := 0;
								end if;
							elsif output_saved = 0 then	--TODO: handle saving
								we <= '1';
								out_pool <= '1';
								-- Load Input from MemAddr = input_start_address + input_size * feature 
								MemAddress <= temp_output_start_address + MemAddr;
								PoolAddress <=  BuffTempAddr;

								-- convolution buffer address 
								if col = window_output_size - 1 then
									col := 0;
									row := row + 1;
									BuffTempAddr := std_logic_vector(to_unsigned((row * 14), ADDRESS_SIZE));
								else
									col  := col+ 1;
									BuffTempAddr := BuffTempAddr + X"0001";
								end if;

								MemAddr := MemAddr + X"0001";
								wordsCount := wordsCount + 1;
							
								-- BuffAddr <= wordsCount  -- TODO:
								if wordsCount = output_size +1 then 
									output_saved := 1;
									wordsCount := 0;
									MemAddr := X"0000";
									row := 0;
									col := 0;
									BuffTempAddr := X"0000";
									out_pool <= '0';
									we <= '0';	
									if current_layer_sig > 0 and feature < max_feature_maps then
										image_loaded := 0;	
										temp_input_start_address :=  input_start_address + input_size * depth;
									end if;								end if;	
							elsif feature < max_feature_maps then
								
					
								-- OUT_POOL=1
								out_pool <= '1';
								-- store output at MemAddr = output_start_address + output_size*feature
								output_saved := 0;
								temp_output_start_address := output_start_address + output_size*feature;
								-- OUT_POOL = 0
								out_pool <= '0';

								feature := feature + 1;
								if feature < max_feature_maps then 
									-- if need to read another input use image_loaded = 0
									image_loaded := 0;	
									-- Load Input from MemAddr = input_start_address + input_size * feature 
									temp_input_start_address :=  input_start_address + input_size * feature;
								end if;
							else
								feature := 0; --reset featuers
								--current_layer_counter+=1
								-- TODO handle max feature
								current_layer_sig := current_layer_sig + 1;
								initiate := 0;
								if current_layer_sig = total_layer_count then
									done <= '1'; -- now computation is done
									tmp_done := '1';
						   		else
									done <= '0';
									tmp_done := '0';
						   		end if;
							end if;
				end if;
		end process;
end controller2Arc;
