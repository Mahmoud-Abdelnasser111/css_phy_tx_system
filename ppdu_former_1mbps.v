//=========================================================
// PPDU Former
// IEEE 802.15.4 CSS - 1 Mbps
//
// Input payload is SERIAL:
//   I_in = 1 chip / clock
//   Q_in = 1 chip / clock
//
// PPDU:
//   Preamble : 32 chips
//   SFD      : 16 chips
//   Payload  : serial I/Q chips
//
// Padding is NOT performed here.
//=========================================================

module ppdu_former_1mbps (

    input  wire clk,
    input  wire reset,
    input  wire start_Tx,

    // Preamble / SFD ROM
    input  wire preamble_chip,
    input  wire SFD_chip,

    // Serialized payload
    input  wire I_in,
    input  wire Q_in,
    input  wire payload_valid,
    input  wire payload_last,

    // Outputs
    output reg I_out,
    output reg Q_out,

    output reg ppdu_valid,
    output reg ppdu_last,

    // High while PPDU is ready to accept payload
    output reg payload_ready,

    output reg done_Tx
);

    reg SFD_chip_internal;
    //=====================================================
    // FSM states
    //=====================================================

    parameter IDLE     = 3'b000,
              PREAMBLE = 3'b001,
              SFD      = 3'b010,
              PAYLOAD  = 3'b011,
              DONE     = 3'b100;


    reg [2:0] current_state;
    reg [2:0] next_state;


    //=====================================================
    // Counters
    //=====================================================

    reg [5:0] pre_cnt;
    reg [4:0] sfd_cnt;

    always @(*) begin
    case (sfd_cnt)
        5'd0:  SFD_chip_internal = 1'b0;
        5'd1:  SFD_chip_internal = 1'b1;
        5'd2:  SFD_chip_internal = 1'b1;
        5'd3:  SFD_chip_internal = 1'b1;
        5'd4:  SFD_chip_internal = 1'b0;
        5'd5:  SFD_chip_internal = 1'b1;
        5'd6:  SFD_chip_internal = 1'b0;
        5'd7:  SFD_chip_internal = 1'b0;
        5'd8:  SFD_chip_internal = 1'b1;
        5'd9:  SFD_chip_internal = 1'b0;
        5'd10: SFD_chip_internal = 1'b0;
        5'd11: SFD_chip_internal = 1'b1;
        5'd12: SFD_chip_internal = 1'b1;
        5'd13: SFD_chip_internal = 1'b1;
        5'd14: SFD_chip_internal = 1'b0;
        5'd15: SFD_chip_internal = 1'b0;
        default: SFD_chip_internal = 1'b0;
    endcase
end
    //=====================================================
    // State register
    //=====================================================

    always @(posedge clk or posedge reset) begin

        if (reset)
            current_state <= IDLE;

        else
            current_state <= next_state;

    end


    //=====================================================
    // Next state logic
    //=====================================================

    always @(*) begin

        next_state = current_state;

        case (current_state)

            IDLE: begin

                if (start_Tx)
                    next_state = PREAMBLE;

            end


            PREAMBLE: begin

                if (pre_cnt == 6'd31)
                    next_state = SFD;

            end


            SFD: begin

                if (sfd_cnt == 5'd15)
                    next_state = PAYLOAD;

            end


            PAYLOAD: begin

                if (payload_valid && payload_last)
                    next_state = DONE;

            end


            DONE: begin

                next_state = IDLE;

            end


            default: begin

                next_state = IDLE;

            end

        endcase

    end


    //=====================================================
    // Output logic
    //=====================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            I_out <= 1'b0;
            Q_out <= 1'b0;

            ppdu_valid <= 1'b0;
            ppdu_last  <= 1'b0;

            payload_ready <= 1'b0;

            done_Tx <= 1'b0;

            pre_cnt <= 6'd0;
            sfd_cnt <= 5'd0;

        end

        else begin

            // Default outputs
            ppdu_valid <= 1'b0;
            ppdu_last  <= 1'b0;
            done_Tx    <= 1'b0;


            case (current_state)


                //=========================================
                // IDLE
                //=========================================

                IDLE: begin

                    pre_cnt <= 6'd0;
                    sfd_cnt <= 5'd0;

                    payload_ready <= 1'b0;

                end


                //=========================================
                // PREAMBLE
                // 32 chips
                //=========================================

                PREAMBLE: begin

                    payload_ready <= 1'b0;

                    I_out <= preamble_chip;
                    Q_out <= preamble_chip;

                    ppdu_valid <= 1'b1;


                    if (pre_cnt == 6'd31) begin

                        pre_cnt <= 6'd0;
                        sfd_cnt <= 5'd0;

                    end

                    else begin

                        pre_cnt <= pre_cnt + 1'b1;

                    end

                end


                //=========================================
                // SFD
                // 16 chips
                //=========================================

                SFD: begin

                    payload_ready <= 1'b0;

                    I_out <= SFD_chip_internal;
Q_out <= SFD_chip_internal;
                    ppdu_valid <= 1'b1;


                    if (sfd_cnt == 5'd15) begin

                        sfd_cnt <= 5'd0;

                    end

                    else begin

                        sfd_cnt <= sfd_cnt + 1'b1;

                    end

                end


                //=========================================
                // PAYLOAD
                //=========================================

                PAYLOAD: begin

                    payload_ready <= 1'b1;


                    if (payload_valid) begin

                        I_out <= I_in;
                        Q_out <= Q_in;

                        ppdu_valid <= 1'b1;


                        if (payload_last) begin

                            ppdu_last <= 1'b1;

                        end

                    end

                end


                //=========================================
                // DONE
                //=========================================

                DONE: begin

                    payload_ready <= 1'b0;

                    done_Tx <= 1'b1;

                end


            endcase

        end

    end

endmodule