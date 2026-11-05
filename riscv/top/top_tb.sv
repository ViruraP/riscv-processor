`timescale 1ns/1ps

module top_tb;

    logic clk;
    logic rst_n;

    logic [31:0] trap_pc;
    logic [31:0] addr;
    logic [31:0] data_out;
    logic [3:0]  write_en;
    logic        read_en;
    logic        mem_ready;

    logic [31:0] last_written_data;
    logic [31:0] last_written_addr;

    integer errors;
    integer cycle_count;
    integer timeout_count;

    riscv_top dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .trap_pc   (trap_pc),
        .addr      (addr),
        .data_out  (data_out),
        .write_en  (write_en),
        .read_en   (read_en),
        .mem_ready (mem_ready)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_written_data <= 32'b0;
            last_written_addr <= 32'b0;
        end
        else begin
            if (|write_en) begin
                last_written_data <= data_out;
                last_written_addr <= addr;
            end
        end
    end

    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count = cycle_count + 1;

            $display(
                "cycle=%0d PC=%h addr=%h read_en=%b write_en=%b data_out=%h mem_ready=%b",
                cycle_count,
                trap_pc,
                addr,
                read_en,
                write_en,
                data_out,
                mem_ready
            );
        end
    end

    initial begin

        errors       = 0;
        cycle_count  = 0;
        timeout_count = 0;

        rst_n = 1'b0;

        repeat (5)
            @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        $display("CPU started.");

        while (
            trap_pc != 32'h000000C4 &&
            trap_pc != 32'h000000C8 &&
            timeout_count < 20000
        ) begin

            @(posedge clk);
            #1;

            timeout_count = timeout_count + 1;

        end

        if (
            trap_pc != 32'h000000C4 &&
            trap_pc != 32'h000000C8
        ) begin

            errors = errors + 1;

            $error(
                "Program timeout: final loop not reached. PC=%h",
                trap_pc
            );

        end

        else begin

            $display(
                "Program reached final loop: PC=%h",
                trap_pc
            );

            if (last_written_addr !== 32'h0000A000) begin

                errors = errors + 1;

                $error(
                    "Final write address FAILED: expected=0000A000 got=%h",
                    last_written_addr
                );

            end
            else begin

                $display(
                    "Final write address PASSED: %h",
                    last_written_addr
                );

            end

            if (last_written_data !== 32'h0000136F) begin

                errors = errors + 1;

                $error(
                    "Final written data FAILED: expected=0000136F got=%h",
                    last_written_data
                );

            end
            else begin

                $display(
                    "Final written data PASSED: %h",
                    last_written_data
                );

            end

            repeat (20)
                @(posedge clk);

        end

        if (errors == 0) begin

            $display("All complete-system tests passed.");

        end
        else begin

            $display(
                "Complete-system test finished with %0d errors.",
                errors
            );

        end

        $finish;

    end

endmodule