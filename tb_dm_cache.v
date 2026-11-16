`timescale 1ns/1ps
// Unit testbench for dm_cache.v (connected to memory.v)
// Checks: read miss/hit, block refill, conflict eviction,
// write-through on hit, and no-write-allocate on miss.
module tb_dm_cache;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    reg req = 0, we = 0;
    reg [31:0] addr = 0, wdata = 0;

    wire done, mreq, mwe, mrdy;
    wire [31:0] rdata, hits, misses, maddr, mwdata;
    wire [127:0] mblk;

    dm_cache dut (.clk(clk), .rst(rst), .cpu_req(req), .cpu_we(we),
        .cpu_addr(addr), .cpu_wdata(wdata), .cpu_done(done), .cpu_rdata(rdata),
        .mem_req(mreq), .mem_we(mwe), .mem_addr(maddr), .mem_wdata(mwdata),
        .mem_rblock(mblk), .mem_ready(mrdy), .hits(hits), .misses(misses));
    memory mem (.clk(clk), .rst(rst), .req(mreq), .we(mwe), .addr(maddr),
        .wdata(mwdata), .rblock(mblk), .ready(mrdy));

    integer errors = 0;
    reg [31:0] rd, h0, m0;

    task check(input cond, input [8*48-1:0] msg);
        if (!cond) begin
            errors = errors + 1;
            $display("  FAIL: %0s", msg);
        end
    endtask

    task access(input w, input [31:0] a, input [31:0] d);
    begin
        h0 = hits; m0 = misses;
        we = w; addr = a; wdata = d; req = 1;
        @(negedge clk);
        while (!done) @(negedge clk);
        rd = rdata;
        req = 0;
        @(negedge clk);
    end
    endtask

    wire was_hit  = (hits == h0 + 1) && (misses == m0);
    wire was_miss = (misses == m0 + 1) && (hits == h0);

    initial begin
        repeat (3) @(negedge clk); rst = 0; @(negedge clk);
        $display("dm_cache.v unit test");

        // 1. Cold read miss, data comes from memory (word i = i)
        access(0, 32'h100, 0);
        check(was_miss, "cold read was not a miss");
        check(rd == 32'd64, "wrong data on read miss");

        // 2. Same word again -> hit
        access(0, 32'h100, 0);
        check(was_hit, "repeat read was not a hit");
        check(rd == 32'd64, "wrong data on read hit");

        // 3. Other word in the same block -> hit (block was refilled)
        access(0, 32'h10C, 0);
        check(was_hit, "same-block read was not a hit");
        check(rd == 32'd67, "wrong word from refilled block");

        // 4. Conflict: 0x500 maps to the same index as 0x100 -> evicts it
        access(0, 32'h500, 0);
        check(was_miss, "conflicting read was not a miss");
        check(rd == 32'd320, "wrong data for conflicting block");
        access(0, 32'h100, 0);
        check(was_miss, "evicted block still hit");

        // 5. Write hit: cache and memory both updated (write-through)
        access(1, 32'h104, 32'hA5A5A5A5);
        check(was_hit, "write to cached block was not a hit");
        access(0, 32'h104, 0);
        check(was_hit && rd == 32'hA5A5A5A5, "write hit not seen in cache");
        access(0, 32'h504, 0);       // evict 0x100's block
        access(0, 32'h104, 0);       // refill from memory
        check(was_miss && rd == 32'hA5A5A5A5, "write-through did not reach memory");

        // 6. Write miss: memory updated, block NOT allocated
        access(1, 32'h208, 32'h5A5A5A5A);
        check(was_miss, "write to uncached block was not a miss");
        access(0, 32'h208, 0);
        check(was_miss, "write miss allocated a line (should not)");
        check(rd == 32'h5A5A5A5A, "write miss did not reach memory");

        // 7. Reset clears all valid bits and counters
        rst = 1; repeat (2) @(negedge clk); rst = 0; @(negedge clk);
        check(hits == 0 && misses == 0, "counters not cleared by reset");
        access(0, 32'h208, 0);
        check(was_miss, "line still valid after reset");

        if (errors == 0) $display("dm_cache.v unit test: PASS");
        else             $display("dm_cache.v unit test: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
