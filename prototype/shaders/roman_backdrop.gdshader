shader_type canvas_item;
// Menu backdrop over the live game: the world stays recognisable but recedes
// (desaturated warm grade, soft darkening, vignette) so a Roman tablet in
// front of it reads clearly. Works with the Compatibility renderer.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.5;
uniform float desaturate : hint_range(0.0, 1.0) = 0.7;
uniform vec2 focus = vec2(0.5, 0.5);

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 sepia = vec3(luma) * vec3(1.05, 0.97, 0.86);
	vec3 graded = mix(color, sepia, desaturate * amount);
	vec2 offset = (UV - focus) * vec2(1.25, 1.0);
	float vignette = smoothstep(0.2, 0.95, length(offset));
	graded *= 1.0 - darkness * amount * (0.6 + 0.4 * vignette);
	COLOR = vec4(graded, 1.0);
}
