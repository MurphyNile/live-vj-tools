#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

#define PROCESSING_COLOR_SHADER

uniform vec2 resolution;
uniform float time;
uniform float drive;
uniform float density;
uniform float bass;
uniform float mid;
uniform float high;
uniform float pulse;
uniform float gather;
uniform float intensity;
uniform float layoutA;
uniform float layoutB;
uniform float layoutMorph;
uniform float variation;
uniform float eventSeed;
uniform float impact;
uniform float rareBurst;
uniform vec2 burstCenter;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.53;
  mat2 rotation = mat2(0.82, -0.57, 0.57, 0.82);
  for (int i = 0; i < 4; i++) {
    value += amplitude * valueNoise(p);
    p = rotation * p * 2.02 + vec2(7.1, 11.7);
    amplitude *= 0.49;
  }
  return value;
}

float priorityBase(float id) {
  if (id < 0.5) return 0.96;
  if (id < 1.5) return 0.34;
  if (id < 2.5) return 0.72;
  if (id < 3.5) return 0.18;
  if (id < 4.5) return 0.88;
  if (id < 5.5) return 0.48;
  if (id < 6.5) return 0.78;
  if (id < 7.5) return 0.27;
  return 0.61;
}

float densityBase(float id) {
  if (id < 0.5) return 0.88;
  if (id < 1.5) return 0.26;
  if (id < 2.5) return 0.67;
  if (id < 3.5) return 0.14;
  if (id < 4.5) return 0.94;
  if (id < 5.5) return 0.42;
  if (id < 6.5) return 0.73;
  if (id < 7.5) return 0.22;
  return 0.56;
}

vec4 macroRegion(float id, float state) {
  float col = mod(id, 3.0);
  float row = floor(id / 3.0);
  float jx = (hash21(vec2(701.0 + state * 113.0 + id * 37.0, 1.7)) - 0.5) * 0.055;
  float jy = (hash21(vec2(907.0 + state * 149.0 + id * 53.0, 2.9)) - 0.5) * 0.065;
  float extraW = hash21(vec2(1103.0 + state * 173.0 + id * 71.0, 4.1)) * 0.115;
  float extraH = hash21(vec2(1301.0 + state * 197.0 + id * 89.0, 5.3)) * 0.120;
  float x = col / 3.0 - 0.010 + jx;
  float y = row / 3.0 - 0.012 + jy;
  float w = 0.315 + extraW;
  float h = 0.305 + extraH;
  if (abs(mod(id + state * 2.0, 7.0) - 1.0) < 0.5) w += 0.105;
  if (abs(mod(id + state, 8.0) - 3.0) < 0.5) h += 0.095;
  if (col < 0.5) x = min(x, 0.008);
  if (row < 0.5) y = min(y, 0.008);
  x = clamp(x, -0.025, 0.94);
  y = clamp(y, -0.025, 0.94);
  w = min(w, 1.025 - x);
  h = min(h, 1.025 - y);
  return vec4(x, y, w, h);
}

float softRegion(vec2 uv, vec4 region) {
  vec2 center = region.xy + region.zw * 0.5;
  vec2 q = abs(uv - center) / max(region.zw * 0.5, vec2(0.001));
  float boxDistance = max(q.x, q.y);
  float roundDistance = length(q) * 0.73;
  float d = mix(boxDistance, roundDistance, 0.78);
  return 1.0 - smoothstep(0.54, 1.34, d);
}

vec2 layoutCoordinate(vec2 p, float state) {
  if (state < 0.5) {
    p.x *= 0.86;
    return p;
  }
  if (state < 1.5) {
    vec2 q = p.yx;
    q.x *= 0.94;
    q.y += sin(q.x * 1.8) * 0.045;
    return q;
  }
  if (state < 2.5) {
    p.x += sin(p.y * 2.2) * 0.055;
    p.y *= 0.93;
    return p;
  }
  float angle = 0.12;
  mat2 turn = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
  vec2 q = turn * p;
  q.y += sin(q.x * 2.6) * 0.044;
  return q;
}

void main() {
  vec2 uv = gl_FragCoord.xy / resolution.xy;
  uv.y = 1.0 - uv.y;

  float weightSum = 0.0;
  float regionalPhase = 0.0;
  float regionalDensity = 0.0;
  float regionalPresence = 0.0;
  float regionalStillness = 0.0;
  float regionalEvent = 0.0;
  for (int i = 0; i < 9; i++) {
    float id = float(i);
    vec4 a = macroRegion(id, layoutA);
    vec4 b = macroRegion(id, layoutB);
    vec4 region = mix(a, b, layoutMorph);
    float influence = softRegion(uv, region);
    float shiftedId = mod(id + layoutB * 2.0, 9.0);
    float priority = priorityBase(shiftedId);
    float localDensity = densityBase(shiftedId);
    float weight = influence * (0.24 + priority * 0.76);
    weightSum += weight;
    regionalPhase += weight * hash21(vec2(id * 3.7 + layoutB + variation * 0.71, 8.1));
    regionalDensity += weight * localDensity;
    regionalStillness += weight * hash21(vec2(id * 7.9, layoutB + 13.7));
    regionalEvent += weight * hash21(vec2(id * 11.3 + eventSeed * 0.17,
      variation * 3.1 + 19.7));
    regionalPresence = max(regionalPresence, influence * priority);
  }
  regionalPhase /= max(weightSum, 0.001);
  regionalDensity /= max(weightSum, 0.001);
  regionalStillness /= max(weightSum, 0.001);
  regionalEvent /= max(weightSum, 0.001);

  vec2 p = uv - 0.5;
  p.x *= resolution.x / resolution.y;
  vec2 pa = layoutCoordinate(p, layoutA);
  vec2 pb = layoutCoordinate(p, layoutB);
  p = mix(pa, pb, layoutMorph);
  p *= mix(0.96, 1.07, gather);

  // Each region receives a long activity window. Some areas almost stop while
  // neighbouring areas continue to dissolve, creating suspended motion rather
  // than one continuously boiling surface.
  float activityWave = 0.5 + 0.5 * sin(time * 0.23 +
    regionalPhase * 8.0 + regionalEvent * 5.7);
  float localActivity = smoothstep(0.48, 0.82, activityWave);
  float t = time * (0.15 + mid * 0.075) * mix(0.12, 0.58, regionalStillness) +
    sin(time * 0.17 + regionalEvent * 4.0) * localActivity * 0.16;
  float phaseTime = t + regionalPhase * 4.2 + variation * 0.37;
  float large = fbm(p * (0.92 + bass * 0.22) + vec2(t * 0.31, -t * 0.18));
  vec2 warp = vec2(
    fbm(p * 1.18 + vec2(large * 1.35, phaseTime * 0.12)),
    fbm(p * 1.13 + vec2(-phaseTime * 0.09, large * 1.48))
  );
  float surface = fbm(
    p * (1.04 + high * 0.52 + mod(variation, 3.0) * 0.035) +
    (warp - 0.5) * (1.18 + bass * 1.25 + impact * 0.28) +
    vec2(-t * 0.08, t * 0.05)
  );

  float air = valueNoise(
    uv * vec2(2.35, 1.45) + vec2(-t * 0.025, t * 0.018) +
    (warp - 0.5) * 0.18
  );
  float membraneValue = large * 0.49 + surface * 0.31 + air * 0.20;
  float threshold = 0.48 + (0.50 - regionalDensity) * 0.16 +
    (regionalPhase - 0.5) * 0.055 - density * 0.035 - impact * 0.018;

  float body = smoothstep(threshold - 0.115, threshold + 0.105, membraneValue);
  float sharpEdge = 1.0 - smoothstep(0.010, 0.035,
    abs(membraneValue - threshold));
  float softEdge = 1.0 - smoothstep(0.032, 0.145,
    abs(membraneValue - threshold));

  float fragmentScale = mix(0.78, 1.34, regionalEvent);
  float fragment = valueNoise(
    uv * vec2((8.2 + mod(variation, 3.0) * 1.5) * fragmentScale,
      (4.8 + mod(variation + 1.0, 3.0) * 0.9) / fragmentScale) +
    (warp - 0.5) * (0.72 + impact * 0.24) +
    vec2(t * 0.055, -t * 0.034) + vec2(regionalPhase * 2.6)
  );
  float dissolveThreshold = 0.43 + (0.52 - regionalDensity) * 0.17 - high * 0.025 +
    (regionalEvent - 0.5) * 0.075 - localActivity * impact * 0.025;
  float fragmentBody = smoothstep(dissolveThreshold - 0.10,
    dissolveThreshold + 0.12, fragment);
  float fragmentEdge = 1.0 - smoothstep(0.014, 0.092,
    abs(fragment - dissolveThreshold));

  float verticalAir = valueNoise(vec2(
    uv.x * 5.1 + warp.x * 0.44 + regionalPhase,
    uv.y * 0.72 - t * 0.030
  ));
  float verticalSmear = smoothstep(0.48, 0.82, verticalAir) * softEdge;
  float suspendedVapor = smoothstep(0.54, 0.84,
    valueNoise(vec2(uv.x * 2.8 + regionalEvent * 3.0,
      uv.y * 0.92 - t * 0.018))) * softEdge * (0.35 + localActivity * 0.65);

  float presence = smoothstep(0.08, 0.74, regionalPresence);
  float luma = body * fragmentBody * (0.13 + drive * 0.39 + regionalDensity * 0.19);
  luma += sharpEdge * (0.26 + drive * 0.22);
  luma += softEdge * (0.065 + mid * 0.075);
  luma += fragmentEdge * body * (0.045 + high * 0.090);
  luma += verticalSmear * (0.045 + mid * 0.065);
  luma += suspendedVapor * (0.030 + drive * 0.036);
  luma *= mix(0.86, 1.0, localActivity);
  luma *= mix(0.14, 1.0, presence);

  float pulseTexture = 0.5 + 0.5 * sin(surface * 7.2 + regionalPhase * 5.0);
  luma += body * fragmentBody * pulse * (0.024 + bass * 0.046) * pulseTexture;
  luma += softEdge * impact * (0.035 + high * 0.055);

  vec2 burstDelta = (uv - burstCenter) / vec2(0.15, 0.22);
  float burstCore = exp(-dot(burstDelta, burstDelta) * 2.1) * rareBurst;
  float burstTrail = exp(-abs(uv.x - burstCenter.x) * 34.0) *
    exp(-abs(uv.y - burstCenter.y) * 3.4) * rareBurst;
  luma += burstCore * 0.92 + burstTrail * 0.13;

  luma = clamp(luma * intensity, 0.0, 1.0);
  float grain = (hash21(gl_FragCoord.xy + vec2(floor(time * 3.0))) - 0.5) *
    (0.010 + high * 0.009);
  vec3 ink = vec3(0.980, 0.976, 0.965);
  vec3 color = ink * clamp(luma + grain, 0.0, 1.0);
  gl_FragColor = vec4(color, 1.0);
}
