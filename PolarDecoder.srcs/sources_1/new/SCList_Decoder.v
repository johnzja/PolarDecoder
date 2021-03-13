`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:     Tsinghua University
// Engineer:    John Zhu
// 
// Create Date: 2021/03/13 15:37:13
// Design Name: 
// Module Name: SCList_Decoder
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


module SCList_Decoder
    #(parameter LLR_WIDTH = 8, parameter n = 3, parameter l = 3, parameter K = 4)
    (
    input wire clk,
    input wire reset,
    input wire input_ready,
    input wire [LLR_WIDTH-1:0] LLR,
    
    output reg output_ready,
    output reg [3:0] decoded_bits
    );
    
    
    localparam N = 2**n;
    localparam L = 2**l;
    
    reg [LLR_WIDTH-1:0] P [L-1:0][N-2:0];
    reg [N-2:0] CL [L-1:0];
    reg [N-2:0] CR [L-1:0];
    wire [N-2:0] CL_next_Bus;   // CL_next_Bus[0] is unused.
    
    reg [n-1:0] P_wr_en;
    reg [n-1:0] P_wr_from_F;
    
    reg [n-1:0] CL_wr_en;
    reg [n-1:0] CR_wr_en;
    
    genvar i;
    genvar j;
    genvar list;
    
    wire [LLR_WIDTH-1:0] P_next_F [L-1:0][N-2:0];
    wire [LLR_WIDTH-1:0] P_next_G [L-1:0][N-2:0];
    wire [LLR_WIDTH-1:0] P_next_Bus [N-2:0];
    reg [L-1:0] Copy_EN;            // Copy from P_next_Copy, CL_next_Copy and CR_next_Copy iff Cply_EN[list] = 1.
    
    generate
        for(list=0;list<L;list=list+1) begin:FG_List
            for(i=0;i<n-1;i=i+1) begin: FG
                localparam t1 = 2**(i+1)-1;     // 1
                localparam t2 = t1 + (2**i);    // 1+1
                localparam t_out = 2**i - 1;    // 0
                localparam t_out_len = 2**i;    // of length 1
                
                // Connect F modules onto P array.
                for(j=0;j<t_out_len;j=j+1)  begin: FG_inner
                    F #(.LLR_WIDTH(LLR_WIDTH)) f_inst(.LLR_1(P[list][t1+j]), .LLR_2(P[list][t2+j]), .LLR_pred_U1(P_next_F[list][t_out+j]));
                    G #(.LLR_WIDTH(LLR_WIDTH)) g_inst(.LLR_1(P[list][t1+j]), .LLR_2(P[list][t2+j]), .U1(CL[list][t_out+j]), .LLR_pred_U2(P_next_G[list][t_out+j]));
                end
            end
        end
    endgenerate
    
    generate
        for(list=0;list<L;list=list+1) begin: update_List
            for(i=0;i<n;i=i+1) begin: P_update_logic
                localparam t_out = 2**i - 1;
                localparam t_out_len = 2**i;
                
                for(j=0;j<t_out_len;j=j+1) begin: P_update_logic_inner
                    always@(posedge clk) begin
                        if(reset) begin
                            P[list][t_out+j] <= 0;     
                        end
                        else begin
                            if(Copy_EN[list]) P[list][t_out+j] <= P_next_Bus[t_out+j];
                            else if(P_wr_en[i]) P[list][t_out+j] <= (P_wr_from_F[i])?P_next_F[list][t_out+j]:P_next_G[list][t_out+j];
                        end
                    end
                end
            end
        end
    endgenerate
    
    // C-array working logic: CL and CR.
    // SCList decoding: Just copy CL is enough.
    generate
        for(list=0;list<L;list=list+1) begin:C_update_list
            for(i=0;i<n-1;i=i+1) begin: C_update_logic
                localparam t1 = 2**(i+1)-1;     // 1
                localparam t2 = t1 + (2**i);    // 1+1=2
                localparam t_out = 2**i - 1;    // [0]
                localparam t_out_len = 2**i;    // len = 1.
                
                for(j=0;j<t_out_len;j=j+1) begin: C_update_logic_inner
                    always@(posedge clk) begin
                        if(reset) begin
                            CL[list][t1+j] <= 0;
                            CR[list][t1+j] <= 0;
                            CL[list][t2+j] <= 0;
                            CR[list][t2+j] <= 0;
                        end 
                        else begin
                            if(CR_wr_en[i+1]) begin
                                CR[list][t1+j] <= CR[list][t_out+j] ^ CL[list][t_out+j];  // Partial-sum return.
                                CR[list][t2+j] <= CR[list][t_out+j];
                            end
                            
                            // Update CL.
                            if(Copy_EN[list]) begin
                                CL[list][t1+j] <= CL_next_Bus[t1+j];
                                CL[list][t2+j] <= CL_next_Bus[t2+j];
                            end
                            else if(CL_wr_en[i+1]) begin
                                CL[list][t1+j] <= CR[list][t_out+j] ^ CL[list][t_out+j];  // Partial-sum return.
                                CL[list][t2+j] <= CR[list][t_out+j];
                            end
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
    localparam PREP_SORT    = 4'h8;
    localparam WAIT_SORT    = 4'h9;
    localparam COPY_PATH    = 4'hA;
    
    reg [n-1:0] counter = 0;
    reg [n-1:0] llr_layer = 0;
    reg [n-1:0] psr_onehot = 0;
    reg [LLR_WIDTH-1:0] input_LLRs[N-1:0];
    
    // Generator block for f functions and g functions applied on channel input LLRs.
    generate
    for(list=0;list<L;list=list+1) begin: CH_List
        localparam t_out = 2**(n-1) - 1;    // 3
        localparam t_out_len = 2**(n-1);    // 4
        for(j=0;j<t_out_len;j=j+1) begin: CH_F
            F #(.LLR_WIDTH(LLR_WIDTH)) ch_f_inst(.LLR_1(input_LLRs[j]), .LLR_2(input_LLRs[j+t_out_len]), .LLR_pred_U1(P_next_F[list][t_out+j]));
            G #(.LLR_WIDTH(LLR_WIDTH)) ch_g_inst(.LLR_1(input_LLRs[j]), .LLR_2(input_LLRs[j+t_out_len]), .U1(CL[list][t_out+j]), .LLR_pred_U2(P_next_G[list][t_out+j]));
        end
    end
    endgenerate
    
    
    reg [N-1:0] frozen_bits;    // Register of length N, indicating which bits are forced to zero.
    reg t;                      
    integer k;
    
    localparam PM_WIDTH = LLR_WIDTH+n;
    reg [PM_WIDTH-1:0] PM[L-1:0];            // Path measures.
    reg [PM_WIDTH-1:0] PM_split_0[L-1:0];    // Splitted path measures, MSB indicating the bit choice.
    reg [PM_WIDTH-1:0] PM_split_1[L-1:0];    // Splitted path measures, MSB indicating the bit choice.
    
    reg [K-1:0] u [L-1:0];
    wire [K-1:0] u_next_Bus;
    reg [l-1:0] list_iter;
    
    // Using the bitonic sorting network.
    reg sort_start = 0;
    wire sort_complete;
    
    // Setup x_input, l_input, x_output and l_output.
    wire [PM_WIDTH*(2*L)-1:0] x_input;
    wire [(l+1)*(2*L)-1:0] l_input;
    wire [PM_WIDTH*(2*L)-1:0] x_output;
    wire [(l+1)*(2*L)-1:0] l_output;
    
    wire [PM_WIDTH-1:0] PM_split_sorted[2*L-1:0];
    wire [l:0] PM_split_sorted_label[2*L-1:0];
    
    generate 
        for(i=0;i<L;i=i+1) begin: connnect_sort_x_0
            assign x_input[(i+1)*PM_WIDTH-1:i*PM_WIDTH] = PM_split_0[i];
            assign l_input[(i+1)*(l+1)-1:i*(l+1)] = {1'b0, i[l-1:0]};
            
        end
        
        for(i=L;i<(2*L);i=i+1) begin: connect_sort_x_1
            assign x_input[(i+1)*PM_WIDTH-1:i*PM_WIDTH] = PM_split_1[i];
            assign l_input[(i+1)*(l+1)-1:i*(l+1)] = {1'b1, i[l-1:0]};
        end
        
        for(i=0;i<(2*L);i=i+1) begin: connect_sort_y
            assign PM_split_sorted[i] = x_output[(i+1)*PM_WIDTH-1:i*PM_WIDTH];
            assign PM_split_sorted_label[i] = l_output[(i+1)*(l+1)-1:i*(l+1)];
        end
    endgenerate
    
    bitonic_sorting_top #(.LOG_INPUT_NUM(l+1), .DATA_WIDTH(PM_WIDTH), .LABEL_WIDTH(l+1), .SIGNED(0), .ASCENDING(0)) 
        bs_inst(.clk(clk), .rst(reset), .x_valid(sort_start), 
    .x(x_input), .x_label(l_input), .y(x_output), .y_label(l_output), .y_valid(sort_complete)); 
    
    always@(posedge clk) begin
        if(reset) begin
            phi <= 0;
            state <= INIT;
            counter <= 0;
            
            P_wr_en <= 0;
            P_wr_from_F <= 0;
            Copy_EN <= 0;
            
            sort_start <= 0;
            
            frozen_bits <= 8'b00010111;     // A = { 4, 6, 7, 8 }.
            
            decoded_bits <= 0;
            for(k=0;k<K;k=k+1) u[k] <= 0;   // Initialize u-paths to be zero.
            for(k=0;k<L;k=k+1) PM[k] <= 0;
        end
        else begin
            // Main FSM logic starts here.
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
                        state <= PREP_SORT;
                    end
                end
                
                // PREP_SORT state: Perform path-splitting.
                PREP_SORT: begin
                    if(frozen_bits[phi]) begin
                        if(!phi[0]) begin
                            for(k=0;k<L;k=k+1) CL[k][0] = 1'b0;
                        end else begin
                            for(k=0;k<L;k=k+1) CR[k][0] = 1'b0;
                        end
                        state <= DECIDE;
                    end
                    else begin
                        // perform path-splitting.
                        /*
                        if(!phi[0]) begin
                            CL[0] = (P[0][LLR_WIDTH-1]);    // if LLR>0, then CL[0] <= 1.
                            decoded_bits = decoded_bits >> 1;
                            decoded_bits[3] = CL[0];
                        end else begin
                            CR[0] = (P[0][LLR_WIDTH-1]);
                            decoded_bits = decoded_bits >> 1;
                            decoded_bits[3] = CR[0];
                        end
                        */
                        
                        // Setup PM_split_0 and PM_split_1 in parallel.
                        for(list_iter=0;list_iter<L;list_iter=list_iter+1) begin
                            if(P[list_iter][0][LLR_WIDTH-1]) begin
                                // negative sign.
                                PM_split_0[list_iter] <= PM[list_iter] + ((~P[list_iter][0])+1);
                                PM_split_1[list_iter] <= PM[list_iter];
                            end else begin
                                // positive sign.
                                PM_split_1[list_iter] <= PM[list_iter] + P[list_iter][0];
                                PM_split_0[list_iter] <= PM[list_iter];
                            end
                        end
                        
                        // Enable the bitonic sorting network.
                        sort_start <= 1'b1;
                        state <= WAIT_SORT;
                    end


                end
                
                WAIT_SORT: begin
                    sort_start <= 1'b0;
                    if(sort_complete) begin
                        // TODO: Find out the survivor paths and extend them at CL or CR.
                        // TODO: Copy paths if necessary.
                    end
                end
                
                
                DECIDE: begin
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