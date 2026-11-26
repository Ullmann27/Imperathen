shader_type spatial;
render_mode world_vertex_coords, diffuse_burley;
// Tree, shrub and vine wood: tileable bark albedo + normal map, baked crown
// occlusion (COLOR.a), damp moss on the weather (north) side near the ground.
#include "res://scripts/vegetation/vegetation_wind.gdshaderinc"

uniform sampler2D bark_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength = 1.0;
uniform vec3 moss_color : source_color = vec3(0.29, 0.34, 0.16);
uniform float moss = 0.4;
uniform float wetness = 0.0;
varying float ao;
varying float height_m;
varying vec3 world_normal;

void vertex() {
	vec3 anchor = MODEL_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	float t = wind_time >= 0.0 ? wind_time : TIME;
	height_m = (VERTEX.y - anchor.y) / max(scale, 0.01);
	world_normal = NORMAL;
	VERTEX = vegetation_wind(VERTEX, NORMAL, vec4(COLOR.rg, 0.0, COLOR.a), INSTANCE_CUSTOM, anchor, scale, t);
	ao = COLOR.a;
}

void fragment() {
	vec3 bark = texture(bark_albedo, UV).rgb;
	float weather = clamp(0.45 - world_normal.z * 0.55, 0.0, 1.0);
	float low = 1.0 - smoothstep(0.15, 2.4, height_m);
	float patches = smoothstep(0.35, 0.75, texture(bark_albedo, UV * 0.31 + vec2(0.17, 0.53)).g * 2.2);
	float m = clamp(moss * weather * (0.35 * low + 0.25) * patches * 1.6, 0.0, 0.85);
	vec3 c = mix(bark, moss_color * (0.65 + 0.7 * bark.g), m);
	c *= mix(0.5, 1.0, ao);
	ALBEDO = c * mix(1.0, 0.72, wetness);
	NORMAL_MAP = texture(bark_normal, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = mix(0.93, 0.6, wetness);
	SPECULAR = 0.3;
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
}
