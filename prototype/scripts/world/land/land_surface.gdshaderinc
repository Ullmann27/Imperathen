// Shared ground of Valdora: the village ground, the streamed regional terrain,
// the backdrop hills and the far relief all build their albedo from these
// functions, so the surfaces continue into each other without a seam.
// Colours: textures and colour uniforms are declared source_color and vertex
// attributes carry weights only, never colours. The engine then does the
// colour-space handling itself in every renderer (Compatibility shades in the
// stored sRGB values and linearises ALBEDO afterwards; Forward+/Mobile
// linearise the inputs).
#include "res://scripts/world/village/valdora_land.gdshaderinc"

uniform sampler2D road_color : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D road_relief : repeat_enable, filter_linear_mipmap;
uniform sampler2D verge_color : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D verge_relief : repeat_enable, filter_linear_mipmap;
// R moisture patches, G mottling, B ridged streaks (tools/world/landscape_textures.py).
uniform sampler2D macro_field : repeat_enable, filter_linear_mipmap;
uniform vec3 season_tint : source_color = vec3(1.0);
// Mean of verge_color: the distant ground keeps the hue of the near turf.
uniform vec3 verge_mean : source_color = vec3(0.389, 0.386, 0.242);
// Drier and fresher open land around the village, relative to the turf.
uniform vec3 dry_tint = vec3(1.10, 1.00, 0.80);
uniform vec3 fresh_tint = vec3(0.84, 0.97, 0.88);
// Haze: the environment's fog, written by the shader so that high, distant
// relief can stay readable above the valley haze (linear RGB).
uniform vec3 haze_color = vec3(0.5, 0.6, 0.65);
uniform float haze_density = 0.0;
uniform float haze_height = 0.0;
uniform float haze_height_density = 0.0;
uniform float haze_cap = 1.0;

float land_grain(vec2 p) {
	return sin(p.x * .69 + p.y * .39) * .15 + sin(p.y * 2.06 - p.x * .42) * .065 + sin(p.x * 5.01 + p.y * 2.33) * .032;
}

// Two scales of the macro field; .xyz = large, the fine one in land_fine().
vec3 land_macro(vec2 p) {
	return texture(macro_field, p * .0037).rgb;
}

vec3 land_fine(vec2 p) {
	return texture(macro_field, mat2(vec2(.8, .6), vec2(-.6, .8)) * p * .021).rgb;
}

// Tint of the open land: 1 inside the village, patchy meadow beyond it.
vec3 land_open_tint(vec2 p, vec3 large, vec3 fine) {
	float away = smoothstep(55.0, 170.0, max(abs(p.x), abs(p.y + 15.0)));
	float moisture = large.r * .62 + fine.r * .38;
	vec3 tint = mix(dry_tint, fresh_tint, smoothstep(.22, .78, moisture)) * (.84 + .32 * fine.g);
	return mix(vec3(1.0), tint, away);
}

// Turf as the village verge draws it. sod = texture(verge_color, p * .31).
vec3 land_meadow(vec3 sod, vec2 p, float grain, vec3 large, vec3 fine) {
	float macro = sin(p.x * .21 + p.y * .14) * sin(p.y * .30 - p.x * .09);
	return sod * season_tint * (.87 + .18 * macro + grain * .19) * land_open_tint(p, large, fine);
}

vec2 land_road_uv(vec2 p) {
	return mat2(vec2(.97, .24), vec2(-.24, .97)) * p * .42;
}

// Cover of high and steep land, the same on streamed terrain and far
// relief: wooded foothills, a ragged treeline, bare rock, snow above the
// seasonal snow line. h = height in metres, slope = 1 - normal.y.
uniform vec3 forest_color : source_color = vec3(0.118, 0.176, 0.098);
uniform vec3 rock_color : source_color = vec3(0.47, 0.45, 0.42);
uniform vec3 snow_color : source_color = vec3(0.90, 0.92, 0.95);
uniform float snowline = 2300.0;

vec4 land_cover(vec3 ground, vec2 p, float h, float slope) {
	if (h < 60.0) {
		return vec4(ground, 0.0);
	}
	vec3 wide = texture(macro_field, p * .00041).rgb;
	float wooded = smoothstep(150.0, 420.0, h + 160.0 * (wide.r - .5)) * (1.0 - smoothstep(1450.0, 1850.0, h + 420.0 * (wide.b - .5)));
	ground = mix(ground, forest_color * season_tint * (.8 + .5 * wide.g), wooded * (.55 + .45 * smoothstep(.02, .10, slope)));
	float bare = max(smoothstep(.30, .52, slope + .12 * (wide.b - .5)) * step(420.0, h), smoothstep(1500.0, 1950.0, h + 420.0 * (wide.b - .5)));
	ground = mix(ground, rock_color * (.82 + .36 * wide.g), bare);
	float snow = smoothstep(snowline - 160.0, snowline + 260.0, h + 380.0 * (wide.r - .5)) * (1.0 - .55 * smoothstep(.45, .7, slope));
	return vec4(mix(ground, snow_color, snow), snow);
}

// view_vertex = VERTEX in fragment(); clear = 0 valley floor .. 1 high relief.
vec4 land_haze(vec3 view_vertex, float world_y, float clear) {
	float amount = 1.0 - exp(-length(view_vertex) * haze_density);
	if (abs(haze_height_density) >= 0.0001) {
		amount = max(amount, 1.0 - exp(min(0.0, (world_y - haze_height) * haze_height_density)));
	}
	return vec4(haze_color, mix(amount, min(amount, haze_cap), clear));
}
