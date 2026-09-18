module chirp_ROM (
       input [5:0]address_real ,
       input [5:0]address_image ,
       output [5:0]chirp_seq_out_real,
       output [5:0]chirp_seq_out_image

);
 
reg signed [5:0]chirp_rom_real[37:0];
reg signed [5:0]chirp_rom_image[37:0];

// store first sub_chirp only
// first 38 samples for real part and second 38 samples for image part

initial
begin
     $readmemb("../rtl/first_subchirp_real.txt",chirp_rom_real);
     $readmemb("../rtl/first_subchirp_image.txt",chirp_rom_image);
end


   assign chirp_seq_out_real=chirp_rom_real[address_real];
   assign chirp_seq_out_image=chirp_rom_image[address_image];


endmodule 

