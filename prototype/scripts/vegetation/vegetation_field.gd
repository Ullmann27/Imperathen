extends Node3D
## Draws the Valdora vegetation from vegetation_ecology.gd with MultiMesh
## instancing. Trees, shrubs and vines are grouped in 32 m cells; when the
## camera moves, visible cells (frustum test) are sorted into one MultiMesh per
## asset and detail level (LOD0..LOD3, impostor), so the draw-call count
## depends on the species in view, not on the number of trees. Herb and crop
## clumps sit in static 16 m chunks (one MultiMesh each) whose density, mesh
## detail and range follow the graphics profile. Trunk colliders live in one
## server-side static body. Nothing here changes the simulation.

const Library = preload("res://scripts/vegetation/vegetation_library.gd")
const Ecology = preload("res://scripts/vegetation/vegetation_ecology.gd")
const Grass = preload("res://scripts/vegetation/vegetation_grass.gd")
const PROFILES := preload("res://assets/vegetation/vegetation_profiles.json")
const CELL := 32.0
const LEVELS := ["lod0", "lod1", "lod2", "lod3", "impostor"]
## Re-sorting is cheap but not free on a phone: the batches are rebuilt only
## after a real camera change. Cells are kept in a wider fan than the view so
## a turn of up to TURN_LIMIT degrees never reveals an empty edge.
const MOVE_LIMIT := 2.0
const TURN_LIMIT := 12.0
const FAN_MARGIN_DEG := 32.0
const ALWAYS_NEAR := 36.0
const MAX_INTERVAL := 1.0
const SEASON_TINT := [Color("#f2ffd8"), Color("#ffffff"), Color("#f4e2b8"), Color("#c9b89a")]
const SEASON_AUTUMN := [0.0, 0.0, 0.62, 0.9]
const SEASON_LEAVES := [1.0, 1.0, 0.85, 0.18]
const SEASON_BLOOM := [1.0, 0.75, 0.2, 0.0]
const SEASON_CROP := [0, 1, 2, 2]
const SEASON_DRY := [0.05, 0.35, 0.55, 0.3]
const SEASON_GUST := [0.9, 0.7, 1.35, 1.1]

var profile := "balanced"
var season := 1
var ecology: Ecology
var placed_trees := 0
var _cells: Dictionary = {}
var _assets: Dictionary = {}
var _batches: Dictionary = {}
var _card_chunks: Array = []
var _last_view := Transform3D()
var _last_fov := -1.0
var _since_refresh := 0.0
var _dirty := true
var _visible: Dictionary = {}
var _visible_cards := {"chunks": 0, "instances": 0, "triangles": 0}
var _body := RID()
var _shapes: Dictionary = {}
var _wind_time := -1.0
var grass: Grass


## ground_height: Callable(Vector2) -> float; legacy_sites: the existing
## village tree placements (their colliders already exist).
func build(ground_height: Callable, legacy_sites: Array, brook_source_z := -95.0) -> void:
	ecology = Ecology.new(ground_height, brook_source_z)
	ecology.build(legacy_sites)
	_build_cells()
	_build_cards()
	grass = Grass.new()
	grass.name = "GrassBlades"
	grass.ecology = ecology
	add_child(grass)
	set_quality(profile)
	apply_season(season)


func _build_cells() -> void:
	for tree: Dictionary in ecology.trees:
		var asset: String = tree.asset
		if not _assets.has(asset):
			_assets[asset] = Library.asset(asset)
		var info: Dictionary = _assets[asset]
		if info.lods.is_empty():
			continue
		var at: Vector3 = tree.position
		var key := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
		if not _cells.has(key):
			_cells[key] = {"blocks": {}, "positions": {}, "aabb": AABB(at, Vector3.ZERO)}
		var cell: Dictionary = _cells[key]
		var s: float = tree.scale
		var basis := Basis(Vector3.UP, float(tree.yaw)).scaled(Vector3.ONE * s)
		var c: Color = tree.custom
		if not cell.blocks.has(asset):
			cell.blocks[asset] = PackedFloat32Array()
			cell.positions[asset] = PackedVector3Array()
		var block: PackedFloat32Array = cell.blocks[asset]
		block.append_array([basis.x.x, basis.y.x, basis.z.x, at.x, basis.x.y, basis.y.y, basis.z.y, at.y,
			basis.x.z, basis.y.z, basis.z.z, at.z, c.r, c.g, c.b, c.a])
		cell.blocks[asset] = block
		var positions: PackedVector3Array = cell.positions[asset]
		positions.append(at)
		cell.positions[asset] = positions
		var reach: float = info.radius * s
		var box := AABB(at - Vector3(reach, 0.5, reach), Vector3(reach * 2.0, info.height * s + 1.0, reach * 2.0))
		cell.aabb = cell.aabb.merge(box)
		placed_trees += 1
	_attach_collision()


func _enter_tree() -> void:
	# A campaign city visit temporarily detaches the entire village.
	if ecology != null:
		_attach_collision.call_deferred()


func _attach_collision() -> void:
	if _body.is_valid() or ecology == null or ecology.colliders.is_empty() or not is_inside_tree():
		return
	_body = PhysicsServer3D.body_create()
	PhysicsServer3D.body_attach_object_instance_id(_body, get_instance_id())
	PhysicsServer3D.body_set_mode(_body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_collision_layer(_body, 1)
	PhysicsServer3D.body_set_collision_mask(_body, 0)
	for entry: Array in ecology.colliders:
		var radius: float = snappedf(entry[1], .05)
		if not _shapes.has(radius):
			var shape := PhysicsServer3D.box_shape_create()
			PhysicsServer3D.shape_set_data(shape, Vector3(radius * .85, 1.6, radius * .85))
			_shapes[radius] = shape
		PhysicsServer3D.body_add_shape(_body, _shapes[radius], Transform3D(Basis.IDENTITY, (entry[0] as Vector3) + Vector3.UP * 1.6))
	PhysicsServer3D.body_set_space(_body, get_world_3d().space)


func _build_cards() -> void:
	for key: String in ecology.cards:
		var chunk: Dictionary = ecology.cards[key]
		var batch := MultiMeshInstance3D.new()
		batch.name = "Cards_" + key
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = Library.card_mesh("clump_near", chunk.atlas)
		multimesh.instance_count = chunk.count
		multimesh.buffer = chunk.buffer
		var half := Ecology.CHUNK * .5 + 1.5
		multimesh.custom_aabb = AABB(Vector3(chunk.center.x - half, chunk.min_y - .2, chunk.center.z - half), Vector3(half * 2.0, chunk.max_y - chunk.min_y + 3.4, half * 2.0))
		batch.multimesh = multimesh
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		_card_chunks.append({"node": batch, "atlas": chunk.atlas, "center": chunk.center, "count": chunk.count, "lod": "near"})


func _exit_tree() -> void:
	if _body.is_valid():
		PhysicsServer3D.free_rid(_body)
		_body = RID()
	for shape: RID in _shapes.values():
		PhysicsServer3D.free_rid(shape)
	_shapes.clear()


func set_quality(next_profile: String) -> void:
	profile = next_profile if PROFILES.data.profiles.has(next_profile) else "balanced"
	var budget: Dictionary = PROFILES.data.profiles[profile]
	for material: ShaderMaterial in Library.materials():
		material.set_shader_parameter("wind_detail", int(budget.wind_detail))
		if material.shader == Library.LEAF_SHADER:
			material.set_shader_parameter("normal_strength", float(budget.leaf_normal_strength))
		if material.shader == Library.CARD_SHADER:
			var crops: bool = material.get_shader_parameter("crops")
			var end := float(budget.crop_end_m if crops else budget.herb_end_m)
			material.set_shader_parameter("fade_end", end)
			material.set_shader_parameter("widen_start", end * (.45 if crops else .75))
	if grass:
		grass.configure(budget)
	_dirty = true
	_update_cards(get_viewport().get_camera_3d() if is_inside_tree() else null)


func apply_season(index: int) -> void:
	season = posmod(index, 4)
	for material: ShaderMaterial in Library.materials():
		material.set_shader_parameter("wind_strength", SEASON_GUST[season])
		if material.shader == Library.LEAF_SHADER or material.shader == Library.IMPOSTOR_SHADER:
			material.set_shader_parameter("season_tint", SEASON_TINT[season])
			material.set_shader_parameter("autumn", SEASON_AUTUMN[season])
			material.set_shader_parameter("leaf_presence", SEASON_LEAVES[season])
		elif material.shader == Library.CARD_SHADER:
			material.set_shader_parameter("season_tint", SEASON_TINT[season].lerp(Color.WHITE, .5))
			material.set_shader_parameter("bloom", SEASON_BLOOM[season])
			material.set_shader_parameter("crop_stage", SEASON_CROP[season])
			material.set_shader_parameter("dryness", SEASON_DRY[season])
		elif material.shader == Library.BARK_SHADER:
			material.set_shader_parameter("wetness", [.25, .0, .55, .35][season])
		elif material.shader == Library.GRASS_SHADER:
			material.set_shader_parameter("season_tint", [Color("#f0ffd0"), Color("#ffffff"), Color("#f0dcae"), Color("#b9ab8c")][season])
			material.set_shader_parameter("dryness", [.0, .3, .6, .75][season])


func set_wind_time(seconds: float) -> void:
	_wind_time = seconds
	for material: ShaderMaterial in Library.materials():
		material.set_shader_parameter("wind_time", seconds)


## The blade grass is pressed down around this point (the player's feet).
func set_player_position(at: Vector3) -> void:
	Library.grass_material().set_shader_parameter("player_position", at)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_since_refresh += delta
	var view := camera.get_camera_transform()
	var moved := view.origin.distance_to(_last_view.origin)
	var turned := rad_to_deg((-view.basis.z).angle_to(-_last_view.basis.z))
	var changed := moved > .05 or turned > .5 or not is_equal_approx(camera.fov, _last_fov)
	if _dirty or moved > MOVE_LIMIT or turned > TURN_LIMIT or (changed and _since_refresh > MAX_INTERVAL):
		refresh(camera, false)
	elif grass and (changed or grass.pending(view.origin)):
		_update_grass(camera, false)


func _update_grass(camera: Camera3D, complete: bool) -> void:
	var view := camera.get_camera_transform()
	var forward := Vector2(-view.basis.z.x, -view.basis.z.z)
	forward = forward.normalized() if forward.length() > .05 else Vector2.ZERO
	var aspect := 1.78
	if is_inside_tree():
		var size := get_viewport().get_visible_rect().size
		aspect = maxf(1.0, size.x / maxf(1.0, size.y))
	grass.update(view.origin, forward, rad_to_deg(atan(tan(deg_to_rad(camera.fov * .5)) * aspect)) + 8.0, complete)


## Re-sort every visible tree into its detail batch for this camera.
## complete_grass builds every missing grass cell at once (reviews, tests);
## in play the cells arrive a few per frame.
func refresh(camera: Camera3D, complete_grass := true) -> void:
	if camera == null or ecology == null:
		return
	_dirty = false
	_since_refresh = 0.0
	_last_view = camera.get_camera_transform()
	_last_fov = camera.fov
	var eye := _last_view.origin
	var forward := Vector2(-_last_view.basis.z.x, -_last_view.basis.z.z)
	forward = forward.normalized() if forward.length() > .05 else Vector2.ZERO
	var aspect := 1.78
	if is_inside_tree():
		var size := get_viewport().get_visible_rect().size
		aspect = maxf(1.0, size.x / maxf(1.0, size.y))
	var half_fov := rad_to_deg(atan(tan(deg_to_rad(camera.fov * .5)) * aspect)) + FAN_MARGIN_DEG
	var budget: Dictionary = PROFILES.data.profiles[profile]
	var bands: Array = budget.tree_lod_m
	var end := float(budget.impostor_end_m)
	var groups: Dictionary = {}
	_visible = {}
	for key: Vector2i in _cells:
		var cell: Dictionary = _cells[key]
		var box: AABB = cell.aabb
		if not _in_fan(eye, forward, half_fov, box):
			continue
		var nearest := _distance_to_box(eye, box)
		var farthest := eye.distance_to(box.get_center()) + box.size.length() * .5
		for asset: String in cell.blocks:
			var info: Dictionary = _assets[asset]
			var factor := clampf(sqrt(float(info.height) / 14.0), .42, 1.25)
			var limit := end * factor if info.impostor != null else float(bands[3]) * factor * 1.15
			if nearest > limit:
				continue
			var block: PackedFloat32Array = cell.blocks[asset]
			var level_near := _level(nearest, bands, factor, info)
			var level_far := _level(farthest, bands, factor, info)
			if level_near == level_far and farthest <= limit:
				_append(groups, asset, level_near, block)
				continue
			var positions: PackedVector3Array = cell.positions[asset]
			for i in positions.size():
				var d := eye.distance_to(positions[i])
				if d > limit:
					continue
				_append(groups, asset, _level(d, bands, factor, info), block.slice(i * 16, i * 16 + 16))
	for key: String in _batches:
		if not groups.has(key):
			var idle: MultiMeshInstance3D = _batches[key]
			idle.multimesh.visible_instance_count = 0
			idle.hide()
	var shadow_lod := int(budget.shadow_lod)
	for key: String in groups:
		var parts := key.split("|")
		var info: Dictionary = _assets[parts[0]]
		var level := int(parts[1])
		var batch: MultiMeshInstance3D = _batches.get(key)
		if batch == null:
			batch = MultiMeshInstance3D.new()
			batch.name = key.replace("|", "_")
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.use_custom_data = true
			batch.multimesh.mesh = info.impostor if level == 4 else info.lods[level]
			batch.multimesh.custom_aabb = AABB(Vector3(-400, -20, -400), Vector3(800, 120, 800))
			_batches[key] = batch
			add_child(batch)
		var data: PackedFloat32Array = groups[key]
		var count := data.size() / 16
		var multimesh := batch.multimesh
		if count > multimesh.instance_count:
			multimesh.instance_count = nearest_po2(count)
		if data.size() < multimesh.instance_count * 16:
			data.resize(multimesh.instance_count * 16)
		multimesh.buffer = data
		multimesh.visible_instance_count = count
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level <= shadow_lod else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.show()
		_visible[key] = count
	_update_cards(camera)
	if grass:
		_update_grass(camera, complete_grass)


func _level(distance: float, bands: Array, factor: float, info: Dictionary) -> int:
	for level in 4:
		if distance < float(bands[level]) * factor:
			return level
	return 4 if info.impostor != null else 3


func _append(groups: Dictionary, asset: String, level: int, block: PackedFloat32Array) -> void:
	var key := "%s|%d" % [asset, level]
	if not groups.has(key):
		groups[key] = PackedFloat32Array()
	var data: PackedFloat32Array = groups[key]
	data.append_array(block)
	groups[key] = data


func _update_cards(camera: Camera3D) -> void:
	if camera == null:
		return
	var budget: Dictionary = PROFILES.data.profiles[profile]
	var camera_view := camera.get_camera_transform()
	var eye := camera_view.origin
	var forward := Vector2(-camera_view.basis.z.x, -camera_view.basis.z.z)
	forward = forward.normalized() if forward.length() > .05 else Vector2.ZERO
	var aspect := 1.78
	if is_inside_tree():
		var size := get_viewport().get_visible_rect().size
		aspect = maxf(1.0, size.x / maxf(1.0, size.y))
	var half_fov := rad_to_deg(atan(tan(deg_to_rad(camera.fov * .5)) * aspect)) + FAN_MARGIN_DEG
	_visible_cards = {"chunks": 0, "instances": 0, "triangles": 0}
	var near_tris := _card_triangles("clump_near")
	var far_tris := _card_triangles("clump_far")
	for chunk: Dictionary in _card_chunks:
		var node: MultiMeshInstance3D = chunk.node
		var crops: bool = chunk.atlas == "crops"
		var end := float(budget.crop_end_m if crops else budget.herb_end_m)
		var center: Vector3 = chunk.center
		var d := maxf(0.0, Vector2(eye.x - center.x, eye.z - center.z).length() - Ecology.CHUNK * .71)
		# Cull distant off-camera chunks before submitting draw calls, retaining
		# the same movement/turn safety margin as the tree batches.
		if d > end or not _in_fan(eye, forward, half_fov, node.multimesh.custom_aabb):
			node.visible = false
			continue
		node.visible = true
		var near := d < float(budget.herb_near_m)
		var lod := "near" if near else "far"
		if chunk.lod != lod:
			node.multimesh.mesh = Library.card_mesh("clump_" + lod, chunk.atlas)
			chunk.lod = lod
		var density := float(budget.crop_density if crops else budget.herb_density)
		if d > end * .55:
			density *= float(budget.far_card_share)
		var count := ceili(int(chunk.count) * density)
		node.multimesh.visible_instance_count = count
		_visible_cards.chunks += 1
		_visible_cards.instances += count
		_visible_cards.triangles += count * (near_tris if near else far_tris)


func _card_triangles(variant: String) -> int:
	return Library._triangles(Library.card_mesh(variant, "herbs"))


## Horizontal view fan test: cells near the eye always pass, others when
## their angular extent overlaps the widened horizontal field of view.
static func _in_fan(eye: Vector3, forward: Vector2, half_fov_deg: float, box: AABB) -> bool:
	if forward == Vector2.ZERO:
		return true
	var center := box.get_center()
	var offset := Vector2(center.x - eye.x, center.z - eye.z)
	var distance := offset.length()
	var radius := Vector2(box.size.x, box.size.z).length() * .5
	if distance < ALWAYS_NEAR + radius:
		return true
	var spread := rad_to_deg(asin(clampf(radius / distance, 0.0, 1.0)))
	return rad_to_deg(forward.angle_to(offset)) <= half_fov_deg + spread and rad_to_deg(forward.angle_to(offset)) >= -(half_fov_deg + spread)


static func _distance_to_box(point: Vector3, box: AABB) -> float:
	var closest := point.clamp(box.position, box.end)
	return point.distance_to(closest)


## Render-side counters for reviews and tests (no simulation state).
func stats() -> Dictionary:
	var by_level := {}
	var triangles := 0
	var batches := 0
	for key: String in _visible:
		var parts := key.split("|")
		var level: String = LEVELS[int(parts[1])]
		by_level[level] = int(by_level.get(level, 0)) + int(_visible[key])
		var tris: Array = _assets[parts[0]].triangles
		triangles += int(_visible[key]) * int(tris[mini(int(parts[1]), tris.size() - 1)])
		batches += 1
	var blades: Dictionary = grass.stats() if grass else {}
	var placed := {}
	if ecology:
		placed = ecology.counts.duplicate()
	return {"profile": profile, "season": season, "placed_trees_shrubs_vines": placed_trees, "placed": placed,
		"colliders": ecology.colliders.size() if ecology else 0, "visible_by_level": by_level,
		"visible_tree_batches": batches, "tree_triangles_submitted": triangles,
		"card_chunks_visible": _visible_cards.chunks, "card_instances_visible": _visible_cards.instances,
		"card_triangles_submitted": _visible_cards.triangles,
		"grass_cells_visible": int(blades.get("cells", 0)), "grass_tufts_visible": int(blades.get("instances", 0)),
		"grass_triangles_submitted": int(blades.get("triangles", 0)),
		"estimated_draw_calls": batches * 2 + _visible_cards.chunks + int(blades.get("cells", 0))}
