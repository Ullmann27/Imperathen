shader_type canvas_item;
// Additive torch flame: a flickering teardrop of noise, white-yellow core to red tips.
render_mode blend_add;

uniform float clock = -1.0;
uniform float seed = 0.0;
uniform float intensity = 1.0;

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

void fragment() {
	float t = (clock < 0.0 ? TIME : clock) + seed * 7.0;
	vec2 uv = UV;
	float y = 1.0 - uv.y;
	float n = noise(vec2(uv.x * 5.0 + seed, uv.y * 4.0 + t * 3.2)) * 0.6
		+ noise(vec2(uv.x * 11.0 - seed, uv.y * 9.0 + t * 5.1)) * 0.4;
	float x = (uv.x - 0.5) + (n - 0.5) * 0.28 * y;
	float width = 0.34 * pow(max(0.0, 1.0 - y), 0.55) * smoothstep(0.0, 0.12, y + 0.05);
	float shape = smoothstep(width, width * 0.25, abs(x)) * smoothstep(1.0, 0.55, y + (n - 0.5) * 0.35);
	vec3 hot = vec3(1.0, 0.95, 0.75);
	vec3 warm = vec3(1.0, 0.55, 0.12);
	vec3 tip = vec3(0.75, 0.12, 0.03);
	vec3 col = mix(hot, warm, smoothstep(0.05, 0.4, y + abs(x) * 1.5));
	col = mix(col, tip, smoothstep(0.35, 0.85, y));
	float flicker = 0.85 + 0.15 * sin(t * 13.0 + seed) * sin(t * 7.3);
	COLOR = vec4(col * shape * intensity * flicker, 1.0);
}
