module symbol_mapper_1mbps (
    input   [2:0] symbol,
    output reg  [3:0] codeword
);

always @(*) begin
    case (symbol)

        3'b000: codeword = 4'b1111;
        3'b001: codeword = 4'b1010;
        3'b010: codeword = 4'b1100;
        3'b011: codeword = 4'b1001;
        3'b100: codeword = 4'b0000;
        3'b101: codeword = 4'b0101;
        3'b110: codeword = 4'b0011;
        3'b111: codeword = 4'b0110;

        default: codeword = 4'b0000;

    endcase
end

endmodule