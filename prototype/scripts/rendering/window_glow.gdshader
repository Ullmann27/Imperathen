shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
// Warm firelight seen through a door or window at night: a card just inside
// the opening, brighter low down (hearth) and soft at the frame.
uniform vec3 glow_color : source_color = vec3(1.0, .62, .30);
uniform float strength = 0.0;

void fragment() {
	float frame = smoothstep(0.0, .18, UV.x) * smoothstep(1.0, .82, UV.x) * smoothstep(0.0, .12, UV.y) * smoothstep(1.0, .9, UV.y);
	float hearth = mix(1.0, .45, UV.y);
	ALBEDO = glow_color * (.6 + .6 * hearth);
	ALPHA = clamp(strength * frame * hearth, 0.0, 1.0);
}
