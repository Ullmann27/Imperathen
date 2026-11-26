shader_type spatial;
render_mode cull_back;
// Individual hair and beard colour on the shared strand textures. Luminance
// of the source texture keeps the strand structure; greying is decided per
// strand cell, so grey reads as individual white hairs, not as a flat tint.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal_texture = false;
uniform float reference_luminance = 0.35;
uniform vec3 hair_color : source_color = vec3(0.10, 0.07, 0.05);
uniform float grey = 0.0;
uniform vec3 grey_color : source_color = vec3(0.66, 0.65, 0.62);
uniform float roughness = 0.78;
uniform float normal_strength = 1.0;

float strand_cell(vec2 uv) {
	vec2 cell = floor(uv * vec2(420.0, 36.0));
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 t = texture(albedo_texture, UV);
	float l = clamp(dot(t.rgb, vec3(0.299, 0.587, 0.114)) / max(reference_luminance, 0.01), 0.15, 2.2);
	float white = step(strand_cell(UV), grey) * (0.7 + 0.3 * l);
	vec3 dyed = hair_color * l;
	vec3 aged = mix(dyed, grey_color * (0.55 + 0.45 * l), clamp(grey * 0.55, 0.0, 1.0));
	ALBEDO = mix(aged, grey_color * (0.75 + 0.25 * l), clamp(white, 0.0, 1.0));
	ROUGHNESS = roughness;
	if (use_normal_texture) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
}
