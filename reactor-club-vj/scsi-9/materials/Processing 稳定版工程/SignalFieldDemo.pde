import processing.sound.*;
import codeanticode.syphon.*;

/*
  SIGNAL FIELD V8
  Processing 4 + Sound + Syphon

  One sketch, five continuous monochrome visual systems.
  The only optional colour is the red scan line.
  The Syphon output is always 2112 x 1152.
*/

final int PREVIEW_W = 1056;
final int PREVIEW_H = 576;
final int OUTPUT_W = 2112;
final int OUTPUT_H = 1152;
final int FFT_BINS = 512;
final int BAND_COUNT = 5;
final int HISTORY = 512;
final int POINT_COUNT = 720;
final int PLATE_COUNT = 18;
final int ASCII_COLS = 76;
final int ASCII_ROWS = 40;
final int ASCII_SLICES = 12;

AudioIn mic;
FFT fft;
Amplitude amplitude;
SyphonServer syphon;
PGraphics output;
PShader fluidShader;
PFont mono;
PImage transitionFrame;

MotionPoint[] points = new MotionPoint[POINT_COUNT];
Plate[] plates = new Plate[PLATE_COUNT];

float[] spectrum = new float[FFT_BINS];
float[] previousSpectrum = new float[FFT_BINS];
float[] bandRaw = new float[BAND_COUNT];
float[] bandFloor = new float[BAND_COUNT];
float[] bandPeak = new float[BAND_COUNT];
float[] bandValue = new float[BAND_COUNT];
float[] previousBandValue = new float[BAND_COUNT];
float[][] history = new float[BAND_COUNT][HISTORY];
int[] bandBinCount = new int[BAND_COUNT];

String[] sceneNames = {"FIELD", "PLATES", "SCORE", "MEMBRANE", "ASCII VEIL"};
String[] presetNames = {"SCSI-9", "FEIYI", "NAXIN"};
String[] densityNames = {"AUTO", "SPARSE", "DENSE"};
float[] testLevels = {0.025, 0.18, 0.50, 0.92};
float[] releaseRate = {0.045, 0.062, 0.078};
float[] presetSpeedTarget = {0.72, 1.00, 1.28};
float[] presetDensityTarget = {-0.10, 0.00, 0.10};
float[] presetSpringTarget = {0.042, 0.058, 0.074};
int[] onsetGapMs = {170, 125, 100};
int[] layoutIntervals = {4, 3, 2};

int currentScene = 0;
int artistPreset = 0;
int densityMode = 0;
int historyHead = 0;
int eventCounter = 0;
int previousSyntheticBeat = -1;
int calibrationFrames = 0;
int lastOnsetMs = -1000;
int layoutA = 0;
int layoutB = 1;
String ASCII_GLYPHS = ".:+*#01/\\<>(){}ABCDEF";

boolean audioReady = false;
boolean syphonReady = false;
boolean syphonHasClient = false;
boolean shaderReady = false;
boolean testSignal = false;
boolean debugEnabled = false;
boolean redScanEnabled = false;
boolean centerReserve = false;
boolean autoLayout = true;

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

void settings() {
  size(PREVIEW_W, PREVIEW_H, P3D);
  smooth(4);
}

void setup() {
  frameRate(60);
  surface.setTitle("SIGNAL FIELD V8 — MONO / SYPHON 2112x1152");

  output = createGraphics(OUTPUT_W, OUTPUT_H, P3D);
  output.smooth(4);
  mono = createFont("Monospaced", 18, true);

  randomSeed(91723);
  for (int i = 0; i < POINT_COUNT; i++) {
    points[i] = new MotionPoint(i, random(1), random(1), random(1));
  }
  for (int i = 0; i < PLATE_COUNT; i++) plates[i] = new Plate(i);

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
    syphon = new SyphonServer(this, "SIGNAL_FIELD_2112x1152");
    syphonReady = true;
    println("Syphon server started: SIGNAL_FIELD_2112x1152");
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

  if (currentScene == 0) drawField(output);
  if (currentScene == 1) drawPlates(output);
  if (currentScene == 2) drawScore(output);
  if (currentScene == 3) drawMembrane(output);
  if (currentScene == 4) drawAsciiVeil(output);

  if (transitionFrame != null && sceneFade < 1) {
    output.tint(255, 255 * pow(1.0 - sceneFade, 1.55));
    output.image(transitionFrame, 0, 0, output.width, output.height);
    output.noTint();
  }

  if (redScanEnabled) drawRedScan(output);
  if (centerReserve) drawCenterReserve(output);
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
  float targetDensity = pow(normalized, 1.18) + presetDensity;
  if (densityMode == 1) targetDensity = 0.075 + drive * 0.055;
  if (densityMode == 2) targetDensity = 0.78 + drive * 0.16;
  densitySmooth = lerp(densitySmooth, constrain(targetDensity, 0.025, 0.98), 0.045);

  gatherSmooth = lerp(gatherSmooth, gatherTarget, 0.025 + bandValue[1] * 0.018);
  pulseSmooth = lerp(pulseSmooth, pulseTarget,
    pulseTarget > pulseSmooth ? 0.22 : 0.075);
  pulseTarget *= artistPreset == 0 ? 0.925 : artistPreset == 1 ? 0.902 : 0.884;

  layoutMorph = min(1.0, layoutMorph + 0.0105 * presetSpeed);
  sceneFade = min(1.0, sceneFade + 0.022);
  float orientationTarget = layoutB % 2 == 0 ? 0 : 1;
  scoreOrientation = lerp(scoreOrientation, orientationTarget, 0.018 * presetSpeed);

  motionTime += (0.0025 + bandValue[2] * 0.0035) * presetSpeed;
  scanPhase = (scanPhase + 0.0017 + bandValue[4] * 0.0035) % 1.0;
  asciiScroll += (0.018 + bandValue[4] * 0.060 + drive * 0.012) * presetSpeed;
  for (int i = 0; i < ASCII_SLICES; i++) {
    asciiShift[i] = lerp(asciiShift[i], asciiShiftTarget[i], 0.095);
    asciiShiftTarget[i] *= 0.905;
  }
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
  int next = constrain(nextScene, 0, 4);
  if (next == currentScene) return;
  if (output != null) transitionFrame = output.get();
  currentScene = next;
  sceneFade = 0;
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

    p.update(tx * OUTPUT_W, ty * OUTPUT_H, presetSpring);
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

  // Moving group envelopes give the particle field a readable large-scale
  // composition. They are calculated from the same active points, not added UI.
  float[] minX = {pg.width, pg.width, pg.width, pg.width};
  float[] minY = {pg.height, pg.height, pg.height, pg.height};
  float[] maxX = {0, 0, 0, 0};
  float[] maxY = {0, 0, 0, 0};
  int[] groupCount = {0, 0, 0, 0};
  for (int i = 0; i < active; i++) {
    MotionPoint p = points[i];
    int group = p.cluster;
    minX[group] = min(minX[group], p.x);
    minY[group] = min(minY[group], p.y);
    maxX[group] = max(maxX[group], p.x);
    maxY[group] = max(maxY[group], p.y);
    groupCount[group]++;
  }
  pg.noFill();
  pg.rectMode(CORNER);
  for (int group = 0; group < 4; group++) {
    if (groupCount[group] < 2) continue;
    float margin = lerp(46, 15, densitySmooth) + bandValue[group] * 28;
    float gx = minX[group] - margin;
    float gy = minY[group] - margin;
    float gw = max(12, maxX[group] - minX[group] + margin * 2);
    float gh = max(12, maxY[group] - minY[group] + margin * 2);
    float gcx = gx + gw * 0.5;
    float gcy = gy + gh * 0.5;
    gw = min(gw, pg.width * 0.46);
    gh = min(gh, pg.height * 0.58);
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

  // A few restrained connections make the clusters readable from a distance.
  pg.noFill();
  inkStroke(pg, 24 + gatherSmooth * 42);
  pg.strokeWeight(1.0 + bandValue[2] * 1.2);
  int links = min(active - 1, int(lerp(10, 110, densitySmooth)));
  for (int i = 0; i < links; i += 2) {
    MotionPoint a = points[i];
    MotionPoint b = points[i + 1];
    if (a.cluster != b.cluster) continue;
    float distance = dist(a.x, a.y, b.x, b.y);
    if (distance < pg.width * 0.18) pg.line(a.x, a.y, b.x, b.y);
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
    float bandY = pg.height * (0.34 + sin(motionTime * 0.37) * 0.13);
    pg.rect(0, bandY, pg.width, pg.height * (0.10 + bandValue[0] * 0.11));
  } else {
    float bandX = pg.width * (0.38 + sin(motionTime * 0.31) * 0.15);
    pg.rect(bandX, 0, pg.width * (0.075 + bandValue[0] * 0.09), pg.height);
  }

  for (int i = 0; i < active; i++) {
    Plate p = plates[i];
    float x = p.x * pg.width;
    float y = p.y * pg.height;
    float w = max(2, p.w * pg.width);
    float h = max(2, p.h * pg.height);
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
      if (i == 0 && w > pg.width * 0.18 && h > pg.height * 0.08) {
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
  float sweep = (0.08 + (motionTime * 0.11) % 0.84) * pg.width;
  inkStroke(pg, 34 + bandValue[4] * 88);
  pg.strokeWeight(1.0 + bandValue[4] * 1.8);
  pg.line(sweep, pg.height * 0.035, sweep, pg.height * 0.965);
}

// ---------------------------------------------------------------------------
// 3. SCORE — actual band histories as large, slowly turning wave structures.
// ---------------------------------------------------------------------------

void drawScore(PGraphics pg) {
  int lanes = constrain(2 + int(densitySmooth * 3.4), 2, 5);
  float marginX = pg.width * 0.035;
  float marginY = pg.height * 0.055;
  float availableW = pg.width - marginX * 2;
  float availableH = pg.height - marginY * 2;
  int steps = artistPreset == 0 ? 144 : artistPreset == 1 ? 112 : 176;

  // One large spectral body controls the frame. Its scale is intentionally much
  // larger than a conventional audio waveform.
  int dominant = dominantBand();
  float lanePosition = lerp(0.34, 0.50, gatherSmooth);
  float ribbonWidth = lerp(112, 38, densitySmooth) *
    (1.0 + bandValue[dominant] * 0.90 + pulseSmooth * 0.38);
  inkFill(pg, 72 + bandValue[dominant] * 104);
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
    inkStroke(pg, 26 + bandValue[dominant] * 72 + pulseSmooth * 28);
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
    inkStroke(pg, lerp(224, 118, densitySmooth) *
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
    inkStroke(pg, alpha * (1.0 - scoreOrientation));
    float x = marginX + u * availableW;
    pg.line(x, marginY, x, pg.height - marginY);
    inkStroke(pg, alpha * scoreOrientation);
    float y = marginY + u * availableH;
    pg.line(marginX, y, pg.width - marginX, y);
  }
}

// ---------------------------------------------------------------------------
// 4. MEMBRANE — smooth monochrome fluid field, with CPU fallback.
// ---------------------------------------------------------------------------

void drawMembrane(PGraphics pg) {
  if (shaderReady) {
    try {
      fluidShader.set("resolution", float(pg.width), float(pg.height));
      fluidShader.set("time", motionTime * 2.10);
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
      pg.noStroke();
      // Explicit fill is essential because scenes 1–3 can legitimately finish
      // with noFill(). Without this, the shader rectangle is never submitted.
      pg.fill(255);
      pg.shader(fluidShader);
      pg.rect(0, 0, pg.width, pg.height);
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
  int clusterCount = 5 + int(densitySmooth * 2.2);
  noiseDetail(5, 0.52);

  for (int cluster = 0; cluster < clusterCount; cluster++) {
    float baseX = cluster == 0 ? 0.12 : cluster == 1 ? 0.39 :
      cluster == 2 ? 0.76 : cluster == 3 ? 0.20 :
      cluster == 4 ? 0.52 : cluster == 5 ? 0.84 : 0.59;
    float baseY = cluster == 0 ? 0.23 : cluster == 1 ? 0.31 :
      cluster == 2 ? 0.20 : cluster == 3 ? 0.70 :
      cluster == 4 ? 0.61 : cluster == 5 ? 0.68 : 0.88;
    float spread = 0.78 + gatherSmooth * 0.20;
    float centerX = pg.width * (0.5 + (baseX - 0.5) * spread);
    float centerY = pg.height * (0.5 + (baseY - 0.5) * spread);
    centerX += sin(motionTime * 0.61 + cluster * 1.9) * pg.width * 0.025;
    centerY += cos(motionTime * 0.47 + cluster * 1.4) * pg.height * 0.025;

    int contours = 3 + int(densitySmooth * 5 + bandValue[4] * 2.5);
    for (int c = contours - 1; c >= 0; c--) {
      float scale = (c + 1) / float(contours);
      float radiusX = pg.width * scale * (0.040 + bandValue[0] * 0.055 + cluster * 0.003);
      float radiusY = pg.height * scale * (0.064 + bandValue[1] * 0.060);
      if (c % 3 == 0 && densitySmooth > 0.28) {
        pg.noStroke();
        inkFill(pg, 10 + drive * 24);
      } else {
        pg.noFill();
        inkStroke(pg, 62 + densitySmooth * 104);
        pg.strokeWeight(1.1 + bandValue[4] * 2.4);
      }
      pg.beginShape();
      int segments = 80;
      for (int i = 0; i <= segments; i++) {
        float angle = TWO_PI * i / segments;
        float n = noise(cluster * 2.1 + c * 0.18 + cos(angle) * 0.70 + motionTime,
          sin(angle) * 0.70 - motionTime * 0.57);
        float warp = 0.66 + n * (0.48 + bandValue[2] * 0.26);
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
  float cellW = pg.width / float(ASCII_COLS);
  float cellH = pg.height / float(ASCII_ROWS);
  int baseRow = floor(asciiScroll);
  float rowFraction = asciiScroll - baseRow;
  float threshold = 0.425 - densitySmooth * 0.105 - bandValue[0] * 0.065;
  float shapeMorph = morphEase();

  pg.textFont(mono);
  pg.textSize(min(cellW, cellH) *
    (0.91 + bandValue[0] * 0.13 + pulseSmooth * 0.08));
  pg.textAlign(CENTER, CENTER);
  pg.noStroke();

  for (int row = -1; row <= ASCII_ROWS; row++) {
    int virtualRow = row + baseRow;
    float y = (row - rowFraction + 0.5) * cellH;
    float v = ((virtualRow % ASCII_ROWS) + ASCII_ROWS + 0.5) / float(ASCII_ROWS);
    v = v % 1.0;
    int slice = constrain(int(map(y, 0, pg.height, 0, ASCII_SLICES)), 0, ASCII_SLICES - 1);
    float rowShift = asciiShift[slice];

    for (int col = 0; col < ASCII_COLS; col++) {
      float u = (col + 0.5) / ASCII_COLS;
      float shapeA = asciiShape(layoutA, u, v);
      float shapeB = asciiShape(layoutB, u, v);
      float shape = lerp(shapeA, shapeB, shapeMorph);
      float grain = noise(u * 3.4 + motionTime * 0.22,
        v * 3.7 - motionTime * 0.17);
      float occupancy = shape * 0.92 + grain * 0.27;

      float cellSeed = fixedHash(col * 197 + virtualRow * 89 + layoutB * 43);
      float dissolve = threshold + (cellSeed - 0.5) * (0.16 + pulseSmooth * 0.08);
      if (occupancy < dissolve) continue;

      float crackCenter = 0.50 + sin(v * 7.4 + motionTime * 0.78) *
        (0.035 + bandValue[2] * 0.075);
      float crackWidth = 0.008 + pulseSmooth * 0.026 + bandValue[4] * 0.006;
      float crackDistance = abs(u - crackCenter);
      if (crackDistance < crackWidth) continue;

      float fission = 0;
      if (pulseSmooth > 0.08) {
        fission = (u < crackCenter ? -1 : 1) * pulseSmooth *
          (24 + bandValue[1] * 96);
      }
      float flowShift = sin(v * 9.0 + motionTime * 1.15) *
        (6 + bandValue[2] * 24);
      float x = (col + 0.5) * cellW + rowShift + fission + flowShift;
      if (x < -cellW || x > pg.width + cellW) continue;

      int eventStep = eventCounter / 2;
      int glyphIndex = int(fixedHash(col * 101 + virtualRow * 61 +
        eventStep * 127) * ASCII_GLYPHS.length());
      glyphIndex = constrain(glyphIndex, 0, ASCII_GLYPHS.length() - 1);
      float alpha = constrain(map(occupancy - dissolve, 0, 0.34, 92, 248), 78, 248);
      inkFill(pg, alpha);
      float yJitter = sin(col * 1.73 + virtualRow * 0.41 + motionTime * 1.8) *
        bandValue[4] * cellH * 0.20;
      pg.text(ASCII_GLYPHS.charAt(glyphIndex), x, y + yJitter);
    }
  }

  // Event-driven rows move as complete units. The shifts ease in and out, so
  // the glitch remains physical rather than looking like random frame noise.
  for (int i = 0; i < ASCII_SLICES; i++) {
    float amount = abs(asciiShift[i]);
    if (amount < 7) continue;
    float y = (i + 0.5) * pg.height / ASCII_SLICES;
    pg.noStroke();
    inkFill(pg, 18 + min(58, amount * 0.32));
    float w = min(pg.width * 0.34, amount * 2.25);
    float x = asciiShift[i] > 0 ? pg.width - w : 0;
    pg.rect(x, y - 2, w, 4 + bandValue[4] * 5);

    float blockSeed = fixedHash(i * 163 + eventCounter * 281);
    float blockW = pg.width * (0.035 + blockSeed * 0.135);
    float blockX = (blockSeed * 0.78 + 0.11) * pg.width + asciiShift[i] * 0.42;
    inkFill(pg, 52 + min(118, amount * 0.62));
    pg.rect(blockX, y - cellH * 0.31, blockW,
      max(4, cellH * (0.15 + bandValue[4] * 0.28)));

    float secondSeed = fixedHash(i * 229 + eventCounter * 367);
    if (pulseSmooth > 0.22 && secondSeed > 0.36) {
      float secondW = pg.width * (0.018 + secondSeed * 0.075);
      float secondX = pg.width * (0.08 + secondSeed * 0.78) - asciiShift[i] * 0.28;
      inkFill(pg, 35 + pulseSmooth * 95);
      pg.rect(secondX, y + cellH * 0.20, secondW,
        3 + pulseSmooth * cellH * 0.28);
    }
  }
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
// Shared drawing and diagnostics.
// ---------------------------------------------------------------------------

void drawRedScan(PGraphics pg) {
  float high = bandValue[4];
  float stepCount = max(42.0, 210 - pulseSmooth * 118 - high * 42);
  float steppedPhase = floor(scanPhase * stepCount) / stepCount;
  float frameGate = fixedHash(frameCount * 193 + eventCounter * 379);
  float jump = 0;
  if (pulseSmooth > 0.10 && frameGate > 0.46) {
    jump = (fixedHash(frameCount * 271 + eventCounter * 149) - 0.5) *
      pg.height * (0.025 + high * 0.065 + pulseSmooth * 0.035);
  }
  float y = (steppedPhase * pg.height + jump + pg.height) % pg.height;
  float blink = pulseSmooth > 0.08 ?
    (frameGate > 0.34 ? 1.0 : 0.12) : 1.0;
  float flash = pow(constrain(pulseSmooth, 0, 1), 1.20) *
    (9 + drive * 22 + high * 15) * blink;

  pg.blendMode(ADD);
  pg.noStroke();
  if (flash > 1) {
    pg.fill(250, 249, 246, flash);
    pg.rect(0, 0, pg.width, pg.height);
  }
  float halo = 7 + bandValue[2] * 18 + pulseSmooth * 14;
  pg.fill(255, 20, 10, (18 + drive * 30 + high * 36) * blink);
  pg.rect(0, y - halo * 0.5, pg.width, halo);
  pg.fill(255, 62, 38, (132 + drive * 72 + high * 48) * blink);
  pg.rect(0, y - 1, pg.width,
    1.6 + high * 3.8 + pulseSmooth * 2.8);

  float echoY = ((scanPhase + 0.12 + bandValue[1] * 0.08) % 1.0) * pg.height;
  pg.fill(255, 32, 18, (16 + high * 38) * blink);
  pg.rect(0, echoY, pg.width, 1 + high * 1.8);

  if (pulseSmooth > 0.10) {
    for (int i = 0; i < 3; i++) {
      float seed = fixedHash(eventCounter * 431 + i * 97);
      float segmentX = pg.width * seed;
      float segmentW = pg.width * (0.035 + fixedHash(eventCounter * 613 + i * 157) * 0.16);
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
    pg.rect(pg.width * 0.5, pg.height * 0.5,
      pg.width * (0.29 + t * 0.055), pg.height * (0.20 + t * 0.075));
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
  float x = 14;
  float y = height - 112;
  float w = 560;
  float h = 98;
  noStroke();
  fill(0, 225);
  rect(x, y, w, h);
  stroke(255, 48);
  noFill();
  rect(x, y, w, h);

  fill(238);
  textFont(mono);
  textSize(11);
  textAlign(LEFT, TOP);
  String source = testSignal ? "TEST" : audioReady ? "MIC" : "NO MIC";
  String syphonState = !syphonReady ? "SYPHON OFF" :
    syphonHasClient ? "SYPHON CONNECTED" : "SYPHON SOURCE LIVE";
  text(sceneNames[currentScene] + "  /  " + presetNames[artistPreset] + "  /  " + source,
    x + 10, y + 9);
  text(syphonState + "  /  " + densityNames[densityMode] +
    "  /  RED SCAN " + (redScanEnabled ? "ON" : "OFF"), x + 10, y + 28);
  text("raw " + nf(rawAmplitude, 1, 5) + "  drive " + nf(drive, 1, 2) +
    "  density " + nf(densitySmooth, 1, 2) + "  gather " + nf(gatherSmooth, 1, 2),
    x + 10, y + 47);
  text("gain " + nf(inputGain, 1, 2) + "  onset " + nf(onsetScore, 1, 2) +
    " / " + nf(onsetThreshold, 1, 2) + "  layout " + (layoutB + 1), x + 10, y + 66);
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
      calibrationFrames > 0 ? 0.0015 : 0.00012);
  }
  amplitudePeak = max(rawAmplitude, amplitudePeak * 0.99925);
  amplitudePeak = max(amplitudePeak, amplitudeFloor + 0.002);
  float ampNormalized = (rawAmplitude - amplitudeFloor * 1.08) /
    max(0.00001, amplitudePeak - amplitudeFloor);
  ampNormalized = constrain(pow(constrain(ampNormalized, 0, 1), 0.55) * inputGain, 0, 1);
  drive = smoothAsymmetric(drive, ampNormalized, 0.48, 0.070);

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
        calibrationFrames > 0 ? 0.0015 : 0.00010);
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

  positiveFlux /= FFT_BINS;
  fluxPeak = max(positiveFlux, fluxPeak * 0.9975);
  float fluxNormalized = constrain(positiveFlux / max(0.000001, fluxPeak), 0, 1);
  flux = smoothAsymmetric(flux, fluxNormalized, 0.60, 0.15);
  float bassRise = max(0, bandValue[0] - previousBandValue[0]);
  float midRise = max(0, bandValue[2] - previousBandValue[2]);
  onsetScore = max(flux * 0.70, max(bassRise * 2.15, midRise * 1.65));

  int now = millis();
  if (onsetScore > onsetThreshold && drive > 0.03 &&
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
  drive = smoothAsymmetric(drive,
    constrain(level * 0.86 + beatEnvelope * 0.22, 0, 1), 0.42, 0.065);
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
  flux = smoothAsymmetric(flux, beatEnvelope, 0.68, 0.13);
  onsetScore = beatEnvelope;
  if (beatIndex != previousSyntheticBeat) {
    triggerOnset(max(0.34, level), section == 3 ? 4 : section);
    previousSyntheticBeat = beatIndex;
  }
}

void triggerOnset(float strength, int dominant) {
  pulseTarget = max(pulseTarget, constrain(strength, 0, 1));
  eventCounter++;

  for (int i = 0; i < ASCII_SLICES; i++) {
    float gate = fixedHash(eventCounter * 211 + i * 47);
    if (gate > 0.38) {
      float direction = fixedHash(eventCounter * 307 + i * 83) > 0.5 ? 1 : -1;
      float magnitude = 0.62 + fixedHash(eventCounter * 419 + i * 101) * 0.58;
      asciiShiftTarget[i] = direction * magnitude * OUTPUT_W * strength *
        (0.085 + bandValue[4] * 0.095);
    }
  }

  // Alternating organization makes gather and dispersion plainly visible.
  if (eventCounter % 2 == 0) {
    gatherTarget = gatherTarget > 0.5 ? 0.18 : 0.86;
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
  for (int b = 0; b < BAND_COUNT; b++) {
    bandFloor[b] = bandRaw[b] > 0.000001 ? bandRaw[b] * 0.18 : 0.000001;
    bandPeak[b] = max(0.0025, bandRaw[b] * 1.80);
    bandValue[b] = 0;
    previousBandValue[b] = 0;
  }
  calibrationFrames = 180;
  println("Analysis reset. Listening for 3 seconds.");
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
  if (key >= '1' && key <= '5') changeScene(key - '1');
  if (key == 'q' || key == 'Q') artistPreset = 0;
  if (key == 'w' || key == 'W') artistPreset = 1;
  if (key == 'e' || key == 'E') artistPreset = 2;
  if (key == 'd' || key == 'D') debugEnabled = !debugEnabled;
  if (key == 's' || key == 'S') redScanEnabled = !redScanEnabled;
  if (key == 'v' || key == 'V') centerReserve = !centerReserve;
  if (key == 'n' || key == 'N') densityMode = (densityMode + 1) % 3;
  if (key == 'a' || key == 'A') autoLayout = !autoLayout;
  if (key == 'r' || key == 'R') changeLayout(dominantBand());
  if (key == 'c' || key == 'C') resetAnalysis();
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
  if (key == '[') inputGain = max(0.25, inputGain / 1.15);
  if (key == ']') inputGain = min(8.0, inputGain * 1.15);
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
    x = u * OUTPUT_W;
    y = v * OUTPUT_H;
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
