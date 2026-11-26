shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Village ground: lanes, squares, verge, brook banks and bed. Turf, open-land
// tint, tracks and haze come from the shared land functions, so this surface
// continues into the regional terrain without a seam.
#include "res://scripts/world/land/land_surface.gdshaderinc"
uniform sampler2D bed_color : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float wetness : hint_range(0,1) = 0.0;
uniform float relief_strength = 0.75;
uniform float frontier_expanded = 0.0;
// The water surfaces at a spring at the hill foot; banks and bed begin there.
uniform float brook_source_z = -95.0;
uniform float water_surface_y = -0.16;
varying float ground_y;
varying vec2 ground_xz;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	ground_xz = world.xz;
	ground_y = world.y;
}
void fragment() {
	vec2 p=ground_xz;
	float grain=land_grain(p);
	vec3 large=land_macro(p);
	vec3 fine=land_fine(p);
	float lane=abs(p.x-.22*sin(p.y*.17)-.13*sin(p.y*.35));
	float crossroad=abs(p.y-4.0-.14*sin(p.x*.43));
	float longitudinal=(1.0-smoothstep(1.37,2.47,lane+grain))*(1.0-smoothstep(49.0,53.0,abs(p.y+12.0)));
	float transverse=(1.0-smoothstep(1.08,1.92,crossroad+grain))*(1.0-smoothstep(23.0,26.0,abs(p.x+2.0)));
	float square=1.0-smoothstep(.56,1.02,length((p-vec2(-5.7,.10))/vec2(7.5,6.1))+grain*.05);
	// Trodden, damp earth on the banks, narrowing with the water at both ends.
	float shore=land_water_distance(p,brook_source_z);
	float bank=(1.0-smoothstep(-.3,1.8,shore+grain*1.6))*step(shore,90.0);
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
	wear=max(wear,land_track_wear(p,grain));
	vec2 vuv=p*.31;
	vec2 ruv=land_road_uv(p);
	vec3 soil=texture(road_color,ruv).rgb;
	vec3 sod=texture(verge_color,vuv).rgb;
	sod=land_meadow(sod,p,grain,large,fine);
	float grooves=(1.0-smoothstep(.055,.19,abs(lane-.70-.045*sin(p.y*1.18))))*longitudinal;
	grooves=max(grooves,(1.0-smoothstep(.035,.18,abs(crossroad-.68)))*transverse);
	soil*=1.0-grooves*.16-wetness*.23;
	vec3 textured=mix(sod,soil,wear);
	vec2 beds=abs(p-vec2(11.0,-17.0))-vec2(4.89,2.31);
	float cultivated=1.0-smoothstep(-.10,.18,max(beds.x,beds.y)+grain*.22);
	float furrow=sin((p.x-6.73)*8.37758+.14*sin(p.y*1.80));
	textured=mix(textured,soil*vec3(.69,.60,.51)*(.91+.11*furrow),cultivated);
	// Below the waterline the bed shows pebbles and silt, darker with depth.
	float under=(1.0-smoothstep(-.05,.02,ground_y-water_surface_y))*step(shore,90.0);
	float depth=clamp((water_surface_y-ground_y)/.46,0.0,1.0);
	vec3 bed=texture(bed_color,p*.47).rgb*mix(vec3(.80,.78,.70),vec3(.42,.47,.40),depth);
	float damp=(1.0-smoothstep(.0,.55,shore+grain))*step(shore,90.0);
	ALBEDO=mix(textured*(1.0-damp*.30)*(1.0-wetness*.10),bed,under);
	vec3 surface=mix(texture(verge_relief,vuv).rgb,texture(road_relief,ruv).rgb,wear);
	surface.r+=cultivated*.085*cos((p.x-6.73)*8.37758+.14*sin(p.y*1.80));
	NORMAL_MAP=vec3(surface.rg,sqrt(max(.012,1.0-dot(surface.rg*2.0-1.0,surface.rg*2.0-1.0)))*.5+.5);
	NORMAL_MAP_DEPTH=relief_strength;
	ROUGHNESS=clamp(surface.b-wetness*(.10+.31*wear)-damp*.22-under*.2,.33,1.0);
	SPECULAR=.27;
	FOG=land_haze(VERTEX,ground_y,0.0);
}
