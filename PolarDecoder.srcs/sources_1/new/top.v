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
    output wire [7:0] decoded_bits_disp,
    input wire Rx_Serial,
    output wire Tx_Serial,

    input wire [2:0] SW,
    output wire [7:0] D
    );
    
    wire manual_reset;
    debounce deb(clk, reset, manual_reset);

    reg input_ready; wire output_ready;
    
    parameter n = 5;
    localparam N = 2**n;
    parameter M = 16;
    parameter K_CRC = 4;
    localparam K = M + K_CRC;       // Total cnt. of non-frozen bits.

    parameter l = 3;
    parameter ADDITIONAL_WIDTH = 3;
    localparam LLR_WIDTH = 8 + ADDITIONAL_WIDTH;

    reg [LLR_WIDTH-1:0] LLR_RECV [N-1:0];
    wire [K-1:0] decoded_bits;
    assign decoded_bits_disp = decoded_bits[7:0];

    wire [N*LLR_WIDTH-1:0] LLR_recv_bitstr;
    integer k;
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
                        LLR_RECV[UART_RecvCnt] <= {{ADDITIONAL_WIDTH{Rx_Data[7]}}, Rx_Data};    // Sign-extension.
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
    reg [M-1:0] decoded_bits_to_transmit;
    localparam M_bytes = M/8;

    reg [4:0] TransmitCnt;

    // Transmit FSM.
    localparam TransmitData     = 4'h1;
    localparam WaitTransmit     = 4'h2;

    always@(posedge clk or posedge manual_reset) begin
        if(manual_reset) begin
            UART_Tx_FSM_state <= 0;
        end else case(UART_Tx_FSM_state)
            INIT: begin
                TransmitCnt = 0;
                if(output_ready) begin
                    decoded_bits_to_transmit <= decoded_bits[M-1:0];       // Save data to be transmitted.
                    UART_Tx_FSM_state <= TransmitData;
                end
            end

            TransmitData: begin
                Tx_DataValid <= 1'b1;
                Tx_Data = decoded_bits_to_transmit[7:0];
                decoded_bits_to_transmit = decoded_bits_to_transmit >> 8;
                UART_Tx_FSM_state <= WaitTransmit;
            end

            WaitTransmit: begin
                Tx_DataValid <= 1'b0;
                if(Tx_Done) begin
                    TransmitCnt = TransmitCnt + 1;
                    if(TransmitCnt == M_bytes)
                        UART_Tx_FSM_state <= INIT;
                    else
                        UART_Tx_FSM_state <= TransmitData;
                end
            end
        endcase
    end

    // Include the SCL decoder.
    SCList_Decoder #(.LLR_WIDTH(LLR_WIDTH), .n(n), .l(l), .K(K), .FROZEN_BITS(32'b00000000000000110000011101111111)) 
                                                                            scl_decoder(.clk(clk), .reset(manual_reset), 
                                                                            .input_ready(input_ready), .output_ready(output_ready), 
                                                                            .decoded_bits(decoded_bits), .LLR(LLR_recv_bitstr));
endmodule
