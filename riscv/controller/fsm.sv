module fsm (
    input  logic       clk,
    input  logic       rst_n,

    // Status signals
    input  logic       mem_ready,//memory from Milestone 2
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    input  logic [2:0] flags,       // {overflow, negative, zero}

    // PC and instruction register
    output logic       PCWrite,//是否在时钟沿更新 PC。Does the PC update on the clock edge
    output logic [1:0] PCSel,//更新 PC 时，新 PC 从哪里来。Where does the new PC come from when updating
    output logic       IRWrite,//是否把内存读出的指令存入指令寄存器 IR。Whether to store the instruction fetched from memory into the instruction register IR

    // Register file and effective-address register
    output logic       RFWrite_n,   // active-low是否写寄存器堆。Should the register stack be written
    output logic       EAWrite,//是否保存有效地址（effective address）

    // Datapath multiplexers
    output logic       AddrSel,//内存地址选 PC，还是选有效地址。the memory address be selected as the PC, or the effective address
    output logic       ALUASel,//0——rs1 寄存器读出的值；1——当前 PC.0 - The value read from the rs1 register; 1 - The current PC
    output logic [1:0] ALUBSel,//ALU 两个输入选什么。What should be selected as the two inputs of the ALU.
   
    output logic [3:0] ALUOp,//ALU 做加、减、移位等哪种操作。What operations does the ALU perform
    output logic [2:0] WBSel,//写回 rd 的数据选什么。What data should be written back to rd

    // Memory controls
    output logic       MemRead,//是否发起内存读请求。Whether to initiate a memory read request
    output logic [1:0] MemWriteMode//是否写内存，以及写字节、半字或字。Whether to write to memory, and whether to write in bytes, half-words or words
);
//总控制输出12 个 Control Signals，总计 20 bits
    // Opcode definitions
    localparam logic [6:0] OPCODE_OP     = 7'b0110011;//R-type, register to register
    localparam logic [6:0] OPCODE_OP_IMM = 7'b0010011;//I-type, immediate
    localparam logic [6:0] OPCODE_LUI    = 7'b0110111;//U-type, constant building_LUI
    localparam logic [6:0] OPCODE_AUIPC  = 7'b0010111;//U-type, constant building_AUIPC
    localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;//I-type, loads
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;//S-type, stores
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;//SB-type, conditional branches
    localparam logic [6:0] OPCODE_JAL    = 7'b1101111;//UJ-type, unconditional jump
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;//I-type, indirect jump
    
    // ALU operation definitions

    localparam logic [3:0] ALU_ADD  = 4'b0000;
    localparam logic [3:0] ALU_SUB  = 4'b0001;
    localparam logic [3:0] ALU_SLL  = 4'b0010;
    localparam logic [3:0] ALU_SLT  = 4'b0100;
    localparam logic [3:0] ALU_SLTU = 4'b0110;
    localparam logic [3:0] ALU_XOR  = 4'b1000;
    localparam logic [3:0] ALU_SRL  = 4'b1010;
    localparam logic [3:0] ALU_SRA  = 4'b1011;
    localparam logic [3:0] ALU_OR   = 4'b1100;
    localparam logic [3:0] ALU_AND  = 4'b1110;

    // Multiplexer encodings

    // PCSel
    localparam logic [1:0] PC_PLUS_4   = 2'b00;
    localparam logic [1:0] PC_PLUS_IMM = 2'b01;
    localparam logic [1:0] PC_FROM_ALU = 2'b10;
    //2'b00  PC_PLUS_4  当前 PC + 4普通指令完成、分支不成立; 2'b01  PC_PLUS_IMM  当前 PC + 分支或跳转立即数分支成立、JAL;2'b10  PC_FROM_ALU 由 ALU 算出的跳转地址JALR
    //2'b00 PC_PLUS_4 Indicates that the current PC + 4 ordinary instruction has been completed and the branch is not valid; 2'b01 PC_PLUS_IMM Indicates that the current PC + branch or jump immediate number branch is valid and JAL; 2'b10 PC_FROM_ALU Indicates the jump address calculated by ALU for JALR

    // ALUBSel
    localparam logic [1:0] ALU_B_RS2 = 2'b00;
    localparam logic [1:0] ALU_B_IMM = 2'b01;
     //00（ALU_B_RS2）rs2 寄存器读出的值;01（ALU_B_IMM）decoder 得到的立即数
    //00 (ALU_B_RS2) The value read from the RS2 register; 01 (ALU_B_IMM) The immediate number obtained by the decoder

    // WBSel
    localparam logic [2:0] WB_ALU    = 3'b000;
    localparam logic [2:0] WB_MEMORY = 3'b001;
    localparam logic [2:0] WB_PC4    = 3'b010;
    localparam logic [2:0] WB_U_IMM  = 3'b011;
    localparam logic [2:0] WB_PC_IMM = 3'b100;
//| `WBSel`  | 名name         | 选中的数据 selected data                    | 用在哪些指令 Instruction |
//| `3'b000` | `WB_ALU`      | ALU 的计算结果  ALU result                  | ADD、SUB、ADDI、SLT.etc. |
//| `3'b001` | `WB_MEMORY`   | 从内存读出的数据data from mem                | LB、LH、LW、LBU、LHU |
//| `3'b010` | `WB_PC4`      | current PC + 4                            | JAL、JALR，保存返回地址 |
//| `3'b011` | `WB_U_IMM`    | U-immediate number ，即指令高 20 位放到结果高 20 位、低 12 位为 0 | LUI |
//| `3'b100` | `WB_PC_IMM`   | current PC + U-immediate number           | AUIPC |

    // MemWriteMode
    localparam logic [1:0] MEM_WRITE_NONE = 2'b00;
    localparam logic [1:0] MEM_WRITE_BYTE = 2'b01;
    localparam logic [1:0] MEM_WRITE_HALF = 2'b10;
    localparam logic [1:0] MEM_WRITE_WORD = 2'b11;

    // Controller states
    typedef enum logic [1:0] {
        FETCH_DECODE,
        EXECUTE_1,
        EXECUTE_2
    } state_t;

    state_t current_state;
    state_t next_state;

    // Internal status signals
    logic zero_flag;
    logic valid_load;
    logic valid_store;

    // flags = {overflow, negative, zero}
    assign zero_flag = flags[0];//change with flag from ALU

    // Validate load/store funct3
    //valid_load = 1 means this is a supported load instruction.
    always_comb begin
        valid_load  = 1'b0;
        valid_store = 1'b0;
        // LB, LH, LW, LBU, LHU
        case (funct3)
            3'b000,
            3'b001,
            3'b010,
            3'b100,
            3'b101: valid_load = 1'b1;
            default: valid_load = 1'b0;
        endcase
        // SB, SH, SW
        case (funct3)
            3'b000,
            3'b001,
            3'b010: valid_store = 1'b1;

            default: valid_store = 1'b0;
        endcase
    end
    
    // State register只保存当前状态only save current state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= FETCH_DECODE;//if rst_n=0，FSM back FETCH_DECODE
        else
            current_state <= next_state;
    end
    
    // Next-state logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            FETCH_DECODE: begin
                if (mem_ready)
                    next_state = EXECUTE_1;
            end
            EXECUTE_1: begin

                if ((opcode == OPCODE_LOAD  && valid_load) ||
                    (opcode == OPCODE_STORE && valid_store)) begin
                    next_state = EXECUTE_2;
                end
                else begin
                    next_state = FETCH_DECODE;
                end
            end
            EXECUTE_2: begin
                if (mem_ready)
                    next_state = FETCH_DECODE;
            end
            default: begin
                next_state = FETCH_DECODE;
            end
        endcase
    end
    // Controller output logic
    always_comb begin
        PCWrite      = 1'b0;
        PCSel        = PC_PLUS_4;
        IRWrite      = 1'b0;
        RFWrite_n    = 1'b1;
        EAWrite      = 1'b0;
        AddrSel      = 1'b0;
        ALUASel      = 1'b0;
        ALUBSel      = ALU_B_RS2;
        ALUOp        = ALU_ADD;
        WBSel        = WB_ALU;
        MemRead      = 1'b0;
        MemWriteMode = MEM_WRITE_NONE;
        case (current_state)
            FETCH_DECODE: begin
                AddrSel = 1'b0;
                MemRead = !mem_ready;
                if (mem_ready)
                    IRWrite = 1'b1;
            end
            EXECUTE_1: begin
                case (opcode)
                    OPCODE_OP: begin
                        ALUASel = 1'b0;
                        ALUBSel = ALU_B_RS2;
                        WBSel   = WB_ALU;
                        case (funct3)
                            3'b000: begin
                                if (funct7 == 7'b0100000)
                                    ALUOp = ALU_SUB;
                                else
                                    ALUOp = ALU_ADD;
                            end
                            // SLL
                            3'b001:
                                ALUOp = ALU_SLL;
                            // SLT
                            3'b010:
                                ALUOp = ALU_SLT;
                            // SLTU
                            3'b011:
                                ALUOp = ALU_SLTU;
                            // XOR
                            3'b100:
                                ALUOp = ALU_XOR;
                            // SRL or SRA
                            3'b101: begin
                                if (funct7 == 7'b0100000)
                                    ALUOp = ALU_SRA;
                                else
                                    ALUOp = ALU_SRL;
                            end
                            // OR
                            3'b110:
                                ALUOp = ALU_OR;
                            // AND
                            3'b111:
                                ALUOp = ALU_AND;
                            default:
                                ALUOp = ALU_ADD;
                        endcase
                        RFWrite_n = 1'b0;
                        PCWrite = 1'b1;
                        
                        PCSel   = PC_PLUS_4;
                    end
                    OPCODE_OP_IMM: begin
                        ALUASel = 1'b0;
                        ALUBSel = ALU_B_IMM;
                        WBSel   = WB_ALU;
                        case (funct3)
                            // ADDI
                            3'b000:
                                ALUOp = ALU_ADD;
                            // SLLI
                            3'b001:
                                ALUOp = ALU_SLL;
                            // SLTI
                            3'b010:
                                ALUOp = ALU_SLT;
                            // SLTIU
                            3'b011:
                                ALUOp = ALU_SLTU;
                            // XORI
                            3'b100:
                                ALUOp = ALU_XOR;
                            // SRLI or SRAI
                            3'b101: begin
                                if (funct7 == 7'b0100000)
                                    ALUOp = ALU_SRA;
                                else
                                    ALUOp = ALU_SRL;
                            end
                            // ORI
                            3'b110:
                                ALUOp = ALU_OR;
                            // ANDI
                            3'b111:
                                ALUOp = ALU_AND;
                            default:
                                ALUOp = ALU_ADD;
                        endcase
                        RFWrite_n = 1'b0;
                        PCWrite = 1'b1;
                        PCSel   = PC_PLUS_4;
                    end

                    OPCODE_LUI: begin
                        WBSel     = WB_U_IMM;
                        RFWrite_n = 1'b0;
                        PCWrite = 1'b1;
                        PCSel   = PC_PLUS_4;
                    end

                    OPCODE_AUIPC: begin
                        WBSel     = WB_PC_IMM;
                        RFWrite_n = 1'b0;
                        PCWrite = 1'b1;
                        PCSel   = PC_PLUS_4;
                    end

                    OPCODE_LOAD: begin
                        if (valid_load) begin
                            ALUASel = 1'b0;
                            ALUBSel = ALU_B_IMM;
                            ALUOp   = ALU_ADD;
                            EAWrite = 1'b1;
                            PCWrite = 1'b0;
                        end
                        else begin
                            PCWrite = 1'b1;
                            PCSel   = PC_PLUS_4;
                        end
                    end

                    OPCODE_STORE: begin
                        if (valid_store) begin
                            ALUASel = 1'b0;
                            ALUBSel = ALU_B_IMM;
                            ALUOp   = ALU_ADD;
                            EAWrite = 1'b1;
                            PCWrite = 1'b0;
                        end
                        else begin
                            PCWrite = 1'b1;
                            PCSel   = PC_PLUS_4;
                        end
                    end

                    OPCODE_BRANCH: begin
                        ALUASel = 1'b0;
                        ALUBSel = ALU_B_RS2;
                        PCWrite = 1'b1;
                        PCSel = PC_PLUS_4;
                        case (funct3)
                            // BEQ
                            3'b000: begin
                                ALUOp = ALU_SUB;
                                if (zero_flag)
                                    PCSel = PC_PLUS_IMM;
                            end

                            // BNE
                            3'b001: begin
                                ALUOp = ALU_SUB;
                                if (!zero_flag)
                                    PCSel = PC_PLUS_IMM;
                            end
                            // BLT
                            3'b100: begin
                                ALUOp = ALU_SLT;
                              if (!zero_flag)
                                    PCSel = PC_PLUS_IMM;
                            end
                         3'b101: begin
                                ALUOp = ALU_SLT;
                                if (zero_flag)
                                    PCSel = PC_PLUS_IMM;
                            end
                          // BLTU
                            3'b110: begin
                                ALUOp = ALU_SLTU;
                                if (!zero_flag)
                                    PCSel = PC_PLUS_IMM;
                            end
                            // BGEU
                            3'b111: begin
                                ALUOp = ALU_SLTU;
                                if (zero_flag)
                                    PCSel = PC_PLUS_IMM;
                            end
                            default: begin
                                ALUOp = ALU_SUB;
                                PCSel = PC_PLUS_4;
                            end
                        endcase
                    end

                    OPCODE_JAL: begin
                       WBSel     = WB_PC4;
                        RFWrite_n = 1'b0;
                       PCWrite = 1'b1;
                        PCSel   = PC_PLUS_IMM;
                    end

                    OPCODE_JALR: begin
                        if (funct3 == 3'b000) begin
                            ALUASel = 1'b0;
                            ALUBSel = ALU_B_IMM;
                            ALUOp   = ALU_ADD;
                            WBSel     = WB_PC4;
                            RFWrite_n = 1'b0;
                            PCWrite = 1'b1;
                            PCSel   = PC_FROM_ALU;
                        end
                        else begin
                            PCWrite = 1'b1;
                            PCSel   = PC_PLUS_4;
                        end
                    end

                    default: begin
                        RFWrite_n = 1'b1;
                        PCWrite = 1'b1;
                        PCSel   = PC_PLUS_4;
                    end
                endcase
            end

            EXECUTE_2: begin
                AddrSel = 1'b1;
                case (opcode)
                  OPCODE_LOAD: begin
                        WBSel = WB_MEMORY;
                       MemRead = !mem_ready;
                        if (mem_ready) begin
                          RFWrite_n = 1'b0;
                            PCWrite = 1'b1;
                            PCSel   = PC_PLUS_4;
                        end
                    end

                    OPCODE_STORE: begin
                        if (!mem_ready) begin
                            case (funct3)
                                // SB
                                3'b000:
                                    MemWriteMode = MEM_WRITE_BYTE;
                                // SH
                                3'b001:
                                    MemWriteMode = MEM_WRITE_HALF;
                                // SW
                                3'b010:
                                    MemWriteMode = MEM_WRITE_WORD;
                                default:
                                    MemWriteMode = MEM_WRITE_NONE;
                            endcase
                        end
                        else begin
                            MemWriteMode = MEM_WRITE_NONE;
                        end
                        if (mem_ready) begin
                            PCWrite = 1'b1;
                            PCSel   = PC_PLUS_4;
                        end
                    end
                   default: begin
                        // Safety recovery
                        PCWrite = 1'b1;
                        PCSel   = PC_PLUS_4;
                    end
                endcase
            end
            default: begin
                // Keep safe defaults
            end
        endcase
    end
endmodule
