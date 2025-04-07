% Clear any existing serial connections
delete(instrfindall);

% Create serial object (adjust COM port as needed)
port = 'COM4'; % Replace with your Arduino's COM port
baudRate = 115200; % Match Arduino's baud rate
s = serialport(port, baudRate);

% Configure serial port
configureTerminator(s, "LF"); % Line feed as terminator (matches Serial.println)

% Parameters
recordingTime = 20; % Recording duration in seconds (matches Arduino)
sampleRate = 16000; % Match Arduino sketch
numSamples = recordingTime * sampleRate; % Total samples to collect (320,000)
audioData = zeros(numSamples, 1, 'int16'); % Preallocate as 16-bit integers (PCM)

% Read data from serial port
disp('Recording started...');
tic; % Start timer
for i = 1:numSamples
    line = readline(s); % Read one line
    if contains(line, 'Recording complete') % Stop if Arduino signals end
        audioData = audioData(1:i-1); % Trim excess preallocated space
        break;
    end
    audioData(i) = int16(str2double(line)); % Convert to 16-bit PCM
end
disp('Recording finished.');
elapsedTime = toc;
disp(['Elapsed time: ', num2str(elapsedTime), ' seconds']);

% Clean up
clear s;

% Save to CSV file as PCM data
csvFileName = 'normalBreathingTest3.csv';
writematrix(audioData, csvFileName);
disp(['PCM data saved to ', csvFileName]);

% Optional: Plot the data
figure;
plot(audioData);
title('Recorded PCM Audio Data');
xlabel('Sample Number');
ylabel('Amplitude (16-bit PCM)');