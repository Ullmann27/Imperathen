shader_type canvas_item;
// Title-sequence sky: crimson storm light behind the aquila, slow smoke, volumetric
// light shafts (god rays) from the eagle, an impact flash and a vignette.
// Procedural, no textures; GL Compatibility friendly. "clock" drives it from the
// sequence timeline so movie recordings and tests are deterministic.

uniform vec2 focus = vec2(0.5, 0.4);
uniform float aspect = 1.7778;
uniform float rays = 1.0;
uniform float glow = 1.0;
uniform float flash = 0.0;
uniform float clock = 0.0;
uniform int detail = 2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		if (octave >= octaves) {
			break;
		}
		value += amplitude * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	float t = clock;
	vec2 uv = UV;
	// Distances relative to the shorter screen side so portrait phones get the
	// same glow size as landscape screens.
	vec2 d = (uv - focus) * vec2(aspect, 1.0) / min(aspect, 1.0);
	float r = length(d);
	vec3 core = vec3(0.42, 0.10, 0.05);
	vec3 mid = vec3(0.13, 0.025, 0.02);
	vec3 edge = vec3(0.012, 0.007, 0.006);
	vec3 color = mix(core, mid, smoothstep(0.0, 0.45, r));
	color = mix(color, edge, smoothstep(0.35, 1.1, r));
	color *= mix(0.35, 1.0, glow);
	int octaves = detail >= 2 ? 5 : (detail == 1 ? 4 : 3);
	vec2 sp = uv * vec2(aspect, 1.0);
	float smoke = fbm(sp * 2.2 + vec2(t * 0.035, -t * 0.05), octaves);
	float billow = fbm(sp * 1.1 - vec2(t * 0.02, t * 0.012), octaves - 1);
	color += vec3(0.16, 0.05, 0.03) * (smoke - 0.42) * 1.6 * (0.5 + glow * 0.5);
	color += vec3(0.07, 0.02, 0.015) * smoothstep(0.45, 0.8, billow);
	// Light shafts: soft angular noise from the focus (not a regular starburst),
	// broken up by the smoke so they read as volumetric beams.
	float angle = atan(d.y, d.x);
	float a1 = noise(vec2(angle * 7.0 + 31.0, t * 0.12));
	float a2 = noise(vec2(angle * 19.0 - 7.0, t * 0.2 + 4.0));
	float band = pow(a1, 3.0) * 0.9 + pow(a2, 6.0) * 0.6;
	float shaft = band * smoothstep(1.1, 0.06, r) * (0.45 + 1.0 * smoke);
	color += vec3(1.0, 0.6, 0.25) * shaft * 0.55 * rays;
	color += vec3(1.0, 0.72, 0.38) * exp(-r * r * 7.0) * 0.36 * rays;
	color = mix(color, vec3(1.0, 0.9, 0.75), flash * 0.75);
	color *= 1.0 - smoothstep(0.5, 1.3, length((uv - vec2(0.5, 0.46)) * vec2(aspect * 0.78, 1.18)));
	COLOR = vec4(color, 1.0);
}
