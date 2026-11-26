shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// CPU-baked atlas tile and variation in UV2; no instance data or vertex movement.
uniform sampler2D card_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.45;
uniform vec3 season_tint : source_color = vec3(1.0);
uniform float bloom = 1.0;
uniform int crop_stage = 1;
uniform bool crops = false;
uniform float dryness = 0.0;
varying float ao;
varying float tip;
varying float variation;
void vertex() {
	variation = clamp(UV2.y,0.0,1.0);
	float tile = clamp(floor(UV2.x*16.0+0.5),0.0,15.0);
	if (!crops && tile >= 7.0 && variation > bloom) { tile = 0.0; }
	if (crops && (tile == 0.0 || tile == 2.0 || tile == 3.0)) { tile = crop_stage == 0 ? 1.0 : (crop_stage >= 2 ? 10.0 : tile); }
	UV = clamp(UV,vec2(0.001),vec2(0.249)) + vec2(mod(tile,4.0)*0.25,floor(tile/4.0)*0.25);
	ao = clamp(COLOR.a,0.0,1.0);
	tip = clamp(COLOR.b,0.0,1.0);
}
void fragment() {
	vec4 tex = texture(card_albedo,UV);
	vec3 c = tex.rgb*season_tint*mix(0.85,1.12,variation);
	c = mix(c,c*vec3(1.25,1.05,0.62)+vec3(0.05,0.03,0.0),dryness*variation*tip);
	ALBEDO = c*mix(0.55,1.0,ao);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	ROUGHNESS = 0.88;
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
}
