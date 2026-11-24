shader_type canvas_item;
// Marching legion silhouettes from the white coverage atlas: near-black figures,
// a warm rim where the backlight wraps around them, and mip blur for depth of field.

uniform vec4 body : source_color = vec4(0.03, 0.018, 0.016, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.58, 0.26, 1.0);
uniform float rim_strength = 1.0;
uniform vec2 light_dir = vec2(0.0, -1.0);
uniform float blur = 0.0;
uniform float opacity = 1.0;

void fragment() {
	float a = textureLod(TEXTURE, UV, blur).a;
	vec2 step_uv = TEXTURE_PIXEL_SIZE * (2.5 + blur * 2.0);
	float toward = textureLod(TEXTURE, UV + light_dir * step_uv, blur).a;
	float edge = clamp(a - toward, 0.0, 1.0);
	vec3 col = mix(body.rgb, rim.rgb, edge * rim_strength);
	COLOR = vec4(col, a * opacity * COLOR.a);
}
