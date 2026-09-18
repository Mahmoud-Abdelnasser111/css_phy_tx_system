module css_phy_tx_1mbps_top (

    input  wire        clk,
    input  wire        reset,
    input  wire        start_Tx,

    input  wire [7:0]  payloadLength,

    input  wire        payload_wr_en,
    input  wire [6:0]  payload_wr_addr,
    input  wire [7:0]  payload_wr_data,

    output wire [7:0]  Tx_real,
    output wire [7:0]  Tx_imag,

    output wire        Tx_valid,
    output wire        done_Tx

);

    
    // PART TOP outputs
  

    wire I_ppdu;
    wire Q_ppdu;

    wire ppdu_valid;
    wire ppdu_last;

    wire part_done;


  
    // QPSK mapper outputs
  

    wire signed [1:0] qpsk_real;
    wire signed [1:0] qpsk_imag;

    reg qpsk_valid;
    reg qpsk_last;


    // PART TOP


    part_top_1mbps u_part_top (

        .clk            (clk),
        .reset          (reset),
        .start          (start_Tx),

        .payload_length (payloadLength),

        .payload_wr_en  (payload_wr_en),
        .payload_wr_addr(payload_wr_addr),
        .payload_wr_data(payload_wr_data),

        .I_ppdu         (I_ppdu),
        .Q_ppdu         (Q_ppdu),

        .ppdu_valid     (ppdu_valid),
        .ppdu_last      (ppdu_last),

        .done           (part_done)

    );


    // QPSK MAPPER

    qpsk_mapper u_qpsk_mapper (

        .clk        (clk),
        .reset      (reset),

        .I          (I_ppdu),
        .Q          (Q_ppdu),

        .Xn_real    (qpsk_real),
        .Xn_imj     (qpsk_imag)

    );


    // Align valid/last with registered QPSK mapper
  

    always @(posedge clk) begin

        if (reset) begin

            qpsk_valid <= 1'b0;
            qpsk_last  <= 1'b0;

        end

        else begin

            qpsk_valid <= ppdu_valid;
            qpsk_last  <= ppdu_last;

        end

    end


   
    // DQPSK + CHIRP
  

    chirp_DQPSK_int u_chirp_dqpsk (

        .I_in      (qpsk_real),
        .Q_in      (qpsk_imag),

        .clk       (clk),
        .rst       (reset),

        .valid_in  (qpsk_valid),
        .last_in   (qpsk_last),

        .tx_real   (Tx_real),
        .tx_image  (Tx_imag),

        .tx_valid  (Tx_valid),
        .done      (done_Tx)

    );


endmodule