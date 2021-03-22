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
    output wire [7:0] decoded_bits,
    input wire Rx_Serial,
    output wire Tx_Serial,

    input wire [2:0] SW,
    output wire [7:0] D
    );
    
    wire manual_reset;
    debounce deb(clk, reset, manual_reset);

    reg input_ready; wire output_ready;
    
    parameter LLR_WIDTH = 11;            // Additional bits = 3.
    
    parameter n = 4;
    parameter N = 2**n;
    parameter M = 8;
    parameter l = 3;

    reg [LLR_WIDTH-1:0] LLR_RECV [N-1:0];
    
    integer k;
    // initial begin
    //     LLR_RECV[0] <= 11'b0001111_1100;    // -2.0 * 2
    //     LLR_RECV[1] <= 11'b0001111_1011;    // -2.5 * 2
    //     LLR_RECV[2] <= 11'b0001111_1000;    // -4.0 * 2
    //     LLR_RECV[3] <= 11'b0000000_0010;    // 1.0  * 2
    //     LLR_RECV[4] <= 11'b0001111_0011;    // -6.5 * 2
    //     LLR_RECV[5] <= 11'b0000000_1100;    // 6.0  * 2
    //     LLR_RECV[6] <= 11'b0000010_0001;    // 16.6 * 2
    //     LLR_RECV[7] <= 11'b0000000_0111;    // 3.5  * 2
    // end
    
    wire [N*LLR_WIDTH-1:0] LLR_recv_bitstr;
    genvar i;
    generate
        for(i=0;i<N;i=i+1) begin: gen_LLR_recv_bitstr
            assign LLR_recv_bitstr[((i+1)*LLR_WIDTH)-1:i*LLR_WIDTH] = LLR_RECV[i];
        end
    endgenerate


    reg [3:0] FSM_state;
    reg [n-1:0] counter;
    
    initial begin
        FSM_state <= 0;
        counter <= 0;
        input_ready <= 0;
    end

    // Engineer:  John Zhu. All rights reserved.
    /*-------------------RX/TX modules---------------*/
    // One byte transmitted at a time.
    wire Rx_DataValid;
    wire [7:0] Rx_Data;
    uart_rx Rx(.i_Clock(clk), .i_Rx_Serial(Rx_Serial), .o_Rx_DV(Rx_DataValid), .o_Rx_Byte(Rx_Data));
    
    reg Tx_DataValid;
    reg [7:0] Tx_Data;
    wire Tx_Active;
    wire Tx_Done;
    uart_tx Tx(.i_Clock(clk), .i_Tx_DV(Tx_DataValid), .i_Tx_Byte(Tx_Data), .o_Tx_Serial(Tx_Serial), 
                .o_Tx_Active(Tx_Active), .o_Tx_Done(Tx_Done));
    
    /*-------------FSM for UART Tx and Rx---------------*/
    
    reg [3:0] UART_Rx_FSM_state;
    reg [n-1:0] UART_RecvCnt;
    reg [7:0] ByteCnt;                  // Number of input LLRs.

    localparam INIT         = 4'h0;
    localparam RecvData     = 4'h1;
    localparam RecvComplete = 4'h2;

    // Receive-FSM.
    always@(posedge clk or posedge manual_reset) begin
        if(manual_reset) begin
            UART_Rx_FSM_state <= INIT;
            UART_RecvCnt <= -1;
        end else begin
            case(UART_Rx_FSM_state)
                INIT: begin
                    if(Rx_DataValid) begin
                        ByteCnt = Rx_Data;
                        if(ByteCnt == N) begin
                            UART_Rx_FSM_state <= RecvData;
                            UART_RecvCnt <= -1;
                        end
                    end
                end

                RecvData: begin
                    if(Rx_DataValid) begin
                        UART_RecvCnt = UART_RecvCnt + 1;
                        LLR_RECV[UART_RecvCnt] <= {{3{Rx_Data[7]}}, Rx_Data};   // Sign-extension.
                        //LLR_RECV[UART_RecvCnt] <= Rx_Data;      // Sign-extension.

                        if(UART_RecvCnt == N-1) begin
                            input_ready <= 1'b1;
                            UART_Rx_FSM_state <= RecvComplete;
                        end
                    end
                end

                RecvComplete: begin
                    input_ready <= 1'b0;
                    UART_Rx_FSM_state <= INIT;
                end
                
            endcase
        end
    end

    assign D = LLR_RECV[SW];      // Debug Port.

    reg [3:0] UART_Tx_FSM_state;
    reg [3:0] decoded_bits_to_transmit;
    reg [7:0] decoded_byte_to_transmit;

    localparam TransmitData     = 4'h1;
    localparam WaitTransmit     = 4'h2;

    always@(posedge clk or posedge manual_reset) begin
        if(manual_reset) begin
            UART_Tx_FSM_state <= 0;
        end else case(UART_Tx_FSM_state)
            INIT: begin
                if(output_ready) begin
                    // decoded_byte_to_transmit <= {4'b0000, decoded_bits};
                    decoded_byte_to_transmit <= decoded_bits;
                    UART_Tx_FSM_state <= TransmitData;
                end
            end

            TransmitData: begin
                Tx_DataValid <= 1'b1;
                Tx_Data <= decoded_byte_to_transmit;
                UART_Tx_FSM_state <= WaitTransmit;
            end

            WaitTransmit: begin
                Tx_DataValid <= 1'b0;
                if(Tx_Done) begin
                    UART_Tx_FSM_state <= INIT;
                end
            end
        endcase
    end
    

    /*
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
    */

    // Include the SCL decoder.
    SCList_Decoder #(.LLR_WIDTH(LLR_WIDTH), .n(n), .l(l), .K(M), .FROZEN_BITS(16'b0000000101111111)) 
                                                                            scl_decoder(.clk(clk), .reset(manual_reset), 
                                                                            .input_ready(input_ready), .output_ready(output_ready), 
                                                                            .decoded_bits(decoded_bits), .LLR(LLR_recv_bitstr));
    
endmodule
