shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
// Narrow triangular cross-section blades. Individual local roots (y=0) do not move.
uniform float wind_time=0.0;
uniform float wind_strength : hint_range(0.0,1.0)=0.65;
uniform vec2 wind_direction=vec2(0.88,0.475);
void vertex() {
	vec2 anchor=MODEL_MATRIX[3].xz;
	vec2 direction=normalize(wind_direction);
	float phase=dot(anchor,direction)*1.15;
	float gust=sin(wind_time*1.45-phase)*0.68+sin(wind_time*0.49-phase*0.37)*0.32;
	float leaf=sin(wind_time*5.1+dot(anchor,vec2(3.1,2.4))+VERTEX.y*14.0);
	vec2 local_direction=vec2(dot(normalize(MODEL_MATRIX[0].xz),direction),dot(normalize(MODEL_MATRIX[2].xz),direction));
	float h=max(0.0,VERTEX.y);
	VERTEX.xz += local_direction * h*h * (gust*1.8+leaf*0.28) * wind_strength;
}
void fragment() {
	ALBEDO=COLOR.rgb;
	ROUGHNESS=0.91;
	SPECULAR=0.20;
	if (!FRONT_FACING) { NORMAL=-NORMAL; }
}
