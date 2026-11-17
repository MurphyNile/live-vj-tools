void drawMasterFX(PGraphics g){
  // Unlike V1, each hit begins at full power on its first rendered frame.
  // RED is a saturated stage exposure with the letterforms lifted back out
  // in white. WHITE is an unambiguous full-frame flash, not a weak tint.
  if(flashPulse>0.015){
    float a=clamp01(flashPulse*flashPower);
    g.blendMode(BLEND);
    g.noStroke();
    if(flashTint==1){
      g.fill(255,19,25,248*a);
      g.rect(0,0,W,H);
      // Recover the official white letters without repainting the glyphs.
      g.blendMode(ADD);
      g.tint(WHITE,155*a);
      g.image(mergedFrame,0,0);
      g.noTint();
      g.blendMode(BLEND);
    }else{
      g.fill(255,255,255,244*a);
      g.rect(0,0,W,H);
    }
  }
  if(invertPulse>0.015){
    g.blendMode(DIFFERENCE);
    g.noStroke();
    g.fill(255,255,255,255*clamp01(invertPulse*invertPower));
    g.rect(0,0,W,H);
    g.blendMode(BLEND);
  }
  if(masterBrightness<0.999){
    g.blendMode(BLEND);
    g.noStroke();
    g.fill(0,255*(1.0-masterBrightness));
    g.rect(0,0,W,H);
  }
  g.noTint();
  g.blendMode(BLEND);
}
