/* MCR-T / STAGE BACKGROUND BANK V4
   15 compressed and preloaded user images (7 prior + 8 newly supplied).
   S toggles the 0.6-second fade envelope, independent of all logo scenes.
   Beat switching uses a shuffle bag. All images appear before any repeats.
*/

void loadStageBackgrounds(){
  bgCount=0;
  float[] shadeTable={108.0, 108.0, 100.0, 95.0, 113.0, 92.0, 104.0, 130.0, 146.0, 144.0, 143.0, 76.0, 133.0, 132.0, 123.0};
  for(int i=1;i<=BG_CAPACITY;i++){
    String path="BG_"+nf(i,2)+".jpg";
    PImage pic=loadImage(path);
    if(pic!=null && pic.width>0 && pic.height>0){
      bgImages[bgCount]=pic;
      bgShade[bgCount]=shadeTable[i-1];
      bgCount++;
    }else println("Missing background file: data/"+path);
  }
  bgCurrent=0;
  bgPrevious=0;
  bgHasPicked=false;
  bgBlend=1.0;
  bgVisibility=0;
  bgReveal=0;
  reshuffleBackgrounds(-1);
  println("MCR-T BG: preloaded "+bgCount+" / "+BG_CAPACITY+" JPEGs. Press S to fade in/out.");
}

void reshuffleBackgrounds(int avoid){
  if(bgCount<=0)return;
  for(int i=0;i<bgCount;i++)bgDeck[i]=i;
  for(int i=bgCount-1;i>0;i--){
    int j=floor(random(i+1));
    int a=bgDeck[i]; bgDeck[i]=bgDeck[j]; bgDeck[j]=a;
  }
  // Prevent repeated adjacent images across a shuffle-deck boundary.
  if(bgCount>1 && bgDeck[0]==avoid){
    int a=bgDeck[0]; bgDeck[0]=bgDeck[1]; bgDeck[1]=a;
  }
  bgDeckPos=0;
}

int nextShuffledBackground(){
  if(bgCount<=0)return 0;
  if(bgDeckPos>=bgCount)reshuffleBackgrounds(bgCurrent);
  return bgDeck[bgDeckPos++];
}

void cueBackground(float strength){
  if(bgCount<=0)return;
  if(bgCount==1){bgCurrent=0;bgPrevious=0;bgBlend=1;return;}
  int chosen=nextShuffledBackground();
  // On the first S activation we fade from black rather than from a random old image.
  if(!bgHasPicked || bgReveal<0.005){
    bgCurrent=chosen;
    bgPrevious=chosen;
    bgBlend=1.0;
  }else{
    if(chosen==bgCurrent){ // defensive; shuffle already prevents this.
      chosen=(chosen+1)%bgCount;
    }
    bgPrevious=bgCurrent;
    bgCurrent=chosen;
    bgBlend=0;
  }
  bgHasPicked=true;
  bgBlendRate=strength>=0.68?5.4:strength>=0.43?3.7:2.9;
  lastBgSwap=millis();
}

void drawStageBackground(PGraphics g){
  if(bgCount==0 || bgReveal<0.002)return;
  float mix=smoothStep(bgBlend);
  // Shared, slow drift. Do not jump the camera when the photo changes.
  float zoom=1.046+0.010*sin(clock*0.32)+0.010*bandValue[0];
  float moveX=sin(clock*0.23)*6.0;
  float moveY=cos(clock*0.27)*4.0;
  float rw=W*zoom, rh=H*zoom;
  float left=(W-rw)*0.5+moveX;
  float top=(H-rh)*0.5+moveY;
  g.imageMode(CORNER);
  g.blendMode(BLEND);
  // Correct cross-dissolve: old image is fully visible, new image gradually
  // covers it. No mid-transition double-alpha dark dip or strobe.
  g.tint(255,255*bgReveal);
  g.image(bgImages[bgPrevious],left,top,rw,rh);
  if(bgCurrent!=bgPrevious && mix>0.001){
    g.tint(255,255*bgReveal*mix);
    g.image(bgImages[bgCurrent],left,top,rw,rh);
  }
  g.noTint();
  // Brightness-normalized shading reduces sudden white-image glare.
  float shade=lerp(bgShade[bgPrevious],bgShade[bgCurrent],mix);
  g.noStroke();
  g.fill(0,bgReveal*constrain(shade-12.0*kick,65,160));
  g.rect(0,0,W,H);
}
