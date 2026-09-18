module zero_padding #(
 parameter N = 6
)(
    input  wire clk,
    input  wire reset,

    input  wire data_in, // data entered to the zero padding block 
    input  wire data_valid, //makes sure X doesnt enter if x entered doesnt take it 
    input  wire data_last, // become 1 when last bit entered of the data

    output reg  data_out, // data leaves the zero padding block (data itself)
    output reg data_out_valid, // makes sure all data out is valid if last bit is 0 it tells its from data or the padding
    output reg data_out_last // tells if is this last bit or what after padding (flag)
);

    localparam BLOCK_BITS = N; // its for deal with blocks of 6 bits
    localparam COUNT_WIDTH = 3;

    reg [2:0] bit_count; // counts the bits entered 
    reg [COUNT_WIDTH-1:0] padding_count;  // counts how many zeros we must add 
    reg padding_active; // flag activates the padding 

    always @(posedge clk) begin

        if (reset) begin
            data_out       <= 1'b0;
            data_out_valid <= 1'b0;
            data_out_last  <= 1'b0;

            bit_count      <= 0;
            padding_count  <= 0;
            padding_active <= 1'b0;
        end

        else begin

            // Default values
            data_out       <= 1'b0;
            data_out_valid <= 1'b0;
            data_out_last  <= 1'b0;

            // ============================================
            // Receive normal data
            // ============================================
            if (data_valid && !padding_active) begin

                // Pass input bit directly to output
                data_out       <= data_in;
                data_out_valid <= 1'b1;

                // ----------------------------------------
                // Last real input bit
                // ----------------------------------------
                if (data_last) begin

                    // Is total number of bits already
                    // a multiple of BLOCK_BITS?
                    if (((bit_count + 1'b1) % BLOCK_BITS) == 0) begin //+1 to add the current bit to the block 

                        // No padding required
                        data_out_last <= 1'b1;

                        bit_count <= 0; 
                    end

                    else begin

                        // Padding required
                        padding_active <= 1'b1;

                        padding_count <=
                            BLOCK_BITS -
                            ((bit_count + 1'b1) % BLOCK_BITS);

                        bit_count <= 0; // when we finish padding return it to zero
                    end
                end

                // ----------------------------------------
                // Normal bit
                // ----------------------------------------
                else begin

                    if (bit_count == BLOCK_BITS-1)
                        bit_count <= 0;
                    else
                        bit_count <= bit_count + 1'b1;

                end
            end

            // ============================================
            // Generate zero padding
            // ============================================
            else if (padding_active) begin

                // Padding bit = 0
                data_out       <= 1'b0;
                data_out_valid <= 1'b1;

                // Last padding bit
                if (padding_count == 1) begin

                    data_out_last  <= 1'b1;

                    padding_count  <= 0;
                    padding_active <= 1'b0;
                end

                else begin

                    padding_count <= padding_count - 1'b1;

                end
            end
        end
    end

endmodule