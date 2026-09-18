clear;
clc;

EXPECTED_SAMPLES = 9984;
CHIRP_BITS       = 6;
SCALE            = 2^(CHIRP_BITS-1)-1;     % 31

%% Load ACTUAL RTL TX output
rtl_real = load('RTL_Tx_real.txt');
rtl_imag = load('RTL_Tx_imag.txt');

if length(rtl_real) ~= EXPECTED_SAMPLES || ...
   length(rtl_imag) ~= EXPECTED_SAMPLES
    error('RTL sample count mismatch.');
end

rtl = rtl_real(:) + 1j*rtl_imag(:);

%% Read the exact same payload used by the RTL testbench
fid = fopen('original_payload.txt','r');
if fid == -1
    error('Cannot open original_payload.txt');
end

incomingStream = [];

while ~feof(fid)
    line = fgetl(fid);

    if ischar(line)
        line = strtrim(line);

        if ~isempty(line)
            if length(line) ~= 8 || any(line ~= '0' & line ~= '1')
                error('Invalid payload line: %s', line);
            end

            incomingStream = [incomingStream (line-'0')];
        end
    end
end

fclose(fid);

%% Generate UNQUANTIZED floating-point MATLAB reference we didnt use floor
samplingFreqMhz = 32;
dataRate = 0;               % 1 Mbps
chirpIndex = 1;

chirpSeq_Tx = chirpSequenceGenerator(chirpIndex, samplingFreqMhz);

% This is the same call used by the working MATLAB golden script.
% IMPORTANT: do not floor() or fi() this waveform before the MSE.
TxchirpSequences = ChirpSpreadSpectrum_Tx( ...
    incomingStream, ...
    dataRate, ...
    chirpSeq_Tx);

TxchirpSequences = TxchirpSequences(:);

if length(TxchirpSequences) ~= EXPECTED_SAMPLES
    error('MATLAB floating-point output must contain %d samples.', ...
          EXPECTED_SAMPLES);
end

%% Put MATLAB floating reference in the same amplitude domain as RTL
matlab_float_scaled = TxchirpSequences * SCALE;

%% Normalized complex MSE
error_signal = rtl - matlab_float_scaled;

MSE = sum(abs(error_signal).^2) / ...
      sum(abs(matlab_float_scaled).^2);

fprintf('\n============================================\n');
fprintf('ACTUAL RTL vs MATLAB FLOATING-POINT MSE\n');
fprintf('============================================\n');
fprintf('Samples           = %d\n', EXPECTED_SAMPLES);
fprintf('Fixed-point bits  = %d\n', CHIRP_BITS);
fprintf('Scale             = %d\n', SCALE);
fprintf('MSE               = %.10f\n', MSE);
fprintf('Required limit    = 0.005\n');

if MSE < 0.005
    fprintf('RESULT            = PASS\n');
else
    fprintf('RESULT            = FAIL\n');
end

%% Optional plot
figure;
plot(real(matlab_float_scaled));
hold on;
plot(real(rtl), '--');
grid on;
xlabel('Sample');
ylabel('Real amplitude');
title('ACTUAL RTL vs MATLAB Floating-Point Reference');
legend('MATLAB float (scaled)', 'RTL');