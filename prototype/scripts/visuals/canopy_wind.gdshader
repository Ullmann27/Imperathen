shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Tree foliage cards with the original alpha-scissor look plus wind: whole
// boughs lean with slow gusts, leaves flutter. Height-weighted, so trunks and
// the root skirt stay planted. Shadows use the same displaced vertices.
uniform sampler2D foliage : source_color, filter_linear_mipmap;
uniform float alpha_cut = .37;
uniform float canopy_height = 7.0;
uniform float sway = 1.0;
uniform float fixed_time = -1.0;
uniform vec2 wind_direction = vec2(.83, .56);
varying float crown;

void vertex() {
	vec3 anchor = MODEL_MATRIX[3].xyz;
	float t = fixed_time >= 0.0 ? fixed_time : TIME;
	crown = clamp(VERTEX.y / canopy_height, 0.0, 1.0);
	float phase = dot(anchor.xz, vec2(.37, .23));
	float front = sin(dot(anchor.xz, wind_direction) * .23 - t * 1.35) * .5 + .5;
	float bough = sin(t * .92 + phase) * .55 + sin(t * 1.63 + phase * 1.31) * .22 + front * .5;
	float leaf = sin(t * 3.4 + dot(VERTEX, vec3(2.3, 1.7, 2.9)));
	VERTEX.xz += wind_direction * bough * .085 * crown * crown * sway;
	VERTEX += vec3(.6, .35, -.5) * leaf * .022 * crown * sway;
}

void fragment() {
	vec4 leaf = texture(foliage, UV);
	ALBEDO = leaf.rgb * mix(.82, 1.06, crown);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = .86;
	// Inner and lower leaves see less sky.
	AO = mix(.55, 1.0, crown);
	AO_LIGHT_AFFECT = 0.0;
}

void light() {
	// Wrapped diffuse and light through the leaves when looking toward the sun.
	float wrap = clamp((dot(NORMAL, LIGHT) + .3) / 1.3, 0.0, 1.0);
	float through = pow(clamp(dot(-VIEW, LIGHT), 0.0, 1.0), 6.0) * .3;
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * (wrap + through) / PI;
}
