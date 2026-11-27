extends RefCounted
## Presentation of the imported well and water, in metres. The authoritative
## mission never depends on a rendering frame. Original Blender objects are
## restored after the action or scene interruption.
const Art = preload("res://scripts/world/village_art.gd")
const BUCKET_PARTS := ["Well_Bucket_Staves", "Well_Bucket_Base", "Well_Bucket_Hoops", "Well_Bucket_Handle"]
const BASE := Vector3(.13,.3725,.10)
const AXLE := Vector3(.13,1.68,.103)
const BUCKET_HANDLE := Vector3(0,.4275,0)
const BUCKET_LIP := Vector3(0,.3075,0)
var well: Node3D
var hanging: Node3D
var parts: Array[Dictionary] = []
var rope: MeshInstance3D
var stream: Array[MeshInstance3D] = []
var bucket_surface: MeshInstance3D
var root: Node3D
var _rope_was_visible := true
var _active := false

func setup(parent: Node3D) -> void:
	root = parent
	var water := Art.material(Color("a8c7c7"),.13)
	var rope_material := Art.material(Color("756044"),.95)
	rope = _cylinder("WorkingWellRope",.012,rope_material)
	for i in 8:
		stream.append(_cylinder("WaterStream%d" % i,.007,water))
	bucket_surface = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = .135
	disc.bottom_radius = .135
	disc.height = .006
	disc.radial_segments = 16
	bucket_surface.mesh = disc
	bucket_surface.material_override = water
	root.add_child(bucket_surface)
	bucket_surface.hide()

func _cylinder(id: String, radius: float, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = id
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 6
	item.mesh = mesh
	item.material_override = material
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(item)
	item.hide()
	return item

func bind_well() -> bool:
	if is_instance_valid(well) and parts.size() == BUCKET_PARTS.size():
		return true
	parts.clear()
	well = root.get_parent().find_child("I01Well",true,false) as Node3D
	if not is_instance_valid(well):
		return false
	var base := well.global_transform*Transform3D(Basis.IDENTITY,BASE)
	for id: String in BUCKET_PARTS:
		var node := well.find_child(id+"*",true,false) as Node3D
		if not is_instance_valid(node):
			parts.clear()
			return false
		parts.append({"node":node,"rest":node.transform,"offset":base.affine_inverse()*node.global_transform})
	hanging = well.find_child("Well_Hanging_Rope*",true,false) as Node3D
	if not is_instance_valid(hanging):
		parts.clear()
		return false
	_rope_was_visible = hanging.visible
	return true

func bucket_base() -> Transform3D:
	return well.global_transform*Transform3D(Basis.IDENTITY,BASE) if is_instance_valid(well) else Transform3D.IDENTITY

func bucket_at(pose: Transform3D, filled: float, tilt: float = 0.0) -> void:
	if not bind_well():
		return
	_active = true
	for part: Dictionary in parts:
		var node: Node3D = part.node
		if is_instance_valid(node):
			node.global_transform = pose*part.offset
	hanging.hide()
	_line(rope,well.to_global(AXLE),pose*BUCKET_HANDLE,1.0)
	bucket_surface.global_transform = Transform3D(pose.basis.orthonormalized(),pose*Vector3(0,lerpf(.03,.26,clampf(filled,0,1)),0))
	bucket_surface.visible = filled > .01 and tilt < .45

func _line(item: MeshInstance3D, start: Vector3, finish: Vector3, width: float) -> void:
	var delta := finish-start
	if not start.is_finite() or not finish.is_finite() or delta.length_squared()<.000001 or width<=.001:
		item.hide()
		return
	var basis := Basis(Quaternion(Vector3.UP,delta.normalized())).scaled_local(Vector3(width,delta.length(),width))
	item.global_transform = Transform3D(basis,(start+finish)*.5)
	item.show()

func water_between(start: Vector3, finish: Vector3, strength: float) -> void:
	if strength <= .001 or not start.is_finite() or not finish.is_finite() or start.y <= finish.y:
		clear_stream()
		return
	var previous := start
	for i in stream.size():
		var t := float(i+1)/float(stream.size())
		var next := start.lerp(finish,t)
		# A short accelerating downward arc, not a beam floating in space.
		next.y += (start.y-finish.y)*.45*t*(1.0-t)
		_line(stream[i],previous,next,strength)
		previous = next

func clear_stream() -> void:
	for item: MeshInstance3D in stream:
		if is_instance_valid(item):
			item.hide()

func finish() -> void:
	clear_stream()
	if is_instance_valid(rope):
		rope.hide()
	if is_instance_valid(bucket_surface):
		bucket_surface.hide()
	if not _active:
		return
	for part: Dictionary in parts:
		if is_instance_valid(part.node):
			part.node.transform = part.rest
	if is_instance_valid(hanging):
		hanging.visible = _rope_was_visible
	_active = false
