extends RefCounted

const MODEL := "res://assets/operation_prima/table_bread.glb"


static func build_mesh() -> ArrayMesh:
	var packed := load(MODEL) as PackedScene
	if packed == null:
		push_error("Cannot load the family breakfast bread")
		return null
	var root := packed.instantiate()
	var part := root.get_node_or_null("TableBread") as MeshInstance3D
	var mesh := part.mesh as ArrayMesh if part else null
	root.free()
	if mesh == null or mesh.get_surface_count() != 3:
		push_error("Invalid breakfast bread mesh or material slots")
		return null
	return mesh
