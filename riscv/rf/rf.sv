module rf #(
    parameter int BW    = 32,
    parameter int DEPTH = 32
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic [BW-1:0]            data_in,
    output logic [BW-1:0]            data_out_1,
    output logic [BW-1:0]            data_out_2,
    input  logic [$clog2(DEPTH)-1:0] read_addr_1,
    input  logic [$clog2(DEPTH)-1:0] read_addr_2,
    input  logic [$clog2(DEPTH)-1:0] write_addr,
    input  logic                     write_en_n,
    input  logic                     chip_en
);

    // YOUR CODE
 logic [BW-1:0] regs [0:DEPTH-1];

    integer i;

    // Synchronous write, asynchronous active-low reset
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                regs[i] <= '0;
            end
        end
        else if (chip_en && !write_en_n) begin
            if (write_addr != '0 && write_addr < DEPTH)
                regs[write_addr] <= data_in;
        end
    end

    // Asynchronous read
    always_comb begin
        if (chip_en) begin
            if (read_addr_1 != '0 && read_addr_1 < DEPTH)
                data_out_1 = regs[read_addr_1];
                
            else
                data_out_1 = '0;

            if (read_addr_2 != '0 && read_addr_2 < DEPTH)
                data_out_2 = regs[read_addr_2];
                
            else
                data_out_2 = '0;
        end
        else begin
            data_out_1 = '0;
            data_out_2 = '0;
        end
    end

endmodule 
