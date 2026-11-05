module urbana_top #(
    parameter BW = 32
)(
    input logic CLK_100MHZ,
    input logic [15:0] SW,
    output logic [15:0] LED,
    output logic [7:0] D1_SEG,
    output logic [3:0] D1_AN,
    output logic [7:0] D0_SEG,
    output logic [3:0] D0_AN
);
                          
    logic [BW-1:0] alu_a;
    logic [BW-1:0] alu_b;
    logic [3:0]    alu_opcode;
    logic [BW-1:0] alu_out;
    logic [2:0]    alu_flags;
//SW[15:12]   no use there
//SW[11:8]    opcode
//SW[7:4]     operand B
//SW[3:0]     operand A
//4 bits
    assign alu_a      = SW[3:0];
    assign alu_b      = SW[7:4];
    assign alu_opcode = SW[11:8];

    alu #(
        .BW(BW)
    ) alu_inst (
        .in_a(alu_a),
        .in_b(alu_b),
        .opcode(alu_opcode),
        .out(alu_out),
        .flags(alu_flags)
    );           

// driver_left:
// B   0   A   0
/*original
    kw4281_driver driver_left (.rst_n(1'b1), .clk(CLK_100MHZ), 
                          .input_bcd({4'b0000, SW[15:12], 4'b0000, SW[11:8]}), .input_dots(4'b1010),
                          .an(D0_AN), .seg(D0_SEG));
    
    kw4281_driver driver_right (.rst_n(1'b1), .clk(CLK_100MHZ), 
                         .input_bcd({SW[7:4], 4'b0000, SW[3:0], 4'b000}), .input_dots(4'b1111),
                          .an(D1_AN), .seg(D1_SEG));
// driver_right:
// 0   result   0   opcode 
/*my code*/
    kw4281_driver driver_left (.rst_n(1'b1), .clk(CLK_100MHZ), 
                          .input_bcd({alu_b, 4'b0000, alu_a, 4'b0000}),
                          //.input_bcd(16'h1234),
                          .input_dots(4'b1111),
                          .an(D0_AN), .seg(D0_SEG));
    
    kw4281_driver driver_right (.rst_n(1'b1), .clk(CLK_100MHZ), 
                         .input_bcd({4'b0000, alu_out, 4'b0000, alu_opcode}),
                         //.input_bcd(16'h5678),
                         .input_dots(4'b1111),
                          .an(D1_AN), .seg(D1_SEG));
/**/                
endmodule
