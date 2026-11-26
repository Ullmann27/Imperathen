shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_burley;
// Far tree card: one quad turned toward the camera about the vertical axis.
// The atlas holds 8 orthographic views of LOD0 (albedo with baked occlusion,
// camera-space normals); the view nearest to the camera azimuth in the tree's
// own frame is shown and lit with that view's normals.
#include "res://scripts/vegetation/vegetation_wind.gdshaderinc"

uniform sampler2D impostor_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D impostor_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float frame_size = 10.0;
uniform float center_height = 5.0;
uniform float views = 8.0;
uniform float alpha_cut = 0.5;
uniform vec3 season_tint : source_color = vec3(1.0);
uniform vec3 autumn_color : source_color = vec3(0.74, 0.50, 0.17);
uniform float autumn = 0.0;
uniform float leaf_presence = 1.0;
varying vec3 frame_dir;
varying vec3 frame_right;
varying float variation;

void vertex() {
	vec3 anchor = MODEL_MATRIX[3].xyz;
	mat3 basis = mat3(MODEL_MATRIX);
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 to_camera = CAMERA_POSITION_WORLD - anchor;
	to_camera.y = 0.0;
	vec3 d = length(to_camera) > 0.001 ? normalize(to_camera) : vec3(0.0, 0.0, 1.0);
	vec3 local_dir = normalize(transpose(basis) * d);
	float step_angle = 6.2832 / views;
	float k = mod(floor(atan(local_dir.x, local_dir.z) / step_angle + 0.5) + views, views);
	vec3 local_frame = vec3(sin(k * step_angle), 0.0, cos(k * step_angle));
	frame_dir = normalize(basis * local_frame);
	frame_right = normalize(cross(vec3(0.0, 1.0, 0.0), frame_dir));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), d));
	float lx = UV.x - 0.5;
	float ly = 1.0 - UV.y;
	float t = wind_time >= 0.0 ? wind_time : TIME;
	vec3 wind = normalize(vec3(wind_direction.x, 0.0, wind_direction.y));
	float sway = sin(t * 0.83 + vegetation_hash(anchor.xz) * 6.2832) * 0.5 + 0.7;
	VERTEX = anchor + right * lx * frame_size * s + vec3(0.0, center_height - frame_size * 0.5 + ly * frame_size, 0.0) * s;
	VERTEX += wind * ly * ly * trunk_sway * plant_height * s * sway * wind_strength;
	NORMAL = d;
	UV = vec2((k + UV.x) / views, UV.y);
	variation = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec4 tex = texture(impostor_albedo, UV);
	vec3 c = tex.rgb * season_tint * mix(0.86, 1.08, variation);
	c = mix(c, autumn_color * (0.5 + 0.9 * tex.g), clamp(autumn * (0.45 + 0.9 * variation), 0.0, 1.0) * smoothstep(0.08, 0.2, tex.g - tex.r));
	ALBEDO = c;
	ALPHA = tex.a * mix(1.0, 0.75 + 0.25 * leaf_presence, step(tex.r, tex.g));
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec2 nxy = texture(impostor_normal, UV).rg * 2.0 - 1.0;
	vec3 n = vec3(nxy, sqrt(max(0.0, 1.0 - dot(nxy, nxy))));
	vec3 world_n = normalize(frame_right * n.x + vec3(0.0, 1.0, 0.0) * n.y + frame_dir * n.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	BACKLIGHT = c * 0.3;
}
