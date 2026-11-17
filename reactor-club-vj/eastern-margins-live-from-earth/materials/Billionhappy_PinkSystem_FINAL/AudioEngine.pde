// Audio engine adapted from the user's Reactor Signal Field V16.
// No audio data is used to select a new visual scene automatically.
AudioIn mic;
FFT fft;
Amplitude amplitude;
final float[] releaseRate = {0.055, 0.12};
final float[] testLevels = {0.025, 0.18, 0.50, 0.92};
final int[] onsetGapMs = {190, 118};
float[] spectrum = new float[FFT_BINS];
float[] previousSpectrum = new float[FFT_BINS];
float[] bandRaw = new float[BAND_COUNT];
float[] bandFloor = new float[BAND_COUNT];
float[] bandPeak = new float[BAND_COUNT];
float[] bandValue = new float[BAND_COUNT];
float[] previousBandValue = new float[BAND_COUNT];
int[] bandBinCount = new int[BAND_COUNT];
boolean audioReady = false;
boolean testSignal = false;
boolean liveMicGuard = true;
int artistPreset = 1;
float inputGain = 1.35;
float onsetThreshold = 0.34;
int calibrationFrames = 0;
int lastOnsetMs = -1000;
int previousSyntheticBeat = -1;
float rawAmplitude = 0;
float amplitudeFloor = 0.0003;
float amplitudePeak = 0.018;
float drive = 0;
float flux = 0;
float fluxPeak = 0.00005;
float onsetScore = 0;
float rawMicSignal = 0;
float environmentLevel = 0;
float lowFrequencySupport = 0;
float guardReduction = 0;
float inputHot = 0;

void setupAudio() {
  try {
    mic = new AudioIn(this, 0);
    fft = new FFT(this, FFT_BINS);
    amplitude = new Amplitude(this);
    mic.start();
    fft.input(mic);
    amplitude.input(mic);
    audioReady = true;
    println("Mic started. Press C to calibrate at show volume, T for test beat.");
  } catch (Throwable error) {
    audioReady = false;
    testSignal = true;
    println("Mic unavailable, synthetic test signal enabled: " + error.getMessage());
  }
}

void updateAudioAnalysis() {
  for (int b = 0; b < BAND_COUNT; b++) previousBandValue[b] = bandValue[b];
  if (testSignal || !audioReady) { updateSyntheticSignal(); return; }
  fft.analyze(spectrum);
  rawAmplitude = amplitude.analyze();
  if (rawAmplitude < amplitudeFloor) {
    amplitudeFloor = lerp(amplitudeFloor, rawAmplitude, 0.080);
  } else {
    amplitudeFloor = lerp(amplitudeFloor, rawAmplitude,
      calibrationFrames > 0 ? 0.0080 : 0.00012);
  }
  amplitudePeak = max(rawAmplitude, amplitudePeak * 0.99925);
  amplitudePeak = max(amplitudePeak, amplitudeFloor + 0.002);
  float ampNormalized = (rawAmplitude - amplitudeFloor * 1.08) /
    max(0.00001, amplitudePeak - amplitudeFloor);
  ampNormalized = constrain(pow(constrain(ampNormalized, 0, 1), 0.55) * inputGain, 0, 1);
  rawMicSignal = ampNormalized;

  float environmentRate = calibrationFrames > 0 ? 0.020 :
    rawMicSignal > environmentLevel ? 0.0018 : 0.0040;
  environmentLevel = lerp(environmentLevel, rawMicSignal, environmentRate);
  for (int b = 0; b < BAND_COUNT; b++) { bandRaw[b] = 0; bandBinCount[b] = 0; }
  float positiveFlux = 0;
  for (int i = 1; i < FFT_BINS; i++) {
    float hz = i * 22050.0 / (FFT_BINS - 1);
    int band = frequencyBandForHz(hz);
    if (band >= 0) { bandRaw[band] += spectrum[i]; bandBinCount[band]++; }
    positiveFlux += max(0, spectrum[i] - previousSpectrum[i]);
    previousSpectrum[i] = spectrum[i];
  }
  for (int b = 0; b < BAND_COUNT; b++) {
    if (bandBinCount[b] > 0) bandRaw[b] /= bandBinCount[b];
    if (bandRaw[b] < bandFloor[b]) {
      bandFloor[b] = lerp(bandFloor[b], bandRaw[b], 0.070);
    } else {
      bandFloor[b] = lerp(bandFloor[b], bandRaw[b],
        calibrationFrames > 0 ? 0.0080 : 0.00010);
    }
    bandPeak[b] = max(bandRaw[b], bandPeak[b] * 0.9991);
    bandPeak[b] = max(bandPeak[b], bandFloor[b] + 0.00005);
    float normalized = (bandRaw[b] - bandFloor[b] * 1.06) /
      max(0.000001, bandPeak[b] - bandFloor[b]);
    normalized = constrain(pow(constrain(normalized, 0, 1), 0.58) * inputGain, 0, 1);
    bandValue[b] = smoothAsymmetric(bandValue[b], normalized, 0.46, releaseRate[artistPreset]);
  }
  lowFrequencySupport = constrain(bandValue[0] * 0.88 + bandValue[1] * 0.12, 0, 1);
  float midHighEnergy = constrain(bandValue[2] * 0.68 +
    bandValue[3] * 0.22 + bandValue[4] * 0.10, 0, 1);
  float voiceOrNoiseBias = max(0, midHighEnergy - lowFrequencySupport * 1.15);
  float transientLift = max(0, rawMicSignal - environmentLevel);
  float protectedTarget = constrain(rawMicSignal * 0.10 +
    transientLift * 1.25 + lowFrequencySupport * 0.60, 0, 1);
  protectedTarget *= 1.0 - constrain(voiceOrNoiseBias * 0.92, 0, 0.70);
  protectedTarget = constrain(protectedTarget, 0, 1);
  float visualTarget = liveMicGuard ? protectedTarget : rawMicSignal;
  drive = smoothAsymmetric(drive, visualTarget, 0.44,
    liveMicGuard ? 0.090 : 0.070);
  guardReduction = lerp(guardReduction,
    liveMicGuard ? max(0, rawMicSignal - visualTarget) : 0, 0.12);
  float hotTarget = rawMicSignal > 0.965 ? 1.0 : 0.0;
  inputHot = lerp(inputHot, hotTarget, hotTarget > inputHot ? 0.022 : 0.10);

  positiveFlux /= FFT_BINS;
  fluxPeak = max(positiveFlux, fluxPeak * 0.9975);
  float fluxNormalized = constrain(positiveFlux / max(0.000001, fluxPeak), 0, 1);
  flux = smoothAsymmetric(flux, fluxNormalized, 0.60, 0.15);
  float bassRise = max(0, bandValue[0] - previousBandValue[0]);
  float midRise = max(0, bandValue[2] - previousBandValue[2]);
  onsetScore = max(flux * 0.70, max(bassRise * 2.15, midRise * 1.65));
  if (liveMicGuard) {
    float lowAttack = constrain(lowFrequencySupport + bassRise * 2.6, 0, 1);
    float musicSupport = constrain(lowAttack * 1.30 - voiceOrNoiseBias * 0.65, 0, 1);
    onsetScore *= lerp(0.20, 1.0, musicSupport);
  }
  if (calibrationFrames > 0) onsetScore = 0;
  int now = millis();
  if (onsetScore > effectiveOnsetThreshold() && drive > 0.03 &&
      now - lastOnsetMs > onsetGapMs[artistPreset]) {
    onBeat(constrain(max(onsetScore, drive), 0.22, 1.0), dominantBand());
    lastOnsetMs = now;
    flux *= 0.34;
  }
  if (calibrationFrames > 0) calibrationFrames--;
}

void updateSyntheticSignal() {
  float seconds = millis() * 0.001;
  float beatDuration = 60.0 / 124.0;
  int beatIndex = floor(seconds / beatDuration);
  float beatPhase = (seconds % beatDuration) / beatDuration;
  int section = floor(seconds / 8.0) % 4;
  float level = testLevels[section];
  float beatEnvelope = pow(max(0, 1.0 - beatPhase * 4.2), 3.0);
  rawAmplitude = level * 0.035;
  rawMicSignal = constrain(level * 0.86 + beatEnvelope * 0.22, 0, 1);
  drive = smoothAsymmetric(drive, rawMicSignal, 0.42, 0.065);
  environmentLevel = lerp(environmentLevel, level * 0.72, 0.035);
  guardReduction = 0;
  inputHot = 0;
  for (int b = 0; b < BAND_COUNT; b++) {
    float movement = 0.78 + 0.22 * sin(seconds * (0.55 + b * 0.18) + b * 1.31);
    float spectralTilt = map(b, 0, BAND_COUNT - 1, 1.00, 0.58);
    float target = level * movement * spectralTilt;
    if (b == 0) target += beatEnvelope * 0.34;
    if (b == 2) target += beatEnvelope * 0.17;
    if (b == 4 && section == 3) target += beatEnvelope * 0.24;
    bandValue[b] = smoothAsymmetric(bandValue[b],
      constrain(target, 0, 1), 0.44, releaseRate[artistPreset]);
    bandRaw[b] = bandValue[b] * 0.01;
  }
  lowFrequencySupport = constrain(bandValue[0] * 0.88 + bandValue[1] * 0.12, 0, 1);
  flux = smoothAsymmetric(flux, beatEnvelope, 0.68, 0.13);
  onsetScore = beatEnvelope;
  if (beatIndex != previousSyntheticBeat) {
    onBeat(max(0.34, level), section == 3 ? 4 : section);
    previousSyntheticBeat = beatIndex;
  }
}

void resetAnalysis() {
  amplitudeFloor = rawAmplitude > 0.00001 ? rawAmplitude * 0.22 : 0.0003;
  amplitudePeak = max(0.018, rawAmplitude * 1.60);
  fluxPeak = 0.00005;
  drive = 0;
  flux = 0;
  rawMicSignal = 0;
  environmentLevel = 0;
  lowFrequencySupport = 0;
  guardReduction = 0;
  inputHot = 0;
  for (int b = 0; b < BAND_COUNT; b++) {
    bandFloor[b] = bandRaw[b] > 0.000001 ? bandRaw[b] * 0.18 : 0.000001;
    bandPeak[b] = max(0.0025, bandRaw[b] * 1.80);
    bandValue[b] = 0;
    previousBandValue[b] = 0;
  }
  calibrationFrames = liveMicGuard ? 600 : 180;
  println("Audio recalibration: " + (liveMicGuard ? "10" : "3") + " seconds");
}

int frequencyBandForHz(float hz) {
  if (hz >= 40 && hz < 140) return 0;
  if (hz >= 140 && hz < 500) return 1;
  if (hz >= 500 && hz < 2000) return 2;
  if (hz >= 2000 && hz < 6000) return 3;
  if (hz >= 6000 && hz < 12000) return 4;
  return -1;
}

float smoothAsymmetric(float current, float target, float attack, float release) {
  return lerp(current, target, target > current ? attack : release);
}

float effectiveOnsetThreshold() { return onsetThreshold * (artistPreset == 0 ? 1.0 : 0.82); }
int dominantBand() {
  int winner = 0;
  for (int b = 1; b < BAND_COUNT; b++) if (bandValue[b] > bandValue[winner]) winner = b;
  return winner;
}
