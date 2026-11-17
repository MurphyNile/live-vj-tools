// All status text is drawn AFTER syphon.sendImage(output), preview only.
void drawHUD() {
  pushStyle();
  noStroke();
  fill(0, 237);
  rect(0, 0, OUT_W, 178);
  textAlign(LEFT, TOP);
  fill(255,101,202);
  textSize(20);
  text("BILLIONHAPPY / PINK SYSTEM FINAL", 14, 9);
  fill(248);
  textSize(15);
  text("0" + (currentScene+1) + "  " + sceneNames[currentScene] + "   |   " +
    (testSignal ? "TEST 124 BPM" : audioReady ? "LIVE MIC" : "NO MIC"), 14, 35);
  fill(204);
  textSize(12);
  text("Syphon: " + (syphonReady ? (syphonHasClient ? "CONNECTED" : "READY") : "OFF") +
    "   FPS: " + nf(frameRate,1,1) + "   Beats: " + beatCount +
    "   Mic Guard: " + (liveMicGuard?"ON":"OFF"), 14, 60);
  text("FLASH [F]: " + (autoFlash?"ON":"OFF") + "  -/+ " + nf(flashIntensity,1,2) +
    "   INVERT [I]: " + (autoInvert?"ON":"OFF") + "  ;/' " + nf(invertIntensity,1,2) +
    "   GLOW [O]: " + (autoGlow?"ON":"OFF") + "  [/] " + nf(glowIntensity,1,2), 14, 80);
  text("Input Gain [,/.]: " + nf(inputGain,1,2) +
    "   Brightness: " + nf(masterIntensity,1,2) +
    "   CAL: " + (calibrationFrames>0?"YES":"NO"), 14, 100);
  for (int i = 0; i < BAND_COUNT; i++) {
    float x = 14 + i*125;
    fill(43); rect(x, 124, 116, 10);
    fill(255,101,202); rect(x, 124, 116*bandValue[i], 10);
    fill(220); text("B" + i + " " + nf(bandValue[i],1,2), x, 139);
  }
  fill(255,188,217);
  text("D hide HUD  /  ? show shortcuts  /  H hold BLACKOUT", 14, 159);
  popStyle();
}

void drawHelp() {
  pushStyle();
  noStroke(); fill(0,242); rect(0, OUT_H-265, OUT_W, 265);
  textAlign(LEFT,TOP); fill(255,101,202); textSize(20);
  text("LIVE KEYS / FINAL", 18, OUT_H-253);
  fill(250); textSize(14);
  text("1 SOLO    2 WALL / SWEEP    3 CLONE    4 FALL / SPACE DROP\n"+
    "R next arrangement   N density   A auto layouts\n"+
    "SPACE / B manual beat   E flash hit   U invert hit\n"+
    "F auto flash   I auto invert   O auto glow\n"+
    "- / + flash strength   ; / ' invert strength   [ / ] glow strength", 18, OUT_H-216);
  text("T 124 BPM test   C re-calibrate mic\n"+
    ", / . input gain\n"+
    "D HUD   ? shortcuts\n"+
    "H HOLD blackout   UP/DOWN brightness\n"+
    "0 reset FX", 565, OUT_H-216);
  fill(205); textSize(12);
  text("Final live layout. Flash and invert are both stronger, longer and easier to trigger on stage.", 18, OUT_H-23);
  popStyle();
}
