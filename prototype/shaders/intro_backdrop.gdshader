shader_type canvas_item;
// Intro backdrop: dark imperial red with slow smoke, faint light rays behind the
// eagle and a vignette. Procedural, no textures; GL Compatibility friendly.

uniform vec2 focus = vec2(0.5, 0.4);
uniform float aspect = 1.7778;
uniform float rays = 1.0;
uniform float time_offset = 0.0;

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

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	float t = TIME + time_offset;
	vec2 uv = UV;
	vec2 d = (uv - focus) * vec2(aspect, 1.0);
	float r = length(d);
	vec3 core = vec3(0.30, 0.075, 0.05);
	vec3 edge = vec3(0.018, 0.010, 0.008);
	vec3 color = mix(core, edge, smoothstep(0.0, 0.95, r));
	float smoke = fbm(uv * vec2(aspect, 1.0) * 2.4 + vec2(t * 0.025, -t * 0.04));
	color += vec3(0.10, 0.035, 0.02) * (smoke - 0.45) * 1.4;
	float angle = atan(d.y, d.x);
	float beam = pow(max(0.0, sin(angle * 9.0 + t * 0.08)), 6.0) * smoothstep(0.85, 0.05, r);
	color += vec3(0.42, 0.24, 0.08) * beam * 0.16 * rays;
	color *= 1.0 - smoothstep(0.55, 1.25, length((uv - 0.5) * vec2(aspect * 0.8, 1.15)));
	COLOR = vec4(color, 1.0);
}
