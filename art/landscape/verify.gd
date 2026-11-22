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
			if not Grove.CANOPY_BOUNDS[kind].encloses(mesh.get_aabb()):
				errors.append("Culling bound clips native mesh " + batch.name)
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
	await _verify_frustum(errors)
	print("Tree import, instancing and LOD checks: ", errors)
	quit(0 if errors.is_empty() else 1)

func _verify_frustum(errors: Array[String]) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(320,320)
	view.own_world_3d = true
	root.add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(0,4,0)
	camera.set_orthogonal(16,0.2,70)
	camera.current = true
	var grove := Grove.new()
	view.add_child(grove)
	var sites := [
		{"kind":"oak", "position":Vector3(0,0,-16)}, # Entire canopy inside.
		{"kind":"oak", "position":Vector3(11,0,-12)}, # Only its canopy is inside.
		{"kind":"olive", "position":Vector3(19,0,-18)}, # Outside until a wider view.
		{"kind":"pine", "position":Vector3(0,0,24)}, # Behind the camera.
		{"kind":"oak", "position":Vector3(0,0,-90)}, # Beyond the far plane.
		{"kind":"pine", "position":Vector3(0,-15,-29), "scale":2.0, "yaw":1.24},
	]
	grove.populate(sites)
	var counts: Array[int] = []
	_expect_visible(grove,3,"narrow view including two boundary canopies",counts,errors)
	camera.rotation.y = PI
	_expect_visible(grove,1,"camera turns in place",counts,errors)
	camera.rotation.y = 0
	camera.size = 44
	_expect_visible(grove,4,"orthographic zoom",counts,errors)
	camera.size = 16
	view.size = Vector2i(640,320)
	await process_frame
	_expect_visible(grove,4,"wider aspect",counts,errors)
	view.size = Vector2i(320,320)
	await process_frame
	camera.far = 120
	_expect_visible(grove,4,"far clip change",counts,errors)
	camera.far = 70
	grove.position.x = 80
	_expect_visible(grove,0,"translated grove",counts,errors)
	grove.position.x = 0
	camera.set_perspective(27,0.2,70)
	_expect_visible(grove,2,"perspective narrows",counts,errors)
	camera.fov = 110
	_expect_visible(grove,4,"perspective zoom in place",counts,errors)
	print("Fixed six-tree camera fixture, submitted counts: ", counts)
	view.free()

func _expect_visible(grove, expected: int, label_text: String, counts: Array[int], errors: Array[String]) -> void:
	grove._process(0.0)
	counts.append(grove.visible_tree_count)
	var submitted := 0
	for batch: MultiMeshInstance3D in grove.get_children():
		if batch.visible:
			submitted += batch.multimesh.visible_instance_count
	var lod: Vector3i = grove.visible_tree_lods
	if grove.visible_tree_count != expected or submitted != expected or lod.x+lod.y+lod.z != expected:
		errors.append("%s: expected %d trees, submitted %d" % [label_text,expected,submitted])
