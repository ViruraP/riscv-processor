`timescale 1ns / 1ps

module memory_tb;

    logic        clk;
    logic        rst_n;

    logic [31:0] addr;
    logic [31:0] data_in;
    logic [31:0] data_out;

    logic [3:0]  write_en;
    logic        read_en;

    logic        mem_ready;

    integer errors;


    memory DUT (
        .clk       (clk),
        .rst_n     (rst_n),
        .addr      (addr),
        .data_in   (data_in),
        .data_out  (data_out),
        .write_en  (write_en),
        .read_en   (read_en),
        .mem_ready (mem_ready)
    );


    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end


    task automatic write_memory (
        input logic [31:0] test_addr,
        input logic [31:0] test_data,
        input logic [3:0]  test_we
    );
        time start_time;
        time ready_time;

        begin
            addr     = test_addr;
            data_in  = test_data;
            write_en = test_we;
            read_en  = 1'b0;

            @(posedge clk);
            start_time = $time;

            $display(
                "WRITE start: time=%0t addr=%h data=%h write_en=%b",
                $time,
                test_addr,
                test_data,
                test_we
            );

            wait(mem_ready == 1'b1);

            ready_time = $time;

            $display(
                "WRITE ready: time=%0t latency=%0t",
                ready_time,
                ready_time - start_time
            );

            write_en = 4'b0000;

            wait(mem_ready == 1'b0);

            #1;
        end
    endtask


    task automatic read_memory (
        input logic [31:0] test_addr,
        input logic [31:0] expected_data,
        input string       test_name
    );
        time start_time;
        time ready_time;

        begin
            addr     = test_addr;
            write_en = 4'b0000;
            read_en  = 1'b1;

            @(posedge clk);
            start_time = $time;

            $display(
                "READ start: time=%0t addr=%h",
                $time,
                test_addr
            );

            wait(mem_ready == 1'b1);

            ready_time = $time;

            #1;

            $display(
                "READ ready: time=%0t latency=%0t data=%h",
                ready_time,
                ready_time - start_time,
                data_out
            );

            if (data_out !== expected_data) begin
                errors = errors + 1;

                $error(
                    "%s FAILED: expected=%h got=%h",
                    test_name,
                    expected_data,
                    data_out
                );
            end
            else begin
                $display(
                    "%s PASSED: data=%h",
                    test_name,
                    data_out
                );
            end

            read_en = 1'b0;

            wait(mem_ready == 1'b0);

            #1;
        end
    endtask


    initial begin

        errors = 0;

        rst_n    = 1'b0;
        addr     = 32'b0;
        data_in  = 32'b0;
        write_en = 4'b0000;
        read_en  = 1'b0;


        // Reset
        $display("===== RESET =====");

        #12;
        rst_n = 1'b1;

        #2;

        if (mem_ready !== 1'b0) begin
            errors = errors + 1;
            $error("RESET FAILED: mem_ready should be 0");
        end
        else begin
            $display("RESET PASSED");
        end


        // Test 1: Full word write
        $display("===== FULL WORD WRITE =====");

        write_memory(
            32'h0000_0010,
            32'h1234_5678,
            4'b1111
        );

        read_memory(
            32'h0000_0010,
            32'h1234_5678,
            "Full word write/read"
        );


        // Test 2: Byte 0
        $display("===== BYTE 0 WRITE =====");

        // 12345678 -> 123456AA
        write_memory(
            32'h0000_0010,
            32'h0000_00AA,
            4'b0001
        );

        read_memory(
            32'h0000_0010,
            32'h1234_56AA,
            "Byte 0 write"
        );


        // Test 3: Byte 1
        $display("===== BYTE 1 WRITE =====");

        // 123456AA -> 1234BBAA
        write_memory(
            32'h0000_0010,
            32'h0000_BB00,
            4'b0010
        );

        read_memory(
            32'h0000_0010,
            32'h1234_BBAA,
            "Byte 1 write"
        );


        // Test 4: Byte 2
        $display("===== BYTE 2 WRITE =====");

        // 1234BBAA -> 12CCBBAA
        write_memory(
            32'h0000_0010,
            32'h00CC_0000,
            4'b0100
        );

        read_memory(
            32'h0000_0010,
            32'h12CC_BBAA,
            "Byte 2 write"
        );


        // Test 5: Byte 3
        $display("===== BYTE 3 WRITE =====");

        // 12CCBBAA -> DDCCBBAA
        write_memory(
            32'h0000_0010,
            32'hDD00_0000,
            4'b1000
        );

        read_memory(
            32'h0000_0010,
            32'hDDCC_BBAA,
            "Byte 3 write"
        );


        // Test 6: Different address
        $display("===== DIFFERENT ADDRESS =====");

        write_memory(
            32'h0000_0014,
            32'hCAFE_BABE,
            4'b1111
        );

        read_memory(
            32'h0000_0014,
            32'hCAFE_BABE,
            "Second address"
        );

        // Check first address is unchanged
        read_memory(
            32'h0000_0010,
            32'hDDCC_BBAA,
            "Address isolation"
        );


        // Test 7: Idle
        $display("===== IDLE TEST =====");

        read_en  = 1'b0;
        write_en = 4'b0000;

        @(posedge clk);
        #1;

        if (mem_ready !== 1'b0) begin
            errors = errors + 1;
            $error("IDLE FAILED: mem_ready should remain 0");
        end
        else begin
            $display("IDLE PASSED: mem_ready = 0");
        end


        // Final result
        $display("===== MEMORY TEST FINISHED =====");

        if (errors == 0)
            $display("All memory tests passed.");
        else
            $display(
                "Memory test completed with %0d errors.",
                errors
            );

        #20;
        $finish;

    end

endmodule