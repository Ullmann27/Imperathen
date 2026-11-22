extends SceneTree

const Grove = preload("res://scripts/visuals/grove.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var errors: Array[String] = []
	var grove := Grove.new()
	root.add_child(grove)
	var test_positions: Array = []
	for kind in Grove.KINDS:
		for x in [9, 31, 90]:
			test_positions.append({"kind":kind, "position":Vector3(x, 0, 0), "scale":1.2, "yaw":.5})
	grove.populate(test_positions)
	if grove.get_child_count() != 9:
		errors.append("Expected three LODs per species")
	for kind in Grove.KINDS:
		var tris := 1000000
		for level in Grove.LEVELS:
			var batch := grove.get_node(kind + "_" + level) as MultiMeshInstance3D
			var mesh := batch.multimesh.mesh
			if mesh.get_surface_count() != 2 or batch.multimesh.visible_instance_count != 1:
				errors.append("Mesh or batch " + batch.name)
			var count := 0
			for i in mesh.get_surface_count():
				count += mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size() / 3
			if count >= tris:
				errors.append("LOD reduction " + batch.name)
			tris = count
			var leaves := mesh.surface_get_material(1) as StandardMaterial3D
			if leaves.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or leaves.albedo_texture == null:
				errors.append("Leaf alpha material " + batch.name)
	grove.set_quality("low")
	for kind in Grove.KINDS:
		if grove.get_node(kind + "_near").visible or grove.get_node(kind + "_far").multimesh.visible_instance_count != 2:
			errors.append("Low distance switch " + kind)
	grove.populate([])
	for batch in grove.get_children():
		if batch.visible or batch.multimesh.visible_instance_count != 0:
			errors.append("Stale batch " + batch.name)
	for name in ["han_house","wa_store","wa_house","wood_longhouse","farmer","han_farmer","wa_farmer"]:
		var packed := load("res://assets/landscape/%s.glb" % name) as PackedScene
		var object := packed.instantiate()
		root.add_child(object)
		var mesh_instance := object as MeshInstance3D
		if mesh_instance == null:
			mesh_instance = object.find_children("*","MeshInstance3D",true,false)[0]
		var mesh := mesh_instance.mesh
		var material := mesh.surface_get_material(0) as StandardMaterial3D
		if mesh.get_surface_count() != 1 or material.albedo_texture == null:
			errors.append("Architecture/worker atlas: " + name)
		if mesh.get_aabb().size.y < 1.6:
			errors.append("Metre scale: " + name)
		if name.ends_with("farmer"):
			var player := object.find_child("AnimationPlayer",true,false) as AnimationPlayer
			if not (player.has_animation("idle") and player.has_animation("march")):
				errors.append("Farmer animation clips")
			player.play("march")
			player.seek(.25,true)
			player.advance(.1)
			if not player.is_playing() or player.current_animation_position <= .25:
				errors.append("Farmer playback")
		object.free()
	grove.free()
	print("Tree import, instancing and LOD checks: ", errors)
	quit(0 if errors.is_empty() else 1)
