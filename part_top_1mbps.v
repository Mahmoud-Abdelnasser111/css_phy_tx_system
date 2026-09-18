module part_top_1mbps (

    input  wire       clk,
    input  wire       reset,
    input  wire       start,

    input  wire [7:0] payload_length,

    // Payload RAM write interface
    input  wire       payload_wr_en,
    input  wire [6:0] payload_wr_addr,
    input  wire [7:0] payload_wr_data,

    // Final PPDU outputs
    output wire       I_ppdu,
    output wire       Q_ppdu,
    output wire       ppdu_valid,
    output wire       ppdu_last,
    output reg        done
);
    // 0) Main FSM
    localparam STATE_IDLE    = 2'd0;
    localparam STATE_COLLECT = 2'd1;
    localparam STATE_SEND    = 2'd2;
    localparam STATE_DONE    = 2'd3;
    reg [1:0] state;
    wire ppdu_done_internal;
    wire codeword_valid_internal;
    // 1) Payload RAM
    wire [6:0] payload_rd_addr;
    wire [7:0] payload_rd_data;

    payload_ram_1mbps u_payload_ram (

        .clk     (clk),

        .wr_en   (payload_wr_en),
        .wr_addr (payload_wr_addr),
        .wr_data (payload_wr_data),

        .rd_addr (payload_rd_addr),
        .rd_data (payload_rd_data)

    );
    // 2) PHR
    reg [11:0] phr;
    reg [7:0] payload_length_reg;
    always @(*) begin
        // Payload length = 7 bits
        phr[6:0] = payload_length_reg[6:0];
        // Remaining 5 bits = 0
        phr[11:7] = 5'b00000;
    end
    // 3) Serializer
    reg        serializer_active;
    reg [10:0] frame_bit_count;

    wire [10:0] payload_bits;
    wire [10:0] total_frame_bits;

    assign payload_bits =
        {3'b000, payload_length_reg} << 3;

    assign total_frame_bits =
        11'd12 + payload_bits;
    // Payload byte address
    assign payload_rd_addr =
        (frame_bit_count >= 11'd12) ?

        ((frame_bit_count - 11'd12) >> 3) :

        7'd0;
    // Bit position inside payload byte
    wire [2:0] payload_bit_select;
    assign payload_bit_select =

        (frame_bit_count >= 11'd12) ?

        (frame_bit_count - 11'd12) :
        3'd0;
    // Serialized output
    reg serial_bit;
    reg serial_valid;
    reg serial_last;
    always @(*) begin
        serial_bit   = 1'b0;
        serial_valid = 1'b0;
        serial_last  = 1'b0;
        if (serializer_active) begin
            serial_valid = 1'b1;
            // PHR
            if (frame_bit_count < 11'd12) begin

                serial_bit =
                    phr[frame_bit_count];
            end

            // Payload
            else begin
                   serial_bit = payload_rd_data[3'd7 - payload_bit_select];
            end


            // Last real bit before padding
            if (frame_bit_count ==
                total_frame_bits - 1'b1) begin

                serial_last = 1'b1;

            end

        end

    end
    // Serializer control
    always @(posedge clk) begin

        if (reset) begin

            serializer_active  <= 1'b0;
            frame_bit_count    <= 11'd0;
            payload_length_reg <= 8'd0;

        end

        else begin

            // Start frame
            if (start && !serializer_active) begin
                serializer_active  <= 1'b1;
                frame_bit_count    <= 11'd0;
                payload_length_reg <= payload_length;
            end
            else if (serializer_active) begin
                // Last real bit sent
                if (frame_bit_count ==
                    total_frame_bits - 1'b1) begin

                    serializer_active <= 1'b0;
                    frame_bit_count   <= 11'd0;
                end
                else begin
                    frame_bit_count <=
                        frame_bit_count + 1'b1;
                end
            end
        end
    end
    // 4) Zero Padding
    wire padded_bit;
    wire padded_valid;
    wire padded_last;

    zero_padding #(
        .N(6)
    ) u_zero_padding (
        .clk            (clk),
        .reset          (reset),
        .data_in        (serial_bit),
        .data_valid     (serial_valid),
        .data_last      (serial_last),
        .data_out       (padded_bit),
        .data_out_valid (padded_valid),
        .data_out_last  (padded_last)
    );
    // 5) DEMUX
    wire I_bit;
    wire I_valid;
    wire Q_bit;
    wire Q_valid;
    wire demux_done;
    iq_demux_1mbps u_demux (
        .clk        (clk),
        .reset      (reset),
        .data_in    (padded_bit),
        .data_valid (padded_valid),
        .data_last  (padded_last),
        .I_bit      (I_bit),
        .I_valid    (I_valid),
        .Q_bit      (Q_bit),
        .Q_valid    (Q_valid),
        .done       (demux_done)
    );
    // 6) 3-bit Symbol Formation
    reg [2:0] I_symbol_reg;
    reg [2:0] Q_symbol_reg;
    reg [1:0] I_count;
    reg [1:0] Q_count;
    reg I_symbol_ready;
    reg Q_symbol_ready;
    // 7) Symbol Mapper
    wire [3:0] I_mapped;
    wire [3:0] Q_mapped;
    symbol_mapper_1mbps u_mapper_I (
        .symbol   (I_symbol_reg),
        .codeword (I_mapped)
    );
    symbol_mapper_1mbps u_mapper_Q (
        .symbol   (Q_symbol_reg),
        .codeword (Q_mapped)
    );
    reg [3:0] I_codeword_mem [0:171];
    reg [3:0] Q_codeword_mem [0:171];
    reg [7:0] collect_count;
    // 9) Collect symbols and store codewords
    always @(posedge clk) begin
        if (reset) begin
            I_symbol_reg   <= 3'b000;
            Q_symbol_reg   <= 3'b000;
            I_count        <= 2'd0;
            Q_count        <= 2'd0;
            I_symbol_ready <= 1'b0;
            Q_symbol_ready <= 1'b0;
            collect_count  <= 8'd0;
        end

        else begin
            // Collect I
            if (I_valid) begin
                case (I_count)
                    2'd0: begin
                        I_symbol_reg[2] <= I_bit;
                        I_count <= 2'd1;
                    end
                    2'd1: begin
                        I_symbol_reg[1] <= I_bit;
                        I_count <= 2'd2;
                    end
                    2'd2: begin
                        I_symbol_reg[0] <= I_bit;
                        I_symbol_ready <= 1'b1;
                        I_count <= 2'd0;
                    end
                    default: begin
                        I_count <= 2'd0;
                    end
                endcase
            end
            // Collect Q
            if (Q_valid) begin
                case (Q_count)
                    2'd0: begin
                        Q_symbol_reg[2] <= Q_bit;
                        Q_count <= 2'd1;
                    end
                    2'd1: begin
                        Q_symbol_reg[1] <= Q_bit;
                        Q_count <= 2'd2;
                    end
                    2'd2: begin
                        Q_symbol_reg[0] <= Q_bit;
                        Q_symbol_ready <= 1'b1;
                        Q_count <= 2'd0;
                    end
                    default: begin
                        Q_count <= 2'd0;
                    end
                endcase
            end
            // Both symbols complete
            if (Q_valid &&
                (Q_count == 2'd2) &&
                I_symbol_ready) begin
                // I codeword
                I_codeword_mem[collect_count] <=
                    I_mapped;
                // Q_bit is the third bit and has not entered
                // Q_symbol_reg yet because of NBA timing.
                case ({Q_symbol_reg[2:1], Q_bit})
                    3'b000:
                        Q_codeword_mem[collect_count] <= 4'b1111;
                    3'b001:
                        Q_codeword_mem[collect_count] <= 4'b1010;
                    3'b010:
                        Q_codeword_mem[collect_count] <= 4'b1100;
                    3'b011:
                        Q_codeword_mem[collect_count] <= 4'b1001;
                    3'b100:
                        Q_codeword_mem[collect_count] <= 4'b0000;
                    3'b101:
                        Q_codeword_mem[collect_count] <= 4'b0101;
                    3'b110:
                        Q_codeword_mem[collect_count] <= 4'b0011;
                    3'b111:
                        Q_codeword_mem[collect_count] <= 4'b0110;
                endcase
                $display("STORE CW %0d: I_mem=%b Q_mem=%b I_mapped=%b Q_mapped=%b",
         collect_count,
         I_mapped,
         Q_mapped,
         I_mapped,
         Q_mapped);
                collect_count <=
                    collect_count + 1'b1;
                I_symbol_ready <= 1'b0;
                Q_symbol_ready <= 1'b0;
            end
        end
    end
    // 10) Detect end of collection
    wire collect_done;
    assign collect_done =
        demux_done &&
        (Q_valid && (Q_count == 2'd2)) &&
        I_symbol_ready;
    // 11) Main FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
        end
        else begin
            case (state)
                STATE_IDLE: begin

                    if (start)
                        state <= STATE_COLLECT;

                end
                STATE_COLLECT: begin

                    if (collect_done)
                        state <= STATE_SEND;

                end
                STATE_SEND: begin

                    if (ppdu_done_internal)
                        state <= STATE_DONE;

                end
                STATE_DONE: begin

                    state <= STATE_IDLE;

                end
                default: begin

                    state <= STATE_IDLE;

                end
            endcase
        end
    end
    //  P/S
    reg [7:0] send_count;
    reg [1:0] chip_count;
    wire ps_I_chip;
    wire ps_Q_chip;
    wire ps_chip_valid;
    wire ps_chip_last;
   

    // PPDU tells us when it is ready for payload.
    wire payload_ready_internal;
    // Current P/S chip
    assign ps_I_chip = I_codeword_mem[send_count][3 - chip_count];
assign ps_Q_chip = Q_codeword_mem[send_count][3 - chip_count];
    // Payload valid
    assign ps_chip_valid =
        (state == STATE_SEND) &&
        payload_ready_internal;
    // Last payload chip
    assign ps_chip_last =
        ps_chip_valid &&
        (send_count == collect_count - 1'b1) &&
        (chip_count == 2'd3);
// P/S counter
always @(posedge clk ) begin
    if (reset) begin
        send_count <= 8'd0;
        chip_count <= 2'd0;
    end
    else if (state != STATE_SEND) begin
        send_count <= 8'd0;
        chip_count <= 2'd0;
    end
    else if (payload_ready_internal) begin
        if (chip_count == 2'd3) begin
            chip_count <= 2'd0;

            if (send_count == collect_count - 1'b1)
                send_count <= 8'd0;
            else
                send_count <= send_count + 1'b1;
        end
        else begin
            chip_count <= chip_count + 1'b1;
        end
    end
end
    // Preamble / SFD generation
    reg [4:0] sfd_index;

    reg preamble_chip;
    reg SFD_chip;


    always @(*) begin

        // Preamble
        preamble_chip = 1'b1;

        // Default SFD
        SFD_chip = 1'b0;

        case (sfd_index)

            5'd0:  SFD_chip = 1'b0;
            5'd1:  SFD_chip = 1'b1;
            5'd2:  SFD_chip = 1'b1;
            5'd3:  SFD_chip = 1'b1;
            5'd4:  SFD_chip = 1'b0;
            5'd5:  SFD_chip = 1'b1;
            5'd6:  SFD_chip = 1'b0;
            5'd7:  SFD_chip = 1'b0;

            5'd8:  SFD_chip = 1'b1;
            5'd9:  SFD_chip = 1'b0;
            5'd10: SFD_chip = 1'b0;
            5'd11: SFD_chip = 1'b1;
            5'd12: SFD_chip = 1'b1;
            5'd13: SFD_chip = 1'b1;
            5'd14: SFD_chip = 1'b0;
            5'd15: SFD_chip = 1'b0;

            default:
                SFD_chip = 1'b0;

        endcase

    end
    // SFD counter

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            sfd_index <= 5'd0;

        end

        else begin

            if (state != STATE_SEND) begin

                sfd_index <= 5'd0;

            end

            else if (!payload_ready_internal) begin

                if (sfd_index < 5'd15)
                    sfd_index <= sfd_index + 1'b1;

            end

        end

    end

    //  PPDU Former


    ppdu_former_1mbps u_ppdu (

        .clk           (clk),
        .reset         (reset),

        .start_Tx      (state == STATE_SEND),

        .preamble_chip (preamble_chip),
        .SFD_chip      (SFD_chip),

        .I_in          (ps_I_chip),
        .Q_in          (ps_Q_chip),

        .payload_valid (ps_chip_valid),
        .payload_last  (ps_chip_last),

        .I_out         (I_ppdu),
        .Q_out         (Q_ppdu),

        .ppdu_valid    (ppdu_valid),
        .ppdu_last     (ppdu_last),

        .payload_ready (payload_ready_internal),

        .done_Tx       (ppdu_done_internal)

    );
    // DONE output

    always @(posedge clk) begin

        if (reset) begin
            done <= 1'b0;
        end
        else begin
            done <= 1'b0;
            if (ppdu_done_internal)
                done <= 1'b1;
        end
    end
endmodule