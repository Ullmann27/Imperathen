extends SceneTree
## Imported cast, animation continuity, individual materials and profile budgets.

const Person := preload("res://scripts/visuals/village_person.gd")
const Soldier := preload("res://scripts/visuals/soldier_visual.gd")
const IDENTITIES := ["civilian_man", "civilian_woman", "elder", "legionary", "officer", "spearman", "archer"]
const BUDGETS := [24000, 10000, 3500, 1300]
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)


func _triangles(person: Person) -> int:
	var count := 0
	for mesh: MeshInstance3D in person.body.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			count += mesh.mesh.surface_get_array_index_len(surface) / 3
	return count


func _resident(identity: String, variation: int = 0) -> Person:
	var actor := Person.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.configure("resident", "italia", 65 if identity == "elder" else 28)
	actor.configure_appearance(identity, variation)
	return actor


func _cloth(person: Person) -> StandardMaterial3D:
	return (person.body.find_child("HeroTunic", true, false) as MeshInstance3D).get_active_material(0) as StandardMaterial3D


func _run() -> void:
	for identity: String in IDENTITIES:
		var person := _resident(identity, 4)
		person.sample_pose("march", 0.37)
		var previous := 100000
		for level in 4:
			person._reload(level)
			_check(person.active_model_path == "res://assets/characters/frontier_%s_%d.glb" % [identity, level], identity + " uses the new imported LOD")
			var body := person.body.find_child("HeroBody", true, false) as MeshInstance3D
			_check(body != null and body.skin != null, identity + " has anatomical skinned body")
			var skeleton := person.body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			_check(skeleton.get_bone_count() == (17 if identity == "archer" else 15), identity + " retained runtime rig")
			var triangles := _triangles(person)
			_check(triangles > 0 and triangles < previous and triangles <= BUDGETS[level], "%s LOD %d actual budget %d" % [identity, level, triangles])
			previous = triangles
			_check(person.animator.current_animation == "march" and is_equal_approx(person.animator.current_animation_position / person.animator.current_animation_length, 0.37), identity + " phase survives LOD switch")
			var jaw := body.find_blend_shape_by_name("JawOpen")
			_check((jaw >= 0) == (level < 2), identity + " facial morphs only on the two nearby tiers")
			if jaw >= 0:
				person._face.pose("talk", 0.15, level)
				_check(body.get_blend_shape_value(jaw) > 0.05, identity + " live face controller drives the imported jaw")
				person._face.pose("idle", 0.0, level)
			_check(body.find_blend_shape_by_name("Mature") < 0, identity + " adult anatomy baked once")
		person._reload(0)
		person.sample_pose("march", 0.11)
		var rig := person.body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var hand := rig.find_bone("Hand_R")
		var before := rig.get_bone_global_pose(hand).origin
		person.sample_pose("march", 0.43)
		_check(before.distance_to(rig.get_bone_global_pose(hand).origin) > 0.015, identity + " real motion changes the bound hand")
		person.free()
	_test_material_independence()
	_test_profiles_and_routes()
	for role: String in Soldier.ROLES:
		var soldier := Soldier.new()
		soldier.configure(role, 1)
		root.add_child(soldier)
		for level in [0, 1]:
			soldier.set_detail(level)
			_check(soldier.find_child("HeroBody", true, false) != null and soldier.find_child("FrontierRomanKit", true, false) != null, role + " battle actor selects new anatomy and equipment")
			soldier.present("shoot" if role == "archer" else "wall", 0.2, 0.1)
			_check(soldier.player.current_animation == ("shoot" if role == "archer" else "wall"), role + " battle pose remains available")
		soldier.set_detail(2)
		_check(soldier.player == null and Soldier.far_mesh(role) != null, role + " keeps cheap instanced distant silhouette")
		soldier.free()
	print("FRONTIER_PEOPLE_PASS" if failures == 0 else "FRONTIER_PEOPLE_FAIL", " ", checks, " checks, ", failures, " failed")
	quit(0 if failures == 0 else 1)


func _test_material_independence() -> void:
	var first := _resident("civilian_man", 0)
	var second := _resident("civilian_man", 0)
	var first_body := first.body.find_child("HeroBody", true, false) as MeshInstance3D
	var second_body := second.body.find_child("HeroBody", true, false) as MeshInstance3D
	_check(first_body.mesh == second_body.mesh, "residents share immutable geometry")
	_check(_cloth(first) == _cloth(second), "same variant reuses its material")
	var original := _cloth(first).albedo_color
	second.configure_appearance("civilian_man", 1)
	_check(_cloth(first) != _cloth(second) and _cloth(first).albedo_color != _cloth(second).albedo_color, "clothing variants are visibly distinct")
	_check(_cloth(first).albedo_color == original, "changing one resident cannot recolour a neighbour")
	_check(not is_equal_approx(first.body.scale.y, second.body.scale.y), "stable adult stature variation")
	var source := (first.body.find_child("HeroTunic", true, false) as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	_check(source.albedo_color == Color.WHITE, "original shared source material is unchanged")
	first.free()
	second.free()


func _test_profiles_and_routes() -> void:
	var person := _resident("elder")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 0, 20)
	var selected := {"low": 3, "balanced": 2, "high": 2, "very_high": 1}
	for profile: String in selected:
		person.profile = profile
		person.refresh_lod(camera)
		_check(person.detail == selected[profile], profile + " applies the crowd distance budget")
	person.configure("resident", "italia", 16)
	_check(not "frontier_" in person.active_model_path, "adult appearance never replaces a child")
	person.configure("resident", "italia", 28)
	person.configure_appearance("invalid_id", 5)
	_check(not "frontier_" in person.active_model_path and person.body != null, "invalid appearance has a working legacy resident fallback")
	person.configure("player", "italia", 22)
	_check("hero_quality_" in person.active_model_path, "main player retains the existing hero asset")
	var hair := person.body.find_child("HeroHair", true, false) as MeshInstance3D
	_check(hair != null and hair.get_active_material(0) == hair.mesh.surface_get_material(0), "resident colour variation does not alter player hair")
	person.free()
	camera.free()
