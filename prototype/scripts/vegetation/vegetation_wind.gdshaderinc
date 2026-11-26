// Shared wind for the Valdora vegetation (trees, shrubs, vines, herb cards).
// Three layers after the Crysis vegetation model (GPU Gems 3, ch. 16):
//   trunk sway     whole plant bends with the gust, length preserved,
//                  weighted by (height / plant height)^2
//   branch bend    vertical bob and lean of each branch: vertex COLOR.r is the
//                  bend weight (0 trunk .. 1 twig tip), COLOR.g the branch phase
//   leaf flicker   fast flutter of card tips along the normal: COLOR.b
// Per-instance variation from INSTANCE_CUSTOM: x phase offset, y stiffness.
// Every term is a handful of ALU ops per vertex; wind_detail drops the
// branch (0) or leaf (1) layers on the lighter profiles.

uniform float wind_time = -1.0;
uniform vec2 wind_direction = vec2(0.83, 0.56);
uniform float wind_strength = 1.0;
uniform float plant_height = 10.0;
uniform float trunk_sway = 0.022;
uniform float branch_amplitude = 0.11;
uniform float leaf_amplitude = 0.045;
uniform int wind_detail = 2;

float vegetation_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vegetation_value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(vegetation_hash(i), vegetation_hash(i + vec2(1.0, 0.0)), f.x),
		mix(vegetation_hash(i + vec2(0.0, 1.0)), vegetation_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Coherent gust field, 0 calm .. 1 full gust: two octaves of value noise
// carried downwind (large fronts about 30 m across at 4.5 m/s, smaller
// eddies at 7 m/s). Every plant samples the same field at its position, so
// gusts visibly run across meadows, crops and crowns instead of a uniform
// sway (the scrolling 2D wind noise of the Ghost of Tsushima grass).
float vegetation_gust(vec2 xz, float t) {
	float broad = vegetation_value_noise((xz - wind_direction * t * 4.5) * 0.034);
	float eddy = vegetation_value_noise((xz - wind_direction * t * 7.0) * 0.11 + vec2(17.3, 5.1));
	return smoothstep(0.22, 0.86, broad * 0.72 + eddy * 0.28);
}

// World-space displacement (render_mode world_vertex_coords).
vec3 vegetation_wind(vec3 world, vec3 world_normal, vec4 weights, vec4 custom, vec3 anchor, float scale, float t) {
	vec3 wind = normalize(vec3(wind_direction.x, 0.0, wind_direction.y));
	float phase = custom.x * 6.2832 + vegetation_hash(anchor.xz) * 6.2832;
	float stiffness = max(0.35, custom.y);
	// Gust fronts travel across the landscape along the wind (Leicht keeps
	// one sine front instead of the noise field).
	float front = wind_detail >= 1 ? vegetation_gust(anchor.xz, t) : sin(dot(anchor.xz, wind_direction) * 0.045 - t * 0.55) * 0.5 + 0.5;
	float gust = wind_strength * (0.55 + 0.45 * front + 0.12 * sin(t * 1.31 + phase)) / stiffness;
	vec3 rel = world - anchor;
	float len = length(rel);
	float height = max(0.0, rel.y) / max(0.5, plant_height * scale);
	float bend = height * height;
	float sway = (0.75 + 0.25 * sin(t * 0.83 + phase)) * gust;
	rel.xz += wind.xz * bend * sway * trunk_sway * plant_height * scale;
	rel.xz += vec2(-wind.z, wind.x) * bend * sin(t * 1.12 + phase * 1.7) * trunk_sway * 0.35 * plant_height * scale * gust;
	rel = normalize(rel) * len;
	vec3 moved = anchor + rel;
	if (wind_detail >= 1) {
		float branch_phase = weights.g * 6.2832 + phase;
		float bob = sin(t * (1.7 + weights.g * 0.9) + branch_phase) * 0.65 + sin(t * 3.05 + branch_phase * 1.9) * 0.25;
		float amount = weights.r * branch_amplitude * scale * gust;
		moved.y += bob * amount * 0.7;
		moved.xz += wind.xz * (0.55 + 0.45 * bob) * amount;
	}
	if (wind_detail >= 2) {
		float flutter = sin(t * (7.3 + 3.1 * weights.g) + dot(world, vec3(3.1, 2.3, 1.7)) + phase);
		moved += world_normal * weights.b * leaf_amplitude * scale * flutter * (0.5 + 0.5 * gust);
	}
	return moved;
}
