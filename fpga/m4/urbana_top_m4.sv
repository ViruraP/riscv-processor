module urbana_top (
    input logic CLK_100MHZ,
    input logic [15:0] SW,
    output logic [15:0] LED,
    output logic [7:0] D1_SEG,
    output logic [3:0] D1_AN,
    output logic [7:0] D0_SEG,
    output logic [3:0] D0_AN
);
/*
LED	               实际状态	     对应信号	           代表什么
LED[0]	         常亮（视觉上）	cpu_clk	CPU        时钟正在运行
LED[1]	           常亮	         rst_n	CPU      已解除复位，处于运行状态
LED[2]	           闪烁	        read_en	CPU      不断向 Memory 发起读取请求
LED[3]	           熄灭	       \|write_en	     当前没有向 Memory 写入数据
LED[4]	          闪烁	        mem_ready	     Memory 不断完成请求并向 CPU 返回完成信号
LED[5]-LED[8]	  熄灭	       write_en[3:0]	当前没有启用任何 SRAM 字节写入通道
LED[9]-LED[15] 	 熄灭	       固定为 0	        未使用
*/
    logic rst_n;

    assign rst_n = SW[0];

    localparam integer CLK_DIV_COUNT = 337500;
    //450000：1min20s
    //

    logic [$clog2(CLK_DIV_COUNT)-1:0] clk_counter;
    logic cpu_clk;

    always_ff @(posedge CLK_100MHZ or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter <= '0;
            cpu_clk <= 1'b0;
        end
        else begin
            if (clk_counter == CLK_DIV_COUNT - 1) begin
                clk_counter <= '0;
                cpu_clk <= ~cpu_clk;
            end
            else begin
                clk_counter <= clk_counter + 1'b1;
            end
        end
    end

    logic [31:0] trap_pc;
    logic [31:0] addr;
    logic [31:0] data_out;
    logic [3:0]  write_en;
    logic        read_en;
    logic        mem_ready;

    riscv_top u_riscv_top (
        .clk       (cpu_clk),
        .rst_n     (rst_n),
        .trap_pc   (trap_pc),
        .addr      (addr),
        .data_out  (data_out),
        .write_en  (write_en),
        .read_en   (read_en),
        .mem_ready (mem_ready)
    );

    logic [31:0] last_written_data;

    always_ff @(posedge cpu_clk or negedge rst_n) begin
        if (!rst_n) begin
            last_written_data <= 32'b0;
        end
        else begin
            if (|write_en) begin
                last_written_data <= data_out;
            end
        end
    end

    always_comb begin
        LED = 16'b0;

        LED[0] = cpu_clk;
        LED[1] = rst_n;
        LED[2] = read_en;
        LED[3] = |write_en;
        LED[4] = mem_ready;

        LED[8:5] = write_en;
    end

    kw4281_driver driver_pc (
        .rst_n      (rst_n),
        .clk        (CLK_100MHZ),
        .input_bcd  (trap_pc[15:0]),
        .input_dots (4'b1111),
        .an         (D0_AN),
        .seg        (D0_SEG)
    );

    kw4281_driver driver_write_data (
        .rst_n      (rst_n),
        .clk        (CLK_100MHZ),
        .input_bcd  (last_written_data[15:0]),
        .input_dots (4'b1111),
        .an         (D1_AN),
        .seg        (D1_SEG)
    );

endmodule