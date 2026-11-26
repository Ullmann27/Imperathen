shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A torch or lamp flame: a camera-facing card with a procedural, flickering
// teardrop. One MultiMesh carries all flames; each gets its own phase from its
// position. `lit` fades all flames in at dusk and out at dawn.
uniform vec3 core_color : source_color = vec3(1.0, .86, .55);
uniform vec3 edge_color : source_color = vec3(1.0, .42, .10);
uniform float lit = 0.0;
uniform float brightness = 2.4;
uniform float fixed_time = -1.0;
varying float phase;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	phase = fract(origin.x * .37 + origin.z * .71) * 6.2832;
	// Billboard around the vertical axis; the card keeps its authored size.
	vec3 to_eye = normalize(vec3(CAMERA_POSITION_WORLD.x - origin.x, 0.0, CAMERA_POSITION_WORLD.z - origin.z) + vec3(0.0, 0.0, .0001));
	vec3 right = vec3(to_eye.z, 0.0, -to_eye.x);
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	vec3 world = origin + right * VERTEX.x * size.x + vec3(0.0, 1.0, 0.0) * VERTEX.y * size.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float t = (fixed_time >= 0.0 ? fixed_time : TIME) * 7.0 + phase;
	// UV.y runs 0 (top) to 1 (bottom); the flame leans and stretches in time.
	float up = 1.0 - UV.y;
	float sway = (sin(t + up * 4.0) * .5 + sin(t * 2.3 + up * 7.0) * .3) * .09 * up;
	float x = (UV.x - .5 - sway) * 2.0;
	float width = mix(.62, .0, pow(up, 1.35)) * (.92 + .08 * sin(t * 3.1));
	float body = 1.0 - smoothstep(width * .35, width, abs(x));
	body *= smoothstep(0.0, .12, up) * (1.0 - smoothstep(.82 + .08 * sin(t * 1.7), 1.0, up));
	float core = body * (1.0 - smoothstep(.0, .55, up)) * (1.0 - smoothstep(.0, width * .6 + .001, abs(x)));
	ALBEDO = mix(edge_color, core_color, clamp(core * 1.6 + body * .25, 0.0, 1.0)) * brightness;
	ALPHA = clamp(body * lit, 0.0, 1.0);
}
