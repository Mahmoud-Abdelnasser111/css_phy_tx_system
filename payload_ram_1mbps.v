module payload_ram_1mbps (
    input  wire       clk,
    input  wire       wr_en,
    input  wire [6:0] wr_addr,
    input  wire [7:0] wr_data,

    input  wire [6:0] rd_addr,
    output reg  [7:0] rd_data
);

    reg [7:0] mem [0:127];

    always @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    always @(*) begin
        rd_data = mem[rd_addr];
    end

endmodule