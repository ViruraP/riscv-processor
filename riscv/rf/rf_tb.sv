
`timescale 1ns/1ps

module rf_tb;

    localparam int BW = 32;
    localparam int DEPTH = 32;
    localparam int AW = $clog2(DEPTH);

    logic clk;
    logic rst_n;

    logic [BW-1:0] data_in;
    logic [BW-1:0] data_out_1;
    logic [BW-1:0] data_out_2;

    logic [AW-1:0] read_addr_1;
    logic [AW-1:0] read_addr_2;
    logic [AW-1:0] write_addr;

    logic write_en_n;
    logic chip_en;

    logic [BW-1:0] expected_mem [0:DEPTH-1];

    integer i;
    integer errors;
    integer passed;

    rf #(
        .BW(BW),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_out_1(data_out_1),
        .data_out_2(data_out_2),
        .read_addr_1(read_addr_1),
        .read_addr_2(read_addr_2),
        .write_addr(write_addr),
        .write_en_n(write_en_n),
        .chip_en(chip_en)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic check_outputs (
        input string test_name
    );
        logic [BW-1:0] expected_1;
        logic [BW-1:0] expected_2;

        begin
            #1;

            if (!chip_en) begin
                expected_1 = '0;
                expected_2 = '0;
            end
            else begin
                if (read_addr_1 == '0)
                    expected_1 = '0;
                else
                    expected_1 = expected_mem[read_addr_1];

                if (read_addr_2 == '0)
                    expected_2 = '0;
                else
                    expected_2 = expected_mem[read_addr_2];
            end

            if ((data_out_1 !== expected_1) ||
                (data_out_2 !== expected_2)) begin

                errors = errors + 1;

                $error(
                    "%s FAILED: read1=%0d out1=%h expected1=%h read2=%0d out2=%h expected2=%h",
                    test_name,
                    read_addr_1,
                    data_out_1,
                    expected_1,
                    read_addr_2,
                    data_out_2,
                    expected_2
                );
            end
            else begin
                passed = passed + 1;

                $display(
                    "%s PASSED: read1=%0d data1=%h read2=%0d data2=%h",
                    test_name,
                    read_addr_1,
                    data_out_1,
                    read_addr_2,
                    data_out_2
                );
            end
        end
    endtask

    task automatic write_register (
        input logic [AW-1:0] addr,
        input logic [BW-1:0] value
    );
        begin
            @(negedge clk);

            write_addr = addr;
            data_in = value;
            write_en_n = 1'b0;

            @(posedge clk);
            #1;

            if (chip_en && rst_n && addr != '0 && int'(addr) < DEPTH)
                expected_mem[addr] = value;

            write_en_n = 1'b1;

            $display(
                "WRITE: addr=%0d data=%h",
                addr,
                value
            );
        end
    endtask

    initial begin

        errors = 0;
        passed = 0;

        rst_n = 1'b0;
        chip_en = 1'b1;
        write_en_n = 1'b1;

        data_in = '0;
        read_addr_1 = '0;
        read_addr_2 = '0;
        write_addr = '0;

        for (i = 0; i < DEPTH; i = i + 1)
            expected_mem[i] = '0;

        #2;
        rst_n = 1'b1;

        read_addr_1 = 5'd1;
        read_addr_2 = 5'd2;
        check_outputs("Reset test");

        write_register(5'd1, 32'h12345678);

        read_addr_1 = 5'd1;
        read_addr_2 = 5'd0;
        check_outputs("Normal write and read");

        write_register(5'd2, 32'hABCDEF01);

        read_addr_1 = 5'd1;
        read_addr_2 = 5'd2;
        check_outputs("Two read ports");

        write_register(5'd0, 32'hFFFFFFFF);

        read_addr_1 = 5'd0;
        read_addr_2 = 5'd1;
        check_outputs("Register zero");

        chip_en = 1'b0;

        read_addr_1 = 5'd1;
        read_addr_2 = 5'd2;
        check_outputs("Standby");

        chip_en = 1'b1;

        @(negedge clk);

        write_addr = 5'd1;
        data_in = 32'hDEADBEEF;
        write_en_n = 1'b1;

        @(posedge clk);
        #1;

        read_addr_1 = 5'd1;
        read_addr_2 = 5'd2;
        check_outputs("Write disabled test");

        @(negedge clk);

        chip_en = 1'b0;
        write_en_n = 1'b0;
        write_addr = 5'd1;
        data_in = 32'hEEEEEEEE;

        @(posedge clk);
        #1;

        write_en_n = 1'b1;
        chip_en = 1'b1;

        read_addr_1 = 5'd1;
        read_addr_2 = 5'd2;
        check_outputs("Chip disabled write test");

        write_register(5'd31, 32'hA5A5A5A5);

        read_addr_1 = 5'd31;
        read_addr_2 = 5'd1;
        check_outputs("Last register test");

        @(negedge clk);

        read_addr_1 = 5'd1;
        read_addr_2 = 5'd2;

        check_outputs("Asynchronous read test");

        for (i = 0; i < 100; i = i + 1) begin

            @(negedge clk);

            write_addr = $urandom_range(0, DEPTH-1);
            data_in = $urandom;
            write_en_n = 1'b0;

            @(posedge clk);
            #1;

            if (write_addr != '0)
                expected_mem[write_addr] = data_in;

            $display(
                "RANDOM WRITE %0d: addr=%0d data=%h",
                i,
                write_addr,
                data_in
            );

            write_en_n = 1'b1;

            read_addr_1 = $urandom_range(0, DEPTH-1);
            read_addr_2 = $urandom_range(0, DEPTH-1);

            check_outputs("Random read");
        end

        for (i = 1; i < DEPTH; i = i + 1) begin
            write_register(
                AW'(i),
                BW'(i + 100)
            );
        end

        read_addr_1 = 5'd1;
        read_addr_2 = 5'd31;
        check_outputs("Before final reset");

        @(negedge clk);

        rst_n = 1'b0;

        for (i = 0; i < DEPTH; i = i + 1)
            expected_mem[i] = '0;

        #1;

        read_addr_1 = 5'd1;
        read_addr_2 = 5'd31;
        check_outputs("Asynchronous reset");

        rst_n = 1'b1;

        for (i = 0; i < DEPTH; i = i + 1) begin
            read_addr_1 = AW'(i);
            read_addr_2 = AW'(DEPTH-1-i);

            check_outputs("Reset all registers");
        end

        $display("RF tests passed: %0d", passed);
        $display("RF tests failed: %0d", errors);

        if (errors == 0)
            $display("All RF tests passed.");
        else
            $display("RF test completed with %0d errors.", errors);


        $finish;

    end

endmodule
