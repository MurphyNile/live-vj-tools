/* Shared spatial FX + audio-reactive stage response.
   HUD is drawn only after syphon.sendImage(output), so it never appears on stage.
*/

void renderSpatialFX(PGraphics g) {
  float zoom = 1.0 + punch*0.14 + (holdZoom ? 0.48 : 0.0);
  boolean mirrored = holdMirror || mirrorAmount > 0.20;
  g.noTint();
  g.imageMode(CORNER);

  if (holdMultiply) {
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 2; col++) {
        g.image(sceneLayer, col*OUT_W*0.5, row*OUT_H*0.5, OUT_W*0.5, OUT_H*0.5);
      }
    }
  } else {
    g.pushMatrix();
    g.translate(OUT_W*0.5, OUT_H*0.5);
    g.scale(mirrored ? -zoom : zoom, zoom);
    g.imageMode(CENTER);
    g.image(sceneLayer, 0, 0, OUT_W, OUT_H);
    g.popMatrix();
  }

  float amount = max(glitchAmount, max(sliceAmount, holdSlice ? 0.60 : 0));
  if (amount > 0.06) {
    int slices = 8;
    float h = OUT_H / (float)slices;
    g.imageMode(CORNER);
    for (int i = 0; i < slices; i++) {
      if ((i & 1) == 0) continue;
      int sy = floor(i*h);
      int sh = max(1, min(OUT_H - sy, ceil(h)));
      float xShift = sin(i*1.4 + motionClock*1.05) * amount * 52;
      g.copy(sceneLayer, 0, sy, OUT_W, sh, round(xShift), sy, OUT_W, sh);
    }
  }
  g.imageMode(CORNER);
}

void updateGlowTexture() {
  glowSmall.beginDraw();
  glowSmall.background(0);
  glowSmall.noTint();
  glowSmall.imageMode(CORNER);
  glowSmall.image(compositeLayer, 0, 0, glowSmall.width, glowSmall.height);
  glowSmall.filter(BLUR, 5);
  glowSmall.endDraw();
}

void renderMasterComposite(PGraphics g) {
  g.imageMode(CORNER);
  g.blendMode(BLEND);
  g.noTint();

  float bloomPower = autoGlow ? glowIntensity * currentGlow : 0;
  if (bloomPower > 0.015) {
    g.blendMode(ADD);
    g.tint(255, constrain(bloomPower*236, 0, 248));
    g.image(glowSmall, -18, -18, OUT_W+36, OUT_H+36);
    g.tint(255, constrain(bloomPower*150, 0, 206));
    g.image(glowSmall, -42, -42, OUT_W+84, OUT_H+84);
    g.noTint();
    g.blendMode(BLEND);
  }

  g.image(compositeLayer, 0, 0);

  float light = constrain(0.18*strobeBrightness + 0.32*haloBurst, 0, 0.58);
  if (autoGlow && light > 0.015) {
    g.blendMode(ADD);
    g.tint(255, light*202);
    g.image(compositeLayer, 0, 0);
    g.noTint();
    g.blendMode(BLEND);
  }

  float flash = max(autoFlashPulse, manualFlash) * flashIntensity;
  if (flash > 0.020) {
    g.noStroke();
    if (flashStyle == 0) {
      g.blendMode(ADD);
      g.fill(255, 132, 206, constrain(flash*188, 0, 220));
      g.rect(0, 0, OUT_W, OUT_H);
      g.fill(255, 198, 232, constrain(flash*84, 0, 108));
      g.rect(0, 0, OUT_W, OUT_H);
      g.blendMode(BLEND);
    } else if (flashStyle == 1) {
      g.blendMode(ADD);
      g.fill(255, 255, 255, constrain(flash*156, 0, 188));
      g.rect(0, 0, OUT_W, OUT_H);
      g.blendMode(BLEND);
    } else {
      g.blendMode(ADD);
      g.fill(255, 160, 224, constrain(flash*132, 0, 162));
      g.rect(0, 0, OUT_W, OUT_H);
      g.fill(255, 255, 255, constrain(flash*98, 0, 128));
      g.rect(0, 0, OUT_W, OUT_H);
      g.blendMode(BLEND);
    }
  }

  float invertLevel = max(autoInvertPulse, manualInvert) * invertIntensity;
  if (invertLevel > 0.025) {
    invertBuffer.beginDraw();
    invertBuffer.background(0);
    invertBuffer.noTint();
    invertBuffer.image(compositeLayer, 0, 0);
    if (autoGlow && currentGlow > 0.04) {
      invertBuffer.tint(255, constrain(currentGlow*55, 0, 65));
      invertBuffer.image(glowSmall, -18, -18, OUT_W+36, OUT_H+36);
      invertBuffer.noTint();
    }
    invertBuffer.filter(INVERT);
    invertBuffer.endDraw();
    g.tint(255, constrain(invertLevel*255, 0, 245));
    g.image(invertBuffer, 0, 0);
    g.noTint();
  }

  if (masterIntensity < 0.999) {
    g.noStroke();
    g.fill(0, (1.0 - masterIntensity) * 255);
    g.rect(0, 0, OUT_W, OUT_H);
  }
  g.imageMode(CORNER);
}
