shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// Streamed regional ground and backdrop hills. Vertex COLOR carries weights:
// r scrub cover of raised relief, g bare stone, b shade variation.
#include "res://scripts/world/land/land_surface.gdshaderinc"

uniform sampler2D scree_color : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec3 scrub_tint = vec3(0.72, 0.86, 0.74);
uniform vec3 stone_tint : source_color = vec3(0.86, 0.80, 0.68);
uniform float relief_strength = 0.75;
varying vec3 land_position;
varying vec3 land_normal;

void vertex() {
	land_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	land_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	// Ground meshes carry no tangents; x-aligned like the village plane.
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = cross(NORMAL, TANGENT);
}

void fragment() {
	vec2 p = land_position.xz;
	float distance_m = length(VERTEX);
	float grain = land_grain(p);
	vec3 large = land_macro(p);
	vec3 fine = land_fine(p);
	vec2 vuv = p * .31;
	// Beyond the reach of the fine texture the turf settles on its mean and
	// the patch pattern carries the surface (no visible tiling).
	float close_up = 1.0 - smoothstep(45.0, 150.0, distance_m);
	vec3 sod = mix(verge_mean * (.9 + .2 * fine.g), texture(verge_color, vuv).rgb, close_up);
	vec3 ground = land_meadow(sod, p, grain * close_up, large, fine);
	ground = mix(ground, ground * scrub_tint * (1.0 - .24 * COLOR.b), COLOR.r);
	// Steep faces and high ground break into scree and bedrock.
	float slope = 1.0 - normalize(land_normal).y;
	float rocky = smoothstep(.17, .33, slope + (fine.b - .5) * .10 + (large.b - .5) * .06);
	rocky = max(rocky, COLOR.g * (.55 + .45 * fine.b));
	vec3 rock = mix(texture(scree_color, p * .043).rgb, texture(scree_color, p * .19).rgb, .35 + .4 * close_up) * stone_tint;
	ground = mix(ground, rock, rocky);
	float wear = land_track_wear(p, grain);
	vec2 ruv = land_road_uv(p);
	vec3 soil = mix(vec3(.6, .49, .34) * season_tint, texture(road_color, ruv).rgb, close_up);
	ALBEDO = land_cover(mix(ground, soil, wear), p, land_position.y, slope).rgb;
	vec3 surface = mix(texture(verge_relief, vuv).rgb, texture(road_relief, ruv).rgb, wear);
	NORMAL_MAP = vec3(surface.rg, sqrt(max(.012, 1.0 - dot(surface.rg * 2.0 - 1.0, surface.rg * 2.0 - 1.0))) * .5 + .5);
	NORMAL_MAP_DEPTH = relief_strength * close_up * (1.0 - rocky * .6);
	ROUGHNESS = mix(.95, clamp(surface.b, .33, 1.0), close_up);
	SPECULAR = mix(.12, .27, close_up);
	FOG = land_haze(VERTEX, land_position.y, 0.0);
}
