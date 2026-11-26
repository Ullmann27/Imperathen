shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_burley, specular_disabled;
// Meadow, wetland and crop clumps: crossed alpha cards, one 4 x 4 atlas.
// INSTANCE_CUSTOM: x atlas tile / 16, y stiffness, z colour variation,
// w phase. Seasons swap tiles (no bloom in winter, green or ripe cereals,
// stubble after harvest). Far clumps widen and shrink away before the
// chunk's visibility range ends, so there is no popping edge.
#include "res://scripts/vegetation/vegetation_wind.gdshaderinc"

uniform sampler2D card_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.45;
uniform float fade_end = 40.0;
uniform float widen_start = 30.0;
uniform vec3 season_tint : source_color = vec3(1.0);
uniform float bloom = 1.0;
uniform int crop_stage = 1;
uniform bool crops = false;
uniform float dryness = 0.0;
varying float ao;
varying float tip;
varying float variation;

void vertex() {
	vec3 anchor = MODEL_MATRIX[3].xyz;
	float height = length(MODEL_MATRIX[1].xyz);
	float tile = floor(INSTANCE_CUSTOM.x * 16.0 + 0.5);
	float pick = vegetation_hash(anchor.xz + 7.0);
	if (!crops && tile >= 7.0 && pick > bloom) {
		tile = 0.0;
	}
	if (crops && (tile == 0.0 || tile == 2.0 || tile == 3.0)) {
		tile = crop_stage == 0 ? 1.0 : (crop_stage >= 2 ? 10.0 : tile);
	}
	UV += vec2(mod(tile, 4.0) * 0.25, floor(tile / 4.0) * 0.25);
	float t = wind_time >= 0.0 ? wind_time : TIME;
	VERTEX = vegetation_wind(VERTEX, NORMAL, COLOR, vec4(INSTANCE_CUSTOM.w, INSTANCE_CUSTOM.y, 0.0, 0.0), anchor, height, t);
	float d = length(anchor - CAMERA_POSITION_WORLD);
	float keep = 1.0 - smoothstep(fade_end * 0.7, fade_end, d);
	float widen = mix(1.0, 1.9, smoothstep(widen_start, fade_end, d));
	vec3 rel = VERTEX - anchor;
	VERTEX = anchor + vec3(rel.x * widen * mix(0.6, 1.0, keep), rel.y * keep, rel.z * widen * mix(0.6, 1.0, keep));
	ao = COLOR.a;
	tip = COLOR.b;
	variation = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec4 tex = texture(card_albedo, UV);
	vec2 texel = UV * vec2(textureSize(card_albedo, 0));
	vec2 dx = dFdx(texel);
	vec2 dy = dFdy(texel);
	float mip = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	vec3 c = tex.rgb * season_tint * mix(0.85, 1.12, variation);
	c = mix(c, c * vec3(1.25, 1.05, 0.62) + vec3(0.05, 0.03, 0.0), dryness * variation * tip);
	ALBEDO = c * mix(0.55, 1.0, ao);
	ALPHA = tex.a * (1.0 + mip * 0.3);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ROUGHNESS = 0.88;
	BACKLIGHT = c * 0.45 * tip;
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
}
