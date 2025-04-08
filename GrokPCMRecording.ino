#include <PDM.h> // Included with Seeed_Arduino_Mic

// Buffer to store PDM data
#define SAMPLE_RATE 16000 // 16 kHz sample rate
#define SAMPLE_BUFFER_SIZE 256 // Number of samples per buffer
#define RECORDING_TIME 20000 // 20 seconds in milliseconds

int16_t sampleBuffer[SAMPLE_BUFFER_SIZE]; // 16-bit PCM samples
volatile int samplesRead;
unsigned long startTime;
bool recording = true;

void setup() {
  Serial.begin(115200); // High baud rate for faster data transfer
  while (!Serial); // Wait for Serial Monitor to open

  // Initialize PDM microphone
  PDM.onReceive(onPDMdata); // Callback when data is ready
  if (!PDM.begin(1, SAMPLE_RATE)) { // Mono channel, 16 kHz
    Serial.println("Failed to start PDM!");
    while (1);
  }

  startTime = millis(); // Record start time
}

void loop() {
  // Check if 20 seconds have elapsed
  if (millis() - startTime >= RECORDING_TIME) {
    if (recording) {
      Serial.println("Recording complete.");
      PDM.end(); // Stop PDM microphone
      recording = false; // Stop sending data
    }
    return; // Exit loop after recording
  }

  if (samplesRead && recording) {
    // Send the audio data over Serial as PCM values
    for (int i = 0; i < samplesRead; i++) {
      Serial.println(sampleBuffer[i]); // PCM 16-bit integer per line
    }
    samplesRead = 0; // Reset the sample count
  }
}

// Callback function to handle PDM data
void onPDMdata() {
  int bytesAvailable = PDM.available();
  if (bytesAvailable > 0) {
    samplesRead = PDM.read(sampleBuffer, bytesAvailable) / sizeof(int16_t);
  }
}