module riscv (
    input logic clk,
    input logic rst_n,
    
    // memory
    input logic mem_ready,
    input logic [31:0] data_in,
    output logic [31:0] data_out,
    output logic [31:0] addr,
    output logic [3:0] write_en,
    output logic read_en,
    output logic [31:0] trap_pc
);

    // Controller signals_FSM
    logic       pc_write;
    logic [1:0] pc_sel;
    logic       ir_write;
    logic       rf_write_n;
    logic       ea_write;
    logic       addr_sel;
    logic       alu_a_sel;
    logic [1:0] alu_b_sel;
    logic [3:0] alu_opcode;
    logic [2:0] wb_sel;
    logic       mem_read;
    logic [1:0] mem_write_mode;

    // Datapath registers(store values across clock cycles)
    logic [31:0] pc;
    logic [31:0] next_pc;
    logic [31:0] instruction_register;//cannot store
    logic [31:0] effective_address_register;
    
    // Decoder signals
    logic [6:0]  instruction_opcode;
    logic [4:0]  instruction_rd;
    logic [2:0]  instruction_funct3;
    logic [4:0]  instruction_rs1;
    logic [4:0]  instruction_rs2;
    logic [6:0]  instruction_funct7;
    logic [31:0] instruction_imm;
    logic [31:0] instruction_u_imm;

    // Register file signals
    logic [31:0] rf_data_1;
    logic [31:0] rf_data_2;
    logic [31:0] rf_write_data;

   // ALU signals
    logic [31:0] alu_in_a;
    logic [31:0] alu_in_b;
    logic [31:0] alu_result;
    logic [2:0]  alu_flags;

    // PC calculation signals
    logic [31:0] pc_plus_4;
    logic [31:0] pc_plus_imm;
    logic [31:0] jalr_address;

    // Memory alignment signals
    logic [31:0] load_shifted;
    logic [31:0] load_result;
    logic [31:0] store_data;
    logic [3:0]  store_write_en;

    // Local encoding definitions
    // ALU B input selector
    localparam logic [1:0] ALU_B_RS2  = 2'b00;
    localparam logic [1:0] ALU_B_IMM  = 2'b01;
    localparam logic [1:0] ALU_B_FOUR = 2'b10;

    // Write-back selector
    localparam logic [2:0] WB_ALU    = 3'b000;
    localparam logic [2:0] WB_MEMORY = 3'b001;
    localparam logic [2:0] WB_PC4    = 3'b010;
    localparam logic [2:0] WB_U_IMM  = 3'b011;
    localparam logic [2:0] WB_PC_IMM = 3'b100;

    // Next-PC selector
    localparam logic [1:0] PC_PLUS_4_SEL   = 2'b00;
    localparam logic [1:0] PC_PLUS_IMM_SEL = 2'b01;
    localparam logic [1:0] PC_FROM_ALU_SEL = 2'b10;

    // Memory write mode
    localparam logic [1:0] MEM_WRITE_NONE = 2'b00;
    localparam logic [1:0] MEM_WRITE_BYTE = 2'b01;
    localparam logic [1:0] MEM_WRITE_HALF = 2'b10;
    localparam logic [1:0] MEM_WRITE_WORD = 2'b11;

    // Program counter and datapath registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc                         <= 32'b0;
            instruction_register       <= 32'b0;
            effective_address_register <= 32'b0;
        end
        else begin
            if (pc_write)
                pc <= next_pc;
            if (ir_write)
                instruction_register <= data_in;//保存刚从内存取到的指令save instructions from memory
            if (ea_write)
                effective_address_register <= alu_result;//保存 Load/Store 地址save Load/Store address
        end
    end
    assign trap_pc = pc;//直接连接 PC 的输出线connect to putput
    assign pc_plus_4   = pc + 32'd4;
    assign pc_plus_imm = pc + instruction_imm;
    assign jalr_address = {
        alu_result[31:2],
        2'b00
    };

    // Next-PC multiplexer
    always_comb begin
        case (pc_sel)
            PC_PLUS_4_SEL:
                next_pc = pc_plus_4;
            PC_PLUS_IMM_SEL:
                next_pc = pc_plus_imm;
            PC_FROM_ALU_SEL:
                next_pc = jalr_address;
            default:
                next_pc = pc_plus_4;
        endcase
    end

    // Instruction decoder
    decoder u_decoder (
        .instruction (instruction_register),
        .opcode      (instruction_opcode),
        .rd          (instruction_rd),
        .funct3      (instruction_funct3),
        .rs1         (instruction_rs1),
        .rs2         (instruction_rs2),
        .funct7      (instruction_funct7),
        .imm         (instruction_imm),
        .u_imm       (instruction_u_imm)
    );

    // Controller
    fsm u_fsm (
        .clk          (clk),
        .rst_n        (rst_n),
        .mem_ready    (mem_ready),
        .opcode       (instruction_opcode),
        .funct3       (instruction_funct3),
        .funct7       (instruction_funct7),
        .flags        (alu_flags),
        .PCWrite      (pc_write),
        .PCSel        (pc_sel),
        .IRWrite      (ir_write),
        .RFWrite_n    (rf_write_n),
        .EAWrite      (ea_write),
        .AddrSel      (addr_sel),
        .ALUASel      (alu_a_sel),
        .ALUBSel      (alu_b_sel),
        .ALUOp        (alu_opcode),
        .WBSel        (wb_sel),
        .MemRead      (mem_read),
        .MemWriteMode (mem_write_mode)
    );

    // Register file
    rf #(
        .BW    (32),
        .DEPTH (32)
    ) u_rf (
        .clk         (clk),
        .rst_n       (rst_n),

        .data_in     (rf_write_data),
        .data_out_1  (rf_data_1),
        .data_out_2  (rf_data_2),

        .read_addr_1 (instruction_rs1),
        .read_addr_2 (instruction_rs2),
        .write_addr  (instruction_rd),

        .write_en_n  (rf_write_n),
        .chip_en     (1'b1)
    );

    // ALU input A multiplexer
    always_comb begin
        case (alu_a_sel)
            1'b0:
                alu_in_a = rf_data_1;
            1'b1:
                alu_in_a = pc;
            default:
                alu_in_a = rf_data_1;
        endcase
    end

    // ALU input B multiplexer
    always_comb begin
        case (alu_b_sel)
            ALU_B_RS2:
                alu_in_b = rf_data_2;
            ALU_B_IMM:
                alu_in_b = instruction_imm;
            ALU_B_FOUR:
                alu_in_b = 32'd4;
            default:
                alu_in_b = rf_data_2;
        endcase
    end

    // ALU
    alu #(
        .BW (32)
    ) u_alu (
        .in_a   (alu_in_a),
        .in_b   (alu_in_b),
        .opcode (alu_opcode),
        .out     (alu_result),
        .flags   (alu_flags)
    );

    // Load alignment
    always_comb begin
        load_shifted =
            data_in >> (8 * effective_address_register[1:0]);
        load_result = 32'b0;
        case (instruction_funct3)
            // LB
            3'b000: begin
                load_result = {
                    {24{load_shifted[7]}},
                    load_shifted[7:0]
                };
            end
            // LH
            3'b001: begin
                load_result = {
                    {16{load_shifted[15]}},
                    load_shifted[15:0]
                };
            end
            // LW
            3'b010: begin
                load_result = data_in;
            end
            // LBU
            3'b100: begin
                load_result = {
                    24'b0,
                    load_shifted[7:0]
                };
            end
            // LHU
            3'b101: begin
                load_result = {
                    16'b0,
                    load_shifted[15:0]
                };
            end
            default: begin
                load_result = 32'b0;
            end
        endcase
    end

    // Register-file write-back multiplexer
     always_comb begin
        case (wb_sel)
            WB_ALU:
                rf_write_data = alu_result;
            WB_MEMORY:
                rf_write_data = load_result;
            WB_PC4:
                rf_write_data = pc_plus_4;
            WB_U_IMM:
                rf_write_data = instruction_u_imm;
            WB_PC_IMM:
                rf_write_data = pc_plus_imm;
            default:
                rf_write_data = 32'b0;
        endcase
    end

    // Memory address multiplexer
     always_comb begin
        if (addr_sel)
            addr = effective_address_register;//Load/Store
        else
            addr = pc;
    end

    // Store-data alignment and byte-write enables
    //data_sram 一次选中一个 32 位字：.addra(addr[15:2]) 让上述四个地址都选中同一个存储位置。一个位置包含四个字节。
    //The data_sram selects one 32-bit word at a time: .addra(addr[15:2]) This ensures that all four addresses point to the same storage location. Each location contains four bytes.
    always_comb begin
        store_data     = 32'b0;
        store_write_en = 4'b0000;
        case (mem_write_mode)
            // SB
            MEM_WRITE_BYTE: begin
                store_data =
                    rf_data_2 <<
                    (8 * effective_address_register[1:0]);
                case (effective_address_register[1:0])
                    2'b00:
                        store_write_en = 4'b0001;
                    2'b01:
                        store_write_en = 4'b0010;
                    2'b10:
                        store_write_en = 4'b0100;
                    2'b11:
                        store_write_en = 4'b1000;
                    default:
                        store_write_en = 4'b0000;
                endcase
            end
            // SH
            MEM_WRITE_HALF: begin
                if (effective_address_register[1] == 1'b0) begin
                    store_data = {
                        16'b0,
                        rf_data_2[15:0]
                    };
                    store_write_en = 4'b0011;
                end
                else begin
                    store_data = {
                        rf_data_2[15:0],
                        16'b0
                    };
                    store_write_en = 4'b1100;
                end
            end
            // SW
            MEM_WRITE_WORD: begin
                store_data     = rf_data_2;
                store_write_en = 4'b1111;
            end
            default: begin
                store_data     = 32'b0;
                store_write_en = 4'b0000;
            end
        endcase
    end
    assign read_en  = mem_read;
    assign data_out = store_data;
    assign write_en = store_write_en;
endmodule

