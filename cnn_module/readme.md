# CNN Module hardware architecture
`
this is the repo that contains the code document and image of the cnn module of the cnn architecture on hardwre project
`
# languages
* TCL
* VHDL
# Tools And Technology
* **Siemens EDA tools**
* **NitroSoc** for placement And Routing
* **ModelSim** for hdl design, post routing simulation , and post sysnthesis simulation 
* **45 Nanometer Technology**: 
* **Calibre**:  for layout vs schematic and GDSII. (this tool was cancelled by course admin due to lack of time .)

![ScreenShot of the cnn module architecture](https://github.com/marait123/CNN_Project/blob/master/cnn_module/doc-images/cnn_schema.JPG?raw=true)
## Main Modules of the hardware 
* **Controller**: this is the module responsible for producing the signals that govern the movement of information among different modules of the architecture.
* **Bus**: this bus is connected to dataout of the memory where it receives data from the memory when controller instructs the memory to output data
* **Convolution Layer Circuit**: this is the circuit that does convolution on all of the input at the same time (one clock cycle for all the input). 
* **Pooling Layer Circuit**: this is the circuit that does pooling operation on all of the input at the same time (one clock cycle for all the input). 
* **Filter Buffer**: this is the buffer where the filter weights are being placed after being read from memory
* **Data Buffer**: this is the buffer where the input data (eg. the image is placed after it is being read from memory
* **Pooling Output Mux**: this is the mux which is used to write the output of the layer to memory ( since we can write only one word at a time we use it to select word by word and write it tot the memroy)
* **Convolution Output Mux**: same as pooling output mux but for the output of the convolution.
# Algorithm (how it works)
## General Description of the Algo
	## below is just a description of the algorithm
	1. Start when signal “start” becomes 1.
	2. Initiate starting address of input and filter and size, number of layers, depth.
	3. Do the following for each layer of the conv base architecture
		- If layer is convolution:
			- for each filter
				- Read input.
				- Read filter.
				- Convolve the filter with input.
				- Save intermediate result.
		- If layer is pooling:
			- Read all input and place inside buffers.
			- do the pooling operation.
			- Save intermediate result.
	4.When all layers are finished done signal becomes ‘1’ and now data is ready to be delivered to FC-sub team.

## Pseduo  Code
```
/*
the below sudo code descripes the flow of our algorithm
*/

layers = [0,1,2,3,4]
* IMMEDIATE_START_ADDRESS= 3575 + 16 * 120 * 5 * 5 = 51575
* layer_type_rom = [0,1,0,1,0] // 0 Convolution 1 Pooling
* input_start_address_rom = [
	0,	-- input of conv
	IMMEDIATE_START_ADDRESS , -- input to pool
	IMMEDIATE_START_ADDRESS + 784*6, -- input to conv
	IMMEDIATE_START_ADDRESS + 784*6+196*6,	-- input to  pool 
	IMMEDIATE_START_ADDRESS + 784*6+196*6+16*100 -- input to conv
] 
* input_size_rom = [1024,784,14*14,100,5*5] 
* output_start_address_rom = [
	IMMEDIATE_START_ADDRESS , -- conv reads from
	IMMEDIATE_START_ADDRESS +784*6, -- pooling start write
	IMMEDIATE_START_ADDRESS +784*6+196*6,-- convolution start write
	IMMEDIATE_START_ADDRESS +784*6+196*6+16*100,-- convolution start write
	IMMEDIATE_START_ADDRESS +784*6+196*6+16*100+ 25 * 16
] 
* output_size_rom = [784,14*14=196,100,5*5,1] 
* filter_start_address_rom = [1024,*,1174,*,3575] 
* max_feature_maps_rom = [6,6,16,16,120] eg. 16 
* max_depth_rom = [1,*,6,*,16] 	eg. 6

intialize {
current_layer_counter = 0
}

POOLING 
// inputs
* input_start_address
* input_size // this is the input of 2D Image or matrix
* output_start_address // this the first place to write to the output
* output_size // the output of 1 feature map pooled
* max_feature_maps // this the number of feature maps of the prevoius conv layer
					// and the number of output maps from the current
on (start, clk, current_layer_counter)
if layer_type[current_layer_counter] == 1;
	// intialize the POOLING

	input_start_address = input_start_address_rom[current_layer_counter]
	input_size = input_size_rom[current_layer_counter]
	output_start_address = output_start_address_rom[current_layer_counter]
	output_size = output_size_rom[current_layer_counter]
	max_feature_maps = max_feature_maps_rom[current_layer_counter]


	For feature = 0 : max_feature_maps;
		Load Input from MemAddr = input_start_address + input_size * feature 
		OUT_POOL=1
		store output at MemAddr = output_start_address + output_size*feature
		OUT_POOL = 0
	current_layer_counter+=1


Convolution 
// inputs
* input_start_address
* input_size // this is the input of 2D Image or matrix
* output_start_address // this the first place to write to the output
* output_size // the output of 1 feature map convolved
* filter_start_address // the address of the 1st filter
* max_feature_maps eg. 16 
* max_depth 	eg. 6

if layer_type[current_layer_counter] == 0;

	// initialze Convolution	
	input_start_address = input_start_address_rom[current_layer_counter]
	input_size = input_size_rom[current_layer_counter]
	output_start_address = output_start_address_rom[current_layer_counter]
	output_size = output_size_rom[current_layer_counter]
	max_feature_maps = max_feature_maps_rom[current_layer_counter]
	filter_start_address = filter_start_address_rom[current_layer_counter]
	max_feature_maps = max_feature_maps_rom[current_layer_counter]
	max_depth = max_depth_rom[current_layer_counter]


	For feature = 0 : max_feature_maps;
		reset_accumulator = 1
		for depth in max_depth;		// now accumulating the result
			Load Input from MemAddr = input_start_address + input_size * feature 
			Load Filter from MemAddr = filter_start_address + max_depth * feature + filter_size(eg. 25)
			reset_acummulator=0	// has no effect when accumulating
			enable_convolve=0
			enalble_convolve = 1
			enable_convolve=0 // now data in buffers
			
		store output at MemAddr = output_start_address + output_size*feature
	current_layer_counter+=1

	
```
# Work Devision:
## Mohammed Ibrahim
	* System Architecture and Design (Schema Design) 
	* Pseudo Code and ALgorithm Design.
	* Controller Internal Design, preparation, Intialization and integration into the larger system.
	* **double for loop generate** to do all at the same time convolution.
## Ahmed Magdy:
	* Convolution Submodule.
	* Pooling SubModule.
	* Project Integration.
## Mohammed Abo Bakr
	* Controller Convolution.
	* Tunning variations in the input size
## Omar Tarek
	* Integration.
	* Adminstrative work.
	* Work Coordination and work negotiation.
	* helped with uncompeleted work of cnn module integration into the bigger architecture>