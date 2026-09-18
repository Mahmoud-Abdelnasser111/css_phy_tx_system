module css_phy_tx_1mbps_top_tb;
    localparam integer PAYLOAD_BYTES  = 28;
    localparam integer GOLDEN_SAMPLES = 9984;
    reg clk;
    reg reset;
    reg start_Tx;
    reg [7:0] payloadLength;
    reg        payload_wr_en;
    reg [6:0]  payload_wr_addr;
    reg [7:0]  payload_wr_data;
    wire [7:0] Tx_real;
    wire [7:0] Tx_imag;
    wire Tx_valid;
    wire done_Tx;
    reg [7:0] payload_mem [0:PAYLOAD_BYTES-1];



    reg [7:0] tx_real_golden [0:GOLDEN_SAMPLES-1];
    reg [7:0] tx_imag_golden [0:GOLDEN_SAMPLES-1];
   
  
    integer payload_file;
    integer tx_real_file;
    integer tx_imag_file;
    integer rtl_real_dump_file;
    integer rtl_imag_dump_file;
  

    // Counters

    integer i;
    integer sample_count;
    integer error_count;
    integer timeout_count;
   

    // DUT
    css_phy_tx_1mbps_top dut (
        .clk             (clk),
        .reset           (reset),
        .start_Tx        (start_Tx),
        .payloadLength   (payloadLength),
        .payload_wr_en   (payload_wr_en),
        .payload_wr_addr (payload_wr_addr),
        .payload_wr_data (payload_wr_data),
        .Tx_real         (Tx_real),
        .Tx_imag         (Tx_imag),
        .Tx_valid        (Tx_valid),
        .done_Tx         (done_Tx)
    );
    // Clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;

    end
    // Convert unsigned 8-bit two's complement to signed

    function integer signed8_to_int;

        input [7:0] value;
        begin

            if (value[7])
                signed8_to_int = value - 256;

            else
                signed8_to_int = value;

        end

    endfunction
    // Load payload + final MATLAB golden
    initial begin
        // Initial values
        reset           = 1'b1;
        start_Tx        = 1'b0;
        payloadLength   = 8'd0;
        payload_wr_en   = 1'b0;
        payload_wr_addr = 7'd0;
        payload_wr_data = 8'd0;
        sample_count    = 0;
        error_count     = 0;
        timeout_count   = 0;
      
        // Open payload
        payload_file = $fopen("original_payload.txt", "r");
        if (payload_file == 0) begin
            $display(
                "ERROR: Cannot open original_payload.txt"

            );
            $stop;

        end

        for (i = 0; i < PAYLOAD_BYTES; i = i + 1) begin
            if ($fscanf(
             payload_file,
                "%b",
                payload_mem[i]
            ) != 1) begin
                $display(
                    "ERROR: Cannot read payload byte %0d",
                    i
                );
                $stop;
            end
        end
        $fclose(payload_file);
        // Open final REAL golden
        tx_real_file = $fopen(
            "TxChirpDQPSK_real_RTLmatched.txt",
            "r"
        );
        if (tx_real_file == 0) begin
            $display(
                "ERROR: Cannot open TxChirpDQPSK_real_RTLmatched.txt"
            );
            $stop;
        end
        for (i = 0; i < GOLDEN_SAMPLES; i = i + 1) begin
            if ($fscanf(
                tx_real_file,
                "%b",
                tx_real_golden[i]
            ) != 1) begin
                $display(
                    "ERROR: Cannot read final REAL sample %0d",
                    i
                );
                $stop;
            end
        end
        $fclose(tx_real_file);
        // Open final IMAG golden
        tx_imag_file = $fopen(
            "TxChirpDQPSK_imag_RTLmatched.txt",
            "r"
        );

        if (tx_imag_file == 0) begin
            $display(
                "ERROR: Cannot open TxChirpDQPSK_imag_RTLmatched.txt"
            );
            $stop;
        end
        for (i = 0; i < GOLDEN_SAMPLES; i = i + 1) begin

            if ($fscanf(
                tx_imag_file,
                "%b",
                tx_imag_golden[i]
            ) != 1) begin
                $display(
                    "ERROR: Cannot read final IMAG sample %0d",
                    i
                );
                $stop;
            end
        end
        $fclose(tx_imag_file);
    // Open files for ACTUAL RTL TX output
    rtl_real_dump_file = $fopen("RTL_Tx_real.txt", "w");
    rtl_imag_dump_file = $fopen("RTL_Tx_imag.txt", "w");
    if (rtl_real_dump_file == 0) begin
        $display("ERROR: Cannot create RTL_Tx_real.txt");
        $stop;
    end
    if (rtl_imag_dump_file == 0) begin
        $display("ERROR: Cannot create RTL_Tx_imag.txt");
        $stop;
    end
        $display("");

        $display("==============================================");

        $display(" FULL CSS PHY 1 Mbps SYSTEM TEST");

        $display("==============================================");

        $display("Payload bytes          : %0d", PAYLOAD_BYTES);

        $display("Payload loaded         : YES");

        $display("Final MATLAB Golden    : LOADED");
        // Reset
        #20;
        reset = 1'b0;
        // Write payload RAM
        $display("");
        $display("Writing payload RAM...");
        for (i = 0; i < PAYLOAD_BYTES; i = i + 1) begin
            @(negedge clk);
            payload_wr_en   = 1'b1;
            payload_wr_addr = i[6:0];
            payload_wr_data = payload_mem[i];
        end

        @(negedge clk);
        payload_wr_en   = 1'b0;
        payload_wr_addr = 7'd0;
        payload_wr_data = 8'd0;
        $display("Payload RAM write complete.");
        payloadLength = PAYLOAD_BYTES;
        // Start transmission
        @(negedge clk);
        start_Tx = 1'b1;
        @(negedge clk);
        start_Tx = 1'b0;
        $display("");
        $display("TX STARTED");
        // Wait for DONE
        timeout_count = 0;
        while (!done_Tx && timeout_count < 15000) begin
            @(posedge clk);
            timeout_count = timeout_count + 1;
        end
        if (!done_Tx) begin
            $display("");
            $display(
                "ERROR: TIMEOUT waiting for DONE"
            );
            $stop;
        end
        $display("");
        $display("DONE detected.");
        // Final result
        #2;
        $display("");

        $display("==============================================");

        $display(" FULL SYSTEM VERIFICATION RESULT");

        $display("==============================================");

      
       
        $display(
            "Total mismatches    : %0d",
            error_count
        );
        if ((sample_count == GOLDEN_SAMPLES) &&
            (error_count == 0)) begin
            $display("");
            $display(
                "PASS: FULL CSS PHY TX == MATLAB GOLDEN"
            );
        end

        else begin

            $display("");

            $display(

                "FAIL: FULL CSS PHY TX DOES NOT MATCH GOLDEN"
            );
        end

        $display("==============================================");

        $fclose(rtl_real_dump_file);
    $fclose(rtl_imag_dump_file);
    $stop;
    end
    // Capture and compare final TX samples
    always @(negedge clk) begin
        if (!reset && Tx_valid) begin
            if (sample_count < GOLDEN_SAMPLES) begin
                // Compare current TX sample
                if (
                    ($signed(Tx_real) !==
                     signed8_to_int(
                         tx_real_golden[sample_count]
                     ))
                    ||
                    ($signed(Tx_imag) !==

                     signed8_to_int(

                         tx_imag_golden[sample_count]

                     ))

                ) begin

                    error_count = error_count + 1;

                    // Print only first 30 mismatches

                    if (error_count <= 30) begin

                        $display(

                            "MISMATCH %0d: RTL=(%0d,%0d) EXPECTED=(%0d,%0d)",

                            sample_count,

                            $signed(Tx_real),

                            $signed(Tx_imag),

                            signed8_to_int(

                                tx_real_golden[sample_count]

                            ),

                            signed8_to_int(

                                tx_imag_golden[sample_count]

                            )

                        );

                    end

                end

                else begin

                    // Print first 10 matches

                    if (sample_count < 10) begin

                        $display(

                            "MATCH %0d: RTL=(%0d,%0d)",

                            sample_count,

                            $signed(Tx_real),

                            $signed(Tx_imag)

                        );

                    end

                end

            // Save ACTUAL RTL output for MSE calculation
            $fwrite(rtl_real_dump_file, "%0d\n", $signed(Tx_real));
            $fwrite(rtl_imag_dump_file, "%0d\n", $signed(Tx_imag));

            sample_count = sample_count + 1;

            end

        end

    end

endmodule