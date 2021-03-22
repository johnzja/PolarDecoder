//This Data memory: efficient.
// Engineer:  John Zhu. All rights reserved.
module DataMemory(clk, Address, Write_data, Read_data, MemRead, MemWrite);
	input clk;
	input [31:0] Address, Write_data;
	input MemRead, MemWrite;
	output [31:0] Read_data;
	reg [31:0] Read_data;
	//RAM_Size is counted in words.
	parameter RAM_SIZE = 1024;
	parameter RAM_SIZE_BIT = 10;
	
	reg [31:0] RAM_data[RAM_SIZE - 1: 0];
	//assign Read_data = MemRead? RAM_data[Address[RAM_SIZE_BIT + 1:2]]: 32'h00000000;

	always @(posedge clk)
	begin
	   if (MemWrite)
		  RAM_data[Address[RAM_SIZE_BIT + 1:2]] <= Write_data;
	   if(MemRead)
	       Read_data <= RAM_data[Address[RAM_SIZE_BIT + 1:2]];
	   else
	       Read_data <= 32'h0;
    end
	
endmodule
