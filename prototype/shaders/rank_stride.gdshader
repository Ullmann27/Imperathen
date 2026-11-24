shader_type spatial;
uniform sampler2D pigments : source_color, filter_linear_mipmap;
uniform sampler2D finish_map : filter_nearest;
uniform float step_fraction : hint_range(0.0, 1.0) = 1.0;
uniform vec3 stance = vec3(0.58, 0.40, 0.51);
uniform vec3 clearance = vec3(0.106, 0.19, 0.134);

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

void vertex() {
	float phase = INSTANCE_CUSTOM.r + step_fraction*INSTANCE_CUSTOM.g;
	int mode = int(round(INSTANCE_CUSTOM.a));
	if (mode >= 1 && mode <= 3) {
		float leg = (1.0 - smoothstep(0.10, 0.74, VERTEX.y)) * (1.0 - smoothstep(0.205, 0.27, abs(VERTEX.x)));
		float offset = VERTEX.x < 0.0 ? 0.0 : 0.5;
		float t = fract(phase + offset);
		if (VERTEX.y <= 0.121 && abs(VERTEX.x) < 0.205 && t > stance[mode-1]) {
			float u = (t - stance[mode-1]) / (1.0 - stance[mode-1]);
			float pitch = radians(14.0)*sin(TAU*u)*sin(PI*u);
			vec3 ankle = vec3(VERTEX.x < 0.0 ? -0.126 : 0.126, 0.12, 0.0);
			vec3 foot = VERTEX - ankle;
			VERTEX = ankle + vec3(foot.x, cos(pitch)*foot.y - sin(pitch)*foot.z, sin(pitch)*foot.y + cos(pitch)*foot.z);
		}
		float lift = mode == 2 ? -0.068 - 0.062*cos(TAU*phase*2.0) : -0.088 - 0.035*cos(TAU*phase*2.0);
		float pelvis_weight = smoothstep(0.12, 0.78, VERTEX.y);
		VERTEX += foot_offset(phase + offset, INSTANCE_CUSTOM.b, stance[mode-1], clearance[mode-1]) * leg + vec3(0.0, lift*pelvis_weight, 0.0);
	} else {
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
