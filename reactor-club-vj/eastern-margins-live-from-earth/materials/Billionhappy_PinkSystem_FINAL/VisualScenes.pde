/* Four focused performance scenes.
   WALL: stronger match-sweep without abrupt ghosting.
   FALL: perspective-based spatial drop system.
*/

void renderScene(PGraphics g) { renderSceneByIndex(g, currentScene, 1.0); }

void renderSceneByIndex(PGraphics g, int sceneIndex, float alphaMul) {
  switch(sceneIndex) {
    case 0: renderSolo(g, alphaMul); break;
    case 1: renderWall(g, alphaMul); break;
    case 2: renderClone(g, alphaMul); break;
    case 3: renderFall(g, alphaMul); break;
  }
}

void drawSkull(PGraphics g, float x, float y, float desiredW, float angle, float opacity) {
  if (opacity < 0.01 || desiredW <= 0) return;
  PImage tex = desiredW <= 340 ? logoSmall : desiredW <= 850 ? logoMedium : logoLarge;
  float h = desiredW * ((float)logoOriginal.height / logoOriginal.width);
  g.pushMatrix();
  g.translate(x, y);
  g.rotate(angle);
  g.imageMode(CENTER);
  g.tint(255, constrain(opacity * 255, 0, 255));
  g.image(tex, 0, 0, desiredW, h);
  g.noTint();
  g.popMatrix();
}

float bassScale() {
  return 1.0 + 0.10*kickPulse + 0.06*bandValue[0];
}

void renderSolo(PGraphics g, float alphaMul) {
  float slow = motionClock;
  // Smaller hero so it leaves a cleaner breathing margin.
  float w = (densityIndex==0 ? 650 : densityIndex==1 ? 840 : 1120);
  float x = OUT_W*0.50 + sin(slow*0.62)*22 + sin(slow*1.52)*5;
  float y = OUT_H*0.50 + sin(slow*0.42)*13;
  float breathing = 1 + 0.022*sin(slow*1.18);
  float width = w * breathing * bassScale() * (1 + 0.058*punch);
  drawSkull(g, x, y, width, 0.018*sin(slow*0.62), alphaMul);
  if (punch > 0.16) {
    drawSkull(g, x-12, y+7, width*0.980, -0.014, alphaMul*0.09*punch*3.8);
    drawSkull(g, x+10, y-4, width*1.010, 0.014, alphaMul*0.07*punch*3.3);
  }
}

void renderWall(PGraphics g, float alphaMul) {
  int cols = densityIndex==0 ? 4 : densityIndex==1 ? 7 : 10;
  int rows = densityIndex==0 ? 3 : densityIndex==1 ? 5 : 6;
  float cw = OUT_W / (float)cols;
  float ch = OUT_H / (float)rows;
  float w = min(cw*1.08, ch*1.56) * bassScale();
  float mix = smoothEase(arrangementMix);

  // Continuous left/right scrolling only — no jump-cut clear/refill behaviour.
  // Speed stays moderate and music-reactive, but remains smooth and controlled.
  float baseSpeed = 34.0 + 16.0*bandValue[0] + 8.0*kickPulse;

  for (int r = 0; r < rows; r++) {
    float rowDir = (r % 2 == 0) ? 1.0 : -1.0;
    float rowSpeed = baseSpeed * (0.92 + 0.08*r) * rowDir;
    float scroll = motionClock * rowSpeed;
    for (int c = 0; c < cols; c++) {
      float x0 = wallX(c, r, cw, w, previousArrangement, cols);
      float x1 = wallX(c, r, cw, w, arrangement, cols);
      float y0 = wallY(c, r, ch, previousArrangement, rows);
      float y1 = wallY(c, r, ch, arrangement, rows);
      float x = lerp(x0, x1, mix);
      float y = lerp(y0, y1, mix);
      float id = r*cols + c;

      x += scroll;
      float wrap = OUT_W + w*1.2;
      while (x < -w*0.6) x += wrap;
      while (x > OUT_W + w*0.6) x -= wrap;

      // Keep some life, but much cleaner than the previous jumpy wall.
      float driftY = sin(motionClock*0.72 + id*0.38) * 6.0;
      float angle = 0.02*sin(motionClock*0.64 + id*0.44) + 0.06*kickPulse*sin(id*0.31 + motionClock*1.6);
      float scale = 1.0 + 0.018*bandValue[2] + 0.040*kickPulse;
      float opacity = (0.90 + 0.08*bandValue[1]) * alphaMul;

      drawSkull(g, x, y + driftY, w*scale, angle, opacity);
      if (x < w*0.5) drawSkull(g, x + wrap, y + driftY, w*scale, angle, opacity*0.94);
      if (x > OUT_W - w*0.5) drawSkull(g, x - wrap, y + driftY, w*scale, angle, opacity*0.94);
    }
  }
}

float wallX(int c, int r, float cw, float w, int type, int cols) {
  float offset = 0;
  if (type == 1) offset = (r & 1) == 0 ? 0 : 0.42;
  if (type == 2) offset = (r % 3) * 0.22;
  if (type == 3) offset = ((r + c) & 1) == 0 ? -0.10 : 0.10;
  float x = (c + 0.5 + offset) * cw;
  float wrap = OUT_W + w*0.8;
  while (x < -w*0.4) x += wrap;
  while (x > OUT_W + w*0.4) x -= wrap;
  return x;
}

float wallY(int c, int r, float ch, int type, int rows) {
  float y = (r + 0.5) * ch;
  if (type == 3 && (c & 1) == 0) y += 4;
  return y;
}

void renderClone(PGraphics g, float alphaMul) {
  int activeStage = holdMultiply ? 3 : cloneStage;
  if (holdMultiply || cloneMix >= 0.999 || previousCloneStage == activeStage) {
    drawCloneStage(g, activeStage, alphaMul);
  } else {
    float t = smoothEase(cloneMix);
    drawCloneStage(g, previousCloneStage, (1.0 - t)*alphaMul);
    drawCloneStage(g, activeStage, t*alphaMul);
  }
}

void drawCloneStage(PGraphics g, int stage, float opacity) {
  if (opacity <= 0.01) return;
  if (stage == 4) {
    float spin = 0.055*sin(motionClock*1.05) + 0.06*kickPulse;
    drawSkull(g, OUT_W*0.5, OUT_H*0.5, 1360*bassScale(), spin, opacity);
    return;
  }
  int n = stage == 0 ? 1 : stage == 1 ? 2 : stage == 2 ? 4 : 8;
  float cw = OUT_W / (float)n;
  float ch = OUT_H / (float)n;
  float w = min(cw*0.98, ch*1.32) * bassScale();
  float scrollX = sin(motionClock*0.54)*24.0;
  float scrollY = cos(motionClock*0.43)*12.0;

  for (int r = 0; r < n; r++) {
    for (int c = 0; c < n; c++) {
      float id = r*11 + c;
      float phase = (r*3+c) * 0.24;
      float dy = sin(motionClock*1.08 + phase) * min(8.5, 17.0/n);
      float dx = cos(motionClock*0.76 + phase) * min(7.2, 14.0/n);
      float rotDir = ((r+c)&1)==0 ? 1 : -1;
      float angle = rotDir * (0.12 * sin(motionClock*1.04 + id*0.62));
      angle += rotDir * 0.12 * kickPulse;
      float scale = 1.0 + 0.046*sin(motionClock*1.42 + id) + 0.045*bandValue[1];
      drawSkull(g, (c+0.5)*cw + dx + scrollX, (r+0.5)*ch + dy + scrollY, w*scale, angle, opacity);
    }
  }
}

void renderFall(PGraphics g, float alphaMul) {
  for (int i = 0; i < FALL_COUNT; i++) {
    float d = constrain(fallDepth[i], 0, 1);
    float perspective = 0.12 + d*1.72;
    float x = OUT_W*0.5 + fallBaseX[i] * (OUT_W*0.30) * perspective;
    float y = lerp(-170, OUT_H+190, pow(d, 1.42));
    float w = fallBodySize[i] * (0.20 + 2.10*d) * (0.95 + 0.16*bandValue[0]);
    float alpha = alphaMul * fallOpacity[i] * constrain(map(d, 0, 1, 0.10, 1.0), 0.10, 1.0);

    // Longer trail = stronger sense of spatial descent.
    for (int t = 4; t >= 1; t--) {
      float td = max(0, d - 0.030*t);
      float tp = 0.12 + td*1.72;
      float tx = OUT_W*0.5 + (fallBaseX[i] - fallVX[i]*0.16*t) * (OUT_W*0.30) * tp;
      float ty = lerp(-170, OUT_H+190, pow(td, 1.42));
      float tw = w * (1.0 - 0.11*t);
      drawSkull(g, tx, ty, tw, fallAng[i] - fallAngVel[i]*t*3.2, alpha * (0.06 + 0.03*t));
    }

    drawSkull(g, x, y, w, fallAng[i], alpha);
  }
}
