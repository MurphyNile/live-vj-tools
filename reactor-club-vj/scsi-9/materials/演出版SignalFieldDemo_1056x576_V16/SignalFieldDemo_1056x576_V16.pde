import processing.sound.*;
import codeanticode.syphon.*;

/*
  SIGNAL FIELD V16 — 1056 x 576 PERFORMANCE
  Processing 4 + Sound + Syphon

  One sketch, seven continuous monochrome visual systems.
  The only optional colour is the red scan line.
  The Syphon output is always 1056 x 576.
*/

final int PREVIEW_W = 1056;
final int PREVIEW_H = 576;
final int DESIGN_W = 2112;
final int DESIGN_H = 1152;
final int OUTPUT_W = 1056;
final int OUTPUT_H = 576;
final float RENDER_SCALE = 0.5;
final int FFT_BINS = 512;
final int BAND_COUNT = 5;
final int HISTORY = 512;
final int POINT_COUNT = 720;
final int PLATE_COUNT = 18;
final int ASCII_COLS = 76;
final int ASCII_ROWS = 40;
final int ASCII_SLICES = 12;
final int MACRO_COUNT = 9;
final int MACRO_STATES = 4;
final int PULSE_EVENT_COUNT = 10;
final int SEQUENCE_COUNT = 16;

AudioIn mic;
FFT fft;
Amplitude amplitude;
SyphonServer syphon;
PGraphics output;
PShader fluidShader;
PFont mono;
PFont uiFont;
PImage transitionFrame;
PImage[] sequenceFrames = new PImage[SEQUENCE_COUNT];

MotionPoint[] points = new MotionPoint[POINT_COUNT];
Plate[] plates = new Plate[PLATE_COUNT];
PulseEvent[] pulseEvents = new PulseEvent[PULSE_EVENT_COUNT];

float[] spectrum = new float[FFT_BINS];
float[] previousSpectrum = new float[FFT_BINS];
float[] bandRaw = new float[BAND_COUNT];
float[] bandFloor = new float[BAND_COUNT];
float[] bandPeak = new float[BAND_COUNT];
float[] bandValue = new float[BAND_COUNT];
float[] previousBandValue = new float[BAND_COUNT];
float[][] history = new float[BAND_COUNT][HISTORY];
int[] bandBinCount = new int[BAND_COUNT];

String[] sceneNames = {"FIELD", "PLATES", "SCORE", "MEMBRANE", "ASCII VEIL", "PULSE", "IMAGE SEQUENCE"};
String[] presetNames = {"SCSI-9", "FEIYI / NAXIN"};
String[] densityNames = {"AUTO", "SPARSE", "DENSE"};
float[] testLevels = {0.025, 0.18, 0.50, 0.92};
float[] releaseRate = {0.045, 0.112};
float[] presetSpeedTarget = {0.72, 1.46};
float[] presetDensityTarget = {-0.065, 0.125};
float[] presetSpringTarget = {0.042, 0.092};
int[] onsetGapMs = {170, 88};
int[] layoutIntervals = {4, 2};

int currentScene = 0;
int artistPreset = 0;
int densityMode = 0;
int historyHead = 0;
int eventCounter = 0;
int previousSyntheticBeat = -1;
int sequenceFrameCount = 0;
int sequenceIndex = 0;
int previousSequenceIndex = 0;
int sequenceSwitchCounter = 0;
int sequenceDirection = 1;
int sequenceWhiteFlashFrames = 0;
int sequenceBlackFlashFrames = 0;
int sequenceScanBands = 4;
int sequenceScanDuration = 9;
int calibrationFrames = 0;
int lastOnsetMs = -1000;
int layoutA = 0;
int layoutB = 1;
String ASCII_GLYPHS = ".:+*01/\\";

boolean audioReady = false;
boolean syphonReady = false;
boolean syphonHasClient = false;
boolean shaderReady = false;
boolean testSignal = false;
boolean debugEnabled = false;
boolean redScanEnabled = false;
boolean centerReserve = false;
boolean autoLayout = true;
boolean sequenceReady = false;
boolean sequenceScanActive = false;
boolean liveMicGuard = true;
boolean beatFlashEnabled = true;

float inputGain = 1.35;
float onsetThreshold = 0.28;
float masterIntensity = 0.98;
float rawAmplitude = 0;
float amplitudeFloor = 0.0003;
float amplitudePeak = 0.018;
float drive = 0;
float flux = 0;
float fluxPeak = 0.00005;
float onsetScore = 0;

float densitySmooth = 0.06;
float gatherTarget = 0.78;
float gatherSmooth = 0.78;
float pulseTarget = 0;
float pulseSmooth = 0;
float layoutMorph = 1;
float sceneFade = 1;
float scoreOrientation = 0;
float motionTime = 0;
float scanPhase = 0;
float presetSpeed = 0.72;
float presetDensity = -0.10;
float presetSpring = 0.042;
float asciiScroll = 0;
float[] asciiShift = new float[ASCII_SLICES];
float[] asciiShiftTarget = new float[ASCII_SLICES];
float[] fieldMinX = new float[4];
float[] fieldMinY = new float[4];
float[] fieldMaxX = new float[4];
float[] fieldMaxY = new float[4];
int[] fieldGroupCount = new int[4];
float[][] macroX = new float[MACRO_STATES][MACRO_COUNT];
float[][] macroY = new float[MACRO_STATES][MACRO_COUNT];
float[][] macroW = new float[MACRO_STATES][MACRO_COUNT];
float[][] macroH = new float[MACRO_STATES][MACRO_COUNT];
float[] macroPriorityBase = {0.96, 0.34, 0.72, 0.18, 0.88, 0.48, 0.78, 0.27, 0.61};
float[] macroDensityBase = {0.88, 0.26, 0.67, 0.14, 0.94, 0.42, 0.73, 0.22, 0.56};
float[] macroScaleX = new float[MACRO_COUNT];
float[] macroScaleY = new float[MACRO_COUNT];
float[] macroScaleXTarget = new float[MACRO_COUNT];
float[] macroScaleYTarget = new float[MACRO_COUNT];
float[] macroOffsetX = new float[MACRO_COUNT];
float[] macroOffsetY = new float[MACRO_COUNT];
float[] macroOffsetXTarget = new float[MACRO_COUNT];
float[] macroOffsetYTarget = new float[MACRO_COUNT];
float rareBurst = 0;
float rareBurstTarget = 0;
int rareRegion = 4;
int variationState = 0;
float impactSmooth = 0;
float impactTarget = 0;
float densityBurstSmooth = 0;
float densityBurstTarget = 0;
float scoreFeedback = 0;
float scoreFeedbackTarget = 0;
int scoreFeedbackMode = 0;
float rawMicSignal = 0;
float environmentLevel = 0;
float lowFrequencySupport = 0;
float guardReduction = 0;
float inputHot = 0;
float globalBeatFlash = 0;
float globalBeatFlashTarget = 0;
float localBeatFlash = 0;
float localBeatFlashTarget = 0;
int beatFlashPattern = 0;
int beatFlashRegion = 4;
int beatCutFrames = 0;
float sequenceAccumulator = 0;
float sequenceRate = 0;
float sequenceBurst = 0;
float sequenceScanProgress = 1;
float sequenceAfterimage = 0;

void settings() {
  size(PREVIEW_W, PREVIEW_H, P3D);
  smooth(4);
}

void setup() {
  frameRate(60);
  surface.setTitle("SIGNAL FIELD V16 — PERFORMANCE / SYPHON 1056x576");

  output = createGraphics(OUTPUT_W, OUTPUT_H, P3D);
  output.smooth(4);
  transitionFrame = createImage(OUTPUT_W, OUTPUT_H, ARGB);
  mono = createFont("Monospaced", 18, true);
  uiFont = createFont("SansSerif", 18, true);
  loadImageSequence();

  randomSeed(91723);
  for (int i = 0; i < POINT_COUNT; i++) {
    points[i] = new MotionPoint(i, random(1), random(1), random(1));
  }
  for (int i = 0; i < PLATE_COUNT; i++) plates[i] = new Plate(i);
  for (int i = 0; i < PULSE_EVENT_COUNT; i++) pulseEvents[i] = new PulseEvent();
  initialiseMacroPartitions();

  try {
    fluidShader = loadShader("fluid.glsl");
    shaderReady = fluidShader != null;
  }
  catch (Throwable error) {
    shaderReady = false;
    println("Fluid shader unavailable. CPU contour fallback enabled.");
    println(error.getMessage());
  }

  try {
    syphon = new SyphonServer(this, "SIGNAL_FIELD_1056x576_V16");
    syphonReady = true;
    println("Syphon server started: SIGNAL_FIELD_1056x576_V16");
  }
  catch (Throwable error) {
    syphonReady = false;
    println("Syphon server could not start. Preview will continue.");
    println(error.getMessage());
  }

  resetAnalysis();
  initialiseAudio();
}

void draw() {
  updateAudioAnalysis();
  writeHistory();
  updateVisualState();
  updatePointMotion();
  updatePlateMotion();

  output.beginDraw();
  output.hint(DISABLE_DEPTH_TEST);
  output.background(0);
  output.blendMode(BLEND);
  output.rectMode(CORNER);
  output.ellipseMode(CENTER);
  output.strokeCap(SQUARE);
  output.strokeJoin(MITER);
  // PGraphics keeps style state between frames. Reset it before every scene so
  // a previous noFill() call can never suppress the shader carrier rectangle.
  output.noStroke();
  output.fill(255);
  output.pushMatrix();
  output.scale(RENDER_SCALE);

  if (currentScene == 0) drawField(output);
  if (currentScene == 1) drawPlates(output);
  if (currentScene == 2) drawScore(output);
  if (currentScene == 3) drawMembrane(output);
  if (currentScene == 4) drawAsciiVeil(output);
  if (currentScene == 5) drawPulse(output);
  if (currentScene == 6) drawImageSequence(output);

  if (transitionFrame != null && sceneFade < 1) {
    output.tint(255, 255 * pow(1.0 - sceneFade, 1.55));
    output.image(transitionFrame, 0, 0, DESIGN_W, DESIGN_H);
    output.noTint();
  }

  if (rareBurst > 0.012 && currentScene != 5 && currentScene != 6) drawRareTransient(output);
  if (beatFlashEnabled) drawBeatFlash(output);
  if (redScanEnabled) drawRedScan(output);
  if (centerReserve) drawCenterReserve(output);
  output.popMatrix();
  output.hint(ENABLE_DEPTH_TEST);
  output.endDraw();

  if (syphonReady) {
    try {
      syphon.sendImage(output);
      if (frameCount % 30 == 0) syphonHasClient = syphon.hasClients();
    }
    catch (Throwable error) {
      syphonReady = false;
      println("Syphon transmission stopped. Preview will continue.");
      println(error.getMessage());
    }
  }

  background(0);
  image(output, 0, 0, width, height);
  if (debugEnabled) drawDebugOverlay();
}

void updateVisualState() {
  presetSpeed = lerp(presetSpeed, presetSpeedTarget[artistPreset], 0.025);
  presetDensity = lerp(presetDensity, presetDensityTarget[artistPreset], 0.025);
  presetSpring = lerp(presetSpring, presetSpringTarget[artistPreset], 0.025);

  float normalized = constrain((drive - 0.055) / 0.82, 0, 1);
  impactSmooth = lerp(impactSmooth, impactTarget,
    impactTarget > impactSmooth ? (artistPreset == 0 ? 0.34 : 0.50) :
    (artistPreset == 0 ? 0.075 : 0.14));
  densityBurstSmooth = lerp(densityBurstSmooth, densityBurstTarget,
    densityBurstTarget > densityBurstSmooth ? (artistPreset == 0 ? 0.28 : 0.44) :
    (artistPreset == 0 ? 0.055 : 0.11));
  impactTarget *= artistPreset == 0 ? 0.86 : 0.68;
  densityBurstTarget *= artistPreset == 0 ? 0.91 : 0.76;

  float targetDensity = pow(normalized, 1.10) + presetDensity + densityBurstSmooth * 0.24;
  if (densityMode == 1) targetDensity = 0.075 + drive * 0.055;
  if (densityMode == 2) targetDensity = 0.78 + drive * 0.16;
  densitySmooth = lerp(densitySmooth, constrain(targetDensity, 0.025, 0.98),
    artistPreset == 0 ? 0.045 : 0.082);

  gatherSmooth = lerp(gatherSmooth, gatherTarget,
    (artistPreset == 0 ? 0.025 : 0.052) + bandValue[1] * 0.018);
  pulseSmooth = lerp(pulseSmooth, pulseTarget,
    pulseTarget > pulseSmooth ? (artistPreset == 0 ? 0.22 : 0.42) :
    (artistPreset == 0 ? 0.075 : 0.14));
  pulseTarget *= artistPreset == 0 ? 0.925 : 0.76;
  rareBurst = lerp(rareBurst, rareBurstTarget,
    rareBurstTarget > rareBurst ? 0.42 : 0.16);
  rareBurstTarget *= 0.68;
  if (rareBurst < 0.002 && rareBurstTarget < 0.002) rareBurst = 0;

  layoutMorph = min(1.0, layoutMorph + 0.0105 * presetSpeed);
  sceneFade = min(1.0, sceneFade + 0.022);
  float orientationTarget = layoutB % 2 == 0 ? 0 : 1;
  scoreOrientation = lerp(scoreOrientation, orientationTarget, 0.018 * presetSpeed);
  scoreFeedback = lerp(scoreFeedback, scoreFeedbackTarget,
    scoreFeedbackTarget > scoreFeedback ? 0.30 : 0.085);
  scoreFeedbackTarget *= artistPreset == 0 ? 0.88 : 0.82;
  if (scoreFeedback < 0.002 && scoreFeedbackTarget < 0.002) scoreFeedback = 0;

  globalBeatFlash = lerp(globalBeatFlash, globalBeatFlashTarget,
    globalBeatFlashTarget > globalBeatFlash ? (artistPreset == 0 ? 0.66 : 0.86) :
    (artistPreset == 0 ? 0.30 : 0.42));
  localBeatFlash = lerp(localBeatFlash, localBeatFlashTarget,
    localBeatFlashTarget > localBeatFlash ? (artistPreset == 0 ? 0.58 : 0.78) :
    (artistPreset == 0 ? 0.18 : 0.27));
  globalBeatFlashTarget *= artistPreset == 0 ? 0.18 : 0.08;
  localBeatFlashTarget *= artistPreset == 0 ? 0.34 : 0.24;
  if (globalBeatFlash < 0.002 && globalBeatFlashTarget < 0.002) globalBeatFlash = 0;
  if (localBeatFlash < 0.002 && localBeatFlashTarget < 0.002) localBeatFlash = 0;

  motionTime += (0.0025 + bandValue[2] * 0.0035) * presetSpeed;
  scanPhase = (scanPhase + 0.0017 + bandValue[4] * 0.0035) % 1.0;
  asciiScroll += (0.018 + bandValue[4] * 0.060 + drive * 0.012) * presetSpeed;
  for (int i = 0; i < ASCII_SLICES; i++) {
    asciiShift[i] = lerp(asciiShift[i], asciiShiftTarget[i], 0.095);
    asciiShiftTarget[i] *= 0.905;
  }
  for (int i = 0; i < MACRO_COUNT; i++) {
    float response = (0.034 + bandValue[i % BAND_COUNT] * 0.026) * presetSpeed;
    macroScaleX[i] = lerp(macroScaleX[i], macroScaleXTarget[i], response);
    macroScaleY[i] = lerp(macroScaleY[i], macroScaleYTarget[i], response);
    macroOffsetX[i] = lerp(macroOffsetX[i], macroOffsetXTarget[i], response * 0.82);
    macroOffsetY[i] = lerp(macroOffsetY[i], macroOffsetYTarget[i], response * 0.82);
    float returnRate = artistPreset == 0 ? 0.0018 : 0.0011;
    macroScaleXTarget[i] = lerp(macroScaleXTarget[i], 1.0, returnRate);
    macroScaleYTarget[i] = lerp(macroScaleYTarget[i], 1.0, returnRate);
    macroOffsetXTarget[i] = lerp(macroOffsetXTarget[i], 0.0, returnRate);
    macroOffsetYTarget[i] = lerp(macroOffsetYTarget[i], 0.0, returnRate);
  }
  for (int i = 0; i < PULSE_EVENT_COUNT; i++) pulseEvents[i].update();
  updateImageSequenceState();
}

float morphEase() {
  float t = constrain(layoutMorph, 0, 1);
  return t * t * (3.0 - 2.0 * t);
}

void changeLayout(int dominant) {
  layoutA = layoutB;
  int jump = 1 + dominant % 3;
  layoutB = (layoutB + jump) % 4;
  if (layoutB == layoutA) layoutB = (layoutB + 1) % 4;
  layoutMorph = 0;
}

void changeScene(int nextScene) {
  int next = constrain(nextScene, 0, 6);
  if (next == currentScene) return;
  if (output != null && transitionFrame != null) {
    transitionFrame.copy(output, 0, 0, OUTPUT_W, OUTPUT_H,
      0, 0, OUTPUT_W, OUTPUT_H);
  }
  currentScene = next;
  sceneFade = 0;
  if (currentScene == 6) resetImageSequenceScene();
}

// ---------------------------------------------------------------------------
// Shared macro field. These rectangles are never shown as a grid: every scene
// reads the same slow, overlapping regions as density and scale guides.
// ---------------------------------------------------------------------------

void initialiseMacroPartitions() {
  for (int state = 0; state < MACRO_STATES; state++) {
    for (int id = 0; id < MACRO_COUNT; id++) {
      int col = id % 3;
      int row = id / 3;
      float jx = (fixedHash(701 + state * 113 + id * 37) - 0.5) * 0.055;
      float jy = (fixedHash(907 + state * 149 + id * 53) - 0.5) * 0.065;
      float extraW = fixedHash(1103 + state * 173 + id * 71) * 0.115;
      float extraH = fixedHash(1301 + state * 197 + id * 89) * 0.120;

      float x = col / 3.0 - 0.010 + jx;
      float y = row / 3.0 - 0.012 + jy;
      float w = 0.315 + extraW;
      float h = 0.305 + extraH;

      // Only one or two regions in each state span farther. Overlap prevents
      // the system from reading as a tiled layout.
      if ((id + state * 2) % 7 == 1) w += 0.105;
      if ((id + state) % 8 == 3) h += 0.095;
      if (col == 0) x = min(x, 0.008);
      if (row == 0) y = min(y, 0.008);
      x = constrain(x, -0.025, 0.94);
      y = constrain(y, -0.025, 0.94);
      w = min(w, 1.025 - x);
      h = min(h, 1.025 - y);

      macroX[state][id] = x;
      macroY[state][id] = y;
      macroW[state][id] = w;
      macroH[state][id] = h;
    }
  }
  for (int id = 0; id < MACRO_COUNT; id++) {
    macroScaleX[id] = 1;
    macroScaleY[id] = 1;
    macroScaleXTarget[id] = 1;
    macroScaleYTarget[id] = 1;
    macroOffsetX[id] = 0;
    macroOffsetY[id] = 0;
    macroOffsetXTarget[id] = 0;
    macroOffsetYTarget[id] = 0;
  }
}

float macroCurrentX(int id) {
  float drift = sin(motionTime * 0.15 + id * 1.73) * 0.0045;
  float baseX = lerp(macroX[layoutA][id], macroX[layoutB][id], morphEase());
  float baseW = lerp(macroW[layoutA][id], macroW[layoutB][id], morphEase());
  return baseX + baseW * 0.5 - baseW * macroScaleX[id] * 0.5 +
    macroOffsetX[id] + drift;
}

float macroCurrentY(int id) {
  float drift = cos(motionTime * 0.13 + id * 1.29) * 0.0040;
  float baseY = lerp(macroY[layoutA][id], macroY[layoutB][id], morphEase());
  float baseH = lerp(macroH[layoutA][id], macroH[layoutB][id], morphEase());
  return baseY + baseH * 0.5 - baseH * macroScaleY[id] * 0.5 +
    macroOffsetY[id] + drift;
}

float macroCurrentW(int id) {
  return lerp(macroW[layoutA][id], macroW[layoutB][id], morphEase()) * macroScaleX[id];
}

float macroCurrentH(int id) {
  return lerp(macroH[layoutA][id], macroH[layoutB][id], morphEase()) * macroScaleY[id];
}

float macroPriority(int id) {
  int shifted = (id + layoutB * 2) % MACRO_COUNT;
  float base = macroPriorityBase[shifted];
  float breath = 0.90 + 0.10 * sin(motionTime * 0.18 + id * 2.1);
  return constrain(base * breath + densitySmooth * 0.08, 0.06, 1.0);
}

float macroDensity(int id) {
  int shifted = (id + layoutB * 2) % MACRO_COUNT;
  return constrain(macroDensityBase[shifted] * (0.74 + densitySmooth * 0.38), 0.04, 1.0);
}

float macroInfluence(float u, float v, int id) {
  float x = macroCurrentX(id);
  float y = macroCurrentY(id);
  float w = macroCurrentW(id);
  float h = macroCurrentH(id);
  float qx = abs(u - (x + w * 0.5)) / max(0.001, w * 0.5);
  float qy = abs(v - (y + h * 0.5)) / max(0.001, h * 0.5);
  float distanceToEdge = max(qx, qy);
  return 1.0 - smoothStepValue(0.72, 1.16, distanceToEdge);
}

int macroRegionAt(float u, float v) {
  int winner = 0;
  float best = -1;
  for (int id = 0; id < MACRO_COUNT; id++) {
    float value = macroInfluence(u, v, id) * (0.45 + macroPriority(id) * 0.55);
    if (value > best) {
      best = value;
      winner = id;
    }
  }
  return winner;
}

float smoothStepValue(float edge0, float edge1, float value) {
  float t = constrain((value - edge0) / max(0.0001, edge1 - edge0), 0, 1);
  return t * t * (3.0 - 2.0 * t);
}

// ---------------------------------------------------------------------------
// 1. FIELD — the same particles visibly gather, form bands and disperse.
// ---------------------------------------------------------------------------

void updatePointMotion() {
  float mixValue = morphEase();
  for (int i = 0; i < POINT_COUNT; i++) {
    MotionPoint p = points[i];
    float ax = patternX(layoutA, p);
    float ay = patternY(layoutA, p);
    float bx = patternX(layoutB, p);
    float by = patternY(layoutB, p);
    float organizedX = lerp(ax, bx, mixValue);
    float organizedY = lerp(ay, by, mixValue);

    float tx = lerp(p.u, organizedX, gatherSmooth);
    float ty = lerp(p.v, organizedY, gatherSmooth);

    float fromCenterX = tx - 0.5;
    float fromCenterY = ty - 0.5;
    float burstScale = pulseSmooth * (0.20 + bandValue[0] * 0.30);
    tx += fromCenterX * burstScale;
    ty += fromCenterY * burstScale;

    float drift = 0.007 + bandValue[2] * 0.018 + (1.0 - gatherSmooth) * 0.018;
    tx += (noise(p.seed * 5.31, motionTime * 0.74) - 0.5) * drift;
    ty += (noise(p.seed * 7.17 + 11.0, motionTime * 0.69) - 0.5) * drift;

    p.update(tx * DESIGN_W, ty * DESIGN_H, presetSpring);
  }
}

float patternX(int state, MotionPoint p) {
  int cluster = p.cluster;
  if (state == 0) {
    float center = (cluster % 4 + 0.5) / 4.0;
    return center + (p.u - 0.5) * (0.08 + bandValue[1] * 0.05);
  }
  if (state == 1) {
    return p.u;
  }
  if (state == 2) {
    float center = cluster == 0 ? 0.19 : cluster == 1 ? 0.43 : cluster == 2 ? 0.69 : 0.84;
    return center + (p.u - 0.5) * (0.16 + bandValue[0] * 0.10);
  }
  float diagonal = (p.u * 0.72 + p.v * 0.28 + cluster * 0.11) % 1.0;
  return diagonal;
}

float patternY(int state, MotionPoint p) {
  int cluster = p.cluster;
  if (state == 0) {
    return 0.10 + p.v * 0.80;
  }
  if (state == 1) {
    float wave = sin(p.u * TWO_PI * (1.4 + cluster * 0.28) + cluster * 1.73 + motionTime * 1.4);
    return 0.22 + cluster * 0.18 + wave * (0.035 + bandValue[2] * 0.055) + (p.v - 0.5) * 0.075;
  }
  if (state == 2) {
    float center = cluster == 0 ? 0.27 : cluster == 1 ? 0.70 : cluster == 2 ? 0.38 : 0.74;
    return center + (p.v - 0.5) * (0.20 + bandValue[1] * 0.12);
  }
  return constrain(p.v * 0.76 + p.u * 0.22 + (cluster - 1.5) * 0.055, 0.05, 0.95);
}

void drawField(PGraphics pg) {
  int active = constrain(int(lerp(26, POINT_COUNT, pow(densitySmooth, 0.82))), 1, POINT_COUNT);

  // V8 composition: four moving envelopes built from the same particle field.
  for (int group = 0; group < 4; group++) {
    fieldMinX[group] = DESIGN_W;
    fieldMinY[group] = DESIGN_H;
    fieldMaxX[group] = 0;
    fieldMaxY[group] = 0;
    fieldGroupCount[group] = 0;
  }
  for (int i = 0; i < active; i++) {
    MotionPoint p = points[i];
    int group = p.cluster;
    fieldMinX[group] = min(fieldMinX[group], p.x);
    fieldMinY[group] = min(fieldMinY[group], p.y);
    fieldMaxX[group] = max(fieldMaxX[group], p.x);
    fieldMaxY[group] = max(fieldMaxY[group], p.y);
    fieldGroupCount[group]++;
  }
  pg.noFill();
  pg.rectMode(CORNER);
  for (int group = 0; group < 4; group++) {
    if (fieldGroupCount[group] < 2) continue;
    float margin = lerp(46, 15, densitySmooth) + bandValue[group] * 28;
    float gx = fieldMinX[group] - margin;
    float gy = fieldMinY[group] - margin;
    float gw = max(12, fieldMaxX[group] - fieldMinX[group] + margin * 2);
    float gh = max(12, fieldMaxY[group] - fieldMinY[group] + margin * 2);
    float gcx = gx + gw * 0.5;
    float gcy = gy + gh * 0.5;
    gw = min(gw, DESIGN_W * 0.46);
    gh = min(gh, DESIGN_H * 0.58);
    gx = gcx - gw * 0.5;
    gy = gcy - gh * 0.5;
    inkStroke(pg, (30 + bandValue[group] * 72 + pulseSmooth * 24) *
      (0.42 + gatherSmooth * 0.58));
    pg.strokeWeight(1.0 + bandValue[group] * 1.5);
    pg.rect(gx, gy, gw, gh);
    if (pulseSmooth > 0.10 && group % 2 == eventCounter % 2) {
      float echo = pulseSmooth * (18 + bandValue[0] * 26);
      inkStroke(pg, 18 + pulseSmooth * 48);
      pg.rect(gx + echo, gy, max(4, gw - echo * 0.4), gh);
    }
  }

  pg.noFill();
  inkStroke(pg, 24 + gatherSmooth * 42);
  pg.strokeWeight(1.0 + bandValue[2] * 1.2);
  int links = min(active - 1, int(lerp(10, 110, densitySmooth)));
  for (int i = 0; i < links; i += 2) {
    MotionPoint a = points[i];
    MotionPoint b = points[i + 1];
    if (a.cluster != b.cluster) continue;
    float distance = dist(a.x, a.y, b.x, b.y);
    if (distance < DESIGN_W * 0.18) pg.line(a.x, a.y, b.x, b.y);
  }

  float baseSize = lerp(24, 2.4, pow(densitySmooth, 0.72));
  pg.rectMode(CENTER);
  pg.ellipseMode(CENTER);
  for (int i = 0; i < active; i++) {
    MotionPoint p = points[i];
    float size = baseSize * lerp(0.50, 1.75, p.sizeSeed) *
      (1.0 + bandValue[p.cluster % BAND_COUNT] * 0.75 + pulseSmooth * 0.28);
    float alpha = lerp(218, 126, densitySmooth) *
      (0.72 + bandValue[p.cluster % BAND_COUNT] * 0.28);

    if (i % 13 == 0 && densitySmooth < 0.50) {
      pg.noFill();
      inkStroke(pg, alpha * 0.70);
      pg.strokeWeight(1.3 + bandValue[4] * 2.0);
      pg.ellipse(p.x, p.y, size * 2.9, size * 2.9);
    } else {
      pg.noStroke();
      inkFill(pg, alpha);
      if (i % 5 == 0) pg.ellipse(p.x, p.y, size, size);
      else pg.rect(p.x, p.y, size * lerp(0.55, 1.80, p.seed), size);
    }

    if (i % 19 == 0 && (bandValue[3] > 0.10 || pulseSmooth > 0.10)) {
      inkStroke(pg, 45 + bandValue[3] * 118);
      pg.strokeWeight(1.0 + bandValue[4] * 1.5);
      pg.line(p.x, p.y, p.x - p.vx * (1.4 + pulseSmooth),
        p.y - p.vy * (1.4 + pulseSmooth));
    }
  }
  pg.rectMode(CORNER);
}

// ---------------------------------------------------------------------------
// 2. PLATES — large planes first, detail only when the image becomes dense.
// ---------------------------------------------------------------------------

void updatePlateMotion() {
  float t = morphEase();
  for (int i = 0; i < PLATE_COUNT; i++) {
    Plate p = plates[i];
    float tx = lerp(p.tx[layoutA], p.tx[layoutB], t);
    float ty = lerp(p.ty[layoutA], p.ty[layoutB], t);
    float tw = lerp(p.tw[layoutA], p.tw[layoutB], t);
    float th = lerp(p.th[layoutA], p.th[layoutB], t);

    float spread = 0.34 + gatherSmooth * 0.66;
    tx = lerp(0.5 - tw * 0.5, tx, spread);
    ty = lerp(0.5 - th * 0.5, ty, spread);

    float cx = tx + tw * 0.5;
    float cy = ty + th * 0.5;
    float driftAmount = 0.0035 + bandValue[(i + 1) % BAND_COUNT] * 0.0085;
    tx += sin(motionTime * 0.62 + i * 1.37) * driftAmount;
    ty += cos(motionTime * 0.49 + i * 1.91) * driftAmount * 0.70;
    tx += (cx - 0.5) * pulseSmooth * 0.16;
    ty += (cy - 0.5) * pulseSmooth * 0.12;
    tw *= 0.88 + bandValue[i % BAND_COUNT] * 0.38;
    th *= 0.90 + bandValue[(i + 2) % BAND_COUNT] * 0.32;
    p.update(tx, ty, tw, th, 0.035 + presetSpeed * 0.018);
  }
}

void drawPlates(PGraphics pg) {
  int active = constrain(3 + int(densitySmooth * (PLATE_COUNT - 3)), 3, PLATE_COUNT);

  // A restrained low-opacity counterform sits behind the plates. It moves on
  // a slower time scale and makes sparse sections feel intentional.
  pg.noStroke();
  inkFill(pg, 12 + drive * 30);
  if (layoutB % 2 == 0) {
    float bandY = DESIGN_H * (0.34 + sin(motionTime * 0.37) * 0.13);
    pg.rect(0, bandY, DESIGN_W, DESIGN_H * (0.10 + bandValue[0] * 0.11));
  } else {
    float bandX = DESIGN_W * (0.38 + sin(motionTime * 0.31) * 0.15);
    pg.rect(bandX, 0, DESIGN_W * (0.075 + bandValue[0] * 0.09), DESIGN_H);
  }

  for (int i = 0; i < active; i++) {
    Plate p = plates[i];
    float x = p.x * DESIGN_W;
    float y = p.y * DESIGN_H;
    float w = max(2, p.w * DESIGN_W);
    float h = max(2, p.h * DESIGN_H);
    float level = bandValue[i % BAND_COUNT];

    if (pulseSmooth > 0.10 && i % 3 == eventCounter % 3) {
      float offset = (i % 2 == 0 ? 1 : -1) * pulseSmooth *
        (12 + bandValue[2] * 44);
      pg.noFill();
      inkStroke(pg, 24 + pulseSmooth * 70);
      pg.strokeWeight(1.1 + bandValue[4]);
      pg.rect(x + offset, y, w, h);
    }

    boolean solid = i == 0 || (i == 5 && densitySmooth > 0.34) ||
      (i == 11 && densitySmooth > 0.70);
    if (solid) {
      pg.noStroke();
      inkFill(pg, (i == 0 ? 196 : 92) + level * 42);
      pg.rect(x, y, w, h);

      // Black interior cuts keep the large white plane precise and light.
      if (i == 0 && w > DESIGN_W * 0.18 && h > DESIGN_H * 0.08) {
        float insetX = min(w * 0.18, 48 + bandValue[0] * 70);
        float insetY = min(h * 0.26, 24 + bandValue[1] * 38);
        pg.fill(0, 225);
        pg.rect(x + insetX, y + insetY,
          max(0, w - insetX * 2), max(0, h - insetY * 2));
      }
    } else {
      pg.noFill();
      inkStroke(pg, 72 + level * 126);
      pg.strokeWeight(1.0 + level * 2.6);
      pg.rect(x, y, w, h);
    }

    // Only selected plates receive one internal division.
    if (i % 4 == 2 && densitySmooth > 0.24) {
      inkStroke(pg, 42 + bandValue[4] * 92);
      pg.strokeWeight(1);
      float split = x + w * (0.25 + level * 0.50);
      pg.line(split, y, split, y + h);
    }
  }

  // One slow line passes through the arrangement and binds the whole frame.
  float sweep = (0.08 + (motionTime * 0.11) % 0.84) * DESIGN_W;
  inkStroke(pg, 34 + bandValue[4] * 88);
  pg.strokeWeight(1.0 + bandValue[4] * 1.8);
  pg.line(sweep, DESIGN_H * 0.035, sweep, DESIGN_H * 0.965);
}

// ---------------------------------------------------------------------------
// 3. SCORE — actual band histories as large, slowly turning wave structures.
// ---------------------------------------------------------------------------

float scorePassOpacity = 1.0;

void scoreInkFill(PGraphics pg, float alpha) {
  inkFill(pg, alpha * scorePassOpacity);
}

void scoreInkStroke(PGraphics pg, float alpha) {
  inkStroke(pg, alpha * scorePassOpacity);
}

void drawScore(PGraphics pg) {
  // Keep the V8 body intact. A very dim duplicate supplies the current
  // version's restrained glow without changing the underlying geometry.
  pg.blendMode(ADD);
  scorePassOpacity = 0.075 + bandValue[4] * 0.035;
  pg.pushMatrix();
  pg.translate(2.0, 1.0);
  drawScoreCore(pg);
  pg.popMatrix();

  pg.blendMode(BLEND);
  scorePassOpacity = 1.0;
  drawScoreCore(pg);

  // Feedback is an event, not a permanent layout. It is either one mirrored
  // field or one short displaced echo and disappears before it becomes a motif.
  if (scoreFeedback > 0.025) {
    pg.blendMode(ADD);
    scorePassOpacity = constrain(scoreFeedback * 0.20, 0, 0.22);
    pg.pushMatrix();
    if (scoreFeedbackMode == 0) {
      pg.translate(DESIGN_W, 0);
      pg.scale(-1, 1);
    } else if (scoreFeedbackMode == 1) {
      pg.translate(0, DESIGN_H);
      pg.scale(1, -1);
    } else {
      float direction = eventCounter % 2 == 0 ? 1 : -1;
      pg.translate(direction * DESIGN_W * (0.008 + scoreFeedback * 0.018),
        -direction * DESIGN_H * (0.004 + scoreFeedback * 0.010));
    }
    drawScoreCore(pg);
    pg.popMatrix();
  }
  scorePassOpacity = 1.0;
  pg.blendMode(BLEND);
}

void drawScoreCore(PGraphics pg) {
  int lanes = constrain(2 + int(densitySmooth * 3.4), 2, 5);
  float marginX = DESIGN_W * 0.035;
  float marginY = DESIGN_H * 0.055;
  float availableW = DESIGN_W - marginX * 2;
  float availableH = DESIGN_H - marginY * 2;
  int steps = artistPreset == 0 ? 144 : 160;

  // One large spectral body controls the frame. Its scale is intentionally much
  // larger than a conventional audio waveform.
  int dominant = dominantBand();
  float lanePosition = lerp(0.34, 0.50, gatherSmooth);
  float ribbonWidth = lerp(112, 38, densitySmooth) *
    (1.0 + bandValue[dominant] * 0.90 + pulseSmooth * 0.38);
  scoreInkFill(pg, 72 + bandValue[dominant] * 104);
  pg.noStroke();
  pg.beginShape();
  for (int i = 0; i <= steps; i++) {
    float u = i / float(steps);
    float sample = historySample(dominant, u);
    float wave = (sample - 0.42) * availableH * 0.46;
    float hx = marginX + u * availableW;
    float hy = marginY + availableH * lanePosition + wave;
    float vx = marginX + availableW * lanePosition + wave * 0.78;
    float vy = marginY + u * availableH;
    pg.vertex(
      lerp(hx, vx - ribbonWidth, scoreOrientation),
      lerp(hy - ribbonWidth, vy, scoreOrientation)
    );
  }
  for (int i = steps; i >= 0; i--) {
    float u = i / float(steps);
    float sample = historySample(dominant, u);
    float wave = (sample - 0.42) * availableH * 0.46;
    float hx = marginX + u * availableW;
    float hy = marginY + availableH * lanePosition + wave;
    float vx = marginX + availableW * lanePosition + wave * 0.78;
    float vy = marginY + u * availableH;
    pg.vertex(
      lerp(hx, vx + ribbonWidth, scoreOrientation),
      lerp(hy + ribbonWidth, vy, scoreOrientation)
    );
  }
  pg.endShape(CLOSE);

  // Two distant contour echoes widen the spatial field without introducing
  // small interface-like blocks.
  for (int echoIndex = 0; echoIndex < 2; echoIndex++) {
    float direction = echoIndex == 0 ? -1 : 1;
    float offset = direction * (ribbonWidth * 1.35 + pulseSmooth * 54);
    pg.noFill();
    scoreInkStroke(pg, 26 + bandValue[dominant] * 72 + pulseSmooth * 28);
    pg.strokeWeight(1.4 + bandValue[4] * 2.1);
    pg.beginShape();
    for (int i = 0; i <= steps; i++) {
      float u = i / float(steps);
      float sample = historySample(dominant, u);
      float wave = (sample - 0.42) * availableH * 0.46;
      float hx = marginX + u * availableW;
      float hy = marginY + availableH * lanePosition + wave + offset;
      float vx = marginX + availableW * lanePosition + wave * 0.78 + offset;
      float vy = marginY + u * availableH;
      pg.vertex(lerp(hx, vx, scoreOrientation), lerp(hy, vy, scoreOrientation));
    }
    pg.endShape();
  }

  for (int lane = 0; lane < lanes; lane++) {
    int band = lane % BAND_COUNT;
    float spread = gatherSmooth;
    float position = lerp(0.5, (lane + 0.5) / lanes, 0.55 + spread * 0.45);
    float amplitudeValue = (0.085 + bandValue[band] * 0.30 + pulseSmooth * 0.045) * availableH;

    pg.noFill();
    scoreInkStroke(pg, lerp(224, 118, densitySmooth) *
      (0.70 + bandValue[band] * 0.30));
    pg.strokeWeight(lerp(7.2, 1.5, densitySmooth) + bandValue[band] * 2.4);
    pg.beginShape();
    for (int i = 0; i <= steps; i++) {
      float u = i / float(steps);
      float sample = historySample(band, u);
      float fine = (noise(lane * 2.7, u * (3.0 + bandValue[4] * 10.0) + motionTime) - 0.5) *
        bandValue[4] * availableH * 0.025;
      float wave = (sample - 0.44) * amplitudeValue + fine;
      float hx = marginX + u * availableW;
      float hy = marginY + availableH * position + wave;
      float vx = marginX + availableW * position + wave * 0.78;
      float vy = marginY + u * availableH;
      pg.vertex(lerp(hx, vx, scoreOrientation), lerp(hy, vy, scoreOrientation));
    }
    pg.endShape();
  }

  // A few full-span strikes appear only when history carries enough energy.
  // Their scale is architectural rather than decorative.
  int strikes = 3 + int(densitySmooth * 3.0);
  for (int i = 0; i < strikes; i++) {
    float u = (i + 1.0) / (strikes + 1.0);
    float sample = historySample((dominant + i + 1) % BAND_COUNT, u);
    if (sample + pulseSmooth * 0.18 < 0.24 + i * 0.025) continue;
    float alpha = 22 + sample * 116 + pulseSmooth * 26;
    float weight = 1.0 + sample * 5.5 + bandValue[4] * 1.6;
    pg.strokeWeight(weight);
    scoreInkStroke(pg, alpha * (1.0 - scoreOrientation));
    float x = marginX + u * availableW;
    pg.line(x, marginY, x, DESIGN_H - marginY);
    scoreInkStroke(pg, alpha * scoreOrientation);
    float y = marginY + u * availableH;
    pg.line(marginX, y, DESIGN_W - marginX, y);
  }
}

// ---------------------------------------------------------------------------
// 4. MEMBRANE — smooth monochrome fluid field, with CPU fallback.
// ---------------------------------------------------------------------------

void drawMembrane(PGraphics pg) {
  if (shaderReady) {
    try {
      // The shader reads physical fragment coordinates, so its resolution must
      // remain the actual half-resolution Syphon surface.
      fluidShader.set("resolution", float(OUTPUT_W), float(OUTPUT_H));
      fluidShader.set("time", motionTime * (artistPreset == 0 ? 0.56 : 0.78));
      fluidShader.set("drive", drive);
      fluidShader.set("density", densitySmooth);
      fluidShader.set("bass", bandValue[0]);
      fluidShader.set("mid", (bandValue[1] + bandValue[2]) * 0.5);
      fluidShader.set("high", (bandValue[3] + bandValue[4]) * 0.5);
      fluidShader.set("pulse", pulseSmooth);
      fluidShader.set("gather", gatherSmooth);
      fluidShader.set("intensity", masterIntensity);
      fluidShader.set("layoutA", float(layoutA));
      fluidShader.set("layoutB", float(layoutB));
      fluidShader.set("layoutMorph", morphEase());
      fluidShader.set("variation", float(variationState));
      fluidShader.set("eventSeed", float(eventCounter % 1009));
      fluidShader.set("impact", impactSmooth);
      fluidShader.set("rareBurst", rareBurst);
      fluidShader.set("burstCenter",
        macroCurrentX(rareRegion) + macroCurrentW(rareRegion) * 0.5,
        macroCurrentY(rareRegion) + macroCurrentH(rareRegion) * 0.5);
      pg.noStroke();
      // Explicit fill is essential because scenes 1–3 can legitimately finish
      // with noFill(). Without this, the shader rectangle is never submitted.
      pg.fill(255);
      pg.shader(fluidShader);
      pg.rect(0, 0, DESIGN_W, DESIGN_H);
      pg.resetShader();
    }
    catch (Throwable error) {
      shaderReady = false;
      pg.resetShader();
      println("Fluid shader failed. CPU contour fallback enabled.");
      println(error.getMessage());
      drawMembraneFallback(pg);
    }
  } else {
    drawMembraneFallback(pg);
  }
}

void drawMembraneFallback(PGraphics pg) {
  noiseDetail(5, 0.52);
  for (int region = 0; region < MACRO_COUNT; region++) {
    float priority = macroPriority(region);
    if (priority < 0.24) continue;
    float centerX = (macroCurrentX(region) + macroCurrentW(region) * 0.5) * DESIGN_W;
    float centerY = (macroCurrentY(region) + macroCurrentH(region) * 0.5) * DESIGN_H;
    int contours = 2 + int(priority * 2 + densitySmooth * 2 + impactSmooth);

    for (int c = contours - 1; c >= 0; c--) {
      float scale = (c + 1) / float(contours);
      float radiusX = macroCurrentW(region) * DESIGN_W * scale *
        (0.30 + bandValue[0] * 0.08);
      float radiusY = macroCurrentH(region) * DESIGN_H * scale *
        (0.28 + bandValue[1] * 0.08);
      pg.noFill();
      inkStroke(pg, 14 + priority * 76 + (contours - c) * 6 + impactSmooth * 24);
      pg.strokeWeight(0.8 + priority * 1.5 + bandValue[4] * 1.1);
      pg.beginShape();
      int segments = 72;
      for (int i = 0; i <= segments; i++) {
        float angle = TWO_PI * i / segments;
        float activityWave = 0.5 + 0.5 * sin(motionTime * 0.10 +
          region * 1.73 + eventCounter * 0.19);
        float activity = smoothStepValue(0.48, 0.82, activityWave);
        float localTime = motionTime * (0.032 + activity * 0.082);
        float n = noise(region * 2.1 + variationState * 0.43 + c * 0.18 +
          cos(angle) * 0.58 + localTime,
          sin(angle) * 0.58 - localTime * 0.64);
        float warp = 0.76 + n * (0.24 + bandValue[2] * 0.13 + impactSmooth * 0.05);
        float x = centerX + cos(angle) * radiusX * warp;
        float y = centerY + sin(angle) * radiusY * warp;
        pg.curveVertex(x, y);
      }
      pg.endShape(CLOSE);
    }
  }
}

// ---------------------------------------------------------------------------
// 5. ASCII VEIL — flowing glyph masses, smooth row displacement and fission.
// ---------------------------------------------------------------------------

void drawAsciiVeil(PGraphics pg) {
  float cellW = DESIGN_W / float(ASCII_COLS);
  float cellH = DESIGN_H / float(ASCII_ROWS);
  int baseRow = floor(asciiScroll);
  float rowFraction = asciiScroll - baseRow;
  float shapeMorph = morphEase();
  int veilMode = variationState % 4;

  pg.textFont(mono);
  pg.textSize(min(cellW, cellH) *
    (0.90 + bandValue[0] * 0.12 + impactSmooth * 0.055));
  pg.textAlign(CENTER, CENTER);
  pg.noStroke();

  for (int row = -1; row <= ASCII_ROWS; row++) {
    int virtualRow = row + baseRow;
    float y = (row - rowFraction + 0.5) * cellH;
    float v = ((virtualRow % ASCII_ROWS) + ASCII_ROWS + 0.5) / float(ASCII_ROWS);
    v = v % 1.0;
    int slice = constrain(int(map(y, 0, DESIGN_H, 0, ASCII_SLICES)), 0, ASCII_SLICES - 1);
    float rowShift = asciiShift[slice] * (0.38 + impactSmooth * 0.28);

    for (int col = 0; col < ASCII_COLS; col++) {
      float u = (col + 0.5) / ASCII_COLS;
      int region = macroRegionAt(u, v);
      float priority = macroPriority(region);
      float regionalDensity = macroDensity(region);
      float shapeA = asciiShape(layoutA, u, v);
      float shapeB = asciiShape(layoutB, u, v);
      float shape = lerp(shapeA, shapeB, shapeMorph);
      float organicScaleX = veilMode == 1 ? 5.2 : veilMode == 2 ? 2.4 : 3.4;
      float organicScaleY = veilMode == 3 ? 5.0 : veilMode == 2 ? 2.8 : 3.8;
      float organic = noise(u * organicScaleX + motionTime * (veilMode == 2 ? 0.045 : 0.09),
        v * organicScaleY - motionTime * (veilMode == 1 ? 0.10 : 0.055) +
        variationState * 0.41 + eventCounter * 0.013);
      shape += (organic - 0.5) * (0.22 + bandValue[2] * 0.10);
      float contourLevel = 0.43 + sin(
        (veilMode % 2 == 0 ? v : u) * (5.1 + veilMode * 0.7) +
        variationState * 0.73) * 0.035;
      float contour = 1.0 - smoothStepValue(0.025, 0.18,
        abs(shape - contourLevel));
      float secondaryContour = 1.0 - smoothStepValue(0.022, 0.15,
        abs(shape - (contourLevel + (veilMode == 2 ? 0.17 : -0.13))));
      float interior = smoothStepValue(0.34, 0.72, shape);
      float contourWeight = veilMode == 0 ? 0.62 : veilMode == 1 ? 0.48 : 0.56;
      float interiorWeight = veilMode == 1 ? 0.10 : veilMode == 3 ? 0.34 : 0.20;
      float occupancy = contour * (contourWeight + highBandEnergy() * 0.18) +
        secondaryContour * (veilMode == 2 ? 0.34 : 0.10) +
        interior * (interiorWeight + densitySmooth * 0.24 + densityBurstSmooth * 0.22) +
        organic * (veilMode == 3 ? 0.19 : 0.12) +
        macroInfluence(u, v, region) * priority * 0.045;

      float cellSeed = fixedHash(col * 197 + virtualRow * 89 + layoutB * 43);
      float regionalState = fixedHash(region * 397 + eventCounter * 109 + veilMode * 67);
      float dissolve = 0.43 - densitySmooth * 0.070 - regionalDensity * 0.035 -
        densityBurstSmooth * 0.075 + (cellSeed - 0.5) *
        (0.17 + veilMode * 0.018 + impactSmooth * 0.055) +
        (regionalState - 0.5) * 0.12;
      if (occupancy < dissolve) continue;

      float crackNoise = noise(v * 2.8 + variationState * 0.9,
        motionTime * 0.12 + eventCounter * 0.07);
      float crackCenter = 0.50 + sin(v * 6.2 + variationState * 1.17) * 0.095 +
        (crackNoise - 0.5) * 0.18;
      float crackCoordinate = u;
      if (veilMode == 1) {
        crackCoordinate = v;
        crackCenter = 0.48 + sin(u * 5.4 + variationState) * 0.10;
      } else if (veilMode == 2) {
        crackCoordinate = u + v * 0.32;
        crackCenter += 0.16;
      } else if (veilMode == 3) {
        crackCoordinate = u - v * 0.24;
        crackCenter -= 0.12;
      }
      float crackWidth = impactSmooth > 0.10 ?
        0.004 + impactSmooth * (0.012 + bandValue[4] * 0.010) : 0;
      float crackDistance = abs(crackCoordinate - crackCenter);
      if (crackDistance < crackWidth) continue;

      float fission = 0;
      if (impactSmooth > 0.10 && slice % 3 == (eventCounter + variationState) % 3) {
        fission = (crackCoordinate < crackCenter ? -1 : 1) * impactSmooth *
          (18 + bandValue[1] * 76);
      }
      float tearGate = fixedHash(col * 349 + virtualRow * 151 + eventCounter * 59);
      if (impactSmooth > 0.28 && tearGate < impactSmooth * 0.055) continue;
      float flowShift = sin(v * 7.0 + organic * 2.4 + motionTime * 0.24) *
        (3 + bandValue[2] * 16 + impactSmooth * 8);
      float xShift = veilMode == 1 ? fission * 0.32 : fission;
      float yShift = veilMode == 1 ? fission * 0.46 :
        veilMode == 3 ? fission * 0.16 : 0;
      float x = (col + 0.5) * cellW + rowShift + xShift + flowShift;
      if (x < -cellW || x > DESIGN_W + cellW) continue;

      int eventStep = eventCounter / 2;
      int glyphIndex = int(fixedHash(col * 101 + virtualRow * 61 +
        eventStep * 127) * ASCII_GLYPHS.length());
      glyphIndex = constrain(glyphIndex, 0, ASCII_GLYPHS.length() - 1);
      float alpha = constrain(map(occupancy - dissolve, 0, 0.42, 54, 246), 38, 246) *
        (0.82 + priority * 0.18);
      inkFill(pg, alpha);
      float yJitter = sin(col * 1.73 + virtualRow * 0.41 + motionTime * 0.24) *
        bandValue[4] * cellH * 0.10;
      pg.text(ASCII_GLYPHS.charAt(glyphIndex), x, y + yJitter + yShift);
    }
  }

  // Strong events leave a few thin torn residues, never a rectangular layout.
  for (int i = 0; i < ASCII_SLICES; i++) {
    float amount = abs(asciiShift[i]);
    if (amount < 34 || i % 3 != (eventCounter + variationState) % 3) continue;
    float y = (i + 0.5) * DESIGN_H / ASCII_SLICES;
    pg.noStroke();
    inkFill(pg, 10 + min(48, amount * 0.16));
    float w = min(DESIGN_W * 0.17, amount * 1.10);
    float seed = fixedHash(i * 331 + eventCounter * 107);
    float x = DESIGN_W * (0.10 + seed * 0.72) - w * 0.5;
    pg.rect(x, y - 1, w, 1.4 + bandValue[4] * 2.2);
  }
}

float highBandEnergy() {
  return constrain((bandValue[3] + bandValue[4]) * 0.5, 0, 1);
}

float asciiShape(int state, float u, float v) {
  float spread = 0.80 + gatherSmooth * 0.20;
  float value = 0;

  if (state == 0) {
    value = max(
      softBlob(u, v, 0.31, 0.43, 0.33, 0.29, spread),
      softBlob(u, v, 0.72, 0.60, 0.34, 0.25, spread)
    );
    value = max(value, softBlob(u, v, 0.52, 0.18, 0.22, 0.18, spread));
  } else if (state == 1) {
    value = max(
      softBlob(u, v, 0.18, 0.30, 0.26, 0.32, spread),
      softBlob(u, v, 0.81, 0.68, 0.27, 0.31, spread)
    );
    value = max(value, softBlob(u, v, 0.50, 0.50, 0.39, 0.14, spread));
  } else if (state == 2) {
    value = max(
      softBlob(u, v, 0.20, 0.78, 0.28, 0.22, spread),
      softBlob(u, v, 0.50, 0.48, 0.31, 0.24, spread)
    );
    value = max(value, softBlob(u, v, 0.80, 0.21, 0.26, 0.21, spread));
  } else {
    value = max(
      softBlob(u, v, 0.09, 0.48, 0.22, 0.38, spread),
      softBlob(u, v, 0.57, 0.36, 0.39, 0.25, spread)
    );
    value = max(value, softBlob(u, v, 0.89, 0.75, 0.21, 0.27, spread));
  }
  value = max(value, softBlob(u, v, 0.50, 0.52, 0.47, 0.42, 1.0) * 0.74);
  return value;
}

float softBlob(float u, float v, float cx, float cy, float rx, float ry, float spread) {
  float centerX = 0.5 + (cx - 0.5) * spread;
  float centerY = 0.5 + (cy - 0.5) * spread;
  float dx = (u - centerX) / max(0.01, rx);
  float dy = (v - centerY) / max(0.01, ry);
  return exp(-(dx * dx + dy * dy) * 1.48);
}

// ---------------------------------------------------------------------------
// 6. PULSE — onset-driven monochrome exposure events.
// ---------------------------------------------------------------------------

void spawnPulseEvent(float strength, int band) {
  PulseEvent slot = pulseEvents[0];
  float oldest = -1;
  for (int i = 0; i < PULSE_EVENT_COUNT; i++) {
    if (!pulseEvents[i].active) {
      slot = pulseEvents[i];
      break;
    }
    float ageRatio = pulseEvents[i].age / max(1.0, pulseEvents[i].duration);
    if (ageRatio > oldest) {
      oldest = ageRatio;
      slot = pulseEvents[i];
    }
  }
  slot.start(strength, band, eventCounter);
}

void drawPulse(PGraphics pg) {
  pg.blendMode(ADD);
  pg.noStroke();
  float air = constrain(drive * 0.55 + highBandEnergy() * 0.18, 0, 1);
  if (air > 0.03) {
    pg.fill(250, 249, 246, 2 + air * 7);
    pg.rect(0, 0, DESIGN_W, DESIGN_H);
  }
  for (int i = 0; i < PULSE_EVENT_COUNT; i++) {
    if (pulseEvents[i].active) pulseEvents[i].display(pg);
  }
  pg.blendMode(BLEND);
}

// ---------------------------------------------------------------------------
// 7. IMAGE SEQUENCE — preloaded monochrome frames with audio-paced switching.
// ---------------------------------------------------------------------------

void loadImageSequence() {
  sequenceFrameCount = 0;
  for (int i = 0; i < SEQUENCE_COUNT; i++) {
    try {
      PImage frame = loadImage("sequence/A" + (i + 1) + ".png");
      if (frame == null) continue;
      // Keep the project palette coherent even if a source frame contains
      // residual colour. The original files on disk are not modified.
      frame.filter(GRAY);
      sequenceFrames[sequenceFrameCount] = frame;
      sequenceFrameCount++;
    }
    catch (Throwable error) {
      println("Sequence frame A" + (i + 1) + " could not be loaded.");
    }
  }
  sequenceReady = sequenceFrameCount > 0;
  if (sequenceReady) {
    println("Image sequence ready: " + sequenceFrameCount + " frames.");
  } else {
    println("Image sequence unavailable. Scene 7 will remain black.");
  }
}

void resetImageSequenceScene() {
  sequenceAccumulator = 0;
  sequenceBurst = 0;
  sequenceRate = 0;
  sequenceDirection = 1;
  sequenceScanActive = false;
  sequenceScanProgress = 1;
  sequenceWhiteFlashFrames = 0;
  sequenceBlackFlashFrames = 0;
  sequenceAfterimage = 0;
}

void updateImageSequenceState() {
  if (currentScene != 6 || !sequenceReady) return;

  float mid = constrain((bandValue[1] + bandValue[2]) * 0.5, 0, 1);
  float high = highBandEnergy();
  float energy = constrain(drive * 0.64 + bandValue[0] * 0.14 +
    mid * 0.10 + high * 0.12, 0, 1);
  float shaped = pow(energy, artistPreset == 0 ? 0.86 : 0.72);
  float maximumRate = artistPreset == 0 ? 11.5 : 18.0;
  float baseRate = lerp(0.24, maximumRate, shaped);
  if (drive < 0.035 && energy < 0.055) baseRate = 0.10;

  sequenceBurst *= artistPreset == 0 ? 0.905 : 0.885;
  float rateTarget = constrain(baseRate + sequenceBurst, 0.05, 30.0);
  sequenceRate = lerp(sequenceRate, rateTarget,
    rateTarget > sequenceRate ? 0.24 : 0.105);
  sequenceAfterimage *= 0.84;

  if (sequenceScanActive) {
    sequenceScanProgress += 1.0 / max(1.0, sequenceScanDuration);
    if (sequenceScanProgress >= 1.0) {
      sequenceScanProgress = 1.0;
      sequenceScanActive = false;
    }
  }

  sequenceAccumulator += sequenceRate / 60.0;
  int advances = 0;
  while (sequenceAccumulator >= 1.0 && advances < 3) {
    sequenceAccumulator -= 1.0;
    advanceImageSequence(false, dominantBand());
    advances++;
  }
}

void triggerImageSequenceOnset(float strength, int dominant) {
  if (!sequenceReady) return;
  float presetForce = artistPreset == 0 ? 0.72 : 1.0;
  float burstRate = lerp(5.5, 17.0, strength) * presetForce;
  sequenceBurst = max(sequenceBurst, burstRate);

  // Most attacks advance cleanly. A rare mid/high attack skips or reverses one
  // step, then normal forward order resumes on the following switch.
  if (strength > 0.34) advanceImageSequence(true, dominant);

  float whiteGate = fixedHash(eventCounter * 2203 + dominant * 421);
  if (strength > 0.54 && whiteGate > (artistPreset == 0 ? 0.62 : 0.48)) {
    sequenceWhiteFlashFrames = strength > 0.82 && whiteGate > 0.84 ? 2 : 1;
  }
  float blackGate = fixedHash(eventCounter * 2281 + dominant * 463);
  if (strength > 0.82 && blackGate > 0.925) sequenceBlackFlashFrames = 1;
}

void advanceImageSequence(boolean fromOnset, int dominant) {
  if (!sequenceReady || sequenceFrameCount < 1) return;
  previousSequenceIndex = sequenceIndex;
  sequenceSwitchCounter++;

  int step = sequenceDirection;
  if (fromOnset && dominant >= 2) {
    float gesture = fixedHash(eventCounter * 2333 +
      sequenceSwitchCounter * 499 + dominant * 71);
    if (gesture > 0.91) step = -sequenceDirection;
    else if (gesture > 0.72) step = sequenceDirection * 2;
  }
  sequenceIndex = (sequenceIndex + step) % sequenceFrameCount;
  if (sequenceIndex < 0) sequenceIndex += sequenceFrameCount;

  float high = highBandEnergy();
  float scanGate = fixedHash(sequenceSwitchCounter * 2381 + eventCounter * 521);
  boolean scanEvent = fromOnset ?
    scanGate > (artistPreset == 0 ? 0.38 : 0.25) :
    sequenceRate > 4.0 && scanGate > 0.935 - high * 0.06;
  if (scanEvent) beginImageSequenceScan(dominant);

  if (fromOnset || high > 0.38) {
    sequenceAfterimage = max(sequenceAfterimage,
      (fromOnset ? 0.20 : 0.08) + high * 0.20);
  }
}

void beginImageSequenceScan(int dominant) {
  float seed = fixedHash(eventCounter * 2417 + sequenceSwitchCounter * 557);
  sequenceScanBands = constrain(3 + int(seed * 4.0), 3, 6);
  sequenceScanDuration = constrain(int(lerp(12, 6,
    bandValue[constrain(dominant, 0, BAND_COUNT - 1)])), 6, 12);
  sequenceScanProgress = 0;
  sequenceScanActive = true;
}

void drawImageSequence(PGraphics pg) {
  if (!sequenceReady || sequenceFrameCount < 1) return;

  PImage currentFrame = sequenceFrames[sequenceIndex];
  PImage oldFrame = sequenceFrames[previousSequenceIndex];
  pg.imageMode(CORNER);
  pg.blendMode(BLEND);
  pg.noTint();

  if (!sequenceScanActive) {
    pg.tint(250, 249, 246, 255);
    pg.image(currentFrame, 0, 0, DESIGN_W, DESIGN_H);
  } else {
    pg.tint(250, 249, 246, 255);
    pg.image(oldFrame, 0, 0, DESIGN_W, DESIGN_H);

    float progress = smoothStepValue(0, 1, sequenceScanProgress);
    for (int band = 0; band < sequenceScanBands; band++) {
      float delay = fixedHash(band * 613 + sequenceSwitchCounter * 101) * 0.38;
      float local = constrain((progress - delay) / max(0.01, 1.0 - delay), 0, 1);
      if (local <= 0.001) continue;

      // Quantised settling keeps the scan stepped rather than mechanically
      // smooth, while the broad bands preserve the full-frame composition.
      float stepped = floor(local * 6.0) / 6.0;
      float direction = fixedHash(band * 677 + sequenceSwitchCounter * 137) > 0.5 ? 1 : -1;
      float xOffset = direction * (1.0 - stepped) * DESIGN_W *
        (0.010 + highBandEnergy() * 0.018);
      int sourceY0 = int(band * currentFrame.height / float(sequenceScanBands));
      int sourceY1 = int((band + 1) * currentFrame.height / float(sequenceScanBands));
      float destinationY = band * DESIGN_H / float(sequenceScanBands);
      float destinationH = (band + 1) * DESIGN_H / float(sequenceScanBands) - destinationY;
      float reveal = local < 0.18 ? local / 0.18 : 1.0;
      pg.tint(250, 249, 246, 255 * reveal);
      pg.image(currentFrame, xOffset, destinationY - 1,
        DESIGN_W, destinationH + 2,
        0, sourceY0, currentFrame.width, sourceY1);
    }
  }

  // One dim, displaced full-frame residue can follow a strong attack. It is
  // deliberately brief and never becomes an always-on feedback loop.
  if (!sequenceScanActive && sequenceAfterimage > 0.025) {
    float direction = sequenceSwitchCounter % 2 == 0 ? 1 : -1;
    pg.blendMode(ADD);
    pg.tint(250, 249, 246, 255 * sequenceAfterimage * 0.16);
    pg.image(oldFrame, direction * DESIGN_W * 0.006,
      -direction * DESIGN_H * 0.003, DESIGN_W, DESIGN_H);
    pg.blendMode(BLEND);
  }
  pg.noTint();

  if (sequenceWhiteFlashFrames > 0) {
    pg.blendMode(ADD);
    pg.noStroke();
    float alpha = sequenceWhiteFlashFrames >= 2 ? 188 : 92;
    pg.fill(250, 249, 246, alpha);
    pg.rect(0, 0, DESIGN_W, DESIGN_H);
    pg.blendMode(BLEND);
    sequenceWhiteFlashFrames--;
  }
  if (sequenceBlackFlashFrames > 0) {
    pg.blendMode(BLEND);
    pg.noStroke();
    pg.fill(0, 242);
    pg.rect(0, 0, DESIGN_W, DESIGN_H);
    sequenceBlackFlashFrames--;
  }
}

// ---------------------------------------------------------------------------
// Shared drawing and diagnostics.
// ---------------------------------------------------------------------------

void drawMacroCorners(PGraphics pg, int id, float alpha, float fraction) {
  float x = macroCurrentX(id) * DESIGN_W;
  float y = macroCurrentY(id) * DESIGN_H;
  float w = macroCurrentW(id) * DESIGN_W;
  float h = macroCurrentH(id) * DESIGN_H;
  float sx = max(9, w * fraction);
  float sy = max(9, h * fraction);
  pg.noFill();
  inkStroke(pg, alpha);
  pg.strokeWeight(0.9 + bandValue[id % BAND_COUNT] * 1.2);
  int omitted = (id + layoutB) % 4;
  if (omitted != 0) {
    pg.line(x, y, x + sx, y);
    pg.line(x, y, x, y + sy);
  }
  if (omitted != 1) {
    pg.line(x + w - sx, y, x + w, y);
    pg.line(x + w, y, x + w, y + sy);
  }
  if (omitted != 2) {
    pg.line(x, y + h, x + sx, y + h);
    pg.line(x, y + h - sy, x, y + h);
  }
  if (omitted != 3) {
    pg.line(x + w - sx, y + h, x + w, y + h);
    pg.line(x + w, y + h - sy, x + w, y + h);
  }
}

void drawLooseCorners(PGraphics pg, float x, float y, float w, float h,
    float alpha, float fraction, int seedId) {
  float sx = max(8, w * fraction);
  float sy = max(8, h * fraction);
  pg.noFill();
  inkStroke(pg, alpha);
  pg.strokeWeight(0.9 + bandValue[abs(seedId) % BAND_COUNT] * 1.2);
  int omitted = abs(seedId + layoutB + variationState) % 4;
  if (omitted != 0) {
    pg.line(x, y, x + sx, y);
    pg.line(x, y, x, y + sy);
  }
  if (omitted != 1) {
    pg.line(x + w - sx, y, x + w, y);
    pg.line(x + w, y, x + w, y + sy);
  }
  if (omitted != 2) {
    pg.line(x, y + h, x + sx, y + h);
    pg.line(x, y + h - sy, x, y + h);
  }
  if (omitted != 3) {
    pg.line(x + w - sx, y + h, x + w, y + h);
    pg.line(x + w, y + h - sy, x + w, y + h);
  }
}

void drawSoftRegion(PGraphics pg, float x, float y, float w, float h, float alpha) {
  pg.noStroke();
  for (int layer = 5; layer >= 1; layer--) {
    float spread = layer * 8.0;
    inkFill(pg, alpha * (0.018 + (5 - layer) * 0.010));
    pg.rect(x - spread, y - spread, w + spread * 2, h + spread * 2);
  }
  inkFill(pg, alpha * 0.66);
  pg.rect(x, y, w, h);
}

void drawSignalMarks(PGraphics pg, int count, float strength) {
  pg.rectMode(CENTER);
  pg.ellipseMode(CENTER);
  for (int i = 0; i < count; i++) {
    int id = (i * 5 + layoutB * 2) % MACRO_COUNT;
    float priority = macroPriority(id);
    if (priority < 0.34) continue;
    float localU = fixedHash(1709 + i * 97 + layoutB * 13);
    float localV = fixedHash(1901 + i * 127 + layoutB * 19);
    float x = (macroCurrentX(id) + macroCurrentW(id) * localU) * DESIGN_W;
    float y = (macroCurrentY(id) + macroCurrentH(id) * localV) * DESIGN_H;
    float seed = fixedHash(2111 + i * 173);
    float size = (2.0 + seed * 7.0) * (0.72 + bandValue[i % BAND_COUNT] * 0.70);
    float alpha = (28 + priority * 92 + bandValue[4] * 34) * strength;
    int form = int(seed * 5.0);

    if (form == 0) {
      pg.noStroke();
      inkFill(pg, alpha);
      pg.rect(x, y, size * 3.4, max(1.3, size * 0.42));
    } else if (form == 1) {
      pg.noFill();
      inkStroke(pg, alpha);
      pg.strokeWeight(0.9 + bandValue[4] * 0.8);
      pg.pushMatrix();
      pg.translate(x, y);
      pg.rotate(QUARTER_PI);
      pg.rect(0, 0, size, size);
      pg.popMatrix();
    } else if (form == 2) {
      inkStroke(pg, alpha);
      pg.strokeWeight(0.9 + bandValue[4] * 0.7);
      pg.line(x - size, y, x + size, y);
      pg.line(x, y - size, x, y + size);
    } else if (form == 3) {
      pg.noStroke();
      inkFill(pg, alpha);
      pg.ellipse(x, y, max(1.5, size * 0.45), max(1.5, size * 0.45));
    } else {
      pg.noStroke();
      inkFill(pg, alpha * 0.78);
      for (int dot = 0; dot < 3; dot++) {
        pg.rect(x + dot * size * 0.72, y, max(1.2, size * 0.25), max(1.2, size * 0.25));
      }
    }
  }
  pg.rectMode(CORNER);
}

void triggerBeatFlash(float strength, int dominant) {
  if (!beatFlashEnabled) return;

  float frequencyWeight = dominant == 0 ? 1.0 : dominant == 1 ? 0.88 :
    dominant == 2 ? 0.62 : dominant == 3 ? 0.38 : 0.30;
  float drumStrength = constrain(strength * frequencyWeight +
    lowFrequencySupport * 0.20, 0, 1);
  float threshold = artistPreset == 0 ? 0.46 : 0.25;
  if (drumStrength < threshold) return;

  float selector = fixedHash(eventCounter * 2591 + dominant * 593);
  beatFlashPattern = int(selector * 5.0) % 5;
  beatFlashRegion = (eventCounter * 7 + dominant * 3 + layoutB) % MACRO_COUNT;

  if (artistPreset == 0) {
    if (beatFlashPattern == 0 && drumStrength > 0.62) {
      globalBeatFlashTarget = max(globalBeatFlashTarget, drumStrength * 0.58);
    } else if (beatFlashPattern == 1 || beatFlashPattern == 3) {
      localBeatFlashTarget = max(localBeatFlashTarget, drumStrength * 0.62);
    } else if (beatFlashPattern == 2 && drumStrength > 0.72) {
      globalBeatFlashTarget = max(globalBeatFlashTarget, drumStrength * 0.38);
      localBeatFlashTarget = max(localBeatFlashTarget, drumStrength * 0.52);
    }
  } else {
    if (beatFlashPattern == 0) {
      globalBeatFlashTarget = max(globalBeatFlashTarget,
        constrain(0.42 + drumStrength * 0.66, 0, 1));
    } else if (beatFlashPattern == 1) {
      localBeatFlashTarget = max(localBeatFlashTarget,
        constrain(0.46 + drumStrength * 0.62, 0, 1));
    } else if (beatFlashPattern == 2) {
      globalBeatFlashTarget = max(globalBeatFlashTarget,
        constrain(0.24 + drumStrength * 0.54, 0, 1));
      localBeatFlashTarget = max(localBeatFlashTarget,
        constrain(0.34 + drumStrength * 0.56, 0, 1));
    } else if (beatFlashPattern == 3) {
      globalBeatFlashTarget = max(globalBeatFlashTarget, drumStrength * 0.34);
      localBeatFlashTarget = max(localBeatFlashTarget,
        constrain(0.38 + drumStrength * 0.64, 0, 1));
    } else if (drumStrength > 0.74) {
      globalBeatFlashTarget = max(globalBeatFlashTarget, drumStrength * 0.72);
    } else {
      localBeatFlashTarget = max(localBeatFlashTarget, drumStrength * 0.42);
    }

    float cutGate = fixedHash(eventCounter * 2683 + dominant * 641);
    if (drumStrength > 0.82 && dominant <= 1 && cutGate > 0.945) {
      beatCutFrames = 1;
    }
  }
}

void drawBeatFlash(PGraphics pg) {
  if (globalBeatFlash < 0.008 && localBeatFlash < 0.008 && beatCutFrames <= 0) return;

  pg.rectMode(CORNER);
  pg.blendMode(ADD);
  pg.noStroke();

  if (localBeatFlash > 0.008) {
    float x;
    float y;
    float w;
    float h;
    if (beatFlashPattern == 1) {
      x = 0;
      w = DESIGN_W;
      h = DESIGN_H * (0.15 + localBeatFlash * 0.16);
      y = constrain((macroCurrentY(beatFlashRegion) +
        macroCurrentH(beatFlashRegion) * 0.5) * DESIGN_H - h * 0.5,
        -h * 0.25, DESIGN_H - h * 0.75);
    } else if (beatFlashPattern == 3) {
      y = 0;
      h = DESIGN_H;
      w = DESIGN_W * (0.12 + localBeatFlash * 0.14);
      x = constrain((macroCurrentX(beatFlashRegion) +
        macroCurrentW(beatFlashRegion) * 0.5) * DESIGN_W - w * 0.5,
        -w * 0.25, DESIGN_W - w * 0.75);
    } else {
      x = macroCurrentX(beatFlashRegion) * DESIGN_W;
      y = macroCurrentY(beatFlashRegion) * DESIGN_H;
      w = max(DESIGN_W * 0.28, macroCurrentW(beatFlashRegion) * DESIGN_W * 1.18);
      h = max(DESIGN_H * 0.25, macroCurrentH(beatFlashRegion) * DESIGN_H * 1.16);
      x -= w * 0.08;
      y -= h * 0.08;
    }
    drawSoftBeatRegion(pg, x, y, w, h, localBeatFlash);
  }

  if (globalBeatFlash > 0.008) {
    float flashAlpha = globalBeatFlash * (artistPreset == 0 ? 82 : 158);
    pg.fill(250, 249, 246, flashAlpha);
    pg.rect(0, 0, DESIGN_W, DESIGN_H);

    if (artistPreset == 1 && globalBeatFlash > 0.58 && beatFlashPattern == 0) {
      float bandH = DESIGN_H * (0.12 + globalBeatFlash * 0.12);
      float y = ((beatFlashRegion + 0.5) / MACRO_COUNT) * DESIGN_H - bandH * 0.5;
      pg.fill(250, 249, 246, globalBeatFlash * 72);
      pg.rect(0, y, DESIGN_W, bandH);
    }
  }
  pg.blendMode(BLEND);

  if (beatCutFrames > 0) {
    pg.noStroke();
    pg.fill(0, 238);
    pg.rect(0, 0, DESIGN_W, DESIGN_H);
    beatCutFrames--;
  }
}

void drawSoftBeatRegion(PGraphics pg, float x, float y, float w, float h,
    float strength) {
  for (int layer = 12; layer >= 0; layer--) {
    float t = layer / 12.0;
    float spread = t * (38 + strength * 62);
    float layerAlpha = strength * lerp(18, 2.5, t);
    pg.fill(250, 249, 246, layerAlpha);
    pg.rect(x - spread, y - spread, w + spread * 2, h + spread * 2);
  }
}

void drawRareTransient(PGraphics pg) {
  float cx = (macroCurrentX(rareRegion) + macroCurrentW(rareRegion) * 0.5) * DESIGN_W;
  float cy = (macroCurrentY(rareRegion) + macroCurrentH(rareRegion) * 0.5) * DESIGN_H;
  float radius = min(DESIGN_W, DESIGN_H) * (0.038 + rareBurst * 0.070);
  pg.blendMode(ADD);
  pg.noStroke();
  for (int layer = 7; layer >= 0; layer--) {
    float t = layer / 7.0;
    float r = radius * (0.36 + t * 2.35);
    pg.fill(250, 249, 246, rareBurst * (8 + (1.0 - t) * 34));
    pg.ellipse(cx, cy, r * 1.08, r * 0.82);
  }
  pg.fill(250, 249, 246, rareBurst * 188);
  pg.ellipse(cx, cy, radius * 0.48, radius * 0.36);

  int rays = 7;
  for (int i = 0; i < rays; i++) {
    float angle = TWO_PI * fixedHash(eventCounter * 433 + i * 101);
    float length = radius * (1.4 + fixedHash(eventCounter * 557 + i * 151) * 2.8);
    float start = radius * (0.30 + fixedHash(i * 61 + eventCounter) * 0.34);
    pg.stroke(250, 249, 246, rareBurst * (42 + bandValue[4] * 54));
    pg.strokeWeight(0.8 + rareBurst * 2.2);
    pg.line(cx + cos(angle) * start, cy + sin(angle) * start,
      cx + cos(angle) * length, cy + sin(angle) * length);
  }
  pg.blendMode(BLEND);
}

void drawRedScan(PGraphics pg) {
  float high = bandValue[4];
  float beatEnergy = max(globalBeatFlash, localBeatFlash * 0.70);
  float stepCount = max(32.0, 210 - pulseSmooth * 118 - high * 42 -
    beatEnergy * (artistPreset == 0 ? 28 : 72));
  float steppedPhase = floor(scanPhase * stepCount) / stepCount;
  float frameGate = fixedHash(frameCount * 193 + eventCounter * 379);
  float jump = 0;
  if ((pulseSmooth > 0.10 || beatEnergy > 0.10) && frameGate > 0.40) {
    jump = (fixedHash(frameCount * 271 + eventCounter * 149) - 0.5) *
      DESIGN_H * (0.025 + high * 0.065 + pulseSmooth * 0.035 + beatEnergy * 0.055);
  }
  float y = (steppedPhase * DESIGN_H + jump + DESIGN_H) % DESIGN_H;
  float blink = pulseSmooth > 0.08 || beatEnergy > 0.08 ?
    (frameGate > 0.34 ? 1.0 : 0.12) : 1.0;
  float flash = pow(constrain(pulseSmooth, 0, 1), 1.20) *
    (9 + drive * 22 + high * 15) * blink +
    beatEnergy * (artistPreset == 0 ? 12 : 42) * blink;

  pg.blendMode(ADD);
  pg.noStroke();
  if (flash > 1) {
    pg.fill(250, 249, 246, flash);
    pg.rect(0, 0, DESIGN_W, DESIGN_H);
  }
  float halo = 7 + bandValue[2] * 18 + pulseSmooth * 14 + beatEnergy * 18;
  pg.fill(255, 20, 10, (18 + drive * 30 + high * 36) * blink);
  pg.rect(0, y - halo * 0.5, DESIGN_W, halo);
  pg.fill(255, 62, 38, (132 + drive * 72 + high * 48) * blink);
  pg.rect(0, y - 1, DESIGN_W,
    1.6 + high * 3.8 + pulseSmooth * 2.8);

  float echoY = ((scanPhase + 0.12 + bandValue[1] * 0.08) % 1.0) * DESIGN_H;
  pg.fill(255, 32, 18, (16 + high * 38) * blink);
  pg.rect(0, echoY, DESIGN_W, 1 + high * 1.8);

  if (pulseSmooth > 0.10 || beatEnergy > 0.10) {
    for (int i = 0; i < 3; i++) {
      float seed = fixedHash(eventCounter * 431 + i * 97);
      float segmentX = DESIGN_W * seed;
      float segmentW = DESIGN_W * (0.035 + fixedHash(eventCounter * 613 + i * 157) * 0.16);
      float segmentY = y + (fixedHash(frameCount * 83 + i * 211) - 0.5) *
        (14 + high * 42);
      pg.fill(255, 52, 28, (38 + pulseSmooth * 96) * blink);
      pg.rect(segmentX, segmentY, segmentW, 1.2 + high * 3.4);
    }
  }
  pg.blendMode(BLEND);
}

void drawCenterReserve(PGraphics pg) {
  pg.rectMode(CENTER);
  pg.noStroke();
  for (int i = 10; i >= 0; i--) {
    float t = i / 10.0;
    pg.fill(0, lerp(18, 255, 1.0 - t));
    pg.rect(DESIGN_W * 0.5, DESIGN_H * 0.5,
      DESIGN_W * (0.29 + t * 0.055), DESIGN_H * (0.20 + t * 0.075));
  }
  pg.rectMode(CORNER);
}

void inkFill(PGraphics pg, float alphaValue) {
  float a = constrain(alphaValue * masterIntensity, 0, 255);
  pg.fill(250, 249, 246, a);
}

void inkStroke(PGraphics pg, float alphaValue) {
  float a = constrain(alphaValue * masterIntensity, 0, 255);
  pg.stroke(250, 249, 246, a);
}

void drawDebugOverlay() {
  float x = 16;
  float y = height - 254;
  float w = min(850, width - 32);
  float h = 238;
  noStroke();
  fill(0, 238);
  rect(x, y, w, h);
  stroke(255, 72);
  noFill();
  rect(x, y, w, h);

  textFont(uiFont);
  textAlign(LEFT, TOP);
  String source = testSignal ? "TEST" : audioReady ? "MIC" : "NO MIC";
  String syphonState = !syphonReady ? "SYPHON OFF" :
    syphonHasClient ? "SYPHON CONNECTED" : "SYPHON SOURCE LIVE";
  fill(250);
  textSize(20);
  text("MIC CONTROL", x + 18, y + 14);
  textSize(13);
  fill(190);
  text(sceneNames[currentScene] + "  /  " + presetNames[artistPreset] +
    "  /  " + source + "  /  " + syphonState, x + 174, y + 19);

  fill(liveMicGuard ? 250 : 145);
  textSize(15);
  text("LIVE MIC GUARD  " + (liveMicGuard ? "ON" : "OFF") + "   [L]",
    x + w - 250, y + 15);
  fill(beatFlashEnabled ? 250 : 145);
  textSize(13);
  text("BEAT FLASH  " + (beatFlashEnabled ? "ON" : "OFF") + "   [F]",
    x + w - 250, y + 37);

  drawDebugMeter("RAW MIC", rawMicSignal, x + 18, y + 58, w - 196);
  drawDebugMeter("VISUAL SIGNAL", drive, x + 18, y + 93, w - 196);

  fill(250);
  textSize(18);
  text("MIC SENSITIVITY   " + nf(inputGain, 1, 2) + "x", x + 18, y + 134);
  textSize(15);
  fill(220);
  text("[-] LESS", x + 278, y + 137);
  text("[=] MORE", x + 386, y + 137);
  text("[C] CALIBRATE", x + 500, y + 137);

  fill(248);
  textSize(16);
  text("STATUS   " + micStatusText(), x + 18, y + 172);
  fill(160);
  textSize(12);
  text("RAW MIC is what the microphone hears. VISUAL SIGNAL is what controls the visuals.",
    x + 18, y + 201);
  text("Onset " + nf(onsetScore, 1, 2) + " / " + nf(effectiveOnsetThreshold(), 1, 2) +
    "     Low-frequency support " + nf(lowFrequencySupport, 1, 2) +
    "     Press D to close this panel.", x + 18, y + 218);
}

void drawDebugMeter(String label, float value, float x, float y, float widthValue) {
  float meterX = x + 138;
  float meterW = max(120, widthValue - 138);
  float constrainedValue = constrain(value, 0, 1);
  fill(210);
  textSize(14);
  text(label, x, y + 2);
  noStroke();
  fill(255, 28);
  rect(meterX, y, meterW, 20);
  fill(250, 249, 246, 222);
  rect(meterX, y, meterW * constrainedValue, 20);
  noFill();
  stroke(255, 76);
  rect(meterX, y, meterW, 20);
  noStroke();
  fill(235);
  textAlign(RIGHT, TOP);
  text(nf(constrainedValue, 1, 2), meterX + meterW + 52, y + 2);
  textAlign(LEFT, TOP);
}

String micStatusText() {
  if (testSignal) return "TEST SIGNAL";
  if (!audioReady) return "NO MICROPHONE";
  if (calibrationFrames > 0) {
    int secondsLeft = max(1, int(ceil(calibrationFrames / 60.0)));
    return "CALIBRATING " + secondsLeft + "s  /  PLAY MUSIC AT SHOW VOLUME";
  }
  if (inputHot > 0.68) return "TOO LOUD  /  PRESS - OR LOWER THE MAC INPUT LEVEL";
  if (liveMicGuard && rawMicSignal > 0.48 && drive < rawMicSignal * 0.55) {
    return "BACKGROUND OR VOICE IS BEING REDUCED";
  }
  if (drive > 0.82) return "STRONG MUSIC SIGNAL";
  if (drive > 0.16) return "GOOD";
  return "LOW  /  PRESS = ONLY IF MUSIC DOES NOT REACT";
}

// ---------------------------------------------------------------------------
// Audio analysis.
// ---------------------------------------------------------------------------

void initialiseAudio() {
  try {
    mic = new AudioIn(this, 0);
    fft = new FFT(this, FFT_BINS);
    amplitude = new Amplitude(this);
    mic.start();
    fft.input(mic);
    amplitude.input(mic);
    audioReady = true;
    println("Microphone started. Press C to calibrate. Press D for diagnostics.");
  }
  catch (Exception error) {
    audioReady = false;
    testSignal = true;
    println("Microphone unavailable. Synthetic test signal enabled.");
    println(error.getMessage());
  }
}

void updateAudioAnalysis() {
  for (int b = 0; b < BAND_COUNT; b++) previousBandValue[b] = bandValue[b];
  if (testSignal || !audioReady) {
    updateSyntheticSignal();
    return;
  }

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

  for (int b = 0; b < BAND_COUNT; b++) {
    bandRaw[b] = 0;
    bandBinCount[b] = 0;
  }

  float positiveFlux = 0;
  for (int i = 1; i < FFT_BINS; i++) {
    float hz = i * 22050.0 / (FFT_BINS - 1);
    int band = frequencyBandForHz(hz);
    if (band >= 0) {
      bandRaw[band] += spectrum[i];
      bandBinCount[band]++;
    }
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
    bandValue[b] = smoothAsymmetric(
      bandValue[b], normalized, 0.46, releaseRate[artistPreset]
    );
  }

  // LIVE MIC GUARD does not try to recognise speech. It compares the current
  // level with a slow room baseline, gives low frequencies more authority and
  // reduces mid/high-heavy events that are commonly caused by nearby speech.
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
    triggerOnset(constrain(max(onsetScore, drive), 0.22, 1.0), dominantBand());
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
    bandValue[b] = smoothAsymmetric(
      bandValue[b], constrain(target, 0, 1), 0.44, releaseRate[artistPreset]
    );
    bandRaw[b] = bandValue[b] * 0.01;
  }
  lowFrequencySupport = constrain(bandValue[0] * 0.88 + bandValue[1] * 0.12, 0, 1);
  flux = smoothAsymmetric(flux, beatEnvelope, 0.68, 0.13);
  onsetScore = beatEnvelope;
  if (beatIndex != previousSyntheticBeat) {
    triggerOnset(max(0.34, level), section == 3 ? 4 : section);
    previousSyntheticBeat = beatIndex;
  }
}

void triggerOnset(float strength, int dominant) {
  pulseTarget = max(pulseTarget,
    constrain(strength * (artistPreset == 0 ? 1.0 : 1.18), 0, 1));
  impactTarget = max(impactTarget, constrain(strength * (artistPreset == 0 ? 0.92 : 1.18), 0, 1));
  densityBurstTarget = max(densityBurstTarget,
    constrain(strength * (artistPreset == 0 ? 0.72 : 1.08), 0, 1));
  eventCounter++;
  triggerBeatFlash(strength, dominant);

  int variationGap = artistPreset == 0 ? 2 : 1;
  if (eventCounter % variationGap == 0) {
    int jump = 1 + int(fixedHash(eventCounter * 971 + dominant * 151) * 3.0);
    variationState = (variationState + jump) % 6;
  }

  // SCORE feedback remains rare and short. It can only open while SCORE is
  // visible, so changing scenes never reveals a stale duplicate.
  float scoreGate = fixedHash(eventCounter * 1877 + dominant * 431);
  if (currentScene == 2 && strength > 0.50 && scoreGate > 0.70 && scoreFeedback < 0.08) {
    scoreFeedbackMode = int(fixedHash(eventCounter * 1949 + dominant * 487) * 3.0) % 3;
    scoreFeedbackTarget = min(1.0, 0.42 + strength * 0.48);
  }
  if (currentScene == 6) triggerImageSequenceOnset(strength, dominant);

  float presetForce = artistPreset == 0 ? 0.68 : 1.0;
  for (int id = 0; id < MACRO_COUNT; id++) {
    float gate = fixedHash(eventCounter * 1031 + id * 181 + dominant * 43);
    float threshold = artistPreset == 0 ? 0.70 : 0.48;
    if (gate > threshold) {
      float sx = fixedHash(eventCounter * 1091 + id * 223);
      float sy = fixedHash(eventCounter * 1151 + id * 257);
      float ox = fixedHash(eventCounter * 1201 + id * 277) - 0.5;
      float oy = fixedHash(eventCounter * 1237 + id * 307) - 0.5;
      macroScaleXTarget[id] = lerp(0.58, 1.48, sx) *
        lerp(1.0, 0.88 + bandValue[id % BAND_COUNT] * 0.32, presetForce);
      macroScaleYTarget[id] = lerp(0.62, 1.42, sy);
      macroOffsetXTarget[id] = ox * 0.095 * strength * presetForce;
      macroOffsetYTarget[id] = oy * 0.085 * strength * presetForce;
    }
  }
  spawnPulseEvent(strength, dominant);

  // A strong onset can open one short local overexposure. The deterministic
  // gate keeps it rare and prevents the entire screen from flashing together.
  float rareGate = fixedHash(eventCounter * 887 + dominant * 131);
  if (strength > 0.68 && rareGate > 0.76 && rareBurst < 0.08) {
    rareRegion = (eventCounter * 5 + dominant * 2 + layoutB) % MACRO_COUNT;
    rareBurstTarget = min(1.0, 0.58 + strength * 0.42);
  }

  for (int i = 0; i < ASCII_SLICES; i++) {
    float gate = fixedHash(eventCounter * 211 + i * 47);
    if (gate > 0.38) {
      float direction = fixedHash(eventCounter * 307 + i * 83) > 0.5 ? 1 : -1;
      float magnitude = 0.62 + fixedHash(eventCounter * 419 + i * 101) * 0.58;
      asciiShiftTarget[i] = direction * magnitude * DESIGN_W * strength *
        (0.085 + bandValue[4] * 0.095);
    }
  }

  // Frequency decides the spatial gesture: bass gathers, mids and highs open.
  // A small deterministic offset prevents repeated notes from producing the
  // exact same distance while preserving the semantic relationship.
  if (eventCounter % (artistPreset == 0 ? 2 : 1) == 0) {
    float nuance = fixedHash(eventCounter * 1447 + dominant * 193);
    if (dominant <= 1) {
      gatherTarget = artistPreset == 0 ? lerp(0.78, 0.91, nuance) :
        lerp(0.84, 0.97, nuance);
    } else {
      gatherTarget = artistPreset == 0 ? lerp(0.16, 0.32, nuance) :
        lerp(0.06, 0.23, nuance);
    }
  }
  if (autoLayout && eventCounter % layoutIntervals[artistPreset] == 0 && strength > 0.32) {
    changeLayout(dominant);
  }
}

void writeHistory() {
  for (int b = 0; b < BAND_COUNT; b++) history[b][historyHead] = bandValue[b];
  historyHead = (historyHead + 1) % HISTORY;
}

float historySample(int band, float normalizedPosition) {
  int offset = int(constrain(normalizedPosition, 0, 1) * (HISTORY - 1));
  int index = (historyHead + offset) % HISTORY;
  return history[constrain(band, 0, BAND_COUNT - 1)][index];
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
  println("Analysis reset. Play music at show volume for " +
    (liveMicGuard ? "10" : "3") + " seconds.");
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

float effectiveOnsetThreshold() {
  return onsetThreshold * (artistPreset == 0 ? 1.0 : 0.82);
}

int dominantBand() {
  int winner = 0;
  for (int b = 1; b < BAND_COUNT; b++) {
    if (bandValue[b] > bandValue[winner]) winner = b;
  }
  return winner;
}

// ---------------------------------------------------------------------------
// Controls.
// ---------------------------------------------------------------------------

void keyPressed() {
  if (key >= '1' && key <= '7') changeScene(key - '1');
  if (key == 'q' || key == 'Q') artistPreset = 0;
  if (key == 'w' || key == 'W') artistPreset = 1;
  if (key == 'e' || key == 'E') artistPreset = 1;
  if (key == 'd' || key == 'D') debugEnabled = !debugEnabled;
  if (key == 's' || key == 'S') redScanEnabled = !redScanEnabled;
  if (key == 'v' || key == 'V') centerReserve = !centerReserve;
  if (key == 'n' || key == 'N') densityMode = (densityMode + 1) % 3;
  if (key == 'a' || key == 'A') autoLayout = !autoLayout;
  if (key == 'r' || key == 'R') changeLayout(dominantBand());
  if (key == 'c' || key == 'C') resetAnalysis();
  if (key == 'l' || key == 'L') {
    liveMicGuard = !liveMicGuard;
    resetAnalysis();
  }
  if (key == 'f' || key == 'F') {
    beatFlashEnabled = !beatFlashEnabled;
    if (!beatFlashEnabled) {
      globalBeatFlash = 0;
      globalBeatFlashTarget = 0;
      localBeatFlash = 0;
      localBeatFlashTarget = 0;
      beatCutFrames = 0;
    }
  }
  if (key == 'b' || key == 'B') triggerOnset(0.92, dominantBand());
  if (key == ' ') triggerOnset(0.88, dominantBand());

  if (key == 't' || key == 'T') {
    if (audioReady) {
      testSignal = !testSignal;
      previousSyntheticBeat = -1;
      if (!testSignal) resetAnalysis();
    } else {
      testSignal = true;
    }
  }
  if (key == '-' || key == '_') inputGain = max(0.15, inputGain / 1.12);
  if (key == '=' || key == '+') inputGain = min(8.0, inputGain * 1.12);
  if (key == ',' || key == '<') onsetThreshold = max(0.10, onsetThreshold - 0.025);
  if (key == '.' || key == '>') onsetThreshold = min(0.90, onsetThreshold + 0.025);
  if (keyCode == UP) masterIntensity = min(1.20, masterIntensity + 0.05);
  if (keyCode == DOWN) masterIntensity = max(0.25, masterIntensity - 0.05);
}

void mousePressed() {
  int selectedBand = constrain(int(map(mouseX, 0, width, 0, BAND_COUNT)), 0, BAND_COUNT - 1);
  triggerOnset(map(mouseY, height, 0, 0.34, 1.0), selectedBand);
}

// ---------------------------------------------------------------------------
// Motion objects. All target changes are eased. Nothing randomizes per frame.
// ---------------------------------------------------------------------------

class MotionPoint {
  int id;
  int cluster;
  float u;
  float v;
  float seed;
  float sizeSeed;
  float x;
  float y;
  float vx = 0;
  float vy = 0;

  MotionPoint(int pointId, float uu, float vv, float ss) {
    id = pointId;
    u = uu;
    v = vv;
    seed = ss;
    sizeSeed = fixedHash(pointId * 71 + 13);
    cluster = pointId % 4;
    x = u * DESIGN_W;
    y = v * DESIGN_H;
  }

  void update(float targetX, float targetY, float spring) {
    vx += (targetX - x) * spring;
    vy += (targetY - y) * spring;
    vx *= 0.79;
    vy *= 0.79;
    x += vx;
    y += vy;
  }
}

class PulseEvent {
  boolean active = false;
  int band = 0;
  int type = 0;
  float age = 0;
  float duration = 36;
  float strength = 0;
  float x = 0.5;
  float y = 0.5;
  float seed = 0;

  void start(float eventStrength, int frequencyBand, int eventId) {
    active = true;
    band = constrain(frequencyBand, 0, BAND_COUNT - 1);
    strength = constrain(eventStrength * (artistPreset == 0 ? 0.88 : 1.10), 0.18, 1.0);
    seed = fixedHash(eventId * 1543 + band * 271);
    type = (int(seed * 5.0) + band + variationState) % 5;
    if (band == 0 && type == 0) type = 2;
    age = 0;
    duration = lerp(68, 18, band / float(BAND_COUNT - 1)) *
      (artistPreset == 0 ? 1.12 : 0.86);
    x = 0.10 + fixedHash(eventId * 1601 + band * 313) * 0.80;
    y = 0.10 + fixedHash(eventId * 1663 + band * 347) * 0.80;
  }

  void update() {
    if (!active) return;
    age++;
    if (age >= duration) active = false;
  }

  float envelope() {
    float phase = constrain(age / max(1.0, duration), 0, 1);
    if (phase < 0.12) return smoothStepValue(0, 0.12, phase);
    return pow(1.0 - phase, band >= 3 ? 2.8 : 1.75);
  }

  void display(PGraphics pg) {
    float env = envelope() * strength;
    float px = x * DESIGN_W;
    float py = y * DESIGN_H;
    float frequencyScale = band / float(BAND_COUNT - 1);
    float phase = constrain(age / max(1.0, duration), 0, 1);
    float driftX = sin(phase * PI + seed * 9.0) * DESIGN_W * 0.018 *
      (0.3 + frequencyScale);
    float driftY = cos(phase * PI * 0.7 + seed * 13.0) * DESIGN_H * 0.014;
    px += driftX;
    py += driftY;

    if (type == 0) {
      // Full-frame exposure with one broad melting centre.
      pg.noStroke();
      pg.fill(250, 249, 246, env * (10 + frequencyScale * 30));
      pg.rect(0, 0, DESIGN_W, DESIGN_H);
      drawPulseCloud(pg, DESIGN_W * 0.5, DESIGN_H * 0.5,
        DESIGN_W * lerp(1.65, 1.16, frequencyScale),
        DESIGN_H * lerp(1.08, 0.72, frequencyScale), env,
        18 + frequencyScale * 15, seed);
    } else if (type == 1) {
      // A complete horizontal or vertical fog body spans the frame.
      boolean vertical = band >= 3;
      float cloudW = vertical ? DESIGN_W * (0.34 + env * 0.18) : DESIGN_W * 1.48;
      float cloudH = vertical ? DESIGN_H * 1.48 : DESIGN_H * (0.31 + env * 0.20);
      drawPulseCloud(pg, px, py, cloudW, cloudH, env,
        17 + frequencyScale * 13, seed + 0.17);
      drawPulseCloud(pg,
        px + (vertical ? DESIGN_W * 0.055 : 0),
        py + (vertical ? 0 : DESIGN_H * 0.065),
        cloudW * 0.76, cloudH * 0.72, env * 0.48,
        12 + frequencyScale * 9, seed + 0.37);
    } else if (type == 2) {
      // One large local field occupies at least half the screen.
      float cloudW = DESIGN_W * lerp(1.18, 0.72, frequencyScale) *
        (0.80 + env * 0.28);
      float cloudH = DESIGN_H * lerp(1.06, 0.64, frequencyScale) *
        (0.78 + env * 0.30);
      drawPulseCloud(pg, px, py, cloudW, cloudH, env,
        19 + (1.0 - frequencyScale) * 11, seed + 0.21);
    } else if (type == 3) {
      // Two broad fields overlap into one suspended body. Neither becomes a
      // separate small halo.
      float spanW = DESIGN_W * lerp(1.10, 0.76, frequencyScale);
      float spanH = DESIGN_H * lerp(0.94, 0.62, frequencyScale);
      drawPulseCloud(pg, px - spanW * 0.12, py - spanH * 0.05,
        spanW, spanH, env, 17 + frequencyScale * 10, seed + 0.19);
      drawPulseCloud(pg, px + spanW * 0.16, py + spanH * 0.10,
        spanW * 0.88, spanH * 0.82, env * 0.58,
        13 + frequencyScale * 8, seed + 0.43);
    } else {
      // A high-frequency flash remains one large luminous sheet.
      float sheetY = py * 0.42 + DESIGN_H * 0.29;
      drawPulseCloud(pg, DESIGN_W * 0.5, sheetY,
        DESIGN_W * 1.56, DESIGN_H * (0.38 + frequencyScale * 0.18),
        env, 21 + frequencyScale * 14, seed + 0.29);
      pg.noStroke();
      pg.fill(250, 249, 246, env * (8 + frequencyScale * 20));
      pg.rect(0, 0, DESIGN_W, DESIGN_H);
    }
  }
}

void drawPulseCloud(PGraphics pg, float cx, float cy, float cloudW, float cloudH,
    float envelope, float coreBrightness, float cloudSeed) {
  pg.noStroke();
  int layers = 46;
  for (int layer = layers; layer >= 0; layer--) {
    float t = layer / float(layers);
    float scale = 0.10 + t * 1.86;
    float inward = 1.0 - t;
    float alpha = envelope * (0.22 + pow(inward, 2.75) * coreBrightness * 0.46);
    float jitter = (fixedHash(int(cloudSeed * 100000) + layer * 193) - 0.5) *
      min(cloudW, cloudH) * 0.010 * t;
    pg.fill(250, 249, 246, alpha);
    pg.ellipse(cx + jitter, cy - jitter * 0.45, cloudW * scale, cloudH * scale);
  }
}

class Plate {
  int id;
  float[] tx = new float[4];
  float[] ty = new float[4];
  float[] tw = new float[4];
  float[] th = new float[4];
  float x;
  float y;
  float w;
  float h;

  Plate(int plateId) {
    id = plateId;
    float a = fixedHash(id * 31 + 3);
    float b = fixedHash(id * 47 + 7);
    float c = fixedHash(id * 59 + 11);
    int lane = (id * 7) % PLATE_COUNT;
    int cell = (id * 5) % PLATE_COUNT;

    tx[0] = 0.025 + a * 0.14;
    ty[0] = 0.045 + lane / float(PLATE_COUNT) * 0.88;
    tw[0] = 0.40 + b * 0.56;
    th[0] = 0.018 + c * 0.115;

    tx[1] = 0.035 + lane / float(PLATE_COUNT) * 0.90;
    ty[1] = 0.035 + b * 0.15;
    tw[1] = 0.018 + c * 0.10;
    th[1] = 0.43 + a * 0.53;

    int col = cell % 4;
    int row = (cell / 4) % 4;
    tx[2] = 0.04 + col * 0.235 + a * 0.035;
    ty[2] = 0.055 + row * 0.225 + b * 0.035;
    tw[2] = 0.16 + c * 0.22;
    th[2] = 0.12 + a * 0.24;

    tx[3] = 0.06 + a * 0.72;
    ty[3] = 0.06 + b * 0.72;
    tw[3] = 0.18 + c * 0.48;
    th[3] = 0.05 + a * 0.36;

    x = tx[0];
    y = ty[0];
    w = tw[0];
    h = th[0];
  }

  void update(float targetX, float targetY, float targetW, float targetH, float rate) {
    x = lerp(x, targetX, rate);
    y = lerp(y, targetY, rate);
    w = lerp(w, targetW, rate);
    h = lerp(h, targetH, rate);
  }
}

float fixedHash(int n) {
  float value = sin(n * 12.9898 + 4.137) * 43758.5453;
  return value - floor(value);
}
