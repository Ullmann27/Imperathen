shader_type spatial;
render_mode world_vertex_coords, diffuse_burley, specular_schlick_ggx, cull_disabled;
// Imported vertex colour carries coarse soil/field variation; alpha is road weight.
// No vertex displacement: collision and visible ground remain the same mesh.
varying vec2 world_xz;
uniform float quality : hint_range(0.0,1.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p*vec2(0.1031,0.11369));
	p += dot(p,p.yx+19.19);
	return fract((p.x+p.y)*p.x);
}
float noise2(vec2 p) {
	vec2 i=floor(p),f=fract(p),w=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1.0,0.0)),w.x),
		mix(hash21(i+vec2(0.0,1.0)),hash21(i+vec2(1.0)),w.x),w.y);
}
void vertex() {
	world_xz = VERTEX.xz;
}
void fragment() {
	float road = clamp(COLOR.a,0.0,1.0);
	float clods=noise2(world_xz*6.2);
	float medium=noise2(world_xz*24.0);
	float detail_fade=1.0-smoothstep(0.015,0.045,max(length(dFdx(world_xz)),length(dFdy(world_xz))));
	float grit=0.5;
	if (detail_fade>0.001 && quality>0.25) {
		grit=noise2(world_xz*110.0);
	}
	float fine=0.5+(grit-0.5)*detail_fade*quality;
	float grains=smoothstep(0.55,0.83,medium*0.68+fine*0.32);
	float patch=noise2(world_xz*0.83);
	float luminance=dot(COLOR.rgb,vec3(0.2126,0.7152,0.0722));
	vec3 base=mix(COLOR.rgb,vec3(luminance),0.24*road);
	vec3 colour=base*(0.82+0.22*clods+0.16*medium+0.20*(fine-0.5));
	colour=mix(colour,vec3(0.26,0.235,0.19)*(0.74+0.41*clods),grains*road*(0.32+0.36*patch));
	colour*=mix(0.86+0.25*patch,1.0,road);
	ALBEDO=colour;
	ROUGHNESS=clamp(0.83+0.13*clods+0.04*grains,0.0,1.0);
	SPECULAR=0.22;
	// True surface-gradient bump in view space. Subpixel relief fades to avoid shimmer.
	float relief=(clods-0.5)*0.003+(medium-0.5)*0.0024+(fine-0.5)*0.0009;
	vec3 dpdx=dFdx(VERTEX);
	vec3 dpdy=dFdy(VERTEX);
	vec3 r1=cross(dpdy,NORMAL);
	vec3 r2=cross(NORMAL,dpdx);
	float det=dot(dpdx,r1);
	vec3 gradient=sign(det)*(dFdx(relief)*r1+dFdy(relief)*r2);
	if (abs(det)>0.0000001) {
		NORMAL=normalize(abs(det)*NORMAL-gradient*detail_fade*quality);
	}
}
