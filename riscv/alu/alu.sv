module alu #(
    parameter BW = 32
)(
    input  logic [BW-1:0] in_a,
    input  logic [BW-1:0] in_b,
    input  logic [3:0]    opcode,

    output logic [BW-1:0] out,
    output logic [2:0]    flags
);

    logic overflow;
    logic negative;
    logic zero;

always_comb begin

    // Default values
    out      = '0;
    overflow = 1'b0;

    case (opcode)

        4'b0000: begin                    // ADD
            out = in_a + in_b;

            overflow =
                (~(in_a[BW-1] ^ in_b[BW-1])) &
                 (in_a[BW-1] ^ out[BW-1]);//两个同号数相加，结果却变号。
        end

        4'b0001: begin                    // SUB
            out = in_a - in_b;

            overflow =
                 (in_a[BW-1] ^ in_b[BW-1]) &
                 (in_a[BW-1] ^ out[BW-1]);//A 和 B 异号，而且结果的符号和 A 不一样时，才会 overflow。
        end

        4'b0010:
            out = in_a << in_b[$clog2(BW)-1:0];   // SLL

        4'b0100:
            out = ($signed(in_a) < $signed(in_b)) ? 1 : 0;   // SLT

        4'b0110:
            out = (in_a < in_b) ? 1 : 0;   // SLTU

        4'b1000:
            out = in_a ^ in_b;   // XOR

        4'b1010:
            out = in_a >> in_b[$clog2(BW)-1:0];   // SRL

        4'b1011:
            out = $signed(in_a) >>> in_b[$clog2(BW)-1:0];   // SRA

        4'b1100:
            out = in_a | in_b;   // OR

        4'b1110:
            out = in_a & in_b;   // AND

        4'b1111:
            out = in_b;          // PASS_B

        default:
            out = '0;

    endcase

    negative = out[BW-1];
    zero     = (out == '0);

    flags = {overflow, negative, zero};

end
endmodule
