shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_burley;
// Meadow grass with individual blades (grass_tuft_near / grass_tuft_far from
// art/vegetation/build.py): opaque geometry, no texture and no alpha test.
// Each blade leans with the coherent gust field sampled at its own root, so
// gust fronts run visibly across the meadow; blades also sway on their own
// phase, flutter at the tip and are pressed down around the player.
// Vertex COLOR: r bend weight, g blade phase, b height along the blade,
// a root occlusion. INSTANCE_CUSTOM: x dryness, y stiffness, z colour
// variation, w thinning hash.
#include "res://scripts/vegetation/vegetation_wind.gdshaderinc"

uniform vec3 root_color : source_color = vec3(0.10, 0.17, 0.05);
uniform vec3 blade_color : source_color = vec3(0.25, 0.39, 0.11);
uniform vec3 tip_color : source_color = vec3(0.47, 0.56, 0.21);
uniform vec3 dry_color : source_color = vec3(0.66, 0.58, 0.31);
uniform vec3 season_tint : source_color = vec3(1.0);
uniform float dryness = 0.0;
uniform float fade_end = 30.0;
uniform float lean = 0.34;
uniform vec3 player_position = vec3(0.0, -1000.0, 0.0);
uniform float player_radius = 0.95;
varying vec3 tint;
varying float along;
varying float ao;

void vertex() {
	vec3 anchor = MODEL_MATRIX[3].xyz;
	float tall = length(MODEL_MATRIX[1].xyz);
	float t = wind_time >= 0.0 ? wind_time : TIME;
	float d = length(anchor - CAMERA_POSITION_WORLD);
	// Blades shrink into the ground before the range ends: no popping edge.
	float keep = 1.0 - smoothstep(fade_end * 0.78, fade_end, d + INSTANCE_CUSTOM.w * fade_end * 0.12);
	vec3 rel = VERTEX - anchor;
	rel.y *= keep;
	float stiffness = max(0.4, INSTANCE_CUSTOM.y);
	vec2 wind = normalize(wind_direction);
	vec2 root = VERTEX.xz - rel.xz * COLOR.b * 0.5;
	float gust = wind_detail >= 1 ? vegetation_gust(root, t) : sin(dot(root, wind) * 0.05 - t * 0.6) * 0.5 + 0.5;
	float phase = COLOR.g * 6.2832 + vegetation_hash(anchor.xz) * 6.2832;
	float own = sin(t * (2.1 + COLOR.g * 1.8) + phase) * 0.6 + sin(t * 4.3 + phase * 1.7) * 0.25;
	float force = wind_strength * (0.16 + 0.84 * gust) / stiffness;
	vec2 offset = wind * (lean * force + 0.07 * own * (0.35 + 0.65 * gust) * wind_strength) * tall * COLOR.r;
	if (wind_detail >= 2) {
		// Tip flutter across the wind, faster in a gust.
		offset += vec2(-wind.y, wind.x) * sin(t * (8.5 + 4.0 * COLOR.g) + phase * 2.3) * 0.035 * tall * COLOR.r * COLOR.b * (0.3 + 0.7 * gust);
	}
	// The player presses the blades down and apart.
	vec3 from_player = anchor + rel - player_position;
	float near = (1.0 - smoothstep(player_radius * 0.3, player_radius, length(from_player.xz))) * step(abs(from_player.y), 1.6);
	vec2 away = length(from_player.xz) > 0.001 ? normalize(from_player.xz) : wind;
	offset += away * near * 0.5 * tall * COLOR.r;
	float bent = clamp(length(offset) / max(0.05, tall * max(COLOR.b, 0.05)), 0.0, 1.2);
	rel.xz += offset * keep;
	// Keep the blade length: a leaning blade loses height.
	rel.y *= sqrt(max(0.12, 1.0 - 0.55 * bent * bent)) * (1.0 - 0.45 * near * COLOR.b);
	VERTEX = anchor + rel;
	float dry = clamp(INSTANCE_CUSTOM.x * 0.75 + dryness * (0.35 + 0.65 * INSTANCE_CUSTOM.z), 0.0, 1.0);
	vec3 green = mix(blade_color, tip_color, COLOR.b * COLOR.b);
	green *= mix(0.82, 1.16, INSTANCE_CUSTOM.z) * mix(0.9, 1.1, COLOR.g);
	vec3 c = mix(green, dry_color * mix(0.85, 1.1, COLOR.g), dry * smoothstep(0.1, 0.7, COLOR.b + dry * 0.4));
	// The lee side of a gust shows the paler undersides: the running sheen.
	c *= 1.0 + 0.16 * gust * COLOR.b;
	tint = mix(root_color, c, smoothstep(0.0, 0.3, COLOR.b)) * season_tint;
	along = COLOR.b;
	ao = COLOR.a;
}

void fragment() {
	ALBEDO = tint * mix(0.5, 1.0, ao);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.62;
	SPECULAR = 0.3 * along;
	BACKLIGHT = tint * 0.55 * along;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
}
