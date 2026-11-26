shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;
// Brook water over the sunk bed (brook.gd): clear in the shallows so pebbles
// and silt show, darker with depth, sky on the surface at flat angles, two
// ripple layers drifting downstream. UV.x = -1..1 bank to bank, COLOR.r = depth.
uniform sampler2D ripple : repeat_enable, filter_linear_mipmap;
uniform float fixed_time = -1.0;
uniform float wetness = 0.0;
uniform float detail = 1.0;
uniform vec3 deep_color : source_color = vec3(0.035, 0.085, 0.075);
uniform vec3 shallow_color : source_color = vec3(0.17, 0.22, 0.15);
uniform vec3 sky_horizon : source_color = vec3(0.57, 0.72, 0.78);
uniform vec3 sky_zenith : source_color = vec3(0.21, 0.46, 0.67);
varying vec2 water_xz;

void vertex() {
	water_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float t = fixed_time >= 0.0 ? fixed_time : TIME;
	vec2 p = water_xz;
	float depth = COLOR.r;
	float edge = 1.0 - abs(UV.x);
	// The brook runs south (+z); rain makes it faster and rougher.
	float run = t * (.34 + .22 * wetness);
	vec2 broad = texture(ripple, vec2(p.x * .19, p.y * .11 - run * .11)).rg * 2.0 - 1.0;
	vec2 fine = texture(ripple, vec2(p.x * .53 + .37, p.y * .34 - run * .52) + broad * .015).rg * 2.0 - 1.0;
	// Slack water at the banks, livelier over the deep middle.
	vec2 slope = (broad * .55 + fine * .5 * detail) * mix(.3, 1.0, smoothstep(0.0, .6, depth)) * (1.0 + .4 * wetness);
	NORMAL_MAP = vec3(slope * .5 + .5, 1.0);
	NORMAL_MAP_DEPTH = .6;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float mirror = .04 + .96 * pow(1.0 - facing, 5.0);
	vec3 body = mix(shallow_color, deep_color, smoothstep(0.0, .85, depth));
	ALBEDO = body * (1.0 - mirror);
	// Reflected sky does not depend on the sun's diffuse light.
	EMISSION = mix(sky_zenith, sky_horizon, smoothstep(.0, .75, 1.0 - facing)) * mirror * (.78 + .5 * (broad.y + fine.y * detail) * (1.0 - facing));
	// A lapping line where the water meets the bank.
	float lap = (1.0 - smoothstep(0.0, .07, edge)) * (.5 + .5 * sin(p.y * 2.6 + broad.x * 5.0 + t * 1.3));
	ALBEDO += vec3(.07) * lap;
	float cover = max(mix(.34, .93, smoothstep(0.0, .8, depth)), mirror);
	ALPHA = cover * smoothstep(0.0, .03, edge);
	ROUGHNESS = .07 + wetness * .07;
	SPECULAR = .7;
}
