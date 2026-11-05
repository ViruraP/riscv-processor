`timescale 1ns / 1ps
//不运行完整的 RISC-V 指令，而是直接给 FSM（Controller）输入 opcode、funct3、flags 和 mem_ready，
//检查它在不同状态下能否输出正确的控制信号
module fsm_tb;

    logic       clk;
    logic       rst_n;
    logic       mem_ready;

    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [2:0] flags;

    logic       PCWrite;
    logic [1:0] PCSel;
    logic       IRWrite;
    logic       RFWrite_n;
    logic       EAWrite;
    logic       AddrSel;
    logic       ALUASel;
    logic [1:0] ALUBSel;
    logic [3:0] ALUOp;
    logic [2:0] WBSel;
    logic       MemRead;
    logic [1:0] MemWriteMode;

    integer errors;

    localparam logic [6:0] OPCODE_LOAD    = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE   = 7'b0100011;
    localparam logic [6:0] OPCODE_BRANCH  = 7'b1100011;
    localparam logic [6:0] OPCODE_JALR    = 7'b1100111;
    localparam logic [6:0] OPCODE_JAL     = 7'b1101111;
    localparam logic [6:0] OPCODE_OP_IMM  = 7'b0010011;
    localparam logic [6:0] OPCODE_OP      = 7'b0110011;
    localparam logic [6:0] OPCODE_LUI     = 7'b0110111;
    localparam logic [6:0] OPCODE_AUIPC   = 7'b0010111;
    localparam logic [6:0] OPCODE_SYSTEM  = 7'b1110011;
    localparam logic [6:0] OPCODE_FENCE   = 7'b0001111;

    localparam logic [1:0] PC_PLUS_4   = 2'b00;
    localparam logic [1:0] PC_PLUS_IMM = 2'b01;
    localparam logic [1:0] PC_FROM_ALU = 2'b10;

    localparam logic ALU_A_RS1 = 1'b0;
    localparam logic ALU_A_PC  = 1'b1;

    localparam logic [1:0] ALU_B_RS2 = 2'b00;
    localparam logic [1:0] ALU_B_IMM = 2'b01;

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

    localparam logic [2:0] WB_ALU    = 3'b000;
    localparam logic [2:0] WB_MEMORY = 3'b001;
    localparam logic [2:0] WB_PC4    = 3'b010;
    localparam logic [2:0] WB_UIMM   = 3'b011;
    localparam logic [2:0] WB_PC_IMM = 3'b100;

    localparam logic [1:0] MEM_WRITE_NONE = 2'b00;
    localparam logic [1:0] MEM_WRITE_BYTE = 2'b01;
    localparam logic [1:0] MEM_WRITE_HALF = 2'b10;
    localparam logic [1:0] MEM_WRITE_WORD = 2'b11;

    fsm dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .mem_ready    (mem_ready),
        .opcode       (opcode),
        .funct3       (funct3),
        .funct7       (funct7),
        .flags        (flags),
        .PCWrite      (PCWrite),
        .PCSel        (PCSel),
        .IRWrite      (IRWrite),
        .RFWrite_n    (RFWrite_n),
        .EAWrite      (EAWrite),
        .AddrSel      (AddrSel),
        .ALUASel      (ALUASel),
        .ALUBSel      (ALUBSel),
        .ALUOp        (ALUOp),
        .WBSel        (WBSel),
        .MemRead      (MemRead),
        .MemWriteMode (MemWriteMode)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_value (
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string test_name
    );
        begin
            if (actual !== expected) begin
                errors = errors + 1;
                $error(
                    "%s FAILED: expected=%h got=%h",
                    test_name,
                    expected,
                    actual
                );
            end
            else begin
                $display("%s PASSED", test_name);
            end
        end
    endtask

    task automatic enter_execute_1;
        begin
            mem_ready = 1'b1;
            #1;

            check_value(MemRead, 1'b0, "FETCH MemRead disabled when ready");
            check_value(IRWrite, 1'b1, "FETCH IRWrite");

            @(posedge clk);
            #1;

            mem_ready = 1'b0;
            #1;
        end
    endtask

    task automatic return_to_fetch;
        begin
            @(posedge clk);
            #1;

            check_value(MemRead, 1'b1, "Return to FETCH MemRead");
            check_value(AddrSel, 1'b0, "Return to FETCH AddrSel");
            check_value(RFWrite_n, 1'b1, "Return to FETCH RFWrite disabled");
            check_value(PCWrite, 1'b0, "Return to FETCH PCWrite disabled");
        end
    endtask

    task automatic test_rtype (
        input logic [2:0] f3,
        input logic [6:0] f7,
        input logic [3:0] expected_aluop,
        input string test_name
    );
        begin
            opcode = OPCODE_OP;
            funct3 = f3;
            funct7 = f7;
            flags = 3'b000;

            enter_execute_1();

            check_value(ALUASel, ALU_A_RS1, {test_name, " ALU A"});
            check_value(ALUBSel, ALU_B_RS2, {test_name, " ALU B"});
            check_value(ALUOp, expected_aluop, {test_name, " ALUOp"});
            check_value(WBSel, WB_ALU, {test_name, " WBSel"});
            check_value(RFWrite_n, 1'b0, {test_name, " RFWrite"});
            check_value(PCWrite, 1'b1, {test_name, " PCWrite"});
            check_value(PCSel, PC_PLUS_4, {test_name, " PCSel"});

            return_to_fetch();
        end
    endtask

    task automatic test_itype (
        input logic [2:0] f3,
        input logic [6:0] f7,
        input logic [3:0] expected_aluop,
        input string test_name
    );
        begin
            opcode = OPCODE_OP_IMM;
            funct3 = f3;
            funct7 = f7;
            flags = 3'b000;

            enter_execute_1();
            check_value(ALUASel, ALU_A_RS1, {test_name, " ALU A"});
            check_value(ALUBSel, ALU_B_IMM, {test_name, " ALU B"});
            check_value(ALUOp, expected_aluop, {test_name, " ALUOp"});
            check_value(WBSel, WB_ALU, {test_name, " WBSel"});
            check_value(RFWrite_n, 1'b0, {test_name, " RFWrite"});
            check_value(PCWrite, 1'b1, {test_name, " PCWrite"});
            check_value(PCSel, PC_PLUS_4, {test_name, " PCSel"});
            return_to_fetch();
        end
    endtask

    task automatic test_store (
        input logic [2:0] store_funct3,
        input logic [1:0] expected_mode,
        input string test_name
    );
        begin
            opcode = OPCODE_STORE;
            funct3 = store_funct3;
            funct7 = 7'b0;
            flags = 3'b0;

            enter_execute_1();
//EXECUTE_1：计算有效地址
            check_value(ALUASel, ALU_A_RS1, {test_name, " ALU A"});
            check_value(ALUBSel, ALU_B_IMM, {test_name, " ALU B"});
            check_value(ALUOp, ALU_ADD, {test_name, " address ADD"});
            check_value(EAWrite, 1'b1, {test_name, " EAWrite"});
            check_value(PCWrite, 1'b0, {test_name, " PC waits"});
            @(posedge clk);
            #1;
//EXECUTE_2：发起 Store

            check_value(AddrSel, 1'b1, {test_name, " AddrSel"});
            check_value(MemRead, 1'b0, {test_name, " MemRead"});
            check_value(MemWriteMode, expected_mode, {test_name, " write mode"});
            check_value(RFWrite_n, 1'b1, {test_name, " RFWrite"});
//为了测试如果 Memory 一直没完成，FSM 能不能留在 EXECUTE_2？
            @(posedge clk);
            #1;

            check_value(MemWriteMode, expected_mode, {test_name, " waits for memory"});
            check_value(PCWrite, 1'b0, {test_name, " PC still waits"});
//Memory 已完成
            mem_ready = 1'b1;
            #1;

            check_value(PCWrite, 1'b1, {test_name, " PCWrite ready"});
            check_value(PCSel, PC_PLUS_4, {test_name, " PC+4"});
//返回 FETCH
            @(posedge clk);
            #1;

            mem_ready = 1'b0;
            #1;

            check_value(MemRead, 1'b1, {test_name, " return FETCH"});
        end
    endtask

    task automatic test_branch (
        input logic [2:0] branch_funct3,
        input logic [2:0] branch_flags,
        input logic [1:0] expected_pcsel,
        input logic [3:0] expected_aluop,
        input string test_name
    );
        begin
            opcode = OPCODE_BRANCH;
            funct3 = branch_funct3;
            funct7 = 7'b0;
            flags = branch_flags;

            enter_execute_1();

            check_value(ALUASel, ALU_A_RS1, {test_name, " ALU A"});
            check_value(ALUBSel, ALU_B_RS2, {test_name, " ALU B"});
            check_value(ALUOp, expected_aluop, {test_name, " compare"});
            check_value(RFWrite_n, 1'b1, {test_name, " RFWrite"});
            check_value(PCWrite, 1'b1, {test_name, " PCWrite"});
            check_value(PCSel, expected_pcsel, {test_name, " PCSel"});

            return_to_fetch();
        end
    endtask

    initial begin

        errors = 0;

        rst_n = 1'b0;
        mem_ready = 1'b0;
        opcode = 7'b0;
        funct3 = 3'b0;
        funct7 = 7'b0;
        flags = 3'b0;

        repeat (2)
            @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        #1;

        check_value(MemRead, 1'b1, "FETCH MemRead enabled");
        check_value(IRWrite, 1'b0, "FETCH IRWrite waits for memory");
        check_value(PCWrite, 1'b0, "FETCH PCWrite disabled");
        check_value(AddrSel, 1'b0, "FETCH address is PC");
        check_value(RFWrite_n, 1'b1, "FETCH RFWrite disabled");

        @(posedge clk);
        #1;

        check_value(MemRead, 1'b1, "FETCH stays while mem_ready=0");

        test_rtype(3'b000, 7'b0000000, ALU_ADD,  "ADD");
        test_rtype(3'b000, 7'b0100000, ALU_SUB,  "SUB");
        test_rtype(3'b001, 7'b0000000, ALU_SLL,  "SLL");
        test_rtype(3'b010, 7'b0000000, ALU_SLT,  "SLT");
        test_rtype(3'b011, 7'b0000000, ALU_SLTU, "SLTU");
        test_rtype(3'b100, 7'b0000000, ALU_XOR,  "XOR");
        test_rtype(3'b101, 7'b0000000, ALU_SRL,  "SRL");
        test_rtype(3'b101, 7'b0100000, ALU_SRA,  "SRA");
        test_rtype(3'b110, 7'b0000000, ALU_OR,   "OR");
        test_rtype(3'b111, 7'b0000000, ALU_AND,  "AND");

        opcode = OPCODE_OP_IMM;
        funct3 = 3'b000;
        funct7 = 7'b0;

        enter_execute_1();

        check_value(ALUASel, ALU_A_RS1, "ADDI ALU A");
        check_value(ALUBSel, ALU_B_IMM, "ADDI ALU B");
        check_value(ALUOp, ALU_ADD, "ADDI ALUOp");
        check_value(WBSel, WB_ALU, "ADDI WBSel");
        check_value(RFWrite_n, 1'b0, "ADDI RFWrite");
        check_value(PCWrite, 1'b1, "ADDI PCWrite");
        check_value(PCSel, PC_PLUS_4, "ADDI PC+4");

        return_to_fetch();

        test_itype(3'b001, 7'b0000000, ALU_SLL,  "SLLI");
        test_itype(3'b010, 7'b0000000, ALU_SLT,  "SLTI");
        test_itype(3'b011, 7'b0000000, ALU_SLTU, "SLTIU");
        test_itype(3'b100, 7'b0000000, ALU_XOR,  "XORI");
        test_itype(3'b101, 7'b0000000, ALU_SRL,  "SRLI");
        test_itype(3'b101, 7'b0100000, ALU_SRA,  "SRAI");
        test_itype(3'b110, 7'b0000000, ALU_OR,   "ORI");
        test_itype(3'b111, 7'b0000000, ALU_AND,  "ANDI");

        opcode = OPCODE_LUI;

        enter_execute_1();

        check_value(WBSel, WB_UIMM, "LUI WBSel");
        check_value(RFWrite_n, 1'b0, "LUI RFWrite");
        check_value(PCWrite, 1'b1, "LUI PCWrite");
        check_value(PCSel, PC_PLUS_4, "LUI PC+4");

        return_to_fetch();

        opcode = OPCODE_AUIPC;

        enter_execute_1();

        check_value(ALUASel, ALU_A_RS1, "AUIPC ALU A default");
        check_value(ALUBSel, ALU_B_RS2, "AUIPC ALU B default");
        check_value(ALUOp, ALU_ADD, "AUIPC uses ADD");
        check_value(WBSel, WB_PC_IMM, "AUIPC WBSel");
        check_value(RFWrite_n, 1'b0, "AUIPC RFWrite");
        check_value(PCWrite, 1'b1, "AUIPC PCWrite");

        return_to_fetch();

        opcode = OPCODE_LOAD;
        funct3 = 3'b010;

        enter_execute_1();

        check_value(ALUASel, ALU_A_RS1, "LW ALU A");
        check_value(ALUBSel, ALU_B_IMM, "LW ALU B");
        check_value(ALUOp, ALU_ADD, "LW address ADD");
        check_value(EAWrite, 1'b1, "LW EAWrite");
        check_value(PCWrite, 1'b0, "LW PC waits in EXECUTE_1");

        @(posedge clk);
        #1;

        check_value(AddrSel, 1'b1, "LW effective address");
        check_value(MemRead, 1'b1, "LW MemRead");
        check_value(WBSel, WB_MEMORY, "LW memory writeback");
        check_value(RFWrite_n, 1'b1, "LW RF waits");
        check_value(PCWrite, 1'b0, "LW PC waits");

        @(posedge clk);
        #1;

        check_value(MemRead, 1'b1, "LW stays in EXECUTE_2");

        mem_ready = 1'b1;
        #1;

        check_value(RFWrite_n, 1'b0, "LW RFWrite when ready");
        check_value(PCWrite, 1'b1, "LW PCWrite when ready");
        check_value(PCSel, PC_PLUS_4, "LW PC+4");

        @(posedge clk);
        #1;

        mem_ready = 1'b0;
        #1;

        test_store(3'b000, MEM_WRITE_BYTE, "SB");
        test_store(3'b001, MEM_WRITE_HALF, "SH");
        test_store(3'b010, MEM_WRITE_WORD, "SW");

        test_branch(3'b000, 3'b001, PC_PLUS_IMM, ALU_SUB, "BEQ taken");
        test_branch(3'b000, 3'b000, PC_PLUS_4,   ALU_SUB, "BEQ not taken");

        test_branch(3'b001, 3'b000, PC_PLUS_IMM, ALU_SUB, "BNE taken");
        test_branch(3'b001, 3'b001, PC_PLUS_4,   ALU_SUB, "BNE not taken");

        test_branch(3'b100, 3'b000, PC_PLUS_IMM, ALU_SLT,  "BLT taken");
        test_branch(3'b100, 3'b001, PC_PLUS_4,   ALU_SLT,  "BLT not taken");
        test_branch(3'b101, 3'b001, PC_PLUS_IMM, ALU_SLT,  "BGE taken");
        test_branch(3'b101, 3'b000, PC_PLUS_4,   ALU_SLT,  "BGE not taken");
        test_branch(3'b110, 3'b000, PC_PLUS_IMM, ALU_SLTU, "BLTU taken");
        test_branch(3'b110, 3'b001, PC_PLUS_4,   ALU_SLTU, "BLTU not taken");
        test_branch(3'b111, 3'b001, PC_PLUS_IMM, ALU_SLTU, "BGEU taken");
        test_branch(3'b111, 3'b000, PC_PLUS_4,   ALU_SLTU, "BGEU not taken");

        opcode = OPCODE_JAL;
        flags = 3'b0;

        enter_execute_1();

        check_value(WBSel, WB_PC4, "JAL writeback PC+4");
        check_value(RFWrite_n, 1'b0, "JAL RFWrite");
        check_value(PCWrite, 1'b1, "JAL PCWrite");
        check_value(PCSel, PC_PLUS_IMM, "JAL target PC+imm");

        return_to_fetch();

        opcode = OPCODE_JALR;
        funct3 = 3'b000;

        enter_execute_1();

        check_value(ALUASel, ALU_A_RS1, "JALR ALU A");
        check_value(ALUBSel, ALU_B_IMM, "JALR ALU B");
        check_value(ALUOp, ALU_ADD, "JALR rs1+imm");
        check_value(WBSel, WB_PC4, "JALR writeback PC+4");
        check_value(RFWrite_n, 1'b0, "JALR RFWrite");
        check_value(PCWrite, 1'b1, "JALR PCWrite");
        check_value(PCSel, PC_FROM_ALU, "JALR target ALU");

        return_to_fetch();

        opcode = OPCODE_SYSTEM;

        enter_execute_1();

        check_value(RFWrite_n, 1'b1, "SYSTEM RF disabled");
        check_value(MemRead, 1'b0, "SYSTEM memory disabled");
        check_value(MemWriteMode, MEM_WRITE_NONE, "SYSTEM write disabled");
        check_value(PCWrite, 1'b1, "SYSTEM advances PC");
        check_value(PCSel, PC_PLUS_4, "SYSTEM PC+4");

        return_to_fetch();

        opcode = OPCODE_FENCE;

        enter_execute_1();

        check_value(RFWrite_n, 1'b1, "FENCE RF disabled");
        check_value(MemRead, 1'b0, "FENCE memory disabled");
        check_value(MemWriteMode, MEM_WRITE_NONE, "FENCE write disabled");
        check_value(PCWrite, 1'b1, "FENCE advances PC");
        check_value(PCSel, PC_PLUS_4, "FENCE PC+4");

        return_to_fetch();

        if (errors == 0)
            $display("All FSM tests passed.");
        else
            $display("FSM test completed with %0d errors.", errors);

        $finish;

    end

endmodule