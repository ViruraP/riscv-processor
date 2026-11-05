//把一条32位 RISC-V 指令拆成基本字段，并按照指令类型生成32位立即数
//Split a 32-bit RISC-V instruction into basic fields and generate a 32-bit immediate value according to the instruction type.
module decoder (
    input  logic [31:0] instruction,

    output logic [6:0]  opcode,
    output logic [4:0]  rd,
    output logic [2:0]  funct3,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [6:0]  funct7,

    output logic [31:0] imm,//根据指令类型生成的立即数Immediate number generated based on the instruction type
    output logic [31:0] u_imm//固定取指令高20位，并在低位补12个0 Fix the high 20 bits of the instruction and pad the lower 12 bits with zeros.
);
/*
op type              opcode	    立即数类型immediate number type
I-type ALU	         0010011	I
Load	             0000011	I
JALR	             1100111	I
Store	             0100011	S
Branch	             1100011	SB
LUI                	 0110111	U
AUIPC	             0010111	U
JAL                  1101111	UJ
*/

/*
decoder 提供所有可能用到的“切片”，指令类型决定哪些切片有意义
The decoder provides all possible "slices" that can be used, and the type of instruction determines which slices are meaningful.
位	       字段	       作用
[6:0]	 opcode	    判断指令大类
[11:7]	   rd	     目标寄存器
[14:12]	  funct3	进一步区分操作
[19:15]    rs1	    第一个源寄存器
[24:20]	  rs2	    第二个源寄存器
[31:25]	  funct7	进一步区分操作
*/
    // Basic instruction fields

    always_comb begin

        opcode = instruction[6:0];
        rd     = instruction[11:7];
        funct3 = instruction[14:12];
        rs1    = instruction[19:15];
        rs2    = instruction[24:20];
        funct7 = instruction[31:25];

        // Safe default
        imm   = 32'b0;
        u_imm = {instruction[31:12], 12'b0};

        // Immediate generation according to opcode
        case (instruction[6:0])
            // I-type ALU instructions
            // ADDI, SLTI, SLTIU, XORI, ORI, ANDI,
            // SLLI, SRLI and SRAI
            7'b0010011: begin
                imm = {
                    {20{instruction[31]}},
                    instruction[31:20]//imm[11:0]
                };//最高位 instruction[31] 是符号位，复制 20 次后组成 32 位立即数The most significant bit, instruction[31], is the sign bit. After being replicated 20 times, it forms a 32-bit immediate number.
            end

            // I-type load instructions
            // LB, LH, LW, LBU and LHU
            7'b0000011: begin
                imm = {
                    {20{instruction[31]}},
                    instruction[31:20]
                };
            end

            // I-type JALR
            7'b1100111: begin
                imm = {
                    {20{instruction[31]}},
                    instruction[31:20]
                };
            end

            // S-type store instructions
            // SB, SH and SW
            7'b0100011: begin
                imm = {
                    {20{instruction[31]}},
                    instruction[31:25],//imm[11:5]
                    instruction[11:7]//imm[4:0]
                };
            end

            // SB-type branch instructions
            // BEQ, BNE, BLT, BGE, BLTU and BGEU
            7'b1100011: begin
                imm = {
                    {19{instruction[31]}},
                    instruction[31],
                    instruction[7],
                    instruction[30:25],
                    instruction[11:8],
                    1'b0//imm[0]=0
                };
            end

            // U-type instructions
            // LUI and AUIPC
            7'b0110111,
            7'b0010111: begin
                imm = {
                    instruction[31:12],
                    12'b0
                };
            end

            // UJ-type JAL
            7'b1101111: begin
                imm = {
                    {11{instruction[31]}},
                    instruction[31],//imm[20]
                    instruction[19:12],//imm[19:12]
                    instruction[20],//imm[11]
                    instruction[30:21],//imm[10:1]
                    1'b0//imm[0]=0
                };
            end

            // R-type, FENCE, SYSTEM or invalid instruction
            default: begin
                imm = 32'b0;
            end

        endcase
    end

endmodule
