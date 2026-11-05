`timescale 1ns/1ps

module alu_tb;

    localparam BW = 32;

    logic [BW-1:0] in_a;
    logic [BW-1:0] in_b;
    logic [3:0]    opcode;

    logic [BW-1:0] out;
    logic [2:0]    flags;

    // DUT
    alu #(
        .BW(BW)
    ) dut (
        .in_a   (in_a),
        .in_b   (in_b),
        .opcode (opcode),
        .out     (out),
        .flags   (flags)
    );


    // Test task
 
    task automatic check_alu (
        input logic [BW-1:0] test_a,
        input logic [BW-1:0] test_b,
        input logic [3:0]    test_opcode,
        input logic [BW-1:0] expected_out,
        input logic [2:0]    expected_flags,
        input string         test_name
    );

        begin
            in_a   = test_a;
            in_b   = test_b;
            opcode = test_opcode;

            #10;

            if ((out !== expected_out) ||
                (flags !== expected_flags)) begin

                $error(
                    "%s FAILED: A=%h B=%h opcode=%b out=%h expected=%h flags=%b expected_flags=%b",
                    test_name,
                    in_a,
                    in_b,
                    opcode,
                    out,
                    expected_out,
                    flags,
                    expected_flags
                );

            end
            else begin

                $display(
                    "%s PASSED: out=%h flags=%b",
                    test_name,
                    out,
                    flags
                );

            end
        end

    endtask


    // Test cases

    initial begin

        // Initial values
        in_a   = '0;
        in_b   = '0;
        opcode = '0;

        #10;



        // ADD
        // 5 + 3 = 8
        // overflow=0, negative=0, zero=0
        check_alu(
            32'd5,
            32'd3,
            4'b0000,
            32'd8,
            3'b000,
            "ADD normal"
        );


        // 0 + 0 = 0
        // zero flag = 1
        check_alu(
            32'd0,
            32'd0,
            4'b0000,
            32'd0,
            3'b001,
            "ADD zero"
        );


        // 0x7fffffff + 1
        // largest positive + 1 -> negative result
        // signed overflow = 1
        check_alu(
            32'h7fffffff,
            32'h00000001,
            4'b0000,
            32'h80000000,
            3'b110,
            "ADD positive overflow"
        );

 
        // SUB
 

        // 8 - 3 = 5
        check_alu(
            32'd8,
            32'd3,
            4'b0001,
            32'd5,
            3'b000,
            "SUB normal"
        );


        // 3 - 3 = 0
        check_alu(
            32'd3,
            32'd3,
            4'b0001,
            32'd0,
            3'b001,
            "SUB zero"
        );


        // 3 - 5 = -2
        // result = FFFFFFFE
        // negative flag = 1
        check_alu(
            32'd3,
            32'd5,
            4'b0001,
            32'hfffffffe,
            3'b010,
            "SUB negative"
        );


        // 0x80000000 - 1
        // minimum signed number - 1 -> overflow
        check_alu(
            32'h80000000,
            32'h00000001,
            4'b0001,
            32'h7fffffff,
            3'b100,
            "SUB overflow"
        );


   
        // SLL
    

        // 1 << 4 = 16
        check_alu(
            32'h00000001,
            32'd4,
            4'b0010,
            32'h00000010,
            3'b000,
            "SLL"
        );


     
        // SLT - signed comparison
     

        // -1 < 1 => true
        check_alu(
            32'hffffffff,
            32'h00000001,
            4'b0100,
            32'h00000001,
            3'b000,
            "SLT signed true"
        );


        // 1 < -1 => false
        check_alu(
            32'h00000001,
            32'hffffffff,
            4'b0100,
            32'h00000000,
            3'b001,
            "SLT signed false"
        );


   
        // SLTU - unsigned comparison
     

        // unsigned FFFFFFFF > 1
        // therefore FFFFFFFF < 1 is false
        check_alu(
            32'hffffffff,
            32'h00000001,
            4'b0110,
            32'h00000000,
            3'b001,
            "SLTU unsigned"
        );


      
        // XOR
    

        check_alu(
            32'hf0f0f0f0,
            32'h0f0f0f0f,
            4'b1000,
            32'hffffffff,
            3'b010,
            "XOR"
        );


     
        // SRL - logical right shift
     

        // Logical shift fills with zeros
        check_alu(
            32'h80000000,
            32'd1,
            4'b1010,
            32'h40000000,
            3'b000,
            "SRL"
        );


       
        // SRA - arithmetic right shift
      
        // Arithmetic shift keeps sign bit
        check_alu(
            32'h80000000,
            32'd1,
            4'b1011,
            32'hc0000000,
            3'b010,
            "SRA"
        );


        // OR
      
        check_alu(
            32'hf0000000,
            32'h0f000000,
            4'b1100,
            32'hff000000,
            3'b010,
            "OR"
        );


      
        // AND
   
        check_alu(
            32'hff00ff00,
            32'h0f0f0f0f,
            4'b1110,
            32'h0f000f00,
            3'b000,
            "AND"
        );

        // PASS_B
        check_alu(
            32'h12345678,
            32'habcdef01,
            4'b1111,
            32'habcdef01,
            3'b010,
            "PASS_B"
        );

        // Undefined opcode
        // opcode 0011 is not defined
        // ALU should return zero
        check_alu(
            32'h12345678,
            32'habcdef01,
            4'b0011,
            32'h00000000,
            3'b001,
            "Undefined opcode"
        );

        $display("All ALU tests completed.");
     
        $finish;

    end

endmodule