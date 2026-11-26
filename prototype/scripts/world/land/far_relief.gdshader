shader_type spatial;
render_mode diffuse_burley, specular_disabled, cull_back;
// Distant land out to the mountain horizon: one coarse mesh under and beyond
// the streamed terrain. No fine texture; cover follows height and slope.
#include "res://scripts/world/land/land_surface.gdshaderinc"

varying vec3 land_position;
varying vec3 land_normal;

void vertex() {
	land_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	land_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 p = land_position.xz;
	float h = land_position.y;
	vec3 large = land_macro(p);
	vec3 fine = land_fine(p);
	vec3 ground = land_meadow(verge_mean * (.9 + .2 * fine.g), p, 0.0, large, fine);
	vec4 cover = land_cover(ground, p, h, 1.0 - normalize(land_normal).y);
	ALBEDO = cover.rgb;
	ROUGHNESS = mix(.95, .7, cover.a);
	FOG = land_haze(VERTEX, h, smoothstep(160.0, 1000.0, h));
}
