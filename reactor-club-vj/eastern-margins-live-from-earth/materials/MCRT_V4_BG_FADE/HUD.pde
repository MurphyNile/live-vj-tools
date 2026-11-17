// HUD and help are drawn after Syphon sends the clean output.
void drawHUD(){
  pushStyle();
  noStroke();fill(0,235);rect(0,0,W,122);
  textAlign(LEFT,TOP);
  fill(255);textSize(18);
  text("MCR-T / ULTRAS LIVE V4 BG FADE",14,9);
  textSize(13);fill(215);
  text((currentScene+1)+" " +sceneName[currentScene]+
    "  |  "+(testSignal?"TEST 136 BPM":audioReady?"LIVE AUDIO":"NO AUDIO")+
    "  |  FPS "+nf(frameRate,1,1),14,37);
  text("FLASH [F] "+(autoFlash?"ON":"OFF")+
    "   INVERT [I] "+(autoInvert?"ON":"OFF")+
    "   RED ACCENT [G] "+(autoAccent?"ON":"OFF")+
    "   BG [S] "+(bgEnabled?"ON":"OFF")+" "+bgCount+" IMG  "+nf(bgReveal,1,2)+
    "   SYPHON "+(syphonReady?(hasClients?"LINKED":"READY"):"OFF"),14,58);
  for(int i=0;i<BAND_COUNT;i++){
    float x=14+i*120;
    fill(55);rect(x,86,106,8);
    fill(255);rect(x,86,106*bandValue[i],8);
  }
  fill(200);text("D HUD  /  ? HELP  /  H BLACKOUT",690,91);
  popStyle();
}
void drawHelp(){
  pushStyle();noStroke();fill(0,237);rect(0,H-230,W,230);
  textAlign(LEFT,TOP);fill(255);textSize(19);
  text("MCR-T / LIVE V4 BG CONTROLS",18,H-219);
  textSize(14);fill(225);
  text("1 MICRO ID     2 SPEED LANES     3 DEPTH DRIVE\n"+
    "S BG FADE IN/OUT (15 images, shuffled)\n"+
    "R layout variant   N density\n"+
    "E RED flash    W WHITE flash\n"+
    "F auto flash   U manual invert   I auto invert",18,H-181);
  text("G red accent   [ / ] flash strength\n"+
    "T test 136 BPM   C calibrate audio\n"+
    "B / SPACE beat hit   V hold freeze\n"+
    "H hold blackout   0 clear FX\n"+
    "D HUD   ? HELP   UP / DOWN master dimmer",540,H-181);
  popStyle();
}
