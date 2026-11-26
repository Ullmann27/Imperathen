shader_type spatial;
// Individual resident skin on the shared frontier body texture. The identity
// masks are baked from the rest surface into the body UV layout by
// art/village_characters/build_resident_identity.py:
//   identity_mask   R beard area, G creases and age spots, B sun exposure, A flush
//   identity_detail RG crease normal, B scalp, A eyebrows
// Only uniforms differ between residents; the textures are shared.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D identity_mask : hint_default_black, filter_linear_mipmap;
uniform sampler2D identity_detail : hint_default_black, filter_linear_mipmap;
uniform bool use_normal_texture = false;
uniform bool use_roughness_texture = false;
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform float roughness = 0.72;
uniform float normal_strength = 1.0;
uniform vec3 tone : source_color = vec3(1.0);
uniform float sun = 0.0;
uniform vec3 sun_tint : source_color = vec3(0.80, 0.64, 0.50);
uniform float flush = 0.0;
uniform float age = 0.0;
uniform float stubble = 0.0;
uniform vec3 stubble_color : source_color = vec3(0.13, 0.10, 0.08);
uniform float scalp = 0.0;
uniform vec3 scalp_color : source_color = vec3(0.16, 0.12, 0.09);
uniform float brow = 0.0;
uniform vec3 brow_color : source_color = vec3(0.10, 0.07, 0.05);

void fragment() {
	vec4 m = texture(identity_mask, UV);
	vec4 d = texture(identity_detail, UV);
	vec3 c = texture(albedo_texture, UV).rgb * tone;
	c *= mix(vec3(1.0), sun_tint, clamp(sun * m.b, 0.0, 1.0));
	c *= mix(vec3(1.0), vec3(1.10, 0.80, 0.76), clamp(flush * m.a, 0.0, 1.0));
	c *= 1.0 - clamp(age * 0.40 * m.g, 0.0, 0.6);
	c = mix(c, stubble_color, clamp(stubble * m.r, 0.0, 0.92));
	c = mix(c, scalp_color, clamp(scalp * d.b, 0.0, 0.9));
	c = mix(c, brow_color, clamp(brow * d.a, 0.0, 0.95));
	ALBEDO = c;
	float base_roughness = use_roughness_texture ? dot(texture(roughness_texture, UV), roughness_channel) * roughness : roughness;
	ROUGHNESS = clamp(base_roughness + 0.12 * stubble * m.r + 0.05 * age * m.g, 0.04, 1.0);
	vec2 base_xy = use_normal_texture ? texture(normal_texture, UV).rg * 2.0 - 1.0 : vec2(0.0);
	vec2 crease_xy = (d.rg * 2.0 - 1.0) * clamp(age, 0.0, 1.0);
	NORMAL_MAP = vec3((base_xy + crease_xy) * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = normal_strength;
}
