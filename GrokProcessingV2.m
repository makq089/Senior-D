%4/1/25

% Read PCM data from your recorded file
rawPCM = readmatrix('normalBreathingTest3.csv'); % Update to your file

%Plot the data
figure;
plot(rawPCM);
title('Recorded PCM Audio Data');
xlabel('Sample Number');
ylabel('Amplitude (16-bit PCM)');

fs = 16000; % Sampling frequency (matches your recording)
fn = fs / 2; % Nyquist frequency
fc = 7.5; % High-pass frequency cutoff (DC offset)
fc1 = 2500; % Low-pass frequency cutoff (remove aliasing)
fc2 = [100 1600]; % Bandpass frequency cutoff (respiratory sounds)

% Remove DC offset explicitly
rawPCM = rawPCM - mean(rawPCM); % Center around 0

% Amplify signal due to low amplitude
gain = 10; % Adjust as needed, monitor for clipping
rawPCM = rawPCM * gain;

% Design filters
[b, a] = butter(1, fc/fn, 'high'); % DC offset high-pass Butterworth filter
[b1, a1] = butter(8, fc1/fn, 'low'); % Anti-aliasing low-pass filter
[b2, a2] = butter(4, [fc2(1)/fn fc2(2)/fn], 'bandpass'); % Bandpass filter

% Apply filters using zero-phase filtering (filtfilt)
y = filtfilt(b, a, rawPCM);
y1 = filtfilt(b1, a1, y);
y2 = filtfilt(b2, a2, y1);

% Time vector
t = (0:length(rawPCM)-1) / fs; 

% Plot time-domain signals
figure;
% subplot(2,1,1);
% plot(t, rawPCM);
% title('Raw PCM Data (Time Domain)');
% xlabel('Time (s)');
% ylabel('Amplitude');
% xlim([0, 0.5]); % Display first 0.5 sec
% grid on;

%subplot(2,1,2);
plot(t, y2, 'r');
title('Filtered PCM Data (Time Domain)');
xlabel('Time (s)');
ylabel('Amplitude');
xlim([0, 0.5]);
grid on;

% ---- Compute and Plot FFT ----
N = length(y2);  
disp(['N = ', num2str(N), ', N/2 = ', num2str(N/2)]); % Debug length
f = (0:N-1) * (fs/N); % Frequency axis
Y = fft(y2); 
Y_magnitude = abs(Y); % Magnitude without normalization

figure;
half_N = floor(N/2); % Ensure integer index
plot(f(1:half_N), 20*log10(Y_magnitude(1:half_N))); % dB scale (Fixed Line 57)
title('Magnitude Spectrum of Filtered Signal');
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
grid on;

% ---- Segmenting the Sections ----
segmentLength = 0.25 * fs; % 250 ms segment (4000 samples)
overlap = 0.2 * fs; % 200 ms overlap (3200 samples)
stepSize = segmentLength - overlap; % Hop size (800 samples)
num_segments = floor((length(y2) - segmentLength) / stepSize) + 1;

segmented_data = zeros(segmentLength, num_segments);
for i = 1:num_segments
    start_idx = round((i-1) * stepSize + 1); % Ensure integer
    end_idx = round(start_idx + segmentLength - 1); % Ensure integer
    if end_idx > length(y2)
        break;
    end
    segmented_data(:, i) = y2(start_idx:end_idx);
end

% FFT per segment
window = hann(segmentLength);
NFFT = segmentLength;
frequencies = (0:NFFT/2-1) * (fs / NFFT);

figure;
hold on;
for i = 1:num_segments
    segment = segmented_data(:, i) .* window;
    fft_data = fft(segment, NFFT);
    power_spectrum = (abs(fft_data(1:NFFT/2)).^2) / NFFT;
    plot(frequencies, 10*log10(power_spectrum));
end
title('Power Spectrum of Segmented Data');
xlabel('Frequency (Hz)');
ylabel('Power (dB)');
grid on;
hold off;

% ---- Spectrogram ----
figure;
spectrogram(y2, hann(segmentLength), overlap, NFFT, fs, 'yaxis');
% Add color bar with dB label
c = colorbar;
c.Label.String = 'Power (dB)';
c.Label.FontSize = 12;
clim([-100 -30]);
title('Spectrogram of Filtered Signal');

% ---- Spectral Integration and Classification ----
SI_0_250 = zeros(1, num_segments);
SI_250_500 = zeros(1, num_segments);
SI_500_1000 = zeros(1, num_segments);
SI_0_1000 = zeros(1, num_segments);

abnormal_segments = 0;
abnormal_duration = 0;

% Store NSI and scores for the last segment for debugging
last_NSI_0_250 = 0;
last_NSI_250_500 = 0;
last_NSI_500_1000 = 0;
last_Score1 = 0;
last_Score2 = 0;

for i = 1:num_segments
    segment = segmented_data(:, i) .* window;
    fft_data = fft(segment, NFFT);
    power_spectrum = abs(fft_data(1:NFFT/2)).^2; % Raw power spectrum
    
    % Spectral Integration
    idx_0_250 = (frequencies >= 0 & frequencies < 250);
    idx_250_500 = (frequencies >= 250 & frequencies < 500);
    idx_500_1000 = (frequencies >= 500 & frequencies < 1000);
    idx_0_1000 = (frequencies >= 0 & frequencies < 1000);

    SI_0_250(i) = sum(power_spectrum(idx_0_250));
    SI_250_500(i) = sum(power_spectrum(idx_250_500));
    SI_500_1000(i) = sum(power_spectrum(idx_500_1000));
    SI_0_1000(i) = sum(power_spectrum(idx_0_1000));

    % Normalize Spectral Integration (NSI)
    if SI_0_1000(i) > 0
        NSI_0_250 = SI_0_250(i) / SI_0_1000(i);
        NSI_250_500 = SI_250_500(i) / SI_0_1000(i);
        NSI_500_1000 = SI_500_1000(i) / SI_0_1000(i);
    else
        NSI_0_250 = 0;
        NSI_250_500 = 0;
        NSI_500_1000 = 0;
    end
    
    % Compute LDA Scores
    Score1 = -230.54489 + 402.72499 * NSI_0_250 + 500.32269 * NSI_250_500 + 677.28994 * NSI_500_1000;
    Score2 = -266.87228 + 418.88239 * NSI_0_250 + 554.36286 * NSI_250_500 + 699.35894 * NSI_500_1000;

    % Store last segment’s values for debugging
    last_NSI_0_250 = NSI_0_250;
    last_NSI_250_500 = NSI_250_500;
    last_NSI_500_1000 = NSI_500_1000;
    last_Score1 = Score1;
    last_Score2 = Score2;

    % Classify segment
    if Score1 < Score2
        abnormal_segments = abnormal_segments + 1;
        abnormal_duration = abnormal_duration + (segmentLength - overlap) / fs;
    end
end

% Final Classification
if abnormal_duration > 0.25
    disp('Wheezing detected: Abnormal breathing sounds exceed 250 ms.');
else
    disp('Normal breathing detected.');
end

% Debug/check expected ranges of NSI (last segment)
disp(['Last Segment: NSI_0_250 = ', num2str(last_NSI_0_250)]);
disp(['NSI_250_500 = ', num2str(last_NSI_250_500)]);
disp(['NSI_500_1000 = ', num2str(last_NSI_500_1000)]);
disp(['Score1 = ', num2str(last_Score1), ', Score2 = ', num2str(last_Score2)]);
disp(['Abnormal segments: ', num2str(abnormal_segments)]);
disp(['Abnormal duration: ', num2str(abnormal_duration), ' s']);

% Optional: Save filtered data for further use
%audiowrite('filtered_respiratory.wav', y2, fs);