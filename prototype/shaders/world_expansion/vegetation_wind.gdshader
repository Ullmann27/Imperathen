shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_burley;

// COLOR is an authored deformation payload: R branch flexibility,
// G leaf-tip flutter, B stable leaf phase. It is never albedo.
uniform float wind_time = 0.0;
uniform float wind_strength : hint_range(0.0, 2.0) = 0.6;
uniform vec2 wind_direction = vec2(0.8944272, 0.4472136);
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo_texture = false;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal_texture = false;
uniform float normal_scale = 1.0;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_roughness_texture = false;
uniform vec4 roughness_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float roughness_factor : hint_range(0.0, 1.0) = 0.85;
uniform float metallic_factor : hint_range(0.0, 1.0) = 0.0;
uniform float specular_factor : hint_range(0.0, 1.0) = 0.3;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);

void vertex() {
	vec2 direction = wind_direction / max(length(wind_direction), 0.0001);
	vec3 anchor = MODEL_MATRIX[3].xyz;
	float phase = dot(anchor.xz, vec2(0.173, 0.219));
	float leaf_phase = phase + COLOR.b * 6.28318530718;
	float gust = sin(wind_time * 1.15 + phase) * 0.72
		+ sin(wind_time * 0.47 + phase * 0.73) * 0.28;
	float bend = clamp(COLOR.r, 0.0, 1.0) * gust * wind_strength * 0.20;
	float flutter = clamp(COLOR.g, 0.0, 1.0)
		* sin(wind_time * 5.3 + leaf_phase * 1.71) * wind_strength * 0.024;
	// Both terms are exactly zero at an authored R=G=0 root.
	VERTEX.xz += direction * bend + vec2(-direction.y, direction.x) * flutter;
	VERTEX.y += flutter * 0.35;
}

void fragment() {
	vec2 sample_uv = UV * uv_scale + uv_offset;
	vec4 color_sample = base_color;
	if (has_albedo_texture) {
		color_sample *= texture(albedo_texture, sample_uv);
	}
	ALBEDO = color_sample.rgb;
	ROUGHNESS = roughness_factor;
	if (has_roughness_texture) {
		ROUGHNESS *= dot(texture(roughness_texture, sample_uv), roughness_channel);
	}
	ROUGHNESS = clamp(ROUGHNESS, 0.04, 1.0);
	METALLIC = metallic_factor;
	SPECULAR = specular_factor;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	if (has_normal_texture) {
		NORMAL_MAP = texture(normal_texture, sample_uv).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
}
