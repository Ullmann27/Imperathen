shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.45;
uniform vec3 season_tint : source_color = vec3(1.0);
uniform vec3 autumn_color : source_color = vec3(0.74,0.50,0.17);
uniform float autumn = 0.0;
uniform float leaf_presence = 1.0;
uniform float translucency = 0.5;
uniform float normal_strength = 0.65;
varying float ao;
varying float keep;
varying float variation;
void vertex() {
	ao = clamp(COLOR.a,0.0,1.0);
	variation = clamp(COLOR.g,0.0,1.0);
	keep = step(fract(variation*37.73),leaf_presence);
}
void fragment() {
	vec4 tex = texture(leaf_albedo,UV);
	vec3 c = tex.rgb*season_tint*mix(0.84,1.1,variation);
	c = mix(c,autumn_color*(0.55+0.9*tex.g),clamp(autumn*(0.45+0.9*variation),0.0,1.0)*(0.55+0.45*tex.r));
	ALBEDO = c*mix(0.42,1.0,ao);
	ALPHA = tex.a*keep;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	NORMAL_MAP = texture(leaf_normal,UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = 0.65;
	SPECULAR = 0.25;
	AO = ao;
	AO_LIGHT_AFFECT = 0.35;
}
