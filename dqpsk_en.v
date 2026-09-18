module dqpsk (
    input  clk,
    input  rst,
    input  valid_in,

    input signed [1:0] I_in,
    input signed [1:0] Q_in,

    output reg signed [1:0] I_out,
    output reg signed [1:0] Q_out,
    output reg valid_out
);

    reg signed [1:0] I_delay0, I_delay1, I_delay2, I_delay3;
    reg signed [1:0] Q_delay0, Q_delay1, Q_delay2, Q_delay3;

    wire signed [2:0] real_part;
    wire signed [2:0] imag_part;

    assign real_part = (I_in * I_delay3) - (Q_in * Q_delay3);
    assign imag_part = (I_in * Q_delay3) + (Q_in * I_delay3);

    always @(posedge clk) begin
        if (rst) begin
            I_delay0 <= 2'sb01; I_delay1 <= 2'sb01;
            I_delay2 <= 2'sb01; I_delay3 <= 2'sb01;

            Q_delay0 <= 2'sb01; Q_delay1 <= 2'sb01;
            Q_delay2 <= 2'sb01; Q_delay3 <= 2'sb01;

            I_out     <= 2'sb00;
            Q_out     <= 2'sb00;
            valid_out <= 1'b0;
        end
        else if (valid_in) begin
            I_out     <= real_part[1:0];
            Q_out     <= imag_part[1:0];
            valid_out <= 1'b1;

            I_delay3 <= I_delay2;
            I_delay2 <= I_delay1;
            I_delay1 <= I_delay0;
            I_delay0 <= real_part[1:0];

            Q_delay3 <= Q_delay2;
            Q_delay2 <= Q_delay1;
            Q_delay1 <= Q_delay0;
            Q_delay0 <= imag_part[1:0];
        end
        else begin
            valid_out <= 1'b0;
        end
    end

    // synthesis translate_off
    always @(posedge clk) begin
        if (!rst && valid_in) begin
            if ((I_in != 0) && (Q_in != 0))
                $error("dqpsk: I_in and Q_in both nonzero (%0d,%0d) -- Xn is not one-hot, check QPSK mapper", I_in, Q_in);
        end
    end
    // synthesis translate_on
endmodule