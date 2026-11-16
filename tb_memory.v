`timescale 1ns/1ps
// Unit testbench for memory.v
// Checks: initial contents, block read alignment, latency,
// one-cycle ready pulse, and word writes.
module tb_memory;
    localparam LAT = 10;

    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    reg req = 0, we = 0;
    reg [31:0] addr = 0, wdata = 0;
    wire [127:0] rblock;
    wire ready;

    memory #(.LAT(LAT)) dut (.clk(clk), .rst(rst), .req(req), .we(we),
        .addr(addr), .wdata(wdata), .rblock(rblock), .ready(ready));

    integer errors = 0;
    integer lat;

    task check(input cond, input [8*48-1:0] msg);
        if (!cond) begin
            errors = errors + 1;
            $display("  FAIL: %0s", msg);
        end
    endtask

    // Issue one request, wait for ready, return the latency in cycles
    task do_req(input w, input [31:0] a, input [31:0] d);
    begin
        we = w; addr = a; wdata = d; req = 1;
        lat = 1;                 // count the first clock edge
        @(negedge clk);
        while (!ready) begin lat = lat + 1; @(negedge clk); end
        // ready must drop on the very next cycle (one-cycle pulse)
        @(negedge clk);
        check(!ready, "ready held high for more than one cycle");
        req = 0;
        @(negedge clk);
    end
    endtask

    initial begin
        repeat (2) @(negedge clk); rst = 0; @(negedge clk);

        $display("memory.v unit test (LAT = %0d)", LAT);

        // 1. Block read: words 4..7 for byte address 0x10
        do_req(0, 32'h10, 0);
        check(lat == LAT, "read latency != LAT");
        check(rblock == {32'd7, 32'd6, 32'd5, 32'd4}, "block at 0x10 wrong");

        // 2. Unaligned address in the same block returns the same block
        do_req(0, 32'h1C, 0);
        check(rblock == {32'd7, 32'd6, 32'd5, 32'd4}, "block at 0x1C misaligned");

        // 3. Last block in memory (words 4092..4095)
        do_req(0, 32'h3FF0, 0);
        check(rblock == {32'd4095, 32'd4094, 32'd4093, 32'd4092}, "last block wrong");

        // 4. Word write, then read back the block
        do_req(1, 32'h48, 32'hCAFEF00D);
        check(lat == LAT, "write latency != LAT");
        do_req(0, 32'h40, 0);
        check(rblock == {32'd19, 32'hCAFEF00D, 32'd17, 32'd16}, "word write not visible");

        // 5. Dropping req resets the counter: a fresh request still takes LAT
        we = 0; addr = 32'h80; req = 1;
        repeat (4) @(negedge clk);
        req = 0; @(negedge clk);
        do_req(0, 32'h80, 0);
        check(lat == LAT, "counter not reset when req dropped");

        if (errors == 0) $display("memory.v unit test: PASS");
        else             $display("memory.v unit test: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
