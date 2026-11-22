extends Node3D
## Renders tree placements in grove-local metres, batched by species and camera distance.

const KINDS := ["pine", "olive", "oak"]
const LEVELS := ["near", "mid", "far"]
const DISTANCES := {"low": Vector2(0, 24), "balanced": Vector2(17, 52), "high": Vector2(28, 76)}
# Outward-rounded union of the three native GLB bounds, including foliage cards
# and the root skirt. The landscape import test checks every LOD against these.
const CANOPY_BOUNDS := {
	"pine": AABB(Vector3(-4.85,-0.10,-6.65), Vector3(9.95,9.65,12.05)),
	"oak": AABB(Vector3(-4.95,-0.10,-5.90), Vector3(9.58,7.75,10.41)),
	"olive": AABB(Vector3(-3.20,-0.35,-3.10), Vector3(7.32,5.30,7.03)),
}
static var _meshes: Dictionary = {}
var _placements: Array = []
var _batches: Dictionary = {}
var _profile := "balanced"
var _last_camera: Camera3D
var _last_view := Transform3D.IDENTITY
var _last_projection := Projection.IDENTITY
var _last_grove := Transform3D.IDENTITY
var _contents: Dictionary = {}
var visible_tree_count := 0
var visible_tree_lods := Vector3i.ZERO

func populate(placements: Array) -> void:
	_placements = []
	for entry: Dictionary in placements:
		if entry.get("kind", "") not in KINDS or typeof(entry.get("position")) != TYPE_VECTOR3:
			continue
		var size := float(entry.get("scale", 1.0))
		var rotation_basis := Basis(Vector3.UP, float(entry.get("yaw", 0.0)))
		if size > 0.0:
			var pose := Transform3D(rotation_basis.scaled(Vector3.ONE * size), entry.position)
			var bounds: AABB = pose * CANOPY_BOUNDS[entry.kind]
			_placements.append({"kind": entry.kind, "pose": pose, "bounds": bounds})
	_rebuild()

func set_quality(profile: String) -> void:
	var selected := profile if DISTANCES.has(profile) else "balanced"
	if _profile != selected:
		_profile = selected
		_rebuild()

func _ready() -> void:
	_rebuild()

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != _last_camera or global_transform != _last_grove:
		_rebuild()
	elif camera and (camera.get_camera_transform() != _last_view or camera.get_camera_projection() != _last_projection):
		_rebuild()

func _rebuild() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	_last_camera = camera
	_last_grove = global_transform if is_inside_tree() else Transform3D.IDENTITY
	var viewer := Vector3.ZERO
	var planes: Array[Plane] = []
	var absolute_normals := PackedVector3Array()
	if camera:
		_last_view = camera.get_camera_transform()
		_last_projection = camera.get_camera_projection()
		viewer = to_local(_last_view.origin)
		# Test grove-local boxes with world frustum planes transformed once per view.
		var to_grove := _last_grove.affine_inverse()
		for world_plane in camera.get_frustum():
			var local_plane: Plane = to_grove * world_plane
			planes.append(local_plane)
			absolute_normals.append(local_plane.normal.abs())
	visible_tree_count = 0
	visible_tree_lods = Vector3i.ZERO
	var thresholds: Vector2 = DISTANCES[_profile]
	var groups := {}
	for tree: Dictionary in _placements:
		if camera and not _in_frustum(tree.bounds, planes, absolute_normals):
			continue
		var pose: Transform3D = tree.pose
		var distance := viewer.distance_to(pose.origin)
		var level := 0 if distance < thresholds.x else (1 if distance < thresholds.y else 2)
		visible_tree_count += 1
		visible_tree_lods[level] += 1
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
		if _contents.get(key) != transforms:
			for i in transforms.size():
				group.set_instance_transform(i, transforms[i])
		group.visible_instance_count = transforms.size()
		batch.show()
	_contents = groups

static func _in_frustum(bounds: AABB, planes: Array[Plane], absolute_normals: PackedVector3Array) -> bool:
	var center := bounds.get_center()
	var extent := bounds.size * 0.5
	for i in planes.size():
		# A tree is outside only when its entire projected extent is beyond a plane.
		if planes[i].distance_to(center) > absolute_normals[i].dot(extent) + 0.02:
			return false
	return true

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
