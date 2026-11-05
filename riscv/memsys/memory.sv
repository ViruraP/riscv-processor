module memory (
    input  logic        clk,
    input  logic        rst_n,

    input  logic [31:0] addr,
    input  logic [31:0] data_in,
    output logic [31:0] data_out,

    input  logic [3:0]  write_en,
    input  logic        read_en,

    output logic        mem_ready
);

/*
CPU signal      SRAM signal
---------------------------
clk          →  clka
read_en/
write_en     →  ena
write_en     →  wea
addr[15:2]   →  addra
data_in      →  dina
douta        →  data_out
*/

    // SRAM internal signals
    logic        sram_en;
    logic [31:0] sram_dout;

    // Memory request exists when:
    // 1. read_en = 1
    // 2. or any write_en bit is 1
    assign sram_en = read_en || (|write_en);

    // Generated SRAM IP
    data_sram u_data_sram (
        .clka  (clk),
        .ena   (sram_en),
        .wea   (write_en),
        .addra (addr[15:2]),
        .dina  (data_in),
        .douta (sram_dout)
    );

    assign data_out = sram_dout;
    // State machine
    typedef enum logic [1:0] {
        IDLE,//IDLE 是空闲状态
        WAIT_MEM,
        READY
    } state_t;

    state_t state;


    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            state     <= IDLE;
            mem_ready <= 1'b0;
        end

        else begin

            case (state)

                // Wait for a new memory request
                IDLE: begin
                    mem_ready <= 1'b0;

                    if (read_en || (|write_en))//CPU 发起了 memory request
                        state <= WAIT_MEM;
                end


                // Wait one cycle for SRAM operation
                //adds one clock cycle to the read latency
                //启用了 Primitive Output Register 后，典型读取延迟为 2 个时钟周期
                WAIT_MEM: begin
                    mem_ready <= 1'b0;//故意等一个 clock cycle
                    state     <= READY;
                end


                // Operation is finished
                READY: begin
                    mem_ready <= 1'b1;
                    state     <= IDLE;
                end


                default: begin
                    state     <= IDLE;
                    mem_ready <= 1'b0;
                end

            endcase
        end
    end

/*
时钟沿	FSM 执行的分支	SRAM 行为	时钟沿后 mem_ready
E1      	IDLE	 采样地址，开始读取	      0
E2	      WAIT_MEM	 输出寄存器捕获数据	      0
E3	      READY	SRAM  数据已经稳定	          1
E4	      IDLE	     CPU 采样数据并完成写回	  0
*/
endmodule
