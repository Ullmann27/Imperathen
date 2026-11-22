shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float fixed_time=-1.0;
void vertex() {
	float t=fixed_time>=0.0?fixed_time:TIME;
	VERTEX.y-=mod(t*5.9+INSTANCE_CUSTOM.r*9.0,9.0);
}
void fragment() { ALBEDO=vec3(.55,.65,.68); ALPHA=.30; }
