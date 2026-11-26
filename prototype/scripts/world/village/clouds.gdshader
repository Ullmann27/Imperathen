shader_type sky;
uniform sampler2D cloud_field : repeat_enable, filter_linear_mipmap;
uniform vec3 zenith : source_color = vec3(.37,.56,.72);
uniform vec3 horizon : source_color = vec3(.79,.79,.72);
uniform vec3 cloud_color : source_color = vec3(.96,.93,.81);
// Warm forward scattering around a low sun and the bounce colour of the land.
uniform vec3 sun_haze : source_color = vec3(1.0,.80,.56);
uniform vec3 ground_color : source_color = vec3(.33,.31,.22);
uniform float haze_strength=.38;
uniform float coverage=.46;
uniform float phase=0.0;
void sky() {
	float y=max(EYEDIR.y,0.0);
	vec3 base=mix(horizon,zenith,pow(y,.47));
	float sun_side=0.0;
	if (LIGHT0_ENABLED) {
		sun_side=pow(max(dot(normalize(EYEDIR.xz+vec2(1e-4)),normalize(LIGHT0_DIRECTION.xz+vec2(1e-4))),0.0),3.0);
		float low=1.0-smoothstep(0.0,.42,y);
		base=mix(base,sun_haze*LIGHT0_ENERGY*.42+base*.62,haze_strength*sun_side*low);
	}
	vec2 coords=vec2(SKY_COORDS.x+phase*.00057,SKY_COORDS.y*1.60-.17);
	// Longitude wraps at 0/1. Keep that seam out of mipmap selection.
	vec2 uv_dx=dFdx(coords);
	vec2 uv_dy=dFdy(coords);
	uv_dx.x-=round(uv_dx.x);
	uv_dy.x-=round(uv_dy.x);
	float field=AT_CUBEMAP_PASS?.5:textureGrad(cloud_field,coords,uv_dx,uv_dy).r;
	float density=smoothstep(.58-coverage*.31,.77-coverage*.28,field)*smoothstep(.0,.082,y);
	// Clouds take a warm rim on the sun side and a cooler belly elsewhere.
	vec3 lit_cloud=cloud_color*(.80+.19*field)*mix(vec3(.93,.95,1.0),sun_haze*1.15,sun_side*.55);
	COLOR=mix(base,lit_cloud,density*.77);
	if (EYEDIR.y<0.0) {
		// Ambient light from below: the land, not a mirrored horizon.
		COLOR=mix(horizon,ground_color,smoothstep(0.0,.18,-EYEDIR.y));
	}
	if (LIGHT0_ENABLED && !AT_CUBEMAP_PASS) {
		float cos_angle=max(dot(EYEDIR,LIGHT0_DIRECTION),0.0);
		COLOR+=sun_haze*(pow(cos_angle,48.0)*.22+pow(cos_angle,900.0)*.55+smoothstep(.99987,.99996,cos_angle)*2.4)*(1.0-density*.85);
	}
}
