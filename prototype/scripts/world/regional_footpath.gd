extends RefCounted
## The eastern way out of Valdora. The visible entrance uses the existing
## village floor; the surveyed extension follows the streamed terrain to the
## old quarry and the spur to Weidenhof.

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


## Fictional wayside settlement on a spur at the third surveyed waypoint.
const HAMLET := Vector2(241,119)
const HAMLET_ID := "willow_station"
const DESTINATIONS := {"mission":"Missionsziel","willow_station":"Weidenhof","stone_quarry":"Alter Steinbruch","home_village":"Valdora"}

static func destination(id: String) -> Vector2:
	if id == HAMLET_ID:
		return HAMLET
	if id == "stone_quarry":
		return WAYPOINTS[-1]
	return WAYPOINTS[0]

static func _road_offset(point: Vector2) -> float:
	var best_distance := INF
	var best_offset := 0.0
	var offset := 0.0
	for i in range(1,WAYPOINTS.size()):
		var a := WAYPOINTS[i-1]
		var b := WAYPOINTS[i]
		var closest := Geometry2D.get_closest_point_to_segment(point,a,b)
		var distance := point.distance_squared_to(closest)
		if distance < best_distance:
			best_distance = distance
			best_offset = offset + a.distance_to(closest)
		offset += a.distance_to(b)
	return best_offset

static func route_between(start: Vector2, goal: Vector2) -> PackedVector2Array:
	var a := _road_offset(start)
	var b := _road_offset(goal)
	if a > b:
		var reversed := route_between(goal,start)
		reversed.reverse()
		return reversed
	var line := PackedVector2Array([start])
	var offset := 0.0
	for i in range(1,WAYPOINTS.size()):
		var prev := WAYPOINTS[i-1]
		var next := WAYPOINTS[i]
		var length := prev.distance_to(next)
		if a >= offset and a < offset + length:
			line.append(prev.lerp(next,(a-offset)/length))
		if offset+length > a and offset+length <= b:
			line.append(next)
		if b >= offset and b < offset+length:
			line.append(prev.lerp(next,(b-offset)/length))
		offset += length
	line.append(goal)
	return line

## Extend the dirt strip across the actual streamed collision terrain. Only
## segments whose midpoint belongs to this sector are built, including the spur.
static func add_tracks(sector: Node3D, size_m: float, height: Callable) -> void:
	var area := Rect2(Vector2(sector.position.x,sector.position.z),Vector2.ONE*size_m)
	var triangles := SurfaceTool.new()
	triangles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var links: Array = []
	for i in range(2, WAYPOINTS.size()):
		links.append([WAYPOINTS[i-1],WAYPOINTS[i]])
	links.append([WAYPOINTS[2],HAMLET])
	for link: Array in links:
		var a: Vector2 = link[0]
		var b: Vector2 = link[1]
		if not Rect2(a,Vector2.ZERO).expand(b).grow(2.0).intersects(area):
			continue
		var side := a.direction_to(b).orthogonal()
		var parts := ceili(a.distance_to(b)/3.0)
		for i in parts:
			var p := a.lerp(b,float(i)/parts)
			var q := a.lerp(b,float(i+1)/parts)
			if not area.has_point((p+q)*0.5):
				continue
			var edges := [-1.5,-1.14,-.61,.61,1.14,1.5]
			for j in range(edges.size()-1):
				var tone := Color("595239") if j in [0,4] else (Color("81684a") if j in [1,3] else Color("77664c"))
				for corner: Vector2 in [p+side*edges[j],q+side*edges[j],q+side*edges[j+1],p+side*edges[j],q+side*edges[j+1],p+side*edges[j+1]]:
					var ground := float(height.call(corner))
					triangles.set_color(tone)
					triangles.set_normal(Vector3.UP)
					triangles.add_vertex(Vector3(corner.x, ground + .044,corner.y)-sector.position)
				count += 1
	if not count:
		return
	var strip := MeshInstance3D.new()
	strip.name = "CartTrack"
	strip.mesh = triangles.commit()
	var earth := StandardMaterial3D.new()
	earth.vertex_color_use_as_albedo = true
	earth.cull_mode = BaseMaterial3D.CULL_DISABLED
	earth.roughness = .98
	strip.material_override = earth
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sector.add_child(strip)
