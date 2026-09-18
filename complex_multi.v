module complex_multi (
    input  signed [5:0]chirp_seq_real  ,
    input  signed [5:0]chirp_seq_image ,
    input  signed [1:0] DQPSK_real     ,
    input  signed [1:0] DQPSK_image    ,
    output signed [7:0] tx_real    ,
    output signed [7:0] tx_image 
);

    assign tx_real  = (chirp_seq_real  * DQPSK_real) - (chirp_seq_image * DQPSK_image);
    assign tx_image = (chirp_seq_real  * DQPSK_image) + (chirp_seq_image * DQPSK_real);

/*
   always@(*)
   begin
    case({DQPSK_real,DQPSK_image})
     4'b1111 : 
     begin
        tx_real =  chirp_seq_image-chirp_seq_real;
        tx_image=-(chirp_seq_image+chirp_seq_real);
     end

     4'b1101 : 
     begin
        tx_real =-(chirp_seq_image+chirp_seq_real);
        tx_image=(-chirp_seq_image+chirp_seq_real);
     end

     4'b0111 : 
     begin
        tx_real =  chirp_seq_image+chirp_seq_real;
        tx_image= (chirp_seq_image-chirp_seq_real);
     end

     4'b0101 : 
     begin
        tx_real = -chirp_seq_image+chirp_seq_real;
        tx_image= (chirp_seq_image+chirp_seq_real);
     end

     default :
     begin
        tx_real = 8'bx;
        tx_image= 8'bx;
     end

    endcase
   end*/
endmodule 