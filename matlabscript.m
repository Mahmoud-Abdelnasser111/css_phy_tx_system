clear;
clc;
close all;

addpath(pwd);

simulationParameters;
globalSettings();

samplingFreqMhz = 32;
dataRate        = 0;      % 0 = 1 Mbps
PHRlength       = 12;

PAYLOAD_BITS = 224;
PAYLOAD_BYTES = 28;

CHIRP_BITS  = 6;
CHIRP_SCALE = 2^(CHIRP_BITS-1)-1;   % 31

EXPECTED_SAMPLES = 9984;

fid = fopen('payload.txt','r');

if fid == -1
    error('ERROR: Cannot open payload.txt');
end

incomingStream = [];

while ~feof(fid)

    line = fgetl(fid);

    if ischar(line)

        line = strtrim(line);

        if ~isempty(line)

            % Each line must contain exactly 8 bits
            if length(line) ~= 8
                error('ERROR: Payload line is not 8 bits: %s', line);
            end

            % Check that only 0/1 exist
            if any(line ~= '0' & line ~= '1')
                error('ERROR: Invalid binary data in payload.txt: %s', line);
            end

            bits = line - '0';

            incomingStream = [incomingStream bits];

        end
    end
end

fclose(fid);



payloadBits  = length(incomingStream);
payloadBytes = payloadBits / 8;

if payloadBits ~= PAYLOAD_BITS
    error('ERROR: Expected %d payload bits, got %d.', ...
        PAYLOAD_BITS, payloadBits);
end

if payloadBytes ~= PAYLOAD_BYTES
    error('ERROR: Expected %d payload bytes, got %d.', ...
        PAYLOAD_BYTES, payloadBytes);
end



% Generate floating-point chirp

chirpSeq = chirpSequenceGenerator(1, samplingFreqMhz);

if size(chirpSeq,1) ~= 38 || size(chirpSeq,2) ~= 4
    error('ERROR: Expected chirp size = 38 x 4');
end


% Quantize chirp for RTL ROM

chirpSeq_Tx = floor(chirpSeq * CHIRP_SCALE);



fid_real = fopen('chirp_full_real.txt','wt');

if fid_real == -1
    error('ERROR: Cannot create chirp_full_real.txt');
end

fid_imag = fopen('chirp_full_image.txt','wt');

if fid_imag == -1
    fclose(fid_real);
    error('ERROR: Cannot create chirp_full_image.txt');
end


for k = 1:4

    for n = 1:38

        real_val = real(chirpSeq_Tx(n,k));
        imag_val = imag(chirpSeq_Tx(n,k));

        % Convert signed 6-bit value to 6-bit two's complement binary
        real_bin = dec2bin(mod(real_val,64),6);
        imag_bin = dec2bin(mod(imag_val,64),6);

        fprintf(fid_real,'%s\n',real_bin);
        fprintf(fid_imag,'%s\n',imag_bin);

    end

end


fclose(fid_real);
fclose(fid_imag);


% Run MATLAB CSS transmitter

TxchirpSequences = ChirpSpreadSpectrum_Tx( ...
    incomingStream, ...
    dataRate, ...
    chirpSeq_Tx);


% Convert final waveform to integer


TxchirpSequences_Tx = floor(TxchirpSequences);

TxDQPSKReal_tofile = real(TxchirpSequences_Tx);
TxDQPSKImag_tofile = imag(TxchirpSequences_Tx);


% Check final output length

if length(TxchirpSequences_Tx) ~= EXPECTED_SAMPLES

    error('ERROR: Expected %d final samples, got %d.', ...
        EXPECTED_SAMPLES, ...
        length(TxchirpSequences_Tx));

end


% Convert final output to signed 8-bit


TX_BITS = 8;

reTx = fi(TxDQPSKReal_tofile,1,TX_BITS,0);
imTx = fi(TxDQPSKImag_tofile,1,TX_BITS,0);


% Write FINAL REAL Golden


fid = fopen('TxChirpDQPSK_real_RTLmatched.txt','wt');

if fid == -1
    error('ERROR: Cannot create final REAL Golden file');
end

for i = 1:length(reTx)

    fprintf(fid,'%s\n',bin(reTx(i)));

end

fclose(fid);

% Write FINAL IMAG Golden


fid = fopen('TxChirpDQPSK_imag_RTLmatched.txt','wt');

if fid == -1
    error('ERROR: Cannot create final IMAG Golden file');
end

for i = 1:length(imTx)

    fprintf(fid,'%s\n',bin(imTx(i)));

end

fclose(fid);


% Final confirmation


fprintf('\n==============================================\n');
fprintf('MATLAB GOLDEN FILES GENERATED\n');
fprintf('==============================================\n');

fprintf('Payload bytes      = %d\n', payloadBytes);
fprintf('Final TX samples   = %d\n', length(TxchirpSequences_Tx));

fprintf('\nGenerated files:\n');
fprintf('1. chirp_full_real.txt\n');
fprintf('2. chirp_full_image.txt\n');
fprintf('3. TxChirpDQPSK_real_RTLmatched.txt\n');
fprintf('4. TxChirpDQPSK_imag_RTLmatched.txt\n');


fprintf('DONE\n');
