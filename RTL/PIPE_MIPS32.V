//////////////////////////////////////////////////////////////////////////////////
// Company: VIT Vellore (Student)  
// Engineer: SANJAY ELAVARASAN KARTHIKEYAN..
// 
// Create Date: 11.01.2026 19:33:00
// Design Name: Pipelined Processor Design
// Module Name: TOP_MIPS
// Project Name: MIPS32(RISC) Pipeline Implementation(5-Stages).
// Target Devices: --
// Tool Versions: Icarus Verilog(iverilog-v12-20220611-x64), GTKWave(GTKWave LTS 3.3.126)
// Description: MIPS32 is a 32-bit Instruction Set Architecture (ISA) for computer processors, known for its simplicity (RISC).
//              This Project Involves entire verilog modeling of MIPS32(R and I type Instruction, J type is not implemented,with IF, ID, EX,
//              MEM, and WB stages.)
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module TOP_MIPS (clk1,clk2);

input clk1,clk2;         //Two - phase Clock


reg [31:0]  PC, IF_ID_IR,IF_ID_NPC;                               // Registers for Latching in IF to ID stage
reg [31:0]  ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm;     //Registers for Latching in ID to EX stage 
reg [2:0]   ID_EX_type, EX_MEM_type, MEM_WB_type;                 //Type of operation or instruction is decoded from IR in respective stages into these registers and helps in making decision. 
reg [31:0]  EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B;                   //Registers for Latching in EX to MEM stage
reg         EX_MEM_cond;                                   
reg [31:0] MEM_WB_IR, MEM_WB_ALUout, MEM_WB_LMD;                  //Registers for Latching in MEM to WB stage


reg [31:0] Reg [0:31];                                            // Register Bank (32x32)
reg [31:0] Mem[0:1023];                                           // 1024 x 32 Memory


parameter   ADD = 6'b000000, SUB = 6'b000001, AND = 6'b000010, OR = 6'b000011;       // OPCODE (31-26)
parameter   SLT = 6'b000100, MUL = 6'b000101, HLT = 6'b111111, LW = 6'b001000;
parameter   SW = 6'b001001,  ADDI = 6'b001010, SUBI = 6'b001011, SLTI = 6'b001100;
parameter BNEQZ = 6'b001101, BEQZ = 6'b001110;

parameter RR_ALU = 3'b000, RM_ALU = 3'b001, LOAD = 3'b010, STORE = 3'b011, BRANCH = 3'b100, HALT = 3'b101;

reg HALTED;  // Set after HLT instruction is Completed(in WB Stage) 
reg TAKEN_BRANCH;  // Required to disable instructions after branch

always@(posedge clk1)         //IF Stage
    if(HALTED==0)            // Dont fetch instruction if HLT instruction is detected in WB stage
        begin 
            if(((EX_MEM_IR[31:26] == BEQZ) && (EX_MEM_cond==1)) || ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond == 0)) )
            begin

                IF_ID_IR            <= #2 Mem[EX_MEM_ALUOut];  
                TAKEN_BRANCH        <= #2 1'b1;     //means branch instruction is there so FLAG== 1
                IF_ID_NPC           <= #2 EX_MEM_ALUOut + 1;
                PC                  <= #2 EX_MEM_ALUOut + 1;
            end

            else
                begin 
                    IF_ID_IR        <= #2 Mem[PC];
                    IF_ID_NPC       <= #2 PC+1;
                    PC              <= #2 PC+1;
                end
        end

always(posedge clk2)        //ID Stage 
    if(HALTED==0)           // Dont Decode instruction if HLT instruction is detected in WB stage
        begin 
            if(IF_ID_IR[25:21] == 5'b00000) ID_EX_A <= 0;   //if Rs = R0 then A<= 0;(R0 is a speical Register in MIPS32 which contains 0 used in copying 0 to other registers)
            else ID_EX_A <= #2 Reg[IF_ID_IR[25:21]];        //else copy content of Rs into A

            if(IF_ID_IR[20:16] == 5'b00000) ID_EX_B <= 0    //if Rt = R0 then B<= 0;(R0 is a speical Register in MIPS32 which contains 0 used in copying 0 to other registers)
            else ID_EX_B <= #2 Reg[IF_ID_IR[20:16]];        //else copy content of Rs into B

            ID_EX_NPC <= #2 IF_ID_NPC;
            ID_EX_IR  <= #2 IF_ID_IR;
            ID_EX_Imm <= #2 {{16{IF_ID_IR[15]}},{IF_ID_IR[15:0]}};

            case(IF_ID_IR[31:26])                            // USING Case Define type of ID_EX_type register helps in next stages.
                ADD,SUB,AND,OR,SLT,MUL: ID_EX_type  <= #2 RR_ALU;
                ADDI,SUBI,SLTI:         ID_EX_type  <= #2 RM_ALU;
                LW:                     ID_EX_type  <= #2 LOAD;
                SW:                     ID_EX_type  <= #2 STORE;
                BNEQZ,BEQZ:             ID_EX_type  <= #2 BRANCH;
                HLT:                    ID_EX_type  <= #2 HALT;
                default:                ID_EX_type  <= #2 HALT;
            endcase
        end

always@(posedge clk1)       //EX STAGE
    if(HALTED==0)           // Dont Execute instruction if HLT instruction is detected in WB stage      
        begin
            EX_MEM_type <= #2 ID_EX_type;
            EX_MEM_IR   <= #2 ID_EX_IR;
            TAKEN_BRANCH <= #2 1'b0; 

            case(ID_EX_type)   //On the basis of type of Instruction do the ALU operation
                
                RR_ALU: begin
                    case(ID_EX_IR[31:26]) //IR - Opcode mentioning Operation to be carried out by the Instruction
                        ADD:EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_B;   // Arithmetic and Logical Operations
                        SUB:EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_B;  
                        AND:EX_MEM_ALUOut <= #2 ID_EX_A & ID_EX_B;
                        OR: EX_MEM_ALUOut <= #2 ID_EX_A | ID_EX_B;
                        SLT:EX_MEM_ALUOut <= #2 ID_EX_A < ID_EX_B; 
                        MUL:EX_MEM_ALUOut <= #2 ID_EX_A * ID_EX_B;
                        default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
                    endcase
                end

                RM_ALU: begin
                    case(ID_EX_IR[31:26]) ////IR - Opcode mentioning Operation to be carried out by the Instruction
                        ADDI: EX_MEM_ALUOut <= #2 ID_EX_A + ID_EX_Imm;    //operation by ALU for I-Type Instruction 
                        SUBI: EX_MEM_ALUOut <= #2 ID_EX_A - ID_EX_Imm;
                        SLTI: EX_MEM_ALUOut <= #2 ID_EX_A < ID_EX_Imm;
                        default: EX_MEM_ALUOut <= #2 32'hxxxxxxxx;
                    endcase
                end       

                LOAD,STORE: 
                    begin
                        EX_MEM_ALUOut   <= #2 ID_EX_A + ID_EX_Imm;
                        EX_MEM_B        <= #2 ID_EX_B;   
                    end
                
                BRANCH:
                   begin
                        EX_MEM_ALUOut   <= #2 ID_EX_NPC + ID_EX_Imm;
                        EX_MEM_cond     <= #2 (ID_EX_A == 0);
                   end
            
            endcase

        end

always@(posedge clk2)   //MEM Stage
    if(HALTED == 0)
        begin
            MEM_WB_type <= #2 EX_MEM_type;
            MEM_WB_IR   <= #2 EX_MEM_IR;

            case(EX_MEM_type)
                RR_ALU,RM_ALU:
                    MEM_WB_ALUout <= #2 EX_MEM_ALUOut; //Store Alu out of Register - Register and Register - memory alu output into data memory.
                LOAD: 
                    MEM_WB_LMD <= #2 Mem[EX_MEM_ALUOut]; //EX_MEM_ALUOut contains the net address of data memory location for the load instruction just write the word into ALUOut location in data memory

                STORE: 
                    if(TAKEN_BRANCH==0) // if there is a branch instruction - this prevents writing of other data
                        MEM[EX_MEM_ALUOut] <= #2 EX_MEM_B;   // content to be stored is already fetched in Temp Reg B which is then written into ALUOut location of data_Memory
    
            endcase
        end

always@(posedge clk1)   //WB Stage
    begin
        if(TAKEN_BRANCH==0) //Disable Write if branch taken
            case(MEM_WB_type)   
                RR_ALU: Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUout; // R-Type Instruction write into rd - destination register location
                RM_ALU: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUout; // I-Type Instruction write into rt - destination register location
                LOAD: Reg[MEM_WB_IR[20:16]]   <= #2 MEM_WB_LMD;    // I-Type Instruction write into rt - destination register location
                HALT: HALTED <= #2 1'b1;
            endcase
    end



endmodule
