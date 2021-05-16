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
    reg [8*(LLR_WIDTH)-1:0] LLR_RECV;
    
    integer k;
    initial begin
    /*
        LLR_RECV[7:0]   <= 8'b1111_1100;    // -2.0 * 2
        LLR_RECV[15:8]  <= 8'b1111_1011;    // -2.5 * 2
        LLR_RECV[23:16] <= 8'b1111_1000;    // -4.0 * 2
        LLR_RECV[31:24] <= 8'b0000_0010;    // 1.0  * 2
        LLR_RECV[39:32] <= 8'b1111_0011;    // -6.5 * 2
        LLR_RECV[47:40] <= 8'b0000_1100;    // 6.0  * 2
        LLR_RECV[55:48] <= 8'b0010_0001;    // 16.6 * 2
        LLR_RECV[63:56] <= 8'b0000_0111;    // 3.5  * 2
        */
        LLR_RECV[7:0]   <= 8'd29;    // -2.0 * 2
        LLR_RECV[15:8]  <= 8'd245;    // -2.5 * 2
        LLR_RECV[23:16] <= 8'd242;    // -4.0 * 2
        LLR_RECV[31:24] <= 8'd33;    // 1.0  * 2
        LLR_RECV[39:32] <= 8'd29;    // -6.5 * 2
        LLR_RECV[47:40] <= 8'd241;    // 6.0  * 2
        LLR_RECV[55:48] <= 8'd230;    // 16.6 * 2
        LLR_RECV[63:56] <= 8'd10;    // 3.5  * 2
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
                input_ready <= 1;
            end
            
            4'h1: begin
                input_ready <= 0;
                FSM_state <= 4'h2;
            end
            
            4'h2: begin
                FSM_state <= 4'h2;      // Absorption state.
            end
        endcase
    end
    
    SCList_Decoder #(.LLR_WIDTH(LLR_WIDTH), .n(3), .l(2), .K(4)) 
            scl_decoder(.clk(clk), .reset(reset), .input_ready(input_ready), .output_ready(output_ready), .decoded_bits(decoded_bits), .LLR(LLR_RECV));
    
    /* Simulate The bitonic sorting network */
    // Test an N = 8 bitonic sorting network.
    /*
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
    */
    
    
endmodule


