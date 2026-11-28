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
const STREAM_NEAR_DISTANCE := 8.0
const STREAM_FAR_DISTANCE := 18.0
const STREAM_MIN_STRENGTH := .001
var well: Node3D
var hanging: Node3D
var parts: Array[Dictionary] = []
var winding_parts: Array[Dictionary] = []
var crank: Node3D
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
	if not is_instance_valid(root) or not is_instance_valid(root.get_parent()):
		finish()
		return false
	var regional := root.get_parent().get("regional") as Node3D
	var current := regional.get("water_well") as Node3D if is_instance_valid(regional) else null
	if is_instance_valid(current) and current == well and parts.size() == BUCKET_PARTS.size() \
		and is_instance_valid(hanging) and is_instance_valid(crank) and not winding_parts.is_empty():
		var complete := true
		for part: Dictionary in parts + winding_parts:
			if not is_instance_valid(part.node):
				complete = false
				break
		if complete:
			return true
	# Origin changes can replace the imported scene. Restore the old assembly
	# before dropping cached references; never animate a previous village.
	finish()
	parts.clear()
	winding_parts.clear()
	hanging = null
	crank = null
	well = current
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
	crank = well.find_child("Well_Crank*",true,false) as Node3D
	if not is_instance_valid(crank):
		parts.clear()
		return false
	var pivot := well.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,1.74,0))
	for pattern: String in ["Well_Winding_Axle*","Well_Axle_Rope_Stop*","Well_Wound_Rope*","Well_Crank*"]:
		var matches := well.find_children(pattern,"Node3D",true,false)
		if matches.is_empty():
			parts.clear()
			winding_parts.clear()
			return false
		for item: Node in matches:
			var node := item as Node3D
			winding_parts.append({"node":node,"rest":node.transform,"offset":pivot.affine_inverse()*node.global_transform})
	return true

## The existing axle, wound rope and crank rotate by the actual lift distance.
func windlass(lift_m: float) -> Vector3:
	if not is_finite(lift_m):
		finish()
		return Vector3.INF
	if not bind_well():
		return Vector3.INF
	_active = true
	var angle := lift_m/.105
	var rotation := Basis(Vector3.RIGHT,angle)
	var pivot := well.global_transform*Transform3D(rotation,Vector3(0,1.74,0))
	for part: Dictionary in winding_parts:
		var node: Node3D = part.node
		if is_instance_valid(node):
			node.global_transform = pivot*part.offset
	return well.to_global(Vector3(1.56,1.74,0)+rotation*Vector3(0,-.38,0)) if is_instance_valid(crank) else Vector3.INF


func bucket_base() -> Transform3D:
	return well.global_transform*Transform3D(Basis.IDENTITY,BASE) if is_instance_valid(well) else Transform3D.IDENTITY

func bucket_at(pose: Transform3D, filled: float, tilt: float = 0.0) -> void:
	if not _finite_transform(pose) or not is_finite(filled) or not is_finite(tilt):
		finish()
		return
	if not bind_well():
		return
	_active = true
	for part: Dictionary in parts:
		var node: Node3D = part.node
		if is_instance_valid(node):
			node.global_transform = pose*part.offset
	hanging.hide()
	_line(rope,well.to_global(AXLE),pose*BUCKET_HANDLE,1.0)
	var water_level := clampf(filled,0.0,1.0)
	bucket_surface.global_transform = Transform3D(pose.basis.orthonormalized(),pose*Vector3(0,lerpf(.03,.26,water_level),0))
	bucket_surface.visible = filled > .01 and absf(tilt) < .45

func _finite_transform(pose: Transform3D) -> bool:
	return pose.origin.is_finite() and pose.basis.x.is_finite() and pose.basis.y.is_finite() and pose.basis.z.is_finite()

func _line(item: MeshInstance3D, start: Vector3, finish: Vector3, width: float) -> void:
	if not is_instance_valid(item):
		return
	var delta := finish-start
	if not start.is_finite() or not finish.is_finite() \
		or not is_finite(width) or delta.length_squared()<.000001 or width<=STREAM_MIN_STRENGTH:
		item.hide()
		return
	var basis := Basis(Quaternion(Vector3.UP,delta.normalized())).scaled_local(Vector3(width,delta.length(),width))
	item.global_transform = Transform3D(basis,(start+finish)*.5)
	item.show()

func water_between(start: Vector3, finish: Vector3, strength: float) -> void:
	if not is_finite(strength) or strength <= STREAM_MIN_STRENGTH or not start.is_finite() \
		or not finish.is_finite() or start.y <= finish.y:
		clear_stream()
		return
	var midpoint := start.lerp(finish,.5)
	var camera: Camera3D
	if is_instance_valid(root) and root.is_inside_tree():
		var viewport := root.get_viewport()
		camera = viewport.get_camera_3d() if is_instance_valid(viewport) else null
	var distance := camera.global_position.distance_to(midpoint) if is_instance_valid(camera) else 0.0
	var segment_count := _stream_segment_count(distance)
	var flow_strength := clampf(strength,0.0,1.0)
	var previous := start
	for i in stream.size():
		if i >= segment_count:
			stream[i].hide()
			continue
		var t := float(i+1)/float(segment_count)
		var next := start.lerp(finish,t)
		# A short accelerating downward arc, not a beam floating in space.
		next.y += (start.y-finish.y)*.45*t*(1.0-t)
		_line(stream[i],previous,next,flow_strength)
		previous = next

func _stream_segment_count(distance: float) -> int:
	if stream.is_empty():
		return 0
	if not is_finite(distance) or distance <= STREAM_NEAR_DISTANCE:
		return stream.size()
	var ratio := .5 if distance <= STREAM_FAR_DISTANCE else .25
	return mini(stream.size(), maxi(1, ceili(float(stream.size())*ratio)))

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
	for part: Dictionary in winding_parts:
		if is_instance_valid(part.node):
			part.node.transform = part.rest
	if is_instance_valid(hanging):
		hanging.visible = _rope_was_visible
	_active = false
