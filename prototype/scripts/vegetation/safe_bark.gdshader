shader_type spatial;
render_mode diffuse_burley;
// Android safety path: static local geometry, native engine transform only.
uniform sampler2D bark_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength = 1.0;
uniform vec3 moss_color : source_color = vec3(0.29,0.34,0.16);
uniform float moss = 0.4;
uniform float wetness = 0.0;
varying float ao;
varying float height_m;
varying float weather;
void vertex() {
	ao = clamp(COLOR.a,0.0,1.0);
	height_m = VERTEX.y;
	weather = clamp(0.45-NORMAL.z*0.55,0.0,1.0);
}
void fragment() {
	vec3 bark = texture(bark_albedo,UV).rgb;
	float low = 1.0-smoothstep(0.15,2.4,height_m);
	float patches = smoothstep(0.35,0.75,texture(bark_albedo,UV*0.31+vec2(0.17,0.53)).g*2.2);
	float m = clamp(moss*weather*(0.35*low+0.25)*patches*1.6,0.0,0.85);
	ALBEDO = mix(bark,moss_color*(0.65+0.7*bark.g),m)*mix(0.5,1.0,ao)*mix(1.0,0.72,wetness);
	NORMAL_MAP = texture(bark_normal,UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = mix(0.93,0.6,wetness);
	SPECULAR = 0.3;
	AO = ao;
	AO_LIGHT_AFFECT = 0.25;
}
