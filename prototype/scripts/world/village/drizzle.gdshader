shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
// Each native instance starts at an exact static roof/terrain hit.
// No packed custom-data buffer; small, bounded displacement in local space.
uniform float fixed_time=-1.0;
uniform float intensity=0.0;
uniform float wind=1.0;
varying float fall_height;
void vertex() {
	float t=fixed_time>=0.0?fixed_time:TIME;
	vec3 at=MODEL_MATRIX[3].xyz;
	float phase=fract(sin(dot(at.xz,vec2(12.9898,78.233)))*43758.5453);
	fall_height=9.0-fract(t*mix(.64,1.1,intensity)+phase)*9.0;
	VERTEX.y+=fall_height;
	VERTEX.x+=VERTEX.y*.012*wind;
}
void fragment() {
	ALBEDO=vec3(.53,.65,.76);
	ALPHA=.34*intensity*smoothstep(.0,.25,fall_height);
}
