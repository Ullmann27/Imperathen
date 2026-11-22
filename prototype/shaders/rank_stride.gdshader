shader_type spatial;
uniform sampler2D pigments : source_color, filter_linear_mipmap;
uniform sampler2D finish_map : filter_nearest;
uniform float step_fraction : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// The far mesh has a separate silhouette for each leg. The simulation supplies
	// the same measured stride phase used by nearby skeletons, including on pause.
	float phase = TAU * (INSTANCE_CUSTOM.r + step_fraction * INSTANCE_CUSTOM.g);
	float amplitude = INSTANCE_CUSTOM.a;
	float leg = 1.0 - smoothstep(0.10, 0.74, VERTEX.y);
	// Exclude the spear, bow and shield from the leg envelope.
	leg *= 1.0 - smoothstep(0.18, 0.235, abs(VERTEX.x));
	float swing = sin(phase) * sign(VERTEX.x);
	VERTEX.z += swing * amplitude * leg * 0.28;
	VERTEX.y += max(0.0, cos(phase) * sign(VERTEX.x)) * leg * amplitude * 0.072;
	VERTEX.z -= (1.0 - step_fraction) * INSTANCE_CUSTOM.b * 2.0;
}

void fragment() {
	ALBEDO = texture(pigments, UV).rgb;
	vec3 surface = texture(finish_map, UV).rgb;
	ROUGHNESS = surface.g;
	METALLIC = surface.b;
}
