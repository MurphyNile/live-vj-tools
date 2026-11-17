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
  for (int i = 0; i < 5; i++) {
    value += amplitude * valueNoise(p);
    p = rotation * p * 2.02 + vec2(7.1, 11.7);
    amplitude *= 0.49;
  }
  return value;
}

vec2 layoutCoordinate(vec2 p, float state) {
  if (state < 0.5) {
    p.x *= 0.78;
    p.y *= 1.08;
    return p;
  }
  if (state < 1.5) {
    vec2 q = p.yx;
    q.x *= 0.90;
    q.y += sin(q.x * 2.2) * 0.085;
    return q;
  }
  if (state < 2.5) {
    p.x += sin(p.y * 2.7) * 0.105;
    p.y *= 0.90;
    return p;
  }
  float angle = 0.24;
  mat2 turn = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
  vec2 q = turn * p;
  q.y += sin(q.x * 3.1) * 0.080;
  q.x += sin(q.y * 2.4) * 0.055;
  return q;
}

void main() {
  vec2 uv = gl_FragCoord.xy / resolution.xy;
  uv.y = 1.0 - uv.y;
  vec2 p = uv - 0.5;
  p.x *= resolution.x / resolution.y;

  vec2 pa = layoutCoordinate(p, layoutA);
  vec2 pb = layoutCoordinate(p, layoutB);
  p = mix(pa, pb, layoutMorph);

  // Keep the large field calm. Gather and pulse reorganise it without the
  // previous extreme compression that could collapse the image to black.
  float scale = mix(0.90, 1.12, gather);
  p *= scale * (1.0 - pulse * 0.030);
  float t = time * (0.28 + mid * 0.22);

  float large = fbm(p * (0.82 + bass * 0.34) + vec2(t, -t * 0.46));
  vec2 warp = vec2(
    fbm(p * 1.42 + vec2(large * 1.7, t * 0.58)),
    fbm(p * 1.34 + vec2(-t * 0.39, large * 1.9))
  );
  float field = fbm(
    p * (1.18 + high * 1.18) +
    (warp - 0.5) * (1.52 + bass * 2.15) +
    vec2(-t * 0.29, t * 0.21)
  );

  // A broad organic field replaces every geometric panel mask. The transition
  // range is deliberately wide, creating a soft feather rather than a hard cut.
  float macroNoise = valueNoise(
    uv * vec2(2.15, 1.62) + vec2(-t * 0.060, t * 0.045) +
    (warp - 0.5) * 0.24
  );
  float organicBase = large * 0.60 + macroNoise * 0.40 +
    (warp.x - 0.5) * 0.11;
  float organicMask = smoothstep(
    0.35 - density * 0.055,
    0.67 + gather * 0.025,
    organicBase
  );
  float organicEdge = 1.0 - smoothstep(0.024, 0.105,
    abs(organicBase - (0.50 - density * 0.018)));

  // Smaller fragments move independently inside the soft field. They remain
  // irregular but are eased by broad smoothstep ranges.
  float fragmentNoise = valueNoise(
    uv * vec2(9.2, 6.7) + vec2(t * 0.18, -t * 0.13) +
    (warp - 0.5) * 0.62
  ) * 0.58 + field * 0.27 + large * 0.15;
  float fragmentMask = smoothstep(
    0.37 - high * 0.055,
    0.64 + (1.0 - density) * 0.025,
    fragmentNoise
  );
  float fragmentEdge = 1.0 - smoothstep(0.018, 0.072,
    abs(fragmentNoise - (0.50 - high * 0.020)));

  // Domain-warped phase bands create a marbled flow instead of ordinary noise.
  float marblePhase = field * (10.0 + density * 5.0) +
    large * 4.8 + warp.x * 3.1 + p.x * 1.7 - t * 0.88;
  float marble = 0.5 + 0.5 * sin(marblePhase);
  float marbleBody = smoothstep(0.42 - bass * 0.045, 0.70, marble);
  float marbleThread = 1.0 - smoothstep(0.026, 0.115 + high * 0.025,
    abs(marble - 0.5));

  float fineDistance = abs(fract((field + large * 0.16) *
    (6.0 + density * 7.0 + high * 10.0)) - 0.5);
  float fineContour = 1.0 - smoothstep(0.022, 0.062, fineDistance);

  float luma = marbleBody * (0.24 + drive * 0.56);
  luma += marbleThread * (0.14 + mid * 0.22);
  luma += fineContour * high * density * 0.13;
  luma *= mix(0.09, 1.0, organicMask);
  luma *= mix(0.12, 1.0, fragmentMask);
  luma += organicEdge * (0.035 + drive * 0.048);
  luma += fragmentEdge * organicMask * (0.040 + high * 0.075);
  luma += organicMask * (0.012 + drive * 0.014);

  float pulseTexture = 0.5 + 0.5 * sin(marblePhase * 0.72 + t * 1.25);
  luma += organicMask * fragmentMask * pulse *
    (0.030 + bass * 0.052) * pulseTexture;
  luma = clamp(luma * intensity, 0.0, 1.0);

  float grain = (hash21(gl_FragCoord.xy) - 0.5) * (0.007 + high * 0.010);
  vec3 ink = vec3(0.980, 0.976, 0.965);
  vec3 color = ink * clamp(luma + grain, 0.0, 1.0);
  gl_FragColor = vec4(color, 1.0);
}
