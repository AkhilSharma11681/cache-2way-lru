module sa2_cache (
    input clk, rst,
    input cpu_req, cpu_we,
    input [31:0] cpu_addr, cpu_wdata,
    output cpu_done,
    output reg [31:0] cpu_rdata,
    output mem_req, mem_we,
    output [31:0] mem_addr, mem_wdata,
    input [127:0] mem_rblock,
    input mem_ready,
    output reg [31:0] hits, misses
);
    localparam IDLE=0, LOOKUP=1, REFILL=2, WTHRU=3, DONE=4;
    reg [2:0] state;

    reg [22:0]  tag0  [0:31];  reg [22:0]  tag1  [0:31];
    reg [127:0] data0 [0:31];  reg [127:0] data1 [0:31];
    reg         v0    [0:31];  reg         v1    [0:31];
    reg         lru   [0:31];

    wire [4:0]  idx = cpu_addr[8:4];
    wire [22:0] tag = cpu_addr[31:9];
    wire [1:0]  w   = cpu_addr[3:2];

    wire hit0 = v0[idx] && (tag0[idx] == tag);
    wire hit1 = v1[idx] && (tag1[idx] == tag);
    wire hit  = hit0 | hit1;

    wire [127:0] blk0 = data0[idx];
    wire [127:0] blk1 = data1[idx];
    wire [31:0] word0 = blk0[w*32 +: 32];
    wire [31:0] word1 = blk1[w*32 +: 32];

    wire victim = !v0[idx] ? 1'b0 : (!v1[idx] ? 1'b1 : lru[idx]);

    assign mem_req   = (state == REFILL) || (state == WTHRU);
    assign mem_we    = (state == WTHRU);
    assign mem_addr  = cpu_addr;
    assign mem_wdata = cpu_wdata;
    assign cpu_done  = (state == DONE);

    reg [127:0] tmp;
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; hits <= 0; misses <= 0; cpu_rdata <= 0;
            for (i = 0; i < 32; i = i + 1) begin
                v0[i] <= 0; v1[i] <= 0; lru[i] <= 0;
            end
        end else case (state)
            IDLE: if (cpu_req) state <= LOOKUP;
            LOOKUP: begin
                if (hit) begin
                    hits <= hits + 1;
                    lru[idx] <= hit0 ? 1'b1 : 1'b0;
                end else misses <= misses + 1;

                if (cpu_we) begin
                    if (hit0) begin
                        tmp = blk0; tmp[w*32 +: 32] = cpu_wdata; data0[idx] <= tmp;
                    end else if (hit1) begin
                        tmp = blk1; tmp[w*32 +: 32] = cpu_wdata; data1[idx] <= tmp;
                    end
                    state <= WTHRU;
                end else begin
                    if (hit) begin cpu_rdata <= hit0 ? word0 : word1; state <= DONE; end
                    else state <= REFILL;
                end
            end
            REFILL: if (mem_ready) begin
                if (victim == 1'b0) begin
                    data0[idx] <= mem_rblock; tag0[idx] <= tag; v0[idx] <= 1;
                end else begin
                    data1[idx] <= mem_rblock; tag1[idx] <= tag; v1[idx] <= 1;
                end
                lru[idx]  <= ~victim;
                cpu_rdata <= mem_rblock[w*32 +: 32];
                state <= DONE;
            end
            WTHRU: if (mem_ready) state <= DONE;
            DONE: state <= IDLE;
            default: state <= IDLE;
        endcase
    end
endmodule
