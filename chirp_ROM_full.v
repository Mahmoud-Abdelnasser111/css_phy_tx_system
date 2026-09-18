module chirp_ROM_full (
    input  [7:0] address,

    output signed [5:0] chirp_seq_out_real,
    output signed [5:0] chirp_seq_out_image
);

    reg signed [5:0] chirp_rom_real  [0:151];
    reg signed [5:0] chirp_rom_image [0:151];

    initial begin
      
    $readmemb("chirp_full_real.txt", chirp_rom_real);
    $readmemb("chirp_full_image.txt", chirp_rom_image);
end
    

    assign chirp_seq_out_real  = chirp_rom_real[address];
    assign chirp_seq_out_image = chirp_rom_image[address];

endmodule