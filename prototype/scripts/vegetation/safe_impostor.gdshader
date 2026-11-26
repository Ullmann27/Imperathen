shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D impostor_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.5;
uniform vec3 season_tint : source_color = vec3(1.0);
uniform vec3 autumn_color : source_color = vec3(0.74,0.50,0.17);
uniform float autumn = 0.0;
uniform float leaf_presence = 1.0;
void fragment() {
	vec4 tex = texture(impostor_albedo,UV);
	vec3 c = tex.rgb*season_tint;
	c = mix(c,autumn_color*(0.5+0.9*tex.g),clamp(autumn,0.0,1.0)*smoothstep(0.08,0.2,tex.g-tex.r));
	ALBEDO = c;
	ALPHA = tex.a*mix(1.0,0.75+0.25*leaf_presence,step(tex.r,tex.g));
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
}
