`timescale 1ns / 1ps

module riscv_tb;

    logic clk;
    logic rst_n;

    logic        mem_ready;
    logic [31:0] data_in;
    logic [31:0] data_out;
    logic [31:0] addr;
    logic [3:0]  write_en;
    logic        read_en;
    logic [31:0] trap_pc;

    logic [31:0] memory_array [0:255];
//模拟 256 个 32-bit Word，总容量 1024 Bytes。CPU 给出的地址是字节地址，但你的数组按 Word 索引
    logic request_accepted;//当前请求是否已经被接受，避免同一个请求被反复接受
    logic memory_busy;//模拟 Memory 是否正在处理请求
    logic [1:0] delay_count;//模拟 Memory 操作所需的等待周期

    integer errors;
    integer i;

    riscv dut (
        .clk       (clk),
        .rst_n     (rst_n),

        .mem_ready (mem_ready),
        .data_in   (data_in),

        .data_out  (data_out),
        .addr      (addr),
        .write_en  (write_en),
        .read_en   (read_en),

        .trap_pc   (trap_pc)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            mem_ready        <= 1'b0;
            data_in          <= 32'b0;
            request_accepted <= 1'b0;
            memory_busy      <= 1'b0;
            delay_count      <= 2'd0;
        end

        else begin

            mem_ready <= 1'b0;

            if (!read_en && write_en == 4'b0000)
                request_accepted <= 1'b0;

            if (!request_accepted &&
                !memory_busy &&
                (read_en || write_en != 4'b0000)) begin
//如果当前没有已接受的请求、Memory 不忙，并且 CPU 发出了读写请求，就开始处理一次新的 Memory 操作
                request_accepted <= 1'b1;
                memory_busy      <= 1'b1;
                delay_count      <= 2'd1;
            end

            else if (memory_busy) begin

                if (delay_count != 0) begin
                    delay_count <= delay_count - 1'b1;
                end

                else begin

                    memory_busy <= 1'b0;
                    mem_ready   <= 1'b1;

                    if (read_en)
                        data_in <= memory_array[addr[9:2]];
//把对应地址的 32-bit Word 返回 CPU
//CPU 的 addr 是 Byte Address（字节地址），而 memory_array 的索引是 Word Address（字地址）
//需要除4对于二进制地址，这相当于右移两位
                    if (write_en[0])
                        memory_array[addr[9:2]][7:0]
                            <= data_out[7:0];

                    if (write_en[1])
                        memory_array[addr[9:2]][15:8]
                            <= data_out[15:8];

                    if (write_en[2])
                        memory_array[addr[9:2]][23:16]
                            <= data_out[23:16];

                    if (write_en[3])
                        memory_array[addr[9:2]][31:24]
                            <= data_out[31:24];
                end
            end
        end
    end

    function automatic logic [31:0] encode_r (
        input logic [6:0] funct7_value,
        input logic [4:0] rs2_value,
        input logic [4:0] rs1_value,
        input logic [2:0] funct3_value,
        input logic [4:0] rd_value
    );

        encode_r = {
            funct7_value,
            rs2_value,
            rs1_value,
            funct3_value,
            rd_value,
            7'b0110011
        };
    endfunction

    function automatic logic [31:0] encode_i (
        input logic [11:0] immediate,
        input logic [4:0]  rs1_value,
        input logic [2:0]  funct3_value,
        input logic [4:0]  rd_value,
        input logic [6:0]  opcode_value
    );

        encode_i = {
            immediate,
            rs1_value,
            funct3_value,
            rd_value,
            opcode_value
        };

    endfunction

    function automatic logic [31:0] encode_s (
        input logic [11:0] immediate,
        input logic [4:0]  rs2_value,
        input logic [4:0]  rs1_value,
        input logic [2:0]  funct3_value
    );

        encode_s = {
            immediate[11:5],
            rs2_value,
            rs1_value,
            funct3_value,
            immediate[4:0],
            7'b0100011
        };

    endfunction

    function automatic logic [31:0] encode_b (
        input logic [12:0] immediate,
        input logic [4:0]  rs2_value,
        input logic [4:0]  rs1_value,
        input logic [2:0]  funct3_value
    );

        encode_b = {
            immediate[12],
            immediate[10:5],
            rs2_value,
            rs1_value,
            funct3_value,
            immediate[4:1],
            immediate[11],
            7'b1100011
        };

    endfunction

    function automatic logic [31:0] encode_u (
        input logic [19:0] upper_immediate,
        input logic [4:0]  rd_value,
        input logic [6:0]  opcode_value
    );

        encode_u = {
            upper_immediate,
            rd_value,
            opcode_value
        };

    endfunction

    function automatic logic [31:0] encode_j (
        input logic [20:0] immediate,
        input logic [4:0]  rd_value
    );

        encode_j = {
            immediate[20],
            immediate[10:1],
            immediate[11],
            immediate[19:12],
            rd_value,
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

                $error(
                    "%s FAILED: expected=%h got=%h",
                    test_name,
                    expected,
                    actual
                );

                errors = errors + 1;
            end

            else begin
                $display("%s PASSED", test_name);
            end

        end

    endtask

//每条独立测试前初始化 CPU
    task automatic prepare_test (
        input logic [31:0] instruction
    );

        begin

            rst_n = 1'b0;

            repeat (2)
                @(posedge clk);

            for (i = 0; i < 256; i = i + 1)
                memory_array[i] = 32'b0;

            memory_array[0] = instruction;

            @(negedge clk);
            rst_n = 1'b1;

            #1;
        end

    endtask
//等待指令执行完成
    task automatic wait_for_pc (
        input logic [31:0] expected_pc,
        input string test_name
    );

        integer cycles;

        begin

            cycles = 0;
//每经过一个时钟周期就检查 PC 是否到达预期地址，最多等待 100 个周期
            while (trap_pc !== expected_pc && cycles < 100) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end

            if (trap_pc !== expected_pc) begin

                $error(
                    "%s FAILED: expected PC=%h got PC=%h",
                    test_name,
                    expected_pc,
                    trap_pc
                );

                errors = errors + 1;
            end

        end

    endtask

    task automatic test_r_type (
        input logic [6:0]  funct7_value,
        input logic [2:0]  funct3_value,
        input logic [31:0] operand_a,
        input logic [31:0] operand_b,
        input logic [31:0] expected,
        input string       test_name
    );

        begin

            prepare_test(
                encode_r(
                    funct7_value,
                    5'd2,
                    5'd1,
                    funct3_value,
                    5'd3
                )
            );

            dut.u_rf.regs[1] = operand_a;
            dut.u_rf.regs[2] = operand_b;

            wait_for_pc(
                32'd4,
                test_name
            );

            check_value(
                dut.u_rf.regs[3],
                expected,
                test_name
            );

        end

    endtask

    task automatic test_i_type (
        input logic [11:0] immediate,
        input logic [2:0]  funct3_value,
        input logic [31:0] operand_a,
        input logic [31:0] expected,
        input string       test_name
    );

        begin

            prepare_test(
                encode_i(
                    immediate,
                    5'd1,
                    funct3_value,
                    5'd3,
                    7'b0010011
                )
            );

            dut.u_rf.regs[1] = operand_a;

            wait_for_pc(
                32'd4,
                test_name
            );

            check_value(
                dut.u_rf.regs[3],
                expected,
                test_name
            );

        end

    endtask

    task automatic test_load (
        input logic [2:0]  funct3_value,
        input logic [11:0] offset,
        input logic [31:0] expected,
        input string       test_name
    );

        begin

            prepare_test(
                encode_i(
                    offset,
                    5'd1,
                    funct3_value,
                    5'd3,
                    7'b0000011
                )
            );

            dut.u_rf.regs[1] = 32'd64;

            memory_array[16] = 32'h80FF7F01;
//它包含最高位为 1 的字节和半字，可以同时检查 Sign Extension（符号扩展） 和 Zero Extension（零扩展）
            wait_for_pc(
                32'd4,
                test_name
            );

            check_value(
                dut.u_rf.regs[3],
                expected,
                test_name
            );

        end

    endtask

    task automatic test_store (
        input logic [2:0]  funct3_value,
        input logic [11:0] offset,
        input logic [31:0] initial_memory,
        input logic [31:0] store_value,
        input logic [31:0] expected_memory,
        input string       test_name
    );

        begin

            prepare_test(
                encode_s(
                    offset,
                    5'd2,
                    5'd1,
                    funct3_value
                )
            );

            dut.u_rf.regs[1] = 32'd64;
            dut.u_rf.regs[2] = store_value;

            memory_array[16] = initial_memory;

            wait_for_pc(
                32'd4,
                test_name
            );

            check_value(
                memory_array[16],
                expected_memory,
                test_name
            );

        end

    endtask

    task automatic test_branch (
        input logic [2:0]  funct3_value,
        input logic [31:0] operand_a,
        input logic [31:0] operand_b,
        input logic [31:0] expected_pc,
        input string       test_name
    );

        begin

            prepare_test(
                encode_b(
                    13'd8,
                    5'd2,
                    5'd1,
                    funct3_value
                )
            );

            dut.u_rf.regs[1] = operand_a;
            dut.u_rf.regs[2] = operand_b;

            wait_for_pc(
                expected_pc,
                test_name
            );

            check_value(
                trap_pc,
                expected_pc,
                test_name
            );

        end

    endtask

    task automatic test_signed_unsigned_boundaries;
        begin
            $display("Signed/unsigned comparison boundary tests");

            test_r_type(7'b0000000, 3'b010,
                        32'hFFFFFFFF, 32'h00000001, 32'd1,
                        "SLT signed -1 < 1");
            test_r_type(7'b0000000, 3'b011,
                        32'hFFFFFFFF, 32'h00000001, 32'd0,
                        "SLTU unsigned max < 1 is false");
            test_r_type(7'b0000000, 3'b010,
                        32'h80000000, 32'h7FFFFFFF, 32'd1,
                        "SLT signed minimum < maximum");
            test_r_type(7'b0000000, 3'b011,
                        32'h80000000, 32'h7FFFFFFF, 32'd0,
                        "SLTU 0x80000000 < 0x7FFFFFFF is false");
            test_r_type(7'b0000000, 3'b010,
                        32'h00000000, 32'hFFFFFFFF, 32'd0,
                        "SLT signed 0 < -1 is false");
            test_r_type(7'b0000000, 3'b011,
                        32'h00000000, 32'hFFFFFFFF, 32'd1,
                        "SLTU unsigned 0 < max");
        end
    endtask

    task automatic test_jal_negative_offset;
        begin
            $display("JAL negative offset and nonzero PC test");

            prepare_test(encode_j(21'd16, 5'd0));
            memory_array[4] = encode_j(21'h1FFFF8, 5'd5);

            wait_for_pc(32'd16, "JAL jump to nonzero PC");
            wait_for_pc(32'd8, "JAL backward by 8 bytes");
            check_value(dut.u_rf.regs[5], 32'd20,
                        "JAL negative offset link address");
        end
    endtask

    task automatic test_jalr_nonzero_pc;
        begin
            $display("JALR from nonzero PC test");

            prepare_test(encode_j(21'd16, 5'd0));
            memory_array[4] = encode_i(12'd4, 5'd1, 3'b000,
                                        5'd5, 7'b1100111);
            dut.u_rf.regs[1] = 32'd29;

            wait_for_pc(32'd16, "Setup nonzero PC for JALR");
            wait_for_pc(32'd32, "JALR target (29+4)&~3 = 32");
            check_value(dut.u_rf.regs[5], 32'd20,
                        "JALR link stores source PC+4");
        end
    endtask

    task automatic test_instruction_sequence;
        begin
            $display("Consecutive ADDI/ADD/SW/LW integration test");

            prepare_test(encode_i(12'd10, 5'd0, 3'b000,
                                  5'd1, 7'b0010011));
            memory_array[1] = encode_i(12'd20, 5'd0, 3'b000,
                                       5'd2, 7'b0010011);
            memory_array[2] = encode_r(7'b0000000, 5'd2, 5'd1,
                                       3'b000, 5'd3);
            memory_array[3] = encode_s(12'd64, 5'd3, 5'd0,
                                       3'b010);
            memory_array[4] = encode_i(12'd64, 5'd0, 3'b010,
                                       5'd4, 7'b0000011);
            memory_array[16] = 32'hA5A5A5A5;

            wait_for_pc(32'd20, "Five instruction sequence completed");
            check_value(dut.u_rf.regs[1], 32'd10, "Sequence x1");
            check_value(dut.u_rf.regs[2], 32'd20, "Sequence x2");
            check_value(dut.u_rf.regs[3], 32'd30, "Sequence x3");
            check_value(memory_array[16], 32'd30, "Sequence SW result");
            check_value(dut.u_rf.regs[4], 32'd30, "Sequence LW result");
        end
    endtask

    initial begin

        errors = 0;
        rst_n  = 1'b0;

        #1;

        $display("R-type tests");

        test_r_type(
            7'b0000000,
            3'b000,
            32'd10,
            32'd3,
            32'd13,
            "ADD"
        );

        test_r_type(
            7'b0100000,
            3'b000,
            32'd10,
            32'd3,
            32'd7,
            "SUB"
        );

        test_r_type(
            7'b0000000,
            3'b001,
            32'd3,
            32'd2,
            32'd12,
            "SLL"
        );

        test_r_type(
            7'b0000000,
            3'b010,
            32'hFFFFFFFF,
            32'd1,
            32'd1,
            "SLT"
        );

        test_r_type(
            7'b0000000,
            3'b011,
            32'd1,
            32'd2,
            32'd1,
            "SLTU"
        );

        test_r_type(
            7'b0000000,
            3'b100,
            32'h000000A5,
            32'h0000003C,
            32'h00000099,
            "XOR"
        );

        test_r_type(
            7'b0000000,
            3'b101,
            32'h80000000,
            32'd1,
            32'h40000000,
            "SRL"
        );

        test_r_type(
            7'b0100000,
            3'b101,
            32'h80000000,
            32'd1,
            32'hC0000000,
            "SRA"
        );

        test_r_type(
            7'b0000000,
            3'b110,
            32'h000000A0,
            32'h0000000F,
            32'h000000AF,
            "OR"
        );

        test_r_type(
            7'b0000000,
            3'b111,
            32'h000000AF,
            32'h0000000F,
            32'h0000000F,
            "AND"
        );

        $display("I-type ALU tests");

        test_i_type(
            12'd5,
            3'b000,
            32'd10,
            32'd15,
            "ADDI"
        );

        test_i_type(
            12'hFFF,
            3'b000,
            32'd10,
            32'd9,
            "ADDI negative immediate"
        );

        test_i_type(
            12'd2,
            3'b001,
            32'd3,
            32'd12,
            "SLLI"
        );

        test_i_type(
            12'd1,
            3'b010,
            32'hFFFFFFFF,
            32'd1,
            "SLTI"
        );

        test_i_type(
            12'hFFF,
            3'b011,
            32'd1,
            32'd1,
            "SLTIU"
        );

        test_i_type(
            12'h00F,
            3'b100,
            32'h000000A5,
            32'h000000AA,
            "XORI"
        );

        test_i_type(
            12'd2,
            3'b101,
            32'h80000000,
            32'h20000000,
            "SRLI"
        );

        test_i_type(
            12'h402,
            3'b101,
            32'h80000000,
            32'hE0000000,
            "SRAI"
        );

        test_i_type(
            12'h00F,
            3'b110,
            32'h000000A0,
            32'h000000AF,
            "ORI"
        );

        test_i_type(
            12'h00F,
            3'b111,
            32'h000000AF,
            32'h0000000F,
            "ANDI"
        );

        $display("x0 test");

        prepare_test(
            encode_i(
                12'd5,
                5'd0,
                3'b000,
                5'd0,
                7'b0010011
            )
        );

        wait_for_pc(
            32'd4,
            "x0"
        );

        check_value(
            dut.u_rf.regs[0],
            32'd0,
            "x0 remains zero"
        );

        $display("U-type tests");

        prepare_test(
            encode_u(
                20'h12345,
                5'd3,
                7'b0110111
            )
        );

        wait_for_pc(
            32'd4,
            "LUI"
        );

        check_value(
            dut.u_rf.regs[3],
            32'h12345000,
            "LUI"
        );

        prepare_test(
            encode_u(
                20'h00001,
                5'd3,
                7'b0010111
            )
        );

        wait_for_pc(
            32'd4,
            "AUIPC"
        );

        check_value(
            dut.u_rf.regs[3],
            32'h00001000,
            "AUIPC"
        );

        $display("Load tests");

        test_load(
            3'b000,
            12'd3,
            32'hFFFFFF80,
            "LB"
        );

        test_load(
            3'b001,
            12'd2,
            32'hFFFF80FF,
            "LH"
        );

        test_load(
            3'b010,
            12'd0,
            32'h80FF7F01,
            "LW"
        );

        test_load(
            3'b100,
            12'd3,
            32'h00000080,
            "LBU"
        );

        test_load(
            3'b101,
            12'd2,
            32'h000080FF,
            "LHU"
        );

        $display("Store tests");

        test_store(
            3'b000,
            12'd1,
            32'hAABBCCDD,
            32'h11223344,
            32'hAABB44DD,
            "SB"
        );

        test_store(
            3'b001,
            12'd2,
            32'hAABBCCDD,
            32'h11223344,
            32'h3344CCDD,
            "SH"
        );

        test_store(
            3'b010,
            12'd0,
            32'hAABBCCDD,
            32'h11223344,
            32'h11223344,
            "SW"
        );

        $display("Branch tests");

        test_branch(
            3'b000,
            32'd5,
            32'd5,
            32'd8,
            "BEQ taken"
        );

        test_branch(
            3'b000,
            32'd5,
            32'd6,
            32'd4,
            "BEQ not taken"
        );

        test_branch(
            3'b001,
            32'd5,
            32'd6,
            32'd8,
            "BNE taken"
        );

        test_branch(
            3'b001,
            32'd5,
            32'd5,
            32'd4,
            "BNE not taken"
        );

        test_branch(
            3'b100,
            32'hFFFFFFFF,
            32'd1,
            32'd8,
            "BLT taken"
        );

        test_branch(
            3'b100,
            32'd2,
            32'd1,
            32'd4,
            "BLT not taken"
        );

        test_branch(
            3'b101,
            32'd2,
            32'd1,
            32'd8,
            "BGE taken"
        );

        test_branch(
            3'b101,
            32'd1,
            32'd2,
            32'd4,
            "BGE not taken"
        );

        test_branch(
            3'b110,
            32'd1,
            32'd2,
            32'd8,
            "BLTU taken"
        );

        test_branch(
            3'b110,
            32'hFFFFFFFF,
            32'd1,
            32'd4,
            "BLTU not taken"
        );

        test_branch(
            3'b111,
            32'd2,
            32'd1,
            32'd8,
            "BGEU taken"
        );

        test_branch(
            3'b111,
            32'd1,
            32'd2,
            32'd4,
            "BGEU not taken"
        );

        $display("Jump tests");

        prepare_test(
            encode_j(
                21'd8,
                5'd5
            )
        );

        wait_for_pc(
            32'd8,
            "JAL"
        );

        check_value(
            dut.u_rf.regs[5],
            32'd4,
            "JAL link register"
        );

        prepare_test(
            encode_i(
                12'd4,
                5'd1,
                3'b000,
                5'd5,
                7'b1100111
            )
        );

        dut.u_rf.regs[1] = 32'd13;

        wait_for_pc(
            32'd16,
            "JALR alignment"
        );

        check_value(
            trap_pc,
            32'd16,
            "JALR aligned PC"
        );

        check_value(
            dut.u_rf.regs[5],
            32'd4,
            "JALR link register"
        );

        $display("Ignored instruction tests");

        prepare_test(
            32'h00000073
        );

        wait_for_pc(
            32'd4,
            "SYSTEM ignored"
        );

        check_value(
            trap_pc,
            32'd4,
            "SYSTEM PC+4"
        );

        prepare_test(
            32'h0000000F
        );

        wait_for_pc(
            32'd4,
            "FENCE ignored"
        );

        check_value(
            trap_pc,
            32'd4,
            "FENCE PC+4"
        );

        test_signed_unsigned_boundaries();
        test_jal_negative_offset();
        test_jalr_nonzero_pc();
        test_instruction_sequence();

        if (errors == 0)
            $display("All RISC-V processor tests passed.");
        else
            $error("RISC-V processor tests completed with %0d errors.", errors);

        $finish;

    end

endmodule