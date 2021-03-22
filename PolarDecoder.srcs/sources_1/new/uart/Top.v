`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:  John Zhu. All rights reserved.
// 
// Create Date: 2019/07/12 19:40:09
// Design Name: 
// Module Name: Top
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


module Top(clk, reset, PC_Disp, en, ledsL, ledsR, Rx_Serial, Tx_Serial, D, man_halt, BP_EN);
    input clk;
    input reset;
    output [7:0] PC_Disp;
    output [7:0] en;
    output [7:0] ledsL;
    output [7:0] ledsR;
    output Tx_Serial;
    output [7:0] D;
    input Rx_Serial;
    input man_halt;
    input BP_EN;

    
    wire [31:0] PC;
    wire [31:0] IF_Instruction;
    wire [31:0] MEM_ALUOut;
    wire [31:0] MEM_DatabusB_After_Forwarding;
    wire MEM_MemRead, MEM_MemWrite, EX_Int_Req;
    wire [31:0] MEM_ReadData;
    wire Pipeline_Halt;
    wire mannual_reset;
    wire mannual_halt;
    wire BP_EN_debounced;
    reg CPU_reset;
    
    debounce deb(clk, reset, mannual_reset);
    debounce deb2(clk, man_halt, mannual_halt);
    debounce deb3(clk, BP_EN,BP_EN_debounced);
    
    PipeLine pipeline(.clk(clk), .reset(CPU_reset), .halt(Pipeline_Halt), .PC(PC), .IF_Instruction(IF_Instruction),
                    .MEM_ALUOut(MEM_ALUOut), .MEM_DatabusB_After_Forwarding(MEM_DatabusB_After_Forwarding),
                    .MEM_MemRead(MEM_MemRead), .MEM_MemWrite(MEM_MemWrite), .MEM_ReadData(MEM_ReadData), 
                    .EX_Int_Req(EX_Int_Req), .BranchPredictor_EN(BP_EN_debounced));
                    
    /*-------------------Instr Mem---------------*/
    wire [31:0] Instr_Adr, Instr_WriteData, Instr_ReadData;
    wire Instr_RdEn, Instr_WrEn;
    InstructionMemory instr_mem(.clk(clk), .Address(Instr_Adr), .Instruction(IF_Instruction), .WrEn(Instr_WrEn), 
                         .WrData(Instr_WriteData));
                        
    /*-------------------Data Mem---------------*/
    wire [31:0] Data_Adr, Data_WriteData;
    wire Data_RdEn, Data_WrEn;
               
    MemoryDevices memory_devices(.clk(clk), .Address(Data_Adr), .Write_data(Data_WriteData), .Read_data(MEM_ReadData), 
                .MemRead(Data_RdEn), 
                .MemWrite(Data_WrEn), 
                .Timer_Int(EX_Int_Req), .reset(mannual_reset), 
                .en(en), .ledsL(ledsL), .ledsR(ledsR), .LED_Disp(PC_Disp));
                
 //-----------------------UART Processor----------------  
    parameter [2:0] Idle            = 3'b000;
    parameter [2:0] Recv_NumofWords = 3'b001;
    parameter [2:0] Recv_WordAdr    = 3'b111;
    parameter [2:0] Instr_Read      = 3'b010;
    parameter [2:0] Instr_Write     = 3'b011;
    parameter [2:0] Data_Read       = 3'b100;
    parameter [2:0] Data_Write      = 3'b101;
    parameter [2:0] Stop            = 3'b110;
    

    // Engineer:  John Zhu. All rights reserved.
    /*-------------------RX/TX modules---------------*/
    wire Rx_DataValid;
    wire [7:0] Rx_Data;
    uart_rx Rx(.i_Clock(clk), .i_Rx_Serial(Rx_Serial), .o_Rx_DV(Rx_DataValid), .o_Rx_Byte(Rx_Data));
    
    reg Tx_DataValid;
    reg [7:0] Tx_Data;
    wire Tx_Active;
    wire Tx_Done;
    uart_tx Tx(.i_Clock(clk), .i_Tx_DV(Tx_DataValid), .i_Tx_Byte(Tx_Data), .o_Tx_Serial(Tx_Serial), 
                .o_Tx_Active(Tx_Active), .o_Tx_Done(Tx_Done));
    
    /*-------------------Control FSM---------------*/    
    reg [2:0] FSM_State;
    reg [7:0] Rx_Instr_Reg;
    reg [7:0] Rx_NumOfWords;
    reg [4:0] ByteCnt;
    reg [31:0] Rx_WordAdr;
    reg CPU_Halt;
    
    reg [2:0] FSM_ReadMem;
    parameter [2:0] Load_Address    = 3'b000;
    parameter [2:0] Read            = 3'b001;
    parameter [2:0] FetchData       = 3'b010;
    parameter [2:0] Transmit        = 3'b011;
    parameter [2:0] Wait            = 3'b100;
    parameter [2:0] SaveData        = 3'b101;
    reg [2:0] FSM_WriteMem;
    
    
    reg [31:0] Adr_Reg;
    reg RdEn_Reg;
    reg WrEn_Reg;
    reg CPU_reset_from_Rx;
    
    reg [31:0] Tx_Data_word;
    reg [31:0] Rx_Data_word;
    // Engineer:  John Zhu. All rights reserved.
    /*-----------------MUXES-----------------*/
    assign Instr_RdEn = (FSM_State == Instr_Read ) ? RdEn_Reg : 1'b0;
    assign Instr_WrEn = (FSM_State == Instr_Write) ? WrEn_Reg : 1'b0;
    assign Data_RdEn = (FSM_State == Data_Read )   ? RdEn_Reg : MEM_MemRead;
    assign Data_WrEn = (FSM_State == Data_Write)   ? WrEn_Reg : MEM_MemWrite;
    assign Instr_Adr = (FSM_State == Instr_Read || FSM_State == Instr_Write)?Adr_Reg : PC;
    assign Data_Adr  = (FSM_State == Data_Read || FSM_State == Data_Write) ? Adr_Reg : MEM_ALUOut;
    
    wire [31:0] ReadData_from_MEM;
    reg [31:0] WriteData_to_MEM;
    assign ReadData_from_MEM = (FSM_State == Instr_Read)?IF_Instruction : (FSM_State == Data_Read)?MEM_ReadData:32'b0;
    assign Instr_WriteData =    (FSM_State == Instr_Write)?WriteData_to_MEM : 32'b0;
    assign Data_WriteData =     (FSM_State == Data_Write) ?WriteData_to_MEM : MEM_DatabusB_After_Forwarding;
    //All the zeros should be replaced by the original Pipeline signals.
    /*---------------ENDOF MUXES---------------*/
    
    initial begin
        FSM_State <= Idle;
        ByteCnt <= 0;
        CPU_Halt <= 0;
        CPU_reset_from_Rx <= 0;
    end
    
    
    always@(posedge clk)
    begin
        case(FSM_State[2:0])
            Idle:   begin
                if(Rx_DataValid) begin
                    FSM_State <= Recv_NumofWords;   //Next State.
                    Rx_Instr_Reg <= Rx_Data;        //Save the instruction.
                end
                else
                    FSM_State <= Idle;
            end
            
            Recv_NumofWords: begin
                if(Rx_DataValid) begin
                    FSM_State <= Recv_WordAdr;
                    Rx_NumOfWords <= Rx_Data;
                    ByteCnt <= 0;
                end
                else
                    FSM_State <= Recv_NumofWords;
            end
            
            Recv_WordAdr:   begin
                if(Rx_DataValid) begin
                    Rx_WordAdr <= {Rx_WordAdr[23:0], Rx_Data};
                    if(ByteCnt == 3) begin
                        ByteCnt <= 0;
                        Rx_Data_word <= 0;
                        case(Rx_Instr_Reg[1:0])
                            2'b00:  begin
                                FSM_State <= Instr_Read;
                                FSM_ReadMem <= Load_Address;
                                end
                                
                            2'b01:begin
                                FSM_State <= Instr_Write;
                                FSM_WriteMem <= FetchData;
                                CPU_reset_from_Rx <= 1;
                                end
                                
                            2'b10:  begin
                                FSM_State <= Data_Read;
                                FSM_ReadMem <= Load_Address;
                                end
                            2'b11:  begin
                                FSM_State <= Data_Write;
                                FSM_WriteMem <= FetchData;
                                end
                        endcase
                        CPU_Halt <= 1;
                    end
                    else begin
                        ByteCnt <= ByteCnt + 1;
                        FSM_State <= Recv_WordAdr;
                    end
                end
                else
                    FSM_State <= Recv_WordAdr;
            end
            
            //Now: Rx_NumOfWords and Rx_WordAdr are prepared.
            Instr_Read, Data_Read: begin
                case(FSM_ReadMem[2:0])
                    Load_Address:   begin
                        Adr_Reg <= {Rx_WordAdr[29:0],2'b00};
                        FSM_ReadMem <= Read;
                        RdEn_Reg <= 1;
                    end
                    
                    Read:   begin
                        FSM_ReadMem <= FetchData;
                        RdEn_Reg <= 0;
                    end
                    
                    FetchData:  begin
                        Tx_Data_word <= ReadData_from_MEM;
                        FSM_ReadMem <= Transmit;
                    end
                    
                    Transmit:   begin   //MSB first.
                        Tx_DataValid <= 1;
                        FSM_ReadMem <= Wait;
                        if(ByteCnt == 0)    begin
                            ByteCnt <= 1;
                            Tx_Data <= Tx_Data_word[31:24];
                        end
                        else if(ByteCnt == 1)   begin
                            ByteCnt <= 2;
                            Tx_Data <= Tx_Data_word[23:16];
                        end
                        else if(ByteCnt == 2)   begin
                            ByteCnt <= 3;
                            Tx_Data <= Tx_Data_word[15:8];
                        end
                        else if(ByteCnt == 3)   begin
                            ByteCnt <= 4;
                            Tx_Data <= Tx_Data_word[7:0];
                        end
                    end
                    
                    Wait:   begin
                        Tx_DataValid <= 0;
                        if(Tx_Done) begin
                            if(ByteCnt == 4) begin
                                Rx_WordAdr <= Rx_WordAdr + 1;
                                FSM_ReadMem <= Load_Address;
                                ByteCnt <= 0;
                                if(Rx_NumOfWords == 1)  begin
                                    FSM_State <= Stop;
                                end
                                else    begin
                                    Rx_NumOfWords <= Rx_NumOfWords - 1;
                                end
                                
                            end
                            else begin
                                FSM_ReadMem <= Transmit;
                            end
                        end
                        else    begin
                            FSM_ReadMem <= Wait;
                        end
                    end
                endcase
            end
            
            Instr_Write, Data_Write: begin
                case(FSM_WriteMem[2:0])
                    FetchData:   begin  //Fetch data from Rx UART.
                        if(Rx_DataValid)    begin
                            Rx_Data_word <= {Rx_Data_word[23:0], Rx_Data};
                            if(ByteCnt == 3) begin
                                ByteCnt <= 0;
                                FSM_WriteMem <= SaveData;
                            end
                            else begin
                                ByteCnt <= ByteCnt + 1;
                            end
                        end
                        else    begin
                            FSM_WriteMem <= FetchData;
                        end
                    end
                    
                    SaveData:   begin
                        WrEn_Reg <= 1;
                        WriteData_to_MEM <= Rx_Data_word;
                        Adr_Reg <= {Rx_WordAdr[29:0],2'b00};
                        FSM_WriteMem <= Wait;
                    end
                    
                    Wait:   begin
                        WrEn_Reg <= 0;
                        if(Rx_NumOfWords == 1) begin
                            FSM_State <= Stop;
                        end
                        else begin
                            Rx_NumOfWords <= Rx_NumOfWords - 1;
                            FSM_WriteMem <= FetchData;
                            ByteCnt <= 0;
                        end
                        Rx_WordAdr <= Rx_WordAdr + 1;
                    end
                endcase
            end
            
            Stop:  begin
                CPU_Halt <= 0;
                FSM_State <= Idle;
                FSM_WriteMem <= FetchData;
                FSM_ReadMem <= Load_Address;
                ByteCnt <= 0;
                CPU_reset_from_Rx <= 0;
            end
            
        
        
        endcase
    end
    
    assign D[2:0] = FSM_State[2:0];
    assign D[3] = (FSM_State == Data_Read || FSM_State == Data_Write);
    assign D[4] = (FSM_State == Instr_Read || FSM_State == Instr_Write);
    assign D[5] = BP_EN_debounced;
    assign D[6] = CPU_reset;
    assign D[7] = Pipeline_Halt;
    assign Pipeline_Halt = CPU_Halt || mannual_halt;
    
    always@(posedge clk)
        CPU_reset <= CPU_reset_from_Rx | mannual_reset;
    
 
endmodule
