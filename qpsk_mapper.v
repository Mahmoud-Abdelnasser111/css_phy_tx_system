module qpsk_mapper(
    input  clk,
    input  reset,
    input  I,
    input  Q,
    output reg signed [1:0] Xn_real,
    output reg signed [1:0] Xn_imj
);

    always @(posedge clk) begin
        if (reset) begin
            Xn_real <= 2'sb00;
            Xn_imj  <= 2'sb00;
        end
        else begin
            case ({I,Q})
                2'b00: begin
                    Xn_real <= 2'sb11; // -1
                    Xn_imj  <= 2'sb00; //  0
                end

                2'b01: begin
                    Xn_real <= 2'sb00; //  0
                    Xn_imj  <= 2'sb01; // +1
                end

                2'b10: begin
                    Xn_real <= 2'sb00; //  0
                    Xn_imj  <= 2'sb11; // -1
                end

                2'b11: begin
                    Xn_real <= 2'sb01; // +1
                    Xn_imj  <= 2'sb00; //  0
                end
            endcase
        end
    end

endmodule