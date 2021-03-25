`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:     Tsinghua University
// Engineer:    John Zhu
// 
// Create Date: 2021/02/19 17:18:12
// Design Name: CRC-PCC-SCLF decoder for concatenated polar codes.
// Module Name: PolarDecoder
// Project Name: 
// Target Devices: xc7a35tcsg324
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
module F
    #(parameter LLR_WIDTH = 5)
    (
        input wire [LLR_WIDTH-1:0] LLR_1, 
        input wire [LLR_WIDTH-1:0] LLR_2, 
        output wire [LLR_WIDTH-1:0] LLR_pred_U1
    );
    wire output_sign;
    wire [LLR_WIDTH-1:0] abs_LLR_1;
    wire [LLR_WIDTH-1:0] abs_LLR_2;
    
    localparam MSB = LLR_WIDTH - 1;
    assign output_sign = LLR_1[MSB] ^ LLR_2[MSB];
    assign abs_LLR_1 = (LLR_1[MSB]) ? ((~LLR_1) + 1) : LLR_1;
    assign abs_LLR_2 = (LLR_2[MSB]) ? ((~LLR_2) + 1) : LLR_2;
      
    wire [MSB:0] abs_LLR_pred;
    assign abs_LLR_pred = ((abs_LLR_1 < abs_LLR_2) ? abs_LLR_1 : abs_LLR_2);
    assign LLR_pred_U1 = (output_sign) ? ((~abs_LLR_pred) + 1) : abs_LLR_pred;
endmodule

module G
    #(parameter LLR_WIDTH = 5, parameter USE_SATURATION = 0)
    (
        input wire [LLR_WIDTH-1:0] LLR_1, 
        input wire [LLR_WIDTH-1:0] LLR_2,
        input wire U1,
        output wire [LLR_WIDTH-1:0] LLR_pred_U2
    );
    wire [LLR_WIDTH-1:0] LLR_pred_U2_temp;
    wire [LLR_WIDTH-1:0] sum;
    wire [LLR_WIDTH-1:0] diff;

    assign sum = LLR_1 + LLR_2;
    assign diff = LLR_2 - LLR_1;

    if(USE_SATURATION) begin
        assign LLR_pred_U2_temp = (U1) ? (diff) : (sum);
        
        wire OVF_up_add, OVF_down_add;
        wire OVF_up_sub, OVF_down_sub;

        assign OVF_up_add = !LLR_1[LLR_WIDTH-1] && !LLR_2[LLR_WIDTH-1] && sum[LLR_WIDTH-1];
        assign OVF_down_add = LLR_1[LLR_WIDTH-1] && LLR_2[LLR_WIDTH-1] && !sum[LLR_WIDTH-1];

        assign OVF_up_sub = LLR_1[LLR_WIDTH-1] && !LLR_2[LLR_WIDTH-1] && sum[LLR_WIDTH-1];
        assign OVF_down_sub = !LLR_1[LLR_WIDTH-1] && LLR_2[LLR_WIDTH-1] && !sum[LLR_WIDTH-1];

        assign LLR_pred_U2 = (OVF_up_add || OVF_up_sub) ? {1'b0, {(LLR_WIDTH-1){1'b1}}} :
                            (OVF_down_add || OVF_down_sub) ? {1'b1, {(LLR_WIDTH-1){1'b0}}}:
                            LLR_pred_U2_temp;
    end else begin
        assign LLR_pred_U2 = (U1) ? diff : sum;
    end
endmodule

module PolarDecoder
    #(parameter LLR_WIDTH = 8, parameter n = 3)
    (
    input wire clk,
    input wire reset,
    input wire input_ready,
    input wire [LLR_WIDTH-1:0] LLR,
    
    output reg output_ready,
    output reg [3:0] decoded_bits
    );
    
    localparam N = 2**n;
    
    reg [LLR_WIDTH-1:0] P[N-2:0];
    reg [N-2:0] CL;
    reg [N-2:0] CR;
    
    reg [n-1:0] P_wr_en;
    reg [n-1:0] P_wr_from_F;
    
    reg [n-1:0] CL_wr_en;
    reg [n-1:0] CR_wr_en;
    
    genvar i;
    genvar j;
    
    wire [LLR_WIDTH-1:0] P_next_F[N-2:0];
    wire [LLR_WIDTH-1:0] P_next_G[N-2:0];
    
    generate
        for(i=0;i<n-1;i=i+1) begin: FG
            localparam t1 = 2**(i+1)-1;     // 1
            localparam t2 = t1 + (2**i);    // 1+1
            localparam t_out = 2**i - 1;    // 0
            localparam t_out_len = 2**i;    // of length 1
            
            // Connect F modules onto P array.
            for(j=0;j<t_out_len;j=j+1)  begin: FG_inner
                F #(.LLR_WIDTH(LLR_WIDTH)) f_inst(.LLR_1(P[t1+j]), .LLR_2(P[t2+j]), .LLR_pred_U1(P_next_F[t_out+j]));
                G #(.LLR_WIDTH(LLR_WIDTH)) g_inst(.LLR_1(P[t1+j]), .LLR_2(P[t2+j]), .U1(CL[t_out+j]), .LLR_pred_U2(P_next_G[t_out+j]));
            end
        end
    endgenerate
    
    generate
        for(i=0;i<n;i=i+1) begin: P_update_logic
            localparam t_out = 2**i - 1;
            localparam t_out_len = 2**i;
            
            for(j=0;j<t_out_len;j=j+1) begin: P_update_logic_inner
                always@(posedge clk) begin
                    if(reset) begin
                        P[t_out+j] <= 0;
                    end
                    else begin
                        if(P_wr_en[i]) P[t_out+j] <= (P_wr_from_F[i])?P_next_F[t_out+j]:P_next_G[t_out+j];
                    end
                end
            end
        end
    endgenerate
    
    // C-array working logic: CL and CR.
    generate
        for(i=0;i<n-1;i=i+1) begin: C_update_logic
            localparam t1 = 2**(i+1)-1;     // 1
            localparam t2 = t1 + (2**i);    // 1+1=2
            localparam t_out = 2**i - 1;    // [0]
            localparam t_out_len = 2**i;    // len = 1.
            
            for(j=0;j<t_out_len;j=j+1) begin: C_update_logic_inner
                always@(posedge clk) begin
                    if(reset) begin
                        CL[t1+j] <= 0;
                        CR[t1+j] <= 0;
                        CL[t2+j] <= 0;
                        CR[t2+j] <= 0;
                    end 
                    else begin
                        if(CR_wr_en[i+1]) begin
                            CR[t1+j] <= CR[t_out+j] ^ CL[t_out+j];  // Partial-sum return.
                            CR[t2+j] <= CR[t_out+j];
                        end
                        if(CL_wr_en[i+1]) begin
                            CL[t1+j] <= CR[t_out+j] ^ CL[t_out+j];  // Partial-sum return.
                            CL[t2+j] <= CR[t_out+j];
                        end
                    end
                end
            end
        end
    endgenerate
    
    // FSM control logic: controlling the decoding process.
    reg [n-1:0] phi = 0;    // within range [0, 2^n - 1].
    reg [3:0] state = 0;    
    
    localparam INIT         = 4'h0;
    localparam READ_DATA    = 4'h1;
    localparam CH_F_EXEC    = 4'h2;
    localparam LEFT         = 4'h3;
    localparam RIGHT        = 4'h4;
    localparam DECIDE       = 4'h5;
    localparam LLR_LAYERS   = 4'h6;
    localparam COMPLETE     = 4'h7;
    
    reg [n-1:0] counter = 0;
    reg [n-1:0] llr_layer = 0;
    reg [n-1:0] psr_onehot = 0;
    reg [LLR_WIDTH-1:0] input_LLRs[N-1:0];
    
    // Generator block for f functions and g functions applied on channel input LLRs.
    generate
        localparam t_out = 2**(n-1) - 1;    // 3
        localparam t_out_len = 2**(n-1);    // 4
        for(j=0;j<t_out_len;j=j+1) begin: CH_F
            F #(.LLR_WIDTH(LLR_WIDTH)) ch_f_inst(.LLR_1(input_LLRs[j]), .LLR_2(input_LLRs[j+t_out_len]), .LLR_pred_U1(P_next_F[t_out+j]));
            G #(.LLR_WIDTH(LLR_WIDTH)) ch_g_inst(.LLR_1(input_LLRs[j]), .LLR_2(input_LLRs[j+t_out_len]), .U1(CL[t_out+j]), .LLR_pred_U2(P_next_G[t_out+j]));
        end
    endgenerate
    
    
    reg [N-1:0] frozen_bits;    // Register of length N, indicating which bits are forced to zero.
    reg t;                      
    integer k;
    
    always@(posedge clk) begin
        if(reset) begin
            phi <= 0;
            state <= INIT;
            counter <= 0;
            
            P_wr_en <= 0;
            P_wr_from_F <= 0;
            
            frozen_bits <= 8'b00010111; // A = { 4, 6, 7, 8 }.
            decoded_bits <= 0;
        end
        else begin
            // Main FSM logic.
            case(state)
                INIT: begin
                    if(input_ready) begin
                        output_ready <= 0;
                        state <= READ_DATA;
                        counter <= 0;
                    end
                end
                
                READ_DATA: begin
                    input_LLRs[counter] <= LLR;
                    counter <= counter + 1;
                    if(counter == (N-1)) state <= CH_F_EXEC;
                end
                
                CH_F_EXEC: begin
                    P_wr_en[n-1] <= 1'b1;
                    P_wr_from_F[n-1] <= 1'b1;   // Enable the first 4 F-function executions.
                    phi <= 0;
                    state <= LEFT;
                end
                
                LEFT: begin
                    P_wr_en <= P_wr_en >> 1;
                    P_wr_from_F <= P_wr_en >> 1;
                    
                    if(P_wr_en[0]) begin
                        state <= DECIDE;
                    end
                end
                
                // DECIDE state: perform hard decision given the calculated LLR stored in P[0].
                DECIDE: begin
                    if(frozen_bits[phi]) begin
                        if(!phi[0]) begin
                            CL[0] = 1'b0;
                        end else begin
                            CR[0] = 1'b0;
                        end
                    end
                    else begin
                        if(!phi[0]) begin
                            CL[0] = (P[0][LLR_WIDTH-1]);    // if LLR>0, then CL[0] <= 1.
                            decoded_bits = decoded_bits >> 1;
                            decoded_bits[3] = CL[0];
                        end else begin
                            CR[0] = (P[0][LLR_WIDTH-1]);
                            decoded_bits = decoded_bits >> 1;
                            decoded_bits[3] = CR[0];
                        end
                    end
                    
                    // Decision complete. Then setup partial-sum return logic.
                    if(phi == N-1) begin
                        state <= COMPLETE;
                    end else if(phi[0]) begin
                        psr_onehot <= 2;    // initialize the switch as [0 1 0 0 ... ], enabling CL[1] or CR[1] to be accessed.
                        state <= RIGHT;
                    end else begin
                        phi <= phi + 1;
                        state <= LLR_LAYERS;
                    end
                    
                end
                
                RIGHT: begin
                    if((psr_onehot & phi) == 0) begin
                        // Give value to the left column.
                        CL_wr_en    <= psr_onehot;
                        CR_wr_en    <= 0;
                        state       <= LLR_LAYERS;
                        phi         <= phi + 1;  
                    end
                    else begin
                        // Give value to the right column.
                        CR_wr_en <= psr_onehot;
                        CL_wr_en <= 0;
                    end
                    psr_onehot <= psr_onehot << 1;
                end
                
                LLR_LAYERS: begin
                    CL_wr_en <= 0;
                    CR_wr_en <= 0;  // Stop partial-sum return.
                    
                    // Start preparing to decode the next bit.
                    // Calculate llr_layer_vec[phi].
                    t = 0;
                    llr_layer = 0;
                    for(k=0;k<n;k=k+1) begin
                        if(t==0) begin
                            if(!phi[k]) begin
                                llr_layer = llr_layer + 1;
                            end else t = 1;
                        end
                    end
                    
                    if(phi == N/2) begin
                        // Execute G functions on channel LLRs.
                        P_wr_en[n-1] <= 1'b1;
                        P_wr_from_F[n-1] <= 1'b0;   // Enable G-input.
                    end else begin
                        // Execute G functions based on previous partial-sum return.
                        P_wr_en[llr_layer] <= 1'b1;
                        P_wr_from_F[llr_layer] <= 1'b0;
                    end
                    
                    state <= LEFT;
                end
                
                COMPLETE: begin
                    output_ready <= 1;
                    state <= INIT;
                end
                
                default: begin
                    state <= INIT;
                end
            endcase
        end
    end
    
    
    
endmodule
