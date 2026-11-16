`timescale 1ns/1ps
module tb;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    reg req = 0, we = 0, use_sa = 0;
    reg [31:0] addr = 0, wdata = 0;

    wire done_dm, mreq_dm, mwe_dm, mrdy_dm;
    wire [31:0] rdata_dm, hits_dm, miss_dm, maddr_dm, mwd_dm;
    wire [127:0] mblk_dm;
    dm_cache dm (.clk(clk), .rst(rst), .cpu_req(req & ~use_sa), .cpu_we(we),
        .cpu_addr(addr), .cpu_wdata(wdata), .cpu_done(done_dm), .cpu_rdata(rdata_dm),
        .mem_req(mreq_dm), .mem_we(mwe_dm), .mem_addr(maddr_dm), .mem_wdata(mwd_dm),
        .mem_rblock(mblk_dm), .mem_ready(mrdy_dm), .hits(hits_dm), .misses(miss_dm));
    memory mem_dm (.clk(clk), .rst(rst), .req(mreq_dm), .we(mwe_dm), .addr(maddr_dm),
        .wdata(mwd_dm), .rblock(mblk_dm), .ready(mrdy_dm));

    wire done_sa, mreq_sa, mwe_sa, mrdy_sa;
    wire [31:0] rdata_sa, hits_sa, miss_sa, maddr_sa, mwd_sa;
    wire [127:0] mblk_sa;
    sa2_cache sa (.clk(clk), .rst(rst), .cpu_req(req & use_sa), .cpu_we(we),
        .cpu_addr(addr), .cpu_wdata(wdata), .cpu_done(done_sa), .cpu_rdata(rdata_sa),
        .mem_req(mreq_sa), .mem_we(mwe_sa), .mem_addr(maddr_sa), .mem_wdata(mwd_sa),
        .mem_rblock(mblk_sa), .mem_ready(mrdy_sa), .hits(hits_sa), .misses(miss_sa));
    memory mem_sa (.clk(clk), .rst(rst), .req(mreq_sa), .we(mwe_sa), .addr(maddr_sa),
        .wdata(mwd_sa), .rblock(mblk_sa), .ready(mrdy_sa));

    wire done = use_sa ? done_sa : done_dm;
    wire [31:0] rdata = use_sa ? rdata_sa : rdata_dm;

    reg [31:0] cycles; reg counting = 0;
    always @(posedge clk) if (counting) cycles <= cycles + 1;

    reg [31:0] rd;
    task access(input w, input [31:0] a, input [31:0] d);
    begin
        we = w; addr = a; wdata = d; req = 1;
        @(negedge clk);
        while (!done) @(negedge clk);
        rd = rdata;
    end
    endtask

    integer seed, j, n;
    task run_trace(input integer tr);
    begin
        seed = 1;
        case (tr)
            1: for (j = 0; j < 256; j = j + 1) access(0, j*4, 0);
            2: for (n = 0; n < 4; n = n + 1)
                   for (j = 0; j < 64; j = j + 1) access(0, j*4, 0);
            3: for (j = 0; j < 20; j = j + 1) begin
                   access(0, 32'h000, 0); access(0, 32'h400, 0);
               end
            4: for (j = 0; j < 10; j = j + 1) begin
                   access(0, 32'h000, 0); access(0, 32'h400, 0);
                   access(0, 32'h000, 0); access(0, 32'h800, 0);
               end
            5: for (j = 0; j < 500; j = j + 1)
                   access(0, $random(seed) & 32'h7FC, 0);
        endcase
    end
    endtask

    reg ok;
    task write_test;
    begin
        ok = 1;
        access(1, 32'h40, 32'hDEADBEEF);
        access(0, 32'h40, 0); if (rd !== 32'hDEADBEEF) ok = 0;
        access(0, 32'h40, 0); if (rd !== 32'hDEADBEEF) ok = 0;
        access(1, 32'h40, 32'h12345678);
        access(0, 32'h40, 0); if (rd !== 32'h12345678) ok = 0;
        access(0, 32'h44, 0); if (rd !== 32'd17)        ok = 0;
    end
    endtask

    reg [8*22-1:0] name;
    reg [31:0] H [0:1]; reg [31:0] M [0:1]; reg [31:0] C [0:1];
    integer t, k;
    initial begin
        $dumpfile("wave.vcd"); $dumpvars(0, tb);
        $display("");
        $display("Trace                  | Direct-Mapped (hit%% / cycles) | 2-Way LRU (hit%% / cycles)");
        $display("-----------------------------------------------------------------------------------");
        for (t = 1; t <= 5; t = t + 1) begin
            for (k = 0; k < 2; k = k + 1) begin
                use_sa = k; req = 0;
                rst = 1; repeat (3) @(negedge clk); rst = 0; @(negedge clk);
                cycles = 0; counting = 1;
                run_trace(t);
                counting = 0; req = 0;
                H[k] = k ? hits_sa : hits_dm;
                M[k] = k ? miss_sa : miss_dm;
                C[k] = cycles;
                repeat (3) @(negedge clk);
            end
            case (t)
                1: name = "Sequential";
                2: name = "Repeated loop";
                3: name = "2-addr conflict";
                4: name = "3-addr LRU test";
                5: name = "Random";
            endcase
            $display("%-22s | hit=%3d miss=%3d  %5.1f%%  cyc=%5d | hit=%3d miss=%3d  %5.1f%%  cyc=%5d",
                name, H[0], M[0], H[0]*100.0/(H[0]+M[0]), C[0],
                      H[1], M[1], H[1]*100.0/(H[1]+M[1]), C[1]);
            $display("%-22s | AMAT = %5.2f cycles/access        | AMAT = %5.2f cycles/access",
                "", C[0]*1.0/(H[0]+M[0]), C[1]*1.0/(H[1]+M[1]));
        end

        for (k = 0; k < 2; k = k + 1) begin
            use_sa = k; req = 0;
            rst = 1; repeat (3) @(negedge clk); rst = 0; @(negedge clk);
            write_test;
            req = 0;
            $display("Write/Read test (%s): %s", k ? "2-way" : "DM   ", ok ? "PASS" : "FAIL");
        end
        $display("");
        $finish;
    end
endmodule
