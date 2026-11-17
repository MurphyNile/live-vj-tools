import processing.sound.*;
import codeanticode.syphon.*;

/* BILLIONHAPPY / PINK SYSTEM FINAL — REACTOR EDITION
   Processing 4 · Sound · Syphon · 1056×576 · target 60 FPS
   Original skull PNG remains intact. Videos are composited later in Arena.
*/

final int OUT_W = 1056, OUT_H = 576, FFT_BINS = 512, BAND_COUNT = 5;
final int PINK = 0xFFFF65CA;
final int SCENE_COUNT = 4;
final String SYPHON_NAME = "BILLIONHAPPY_PINK_SYSTEM_FINAL";

PGraphics sceneLayer, sceneUnder, sceneOver, compositeLayer, glowSmall, output, invertBuffer;
PImage logoOriginal, logoSmall, logoMedium, logoLarge, freezeFrame;
SyphonServer syphon;
boolean syphonReady = false, syphonHasClient = false;
boolean debugEnabled = false, helpEnabled = false;

int currentScene = 0, previousScene = 0;
String[] sceneNames = {"SOLO / HERO", "WALL / MATCH SWEEP", "CLONE / MULTIPLY", "FALL / SPACE DROP"};
int densityIndex = 1;
int beatCount = 0;
boolean autoArrange = true;

int arrangement = 0, previousArrangement = 0;
float arrangementMix = 1;
int cloneStage = 0, previousCloneStage = 0;
float cloneMix = 1;
float sceneMix = 1;

boolean autoFlash = true;
boolean autoGlow = true;
boolean autoInvert = true;
float flashIntensity = 0.72;
float glowIntensity = 0.92;
float invertIntensity = 0.70;
float masterIntensity = 1;
float motionClock = 0;
float kickPulse = 0, punch = 0, haloBurst = 0;
float autoFlashPulse = 0, manualFlash = 0;
float autoInvertPulse = 0, manualInvert = 0;
float strobeBrightness = 0, currentGlow = 0;
float glitchAmount = 0, mirrorAmount = 0, sliceAmount = 0;
int flashStyle = 0;
int lastAutoFlashMs = -2000, lastManualFlashMs = -2000;
int lastAutoInvertMs = -2000, lastManualInvertMs = -2000;

boolean holdFreeze = false, holdBlack = false;
boolean holdMirror = false, holdSlice = false, holdZoom = false, holdMultiply = false;

// FALL / SPACE DROP uses simple perspective projection for stronger depth.
final int FALL_COUNT = 32;
float[] fallBaseX = new float[FALL_COUNT];    // world x in [-1.15, 1.15]
float[] fallDepth = new float[FALL_COUNT];    // 0 far, 1 near
float[] fallVX = new float[FALL_COUNT];
float[] fallVDepth = new float[FALL_COUNT];
float[] fallAccel = new float[FALL_COUNT];
float[] fallAng = new float[FALL_COUNT];
float[] fallAngVel = new float[FALL_COUNT];
float[] fallBodySize = new float[FALL_COUNT];
float[] fallOpacity = new float[FALL_COUNT];

void settings() {
  size(OUT_W, OUT_H, P3D);
  smooth(4);
}

void setup() {
  frameRate(60);
  surface.setTitle("BILLIONHAPPY / PINK SYSTEM FINAL / REACTOR");
  sceneLayer = createGraphics(OUT_W, OUT_H, P2D);
  sceneUnder = createGraphics(OUT_W, OUT_H, P2D);
  sceneOver = createGraphics(OUT_W, OUT_H, P2D);
  compositeLayer = createGraphics(OUT_W, OUT_H, P2D);
  output = createGraphics(OUT_W, OUT_H, P2D);
  glowSmall = createGraphics(OUT_W/3, OUT_H/3, P2D);
  invertBuffer = createGraphics(OUT_W, OUT_H, P2D);
  freezeFrame = createImage(OUT_W, OUT_H, ARGB);
  sceneLayer.smooth(2);
  sceneUnder.smooth(2);
  sceneOver.smooth(2);
  compositeLayer.smooth(2);
  output.smooth(2);
  invertBuffer.smooth(2);
  loadArtwork();
  initFall();
  try {
    syphon = new SyphonServer(this, SYPHON_NAME);
    syphonReady = true;
    println("Syphon ready: " + SYPHON_NAME);
  } catch (Throwable error) {
    println("Syphon unavailable; local preview continues: " + error.getMessage());
  }
  setupAudio();
  resetAnalysis();
  if (testSignal) calibrationFrames = 0;
}

void draw() {
  updateAudioAnalysis();
  updateAnimation();

  if (!holdFreeze && !holdBlack) {
    renderSceneStack();
    compositeLayer.beginDraw();
    compositeLayer.background(0);
    renderSpatialFX(compositeLayer);
    compositeLayer.endDraw();
    if (autoGlow && glowIntensity > 0.01) updateGlowTexture();
  }

  output.beginDraw();
  output.background(0);
  output.imageMode(CORNER);
  output.noTint();
  output.noStroke();
  if (holdBlack) {
    // Blackout has priority.
  } else if (holdFreeze) {
    output.image(freezeFrame, 0, 0);
  } else {
    renderMasterComposite(output);
  }
  output.endDraw();

  if (syphonReady) {
    try {
      syphon.sendImage(output);
      if (frameCount % 60 == 0) syphonHasClient = syphon.hasClients();
    } catch (Throwable error) {
      syphonReady = false;
      println("Syphon stopped; preview continues: " + error.getMessage());
    }
  }

  background(0);
  image(output, 0, 0);
  if (debugEnabled) drawHUD();
  if (helpEnabled) drawHelp();
}

void renderSceneStack() {
  if (sceneMix >= 0.999 || previousScene == currentScene) {
    sceneLayer.beginDraw();
    sceneLayer.background(0);
    sceneLayer.noStroke();
    sceneLayer.imageMode(CENTER);
    renderSceneByIndex(sceneLayer, currentScene, 1.0);
    sceneLayer.endDraw();
    return;
  }

  sceneUnder.beginDraw();
  sceneUnder.background(0);
  sceneUnder.noStroke();
  sceneUnder.imageMode(CENTER);
  renderSceneByIndex(sceneUnder, previousScene, 1.0);
  sceneUnder.endDraw();

  sceneOver.beginDraw();
  sceneOver.background(0);
  sceneOver.noStroke();
  sceneOver.imageMode(CENTER);
  renderSceneByIndex(sceneOver, currentScene, 1.0);
  sceneOver.endDraw();

  float t = smoothEase(sceneMix);
  sceneLayer.beginDraw();
  sceneLayer.background(0);
  sceneLayer.imageMode(CORNER);
  sceneLayer.tint(255, (1.0 - t) * 255);
  sceneLayer.image(sceneUnder, 0, 0);
  sceneLayer.tint(255, t * 255);
  sceneLayer.image(sceneOver, 0, 0);
  sceneLayer.noTint();
  sceneLayer.endDraw();
}

void loadArtwork() {
  logoOriginal = loadImage("Billionhappy_Original.png");
  if (logoOriginal == null) {
    println("FATAL: data/Billionhappy_Original.png missing.");
    exit();
    return;
  }
  logoSmall = logoOriginal.get(); logoSmall.resize(320, 0);
  logoMedium = logoOriginal.get(); logoMedium.resize(850, 0);
  logoLarge = logoOriginal.get(); logoLarge.resize(1950, 0);
  println("Original logo loaded: " + logoOriginal.width + "x" + logoOriginal.height);
}

void initFall() {
  randomSeed(20261113);
  for (int i = 0; i < FALL_COUNT; i++) resetFallBody(i, true);
}

void resetFallBody(int i, boolean initial) {
  fallBodySize[i] = random(66, 162) * (densityIndex == 2 ? 0.92 : 1.0);
  fallBaseX[i] = random(-1.05, 1.05);
  fallDepth[i] = initial ? pow(random(1), 1.35) : random(0.00, 0.10);
  fallVX[i] = random(-0.28, 0.28);
  fallVDepth[i] = random(0.08, 0.30);
  fallAccel[i] = random(0.09, 0.26);
  fallAng[i] = random(-PI, PI);
  fallAngVel[i] = random(-0.028, 0.028);
  fallOpacity[i] = random(0.42, 0.98);
}

void updateAnimation() {
  float dt = min(0.05, 1.0 / max(20.0, frameRate));
  float frames = dt * 60.0;
  motionClock += dt * (0.86 + 0.14 * bandValue[1] + 0.08 * bandValue[3]);

  kickPulse *= pow(0.90, frames);
  punch *= pow(0.92, frames);
  haloBurst *= pow(0.93, frames);
  autoFlashPulse *= pow(0.52, frames);
  manualFlash *= pow(0.58, frames);
  autoInvertPulse *= pow(0.74, frames);
  manualInvert *= pow(0.78, frames);
  glitchAmount *= pow(0.82, frames);
  sliceAmount *= pow(0.84, frames);
  mirrorAmount *= pow(0.82, frames);
  arrangementMix = min(1.0, arrangementMix + dt * 1.92);
  cloneMix = min(1.0, cloneMix + dt * 2.75);
  sceneMix = min(1.0, sceneMix + dt * 1.86);

  float bass = bandValue[0];
  float lowMid = bandValue[1];
  float mid = bandValue[2];
  float treble = bandValue[3];

  float glowTarget = 0.30 + 0.44*bass + 0.24*mid + 0.10*treble + 0.50*haloBurst;
  glowTarget = constrain(glowTarget, 0.14, 1.26);
  float smooth = glowTarget > currentGlow ? 0.22 : 0.11;
  currentGlow = lerp(currentGlow, glowTarget, 1.0 - pow(1.0 - smooth, frames));

  float brightnessTarget = constrain(0.22*drive + 0.32*kickPulse + 0.20*haloBurst, 0, 0.56);
  strobeBrightness = lerp(strobeBrightness, brightnessTarget, 1.0 - pow(0.84, frames));

  float dropDrive = 0.92 + bass*0.82 + lowMid*0.24 + kickPulse*0.40;
  for (int i = 0; i < FALL_COUNT; i++) {
    float wind = sin(motionClock*0.35 + i*0.41 + arrangement*0.6) * 0.0035;
    if (arrangement == 1) wind += 0.0014;
    if (arrangement == 2) wind += map(fallBaseX[i], -1.0, 1.0, -0.0018, 0.0018);
    if (arrangement == 3) wind += sin(motionClock*1.12 + i*0.7) * 0.0022;

    fallVX[i] += wind;
    fallVDepth[i] += fallAccel[i] * dt * (0.58 + 0.44*bass);
    fallDepth[i] += fallVDepth[i] * dt * dropDrive;
    fallBaseX[i] += fallVX[i] * dt * dropDrive;
    fallAng[i] += fallAngVel[i] * frames * (1.00 + 0.38*mid);

    if (fallBaseX[i] < -1.14) {
      fallBaseX[i] = -1.14;
      fallVX[i] = abs(fallVX[i]) * (0.84 + 0.10*stableHash(i+10));
      fallAngVel[i] *= -1.05;
    }
    if (fallBaseX[i] > 1.14) {
      fallBaseX[i] = 1.14;
      fallVX[i] = -abs(fallVX[i]) * (0.84 + 0.10*stableHash(i+20));
      fallAngVel[i] *= -1.05;
    }
    if (fallDepth[i] > 1.10) resetFallBody(i, false);
  }
}

void sceneChange(int scene) {
  scene = constrain(scene, 0, SCENE_COUNT-1);
  if (scene == currentScene) return;
  previousScene = currentScene;
  currentScene = scene;
  sceneMix = 0;
  kickPulse *= 0.78;
  punch *= 0.72;
  println("SCENE " + (currentScene + 1) + " / " + sceneNames[currentScene]);
}

void nextArrangement() {
  previousArrangement = arrangement;
  arrangement = (arrangement + 1) % 4;
  arrangementMix = 0;
}

void advanceClone() {
  previousCloneStage = cloneStage;
  cloneStage = (cloneStage + 1) % 5;
  cloneMix = 0;
}

float softClamp(float x) { return constrain(x, 0, 1); }
float smoothEase(float t) { t = softClamp(t); return t*t*(3.0-2.0*t); }
float stableHash(int n) {
  float v = sin(n*127.1 + 78.233) * 43758.5453;
  return v - floor(v);
}

void onBeat(float strength, int dominant) {
  beatCount++;
  float impact = constrain(0.40 + strength*0.56, 0.0, 1.0);
  kickPulse = max(kickPulse, impact);
  haloBurst = max(haloBurst, 0.56 + strength*0.44);
  punch = max(punch, strength * (beatCount%4==0 ? 0.44 : 0.22));

  if (currentScene == 2 && beatCount % 8 == 0) advanceClone();
  if ((currentScene == 1 || currentScene == 3) && autoArrange && beatCount % 8 == 0) nextArrangement();

  int now = millis();
  if (autoFlash && strength >= 0.30 && drive >= 0.05 && now - lastAutoFlashMs >= 220) {
    autoFlashPulse = max(autoFlashPulse, constrain(0.60 + 0.40*strength, 0, 1.22));
    flashStyle = beatCount % 3;
    lastAutoFlashMs = now;
  }
  if (autoInvert && strength >= 0.46 && now - lastAutoInvertMs >= 420 && (beatCount % 4 == 0 || strength > 0.78)) {
    autoInvertPulse = max(autoInvertPulse, constrain(0.54 + 0.38*strength, 0, 1.08));
    lastAutoInvertMs = now;
  }
}

void keyPressed() {
  if (key >= '1' && key <= '4') sceneChange(key - '1');
  if (key == ' ' || key == 'b' || key == 'B') onBeat(1.0, dominantBand());
  if (key == 'q' || key == 'Q') artistPreset = 0;
  if (key == 'w' || key == 'W') artistPreset = 1;
  if (key == 'd' || key == 'D') debugEnabled = !debugEnabled;
  if (key == '?' || key == '/') helpEnabled = !helpEnabled;
  if (key == 'a' || key == 'A') autoArrange = !autoArrange;
  if (key == 'r' || key == 'R') nextArrangement();
  if (key == 'n' || key == 'N') densityIndex = (densityIndex + 1) % 3;
  if (key == 'f' || key == 'F') autoFlash = !autoFlash;
  if (key == 'i' || key == 'I') autoInvert = !autoInvert;
  if (key == 'o' || key == 'O') autoGlow = !autoGlow;
  if (key == '[') glowIntensity = max(0, glowIntensity - 0.10);
  if (key == ']') glowIntensity = min(1.8, glowIntensity + 0.10);
  if (key == '-' || key == '_') flashIntensity = max(0.10, flashIntensity - 0.10);
  if (key == '=' || key == '+') flashIntensity = min(1.2, flashIntensity + 0.10);
  if (key == ';') invertIntensity = max(0.10, invertIntensity - 0.10);
  if (key == '\'' || key == '"') invertIntensity = min(1.4, invertIntensity + 0.10);
  if (key == 'c' || key == 'C') resetAnalysis();
  if (key == 'l' || key == 'L') { liveMicGuard = !liveMicGuard; resetAnalysis(); }
  if (key == 't' || key == 'T') {
    if (audioReady) {
      testSignal = !testSignal;
      previousSyntheticBeat = -1;
      if (testSignal) calibrationFrames = 0; else resetAnalysis();
    } else testSignal = true;
  }
  if (key == 'e' || key == 'E') {
    if (millis() - lastManualFlashMs >= 320) {
      manualFlash = 1.18;
      haloBurst = max(haloBurst, 0.92);
      flashStyle = (flashStyle + 1) % 3;
      lastManualFlashMs = millis();
    }
  }
  if (key == 'u' || key == 'U') {
    if (millis() - lastManualInvertMs >= 420) {
      manualInvert = 1.15;
      lastManualInvertMs = millis();
    }
  }
  if (key == 'z' || key == 'Z') { holdZoom = true; punch = max(punch, 0.58); }
  if (key == 'x' || key == 'X') { holdMirror = true; mirrorAmount = 1; }
  if (key == 'j' || key == 'J') holdMultiply = true;
  if (key == 'k' || key == 'K') holdSlice = true;
  if (key == 'g' || key == 'G') { glitchAmount = 0.76; sliceAmount = 0.70; }
  if (key == 'v' || key == 'V') {
    if (!holdFreeze) {
      freezeFrame.copy(output, 0, 0, OUT_W, OUT_H, 0, 0, OUT_W, OUT_H);
      holdFreeze = true;
    }
  }
  if (key == 'h' || key == 'H') holdBlack = true;
  if (key == '0') resetEffects();
  if (key == ',' || key == '<') inputGain = max(0.15, inputGain / 1.12);
  if (key == '.' || key == '>') inputGain = min(8.0, inputGain * 1.12);
  if (key == CODED && keyCode == UP) masterIntensity = min(1.0, masterIntensity + 0.05);
  if (key == CODED && keyCode == DOWN) masterIntensity = max(0.10, masterIntensity - 0.05);
}

void keyReleased() {
  if (key == 'z' || key == 'Z') holdZoom = false;
  if (key == 'x' || key == 'X') holdMirror = false;
  if (key == 'j' || key == 'J') holdMultiply = false;
  if (key == 'k' || key == 'K') holdSlice = false;
  if (key == 'v' || key == 'V') holdFreeze = false;
  if (key == 'h' || key == 'H') holdBlack = false;
}

void mousePressed() { onBeat(0.90, dominantBand()); }

void resetEffects() {
  holdBlack = false; holdFreeze = false; holdMirror = false;
  holdZoom = false; holdMultiply = false; holdSlice = false;
  glitchAmount = 0; sliceAmount = 0; mirrorAmount = 0;
  manualFlash = 0; autoFlashPulse = 0;
  manualInvert = 0; autoInvertPulse = 0;
  punch = 0;
}
