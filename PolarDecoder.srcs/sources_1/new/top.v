`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:     Tsinghua University
// Engineer:    John Zhu
// 
// Create Date: 2021/02/21 14:17:33
// Design Name: SCList Polar Decoder
// Module Name: top
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


module top(
    input wire clk,
    input wire reset,
    output wire [3:0] decoded_bits
    );
    
    reg input_ready; wire output_ready;
    
    parameter LLR_WIDTH = 8;
    reg [LLR_WIDTH-1:0] LLR_RECV[7:0];
    
    initial begin
        LLR_RECV[0] <= 8'b1111_1100;    // -2.0 * 2
        LLR_RECV[1] <= 8'b1111_1011;    // -2.5 * 2
        LLR_RECV[2] <= 8'b1111_1000;    // -4.0 * 2
        LLR_RECV[3] <= 8'b0000_0010;    // 1.0  * 2
        LLR_RECV[4] <= 8'b1111_0011;    // -6.5 * 2
        LLR_RECV[5] <= 8'b0000_1100;    // 6.0  * 2
        LLR_RECV[6] <= 8'b0010_0001;    // 16.6 * 2
        LLR_RECV[7] <= 8'b0000_0111;    // 3.5  * 2
    end
    
    reg [3:0] FSM_state;
    reg [2:0] counter;
    
    initial begin
        FSM_state <= 0;
        counter <= 0;
        input_ready <= 0;
    end
    
    always@(posedge clk) begin
        if(reset) begin
            FSM_state <= 0;
            counter <= 0;
            input_ready <= 0;
        end else
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
    
    SCList_Decoder #(.LLR_WIDTH(LLR_WIDTH), .n(3), .l(2), .K(4)) pd(.clk(clk), .reset(reset), .input_ready(input_ready), .output_ready(output_ready), .decoded_bits(decoded_bits), .LLR(LLR_RECV[counter]));
    
endmodule
