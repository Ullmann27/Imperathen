extends RefCounted
## The eastern way out of Valdora. The visible entrance uses the existing
## village floor; the surveyed extension follows the streamed terrain to the
## planned quarry position. The quarry itself has no constructed location.

const WAYPOINTS: Array[Vector2] = [
	Vector2(46, -13), Vector2(90, -13), Vector2(250, 100),
	Vector2(430, -149), Vector2(620, -238), Vector2(860, -370),
	Vector2(1090, -464), Vector2(1280, -571), Vector2(1500, -750),
]
const ROAD_ID := "home_village__stone_quarry"


static func length_m() -> float:
	var distance := 0.0
	for i in range(1, WAYPOINTS.size()):
		distance += WAYPOINTS[i - 1].distance_to(WAYPOINTS[i])
	return distance


static func map_points() -> Array:
	var points := []
	for waypoint: Vector2 in WAYPOINTS:
		points.append([waypoint.x, 0.0, waypoint.y])
	return points


static func add_entrance(sector: Node3D, sector_size: float) -> void:
	var start := WAYPOINTS[0]
	var entrance_end := WAYPOINTS[1]
	var area := Rect2(Vector2(sector.position.x, sector.position.z), Vector2.ONE * sector_size)
	if not area.has_point(start):
		return
	var entrance := MeshInstance3D.new()
	entrance.name = "EastGateFootpath"
	entrance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ground_strip := PlaneMesh.new()
	ground_strip.size = Vector2(start.distance_to(entrance_end), 2.8)
	entrance.mesh = ground_strip
	var middle := (start + entrance_end) * 0.5
	# 24 mm above the shaded village floor (-0.008 m), without a second body.
	entrance.position = Vector3(middle.x, 0.016, middle.y) - sector.position
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_back;

float grain(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_at(vec2 point) {
	vec2 cell = floor(point);
	vec2 t = fract(point);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(grain(cell), grain(cell + vec2(1.0, 0.0)), t.x),
		mix(grain(cell + vec2(0.0, 1.0)), grain(cell + 1.0), t.x), t.y);
}

void fragment() {
	vec2 metres = UV * vec2(44.0, 2.8);
	float wander = (noise_at(vec2(metres.x * 0.23, 0.35)) - 0.5) * 0.20;
	float verge = abs(UV.y - 0.5 + wander) * 2.0;
	float edge_noise = (noise_at(metres * 5.0) - 0.5) * 0.52;
	float earth = noise_at(metres * 2.3) * 0.62 + noise_at(metres * 21.0) * 0.38;
	float dirt = clamp(earth + (1.0 - verge) * 0.16, 0.0, 1.0);
	ALBEDO = mix(vec3(0.16, 0.125, 0.075), vec3(0.37, 0.30, 0.20), dirt);
	ROUGHNESS = 0.96;
	ALPHA = (1.0 - smoothstep(0.46, 0.92, verge + edge_noise))
		* smoothstep(0.0, 0.045, UV.x) * (1.0 - smoothstep(0.93, 1.0, UV.x));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	entrance.material_override = material
	sector.add_child(entrance)
