module iq_demux_1mbps (
    input  wire clk,
    input  wire reset,

    input  wire data_in, // bit entering the demux 
    input  wire data_valid, // checks if the data entered is true 
    input  wire data_last, // checks last bit in frame 

    output reg  I_bit, // bit going to I path 
    output reg  I_valid, // because I dont get out every clock cycle so we must check for every I its ture 

    output reg  Q_bit, // bit going to Q path 
    output reg  Q_valid, // because Q dont get out every clock cycle so we must check for every I its ture 

    output reg  done // end of the frame flag 
);

    // 0 -> next bit goes to I
    // 1 -> next bit goes to Q
    reg iq_select;

    always @(posedge clk) begin

        if (reset) begin

            I_bit    <= 1'b0;
            Q_bit    <= 1'b0;

            I_valid  <= 1'b0;
            Q_valid  <= 1'b0;

            done     <= 1'b0;

            iq_select <= 1'b0;
        end

        else begin

            // Default
            I_valid <= 1'b0;
            Q_valid <= 1'b0;
            done    <= 1'b0;

            if (data_valid) begin

                // =========================================
                // I
                // =========================================
                if (iq_select == 1'b0) begin

                    I_bit   <= data_in;
                    I_valid <= 1'b1;

                    iq_select <= 1'b1;

                end

                // =========================================
                // Q
                // =========================================
                else begin

                    Q_bit   <= data_in;
                    Q_valid <= 1'b1;

                    iq_select <= 1'b0;

                end

                // =========================================
                // Last input bit
                // =========================================
                if (data_last) begin

                    done <= 1'b1;

                    iq_select <= 1'b0;

                end

            end
        end
    end

endmodule