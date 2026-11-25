extends Node3D
## Streets use bounded spatial batches. Overview uses one far-LOD batch per asset.
## Camera motion updates batch visibility, never thousands of object transforms.
const CHUNK_METRES := 64.0
const BATCH_REFRESH_BUDGET := 48
const PROFILES := {
	"low": {"near": 0.0, "middle": 58.0, "distance": 190.0, "shadow": 0},
	"balanced": {"near": 48.0, "middle": 150.0, "distance": 430.0, "shadow": 1},
	"high": {"near": 80.0, "middle": 260.0, "distance": 780.0, "shadow": 1},
	"very_high": {"near": 115.0, "middle": 390.0, "distance": 1250.0, "shadow": 1}
}
var profile := "balanced"
var overview := false
var overview_distance := 1800.0
var camera: Camera3D
var asset_library: RefCounted
var layout: Dictionary = {}
var batches: Array[Dictionary] = []
var _overview_batches: Array[Dictionary] = []
var _cursor := 0
var _last_refresh_count := 0
var _viewer := Vector3.ZERO


func _process(_delta: float) -> void:
	if camera == null or batches.is_empty():
		return
	refresh_budgeted(camera.global_position)


func populate(next_layout: Dictionary, library: RefCounted) -> Dictionary:
	if not bool(next_layout.get("ok", false)):
		return {"ok": false, "message": str(next_layout.get("message", "Ungültiger Siedlungsplan."))}
	for key in ["buildings", "roads", "vegetation"]:
		for entry: Dictionary in next_layout.get(key, []):
			if not library.assets.has(str(entry.asset)):
				return {"ok": false, "message": "Modell nicht geladen: " + str(entry.asset)}
	# clear() releases this view's references without mutating the caller's plan.
	clear()
	asset_library = library
	layout = next_layout
	var groups := _groups(true)
	for key: String in groups:
		var group: Dictionary = groups[key]
		var cell: Vector2i = group.cell
		var origin := Vector3((float(cell.x) + 0.5) * CHUNK_METRES, 0.0, (float(cell.y) + 0.5) * CHUNK_METRES)
		batches.append(_make_batch(group, origin, "Street_" + key.replace(":", "_")))
	_cursor = 0
	if overview:
		_build_overview_batches()
	refresh_all(camera.global_position if camera != null else Vector3.ZERO)
	return {"ok": true, "building_count": layout.get("building_count", 0), "batch_count": _active_batches().size()}


func _groups(spatial: bool) -> Dictionary:
	var groups := {}
	for kind in ["buildings", "roads", "vegetation"]:
		for entry: Dictionary in layout.get(kind, []):
			var at: Vector3 = entry.position
			var cell := Vector2i(floori(at.x / CHUNK_METRES), floori(at.z / CHUNK_METRES))
			var key := "%d:%d:%s" % [cell.x, cell.y, str(entry.asset)] if spatial else str(entry.asset)
			if not groups.has(key):
				groups[key] = {"cell": cell, "asset": str(entry.asset), "kind": kind, "poses": []}
			var basis := Basis(Vector3.UP, float(entry.get("yaw", 0.0))).scaled(Vector3.ONE * float(entry.get("scale", 1.0)))
			groups[key].poses.append(Transform3D(basis, at))
	return groups


func _make_batch(group: Dictionary, origin: Vector3, label: String) -> Dictionary:
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.position = origin
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = asset_library.assets[group.asset].meshes[2]
	node.multimesh.instance_count = group.poses.size()
	var asset_bounds: AABB = asset_library.assets[group.asset].meshes[0].get_aabb()
	for level in [1, 2]:
		asset_bounds = asset_bounds.merge(asset_library.assets[group.asset].meshes[level].get_aabb())
	var first := true
	var bounds := AABB()
	var local_poses: Array[Transform3D] = []
	for index in group.poses.size():
		var pose: Transform3D = group.poses[index]
		pose.origin -= origin
		node.multimesh.set_instance_transform(index, pose)
		local_poses.append(pose)
		var instance_bounds: AABB = pose * asset_bounds
		bounds = instance_bounds if first else bounds.merge(instance_bounds)
		first = false
	# Shader displacement is <0.449 m horizontally at maximum wind.
	var margin := 0.65 if bool(asset_library.assets[group.asset].wind) else 0.05
	bounds = bounds.grow(margin)
	node.multimesh.custom_aabb = bounds
	node.extra_cull_margin = 0.0
	add_child(node)
	return {"node": node, "asset": group.asset, "kind": group.kind, "count": group.poses.size(),
		"bounds": AABB(bounds.position + origin, bounds.size), "lod": 2, "local_poses": local_poses}


func _build_overview_batches() -> void:
	if not _overview_batches.is_empty():
		return
	var groups := _groups(false)
	for key: String in groups:
		_overview_batches.append(_make_batch(groups[key], Vector3.ZERO, "Overview_" + key))


func _active_batches() -> Array[Dictionary]:
	return _overview_batches if overview else batches


func clear() -> void:
	for batch in batches + _overview_batches:
		var node: Node = batch.node
		remove_child(node)
		node.free()
	batches.clear()
	_overview_batches.clear()
	layout = {}
	asset_library = null
	_cursor = 0


func set_quality(next_profile: String) -> void:
	profile = next_profile if PROFILES.has(next_profile) else "balanced"
	refresh_all(camera.global_position if camera != null else _viewer)


func set_overview(enabled: bool, distance: float = 1800.0) -> void:
	overview = enabled
	overview_distance = maxf(50.0, distance)
	if enabled and asset_library != null:
		_build_overview_batches()
	for batch in batches:
		batch.node.visible = false
	for batch in _overview_batches:
		batch.node.visible = false
	_cursor = 0
	refresh_all(camera.global_position if camera != null else _viewer)


func refresh_budgeted(viewer: Vector3) -> void:
	_last_refresh_count = 0
	var active := _active_batches()
	if not viewer.is_finite() or active.is_empty():
		return
	_viewer = viewer
	for _index in mini(BATCH_REFRESH_BUDGET, active.size()):
		_refresh_batch(active[_cursor], viewer)
		_cursor = (_cursor + 1) % active.size()
		_last_refresh_count += 1


func refresh_all(viewer: Vector3) -> void:
	if not viewer.is_finite():
		return
	_viewer = viewer
	for batch in _active_batches():
		_refresh_batch(batch, viewer)
	_cursor = 0


func _refresh_batch(batch: Dictionary, viewer: Vector3) -> void:
	var budget: Dictionary = PROFILES[profile]
	var bounds: AABB = batch.bounds
	var nearest := Vector3(clampf(viewer.x, bounds.position.x, bounds.end.x),
		clampf(viewer.y, bounds.position.y, bounds.end.y), clampf(viewer.z, bounds.position.z, bounds.end.z))
	var distance := viewer.distance_to(nearest)
	var limit := overview_distance if overview else float(budget.distance)
	var node: MultiMeshInstance3D = batch.node
	node.visible = distance <= limit
	if not node.visible:
		return
	var level := 2 if overview else (0 if distance < float(budget.near) else (1 if distance < float(budget.middle) else 2))
	if level != int(batch.lod):
		node.multimesh.mesh = asset_library.assets[batch.asset].meshes[level]
		batch.lod = level
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if int(budget.shadow) > 0 and level < 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func report() -> Dictionary:
	var selected_lods := [0, 0, 0]
	var distance_buildings := 0
	var distance_plants := 0
	var distance_roads := 0
	var enabled_batches := 0
	var triangles := 0
	var surfaces := 0
	for batch in _active_batches():
		var node: MultiMeshInstance3D = batch.node
		if not node.visible:
			continue
		enabled_batches += 1
		var count := int(batch.count)
		var level := int(batch.lod)
		selected_lods[level] += count
		triangles += count * int(asset_library.assets[batch.asset].triangles[level])
		surfaces += node.multimesh.mesh.get_surface_count()
		if batch.kind == "buildings":
			distance_buildings += count
		elif batch.kind == "vegetation":
			distance_plants += count
		else:
			distance_roads += count
	return {"profile": profile, "overview": overview, "placed_buildings": int(layout.get("building_count", 0)),
		"unique_building_modules": int(layout.get("unique_building_modules", 0)),
		"placed_vegetation": layout.get("vegetation", []).size(), "placed_road_tiles": layout.get("roads", []).size(),
		"batch_count": _active_batches().size(), "stored_batch_count": batches.size() + _overview_batches.size(),
		"distance_enabled_batches": enabled_batches, "distance_enabled_buildings": distance_buildings,
		"distance_enabled_vegetation": distance_plants, "distance_enabled_roads": distance_roads,
		"distance_enabled_lod_instances": selected_lods, "distance_enabled_triangles_upper_bound": triangles,
		"distance_enabled_surfaces": surfaces, "batch_refresh_budget": BATCH_REFRESH_BUDGET,
		"last_refresh_count": _last_refresh_count,
		"distance_limit_m": overview_distance if overview else PROFILES[profile].distance,
		"measurement_scope": "distance residency; actual frustum/occlusion rendering may be lower"}
