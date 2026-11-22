shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform float fixed_time=-1.0;
uniform float gust=1.0;
uniform vec3 season_tint : source_color = vec3(1.0);
varying float tip;
void vertex() {
	tip=UV.y;
	vec3 anchor=MODEL_MATRIX[3].xyz;
	float t=fixed_time>=0.0?fixed_time:TIME;
	float phase=dot(anchor.xz,vec2(.29,.21));
	float sway=sin(t*1.46+phase)*.74+sin(t*.77+phase*1.92)*.26;
	VERTEX.x+=tip*tip*sway*gust*.084;
	VERTEX.z+=tip*tip*gust*.027*sin(t*1.20+phase);
}
void fragment() {
	ALBEDO=COLOR.rgb*season_tint*mix(.67,1.05,tip);
	ROUGHNESS=.93;
}
