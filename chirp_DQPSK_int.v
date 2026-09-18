module chirp_DQPSK_int (

    input  signed [1:0] I_in,
    input  signed [1:0] Q_in,

    input  clk,
    input  rst,

    input  valid_in,
    input  last_in,

    output signed [7:0] tx_real,
    output signed [7:0] tx_image,

    output reg tx_valid,
    output reg done
);

    // =========================================================
    // Parameters
    // =========================================================

    localparam integer MEM_DEPTH     = 208;
    localparam integer TOTAL_SAMPLES = 9984;

    // =========================================================
    // DQPSK signals
    // =========================================================

    wire signed [1:0] I_out;
    wire signed [1:0] Q_out;
    wire              valid_out;

    dqpsk qpsk_instance (
        .clk       (clk),
        .rst       (rst),
        .valid_in  (valid_in),
        .I_in      (I_in),
        .Q_in      (Q_in),
        .I_out     (I_out),
        .Q_out     (Q_out),
        .valid_out (valid_out)
    );

    // =========================================================
    // FIFO
    // =========================================================

    reg signed [1:0] FIFO_i [0:MEM_DEPTH-1];
    reg signed [1:0] FIFO_q [0:MEM_DEPTH-1];

    reg              FIFO_last [0:MEM_DEPTH-1];

    reg [7:0] address_write_I;
    reg [7:0] address_read_I;

    reg [7:0] address_write_Q;
    reg [7:0] address_read_Q;

    reg [7:0] write_count;

    reg all_symbols_loaded;

    // =========================================================
    // DQPSK symbol currently used for chirp modulation
    // =========================================================

    reg signed [1:0] DQPSK_real_latched;
    reg signed [1:0] DQPSK_image_latched;

    // =========================================================
    // Chirp generator
    // =========================================================

    reg chirp_enable;

    wire valid_symbol;
    wire signed [5:0] chirp_real_part;
    wire signed [5:0] chirp_image_part;
    wire chirp_done_from_generator;

    chirp_sequence_generator chirp_seq_gen (
        .clk          (clk),
        .rst          (rst),
        .enable       (chirp_enable),
        .valid_symbol (valid_symbol),
        .real_part    (chirp_real_part),
        .image_part   (chirp_image_part),
        .chirp_done   (chirp_done_from_generator)
    );

    // =========================================================
    // Important pipeline registers
    //
    // We latch:
    //   1) the current DQPSK symbol
    //   2) the current chirp sample
    //
    // at the same clock edge.
    //
    // This avoids the old one-cycle FIFO/chirp misalignment.
    // =========================================================

    reg signed [5:0] chirp_real_latched;
    reg signed [5:0] chirp_image_latched;

    // =========================================================
    // Final sample counter
    // =========================================================

    reg [13:0] sample_count;

    // =========================================================
    // Complex multiplier
    // =========================================================

    complex_multi multi (
        .chirp_seq_real  (chirp_real_latched),
        .chirp_seq_image (chirp_image_latched),
        .DQPSK_real      (DQPSK_real_latched),
        .DQPSK_image     (DQPSK_image_latched),
        .tx_real         (tx_real),
        .tx_image        (tx_image)
    );

    // =========================================================
    // FIFO WRITE
    //
    // DQPSK valid_out means a new DQPSK symbol is ready.
    // =========================================================

    always @(posedge clk) begin

        if (rst) begin

            address_write_I  <= 8'd0;
            address_write_Q  <= 8'd0;
            write_count      <= 8'd0;
            all_symbols_loaded <= 1'b0;

        end
        else begin

            if (valid_out && !all_symbols_loaded) begin

                FIFO_i[address_write_I] <= I_out;
                FIFO_q[address_write_Q] <= Q_out;

                FIFO_last[address_write_I] <= last_in;

                address_write_I <= address_write_I + 1'b1;
                address_write_Q <= address_write_Q + 1'b1;

                if (write_count == MEM_DEPTH-1) begin

                    write_count <= MEM_DEPTH;
                    all_symbols_loaded <= 1'b1;

                end
                else begin

                    write_count <= write_count + 1'b1;

                end
            end
        end
    end

    // =========================================================
    // START CHIRP
    //
    // Chirp starts only AFTER all 208 DQPSK symbols
    // have been written into the FIFO.
    // =========================================================

    always @(posedge clk) begin

        if (rst) begin

            chirp_enable <= 1'b0;

        end
        else begin

            if (all_symbols_loaded &&
                !tx_valid &&
                !done) begin

                chirp_enable <= 1'b1;

            end

            if (tx_valid &&
                (sample_count == TOTAL_SAMPLES-1)) begin

                chirp_enable <= 1'b0;

            end

        end
    end

    // =========================================================
    // FIFO READ + PIPELINE
    //
    // valid_symbol is asserted at the beginning of every
    // 38-sample subchirp.
    //
    // At this edge:
    //   - read next DQPSK symbol
    //   - latch current chirp sample
    //
    // After the edge, both belong to the same subchirp sample.
    // =========================================================

    always @(posedge clk) begin

        if (rst) begin

            address_read_I      <= 8'd0;
            address_read_Q      <= 8'd0;

            DQPSK_real_latched  <= 2'sd0;
            DQPSK_image_latched <= 2'sd0;

            chirp_real_latched  <= 6'sd0;
            chirp_image_latched <= 6'sd0;

        end
        else begin

            // -------------------------------------------------
            // Read next DQPSK symbol
            // -------------------------------------------------

            if (valid_symbol) begin

                DQPSK_real_latched  <= FIFO_i[address_read_I];
                DQPSK_image_latched <= FIFO_q[address_read_Q];

                address_read_I <= address_read_I + 1'b1;
                address_read_Q <= address_read_Q + 1'b1;

            end

            // -------------------------------------------------
            // Latch current chirp sample
            //
            // During the gap, chirp_sequence_generator outputs
            // zero, so the complex multiplier naturally outputs
            // zero as well.
            // -------------------------------------------------

            if (chirp_enable) begin

                chirp_real_latched  <= chirp_real_part;
                chirp_image_latched <= chirp_image_part;

            end
        end
    end

    // =========================================================
    // TX VALID + DONE
    //
    // The first valid output appears one clock after
    // chirp_enable becomes active.
    //
    // We keep tx_valid HIGH for all:
    //   chirp samples + gap samples
    //
    // Total = 9984 samples.
    // =========================================================

    always @(posedge clk) begin

        if (rst) begin

            tx_valid    <= 1'b0;
            done        <= 1'b0;
            sample_count <= 14'd0;

        end
        else begin

            // -------------------------------------------------
            // DONE is a pulse
            // -------------------------------------------------

            done <= 1'b0;

            // -------------------------------------------------
            // Start output pipeline
            // -------------------------------------------------

            if (chirp_enable) begin

                tx_valid <= 1'b1;

                // -------------------------------------------------
                // Count output samples
                //
                // sample_count = index of the sample currently
                // represented during this valid interval.
                // -------------------------------------------------

                if (tx_valid) begin

                    if (sample_count == TOTAL_SAMPLES-1) begin

                        tx_valid     <= 1'b0;
                        done         <= 1'b1;
                        sample_count <= TOTAL_SAMPLES;

                    end
                    else begin

                        sample_count <= sample_count + 1'b1;

                    end
                end
            end
            else begin

                tx_valid <= 1'b0;

            end
        end
    end




endmodule


