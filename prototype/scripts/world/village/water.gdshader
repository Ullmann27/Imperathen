shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform float fixed_time=-1.0;
uniform float wetness=0.0;
uniform float detail=1.0;
varying vec2 water_xz;
void vertex() { water_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
	float t=fixed_time>=0.0?fixed_time:TIME;
	vec2 p=water_xz;
	float bank=abs(p.x+28.0-.52*sin(p.y*.18)-.23*sin(p.y*.46));
	float a=sin(p.y*3.7+p.x*.58+t*1.12);
	float b=sin(p.x*5.6-p.y*1.1+t*.68);
	float c=sin(p.y*11.4+p.x*1.7+t*1.42)*detail;
	vec2 n=vec2(a*.066+b*.030,b*.057+c*.022)*(1.0+.35*wetness);
	NORMAL_MAP=vec3(.5+n,.991);
	float sky=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.0);
	vec3 depth=mix(vec3(.044,.112,.115),vec3(.116,.178,.128),smoothstep(1.75,3.88,bank));
	ALBEDO=mix(depth,vec3(.29,.37,.38),sky*.77)+vec3(.013)*(a*b+.36*c);
	ROUGHNESS=.24+wetness*.09; SPECULAR=.66;
}
