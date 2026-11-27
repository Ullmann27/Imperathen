extends SceneTree
## Actual four-LOD asset and campaign entry. No mock model can pass full QA.
const Person := preload("res://scripts/visuals/village_person.gd")
const World := preload("res://scripts/world/game_world.gd")
const Model := preload("res://scripts/domain/world_model.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _triangles(person: Person) -> int:
	var total := 0
	for part: MeshInstance3D in person.body.find_children("*","MeshInstance3D",true,false):
		if part.mesh and part.visible:
			for surface in part.mesh.get_surface_count():
				total += part.mesh.surface_get_array_index_len(surface) / 3
	return total

func _run() -> void:
	if not Person.MarcusModel.installed():
		# Source-only development can still run the legacy actor. Release/QA
		# explicitly requires the actual generated family.
		if OS.get_environment("IMPERATHEN_REQUIRE_MARCUS") != "1" and OS.get_environment("IMPERATHEN_FULL_ASSET_ACCEPTANCE") != "1":
			print("MARCUS_ASSET_NOT_STAGED")
			quit(0)
			return
		_check(false,"All four actual Marcus GLBs must be imported")
		quit(1)
		return
	var model := Model.new()
	model.new_game("italia",true,true,false,true)
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_physics_process(false)
	var friend := world.get_node("Marcus/Figure") as Person
	var hero := world.get_node("Player/Figure") as Person
	_check(friend.identity == "marcus" and Person.MarcusModel.owns(friend.active_model_path),"Actual campaign uses the distinct Marcus family")
	_check(not Person.MarcusModel.owns(hero.active_model_path),"Player identity is untouched")
	friend.set_process(false)
	var previous := 1000000
	friend.sample_pose("march",.37)
	for level in 4:
		friend._reload(level)
		_check(friend.active_model_path == Person.MarcusModel.PATH % level,"Actual Marcus LOD %d" % level)
		var body := friend.body.find_child("HeroBody",true,false) as MeshInstance3D
		var rigs := friend.body.find_children("*","Skeleton3D",true,false)
		_check(body != null and body.skin != null and not rigs.is_empty() and (rigs[0] as Skeleton3D).get_bone_count() == 17,"Compatible skinned anatomy with two eye joints")
		_check(friend._gaze.eyes.size() == 2,"Actual eye pair is bound at LOD %d" % level)
		if body:
			var mature := body.find_blend_shape_by_name("Mature")
			var jaw := body.find_blend_shape_by_name("JawOpen")
			_check(mature >= 0 and body.get_blend_shape_value(mature) == 0.0 and jaw >= 0,"Youth age and facial shapes")
			var mat := body.get_active_material(0) as StandardMaterial3D
			_check(mat != null and mat.albedo_texture != null,"Actual embedded skin texture")
		var tunic := friend.body.find_child("HeroTunic",true,false) as MeshInstance3D
		if tunic:
			var cloth := tunic.get_active_material(0) as StandardMaterial3D
			_check(cloth != null and cloth.albedo_texture != null and cloth.normal_texture != null and cloth.roughness_texture != null,"Woven PBR tunic")
		else:
			_check(false,"Tunic is present")
		var triangles := _triangles(friend)
		_check(triangles > 0 and triangles < previous,"LOD triangle counts decrease")
		previous = triangles
		_check(friend.animator != null and friend.animator.current_animation == "march" and is_equal_approx(friend.phase,.37),"Animation phase survives LOD")
	friend._reload(0)
	friend.sample_pose("talk",.3)
	var face := friend.body.find_child("HeroBody",true,false) as MeshInstance3D
	if face:
		var jaw := face.find_blend_shape_by_name("JawOpen")
		_check(jaw >= 0 and face.get_blend_shape_value(jaw) > 0.0,"Dialogue moves the actual mouth")
	friend.configure("companion","italia",18)
	_check(Person.MarcusModel.owns(friend.active_model_path),"Adult Marcus retains his own identity")
	var adult := friend.body.find_child("HeroBody",true,false) as MeshInstance3D
	_check(Person.MarcusModel.eye_offsets(true).size() == 2,"Mature eye centres calibrated from real source")
	if adult:
		var slot := adult.find_blend_shape_by_name("Mature")
		_check(slot >= 0 and adult.get_blend_shape_value(slot) > .99,"Adult morphology is active")
	friend.configure("companion","germania",12)
	_check(not Person.MarcusModel.owns(friend.active_model_path),"Other cultures keep their own companion")
	world.free()
	await process_frame
	await preload("res://tests/character_head_focus_checks.gd").run(self, _check)
	await process_frame
	print("MARCUS_CHARACTER_PASS" if failures == 0 else "MARCUS_CHARACTER_FAIL"," ",checks," checks, ",failures," failed")
	quit(0 if failures == 0 else 1)
