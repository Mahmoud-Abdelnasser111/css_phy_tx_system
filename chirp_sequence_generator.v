module chirp_sequence_generator (
    input clk,
    input rst,
    input enable,

    output valid_symbol,
    output signed [5:0] real_part,
    output signed [5:0] image_part,
    output chirp_done
);

    // =========================================================
    // Parameters
    // =========================================================
    localparam integer SUBCHIRP_SAMPLES = 38;

    // =========================================================
    // Counters
    // =========================================================
    reg [5:0] counter;
    reg [7:0] counter_gap;

    // k = current subchirp:
    // 0 -> subchirp 1
    // 1 -> subchirp 2
    // 2 -> subchirp 3
    // 3 -> subchirp 4
    reg [1:0] k;

    // Gap counter state
    reg [7:0] n;
    reg in_gap;
    reg [5:0] gap_sample;

    // =========================================================
    // Complete 152-sample ROM address
    //
    // 0   - 37  -> subchirp 1
    // 38  - 75  -> subchirp 2
    // 76  - 113 -> subchirp 3
    // 114 - 151 -> subchirp 4
    // =========================================================
    wire [7:0] rom_address;

    wire signed [5:0] chirp_seq_out_real;
    wire signed [5:0] chirp_seq_out_image;

    assign rom_address = (k * 8'd38) + counter;

    // =========================================================
    // Complete Chirp ROM
    // =========================================================
    chirp_ROM_full block_1 (
        .address(rom_address),
        .chirp_seq_out_real(chirp_seq_out_real),
        .chirp_seq_out_image(chirp_seq_out_image)
    );

    // =========================================================
    // Main control
    // =========================================================
    always @(posedge clk) begin

        if (rst) begin

            counter     <= 6'd0;
            counter_gap <= 8'd0;
            k           <= 2'd0;
            n           <= 8'd0;
            in_gap      <= 1'b0;
            gap_sample  <= 6'd0;

        end
        else if (enable) begin

            // -------------------------------------------------
            // Gap handling
            // -------------------------------------------------
            if (in_gap) begin

                counter <= 6'd0;

                // Even sequence -> 10 samples
                // Odd sequence  -> 70 samples
                if (n[0] == 1'b0) begin

                    if (counter_gap == 8'd9) begin
                        counter_gap <= 8'd0;
                        in_gap       <= 1'b0;
                        n            <= n + 1'b1;
                    end
                    else begin
                        counter_gap <= counter_gap + 1'b1;
                    end

                end

                else begin

                    if (counter_gap == 8'd69) begin
                        counter_gap <= 8'd0;
                        in_gap       <= 1'b0;
                        n            <= n + 1'b1;
                    end
                    else begin
                        counter_gap <= counter_gap + 1'b1;
                    end

                end

            end

            // -------------------------------------------------
            // Normal chirp samples
            // -------------------------------------------------
            else begin

                if (counter == 6'd37) begin

                    counter <= 6'd0;

                    // Move to next subchirp
                    if (k == 2'd3) begin

                        // 4th subchirp finished
                        k       <= 2'd0;
                        in_gap  <= 1'b1;
                        gap_sample <= 6'd0;

                    end
                    else begin

                        k <= k + 1'b1;

                    end

                end

                else begin

                    counter <= counter + 1'b1;

                end

            end

        end

    end

    // =========================================================
    // Outputs
    // =========================================================

    // Pulse at beginning of every 38-sample subchirp
    assign valid_symbol =
        enable &&
        !in_gap &&
        (counter == 6'd0);

    // Generator indicates gap period
    assign chirp_done = in_gap;

    // During gap output zero
    assign real_part =
        in_gap ? 6'sd0 : chirp_seq_out_real;

    assign image_part =
        in_gap ? 6'sd0 : chirp_seq_out_image;

endmodule