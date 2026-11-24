shader_type canvas_item;
// Polished gold/bronze for the title and the aquila: a vertical metal ramp with a
// bright horizon line, plus a travelling specular sweep. Dark parts of the item
// (outline, drop shadow) keep their own colour.

uniform vec2 extent = vec2(100.0, 100.0);
uniform float ramp = 1.0;
uniform float sheen = -2.0;
uniform float sheen_width = 0.09;
uniform float sheen_strength = 1.0;
uniform float heat = 0.0;
// Vertical span of the letters (or emblem) inside the item, as fractions.
uniform vec2 band = vec2(0.0, 1.0);
// Repeating sweep for menus: one pass every auto_period seconds (0 = off).
uniform float auto_period = 0.0;
uniform float auto_offset = 0.0;
varying vec2 local_uv;

void vertex() {
	local_uv = VERTEX / max(extent, vec2(1.0));
}

vec3 metal(float y) {
	vec3 top = vec3(1.0, 0.95, 0.78);
	vec3 upper = vec3(0.96, 0.78, 0.40);
	vec3 horizon = vec3(1.0, 0.93, 0.70);
	vec3 lower = vec3(0.62, 0.38, 0.13);
	vec3 bottom = vec3(0.86, 0.60, 0.27);
	vec3 c = mix(top, upper, smoothstep(0.0, 0.46, y));
	c = mix(c, horizon, smoothstep(0.44, 0.52, y) * (1.0 - smoothstep(0.52, 0.58, y)));
	c = mix(c, lower, smoothstep(0.54, 0.74, y));
	return mix(c, bottom, smoothstep(0.78, 1.0, y));
}

void fragment() {
	vec4 base = COLOR;
	float lit = smoothstep(0.32, 0.62, max(base.r, base.g));
	vec3 col = base.rgb;
	if (ramp > 0.0) {
		vec3 m = metal(clamp((local_uv.y - band.x) / max(0.01, band.y - band.x), 0.0, 1.0)) * mix(1.0, (base.r + base.g) * 0.62, 0.35);
		col = mix(col, m, lit * ramp);
	}
	float pos = sheen;
	if (auto_period > 0.0) {
		float ph = mod(TIME + auto_offset, auto_period);
		pos = ph < 1.4 ? mix(-0.3, 1.3, ph / 1.4) : -2.0;
	}
	float diag = local_uv.x + (local_uv.y - 0.5) * 0.35;
	float glint = exp(-pow((diag - pos) / sheen_width, 2.0));
	float core = exp(-pow((diag - pos) / (sheen_width * 0.25), 2.0));
	col += vec3(1.0, 0.92, 0.75) * (glint * 0.55 + core * 0.6) * sheen_strength * lit;
	col += vec3(1.0, 0.55, 0.22) * heat * lit;
	COLOR = vec4(col, base.a);
}
