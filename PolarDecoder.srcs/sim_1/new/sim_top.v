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
    
    
    parameter LLR_WIDTH = 8;
    parameter INNER_LLR_WIDTH = LLR_WIDTH + 3;
    
    localparam M = 16;
    localparam K_CRC = 4;
    localparam K = M+K_CRC;
    localparam n = 5;
    localparam N = 2**n;
    
    wire [K-1:0] decoded_bits;
    wire [N*(INNER_LLR_WIDTH)-1:0] LLR_RECV;
    reg [LLR_WIDTH-1:0] LLR_RECV_formatted[N-1:0];
    
    genvar i;
    generate
        for(i=0;i<N;i=i+1) begin: LLR_recv_formatter
            assign LLR_RECV[(i+1)*INNER_LLR_WIDTH-1:i*INNER_LLR_WIDTH] = {{(INNER_LLR_WIDTH-LLR_WIDTH){LLR_RECV_formatted[i][LLR_WIDTH-1]}}, LLR_RECV_formatted[i]};
        end
    endgenerate
    
    
    integer k;
    initial begin
        LLR_RECV_formatted[0]       <= 8'd10;
        LLR_RECV_formatted[1]       <= 8'd0;
        LLR_RECV_formatted[2]       <= 8'd255;
        LLR_RECV_formatted[3]       <= 8'd22;
        LLR_RECV_formatted[4]       <= 8'd16;
        LLR_RECV_formatted[5]       <= 8'd236;
        LLR_RECV_formatted[6]       <= 8'd17;
        LLR_RECV_formatted[7]       <= 8'd23;
        LLR_RECV_formatted[8]       <= 8'd248;
        LLR_RECV_formatted[9]       <= 8'd253;
        LLR_RECV_formatted[10]      <= 8'd17;
        LLR_RECV_formatted[11]      <= 8'd243;
        LLR_RECV_formatted[12]      <= 8'd13;
        LLR_RECV_formatted[13]      <= 8'd5;
        LLR_RECV_formatted[14]      <= 8'd18;
        LLR_RECV_formatted[15]      <= 8'd3;
        LLR_RECV_formatted[16]      <= 8'd3;
        LLR_RECV_formatted[17]      <= 8'd5;
        LLR_RECV_formatted[18]      <= 8'd245;
        LLR_RECV_formatted[19]      <= 8'd22;
        LLR_RECV_formatted[20]      <= 8'd247;
        LLR_RECV_formatted[21]      <= 8'd239;
        LLR_RECV_formatted[22]      <= 8'd21;
        LLR_RECV_formatted[23]      <= 8'd232;
        LLR_RECV_formatted[24]      <= 8'd10;
        LLR_RECV_formatted[25]      <= 8'd243;
        LLR_RECV_formatted[26]      <= 8'd14;
        LLR_RECV_formatted[27]      <= 8'd14;
        LLR_RECV_formatted[28]      <= 8'd5;
        LLR_RECV_formatted[29]      <= 8'd245;
        LLR_RECV_formatted[30]      <= 8'd244;
        LLR_RECV_formatted[31]      <= 8'd16;
        /*
        LLR_RECV[7:0]   <= 8'd29;    // -2.0 * 2
        LLR_RECV[15:8]  <= 8'd245;    // -2.5 * 2
        LLR_RECV[23:16] <= 8'd242;    // -4.0 * 2
        LLR_RECV[31:24] <= 8'd33;    // 1.0  * 2
        LLR_RECV[39:32] <= 8'd29;    // -6.5 * 2
        LLR_RECV[47:40] <= 8'd241;    // 6.0  * 2
        LLR_RECV[55:48] <= 8'd230;    // 16.6 * 2
        LLR_RECV[63:56] <= 8'd10;    // 3.5  * 2
        */
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
    
    SCList_Decoder #(.LLR_WIDTH(INNER_LLR_WIDTH), .n(n), .l(3), .K(K), .FROZEN_BITS(32'b00000000000000110000011101111111)) 
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


