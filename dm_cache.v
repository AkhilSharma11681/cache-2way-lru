// Direct-mapped cache (baseline)
// 1 KB total: 64 lines x 16-byte blocks (4 words per block)
// Address split: tag = [31:10] (22 bits), index = [9:4] (6 bits),
//                word = [3:2] (2 bits), byte = [1:0]
module dm_cache (
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

    reg [21:0]  tagm  [0:63];
    reg [127:0] datam [0:63];
    reg         valid [0:63];

    wire [5:0]  idx = cpu_addr[9:4];
    wire [21:0] tag = cpu_addr[31:10];
    wire [1:0]  w   = cpu_addr[3:2];

    wire hit = valid[idx] && (tagm[idx] == tag);

    wire [127:0] blk  = datam[idx];
    wire [31:0]  word = blk[w*32 +: 32];

    assign mem_req   = (state == REFILL) || (state == WTHRU);
    assign mem_we    = (state == WTHRU);
    assign mem_addr  = cpu_addr;
    assign mem_wdata = cpu_wdata;
    assign cpu_done  = (state == DONE);

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; hits <= 0; misses <= 0; cpu_rdata <= 0;
            for (i = 0; i < 64; i = i + 1) valid[i] <= 0;
        end else case (state)
            IDLE: if (cpu_req) state <= LOOKUP;
            LOOKUP: begin
                if (hit) hits <= hits + 1;
                else     misses <= misses + 1;

                begin
                    if (hit) begin cpu_rdata <= word; state <= DONE; end
                    else state <= REFILL;
                end
            end
            REFILL: if (mem_ready) begin
                datam[idx] <= mem_rblock;
                tagm[idx]  <= tag;
                valid[idx] <= 1;
                cpu_rdata  <= mem_rblock[w*32 +: 32];
                state <= DONE;
            end
            DONE: state <= IDLE;
            default: state <= IDLE;
        endcase
    end
endmodule
