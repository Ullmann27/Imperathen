extends Node3D
## Bounded terrain residency. The authored village remains the only inhabited region.
## All sectors share edge spacing: changing detail rings cannot open terrain cracks.

const Plan = preload("res://scripts/world/world_stream_plan.gd")
const Footpath = preload("res://scripts/world/regional_footpath.gd")
const Quarry = preload("res://scripts/world/regional_quarry.gd")
const GRID := 12
const MESH_BUILD_BUDGET := 2
const COLLIDER_BUILD_BUDGET := 2
const UNLOAD_BUDGET := 8
## A walking capsule can overlap an edge before its center changes sector.
## Keep the adjacent ground ready within one meter, including low quality.
const SUPPORT_MARGIN_M := 1.0
const MAX_RESIDENT_SECTORS := 145
## Authored sRGB ground albedo; the material declares vertex_color_is_srgb, which
## is a no-op in the Compatibility renderer and converts in Forward+/Mobile.
## These are the former #67704b/#9b9868/#8c8877 values taken through one
## sRGB-to-linear step: the albedo the north backdrop has always rendered with.
## The former values rendered about 1.8x lighter than the adjoining village
## verge (measured at the east edge of the village ground).
const EARTH_DRY := Color("232912")
const EARTH_FRESH := Color("545023")
const EARTH_STONE := Color("433f2f")
var sectors: Dictionary = {}
var demand: Dictionary = {}
var _last_cell := ""
var _last_quality := ""
var _last_support_key := ""
var _pending: Array = []
var _retiring: Array[String] = []
var _support_ids: Array[String] = []
var _collision_targets: Dictionary = {}
var _collision_order: Array[String] = []
var _ground: StandardMaterial3D
var loaded_triangles := 0
var _last_mesh_builds := 0
var _last_collider_builds := 0
var _last_unloads := 0


func _ready() -> void:
	_ground = StandardMaterial3D.new()
	_ground.vertex_color_use_as_albedo = true
	_ground.vertex_color_is_srgb = true
	_ground.roughness = 0.95
	_ground.cull_mode = BaseMaterial3D.CULL_BACK


func follow(position: Vector3, quality: String) -> void:
	var cell: Vector2i = Plan.sector_for_position(position)
	if not Plan.sector_valid(cell):
		return
	_last_mesh_builds = 0
	_last_collider_builds = 0
	_last_unloads = 0
	var profile := quality if Plan.PROFILES.has(quality) else "balanced"
	var key := Plan.sector_id(cell)
	var next_support := _support_sectors(position, cell)
	var support_key := ",".join(next_support)
	var demand_changed := key != _last_cell or profile != _last_quality
	if demand_changed:
		_last_cell = key
		_last_quality = profile
		demand = Plan.plan(position, profile)
		var wanted: Dictionary = {}
		_pending.clear()
		_retiring.clear()
		for entry: Dictionary in demand.get("sectors", []):
			wanted[entry.id] = true
			if not sectors.has(entry.id):
				_pending.append(entry)
		for id: String in sectors.keys():
			if not wanted.has(id):
				_retiring.append(id)
		_retiring.sort_custom(func(a: String, b: String) -> bool:
			var distance_a: float = sectors[a].position.distance_squared_to(position)
			var distance_b: float = sectors[b].position.distance_squared_to(position)
			return distance_a > distance_b if distance_a != distance_b else a < b)
	if demand_changed or support_key != _last_support_key:
		_last_support_key = support_key
		_support_ids = next_support
		_refresh_collision_targets()
		_prioritize_support_meshes()
	# Retire old geometry incrementally. During a profile reduction the report
	# exposes the remaining old sectors instead of claiming the new cap is met.
	for _index in mini(UNLOAD_BUDGET, _retiring.size()):
		var id: String = _retiring.pop_front()
		var node: Node3D = sectors[id]
		remove_child(node)
		node.free()
		sectors.erase(id)
		_last_unloads += 1
	while _last_mesh_builds < MESH_BUILD_BUDGET and not _pending.is_empty():
		var entry: Dictionary = _pending.front()
		# Immediate ground support has priority over the cosmetic residency cap.
		# Each call retires more meshes than it can create, so even teleports and
		# profile reductions remain under the largest existing profile's cap.
		if sectors.size() >= int(demand.active_limit) and not _support_ids.has(str(entry.id)):
			break
		_pending.pop_front()
		var sector := _make_sector(entry)
		add_child(sector)
		sectors[entry.id] = sector
		_last_mesh_builds += 1
	# Mesh creation and expensive trimesh construction have separate budgets.
	# Promotion of a resident mesh is no longer an unbounded special case.
	for id: String in _collision_order:
		if _last_collider_builds >= COLLIDER_BUILD_BUDGET:
			break
		if sectors.has(id) and not sectors[id].has_node("GroundCollision"):
			_set_collision(sectors[id], true)
			_last_collider_builds += 1
	loaded_triangles = sectors.size() * GRID * GRID * 2


func _support_sectors(position: Vector3, cell: Vector2i) -> Array[String]:
	var result: Array[String] = [Plan.sector_id(cell)]
	for x_offset: float in [-SUPPORT_MARGIN_M, SUPPORT_MARGIN_M]:
		for z_offset: float in [-SUPPORT_MARGIN_M, SUPPORT_MARGIN_M]:
			var neighbor: Vector2i = Plan.sector_for_position(position + Vector3(x_offset, 0, z_offset))
			var id: String = Plan.sector_id(neighbor)
			if not id.is_empty() and not result.has(id):
				result.append(id)
	return result


func _refresh_collision_targets() -> void:
	_collision_targets.clear()
	_collision_order.clear()
	for id: String in _support_ids:
		_collision_targets[id] = true
		_collision_order.append(id)
	for entry: Dictionary in demand.get("sectors", []):
		if bool(entry.collision) and not _collision_targets.has(entry.id):
			_collision_targets[entry.id] = true
			_collision_order.append(str(entry.id))
	# Collision removal is cheap and immediate; obsolete physics never remains
	# active solely because an old visual sector is awaiting retirement.
	for id: String in sectors:
		if not _collision_targets.has(id):
			_set_collision(sectors[id], false)


func _prioritize_support_meshes() -> void:
	var ordered: Array = []
	for id: String in _support_ids:
		for entry: Dictionary in _pending:
			if str(entry.id) == id:
				ordered.append(entry)
	for entry: Dictionary in _pending:
		if not _support_ids.has(str(entry.id)):
			ordered.append(entry)
	_pending = ordered


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
				surface.set_color(ground_color(global_point))
				surface.set_uv(Vector2(global_point.x, global_point.z) * 0.04)
				surface.add_vertex(point)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "Ground"
	mesh.mesh = surface.commit()
	mesh.material_override = _ground
	node.add_child(mesh)
	Footpath.add_entrance(node, Plan.SECTOR_SIZE_M)
	Quarry.add_site(node, Plan.SECTOR_SIZE_M, surface_height)
	return node


## sRGB albedo of the streamed ground at a global point (also used by the
## north backdrop so its rim carries exactly the terrain colour).
static func ground_color(global_point: Vector3) -> Color:
	var variation := 0.5 + 0.5 * sin(global_point.x * 0.021) * cos(global_point.z * 0.019)
	var earth := EARTH_DRY.lerp(EARTH_FRESH, variation * 0.7)
	if global_point.y > 120:
		earth = earth.lerp(EARTH_STONE, clampf((global_point.y - 120.0) / 140.0, 0, 1))
	return earth


## Height of the generated ground mesh (not the analytic field) at a global
## point: the same sector grid, the same -0.06 offset and the same diagonal
## split as _make_sector. Grid-aligned scenery can rest exactly on it.
static func surface_height(position: Vector2) -> float:
	if not position.is_finite():
		return INF
	var cell: Vector2i = Plan.sector_for_position(Vector3(position.x, 0, position.y))
	var origin: Vector3 = Plan.sector_origin(cell)
	var step := Plan.SECTOR_SIZE_M / float(GRID)
	var local := Vector2((position.x - origin.x) / step, (position.y - origin.z) / step)
	var ix := clampi(floori(local.x), 0, GRID - 1)
	var iz := clampi(floori(local.y), 0, GRID - 1)
	var fx := local.x - ix
	var fz := local.y - iz
	var x0 := origin.x + ix * step
	var z0 := origin.z + iz * step
	var a: float = Plan.terrain_height(Vector2(x0, z0))
	var b: float = Plan.terrain_height(Vector2(x0 + step, z0))
	var c: float = Plan.terrain_height(Vector2(x0, z0 + step))
	var d: float = Plan.terrain_height(Vector2(x0 + step, z0 + step))
	var height := a + (b - a) * fx + (c - a) * fz if fx + fz <= 1.0 else d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)
	return height - 0.06


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
		Quarry.add_collision(node)
	elif not enabled and collision != null:
		node.remove_child(collision)
		collision.free()
		Quarry.remove_collision(node)


func report() -> Dictionary:
	var collisions := 0
	for node: Node3D in sectors.values():
		if node.has_node("GroundCollision"):
			collisions += 1
	var pending_collisions := 0
	for id: String in _collision_order:
		if not sectors.has(id) or not sectors[id].has_node("GroundCollision"):
			pending_collisions += 1
	return {"loaded_sectors":sectors.size(), "pending_sectors":_pending.size(),
		"retiring_sectors":_retiring.size(), "pending_collisions":pending_collisions,
		"pending_work":_pending.size() + _retiring.size() + pending_collisions,
		"collision_sectors":collisions, "collision_limit":_collision_targets.size(),
		"support_sectors":_support_ids.size(), "triangles":loaded_triangles,
		"active_limit":demand.get("active_limit", 0), "resident_limit":MAX_RESIDENT_SECTORS,
		"last_mesh_builds":_last_mesh_builds, "last_collider_builds":_last_collider_builds,
		"last_unloads":_last_unloads, "quality":_last_quality,
		"world_size_m":Plan.WORLD_SIZE_M,
		"inhabited_content":"authored village; distant settlements remain planned"}
