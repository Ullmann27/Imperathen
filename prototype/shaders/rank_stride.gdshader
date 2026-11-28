shader_type spatial;
uniform sampler2D pigments : source_color, filter_linear_mipmap;
uniform sampler2D finish_map : filter_nearest;
uniform float step_fraction : hint_range(0.0, 1.0) = 1.0;
uniform vec3 stance = vec3(0.58, 0.40, 0.51);
uniform vec3 clearance = vec3(0.106, 0.19, 0.134);
// Baked once by FarRanks from the canonical company source, shared by every batch.
uniform vec4 authored_gait_keys[136];

vec3 foot_offset(float phase, float stride, float support, float lift) {
	float t = fract(phase);
	if (t <= support) {
		return vec3(0.0, 0.0, stride * (support * 0.5 - t));
	}
	float u = (t - support) / (1.0 - support);
	float u2 = u * u;
	float u3 = u2 * u;
	float tangent = -stride * (1.0 - support);
	float z = (2.0*u3 - 3.0*u2 + 1.0) * (-stride*support*0.5) + (u3 - 2.0*u2 + u) * tangent;
	z += (-2.0*u3 + 3.0*u2) * (stride*support*0.5) + (u3 - u2) * tangent;
	return vec3(0.0, lift * pow(sin(PI*u), 2.0), z);
}

float upper_lean(float phase, int mode) {
	float pulse = sin(PI*clamp(phase, 0.0, 1.0));
	if (mode == 4) { return -0.16*pulse; }
	if (mode == 5) { return -0.06*pulse; }
	if (mode == 6) { return 0.08*pulse; }
	if (mode == 7) { return 0.045; }
	if (mode == 8) { return 0.07; }
	if (mode == 9) { return 0.22*pulse; }
	if (mode == 10) { return 1.35*clamp(phase, 0.0, 1.0); }
	return 0.006*sin(TAU*phase);
}

// Same two sagittal hinges as FarRanks.guard_vertex and the source company
// rig. Both use Godot model axes (Blender x,z,-y).
vec3 rotate_guard_x(vec3 p, float angle) {
	return vec3(p.x, cos(angle)*p.y - sin(angle)*p.z, sin(angle)*p.y + cos(angle)*p.z);
}

vec3 guard_vertex(vec3 p) {
	vec3 hip = vec3(.105,.89,0.0);
	vec3 knee = vec3(.119,.49,.012);
	vec3 upper = hip + rotate_guard_x(p-hip,radians(-17.0));
	vec3 shin = knee + rotate_guard_x(p-knee,radians(27.0));
	vec3 lower = hip + rotate_guard_x(shin-hip,radians(-17.0));
	float shin_weight = 1.0-smoothstep(.40,.58,p.y);
	float leg_weight = smoothstep(0.0,.04,p.x)*(1.0-smoothstep(.22,.30,abs(p.x)))*(1.0-smoothstep(.75,.95,p.y));
	return mix(p,mix(upper,lower,shin_weight),leg_weight)+vec3(0.0,.0000410085811,0.0);
}

vec4 sample_authored_gait(int mode, float phase, bool left) {
	int count = mode == 1 ? 25 : (mode == 2 ? 18 : 22);
	int base = (mode == 1 ? 0 : (mode == 2 ? 52 : 90)) + (left ? count+1 : 0);
	float frame = fract(phase)*float(count);
	int index = min(int(floor(frame)),count-1);
	return mix(authored_gait_keys[base+index],authored_gait_keys[base+index+1],clamp(frame-float(index),0.0,1.0));
}

vec3 gait_vertex(vec3 p, int mode, float phase, float stride) {
	float side = p.x < 0.0 ? -1.0 : 1.0;
	float cycle = fract(phase + (side > 0.0 ? 0.5 : 0.0));
	float support = stance[mode-1];
	float u = clamp((cycle-support)/(1.0-support),0.0,1.0);
	float pitch = radians(14.0)*sin(TAU*u)*sin(PI*u);
	vec4 key = sample_authored_gait(mode,phase,side>0.0);
	vec3 hip = vec3(side*.105,.89,0.0);
	vec3 knee = vec3(side*.119,.49,.012);
	vec3 ankle = vec3(side*.126,.12,0.0);
	vec3 upper = hip + rotate_guard_x(p-hip,key.x);
	vec3 lower = hip + rotate_guard_x(knee+rotate_guard_x(p-knee,key.y)-hip,key.x);
	vec3 foot = ankle + rotate_guard_x(p-ankle,pitch) + foot_offset(cycle,stride,support,clearance[mode-1]) - vec3(0.0,key.w,0.0);
	float ankle_weight = 1.0-smoothstep(.10,.19,p.y);
	float shin_weight = 1.0-smoothstep(.40,.58,p.y);
	float leg_weight = (1.0-smoothstep(.205,.27,abs(p.x)))*(1.0-smoothstep(.75,.95,p.y));
	return mix(p,mix(upper,mix(lower,foot,ankle_weight),shin_weight),leg_weight)+vec3(0.0,key.w,0.0);
}

void vertex() {
	float phase = INSTANCE_CUSTOM.r + step_fraction*INSTANCE_CUSTOM.g;
	int mode = int(round(INSTANCE_CUSTOM.a));
	if (mode >= 1 && mode <= 3) {
		VERTEX = gait_vertex(VERTEX,mode,phase,INSTANCE_CUSTOM.b);
	} else {
		if (mode >= 6 && mode <= 8) { VERTEX = guard_vertex(VERTEX); }
		float lean = upper_lean(phase, mode);
		float weight = smoothstep(0.65, 1.18, VERTEX.y);
		vec3 upper = VERTEX - vec3(0.0, 0.8, 0.0);
		vec3 bent = vec3(upper.x, cos(lean)*upper.y - sin(lean)*upper.z, sin(lean)*upper.y + cos(lean)*upper.z);
		VERTEX = mix(VERTEX, vec3(0.0, 0.8, 0.0) + bent, weight);
	}
	// COLOR contains local previous-root displacement and signed yaw delta.
	// Interpolate the full transform, including turns and terrain height.
	float turn = COLOR.a * (1.0 - step_fraction);
	VERTEX = vec3(cos(turn)*VERTEX.x + sin(turn)*VERTEX.z, VERTEX.y, -sin(turn)*VERTEX.x + cos(turn)*VERTEX.z);
	NORMAL = vec3(cos(turn)*NORMAL.x + sin(turn)*NORMAL.z, NORMAL.y, -sin(turn)*NORMAL.x + cos(turn)*NORMAL.z);
	VERTEX += COLOR.rgb * (1.0 - step_fraction);
}

void fragment() {
	ALBEDO = texture(pigments, UV).rgb;
	vec3 surface = texture(finish_map, UV).rgb;
	ROUGHNESS = surface.g;
	METALLIC = surface.b;
}
