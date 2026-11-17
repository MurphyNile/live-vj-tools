import processing.sound.*;
import codeanticode.syphon.*;

/* MCR-T / ULTRAS LIVE V4 BG FADE · REACTOR
   Three independent scenes. No decorative ID rails, no cut scene.
   1 MICRO: a single clear wordmark / 2 LANES: kinetic continuous transport
   3 DEPTH: a controlled, legible forward-perspective drive.
*/

final int W=1056, H=576, FFT_BINS=512, BAND_COUNT=5;
final int SCENE_COUNT=3, WHITE=0xFFF3F3F2, RED=0xFFFF1B20;
final String SYPHON_NAME="MCRT_ULTRAS_LIVE_V4_BG";
PImage fullLogo, wordLogo, ultrasLogo, freezeFrame;
PGraphics fromFrame, toFrame, mergedFrame, output;
// 15 pre-compressed JPEG backgrounds. Full shuffle bag, no immediate repeats.
final int BG_CAPACITY=15;
PImage[] bgImages=new PImage[BG_CAPACITY];
float[] bgShade=new float[BG_CAPACITY];
int[] bgDeck=new int[BG_CAPACITY];
int bgCount=0, bgCurrent=0, bgPrevious=0, bgDeckPos=0, lastBgSwap=-5000;
boolean bgEnabled=false, bgHasPicked=false;
// bgVisibility is a linear fade clock; bgReveal is its smoothstep envelope.
float bgVisibility=0, bgReveal=0, bgBlend=1.0, bgBlendRate=4.2;
SyphonServer syphon;
boolean syphonReady=false, hasClients=false;
int currentScene=0, previousScene=0, variant=0, density=1;
String[] sceneName={"MICRO / ID", "LANES / RACE", "DEPTH / DRIVE"};
float transition=1, clock=0;
float kick=0, impact=0, accent=0;
float[] laneOffset={0,80,310,55,180};
float depthPhase=0;

boolean autoFlash=true, autoInvert=false, autoAccent=true;
float flashPower=0.94, invertPower=0.95, masterBrightness=1.0;
float flashPulse=0, invertPulse=0;
int flashTint=1; // 0 WHITE, 1 RED
int lastFlash=-3000, lastInvert=-3000;
boolean pendingManualFlash=false, pendingManualInvert=false;
boolean blackout=false, frozen=false, debug=false, help=false;
int beatCounter=0;

void settings(){ size(W,H,P3D); smooth(4); }

void setup(){
  frameRate(60);
  surface.setTitle("MCR-T / ULTRAS LIVE V4 BG FADE / REACTOR");
  fullLogo=loadImage("MCRT_Logo_Full.png");
  wordLogo=loadImage("MCRT_Wordmark.png");
  ultrasLogo=loadImage("MCRT_Ultras.png");
  if(fullLogo==null || wordLogo==null || ultrasLogo==null){
    println("ERROR: MCRT logo PNG(s) missing from data folder"); exit(); return;
  }
  fromFrame=createGraphics(W,H,P2D);
  toFrame=createGraphics(W,H,P2D);
  mergedFrame=createGraphics(W,H,P2D);
  output=createGraphics(W,H,P2D);
  freezeFrame=createImage(W,H,ARGB);
  loadStageBackgrounds();
  try{
    syphon=new SyphonServer(this,SYPHON_NAME);
    syphonReady=true;
    println("Syphon: "+SYPHON_NAME);
  }catch(Throwable t){
    println("Syphon unavailable: "+t.getMessage());
  }
  setupAudio();
  resetAnalysis();
}

void draw(){
  // First integrate yesterday's envelopes. Then poll audio so this frame shows
  // the FULL intensity of a detected beat instead of decaying it immediately.
  updateDynamics();
  updateAudioAnalysis();

  if(!blackout && !frozen){
    toFrame.beginDraw();
    toFrame.clear();
    toFrame.imageMode(CENTER);
    renderScene(toFrame,currentScene);
    toFrame.endDraw();
    boolean shifting=transition<0.999 && previousScene!=currentScene;
    if(shifting){
      fromFrame.beginDraw();
      fromFrame.clear();
      fromFrame.imageMode(CENTER);
      renderScene(fromFrame,previousScene);
      fromFrame.endDraw();
    }
    mergedFrame.beginDraw();
    mergedFrame.background(0);
    mergedFrame.imageMode(CORNER);
    mergedFrame.noTint();
    // Background must be composited FIRST. Logo scene buffers are transparent.
    drawStageBackground(mergedFrame);
    if(shifting){
      // Clean crossfade of typography, while the background keeps running.
      float mix=smoothStep(transition);
      mergedFrame.tint(255,255*(1.0-mix));
      mergedFrame.image(fromFrame,0,0);
      mergedFrame.tint(255,255*mix);
      mergedFrame.image(toFrame,0,0);
      mergedFrame.noTint();
    }else{
      mergedFrame.image(toFrame,0,0);
    }
    mergedFrame.endDraw();
  }

  output.beginDraw();
  output.background(0);
  output.imageMode(CORNER);
  output.noTint();
  if(blackout){
    // Emergency black has priority over all hit effects.
  }else if(frozen){
    output.image(freezeFrame,0,0);
  }else{
    output.image(mergedFrame,0,0);
    drawMasterFX(output);
  }
  output.endDraw();

  if(syphonReady){
    try{
      syphon.sendImage(output);
      if(frameCount%60==0)hasClients=syphon.hasClients();
    }catch(Throwable t){
      syphonReady=false;
      println("Syphon stopped: "+t.getMessage());
    }
  }
  background(0);
  image(output,0,0);
  if(debug)drawHUD();
  if(help)drawHelp();
}

void updateDynamics(){
  float dt=min(0.050,1.0/max(20.0,frameRate));
  float frames=dt*60.0;
  clock+=dt;
  // S switch is a genuine 0.6s fade-in / 0.5s fade-out, not a one-frame pop.
  // Fade level is time-driven rather than a frame-rate-dependent lerp.
  bgVisibility=constrain(bgVisibility+(bgEnabled?1.75:-2.0)*dt,0,1);
  bgReveal=smoothStep(bgVisibility);
  bgBlend=min(1.0,bgBlend+dt*bgBlendRate);
  transition=min(1,transition+dt*2.05); // deliberate 0.49 s scene change
  kick*=pow(0.88,frames);
  impact*=pow(0.91,frames);
  accent*=pow(0.90,frames);
  // Manual key hits are entered between frames. Hold the first frame at full
  // strength rather than decaying the event before it can be displayed.
  if(pendingManualFlash)pendingManualFlash=false;
  else flashPulse*=pow(0.67,frames);
  if(pendingManualInvert)pendingManualInvert=false;
  else invertPulse*=pow(0.86,frames);

  // No teleporting. Audio changes velocity only, never absolute position.
  float transport=0.80+0.70*bandValue[0]+0.38*drive+0.32*kick;
  for(int i=0;i<laneOffset.length;i++){
    float dir=(i%2==0?1:-1);
    float speed=(i==0?150:i==1?194:i==2?168:i==3?218:186);
    laneOffset[i]+=dir*speed*transport*dt;
    // Preserve a mathematically seamless phase during multi-hour shows.
    // Wrap only by an exact number of tile periods, never arbitrary pixels.
    if(abs(laneOffset[i])>200000){
      float ww=(variant==0?592:variant==1?745:515);
      float gg=(variant==1?124:94);
      laneOffset[i]=wrapPositive(laneOffset[i],ww+gg);
    }
  }
  float depthRate=(density==0?0.80:density==1?1.0:1.25);
  depthPhase+=dt*(0.25+0.20*bandValue[0]+0.16*drive+0.12*kick)*depthRate;
  if(depthPhase>10000)depthPhase-=10000;
}

void changeScene(int next){
  next=constrain(next,0,SCENE_COUNT-1);
  if(next==currentScene)return;
  previousScene=currentScene;
  currentScene=next;
  transition=0;
  impact*=0.5;
}

void onBeat(float strength,int dominant){
  beatCounter++;
  float s=constrain(strength,0,1);
  kick=max(kick,0.42+0.58*s);
  impact=max(impact,0.38+0.62*s);
  if(beatCounter%4==0)accent=max(accent,0.80+0.20*s);
  int now=millis();
  if(bgEnabled && bgCount>=2){
    // Avoid stacking changes mid-crossfade; strong kicks can still switch every beat.
    int every=(s>=0.68?1:(s>=0.43?2:4));
    int minimumGap=s>=0.68?290:430;
    if(beatCounter%every==0 && bgBlend>=0.995 && now-lastBgSwap>=minimumGap)
      cueBackground(s);
  }
  if(autoFlash && beatCounter%4==0 && s>0.42 && now-lastFlash>370){
    flashPulse=max(flashPulse,1.0);
    flashTint=(beatCounter%8==0)?1:0;
    lastFlash=now;
  }
  if(autoInvert && beatCounter%16==0 && s>0.48 && now-lastInvert>1100){
    invertPulse=max(invertPulse,1.0);
    lastInvert=now;
  }
}

void fireFlash(int tint){
  int now=millis();
  // Manual keys always take priority. Cooldown is only for AUTO flashes.
  flashTint=tint;
  flashPulse=1.0;
  pendingManualFlash=true;
  lastFlash=now;
  accent=max(accent,0.65);
}

void keyPressed(){
  if(key=='1')changeScene(0);
  if(key=='2')changeScene(1);
  // Legacy 4 also opens DEPTH, after deleting the old Scene 3 CUT.
  if(key=='3'||key=='4')changeScene(2);
  if(key=='r'||key=='R')variant=(variant+1)%3;
  if(key=='n'||key=='N')density=(density+1)%3;
  if(key=='f'||key=='F')autoFlash=!autoFlash;
  if(key=='s'||key=='S'){
    if(bgCount>0){
      bgEnabled=!bgEnabled;
      if(bgEnabled){
        // Select immediately but show through the fade-in envelope.
        cueBackground(0.56);
      }
    }else println("BG unavailable: data/BG_01.jpg ... BG_15.jpg");
  }
  if(key=='i'||key=='I')autoInvert=!autoInvert;
  if(key=='g'||key=='G')autoAccent=!autoAccent;
  if(key=='e'||key=='E')fireFlash(1); // E = RED, always
  if(key=='w'||key=='W')fireFlash(0); // W = WHITE, always
  if(key=='u'||key=='U'){
    invertPulse=1.0;pendingManualInvert=true;lastInvert=millis();
  }
  if(key=='b'||key=='B'||key==' ')onBeat(0.94,0);
  if(key=='0'){
    flashPulse=0; invertPulse=0; pendingManualFlash=false; pendingManualInvert=false;
    blackout=false; frozen=false;
  }
  if(key=='h'||key=='H')blackout=true;
  if(key=='v'||key=='V'){
    if(!frozen){freezeFrame.copy(output,0,0,W,H,0,0,W,H);frozen=true;}
  }
  if(key=='t'||key=='T'){
    testSignal=!testSignal;
    previousSyntheticBeat=-1;
    if(!testSignal)resetAnalysis();
  }
  if(key=='c'||key=='C')resetAnalysis();
  if(key=='d'||key=='D')debug=!debug;
  if(key=='?'||key=='/')help=!help;
  if(key=='[')flashPower=max(0.3,flashPower-0.10);
  if(key==']')flashPower=min(1.2,flashPower+0.10);
  if(key==',')inputGain=max(0.15,inputGain/1.12);
  if(key=='.')inputGain=min(8.0,inputGain*1.12);
  if(key==CODED&&keyCode==UP)masterBrightness=min(1.0,masterBrightness+0.05);
  if(key==CODED&&keyCode==DOWN)masterBrightness=max(0.1,masterBrightness-0.05);
}

void keyReleased(){
  if(key=='h'||key=='H')blackout=false;
  if(key=='v'||key=='V')frozen=false;
}

float clamp01(float x){return constrain(x,0,1);}
float smoothStep(float t){t=clamp01(t);return t*t*(3-2*t);}
float wrapPositive(float value,float period){return ((value%period)+period)%period;}
float hash01(int n){float v=sin(n*81.11+55.33)*35397.15;return v-floor(v);}
