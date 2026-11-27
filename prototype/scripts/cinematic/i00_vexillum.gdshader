shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform float wind_seconds = 0.0;
uniform float wind_phase = 0.0;
uniform bool use_atlas = false;
uniform sampler2D textile_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 cloth_dye : source_color = vec4(0.52,0.105,0.085,1.0);
uniform vec4 ochre_thread : source_color = vec4(0.67,0.49,0.26,1.0);

void vertex() {
	float v = clamp(UV.y,0.0,1.1);
	float a = 6.28318530718*(0.60*wind_seconds+1.10*UV.x)+3.6*v+wind_phase;
	float b = 6.28318530718*(1.25*wind_seconds-0.80*UV.x)+5.0*v+wind_phase;
	float fold = 0.09+0.075*sin(a)+0.028*sin(b);
	VERTEX.z += v*v*fold;
	float du = v*v*(0.075*6.28318530718*1.10*cos(a)-0.028*6.28318530718*0.80*cos(b));
	float dv = 2.0*v*fold+v*v*(0.075*3.6*cos(a)+0.028*5.0*cos(b));
	NORMAL = normalize(vec3(-du/0.68,dv/0.68,1.0));
}

void fragment() {
	vec2 p = UV;
	float edge = min(min(p.x,1.0-p.x),min(p.y,1.0-p.y));
	float seam = (1.0-smoothstep(0.022,0.030,edge))*smoothstep(0.009,0.015,edge);
	float band = (1.0-smoothstep(0.064,0.075,edge))*smoothstep(0.045,0.052,edge);
	vec2 q = p-vec2(0.5,0.49);
	float radius = length(q);
	float ring = 1.0-smoothstep(0.010,0.016,abs(radius-0.17));
	float theta = atan(q.y,q.x);
	float petal = 1.0-smoothstep(0.006,0.015,abs(radius-(0.076+0.035*cos(8.0*theta))));
	float gold = max(max(seam,band),max(ring,petal)*(1.0-smoothstep(0.19,0.22,radius)));
	vec3 dye = mix(cloth_dye.rgb,ochre_thread.rgb,gold);
	if (use_atlas) { dye = texture(textile_atlas,clamp(p,vec2(0.0),vec2(1.0))).rgb; }
	if (p.y > 1.0) { dye = ochre_thread.rgb*0.88; }
	float pixel_weave = max(fwidth(p.x),fwidth(p.y))*125.0;
	float weave = sin(p.x*785.39816)*sin(p.y*785.39816);
	float yarn = weave*(1.0-smoothstep(0.35,1.0,pixel_weave));
	float mottling = sin(p.x*46.0+p.y*26.0)*sin(p.x*28.0-p.y*37.0);
	ALBEDO = dye*(0.88+0.065*yarn+0.05*mottling);
	ROUGHNESS = clamp(0.77+0.07*yarn-0.07*mottling,0.60,0.91);
	SPECULAR = 0.32;
}
