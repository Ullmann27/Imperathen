shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_burley;
// Alpha-tested twig sprays with painted single leaves. Normals are bent to
// the crown surface at build time; back faces keep that normal so the crown
// lights as a volume. Coverage is held at distance by scaling alpha with the
// mip level, light shines through thin leaves (BACKLIGHT).
#include "res://scripts/vegetation/vegetation_wind.gdshaderinc"

uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.45;
uniform vec3 season_tint : source_color = vec3(1.0);
uniform vec3 autumn_color : source_color = vec3(0.74, 0.50, 0.17);
uniform float autumn = 0.0;
uniform float leaf_presence = 1.0;
uniform float translucency = 0.5;
uniform float normal_strength = 0.65;
varying float ao;
varying float keep;
varying float variation;

void vertex() {
	vec3 anchor = MODEL_MATRIX[3].xyz;
	float scale = length(MODEL_MATRIX[0].xyz);
	float t = wind_time >= 0.0 ? wind_time : TIME;
	VERTEX = vegetation_wind(VERTEX, NORMAL, COLOR, INSTANCE_CUSTOM, anchor, scale, t);
	ao = COLOR.a;
	variation = INSTANCE_CUSTOM.z;
	// Winter thinning drops whole sprays (shared branch phase), not pixels.
	keep = step(vegetation_hash(vec2(COLOR.g * 91.7, INSTANCE_CUSTOM.x * 37.1 + 3.0)), leaf_presence);
}

void fragment() {
	vec4 tex = texture(leaf_albedo, UV);
	vec2 texel = UV * vec2(textureSize(leaf_albedo, 0));
	vec2 dx = dFdx(texel);
	vec2 dy = dFdy(texel);
	float mip = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	float turn = clamp(autumn * (0.45 + 0.9 * variation), 0.0, 1.0);
	vec3 c = tex.rgb * season_tint * mix(0.84, 1.1, variation);
	c = mix(c, autumn_color * (0.55 + 0.9 * tex.g), turn * (0.55 + 0.45 * tex.r));
	ALBEDO = c * mix(0.42, 1.0, ao);
	ALPHA = tex.a * (1.0 + mip * 0.24) * keep;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	NORMAL_MAP = texture(leaf_normal, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = 0.6;
	SPECULAR = 0.32;
	BACKLIGHT = c * translucency * mix(0.5, 1.0, ao);
	AO = ao;
	AO_LIGHT_AFFECT = 0.35;
}
