shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D road_color : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D road_relief : repeat_enable, filter_linear_mipmap;
uniform sampler2D verge_color : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D verge_relief : repeat_enable, filter_linear_mipmap;
uniform vec3 season_tint : source_color = vec3(1.0);
uniform float wetness : hint_range(0,1) = 0.0;
uniform float relief_strength = 0.75;
uniform float frontier_expanded = 0.0;
// Water ends at a spring at the hill foot; its worn banks end with it.
uniform float brook_source_z = -95.0;
// Plane x range, the hill-foot line and the south edge (min_x, max_x, north_z, south_z).
uniform vec4 handoff_bounds = vec4(-90.0, 90.0, -100.0, 70.0);
// Albedo of the streamed regional terrain (RegionalTerrain.ground_color).
uniform vec3 terrain_dry : source_color = vec3(0.137, 0.161, 0.071);
uniform vec3 terrain_fresh : source_color = vec3(0.329, 0.314, 0.137);
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
	float spring=smoothstep(brook_source_z-1.5,brook_source_z+2.5,p.y);
	float bank=(1.0-smoothstep(3.5,5.6,stream+grain))*spring;
	float wear=max(max(longitudinal,transverse),max(square,bank));
	float east=(1.0-smoothstep(1.35,2.40,abs(p.x-30.0)+grain))*(1.0-smoothstep(34.0,38.0,abs(p.y+9.0)));
	float north=(1.0-smoothstep(1.15,2.20,abs(p.y+36.5)+grain))*(1.0-smoothstep(24.0,27.0,abs(p.x-7.0)));
	// Branch streets follow village_layout.gd and leave the south house plots clear.
	float south=(1.0-smoothstep(.65,1.20,abs(p.y-28.0)+grain))*(1.0-smoothstep(30.0,32.0,abs(p.x-13.0)));
	float yard_lane=(1.0-smoothstep(.80,1.30,abs(p.y-24.0)+grain))*(1.0-smoothstep(12.0,14.0,abs(p.x-15.0)));
	float lane_west=(1.0-smoothstep(.90,1.75,abs(p.x+7.0)+grain))*(1.0-smoothstep(8.0,10.0,abs(p.y+28.5)));
	float scribe_square=1.0-smoothstep(.64,1.03,length((p-vec2(12.5,-23.0))/vec2(8.0,3.4))+grain*.06);
	float wagon_yard=1.0-smoothstep(.60,1.04,length((p-vec2(7.0,24.0))/vec2(6.0,4.1))+grain*.06);
	float new_streets=max(max(east,north),max(max(max(south,yard_lane),lane_west),max(scribe_square,wagon_yard)));
	wear=max(wear,new_streets*frontier_expanded);
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
	float waterline=(1.0-smoothstep(2.8,4.7,stream))*.19*spring;
	// Within 14 m of the plane edge (and towards the hill foot) the ground
	// takes on the untextured regional terrain colour it meets there.
	float edge=min(min(p.x-handoff_bounds.x,handoff_bounds.y-p.x),min(p.y-handoff_bounds.z,handoff_bounds.w-p.y));
	float handoff=1.0-smoothstep(0.0,14.0,edge);
	vec3 earth=mix(terrain_dry,terrain_fresh,(.5+.5*sin(p.x*.021)*cos(p.y*.019))*.7);
	ALBEDO=mix(textured*(1.0-waterline)*(1.0-wetness*.10),earth,handoff);
	vec3 surface=mix(texture(verge_relief,vuv).rgb,texture(road_relief,ruv).rgb,wear);
	surface.r+=cultivated*.085*cos((p.x-6.73)*8.37758+.14*sin(p.y*1.80));
	NORMAL_MAP=vec3(surface.rg,sqrt(max(.012,1.0-dot(surface.rg*2.0-1.0,surface.rg*2.0-1.0)))*.5+.5);
	NORMAL_MAP_DEPTH=relief_strength*(1.0-handoff);
	ROUGHNESS=clamp(surface.b-wetness*(.10+.31*wear)-waterline,.33,1.0);
	SPECULAR=.27;
}
