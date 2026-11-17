/* A restrained typographic system. Keep the original vector-derived PNGs
   intact: this project moves and tints them; it does not redraw characters. */

void renderScene(PGraphics g,int scene){
  switch(scene){
    case 0:drawIdentity(g);break;
    case 1:drawLanes(g);break;
    case 2:drawDepth(g);break;
  }
}

void mark(PGraphics g,PImage img,float x,float y,float w,float angle,int colorRGB,float alpha){
  if(w<1 || alpha<=0.005)return;
  float h=w*img.height/(float)img.width;
  g.pushMatrix();
  g.translate(x,y);
  g.rotate(angle);
  g.imageMode(CENTER);
  g.tint(colorRGB,255*clamp01(alpha));
  g.image(img,0,0,w,h);
  g.noTint();
  g.popMatrix();
}

void drawIdentity(PGraphics g){
  // No decoration and no top/bottom rails. Only the official MCR-T ULTRAS.
  float scale=1.0+0.012*sin(clock*0.96)+0.015*kick+0.010*bandValue[0];
  float x=W*0.5+sin(clock*0.45)*7.0;
  float y=H*0.5+cos(clock*0.33)*5.0;
  float width=(variant==0?760:variant==1?700:815)*scale;
  mark(g,fullLogo,x,y,width,0.004*sin(clock*0.45),WHITE,1.0);
}

void drawLanes(PGraphics g){
  // Entire rows move constantly at integrated speed. No decorative rails,
  // no jump-cut refill, and no repeated ghost layer behind the typography.
  int rows=(density==0?2:density==1?3:4);
  float yPad=64;
  float usable=H-2*yPad;
  float rowStep=usable/(float)rows;
  float wordWidth=(variant==0?592:variant==1?745:515);
  float gap=(variant==1?124:94);
  float period=wordWidth+gap;
  for(int r=0;r<rows;r++){
    float y=yPad+(r+0.5)*rowStep;
    float offset=wrapPositive(laneOffset[r],period);
    // Kinetic type is the composition. The middle row is the main anchor.
    boolean middle=(r==rows/2);
    PImage glyph=middle?fullLogo:wordLogo;
    float width=wordWidth*(middle?0.98:1.0);
    float bob=sin(clock*0.55+r*0.75)*3.4;
    float weight=middle?1.0:0.78;
    float beatScale=1.0+0.024*kick+0.018*bandValue[1];
    int ink=WHITE;
    if(autoAccent && r==rows/2 && accent>0.15)ink=RED;
    // For positive and negative integrated phases, periodic copies are
    // guaranteed to cover both edges without a visible reset.
    for(int k=-3;k<=6;k++){
      float x=offset+k*period;
      if(x<-wordWidth || x>W+wordWidth)continue;
      mark(g,glyph,x,y+bob,width*beatScale,0,ink,weight);
    }
  }
}

float normalizedDepth(float x){return wrapPositive(x,1.0);}

void drawDepth(PGraphics g){
  // One hero wordmark travelling in perspective, not a pile of near/far copies.
  // Its near-end fade prevents an abrupt giant-to-small wrap at the loop seam.
  float d=normalizedDepth(depthPhase);
  float appear=smoothStep(constrain((d-0.018)/0.15,0,1));
  float disappear=1.0-smoothStep(constrain((d-0.875)/0.11,0,1));
  float alpha=appear*disappear;
  float width=86+820*pow(d,1.68);
  float travel=(variant==0?0:variant==1?-1:1);
  float x=W*0.50+travel*(1-d)*W*0.13+sin(clock*0.27)*8;
  float y=H*0.50+(0.5-d)*75+cos(clock*0.31)*6;
  float angle=travel*0.045*(1-d)+0.013*sin(clock*0.51);
  int ink=(autoAccent && accent>0.38)?RED:WHITE;
  mark(g,fullLogo,x,y,width,angle,ink,alpha);
}
