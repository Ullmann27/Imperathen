shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Valdora house family (art/architecture/valdora_family). One material for all
// pieces of a house: UV = metric coordinates, UV2.x = texture-array layer,
// UV2.y = random per element, COLOR = ageing masks (R damp/dirt, G moss and
// lichen, B soot, A worn edge). Layer order: family_textures.py LAYERS.

uniform sampler2DArray albedo_layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_layers : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray orm_layers : filter_linear_mipmap, repeat_enable;
uniform bool use_normal_map = true;
uniform bool use_parallax = false;
uniform float parallax_depth = 0.010;
uniform float normal_strength = 1.0;
uniform vec3 plaster_tint : source_color = vec3(0.86, 0.80, 0.70);
uniform float age_dirt : hint_range(0, 1) = 0.6;
uniform float age_moss : hint_range(0, 1) = 0.5;
uniform float age_soot : hint_range(0, 1) = 0.6;
uniform float age_wear : hint_range(0, 1) = 0.5;
uniform float wetness : hint_range(0, 1) = 0.0;
uniform vec3 moss_color : source_color = vec3(0.24, 0.29, 0.13);
uniform vec3 lichen_color : source_color = vec3(0.63, 0.62, 0.50);
uniform vec3 damp_color : source_color = vec3(0.47, 0.44, 0.38);
uniform float macro_variation = 0.07;

varying vec3 world_pos;
varying vec3 world_up_normal;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_up_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float layer = floor(UV2.x + 0.5);
	float rnd = UV2.y;
	vec2 uv = UV;
	if (use_parallax) {
		// One-step offset mapping along the view direction in tangent space.
		// Tangent frame of the mesh UVs: TANGENT = +u, BINORMAL = +v. Deeper
		// texels (low height) shift away from the viewer.
		vec3 view_ts = normalize(vec3(dot(VIEW, TANGENT), dot(VIEW, BINORMAL), dot(VIEW, NORMAL)));
		float h = texture(orm_layers, vec3(uv, layer)).b;
		uv += view_ts.xy / max(view_ts.z, 0.35) * (h - 0.5) * parallax_depth / 1.6;
	}
	vec3 base = texture(albedo_layers, vec3(uv, layer)).rgb;
	vec3 orm = texture(orm_layers, vec3(uv, layer)).rgb;
	bool plaster = layer < 1.5;
	bool tile = layer > 7.5 && layer < 9.5;
	bool stone = layer > 13.5 && layer < 14.5;
	bool wood = layer > 5.5 && layer < 7.5;
	if (plaster) {
		base *= clamp(plaster_tint / vec3(0.86, 0.80, 0.70), vec3(0.75), vec3(1.2));
	}
	// Per-element variation: kiln batches of tiles, individual stones and boards.
	if (tile) {
		base *= mix(vec3(0.84, 0.86, 0.90), vec3(1.10, 1.04, 0.98), rnd);
	} else if (stone) {
		base *= mix(vec3(0.86, 0.86, 0.84), vec3(1.07, 1.04, 0.99), fract(rnd * 3.7));
	} else if (wood) {
		base *= mix(0.86, 1.08, fract(rnd * 5.3));
	}
	// Large-scale world variation breaks repetition between neighbouring houses.
	float macro = value_noise(world_pos.xz * 0.35 + world_pos.y * 0.2) * 2.0 - 1.0;
	base *= 1.0 + macro * macro_variation;
	vec4 age = COLOR;
	float detail_noise = value_noise(world_pos.xz * 3.1 + world_pos.yy * 2.7);
	// Worn arrises: lighter, freshly exposed material.
	base = mix(base, base * 1.16 + 0.025, clamp(age.a * age_wear * (0.6 + 0.4 * detail_noise), 0.0, 1.0));
	// Rising damp and splash dirt.
	float damp = clamp(age.r * age_dirt * (0.75 + 0.5 * detail_noise), 0.0, 1.0);
	base = mix(base, base * damp_color * 1.35, damp * 0.75);
	// Moss in shaded, up-facing spots; lichen spots on tiles.
	float up = clamp(world_up_normal.y * 0.5 + 0.5, 0.0, 1.0);
	float moss = clamp(age.g * age_moss * (0.55 + 0.9 * detail_noise) * (0.4 + 0.6 * up), 0.0, 1.0);
	vec3 growth = tile ? mix(lichen_color, moss_color, step(0.55, detail_noise)) : moss_color;
	base = mix(base, growth * (0.8 + 0.4 * value_noise(world_pos.xz * 9.0)), moss * 0.85);
	// Soot above the door and the smoke vent.
	base *= 1.0 - clamp(age.b * age_soot, 0.0, 1.0) * 0.72;
	// Wet stone and plaster darken; up-facing surfaces gain a sheen.
	float porous = (tile || plaster || stone || layer > 1.5 && layer < 5.5) ? 1.0 : 0.6;
	base *= 1.0 - wetness * 0.30 * porous;
	ALBEDO = base;
	float rough = orm.g;
	rough = mix(rough, 0.95, moss * 0.6);
	rough = mix(rough, max(0.18, rough - 0.45), wetness * (0.35 + 0.65 * up));
	ROUGHNESS = rough;
	METALLIC = (layer > 10.5 && layer < 11.5) ? 0.45 : 0.0;
	SPECULAR = 0.4;
	AO = mix(1.0, orm.r, 0.85);
	AO_LIGHT_AFFECT = 0.25;
	if (use_normal_map) {
		NORMAL_MAP = texture(normal_layers, vec3(uv, layer)).rgb;
		NORMAL_MAP_DEPTH = normal_strength * (1.0 - moss * 0.5);
	}
}
