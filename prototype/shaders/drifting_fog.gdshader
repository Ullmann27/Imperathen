shader_type canvas_item;
// Low drifting smoke/fog band for depth between parallax layers.

uniform vec4 tint : source_color = vec4(0.32, 0.12, 0.08, 1.0);
uniform float density = 0.6;
uniform float clock = -1.0;
uniform float speed = 1.0;
uniform float scale = 1.0;
uniform float aspect = 3.0;
uniform float top_fade = 0.0;
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

void fragment() {
	float t = (clock < 0.0 ? TIME : clock) * speed;
	vec2 p = UV * vec2(aspect, 1.0) * 2.0 * scale;
	float v = 0.0;
	float a = 0.5;
	vec2 q = p + vec2(t * 0.08, 0.0);
	int octaves = detail >= 2 ? 4 : (detail == 1 ? 3 : 2);
	for (int i = 0; i < 4; i++) {
		if (i >= octaves) {
			break;
		}
		v += a * noise(q);
		q = q * 2.1 + vec2(-t * 0.05, t * 0.02);
		a *= 0.5;
	}
	float vertical = smoothstep(0.0, max(0.001, top_fade), UV.y) * smoothstep(1.0, 0.82, UV.y);
	float alpha = smoothstep(0.32, 0.85, v) * density * vertical;
	COLOR = vec4(tint.rgb * (0.8 + v * 0.5), alpha * COLOR.a);
}
