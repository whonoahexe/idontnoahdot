#version 440
// City Night Street, re-rendered from its Wallpaper Engine scene (workshop 2515923492).
// Effects are ported from the scene's own shaders with its own values; the particle
// systems are re-implemented procedurally from their emitter/initializer settings.
// All particle maths happens in Wallpaper Engine scene space: 3840x2160, y up.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 crop; // the part of the scene on screen, in scene UV (y down): x, y, w, h
};

layout(binding = 1) uniform sampler2D baseTex;
layout(binding = 2) uniform sampler2D foliageMask;
layout(binding = 3) uniform sampler2D pulseMask;
layout(binding = 4) uniform sampler2D noiseTex;
layout(binding = 5) uniform sampler2D haloTex;
layout(binding = 6) uniform sampler2D glowTex;

const vec2 SCENE = vec2(3840.0, 2160.0);
const float PI = 3.14159265;
const float TAU = 6.28318531;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 rotateVec2(vec2 v, float r) {
    vec2 cs = vec2(cos(r), sin(r));
    return vec2(v.x * cs.x - v.y * cs.y, v.x * cs.y + v.y * cs.x);
}

// Additive sprite: texture colour weighted by its alpha, centred on c, size in scene units
vec3 sprite(sampler2D tex, vec2 p, vec2 c, vec2 size) {
    vec2 q = (p - c) / size + 0.5;
    if (q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0) return vec3(0.0);
    vec4 t = texture(tex, vec2(q.x, 1.0 - q.y));
    return t.rgb * t.a;
}

// WE "alphafade": linear fade in until fadeIn of life, fade out after fadeOut of life
float alphaFade(float age, float fadeIn, float fadeOut) {
    float a = 1.0;
    if (age < fadeIn) a = age / fadeIn;
    if (age > fadeOut) a = min(a, (1.0 - age) / (1.0 - fadeOut));
    return clamp(a, 0.0, 1.0);
}

// ---- pulse effect (lamp light cone): BLENDMODE 9 = mix(A, BlendAdd(A, B), pulse), tints white
vec3 pulsed(vec2 uv, float pulse) {
    vec3 c = texture(baseTex, uv).rgb;
    vec3 lit = mix(c, min(c + c, vec3(1.0)), pulse);
    return mix(c, lit, texture(pulseMask, uv).r);
}

// ---- "Blinking Stars": boxrandom emitter 1000x500 (half extents), rate 40, life 4-8 s,
// size 5-10, alphafade 0.1/0.9, oscillatealpha up to 3, min scale 0.2
vec3 stars(vec2 p, vec2 origin, vec2 scale, float countMul, float sizeMul) {
    vec2 halfExt = vec2(1000.0, 500.0) * scale;
    vec2 rel = p - origin;
    float margin = 10.0 * sizeMul * scale.x;
    if (abs(rel.x) > halfExt.x + margin || abs(rel.y) > halfExt.y + margin) return vec3(0.0);

    float alive = 40.0 * countMul * 6.0;
    float cell = sqrt(4.0 * halfExt.x * halfExt.y / alive);
    vec2 g = floor((rel + halfExt) / cell);
    vec3 acc = vec3(0.0);
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            vec2 id = g + vec2(float(dx), float(dy));
            vec2 cellMin = id * cell - halfExt;
            if (any(lessThan(id, vec2(0.0))) || cellMin.x >= halfExt.x || cellMin.y >= halfExt.y) continue;
            vec2 seed = id + origin * 0.0137;
            float life = mix(4.0, 8.0, hash12(seed));
            float tt = time / life + hash12(seed + 7.1);
            float k = floor(tt);
            float age = tt - k;
            vec2 pos = min(cellMin + hash22(seed + k * 1.618) * cell, halfExt);
            float size = mix(5.0, 10.0, hash12(seed + k + 1.3)) * sizeMul * scale.x;
            float freq = 3.0 * hash12(seed + k + 3.3);
            float a = alphaFade(age, 0.1, 0.9)
                * mix(0.2, 1.0, 0.5 + 0.5 * sin(time * freq + hash12(seed + 5.5) * TAU));
            acc += sprite(haloTex, rel, pos, vec2(size)) * a;
        }
    }
    return acc;
}

// ---- "floating": sphere emitter 32-512, rate 3, life 3-5, size 50-200, velocity +-50,
// default alphafade; instance overrides count 0.8, lifetime 1.5, speed 0.9; object scale 0.33
vec3 floating(vec2 p) {
    const vec2 origin = vec2(2011.51587, 1516.46814);
    const float sc = 0.33;
    vec2 rel = p - origin;
    if (length(rel) > (512.0 + 100.0 + 45.0 * 7.5) * sc) return vec3(0.0);

    const int SLOTS = 16;
    float period = float(SLOTS) / (3.0 * 0.8);
    vec3 acc = vec3(0.0);
    for (int i = 0; i < SLOTS; i++) {
        float fi = float(i);
        float life = mix(3.0, 5.0, hash12(vec2(fi, 1.7))) * 1.5;
        float slotPeriod = max(period, life);
        float tt = time / slotPeriod + fi / float(SLOTS);
        float k = floor(tt);
        float secs = (tt - k) * slotPeriod;
        if (secs > life) continue;
        vec2 r = hash22(vec2(fi, k + 0.5));
        vec2 spawn = vec2(cos(r.x * TAU), sin(r.x * TAU)) * mix(32.0, 512.0, r.y) * sc;
        vec2 vel = (hash22(vec2(k, fi + 9.1)) * 100.0 - 50.0) * 0.9 * sc;
        float size = mix(50.0, 200.0, hash12(vec2(fi + 4.4, k))) * sc;
        acc += sprite(haloTex, rel, spawn + vel * secs, vec2(size)) * alphaFade(secs / life, 0.5, 0.5);
    }
    return acc;
}

// ---- "Shooting star": sphere emitter at (-256, 256) radius 256, rate 0.2, life 3, size 2-5,
// velocity x 100-250, gravity -40, drag 0.1, rope trail, glow child (halo_4, 100-150, alpha 0.5-0.6)
vec2 starPath(vec2 p0, float vx, float t) {
    const float drag = 0.1;
    const float grav = -40.0;
    float e = (1.0 - exp(-drag * t)) / drag;
    return p0 + vec2(vx * e, grav / drag * t - grav / drag * e);
}

vec3 shootingStar(vec2 p, vec2 origin, float angle, vec2 scale, float countMul, float lifeMul, float seed) {
    float life = 3.0 * lifeMul;
    float period = 1.0 / (0.2 * countMul);
    float tt = (time + 9.0) / period;
    float k = floor(tt);
    float t = (tt - k) * period;
    if (t > life) return vec3(0.0);

    vec2 r = hash22(vec2(k, seed));
    vec2 p0 = vec2(-256.0, 256.0) + vec2(cos(r.x * TAU), sin(r.x * TAU)) * 256.0 * r.y;
    float vx = mix(100.0, 250.0, hash12(vec2(k, seed + 2.0)));
    float size = mix(2.0, 5.0, hash12(vec2(k, seed + 3.0))) * scale.x;

    // into object-local, unrotated and unscaled space
    vec2 q = rotateVec2(p - origin, -angle) / scale;
    vec2 head = starPath(p0, vx, t);
    if (length(q - head) > 400.0) return vec3(0.0);

    float fade = alphaFade(t / life, 0.5, 0.5);
    float trailSecs = min(t, 0.4 * life);
    float best = 0.0;
    vec2 a = head;
    for (int j = 1; j <= 7; j++) {
        float u0 = float(j - 1) / 7.0;
        float u1 = float(j) / 7.0;
        vec2 b = starPath(p0, vx, t - u1 * trailSecs);
        vec2 ab = b - a;
        float h = clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
        float d = length((q - a - ab * h) * scale);
        float u = mix(u0, u1, h);
        float w = size * (1.0 - u);
        best = max(best, (1.0 - u) * smoothstep(w, 0.0, d));
        a = b;
    }
    vec3 trail = vec3(best);

    float glowSize = mix(100.0, 150.0, hash12(vec2(k, seed + 4.0)));
    float glowAlpha = mix(0.5, 0.6, hash12(vec2(k, seed + 5.0)));
    vec3 glow = sprite(glowTex, q * scale, head * scale, vec2(glowSize) * scale) * glowAlpha;
    return (trail + glow) * fade;
}

void main() {
    vec2 uv = crop.xy + qt_TexCoord0 * crop.zw;

    // pulse (applied first in the scene's effect chain)
    float noise = texture(noiseTex, fract(vec2(time * 0.08333333, time * 0.02777777) * 0.55)).r * 0.2;
    float pulse = pow(0.05 + noise, 1.75);

    // foliage sway, UV mode: speeduv 2, power 0.75, phase 0.5, scale 0.4, ratio 2, direction 0.349, strength 0.25
    const float speed = 2.0;
    const float power = 0.75;
    const float phaseMul = 0.5;
    const float noiseScale = 0.4;
    const float ratio = 2.0;
    const float direction = 0.34906584;
    const float strength = 0.25;
    float aspect = SCENE.x / SCENE.y * ratio;
    vec2 noiseDir = rotateVec2(vec2(1.0 / aspect, aspect), direction);
    vec2 params = rotateVec2(uv, direction);
    float amp = strength * strength * 0.005 * texture(foliageMask, uv).r;
    float n = texture(noiseTex, uv * noiseScale).g;
    float phase = (n * PI * 2.0 + params.x * 10.0 + params.y * 5.0) * phaseMul;
    vec4 sines = sin(phase + speed * time * vec4(1.0, -0.16161616, 0.0083333, -0.00019841));
    vec4 csines = sin(0.4 + phase + speed * time * vec4(-0.5, 0.041666666, -0.0013888889, 0.000024801587));
    sines = pow(abs(sines), vec4(power)) * sign(sines);
    csines = pow(abs(csines), vec4(power)) * sign(csines);
    vec2 offset = vec2(noiseDir.x * dot(sines, vec4(amp)), noiseDir.y * dot(csines, vec4(amp)));

    vec3 col = pulsed(uv + offset, pulse);

    // particles, in scene space with y up
    vec2 p = vec2(uv.x, 1.0 - uv.y) * SCENE;
    col += stars(p, vec2(2641.90015, 1937.35876), vec2(0.71222, 0.43507), 1.5, 2.4);
    col += stars(p, vec2(2399.63086, 1548.11609), vec2(0.45300, 0.34289), 1.5, 2.5);
    col += stars(p, vec2(1373.00989, 1920.05774), vec2(0.23556, 0.50902), 1.5, 1.98);
    col += floating(p);
    col += shootingStar(p, vec2(2249.38403, 1614.74194), 0.02142, vec2(1.30893), 1.0, 1.0, 11.0);
    col += shootingStar(p, vec2(2896.27246, 1794.93579), -3.12462, vec2(1.0, 0.84383), 1.2, 0.8, 23.0);

    fragColor = vec4(min(col, vec3(1.0)), 1.0) * qt_Opacity;
}
