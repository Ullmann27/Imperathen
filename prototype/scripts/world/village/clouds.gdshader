shader_type sky;
uniform sampler2D cloud_field : repeat_enable, filter_linear_mipmap;
uniform vec3 zenith : source_color = vec3(.37,.56,.72);
uniform vec3 horizon : source_color = vec3(.79,.79,.72);
uniform vec3 cloud_color : source_color = vec3(.96,.93,.81);
uniform float coverage=.46;
uniform float phase=0.0;
void sky() {
	float y=max(EYEDIR.y,0.0);
	vec3 base=mix(horizon,zenith,pow(y,.47));
	vec2 coords=vec2(SKY_COORDS.x+phase*.00057,SKY_COORDS.y*1.60-.17);
	float field=texture(cloud_field,coords).r;
	float density=smoothstep(.58-coverage*.31,.77-coverage*.28,field)*smoothstep(.0,.082,y);
	COLOR=mix(base,cloud_color*(.86+.13*field),density*.77);
	if (LIGHT0_ENABLED) {
		float cos_angle=max(dot(EYEDIR,LIGHT0_DIRECTION),0.0);
		COLOR+=vec3(.9,.72,.43)*(pow(cos_angle,64.0)*.13+smoothstep(.99987,.99996,cos_angle)*1.15)*(1.0-density);
	}
}
