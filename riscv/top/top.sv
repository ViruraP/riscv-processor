module riscv_top (
    input  logic        clk,
    input  logic        rst_n,

    // Expose some CPU/memory signals for testbench
    output logic [31:0] trap_pc,
    output logic [31:0] addr,
    output logic [31:0] data_out,
    output logic [3:0]  write_en,
    output logic        read_en,
    output logic        mem_ready
);

    // Data returned from memory to CPU
    logic [31:0] mem_data_out;


    // =========================================================
    // RISC-V CPU
    // =========================================================
    riscv u_riscv (
        .clk       (clk),
        .rst_n     (rst_n),

        .mem_ready (mem_ready),
        .data_in   (mem_data_out),

        .data_out  (data_out),
        .addr      (addr),
        .write_en  (write_en),
        .read_en   (read_en),

        .trap_pc   (trap_pc)
    );


    // =========================================================
    // Memory
    // =========================================================
    memory u_memory (
        .clk       (clk),
        .rst_n     (rst_n),

        .addr      (addr),
        .data_in   (data_out),
        .data_out  (mem_data_out),

        .write_en  (write_en),
        .read_en   (read_en),

        .mem_ready (mem_ready)
    );

endmodule