extends RefCounted
## A visible workplace streamed with its terrain cell. The terminal route
## waypoint stays clear on the natural ground in front of the excavation.

const Footpath = preload("res://scripts/world/regional_footpath.gd")
const MeshyWorldProps = preload("res://scripts/visuals/meshy_world_props.gd")
const SITE_NAME := "OldQuarry"
const COLLISION_NAME := "QuarryStructures"
const VISUAL_PATH := "res://assets/world/road_landmarks/old_quarry.glb"
const COLLISION_PATH := "res://assets/world/road_landmarks/old_quarry_collision.glb"
const FRONT_CLEARANCE_M := 4.0


static func approach_direction() -> Vector2:
	return Footpath.WAYPOINTS[-2].direction_to(Footpath.WAYPOINTS[-1])


static func site_coordinates() -> Vector2:
	return Footpath.WAYPOINTS[-1] + approach_direction() * FRONT_CLEARANCE_M


static func add_site(sector: Node3D, sector_size: float, surface_height: Callable) -> void:
	var point := site_coordinates()
	var area := Rect2(Vector2(sector.position.x, sector.position.z), Vector2.ONE * sector_size)
	if not area.has_point(point):
		return
	var visual_scene := load(VISUAL_PATH) as PackedScene
	if visual_scene == null:
		return
	var site := Node3D.new()
	site.name = SITE_NAME
	site.position = Vector3(point.x, surface_height.call(point) + 0.04, point.y) - sector.position
	var front := approach_direction()
	site.rotation.y = atan2(-front.y, front.x)
	site.add_child(visual_scene.instantiate())
	# The original quarry remains the worksite; the exact Meshy limestone
	# formation becomes visible at its side, with no new resource credit.
	var limestone := MeshyWorldProps.instantiate("resource_limestone", 1)
	if limestone != null:
		limestone.name = "MeshyLimestone"
		limestone.position = Vector3(0,0,2.6)
		limestone.scale = Vector3.ONE * 0.72
		site.add_child(limestone)
	sector.add_child(site)


static func add_collision(sector: Node3D) -> void:
	var site := sector.get_node_or_null(SITE_NAME) as Node3D
	if site == null:
		return
	var proxy_scene := load(COLLISION_PATH) as PackedScene
	if proxy_scene == null:
		return
	var proxy := proxy_scene.instantiate() as Node3D
	var faces := PackedVector3Array()
	for mesh: MeshInstance3D in proxy.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var relative := mesh.transform
		var ancestor := mesh.get_parent() as Node3D
		while ancestor != null:
			relative = ancestor.transform * relative
			ancestor = ancestor.get_parent() as Node3D
		for vertex: Vector3 in mesh.mesh.get_faces():
			faces.append(relative * vertex)
	proxy.free()
	if faces.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = COLLISION_NAME
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	site.add_child(body)


static func remove_collision(sector: Node3D) -> void:
	var body := sector.get_node_or_null(SITE_NAME + "/" + COLLISION_NAME)
	if body != null:
		body.free()
