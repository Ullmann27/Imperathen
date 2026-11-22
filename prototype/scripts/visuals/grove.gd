extends Node3D
## Renders tree placements in grove-local metres, batched by species and camera distance.

const KINDS := ["pine", "olive", "oak"]
const LEVELS := ["near", "mid", "far"]
const DISTANCES := {"low": Vector2(0, 24), "balanced": Vector2(17, 52), "high": Vector2(28, 76)}
static var _meshes: Dictionary = {}
var _placements: Array = []
var _batches: Dictionary = {}
var _profile := "balanced"
var _last_camera := Vector3.INF
var _elapsed := 0.0

func populate(placements: Array) -> void:
	_placements = []
	for entry: Dictionary in placements:
		if entry.get("kind", "") not in KINDS or typeof(entry.get("position")) != TYPE_VECTOR3:
			continue
		var size := float(entry.get("scale", 1.0))
		var rotation_basis := Basis(Vector3.UP, float(entry.get("yaw", 0.0)))
		if size > 0.0:
			var pose := Transform3D(rotation_basis.scaled(Vector3.ONE * size), entry.position)
			_placements.append({"kind": entry.kind, "pose": pose})
	_rebuild()

func set_quality(profile: String) -> void:
	var selected := profile if DISTANCES.has(profile) else "balanced"
	if _profile != selected:
		_profile = selected
		_rebuild()

func _ready() -> void:
	_rebuild()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.4:
		return
	_elapsed = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera and to_local(camera.global_position).distance_squared_to(_last_camera) > 4:
		_rebuild()

func _rebuild() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var viewer := to_local(camera.global_position) if camera else Vector3.ZERO
	_last_camera = viewer
	var thresholds: Vector2 = DISTANCES[_profile]
	var groups := {}
	for tree: Dictionary in _placements:
		var pose: Transform3D = tree.pose
		var distance := viewer.distance_to(pose.origin)
		var level := 0 if distance < thresholds.x else (1 if distance < thresholds.y else 2)
		var key := "%s_%s" % [tree.kind, LEVELS[level]]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(pose)
	for key in _batches:
		if not groups.has(key):
			var previous: MultiMeshInstance3D = _batches[key]
			previous.multimesh.visible_instance_count = 0
			previous.hide()
	for key: String in groups:
		var batch: MultiMeshInstance3D = _batches.get(key)
		if batch == null:
			batch = MultiMeshInstance3D.new()
			batch.name = key
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.mesh = _mesh(key)
			_batches[key] = batch
			add_child(batch)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key.ends_with("_far") or _profile == "low" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var group := batch.multimesh
		var transforms: Array = groups[key]
		if transforms.size() > group.instance_count:
			group.instance_count = nearest_po2(transforms.size())
		for i in transforms.size():
			group.set_instance_transform(i, transforms[i])
		group.visible_instance_count = transforms.size()
		batch.show()

static func _mesh(key: String) -> Mesh:
	if not _meshes.has(key):
		var packed := load("res://assets/landscape/%s.glb" % key) as PackedScene
		var node := packed.instantiate()
		var mesh_node := node as MeshInstance3D
		if mesh_node == null:
			mesh_node = node.find_children("*", "MeshInstance3D", true, false)[0]
		_meshes[key] = mesh_node.mesh
		node.free()
	return _meshes[key]
