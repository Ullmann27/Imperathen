shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// Village paving and paths (art/architecture/valdora_family/paving_textures.py).
// Texture coordinates come from world XZ in metres, so patches of any shape
// line up seamlessly. UV2.x = paving layer, UV2.y = patch seed.
// COLOR: R coverage (1 laid surface .. 0 bare ground), G moss and weeds in the
// joints, B dust and soil over the stones, A hollow (where water collects).

uniform sampler2DArray albedo_layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_layers : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray orm_layers : filter_linear_mipmap, repeat_enable;
uniform bool use_normal_map = true;
uniform bool use_parallax = false;
uniform float parallax_depth = 0.02;
uniform float wetness : hint_range(0, 1) = 0.0;
uniform float normal_strength = 1.0;
uniform vec3 moss_color : source_color = vec3(0.22, 0.27, 0.12);
uniform vec3 dust_color : source_color = vec3(0.46, 0.40, 0.32);
uniform vec3 puddle_tint : source_color = vec3(0.30, 0.31, 0.30);
// City mode: street meshes without paving attributes use one fixed layer and
// fixed masks (coverage, moss, dust, hollow) instead of UV2 and COLOR.
uniform bool use_vertex_masks = true;
uniform int fixed_layer = -1;
uniform vec4 fixed_masks = vec4(1.0, 0.25, 0.35, 0.35);
uniform float fixed_seed = 0.37;
// Repeat length per layer in metres (paving_textures.LAYERS order).
const float REPEATS[8] = float[](1.6, 2.4, 1.6, 2.0, 2.4, 1.2, 2.0, 2.0);

varying vec3 world_pos;
varying vec3 world_normal;

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
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	int layer_i = fixed_layer >= 0 ? clamp(fixed_layer, 0, 7) : clamp(int(floor(UV2.x + 0.5)), 0, 7);
	float layer = float(layer_i);
	float seed = use_vertex_masks ? UV2.y : fixed_seed;
	vec4 masks = use_vertex_masks ? COLOR : fixed_masks;
	bool flat_face = abs(world_normal.y) > 0.6;
	// A slight per-patch rotation hides the repeat of neighbouring patches.
	float a = seed * 6.2831;
	mat2 turn = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	vec2 plane = flat_face ? world_pos.xz : vec2(dot(world_pos.xz, normalize(vec2(-world_normal.z, world_normal.x) + 1e-5)), -world_pos.y);
	vec2 uv = turn * plane / REPEATS[layer_i] + vec2(seed * 7.3, seed * 3.1);
	// World-space frame of the texture: +u and +v directions on the ground.
	vec3 t_world = vec3(cos(a), 0.0, -sin(a));
	vec3 v_world = vec3(sin(a), 0.0, cos(a));
	vec3 t_view = normalize((VIEW_MATRIX * vec4(t_world, 0.0)).xyz);
	vec3 v_view = normalize((VIEW_MATRIX * vec4(v_world, 0.0)).xyz);
	if (use_parallax && flat_face) {
		vec3 view_ts = normalize(vec3(dot(VIEW, t_view), dot(VIEW, v_view), dot(VIEW, NORMAL)));
		float h0 = texture(orm_layers, vec3(uv, layer)).b;
		uv += view_ts.xy / max(view_ts.z, 0.3) * (h0 - 0.5) * parallax_depth / REPEATS[layer_i];
	}
	vec3 base = texture(albedo_layers, vec3(uv, layer)).rgb;
	vec3 orm = texture(orm_layers, vec3(uv, layer)).rgb;
	float height = orm.b;
	float stone = smoothstep(0.40, 0.52, height);
	// Organic edge: the laid surface thins out stone by stone into the ground.
	float edge_noise = value_noise(world_pos.xz * 1.7 + seed * 31.0) * 0.6 + value_noise(world_pos.xz * 5.3) * 0.4;
	float cover = masks.r * 1.25 - 0.25 + (edge_noise - 0.5) * 0.55;
	float keep = cover > 0.5 ? 1.0 : stone * step(0.08, cover + 0.25);
	ALPHA = keep;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// Dust and soil drift over the stones; weeds and moss sit in the joints.
	float macro = value_noise(world_pos.xz * 0.23 + seed) * 2.0 - 1.0;
	base *= 1.0 + macro * 0.08;
	float dust = clamp(masks.b * (0.6 + 0.8 * value_noise(world_pos.xz * 0.9)) * (1.0 - 0.5 * stone), 0.0, 1.0);
	base = mix(base, dust_color, dust * 0.55);
	float moss = clamp(masks.g * (1.0 - stone) * smoothstep(0.35, 0.75, value_noise(world_pos.xz * 2.4 + 11.0)), 0.0, 1.0);
	base = mix(base, moss_color * (0.8 + 0.4 * value_noise(world_pos.xz * 12.0)), moss * 0.8);
	// Wet ground darkens; hollows hold puddles that follow the stone relief.
	float hollow = masks.a * 0.6 + (value_noise(world_pos.xz * 0.55 + 3.0) - 0.5) * 0.9 - (height - 0.45) * 1.4;
	float puddle = smoothstep(0.30, 0.45, hollow) * smoothstep(0.35, 0.85, wetness);
	float wet = clamp(wetness * (0.65 + 0.35 * (1.0 - stone)), 0.0, 1.0);
	base *= 1.0 - wet * 0.32;
	base = mix(base, base * puddle_tint * 1.4, puddle * 0.7);
	ALBEDO = base;
	float rough = mix(orm.g, max(0.22, orm.g - 0.42), wet);
	ROUGHNESS = mix(rough, 0.04, puddle);
	SPECULAR = mix(0.4, 0.6, puddle);
	AO = mix(1.0, orm.r, 0.8);
	AO_LIGHT_AFFECT = 0.2;
	if (use_normal_map && flat_face) {
		// Own tangent frame (independent of mesh UVs): red = +u, green = image up = -v.
		vec3 n_ts = mix(texture(normal_layers, vec3(uv, layer)).rgb, vec3(0.5, 0.5, 1.0), puddle) * 2.0 - 1.0;
		n_ts.xy *= normal_strength;
		NORMAL = normalize(t_view * n_ts.x - v_view * n_ts.y + NORMAL * n_ts.z);
	}
}
