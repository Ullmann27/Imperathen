@tool
extends EditorScenePostImport

# Restore the glTF COLOR_0 finish on the stone after Godot's shadow-mesh import.
func _post_import(scene: Node) -> Object:
	var meshes := scene.find_children("*","MeshInstance3D",true,false)
	if scene is MeshInstance3D:
		meshes.append(scene)
	for node: MeshInstance3D in meshes:
		for index in node.mesh.get_surface_count():
			var material := node.get_active_material(index) as StandardMaterial3D
			if material:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
	return scene
