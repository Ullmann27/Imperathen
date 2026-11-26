shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Physical blade vertices are untouched. Colour uses only authored local
// vertex attributes, not per-instance shader data or world-space wind.
uniform vec3 root_color : source_color = vec3(0.10,0.17,0.05);
uniform vec3 blade_color : source_color = vec3(0.25,0.39,0.11);
uniform vec3 tip_color : source_color = vec3(0.47,0.56,0.21);
uniform vec3 dry_color : source_color = vec3(0.66,0.58,0.31);
uniform vec3 season_tint : source_color = vec3(1.0);
uniform float dryness = 0.0;
varying vec3 tint;
varying float ao;
void vertex() {
	float h = clamp(COLOR.b,0.0,1.0);
	float shade = clamp(COLOR.g,0.0,1.0);
	vec3 green = mix(blade_color,tip_color,h*h)*mix(0.83,1.12,shade);
	vec3 c = mix(green,dry_color,clamp(dryness*(0.55+0.35*shade)*smoothstep(0.1,0.7,h),0.0,1.0));
	tint = mix(root_color,c,smoothstep(0.0,0.3,h))*season_tint;
	ao = clamp(COLOR.a,0.0,1.0);
}
void fragment() {
	ALBEDO = tint*mix(0.5,1.0,ao);
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	ROUGHNESS = 0.88;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
}
