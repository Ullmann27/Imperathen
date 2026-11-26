shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A sunbeam through a window or door: an additive prism along the sun
// direction. UV.x runs across a face (soft edges), UV.y along the beam.
// Stands in for volumetric light, which the Compatibility renderer lacks.
uniform vec3 beam_color : source_color = vec3(1.0, .86, .66);
uniform float strength = .16;
uniform float fixed_time = -1.0;

void fragment() {
	float t = fixed_time >= 0.0 ? fixed_time : TIME;
	float along = UV.y;
	float edge = sin(3.14159 * clamp(UV.x, 0.0, 1.0));
	// Faces seen edge-on stack up; weight by how squarely they face the eye.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float dust = .85 + .15 * sin(t * .7 + UV.x * 9.0 + UV.y * 5.0);
	float fade = pow(1.0 - along, 1.6) * smoothstep(0.0, .06, along);
	ALBEDO = beam_color;
	ALPHA = clamp(strength * edge * edge * fade * facing * dust, 0.0, 1.0);
}
