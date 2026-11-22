shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D road_color : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D road_relief : repeat_enable, filter_linear_mipmap;
uniform sampler2D verge_color : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D verge_relief : repeat_enable, filter_linear_mipmap;
uniform vec3 season_tint : source_color = vec3(1.0);
uniform float wetness : hint_range(0,1) = 0.0;
uniform float relief_strength = 0.75;
varying vec2 ground_xz;
void vertex() {
	ground_xz = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz;
}
void fragment() {
	vec2 p=ground_xz;
	float grain=sin(p.x*.69+p.y*.39)*.15+sin(p.y*2.06-p.x*.42)*.065+sin(p.x*5.01+p.y*2.33)*.032;
	float lane=abs(p.x-.22*sin(p.y*.17)-.13*sin(p.y*.35));
	float crossroad=abs(p.y-4.0-.14*sin(p.x*.43));
	float longitudinal=(1.0-smoothstep(1.37,2.47,lane+grain))*(1.0-smoothstep(49.0,53.0,abs(p.y+12.0)));
	float transverse=(1.0-smoothstep(1.08,1.92,crossroad+grain))*(1.0-smoothstep(23.0,26.0,abs(p.x+2.0)));
	float square=1.0-smoothstep(.56,1.02,length((p-vec2(-5.7,.10))/vec2(7.5,6.1))+grain*.05);
	float stream=abs(p.x+28.0-.52*sin(p.y*.18)-.23*sin(p.y*.46));
	float bank=1.0-smoothstep(3.5,5.6,stream+grain);
	float wear=max(max(longitudinal,transverse),max(square,bank));
	vec2 vuv=p*.31;
	vec2 ruv=mat2(vec2(.97,.24),vec2(-.24,.97))*p*.42;
	vec3 soil=texture(road_color,ruv).rgb;
	vec3 sod=texture(verge_color,vuv).rgb;
	float macro=sin(p.x*.21+p.y*.14)*sin(p.y*.30-p.x*.09);
	sod*=season_tint*(.87+.18*macro+grain*.19);
	float grooves=(1.0-smoothstep(.055,.19,abs(lane-.70-.045*sin(p.y*1.18))))*longitudinal;
	grooves=max(grooves,(1.0-smoothstep(.035,.18,abs(crossroad-.68)))*transverse);
	soil*=1.0-grooves*.16-wetness*.23;
	vec3 textured=mix(sod,soil,wear);
	vec2 beds=abs(p-vec2(11.0,-17.0))-vec2(4.89,2.31);
	float cultivated=1.0-smoothstep(-.10,.18,max(beds.x,beds.y)+grain*.22);
	float furrow=sin((p.x-6.73)*8.37758+.14*sin(p.y*1.80));
	textured=mix(textured,soil*vec3(.69,.60,.51)*(.91+.11*furrow),cultivated);
	float waterline=(1.0-smoothstep(2.8,4.7,stream))*.19;
	ALBEDO=textured*(1.0-waterline)*(1.0-wetness*.10);
	vec3 surface=mix(texture(verge_relief,vuv).rgb,texture(road_relief,ruv).rgb,wear);
	surface.r+=cultivated*.085*cos((p.x-6.73)*8.37758+.14*sin(p.y*1.80));
	NORMAL_MAP=vec3(surface.rg,sqrt(max(.012,1.0-dot(surface.rg*2.0-1.0,surface.rg*2.0-1.0)))*.5+.5);
	NORMAL_MAP_DEPTH=relief_strength;
	ROUGHNESS=clamp(surface.b-wetness*(.10+.31*wear)-waterline,.33,1.0);
	SPECULAR=.27;
}
