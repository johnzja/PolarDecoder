`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company:     Tsinghua University
// Engineer:    John Zhu
// 
// Create Date: 2021/03/13 15:37:13
// Design Name: 
// Module Name: CA_PC_SCList_Decoder
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

module CA_PC_SCList_Decoder
    #(  parameter LLR_WIDTH = 8, parameter n = 5, parameter l = 3, parameter K = 22, parameter FROZEN_BITS=8'b00010111,
        parameter CRC_poly = 4'b0011, parameter N_CRC = 4
    )
    (
    input wire clk,
    input wire reset,
    input wire input_ready,
    input wire [((2**n)*(LLR_WIDTH))-1:0] LLR,
    
    output reg output_ready,
    output reg [K-1:0] decoded_bits
    );
    
    
    localparam N = 2**n;
    localparam L = 2**l;

    /*----------------Configure Parity-Check------------------*/
    localparam CntPCEqns = 2;

    localparam integer eqn1 [0:2] = {0, 2, 5};
    localparam integer eqn2 [0:2] = {1, 6, 10};

    localparam integer eqn_checkbits [0:1] = {eqn1[2], eqn2[2]};
    
    localparam integer eqn_xor_vecs [0:1] = {22'b00_0000_0000_0000_0000_0101, 22'b00_0000_0000_0000_0100_0010};

    /*------------------Configure SCFlip----------------------*/
    // Hard-wire the Critical Set into FPGA itself.
    localparam integer flippables [0:5] = {7, 10, 12, 17, 18, 24};
    localparam integer N_CS = 6;

    /*------------End of Parity-Check configuration-----------*/
    
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
    reg [L-1:0] Copy_EN;                        // Copy from P_next_Copy, CL_next_Copy and CR_next_Copy iff Cply_EN[list] = 1.
    
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
                        if(Copy_EN[list]) P[list][t_out+j] <= P_next_Bus[t_out+j];
                        else if(P_wr_en[i]) P[list][t_out+j] <= (P_wr_from_F[i])?P_next_F[list][t_out+j]:P_next_G[list][t_out+j];
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

            // Update CL[0] is included in the FSM logic, not HERE.
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
    localparam IDENT_PATH   = 4'hB;
    localparam WAIT_FIND    = 4'hC;
    localparam CHECK_CRC    = 4'hD;
    localparam RESTART      = 4'hE;
    
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
    reg [L-1:0] active_path;
    reg [l+1:0]   N_active_path;

    reg [K-1:0] u [L-1:0];
    reg [N_CRC-1:0] CRC_u[L-1:0];           // CRC bits of u. Calculated whenever one info bit is decoded.

    wire [K-1:0] u_next_Bus;

    reg [l:0] list_iter;                    // This iteration pointer is only used in 'for' loops.
    reg [l:0] list_iter_fsm;                // This iteration pointer is used in FSM loops.
    
    // Using the bitonic sorting network.
    reg sort_start = 0;
    wire sort_complete;

    // Using the find_min module.
    reg find_min_start = 0;
    wire find_min_complete;
    wire [l-1:0] ptr_min_PM;
    
    // Setup x_input, l_input, x_output and l_output.
    wire [PM_WIDTH*(2*L)-1:0] x_input;
    wire [(l+1)*(2*L)-1:0] l_input;
    wire [PM_WIDTH*(2*L)-1:0] x_output;
    wire [(l+1)*(2*L)-1:0] l_output;
    
    wire [PM_WIDTH-1:0] PM_split_sorted[2*L-1:0];
    wire [l:0] PM_split_sorted_label[2*L-1:0];   

    reg [L-1:0] Flag_SC_state;
    reg [L-1:0] Flag_Killed_state;  
    reg [L-1:0] Flag_Killed_state_dual;
    reg [L-1:0] Flag_Path_decision;

    reg [L-1:0] temp;
    reg [L-1:0] temp_dual;
    reg [l:0] N_Copy_state;                 // #. Paths in copy state.
    reg [l:0] N_Killed_state;               // #. Paths in killed state.
    reg [l-1:0] ptr_Copy_state [L-1:0];     // Path index for each path in copy state.
    reg [l-1:0] ptr_Killed_state [L-1:0];   // Path index for each path in killed state.
    reg [L-1:0] just_copied;                // Bit indicators. 1'b1 means this path is a new path which had just inherited data from another path.
    
    generate 
        for(i=0;i<L;i=i+1) begin: connnect_sort_x_0
            assign x_input[(i+1)*PM_WIDTH-1:i*PM_WIDTH] = PM_split_0[i];
            assign l_input[(i+1)*(l+1)-1:i*(l+1)] = {1'b0, i[l-1:0]};       // Fixed label inputs.
            
        end
        
        for(i=L;i<(2*L);i=i+1) begin: connect_sort_x_1
            assign x_input[(i+1)*PM_WIDTH-1:i*PM_WIDTH] = PM_split_1[i-L];
            assign l_input[(i+1)*(l+1)-1:i*(l+1)] = {1'b1, i[l-1:0]};
        end
        
        for(i=0;i<(2*L);i=i+1) begin: connect_sort_y
            assign PM_split_sorted[i] = x_output[(i+1)*PM_WIDTH-1:i*PM_WIDTH];
            assign PM_split_sorted_label[i] = l_output[(i+1)*(l+1)-1:i*(l+1)];
        end
    endgenerate
    
    bitonic_sorting_top #(.LOG_INPUT_NUM(l+1), .DATA_WIDTH(PM_WIDTH), .LABEL_WIDTH(l+1), .SIGNED(0), .ASCENDING(1)) 
        bs_inst(.clk(clk), .rst(reset), .x_valid(sort_start), 
    .x(x_input), .x_label(l_input), .y(x_output), .y_label(l_output), .y_valid(sort_complete)); 
    

    // CL_next_Bus and P_next_Bus: Assignments.
    reg [l-1:0] reg_copy_selector;
    reg [n-1:0] u_iter;
    assign CL_next_Bus = CL[reg_copy_selector];
    assign u_next_Bus = u[reg_copy_selector];
    
    generate
        for(i=0;i<N-1;i=i+1) begin: P_selector
            assign P_next_Bus[i] = P[reg_copy_selector][i];
        end
    endgenerate
    
    // input LLR assignments.
    wire [LLR_WIDTH-1:0] input_LLRs_formatted[N-1:0];
    generate
        for(i=0;i<N;i=i+1) begin: format_input_LLRs
            assign input_LLRs_formatted[i] = LLR[(i+1)*LLR_WIDTH-1 : i*LLR_WIDTH];
        end
    endgenerate

    wire [PM_WIDTH*L-1:0] fm_input_data;
    wire [l*L-1:0] fm_input_labels;
    wire [PM_WIDTH*L-1:0] fm_output_data;
    wire [l*L-1:0] fm_output_labels;
    wire [l-1:0] ptr_fm_output_labels[L-1:0];

    // Parity-Check and SCLFlip decoding.
    reg is_PCC_bit;
    reg bit_flip;
    reg [n-1:0] index_bit_to_flip;
    reg [n-1:0] index_CS;

    // Main FSM starts here.
    always@(posedge clk or posedge reset) begin
        if(reset) begin
            state <= INIT;
            decoded_bits <= 0;
            for(k=0;k<L;k=k+1) u[k] <= 0;           // Initialize u-paths to be zero.
        end
        else begin
            case(state)
                INIT: begin
                    output_ready <= 0;
                    phi <= 0;

                    P_wr_en <= 0;
                    P_wr_from_F <= 0;
                    Copy_EN <= 0;

                    sort_start <= 0;
                    find_min_start <= 0;

                    frozen_bits <= FROZEN_BITS;

                    active_path <= 1;               // Enable only one path at the beginning.
                    N_active_path <= 1;             // At the beginning: There are only 1 active path.
                    u_iter <= 0;      
                    is_PCC_bit <= 0;    
                    bit_flip <= 0;
                    index_bit_to_flip <= 0;          
                    index_CS <= 0;

                    for(k=0;k<L;k=k+1) begin
                        PM[k] <= 0;
                        CRC_u[k] <= 0;
                    end

                    if(input_ready) begin
                        state <= READ_DATA;
                        counter <= 0;
                    end
                end
                
                READ_DATA: begin
                    for(k=0;k<N;k=k+1) input_LLRs[k] <= input_LLRs_formatted[k];
                    state <= CH_F_EXEC;
                end
                
                CH_F_EXEC: begin
                    P_wr_en[n-1] <= 1'b1;
                    P_wr_from_F[n-1] <= 1'b1;   // Enable the first 4 F-function executions.
                    phi <= 0;
                    state <= LEFT;
                end
                
                // Left-propagation.
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
                        state <= DECIDE;
                        Flag_Path_decision <= 0;
                        is_PCC_bit <= 0;
                    end else begin
                        // Check if this bit is in the parity-check set. Then it is a dynamically-frozen bit!
                        if(u_iter == eqn_checkbits[0]) begin
                            // the 1st checking equation.
                            for(k=0;k<L;k=k+1) begin
                                Flag_Path_decision[k] <= ^(eqn_xor_vecs[0] & u[k]);
                            end
                            state <= DECIDE;
                            is_PCC_bit <= 1;
                        end else if (u_iter == eqn_checkbits[1]) begin
                            // the 2nd checking equation.
                            for(k=0;k<L;k=k+1) begin
                                Flag_Path_decision[k] <= ^(eqn_xor_vecs[1] & u[k]);
                            end
                            state <= DECIDE;
                            is_PCC_bit <= 1;
                        end else begin
                            // Enable the bitonic sorting network.
                            is_PCC_bit <= 0;
                            Flag_Path_decision <= 0;
                            sort_start <= 1'b1;
                            N_active_path = N_active_path << 1;        
                            if(N_active_path > L) N_active_path = L;
                            state <= WAIT_SORT; 
                        end
                    end
                    
                    // Setup PM_split_0 and PM_split_1 in parallel, within 1 clock cycle.
                    for(list_iter=0;list_iter<L;list_iter=list_iter+1) begin
                        if(active_path[list_iter]) begin
                            if(P[list_iter][0][LLR_WIDTH-1]) begin
                                // negative sign.
                                PM_split_0[list_iter] <= PM[list_iter] + {{n {1'b0}}, -P[list_iter][0]};
                                PM_split_1[list_iter] <= PM[list_iter];
                            end else begin
                                // positive sign.
                                PM_split_1[list_iter] <= PM[list_iter] + {{n {1'b0}}, P[list_iter][0]};
                                PM_split_0[list_iter] <= PM[list_iter];
                            end
                        end else begin
                            PM_split_0[list_iter] <= -1;    // All-one path metric (MAX), infinity.
                            PM_split_1[list_iter] <= -1;    // All-one path metric (MAX), infinity.
                        end
                    end
                    
                    just_copied <= 0;
                end
                
                WAIT_SORT: begin
                    sort_start <= 1'b0;
                    if(sort_complete) begin
                        state <= IDENT_PATH;
                        list_iter_fsm <= 0;
                        Flag_SC_state <= 0;
                        Flag_Killed_state <= -1;        // All 1's.
                        Flag_Killed_state_dual <= 0;    //

                        N_Copy_state <= 0;          
                        N_Killed_state <= 0;

                    end else begin
                        state <= WAIT_SORT;
                        active_path <= 0;               // Clear active paths.
                    end
                end
                
                IDENT_PATH: begin
                    if(list_iter_fsm < N_active_path) begin              
                        // Identify the type of each candidate path whose Path Metric(PM) is among the smallest L paths.
                        temp = PM_split_sorted_label[list_iter_fsm][l-1:0];     // bit length: l, it is the path index.
                        active_path[temp] <= 1'b1;

                        if(Flag_Killed_state[temp]) begin
                            Flag_Killed_state[temp] <= 1'b0;
                            Flag_SC_state[temp]     <= 1'b1;
                            if((!bit_flip) || (index_bit_to_flip != phi)) begin
                                Flag_Path_decision[temp] <= PM_split_sorted_label[list_iter_fsm][l];    // if a path is in SC state, then the SC hard-decision bit should be saved.
                            end else begin
                                Flag_Path_decision[temp] <= !(PM_split_sorted_label[list_iter_fsm][l]);
                            end
                        end else if(Flag_SC_state[temp]) begin
                            Flag_SC_state[temp]     <= 1'b0;
                            ptr_Copy_state[N_Copy_state] <= temp;               // ptr_Copy_state[i] means the index of the i-th path which needs to be copied.

                            N_Copy_state = N_Copy_state + 1;
                            Flag_Path_decision[temp] <= 1'b0;                   // if a path is in copy state, then the original path should be extended by 1'b0.
                        end

                    end else begin
                        temp_dual = PM_split_sorted_label[list_iter_fsm][l-1:0];
                        if(!Flag_Killed_state_dual[temp_dual]) begin
                            Flag_Killed_state_dual[temp_dual] <= 1'b1;          // Indicate that this state has been killed once.
                        end else begin
                            N_Killed_state <= N_Killed_state + 1;               // HERE: this state has been killed twice.
                            ptr_Killed_state[N_Killed_state] <= temp_dual;
                        end
                    end

                    if(list_iter_fsm < 2*L-1)
                        list_iter_fsm <= list_iter_fsm + 1;
                    else begin
                        list_iter_fsm <= 0;
                        if(N_Copy_state != 0)
                            state <= COPY_PATH;
                        else
                            state <= DECIDE;
                        
                        reg_copy_selector <= 0;
                        just_copied <= 0;
                    end
                end

                COPY_PATH: begin
                    // Use the path identification information to decide how to copy paths, and then perform copying.

                    reg_copy_selector = ptr_Copy_state[list_iter_fsm];
                    temp = ptr_Killed_state[list_iter_fsm];

                    Copy_EN = 0;                        
                    Copy_EN[temp] = 1'b1;                       
                    CL[temp][0] <= CL[reg_copy_selector][0];        // Enable CL path[temp] to be written.

                    Flag_Path_decision[temp] = 1'b1;    
                    active_path[temp] <= 1'b1;
                    just_copied[temp] <= 1'b1;
                    PM[temp] <= PM_split_1[reg_copy_selector];      // Access reg PM here.

                    u[temp] <= u[reg_copy_selector];
                    CRC_u[temp] <= CRC_u[reg_copy_selector];
                    
                    list_iter_fsm = list_iter_fsm + 1;
                    if(list_iter_fsm == N_Copy_state) begin
                        state <= DECIDE;
                    end
                end
                
                DECIDE: begin
                    Copy_EN <= 0;
                    for(k=0;k<L;k=k+1) begin
                        if(active_path[k]) begin
                            if(!frozen_bits[phi]) begin
                                u[k][u_iter] = Flag_Path_decision[k];
                                // Perform CRC check.

                                if(!is_PCC_bit) begin
                                    if(CRC_u[k][N_CRC-1]) begin
                                        CRC_u[k] <= CRC_poly ^ {CRC_u[k][N_CRC-2:0], Flag_Path_decision[k]};
                                    end else begin
                                        CRC_u[k] <= {CRC_u[k][N_CRC-2:0], Flag_Path_decision[k]};
                                    end
                                end
                            end

                            if(!phi[0]) begin
                                CL[k][0] = Flag_Path_decision[k];
                            end else begin
                                CR[k][0] = Flag_Path_decision[k];
                            end
                            
                            // Update path measures.
                            if(!just_copied[k]) begin
                                if(Flag_Path_decision[k]) begin
                                    PM[k] <= PM_split_1[k];
                                end else begin
                                    PM[k] <= PM_split_0[k];
                                end
                            end
                        end
                    end
                    
                    if(!frozen_bits[phi])   u_iter <= u_iter + 1;

                    // Decision complete. Then setup partial-sum return logic.
                    if(phi == N-1) begin
                        state <= WAIT_FIND;
                        find_min_start <= 1'b1;
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

                CHECK_CRC: begin
                    if(CRC_u[ptr_fm_output_labels[list_iter_fsm]] == 0) begin
                        decoded_bits <= u[ptr_fm_output_labels[list_iter_fsm]];
                        state <= COMPLETE;
                    end else begin
                        list_iter_fsm = list_iter_fsm + 1;
                        if(list_iter_fsm == L) begin
                            // decoded_bits <= u[ptr_fm_output_labels[0]];
                            // Start flipping.
                            index_bit_to_flip <= flippables[index_CS];
                            index_CS = index_CS + 1;
                            if(index_CS == N_CS) begin
                                state <= COMPLETE;
                                decoded_bits <= 0;          // Declare decoding failure. Return all-zeros.
                            end else begin
                                state <= RESTART;
                            end
                            
                        end
                    end
                end

                WAIT_FIND: begin
                    find_min_start <= 1'b0;
                    if(find_min_complete) begin
                        // decoded_bits <= u[CRC_zero_selector];
                        state <= CHECK_CRC;
                        list_iter_fsm <= 0;
                    end
                end
                
                COMPLETE: begin
                    state <= INIT;
                    output_ready <= 1;
                end

                RESTART: begin
                    phi <= 0;

                    P_wr_en <= 0;
                    P_wr_from_F <= 0;
                    Copy_EN <= 0;

                    sort_start <= 0;
                    find_min_start <= 0;

                    frozen_bits <= FROZEN_BITS;

                    active_path <= 1;               // Enable only one path at the beginning.
                    N_active_path <= 1;             // At the beginning: There are only 1 active path.
                    u_iter <= 0;      
                    is_PCC_bit <= 0;    
                    bit_flip <= 1;                  // Enable bit_flip.       

                    for(k=0;k<L;k=k+1) begin        // Initialize PM and CRC_u registers.
                        PM[k] <= 0;
                        CRC_u[k] <= 0;
                    end

                    state <= CH_F_EXEC;             // Start from executing channel F functions.
                end
                
                default: begin
                    state <= INIT;
                end
            endcase
        end
    end
    
    // Post-decoding sorting logic.
    // Calling find_min modules when in complete state.


    generate
        for(i=0;i<L;i=i+1) begin: connect_find_min
            assign fm_input_data[PM_WIDTH*(i+1)-1:PM_WIDTH*i] = PM[i];
            assign fm_input_labels[l*(i+1)-1:l*i] = i[l-1:0];           // Binary representation of i, in l=log2(L) bits.
        end
    endgenerate

    //find_min #(.DATA_WIDTH(PM_WIDTH), .LABEL_WIDTH(l), .LOG_INPUT_NUM(l)) find_min_inst(.clk(clk), 
    //            .input_data(fm_input_data), .input_labels(fm_input_labels), .input_ready(find_min_start), .output_label(ptr_min_PM), .output_ready(find_min_complete));
    
    bitonic_sorting_top #(.LOG_INPUT_NUM(l), .DATA_WIDTH(PM_WIDTH), .LABEL_WIDTH(l), .SIGNED(0), .ASCENDING(1)) 
        bs_findmin(.clk(clk), .rst(reset), .x_valid(find_min_start), 
    .x(fm_input_data), .x_label(fm_input_labels), .y(fm_output_data), .y_label(fm_output_labels), .y_valid(find_min_complete)); 

    // CRC Logic. Need to convert "find_min" into "bitonic_sorting_network", in order to aid the CRC-check logic.
    generate
        for(i=0;i<L;i=i+1) begin
            assign ptr_fm_output_labels[i] = fm_output_labels[l*(i+1)-1:l*i];
        end
    endgenerate
    
endmodule
