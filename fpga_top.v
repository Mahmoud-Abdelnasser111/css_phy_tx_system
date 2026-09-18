module fpga_top (

    // =========================================================
    // ZedBoard clock
    // 100 MHz
    // =========================================================
    input  wire        clk,

    // =========================================================
    // User controls
    // =========================================================
    input  wire        reset_btn,
    input  wire        start_btn,

    // =========================================================
    // Debug LEDs
    // =========================================================
    output wire [7:0]  led,

    // =========================================================
    // Digital TX outputs
    // =========================================================
    output wire [7:0]  tx_real_out,
    output wire [7:0]  tx_imag_out

);

    // =========================================================
    // Parameters
    // =========================================================
    localparam integer PAYLOAD_BYTES = 28;

    // =========================================================
    // Button synchronization
    // =========================================================
    reg reset_sync1;
    reg reset_sync2;

    reg start_sync1;
    reg start_sync2;
    reg start_sync2_d;

    wire reset;
    wire start_pulse;

    assign reset = reset_sync2;

    assign start_pulse = start_sync2 & ~start_sync2_d;

    always @(posedge clk) begin

        reset_sync1 <= reset_btn;
        reset_sync2 <= reset_sync1;

        start_sync1 <= start_btn;
        start_sync2 <= start_sync1;
        start_sync2_d <= start_sync2;

    end

    // =========================================================
    // Payload ROM
    //
    // payload.mem must contain 28 lines,
    // each line = one 8-bit hexadecimal byte
    //
    // Example:
    // 00
    // 11
    // A5
    // ...
    // =========================================================
    reg [7:0] payload_rom [0:PAYLOAD_BYTES-1];

    initial begin
        $readmemh("payload.mem", payload_rom);
    end

    // =========================================================
    // Signals connected to CSS core
    // =========================================================

    reg        core_start;

    reg [7:0]  payload_length;

    reg        payload_wr_en;
    reg [6:0]  payload_wr_addr;
    reg [7:0]  payload_wr_data;

    wire [7:0] tx_real;
    wire [7:0] tx_imag;

    wire       tx_valid;
    wire       done_tx;

    // =========================================================
    // Instantiate the actual CSS PHY core
    // =========================================================

    css_phy_tx_1mbps_top u_css_core (

        .clk             (clk),
        .reset           (reset),
        .start_Tx        (core_start),

        .payloadLength   (payload_length),

        .payload_wr_en   (payload_wr_en),
        .payload_wr_addr (payload_wr_addr),
        .payload_wr_data (payload_wr_data),

        .Tx_real         (tx_real),
        .Tx_imag         (tx_imag),

        .Tx_valid        (tx_valid),
        .done_Tx         (done_tx)

    );

    // =========================================================
    // Wrapper FSM
    // =========================================================

    localparam [2:0]
        ST_IDLE  = 3'd0,
        ST_LOAD  = 3'd1,
        ST_START = 3'd2,
        ST_TX    = 3'd3,
        ST_DONE  = 3'd4;

    reg [2:0] state;

    reg [6:0] payload_count;

    // =========================================================
    // Control FSM
    // =========================================================

    always @(posedge clk) begin

        if (reset) begin

            state           <= ST_IDLE;

            payload_count   <= 6'd0;

            core_start     <= 1'b0;

            payload_length <= 8'd0;

            payload_wr_en  <= 1'b0;
            payload_wr_addr <= 7'd0;
            payload_wr_data <= 8'd0;

        end
        else begin

            // -------------------------------------------------
            // Default values
            // -------------------------------------------------
            core_start    <= 1'b0;
            payload_wr_en <= 1'b0;

            case (state)

                // =================================================
                // IDLE
                // =================================================
                ST_IDLE: begin

                    payload_count <= 6'd0;

                    payload_wr_addr <= 7'd0;
                    payload_wr_data <= 8'd0;

                    if (start_pulse) begin

                        state <= ST_LOAD;

                    end
                end


                // =================================================
                // LOAD PAYLOAD INTO CSS CORE RAM
                // =================================================
                ST_LOAD: begin

                    payload_wr_en   <= 1'b1;

                    payload_wr_addr <= payload_count[6:0];

                    payload_wr_data <= payload_rom[payload_count];

                    if (payload_count == PAYLOAD_BYTES-1) begin

                        payload_count <= 6'd0;

                        state <= ST_START;

                    end
                    else begin

                        payload_count <= payload_count + 1'b1;

                    end

                end


                // =================================================
                // START TRANSMISSION
                // =================================================
                ST_START: begin

                    payload_length <= PAYLOAD_BYTES;

                    core_start <= 1'b1;

                    state <= ST_TX;

                end


                // =================================================
                // WAIT FOR TRANSMISSION TO FINISH
                // =================================================
                ST_TX: begin

                    if (done_tx) begin

                        state <= ST_DONE;

                    end

                end


                // =================================================
                // DONE
                // =================================================
                ST_DONE: begin

                    if (!start_btn) begin

                        state <= ST_IDLE;

                    end

                end


                default: begin

                    state <= ST_IDLE;

                end

            endcase

        end

    end

    // =========================================================
    // Outputs
    // =========================================================

    assign tx_real_out = tx_real;
    assign tx_imag_out = tx_imag;

    // ---------------------------------------------------------
    // LEDs
    //
    // LED0 = TX valid
    // LED1 = DONE
    // LED2 = LOAD state
    // LED3 = TX state
    // LED4 = START state
    // LED5 = RESET
    // ---------------------------------------------------------

    assign led[0] = tx_valid;
    assign led[1] = done_tx;

    assign led[2] = (state == ST_LOAD);
    assign led[3] = (state == ST_TX);
    assign led[4] = (state == ST_START);
    assign led[5] = reset;

    assign led[6] = 1'b0;
    assign led[7] = 1'b0;

endmodule