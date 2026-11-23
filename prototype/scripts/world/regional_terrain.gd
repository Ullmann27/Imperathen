extends Node3D
## Bounded terrain residency. The authored village remains the only inhabited region.
## All sectors share edge spacing: changing detail rings cannot open terrain cracks.

const Plan = preload("res://scripts/world/world_stream_plan.gd")
const GRID := 12
var sectors: Dictionary = {}
var demand: Dictionary = {}
var _last_cell := ""
var _last_quality := ""
var _pending: Array = []
var _ground: StandardMaterial3D
var loaded_triangles := 0


func _ready() -> void:
	_ground = StandardMaterial3D.new()
	_ground.vertex_color_use_as_albedo = true
	_ground.roughness = 0.95
	_ground.cull_mode = BaseMaterial3D.CULL_BACK


func follow(position: Vector3, quality: String) -> void:
	var cell: Vector2i = Plan.sector_for_position(position)
	if not Plan.sector_valid(cell):
		return
	var key := "%s:%s" % [cell.x, cell.y]
	if key != _last_cell or quality != _last_quality:
		_last_cell = key
		_last_quality = quality
		demand = Plan.plan(position, quality)
		var wanted: Dictionary = {}
		_pending.clear()
		for entry: Dictionary in demand.get("sectors", []):
			wanted[entry.id] = true
			if sectors.has(entry.id):
				_set_collision(sectors[entry.id], bool(entry.collision))
			else:
				_pending.append(entry)
		for id: String in sectors.keys():
			if not wanted.has(id):
				var node: Node3D = sectors[id]
				remove_child(node)
				node.free()
				sectors.erase(id)
	for _index in mini(2, _pending.size()):
		var entry: Dictionary = _pending.pop_front()
		var sector := _make_sector(entry)
		add_child(sector)
		sectors[entry.id] = sector
	loaded_triangles = sectors.size() * GRID * GRID * 2


func _make_sector(entry: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "Terrain_" + str(entry.id).replace(":", "_")
	var origin: Array = entry.origin
	node.position = Vector3(float(origin[0]), 0, float(origin[2]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	var step := Plan.SECTOR_SIZE_M / float(GRID)
	for z in GRID:
		for x in GRID:
			var a := _vertex(node.position, x * step, z * step)
			var b := _vertex(node.position, (x + 1) * step, z * step)
			var c := _vertex(node.position, x * step, (z + 1) * step)
			var d := _vertex(node.position, (x + 1) * step, (z + 1) * step)
			for point: Vector3 in [a, b, c, b, d, c]:
				var global_point := point + node.position
				var variation := 0.5 + 0.5 * sin(global_point.x * 0.021) * cos(global_point.z * 0.019)
				var earth := Color("67704b").lerp(Color("9b9868"), variation * 0.7)
				if point.y > 120:
					earth = earth.lerp(Color("8c8877"), clampf((point.y - 120.0) / 140.0, 0, 1))
				surface.set_color(earth)
				surface.set_uv(Vector2(global_point.x, global_point.z) * 0.04)
				surface.add_vertex(point)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "Ground"
	mesh.mesh = surface.commit()
	mesh.material_override = _ground
	node.add_child(mesh)
	_set_collision(node, bool(entry.collision))
	return node


func _vertex(origin: Vector3, x: float, z: float) -> Vector3:
	var height: float = Plan.terrain_height(Vector2(origin.x + x, origin.z + z))
	return Vector3(x, height - 0.06, z)


func _set_collision(node: Node3D, enabled: bool) -> void:
	var collision := node.get_node_or_null("GroundCollision")
	if enabled and collision == null:
		var body := StaticBody3D.new()
		body.name = "GroundCollision"
		var shape := CollisionShape3D.new()
		shape.shape = (node.get_node("Ground") as MeshInstance3D).mesh.create_trimesh_shape()
		body.add_child(shape)
		node.add_child(body)
	elif not enabled and collision != null:
		node.remove_child(collision)
		collision.free()


func report() -> Dictionary:
	var collisions := 0
	for node: Node3D in sectors.values():
		if node.has_node("GroundCollision"):
			collisions += 1
	return {"loaded_sectors":sectors.size(), "pending_sectors":_pending.size(),
		"collision_sectors":collisions, "triangles":loaded_triangles,
		"active_limit":demand.get("active_limit", 0), "world_size_m":Plan.WORLD_SIZE_M,
		"inhabited_content":"authored village; distant settlements remain planned"}
