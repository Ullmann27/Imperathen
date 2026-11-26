extends RefCounted
## Original primitive art for the frontier prototype. All dimensions are metres.

const MAX_CACHED_PRIMITIVES := 128
const Surfaces = preload("res://scripts/rendering/village_surfaces.gd")
static var _boxes: Dictionary = {}
static var _cylinders: Dictionary = {}
static var _spheres: Dictionary = {}

## Returned primitive meshes are shared immutable geometry. Change the node's
## transform or duplicate its mesh before changing mesh dimensions directly.
static func _box_mesh(size: Vector3) -> BoxMesh:
	if _boxes.has(size): return _boxes[size]
	var result := BoxMesh.new()
	result.size = size
	if _boxes.size() < MAX_CACHED_PRIMITIVES: _boxes[size] = result
	return result

static func _cylinder_mesh(radius: float, height: float, top: float) -> CylinderMesh:
	var key := Vector3(radius, height, top)
	if _cylinders.has(key): return _cylinders[key]
	var result := CylinderMesh.new()
	result.bottom_radius = radius
	result.top_radius = top
	result.height = height
	result.radial_segments = 10
	if _cylinders.size() < MAX_CACHED_PRIMITIVES: _cylinders[key] = result
	return result

static func _sphere_mesh(radius: float) -> SphereMesh:
	if _spheres.has(radius): return _spheres[radius]
	var result := SphereMesh.new()
	result.radius = radius
	result.height = radius*2.0
	result.radial_segments = 12
	result.rings = 6
	if _spheres.size() < MAX_CACHED_PRIMITIVES: _spheres[radius] = result
	return result

static func material(color: Color, roughness: float = 0.88, worn: bool = true) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	if worn:
		Surfaces.add_wear(result)
	return result


static func transparent_material(color: Color) -> StandardMaterial3D:
	var result := material(color, 0.88, false)
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result


static func box(parent: Node3D, size: Vector3, location: Vector3, paint: Material, solid: bool = false) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = _box_mesh(size)
	mesh_node.material_override = paint
	mesh_node.position = location
	parent.add_child(mesh_node)
	if solid:
		box_collider(mesh_node, size)
	return mesh_node


static func box_collider(parent: Node3D, size: Vector3, location: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = location
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var geometry := BoxShape3D.new()
	geometry.size = size
	shape.shape = geometry
	body.add_child(shape)
	parent.add_child(body)
	return body


static func cylinder(parent: Node3D, radius: float, height: float, location: Vector3, paint: Material, top_radius: float = -1.0, solid: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _cylinder_mesh(radius, height, radius if top_radius < 0.0 else top_radius)
	node.material_override = paint
	node.position = location
	parent.add_child(node)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var collision := CylinderShape3D.new()
		collision.radius = radius
		collision.height = height
		shape.shape = collision
		body.add_child(shape)
		node.add_child(body)
	return node


static func sphere(parent: Node3D, radius: float, location: Vector3, paint: Material, proportions: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _sphere_mesh(radius)
	node.material_override = paint
	node.position = location
	node.scale = proportions
	parent.add_child(node)
	return node


static func batch_static(root: Node3D, excluded: Array = []) -> Dictionary:
	# Call once on a compact, explicitly static prop group after authoring it.
	# Each group remains independently culled. Never batch a whole settlement.
	var groups := {}
	for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if node in excluded or node.get_child_count() > 0 or node.get_script() != null or node.skin != null or not node.visible or not node.mesh:
			continue
		if node.material_overlay or not is_zero_approx(node.transparency): continue
		var overridden := false
		for surface in node.mesh.get_surface_count():
			overridden = overridden or node.get_surface_override_material(surface) != null
		if overridden: continue
		var paint := node.material_override
		if paint is BaseMaterial3D and paint.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		var key := str([node.mesh.get_instance_id(), paint.get_instance_id() if paint else 0,
			node.layers, node.cast_shadow, node.gi_mode, node.lod_bias, node.extra_cull_margin,
			node.visibility_range_begin, node.visibility_range_end, node.visibility_range_begin_margin,
			node.visibility_range_end_margin, node.visibility_range_fade_mode, node.ignore_occlusion_culling])
		if not groups.has(key): groups[key] = []
		groups[key].append(node)
	var removed := 0
	var batches := 0
	for members: Array in groups.values():
		if members.size() < 2: continue
		var original := members[0] as MeshInstance3D
		var mesh := original.mesh
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = members.size()
		var bounds := AABB()
		for index in members.size():
			var instance := members[index] as MeshInstance3D
			var pose := _relative_transform(instance, root)
			multi.set_instance_transform(index, pose)
			var box: AABB = pose*mesh.get_aabb()
			bounds = box if index == 0 else bounds.merge(box)
		multi.custom_aabb = bounds
		var batch := MultiMeshInstance3D.new()
		batch.name = "StaticBatch%d" % batches
		batch.multimesh = multi
		batch.material_override = original.material_override
		for property: String in ["layers", "cast_shadow", "gi_mode", "lod_bias", "extra_cull_margin",
			"visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin",
			"visibility_range_end_margin", "visibility_range_fade_mode", "ignore_occlusion_culling"]:
			batch.set(property, original.get(property))
		root.add_child(batch)
		for instance: MeshInstance3D in members:
			instance.get_parent().remove_child(instance)
			instance.free()
		removed += members.size()
		batches += 1
	return {"replaced_mesh_nodes":removed, "multimesh_nodes":batches}


static func _relative_transform(instance: Node3D, root: Node3D) -> Transform3D:
	var pose := instance.transform
	var parent := instance.get_parent()
	while parent != root and parent is Node3D:
		pose = (parent as Node3D).transform*pose
		parent = parent.get_parent()
	return pose


static func label(parent: Node3D, words: String, location: Vector3, color: Color = Color(0.94, 0.88, 0.72), font_size: int = 40) -> Label3D:
	var result := Label3D.new()
	result.text = words
	result.position = location
	result.font_size = font_size
	result.pixel_size = 0.005
	result.outline_size = 9
	result.outline_modulate = Color(0.12, 0.13, 0.12, 0.95)
	result.modulate = color
	result.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	result.no_depth_test = false
	result.visibility_range_end = 12.0
	result.visibility_range_end_margin = 1.0
	parent.add_child(result)
	return result


static func roof(parent: Node3D, width: float, depth: float, wall_height: float, rise: float, paint: Material) -> MeshInstance3D:
	if paint is StandardMaterial3D:
		paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left_front := Vector3(-width * 0.5, wall_height, depth * 0.5)
	var right_front := Vector3(width * 0.5, wall_height, depth * 0.5)
	var left_back := Vector3(-width * 0.5, wall_height, -depth * 0.5)
	var right_back := Vector3(width * 0.5, wall_height, -depth * 0.5)
	var peak_front := Vector3(0, wall_height + rise, depth * 0.5)
	var peak_back := Vector3(0, wall_height + rise, -depth * 0.5)
	_triangle(surface, left_front, peak_front, peak_back)
	_triangle(surface, left_front, peak_back, left_back)
	_triangle(surface, right_back, peak_back, peak_front)
	_triangle(surface, right_back, peak_front, right_front)
	_triangle(surface, left_front, right_front, peak_front)
	_triangle(surface, right_back, left_back, peak_back)
	var result := MeshInstance3D.new()
	result.mesh = surface.commit()
	result.material_override = paint
	parent.add_child(result)
	return result


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(point.x, point.z) * 0.4)
		surface.add_vertex(point)


static func hut(parent: Node3D, stone: Material, timber: Material, tiles: Material, solid: bool = true) -> Node3D:
	var home := Node3D.new()
	home.name = "FrontierHut"
	parent.add_child(home)
	box(home, Vector3(4.1, 0.14, 3.9), Vector3(0, 0.06, 0), stone)
	box(home, Vector3(0.22, 2.25, 3.7), Vector3(-1.9, 1.18, 0), stone, solid)
	box(home, Vector3(0.22, 2.25, 3.7), Vector3(1.9, 1.18, 0), stone, solid)
	box(home, Vector3(3.7, 2.25, 0.22), Vector3(0, 1.18, -1.8), stone, solid)
	box(home, Vector3(1.35, 2.25, 0.22), Vector3(-1.25, 1.18, 1.8), stone, solid)
	box(home, Vector3(1.35, 2.25, 0.22), Vector3(1.25, 1.18, 1.8), stone, solid)
	box(home, Vector3(1.15, 0.45, 0.28), Vector3(0, 2.08, 1.8), timber, solid)
	for x: float in [-1.85, 1.85]:
		for z: float in [-1.78, 1.78]:
			box(home, Vector3(0.19, 2.4, 0.19), Vector3(x, 1.25, z), timber)
	roof(home, 4.45, 4.25, 2.37, 1.15, tiles)
	box(home, Vector3(0.16, 0.18, 4.35), Vector3(0, 3.52, 0), timber)
	box(home, Vector3(1.0, 0.38, 1.8), Vector3(-1.12, 0.26, -0.35), timber)
	return home


static func person(parent: Node3D, role: String, home := "italia", age := 18) -> Node3D:
	var actor := preload("res://scripts/visuals/village_person.gd").new()
	actor.name = "Figure"
	parent.add_child(actor)
	actor.configure(role,home,age)
	return actor


static func tree(parent: Node3D, at: Vector3, height: float, bark: Material, foliage: Material, solid: bool = true) -> Node3D:
	var tree_root := Node3D.new()
	tree_root.position = at
	parent.add_child(tree_root)
	cylinder(tree_root, 0.25, height * 0.70, Vector3(0, height * 0.35, 0), bark, 0.13, solid)
	sphere(tree_root, height * 0.31, Vector3(0, height * 0.75, 0), foliage, Vector3(1.0, 0.72, 0.88))
	sphere(tree_root, height * 0.23, Vector3(0.5, height * 0.90, 0.1), foliage, Vector3(0.9, 1.0, 0.9))
	return tree_root
