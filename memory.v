// Main memory model
// 16 KB = 4096 words. Word i is initialised to the value i.
// Every request (block read or word write) takes LAT cycles,
// then ready is pulsed high for one cycle.
module memory #(parameter LAT = 10) (
    input clk, rst,
    input req, we,
    input [31:0] addr, wdata,
    output [127:0] rblock,
    output reg ready
);
    reg [31:0] mem [0:4095];
    reg [7:0]  cnt;

    // start word of the 16-byte block that contains addr
    wire [11:0] base = {addr[13:4], 2'b00};
    assign rblock = {mem[base+3], mem[base+2], mem[base+1], mem[base]};

    integer i;
    initial for (i = 0; i < 4096; i = i + 1) mem[i] = i;

    always @(posedge clk) begin
        if (rst || !req) begin
            cnt <= 0; ready <= 0;
        end else if (ready) begin
            ready <= 0;                      // one-cycle pulse
        end else if (cnt == LAT - 1) begin
            ready <= 1;
            if (we) mem[addr[13:2]] <= wdata;  // word write
        end else
            cnt <= cnt + 1;
    end
endmodule
