shader_type spatial;
// Lamp, candle and hearth flames of the furnished interiors: one merged mesh
// per room. UV.y runs up the flame, UV2 = (phase, flame height in metres).
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

instance uniform float vigor = 1.0;

void vertex() {
	float h = UV.y;
	float phase = UV2.x;
	float size = UV2.y;
	float sway = h * h * size;
	VERTEX.x += (sin(TIME * 9.1 + phase) * 0.10 + sin(TIME * 17.3 + phase * 2.3) * 0.05) * sway;
	VERTEX.z += (cos(TIME * 7.7 + phase * 1.7) * 0.10 + sin(TIME * 21.1 + phase) * 0.04) * sway;
	VERTEX.y += (sin(TIME * 12.7 + phase * 3.1) * 0.08 + (vigor - 1.0) * 0.45) * h * size;
}

void fragment() {
	float h = UV.y;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	vec3 hot = mix(vec3(1.0, 0.86, 0.50), vec3(1.0, 0.42, 0.08), smoothstep(0.25, 0.95, h));
	hot = mix(vec3(0.25, 0.35, 0.90), hot, smoothstep(0.0, 0.16, h));
	float body = pow(facing, 1.4) * (1.0 - smoothstep(0.6, 1.0, h));
	ALBEDO = hot * body * 1.6 * mix(1.0, vigor, 0.5);
}
