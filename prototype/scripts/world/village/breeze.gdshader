shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Instanced verge plants. UV.y is the height fraction of a vertex inside its
// plant (0 at the root, 1 at the tip); UV.x > .5 marks flower petals.
// Per-clump dryness, flower colour and lushness are hashed from its position.
uniform float fixed_time=-1.0;
uniform float gust=1.0;
uniform vec3 season_tint : source_color = vec3(1.0);
uniform float bloom=1.0;
uniform vec2 wind_direction=vec2(.83,.56);
uniform float fade_end=40.0;
varying float tip;
varying float petal;
varying vec3 variation;

void vertex() {
	tip=UV.y;
	petal=step(.5,UV.x);
	vec3 anchor=MODEL_MATRIX[3].xyz;
	variation=fract(sin(vec3(dot(anchor.xz,vec2(12.99,78.23)),dot(anchor.xz,vec2(39.35,11.13)),dot(anchor.xz,vec2(73.17,52.91))))*43758.55);
	variation.r*=variation.r;
	float t=fixed_time>=0.0?fixed_time:TIME;
	float phase=dot(anchor.xz,vec2(.29,.21));
	// Gust fronts travel across the meadow along the wind; blades also flutter.
	float front=sin(dot(anchor.xz,wind_direction)*.23-t*1.35)*.5+.5;
	float wave=front*front*(1.25+.5*sin(t*.31+anchor.x*.05));
	float sway=sin(t*1.46+phase)*.55+sin(t*.77+phase*1.92)*.2+wave*.9;
	float flutter=sin(t*4.1+dot(VERTEX.xz,vec2(31.0,17.0))+phase)*.018*tip;
	vec2 bend=wind_direction*sway*gust*.075+vec2(-wind_direction.y,wind_direction.x)*flutter;
	VERTEX.xz+=bend*tip*tip*(1.0+.35*petal);
	VERTEX.y-=dot(bend,bend)*tip*1.4;
	// Shrink toward the root before the batch's visibility range ends: no pop.
	float distance_to_eye=length(anchor-CAMERA_POSITION_WORLD);
	float keep=1.0-smoothstep(fade_end*.62,fade_end*.97,distance_to_eye);
	VERTEX*=vec3(mix(.55,1.0,keep),keep,mix(.55,1.0,keep));
}

void fragment() {
	vec3 leaf=COLOR.rgb*season_tint*mix(.58,1.08,tip);
	leaf=mix(leaf,leaf*vec3(1.18,1.02,.62)+vec3(.05,.03,0.0),variation.r*smoothstep(.2,1.0,tip));
	leaf*=mix(.88,1.10,variation.b);
	vec3 flower=vec3(.92,.90,.80);
	float pick=variation.g*5.0;
	flower=pick<1.0?vec3(.93,.91,.82):(pick<2.0?vec3(.95,.78,.22):(pick<3.0?vec3(.56,.46,.80):(pick<4.0?vec3(.82,.17,.10):vec3(.43,.57,.86))));
	flower=mix(leaf*vec3(1.05,.86,.6),flower,bloom);
	ALBEDO=mix(leaf,flower*COLOR.rgb,petal);
	ROUGHNESS=.9;
}

void light() {
	// Wrapped diffuse plus light shining through thin blades toward the eye.
	float wrap=clamp((dot(NORMAL,LIGHT)+.4)/1.4,0.0,1.0);
	float through=pow(clamp(dot(-VIEW,LIGHT),0.0,1.0),3.0)*(.25+.75*tip)*.55;
	DIFFUSE_LIGHT+=ATTENUATION*LIGHT_COLOR*(wrap+through)/PI;
}
