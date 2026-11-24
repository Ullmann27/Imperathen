extends SceneTree
## Exercise imported skins and the production actor; optional real viewport QA.

const Person := preload("res://scripts/visuals/village_person.gd")
const Registry := preload("res://scripts/visuals/meshy_character_registry.gd")
const IDS := ["unit_roman_signifer", "unit_germanic_axe_fighter"]
const CLIPS := ["idle", "march", "run", "talk", "work", "gather", "train", "attack", "block", "hit", "death"]
const BUDGETS := [28000, 10000, 3500, 1200]
var checks := 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var stage: Node3D
var camera: Camera3D
var output := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
		DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	_setup_studio()
	# Every unresolved source must remain outside the production biped
	# pipeline until its individual geometry, rig and clips are validated.
	for blocked_id: String in ["unit_roman_heavy_cavalry_rider","unit_roman_light_cavalry_rider","unit_roman_aux_archer","unit_germanic_light_spearman","unit_germanic_mounted_retainer"]:
		_check(not Registry.has_complete_set(blocked_id), blocked_id + " unresolved source cannot enter the biped route")
		for level in 4:
			_check(Registry.path_for(blocked_id,32,level).is_empty(), blocked_id + " cannot bypass the blocked-source gate at tier " + str(level))
	_check(not Registry.has_complete_set("../source/character/unit_roman_signifer"), "Unregistered source/path cannot enter runtime")
	for id: String in IDS:
		var person := Person.new()
		stage.add_child(person)
		person.position.y = .9
		person.set_process(false)
		person.configure_resident("italia" if "roman" in id else "germania", 32, "legionary" if "roman" in id else "spearman")
		_check(person.configure_meshy(id), id + " is selectable through production actor")
		for level in 4:
			person._reload(level)
			_check(person.active_model_path == Registry.PATH % [id, level], id + " exact imported tier " + str(level))
			person.reset_motion()
			person.drive(1.30)
			person._check_lod = 1.0
			_check(absf(person.locomotion_stride("march") - 1.30) < .0001, id + " authored walk stride at tier " + str(level))
			_check(absf(person.locomotion_stride("run") - 1.75) < .0001, id + " authored run stride at tier " + str(level))
			for frame in 30:
				person._process(1.0 / 60.0)
			_check(person.clip == "march" and absf(person.phase - .5) < .002, id + " half stride advances half a cycle without skating")
			var meshes: Array[MeshInstance3D] = []
			for candidate: Node in person.body.find_children("*", "MeshInstance3D", true, false):
				var candidate_mesh := candidate as MeshInstance3D
				if candidate_mesh.skin != null:
					meshes.append(candidate_mesh)
			var rigs := person.body.find_children("*", "Skeleton3D", true, false)
			_check(meshes.size() == 1 and rigs.size() == 1, id + " has one skinned body and one rig")
			if meshes.is_empty() or rigs.is_empty():
				continue
			var mesh := meshes[0] as MeshInstance3D
			var rig := rigs[0] as Skeleton3D
			if level == 0:
				person.sample_pose("idle", 0.0)
				rig.force_update_all_bone_transforms()
				print("MESHY_REST_SKIN_EDGES ", id, " ", _stretched_edges(mesh, rig))
			_check(mesh.skin != null and rig.get_bone_count() == 15, id + " has bound 15-joint skin")
			var triangles := 0
			for surface in mesh.mesh.get_surface_count():
				triangles += mesh.mesh.surface_get_array_index_len(surface) / 3
				var arrays := mesh.mesh.surface_get_arrays(surface)
				_check((arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() > 0, id + " keeps joint indices at tier " + str(level))
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var normalized := weights.size() > 0 and weights.size() % 4 == 0
				for offset in range(0, weights.size(), 4):
					var total := 0.0
					for influence in 4:
						var weight := weights[offset + influence]
						normalized = normalized and is_finite(weight) and weight >= 0.0
						total += weight
					normalized = normalized and absf(total - 1.0) < .002
				_check(normalized, id + " finite normalized vertex weights at tier " + str(level))
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				_check(material != null and material.albedo_texture != null, id + " preserved textured material")
			_check(triangles > 0 and triangles <= BUDGETS[level], id + " measured triangle budget " + str(level))
			for clip: String in CLIPS:
				_check(person.animator != null and person.animator.has_animation(clip), id + " imported action " + clip)
			person.sample_pose("march", .13)
			rig.force_update_all_bone_transforms()
			var hand := rig.get_bone_global_pose(rig.find_bone("Hand_R")).origin
			var foot := rig.get_bone_global_pose(rig.find_bone("Foot_R")).origin
			person.sample_pose("march", .65)
			rig.force_update_all_bone_transforms()
			_check(hand.distance_to(rig.get_bone_global_pose(rig.find_bone("Hand_R")).origin) > .035, id + " walks with changing bound hand position")
			_check(foot.distance_to(rig.get_bone_global_pose(rig.find_bone("Foot_R")).origin) > .12, id + " walks with changing bound foot position")
			person.sample_pose("attack", .55)
			rig.force_update_all_bone_transforms()
			_check(_stretched_edges(mesh, rig) == 0, id + " attack does not stretch skin edges into long strips at tier " + str(level))
			# Newly supported imported axe/shield actions must satisfy the
			# same real skin-deformation gate as the original baked attack.
			if id == "unit_germanic_axe_fighter":
				for style: String in ["cut_inward","cut_outward","overhead","turn_cut","guard_front","guard_high","guard_low","guard_left","guard_right"]:
					_check(person.sample_armed_pose(style,.56),id+" has actual "+style+" at tier "+str(level))
					rig.force_update_all_bone_transforms()
					_check(_stretched_edges(mesh,rig)==0,id+" "+style+" keeps real skin edges at tier "+str(level))
			person.sample_pose("run", .37)
			person._reload((level + 1) % 4)
			_check(person.clip == "run" and absf(person.phase - .37) < .001, id + " action phase survives tier replacement")
		person._reload(0)
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			for pose: String in ["idle", "march", "run", "attack"]:
				person.sample_pose(pose, .13 if pose != "attack" else .55)
				await _capture(person, id + "-" + pose)
			person._reload(2)
			person.sample_pose("march", .65)
			await _capture(person, id + "-lod2-march")
		person.configure("player", "italia", 12)
		_check(not person.configure_meshy(id), "Adult Meshy identity cannot replace the player child")
		_check("hero_quality_" in person.active_model_path, "Child keeps authored hero after rejected Meshy override")
		person.free()
	var report := {"engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"scope": "Imported derivative and production VillagePerson studio test", "android_device_test": false,
		"checks": checks, "failures": failures, "captures": captures}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	stage.free()
	print("MESHY_CHARACTERS_PASS" if failures.is_empty() else "MESHY_CHARACTERS_FAIL", " ", checks, " checks, ", failures.size(), " failed")
	quit(0 if failures.is_empty() else 1)


func _stretched_edges(mesh: MeshInstance3D, rig: Skeleton3D) -> int:
	# Verify the actual imported vertex skin, not merely that bones animate.
	var transforms: Array[Transform3D] = []
	for index in mesh.skin.get_bind_count():
		var name := String(mesh.skin.get_bind_name(index))
		var bone := rig.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(index)
		if bone < 0:
			return 1
		transforms.append(rig.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(index))
	var stretched := 0
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var posed := PackedVector3Array()
		posed.resize(vertices.size())
		for vertex in vertices.size():
			var value := Vector3.ZERO
			for slot in 4:
				var offset := vertex * 4 + slot
				value += (transforms[joints[offset]] * vertices[vertex]) * weights[offset]
			posed[vertex] = value
		for triangle in range(0, indices.size(), 3):
			for edge in 3:
				var a := indices[triangle + edge]
				var b := indices[triangle + (edge + 1) % 3]
				var rest_length := vertices[a].distance_to(vertices[b])
				if posed[a].distance_to(posed[b]) > rest_length * 7.0 + .03:
					stretched += 1
					if stretched <= 3:
						print("MESHY_SKIN_EDGE ", JSON.stringify({"a": str(vertices[a]), "b": str(vertices[b]), "rest_length": rest_length, "posed_length": posed[a].distance_to(posed[b])}))
	return stretched


func _setup_studio() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.07, .08, .10)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.75, .82, .95)
	environment.environment.ambient_light_energy = .45
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 154, 0)
	key.light_color = Color(1, .90, .78)
	key.light_energy = .90
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.8, 2.2, -2.0)
	fill.light_energy = .35
	stage.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(8, 8)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(.13, .15, .17)
	floor_mesh.material_override = floor_material
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.current = true
	camera.position = Vector3(.65, 1.1, -4.0)
	stage.add_child(camera)
	camera.look_at(Vector3(0, .94, 0))
	camera.fov = 34


func _capture(person: Person, label: String) -> void:
	for frame in 4:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "Viewport produced " + label)
	if image != null and not image.is_empty():
		_check(image.save_png(output.path_join(label + ".png")) == OK, "Saved viewport " + label)
	captures.append({"file": label + ".png", "asset": person.active_model_path,
		"action": person.clip, "phase": person.phase, "level": person.detail,
		"pixels": [root.size.x, root.size.y]})
