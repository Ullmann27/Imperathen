shader_type spatial;
// Individual iris colour on the shared opaque eye atlas. The iris and pupil
// are found from the atlas itself (sclera bright, iris dark, pupil black), so
// no UV convention is assumed; only the iris hue changes per resident.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec3 iris_color : source_color = vec3(0.17, 0.10, 0.05);
uniform float reference_luminance = 0.035;
uniform float roughness = 0.31;

void fragment() {
	vec3 t = texture(albedo_texture, UV).rgb;
	float l = dot(t, vec3(0.299, 0.587, 0.114));
	float iris = 1.0 - smoothstep(0.10, 0.30, l);
	float pupil = 1.0 - smoothstep(0.002, 0.008, l);
	vec3 coloured = iris_color * clamp(l / reference_luminance, 0.25, 2.5);
	ALBEDO = mix(t, coloured, iris * (1.0 - pupil));
	ROUGHNESS = roughness;
	SPECULAR = 0.6;
}
