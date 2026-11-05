`timescale 1ns / 1ps

module decoder_tb;

    logic [31:0] instruction;

    logic [6:0]  opcode;
    logic [4:0]  rd;
    logic [2:0]  funct3;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [6:0]  funct7;
    logic [31:0] imm;
    logic [31:0] u_imm;

    integer errors;


    decoder dut (
        .instruction (instruction),
        .opcode      (opcode),
        .rd          (rd),
        .funct3      (funct3),
        .rs1         (rs1),
        .rs2         (rs2),
        .funct7      (funct7),
        .imm         (imm),
        .u_imm       (u_imm)
    );


    function automatic logic [31:0] encode_r (
        input logic [6:0] function_7,
        input logic [4:0] source_2,
        input logic [4:0] source_1,
        input logic [2:0] function_3,
        input logic [4:0] destination,
        input logic [6:0] operation_code
    );
        encode_r = {
            function_7,
            source_2,
            source_1,
            function_3,
            destination,
            operation_code
        };
    endfunction


    function automatic logic [31:0] encode_i (
        input logic signed [11:0] immediate,
        input logic        [4:0]  source_1,
        input logic        [2:0]  function_3,
        input logic        [4:0]  destination,
        input logic        [6:0]  operation_code
    );
        encode_i = {
            immediate,
            source_1,
            function_3,
            destination,
            operation_code
        };
    endfunction


    function automatic logic [31:0] encode_s (
        input logic signed [11:0] immediate,
        input logic        [4:0]  source_2,
        input logic        [4:0]  source_1,
        input logic        [2:0]  function_3,
        input logic        [6:0]  operation_code
    );
        encode_s = {
            immediate[11:5],
            source_2,
            source_1,
            function_3,
            immediate[4:0],
            operation_code
        };
    endfunction


    function automatic logic [31:0] encode_b (
        input logic signed [12:0] immediate,
        input logic        [4:0]  source_2,
        input logic        [4:0]  source_1,
        input logic        [2:0]  function_3
    );
        encode_b = {
            immediate[12],
            immediate[10:5],
            source_2,
            source_1,
            function_3,
            immediate[4:1],
            immediate[11],
            7'b1100011
        };
    endfunction


    function automatic logic [31:0] encode_u (
        input logic [19:0] upper_immediate,
        input logic [4:0]  destination,
        input logic [6:0]  operation_code
    );
        encode_u = {
            upper_immediate,
            destination,
            operation_code
        };
    endfunction


    function automatic logic [31:0] encode_j (
        input logic signed [20:0] immediate,
        input logic        [4:0]  destination
    );
        encode_j = {
            immediate[20],
            immediate[10:1],
            immediate[11],
            immediate[19:12],
            destination,
            7'b1101111
        };
    endfunction


    task automatic check_value (
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string       test_name
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


    initial begin

        errors = 0;
        instruction = 32'b0;

        #10;


        // R-type
        // SUB x5, x3, x7
        instruction = encode_r(
            7'b0100000,
            5'd7,
            5'd3,
            3'b000,
            5'd5,
            7'b0110011
        );

        #1;

        check_value(opcode, 7'b0110011, "SUB opcode");
        check_value(rd,     5'd5,       "SUB rd");
        check_value(rs1,    5'd3,       "SUB rs1");
        check_value(rs2,    5'd7,       "SUB rs2");
        check_value(funct3, 3'b000,     "SUB funct3");
        check_value(funct7, 7'b0100000, "SUB funct7");


        // I-type positive immediate
        // ADDI x5, x3, 12
        instruction = encode_i(
            12'sd12,
            5'd3,
            3'b000,
            5'd5,
            7'b0010011
        );

        #1;

        check_value(opcode, 7'b0010011, "ADDI positive opcode");
        check_value(rd,     5'd5,       "ADDI positive rd");
        check_value(rs1,    5'd3,       "ADDI positive rs1");
        check_value(funct3, 3'b000,     "ADDI positive funct3");
        check_value(imm,    32'd12,     "ADDI positive immediate");


        // I-type negative immediate
        // ADDI x5, x3, -4
        instruction = encode_i(
            -12'sd4,
            5'd3,
            3'b000,
            5'd5,
            7'b0010011
        );

        #1;

        check_value(imm, 32'hFFFFFFFC, "ADDI negative immediate");


        // S-type
        // SW x7, 12(x2)
        instruction = encode_s(
            12'sd12,
            5'd7,
            5'd2,
            3'b010,
            7'b0100011
        );

        #1;

        check_value(opcode, 7'b0100011, "SW opcode");
        check_value(rs1,    5'd2,       "SW rs1");
        check_value(rs2,    5'd7,       "SW rs2");
        check_value(funct3, 3'b010,     "SW funct3");
        check_value(imm,    32'd12,     "SW immediate");


        // S-type negative immediate
        // SW x7, -16(x2)
        instruction = encode_s(
            -12'sd16,
            5'd7,
            5'd2,
            3'b010,
            7'b0100011
        );

        #1;

        check_value(imm, 32'hFFFFFFF0, "SW negative immediate");


        // SB-type
        // BEQ x1, x2, -8
        instruction = encode_b(
            -13'sd8,
            5'd2,
            5'd1,
            3'b000
        );

        #1;

        check_value(opcode, 7'b1100011,  "BEQ opcode");
        check_value(rs1,    5'd1,        "BEQ rs1");
        check_value(rs2,    5'd2,        "BEQ rs2");
        check_value(funct3, 3'b000,      "BEQ funct3");
        check_value(imm,    32'hFFFFFFF8,"BEQ immediate");


        // SB-type positive immediate
        // BNE x4, x6, 16
        instruction = encode_b(
            13'sd16,
            5'd6,
            5'd4,
            3'b001
        );

        #1;

        check_value(opcode, 7'b1100011, "BNE opcode");
        check_value(rs1,    5'd4,       "BNE rs1");
        check_value(rs2,    5'd6,       "BNE rs2");
        check_value(funct3, 3'b001,     "BNE funct3");
        check_value(imm,    32'd16,     "BNE immediate");


        // U-type
        // LUI x10, 0x12345
        instruction = encode_u(
            20'h12345,
            5'd10,
            7'b0110111
        );

        #1;

        check_value(opcode, 7'b0110111,   "LUI opcode");
        check_value(rd,     5'd10,        "LUI rd");
        check_value(imm,    32'h12345000, "LUI immediate");
        check_value(u_imm,  32'h12345000, "LUI u_imm");


        // U-type AUIPC
        instruction = encode_u(
            20'hABCDE,
            5'd8,
            7'b0010111
        );

        #1;

        check_value(opcode, 7'b0010111,   "AUIPC opcode");
        check_value(rd,     5'd8,         "AUIPC rd");
        check_value(imm,    32'hABCDE000, "AUIPC immediate");
        check_value(u_imm,  32'hABCDE000, "AUIPC u_imm");


        // UJ-type positive immediate
        // JAL x1, 16
        instruction = encode_j(
            21'sd16,
            5'd1
        );

        #1;

        check_value(opcode, 7'b1101111, "JAL positive opcode");
        check_value(rd,     5'd1,       "JAL positive rd");
        check_value(imm,    32'd16,     "JAL positive immediate");


        // UJ-type negative immediate
        // JAL x1, -16
        instruction = encode_j(
            -21'sd16,
            5'd1
        );

        #1;

        check_value(opcode, 7'b1101111,  "JAL negative opcode");
        check_value(rd,     5'd1,        "JAL negative rd");
        check_value(imm,    32'hFFFFFFF0,"JAL negative immediate");


        if (errors == 0) begin
            $display("----------------------------------");
            $display("All decoder tests passed.");
            $display("----------------------------------");
        end
        else begin
            $display("----------------------------------");
            $display("%0d decoder tests failed.", errors);
            $display("----------------------------------");
        end

        $finish;

    end

endmodule