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
        LLR_RECV[0] <= 8'b1111_1100;
        LLR_RECV[1] <= 8'b1111_1011;
        LLR_RECV[2] <= 8'b1111_1000;
        LLR_RECV[3] <= 8'b0000_0010;
        LLR_RECV[4] <= 8'b1111_0011;
        LLR_RECV[5] <= 8'b1111_0100;
        LLR_RECV[6] <= 8'b0010_0001;
        LLR_RECV[7] <= 8'b1111_1001;
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
    
    /* Simulate The bitonic sorting network */
    // Test an N = 8 bitonic sorting network.
    localparam DATA_WIDTH=3;
    localparam LABEL_WIDTH = 3;
    localparam LOG_INPUT_NUM = 3;
    
    reg [DATA_WIDTH*(2**LOG_INPUT_NUM)-1 : 0] x_input;
    wire [DATA_WIDTH*(2**LOG_INPUT_NUM)-1 : 0] x_output;
    
    reg [LABEL_WIDTH*(2**LOG_INPUT_NUM)-1 : 0] l_input;
    wire [LABEL_WIDTH*(2**LOG_INPUT_NUM)-1 : 0] l_output;
    
    initial begin
        x_input[2:0]    <= 3'd7;
        x_input[5:3]    <= 3'd6;
        x_input[8:6]    <= 3'd5;
        x_input[11:9]   <= 3'd4;
        x_input[14:12]  <= 3'd3;
        x_input[17:15]  <= 3'd2;
        x_input[20:18]  <= 3'd1;
        x_input[23:21]  <= 3'd0;
        
        l_input[2:0]    <= 3'd0;
        l_input[5:3]    <= 3'd1;
        l_input[8:6]    <= 3'd2;
        l_input[11:9]   <= 3'd3;
        l_input[14:12]  <= 3'd4;
        l_input[17:15]  <= 3'd5;
        l_input[20:18]  <= 3'd6;
        l_input[23:21]  <= 3'd7;
    end
    
    reg x_valid = 0;
    initial begin
        x_valid <= 0;
        #40 x_valid <= 1;
        #10 x_valid <= 0;
    end
    bitonic_sorting_top #(.LOG_INPUT_NUM(LOG_INPUT_NUM), .DATA_WIDTH(DATA_WIDTH), .LABEL_WIDTH(LABEL_WIDTH), .SIGNED(0), .ASCENDING(1)) 
        bs_inst(.clk(clk), .rst(reset), .x_valid(x_valid), 
    .x(x_input), .x_label(l_input), .y(x_output), .y_label(l_output)); 
    
    
    
endmodule


