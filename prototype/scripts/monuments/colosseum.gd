class_name Colosseum
extends Node3D
## Runtime assembly of the reworked Flavian Amphitheatre kit.
## Instanced facade bays, unique sector interiors, manual sector LOD, far shell,
## collision, velarium and lighting hooks.  The building is an epoch-dependent
## later monument (D-053): use `available_at()` before adding it to a world.
const EraRegistry := preload("res://scripts/domain/era_registry.gd")
const Calendar := preload("res://scripts/domain/world_calendar.gd")
const Materials := preload("res://scripts/monuments/monument_materials.gd")
const DIR := "res://assets/monuments/colosseum/"
const CONTENT_ID := "building.amphitheatrum_flavium"
const HYPOGEUM_ID := "building.amphitheatrum_flavium.hypogeum"
## Per-profile budgets (metres / counts). Leicht, Ausgewogen (Fold7), Hoch, Ultra.
const BUDGET := {
	"low": {"lod0": 0.0, "lod1": 300.0, "interior": 60.0, "statues": 0.0, "lights": 0, "masts": false, "occluders": false},
	"balanced": {"lod0": 60.0, "lod1": 450.0, "interior": 95.0, "statues": 120.0, "lights": 4, "masts": true, "occluders": true},
	"high": {"lod0": 120.0, "lod1": 700.0, "interior": 150.0, "statues": 220.0, "lights": 8, "masts": true, "occluders": true},
	"very_high": {"lod0": 240.0, "lod1": 1400.0, "interior": 300.0, "statues": 420.0, "lights": 16, "masts": true, "occluders": true},
}
const UPDATE_INTERVAL := 0.2
const HYSTERESIS := 6.0

@export var profile := "balanced"
@export var velarium := false
@export var night := false
@export var arena_open := false
## Julian day number of the world date; 0 skips the hypogeum gate (shows the Domitianic state).
var world_jdn := 0
var layout: Dictionary = {}
var stats := {"facade_instances": 0, "statue_instances": 0, "sectors": 0, "collision_faces": 0}
var _sectors: Array = []
var _far: Node3D
var _lights: Array = []
var _clock := 0.0
var _built := false


static func available_at(jdn: int) -> bool:
	return EraRegistry.available(CONTENT_ID, jdn)


static func hypogeum_at(jdn: int) -> bool:
	return EraRegistry.available(HYPOGEUM_ID, jdn)


func _ready() -> void:
	if not _built:
		build()


func build() -> void:
	_built = true
	if not BUDGET.has(profile):
		profile = "balanced"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "colosseum_layout.json"))
	if not parsed is Dictionary or parsed.get("format", "") != "imperathen-colosseum-layout":
		push_error("Colosseum layout missing or invalid.")
		return
	layout = parsed
	var count := int(layout.sectors)
	for index in count:
		_sectors.append({"centre": Vector3.ZERO, "bays": 0, "lod0": [], "lod1": [], "statues0": [], "statues1": [], "backing": [], "interior": [], "state": -1})
	_build_structure()
	_build_facade()
	_build_arena()
	_build_far()
	_build_collision()
	_build_lights()
	stats.sectors = count
	_update_lod(true)


func _scene(file: String) -> Node3D:
	var packed := load(DIR + file) as PackedScene
	if packed == null:
		push_error("Missing monument asset " + file)
		return Node3D.new()
	var node := packed.instantiate() as Node3D
	Materials.apply(node, profile)
	return node


func _build_structure() -> void:
	var scene := _scene("colosseum_structure.glb")
	scene.name = "Structure"
	add_child(scene)
	for mesh: MeshInstance3D in scene.find_children("S??_*", "MeshInstance3D", true, false):
		var sector := int(str(mesh.name).substr(1, 2))
		if str(mesh.name).ends_with("Structure"):
			_sectors[sector].interior.append(mesh)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if profile != "low" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _module_mesh(modules: Node, module_name: String) -> Mesh:
	var node := modules.find_child(module_name, true, false) as MeshInstance3D
	return node.mesh if node != null else null


func _multimesh(mesh: Mesh, transforms: Array, label: String) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in transforms.size():
		multi.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.name = label
	add_child(instance)
	return instance


func _build_facade() -> void:
	var modules := _scene("colosseum_modules.glb")
	var levels: Array = layout.levels_m
	var per_sector: Array = []
	for index in _sectors.size():
		per_sector.append({})
	for bay: Dictionary in layout.bays:
		var t: Array = bay.transform
		var base := Transform3D(Basis(Vector3(t[0], t[1], t[2]), Vector3(t[3], t[4], t[5]), Vector3(t[6], t[7], t[8])), Vector3(t[9], t[10], t[11]))
		var sector := int(bay.sector)
		_sectors[sector].centre += base.origin + Vector3(0, 24, 0)
		_sectors[sector].bays += 1
		var bucket: Dictionary = per_sector[sector]
		for level in 4:
			var placed := base
			placed.origin.y = float(levels[level])
			var key := ("Arcade_%d" % level) if level < 3 else ("Attic_Window" if bay.attic == "window" else "Attic_Shield")
			(bucket.get_or_add(key, []) as Array).append(placed)
			if level < 3:
				(bucket.get_or_add("Arch_Backing_%d" % level, []) as Array).append(placed)
			if level in [1, 2]:
				var offset: Array = bay.statue_offset
				var statue := Transform3D(base.basis.orthonormalized(), placed.origin + Vector3(offset[0], offset[1], offset[2]))
				(bucket.get_or_add("Statue_%d" % int(bay.statues[level - 1]), []) as Array).append(statue)
			if level == 3:
				(bucket.get_or_add("Masts", []) as Array).append(placed)
	var budget: Dictionary = BUDGET[profile]
	for sector in _sectors.size():
		var data: Dictionary = _sectors[sector]
		data.centre /= maxf(1.0, float(data.bays))
		for key: String in per_sector[sector]:
			var transforms: Array = per_sector[sector][key]
			if key.begins_with("Arch_Backing"):
				data.backing.append(_multimesh(_module_mesh(modules, key), transforms, "S%02d_%s" % [sector, key]))
				continue
			if key.begins_with("Statue"):
				if float(budget.statues) <= 0.0:
					continue
				data.statues0.append(_multimesh(_module_mesh(modules, key), transforms, "S%02d_%s" % [sector, key]))
				data.statues1.append(_multimesh(_module_mesh(modules, key + "_LOD1"), transforms, "S%02d_%s_L1" % [sector, key]))
				stats.statue_instances += transforms.size()
				continue
			if key == "Masts" and not bool(budget.masts):
				continue
			if float(budget.lod0) > 0.0:
				data.lod0.append(_multimesh(_module_mesh(modules, key + "_LOD0"), transforms, "S%02d_%s_L0" % [sector, key]))
			data.lod1.append(_multimesh(_module_mesh(modules, key + "_LOD1"), transforms, "S%02d_%s_L1" % [sector, key]))
			stats.facade_instances += transforms.size()
	for sector: Dictionary in _sectors:
		for group: String in ["lod0", "lod1", "statues0", "statues1", "backing"]:
			for node: MultiMeshInstance3D in sector[group]:
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (profile != "low" and group in ["lod0", "lod1"]) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# torch brackets and braziers are part of the kit even when unlit
	var brackets: Array = []
	var braziers: Array = []
	for hook: Dictionary in layout.light_hooks:
		var p: Array = hook.position
		var f: Array = hook.facing
		var forward := Vector3(f[0], f[1], f[2])
		var origin := Vector3(p[0], p[1], p[2])
		if hook.kind == "torch":
			brackets.append(Transform3D(Basis.looking_at(-forward, Vector3.UP), origin))
		else:
			braziers.append(Transform3D(Basis.IDENTITY, origin))
		_lights.append({"position": origin + (forward * 0.45 + Vector3(0, 0.5, 0) if hook.kind == "torch" else Vector3(0, 1.4, 0)), "kind": hook.kind, "node": null})
	if profile != "low":
		_multimesh(_module_mesh(modules, "Torch_Bracket"), brackets, "TorchBrackets")
	_multimesh(_module_mesh(modules, "Brazier"), braziers, "Braziers")
	modules.free()


func _build_arena() -> void:
	var scene := _scene("colosseum_arena.glb")
	scene.name = "Arena"
	add_child(scene)
	var hypogeum := world_jdn == 0 or hypogeum_at(world_jdn)
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		match str(mesh.name):
			"Arena_Trapdoors":
				mesh.visible = hypogeum and not arena_open
			"Hypogeum":
				mesh.visible = hypogeum and arena_open
			"Arena_Floor_Deck":
				mesh.visible = not (hypogeum and arena_open)
			"Velarium_Awning":
				mesh.visible = velarium
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if profile in ["high", "very_high"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_far() -> void:
	_far = _scene("colosseum_far.glb")
	_far.name = "FarShell"
	add_child(_far)
	if not bool(BUDGET[profile].occluders):
		return
	# The shell doubles as a CPU occluder so corridors hide what lies behind them.
	var source := _far.find_child("Colosseum_Far", true, false) as MeshInstance3D
	if source == null:
		return
	var faces := source.mesh.get_faces()
	var indices := PackedInt32Array()
	indices.resize(faces.size())
	for index in faces.size():
		indices[index] = index
	var occluder := ArrayOccluder3D.new()
	occluder.set_arrays(faces, indices)
	var instance := OccluderInstance3D.new()
	instance.occluder = occluder
	instance.name = "ShellOccluder"
	add_child(instance)


func _build_collision() -> void:
	var packed := load(DIR + "colosseum_collision.glb") as PackedScene
	if packed == null:
		return
	var scene := packed.instantiate()
	var body := StaticBody3D.new()
	body.name = "ColosseumCollision"
	add_child(body)
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var faces := mesh.mesh.get_faces()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.name = str(mesh.name)
		collider.transform = mesh.transform
		body.add_child(collider)
		stats.collision_faces += faces.size() / 3
	scene.free()


func _build_lights() -> void:
	if not night or int(BUDGET[profile].lights) <= 0:
		return
	for index in int(BUDGET[profile].lights):
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.62, 0.30)
		light.light_energy = 2.2
		light.omni_range = 11.0
		light.shadow_enabled = false
		light.visible = false
		light.name = "FireLight%d" % index
		add_child(light)


func _camera_position() -> Vector3:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	return to_local(camera.global_position) if camera != null else Vector3(0, 2, 0)


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= UPDATE_INTERVAL:
		_clock = 0.0
		_update_lod(false)


func _set_group(nodes: Array, value: bool) -> void:
	for node: Node3D in nodes:
		node.visible = value


func _update_lod(force: bool) -> void:
	if layout.is_empty():
		return
	var budget: Dictionary = BUDGET[profile]
	var eye := _camera_position()
	var planar := Vector2(eye.x / 94.0, eye.z / 78.0).length()
	var outside := maxf(0.0, (planar - 1.0) * 86.0)
	var far := outside > float(budget.lod1) + (0.0 if _far.visible else HYSTERESIS)
	if force or far != _far.visible:
		_far.visible = far
		for child: Node in get_children():
			if child is Node3D and child != _far and not child is OmniLight3D and not child is OccluderInstance3D:
				(child as Node3D).visible = not far
	if far:
		return
	for sector: Dictionary in _sectors:
		var distance := eye.distance_to(sector.centre)
		# vertical offset must not hide detail from a spectator standing below the centre
		distance = minf(distance, Vector2(eye.x - sector.centre.x, eye.z - sector.centre.z).length() + 8.0)
		var state := 0
		if distance < float(budget.lod0):
			state |= 1
		if distance < float(budget.interior):
			state |= 2
		if distance < float(budget.statues):
			state |= 4
		if state == int(sector.state) and not force:
			continue
		sector.state = state
		var near := (state & 1) != 0 and not (sector.lod0 as Array).is_empty()
		_set_group(sector.lod0, near)
		_set_group(sector.lod1, not near)
		_set_group(sector.interior, (state & 2) != 0)
		_set_group(sector.backing, (state & 2) == 0)
		_set_group(sector.statues0, near and (state & 4) != 0)
		_set_group(sector.statues1, not near and (state & 4) != 0)
	if night and not _lights.is_empty():
		var order := _lights.duplicate()
		order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return eye.distance_squared_to(a.position) < eye.distance_squared_to(b.position))
		var slot := 0
		for child: Node in get_children():
			if child is OmniLight3D:
				(child as OmniLight3D).visible = slot < order.size()
				if slot < order.size():
					(child as OmniLight3D).position = order[slot].position
				slot += 1


## Triangles currently submitted by this building (visible nodes only); used for the budget report.
func visible_triangles() -> int:
	var total := 0
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		if not (node as Node3D).is_visible_in_tree():
			continue
		if node is MultiMeshInstance3D:
			var multi := (node as MultiMeshInstance3D).multimesh
			if multi != null and multi.mesh != null:
				total += multi.mesh.get_faces().size() / 3 * multi.instance_count
		elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			total += (node as MeshInstance3D).mesh.get_faces().size() / 3
	return total
