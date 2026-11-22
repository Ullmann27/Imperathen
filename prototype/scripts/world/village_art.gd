extends RefCounted
## Original primitive art for the frontier prototype. All dimensions are metres.

static func material(color: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result


static func transparent_material(color: Color) -> StandardMaterial3D:
	var result := material(color)
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result


static func box(parent: Node3D, size: Vector3, location: Vector3, paint: Material, solid: bool = false) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh_node.mesh = geometry
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
	var geometry := CylinderMesh.new()
	geometry.bottom_radius = radius
	geometry.top_radius = radius if top_radius < 0.0 else top_radius
	geometry.height = height
	geometry.radial_segments = 10
	node.mesh = geometry
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
	var geometry := SphereMesh.new()
	geometry.radius = radius
	geometry.height = radius * 2.0
	geometry.radial_segments = 12
	geometry.rings = 6
	node.mesh = geometry
	node.material_override = paint
	node.position = location
	node.scale = proportions
	parent.add_child(node)
	return node


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


static func person(parent: Node3D, tunic_color: Color, armored: bool = false) -> Node3D:
	var actor := Node3D.new()
	actor.name = "Figure"
	parent.add_child(actor)
	var tunic := material(tunic_color)
	var skin := material(Color(0.66, 0.46, 0.31))
	var leather := material(Color(0.19, 0.13, 0.09))
	var metal := material(Color(0.45, 0.46, 0.43), 0.5)
	box(actor, Vector3(0.48, 0.55, 0.29), Vector3(0, 0.05, 0), tunic)
	cylinder(actor, 0.30, 0.30, Vector3(0, -0.29, 0), tunic, 0.24)
	box(actor, Vector3(0.50, 0.07, 0.32), Vector3(0, -0.16, 0), leather)
	cylinder(actor, 0.075, 0.13, Vector3(0, 0.41, 0), skin)
	sphere(actor, 0.17, Vector3(0, 0.60, -0.015), skin, Vector3(0.90, 1.12, 0.95))
	sphere(actor, 0.174, Vector3(0, 0.68, 0.02), leather, Vector3(0.91, 0.65, 0.90))
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "LegLeft" if side < 0.0 else "LegRight"
		leg.position = Vector3(side * 0.13, -0.36, 0)
		actor.add_child(leg)
		cylinder(leg, 0.085, 0.39, Vector3(0, -0.19, 0), skin)
		box(leg, Vector3(0.19, 0.12, 0.30), Vector3(0, -0.44, -0.055), leather)
		var arm := Node3D.new()
		arm.name = "ArmLeft" if side < 0.0 else "ArmRight"
		arm.position = Vector3(side * 0.31, 0.24, 0)
		actor.add_child(arm)
		cylinder(arm, 0.075, 0.20, Vector3(0, -0.09, 0), tunic)
		cylinder(arm, 0.057, 0.31, Vector3(0, -0.32, 0), skin)
		if side > 0.0:
			var weapon := box(arm, Vector3(0.075, 0.08, 0.52), Vector3(0, -0.48, -0.24), metal)
			weapon.name = "Sword"
			var guard := box(arm, Vector3(0.16, 0.055, 0.07), Vector3(0, -0.48, -0.04), leather)
			guard.name = "SwordGuard"
	if armored:
		box(actor, Vector3(0.50, 0.42, 0.33), Vector3(0, 0.11, 0), metal)
		cylinder(actor, 0.185, 0.17, Vector3(0, 0.72, 0), metal, 0.15)
		var shield := box(actor, Vector3(0.12, 0.63, 0.46), Vector3(-0.47, -0.05, -0.10), tunic)
		box(shield, Vector3(0.15, 0.08, 0.40), Vector3.ZERO, metal)
	return actor


static func tree(parent: Node3D, at: Vector3, height: float, bark: Material, foliage: Material, solid: bool = true) -> Node3D:
	var tree_root := Node3D.new()
	tree_root.position = at
	parent.add_child(tree_root)
	cylinder(tree_root, 0.25, height * 0.70, Vector3(0, height * 0.35, 0), bark, 0.13, solid)
	sphere(tree_root, height * 0.31, Vector3(0, height * 0.75, 0), foliage, Vector3(1.0, 0.72, 0.88))
	sphere(tree_root, height * 0.23, Vector3(0.5, height * 0.90, 0.1), foliage, Vector3(0.9, 1.0, 0.9))
	return tree_root
