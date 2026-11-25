shader_type spatial;
render_mode world_vertex_coords, diffuse_burley, cull_back;

// Original procedural soil/material study for the independent world workshop.
// No modern asphalt, no downloaded image and no baked terrain lighting.
// The vertex albedo is preserved as the large-scale terrain palette.
uniform float detail_strength : hint_range(0.0, 1.0) = 0.58;
varying vec3 terrain_world_xyz;

float _hash2(vec2 xy) {
	return fract(sin(dot(xy, vec2(127.1, 311.7))) * 43758.5453);
}

float _noise2(vec2 xy) {
	vec2 cell = floor(xy);
	vec2 uv = fract(xy);
	uv = uv * uv * (3.0 - 2.0 * uv);
	float a = _hash2(cell);
	float b = _hash2(cell + vec2(1.0, 0.0));
	float c = _hash2(cell + vec2(0.0, 1.0));
	float d = _hash2(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, uv.x), mix(c, d, uv.x), uv.y);
}

void vertex() {
	// world_vertex_coords makes this the world-space position.
	terrain_world_xyz = VERTEX;
}

void fragment() {
	// In the low profile, skip all procedural noise and fragment trig.
	if (detail_strength <= 0.001) {
		ALBEDO = COLOR.rgb;
	} else {
		vec2 world = terrain_world_xyz.xz;
		float broad = _noise2(world * 0.047);
		float patches = _noise2(world * 0.23 + vec2(12.7, -8.2));
		float pebbles = _noise2(world * 3.2);
		float dry = smoothstep(0.33, 0.78, broad * 0.63 + patches * 0.37);
		vec3 hard_soil = vec3(0.205, 0.172, 0.111);
		vec3 sparse_grass = vec3(0.206, 0.235, 0.132);
		vec3 local_earth = mix(hard_soil, sparse_grass, dry);
		vec3 base = mix(COLOR.rgb, local_earth, 0.57);
		vec3 detail = base * (0.88 + broad * 0.22) * (0.91 + pebbles * 0.17);
		ALBEDO = mix(COLOR.rgb, detail, detail_strength);
	}
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
	SPECULAR = 0.18;
}
