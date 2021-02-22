`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/02/21 12:14:31
// Design Name: 
// Module Name: sim_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sim_top(

    );
    
    reg clk;
    initial clk = 0;
    always #5 clk <= ~clk;
    
    reg reset;
    initial begin
        reset = 1;
        #10 reset = 0;
    end
    reg input_ready; wire output_ready;
    wire [3:0] decoded_bits;
    
    parameter LLR_WIDTH = 8;
    reg [LLR_WIDTH-1:0] LLR_RECV[7:0];
    
    initial begin
        LLR_RECV[0] <= 8'h01;
        LLR_RECV[1] <= 8'h01;
        LLR_RECV[2] <= 8'hff;
        LLR_RECV[3] <= 8'hff;
        LLR_RECV[4] <= 8'hff;
        LLR_RECV[5] <= 8'hff;
        LLR_RECV[6] <= 8'h01;
        LLR_RECV[7] <= 8'h01;
    end
    
    reg [3:0] FSM_state;
    reg [2:0] counter;
    
    initial begin
        FSM_state <= 0;
        counter <= 0;
        input_ready <= 0;
    end
    
    always@(posedge clk) begin
        case(FSM_state)
            4'h0: begin
                FSM_state <= 4'h1;
                counter <= 0;
                input_ready <= 1;
            end
            
            4'h1: begin
                input_ready <= 0;
                FSM_state <= 4'h2;
            end
            
            4'h2: begin
                counter <= counter + 1;
                if(counter == 7) FSM_state <= 4'h3;
            end
            
            4'h3: begin
                FSM_state <= 4'h3;
            end
        
        endcase
    end
    
    PolarDecoder #(.LLR_WIDTH(LLR_WIDTH)) pd(.clk(clk), .reset(reset), .input_ready(input_ready), .output_ready(output_ready), .decoded_bits(decoded_bits), .LLR(LLR_RECV[counter]));
    
endmodule


