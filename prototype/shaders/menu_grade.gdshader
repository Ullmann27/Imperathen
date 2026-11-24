shader_type canvas_item;
// Main-menu grade over the 3D village: dusk tone, a deep vignette and light
// shafts from the upper right, so the frontier reads as a Roman stage.
// Premultiplied blending: the tone darkens the world, the shafts add light.
render_mode blend_premul_alpha;

uniform float aspect = 1.7778;
uniform float strength = 1.0;
uniform float shaft = 1.0;

void fragment() {
	float t = TIME;
	vec2 uv = UV;
	vec2 c = (uv - vec2(0.5, 0.45)) * vec2(aspect, 1.0) / min(aspect, 1.0);
	float vig = smoothstep(0.25, 1.05, length(c * vec2(0.62, 0.95)));
	float dark = clamp((0.28 + 0.62 * vig) * strength, 0.0, 0.93);
	vec3 tone = vec3(0.09, 0.035, 0.018);
	vec2 from_light = (uv - vec2(0.95, -0.12)) * vec2(aspect, 1.0) / min(aspect, 1.0);
	float angle = atan(from_light.y, from_light.x);
	float rays = pow(max(0.0, sin(angle * 13.0 + t * 0.05)), 5.0) * 0.6 + pow(max(0.0, sin(angle * 29.0 - t * 0.04)), 9.0) * 0.4;
	float reach = smoothstep(1.5, 0.05, length(from_light)) * (1.0 - vig * 0.6);
	vec3 glow = vec3(1.0, 0.64, 0.3) * rays * reach * 0.16 * shaft;
	COLOR = vec4(tone * dark + glow, dark);
}
