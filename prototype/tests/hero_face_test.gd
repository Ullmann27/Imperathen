extends SceneTree
## Imported-asset and live-presentation checks, including instance independence.

const Person := preload("res://scripts/visuals/village_person.gd")
const Face := preload("res://scripts/visuals/facial_motion.gd")
var failures := 0
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func weight(person: Person, shape: String) -> float:
	var mesh := person.body.find_child("HeroBody",true,false) as MeshInstance3D
	if not mesh:
		return -1.0
	var slot := mesh.find_blend_shape_by_name(shape)
	return mesh.get_blend_shape_value(slot) if slot >= 0 else -1.0


func triangles(person: Person) -> int:
	var total := 0
	for mesh: MeshInstance3D in person.body.find_children("*","MeshInstance3D",true,false):
		if not mesh.visible or not mesh.mesh:
			continue
		for surface in mesh.mesh.get_surface_count():
			var indices: int = mesh.mesh.surface_get_array_index_len(surface)
			total += (indices if indices > 0 else mesh.mesh.surface_get_array_len(surface)) / 3
	return total


func run() -> void:
	for level in 4:
		check(ResourceLoader.exists(Person.HERO_PATH % level,"PackedScene"),"Hero LOD%d is imported" % level)
	if failures:
		print("HERO_FACE_TEST ",checks," checks, ",failures," failed")
		quit(1)
		return
	var hero := Person.new()
	var other := Person.new()
	root.add_child(hero)
	root.add_child(other)
	hero.set_process(false)
	other.set_process(false)
	hero.configure("player","italia",12)
	other.configure("player","italia",12)
	check(hero.active_model_path == Person.HERO_PATH % 0,"Default Italia player actually selects the new model")
	check(hero.body.find_child("HeroEyes",true,false) != null,"Player has separate eye geometry")
	for shape: String in Face.SHAPES:
		check(weight(hero,shape) >= 0.0,"Authored facial shape exists: "+shape)
	check(is_zero_approx(weight(hero,"Mature")),"Young player keeps the young shape")
	var skeletons := hero.body.find_children("*","Skeleton3D",true,false)
	check(skeletons.size() == 1 and skeletons[0].get_bone_count() == 15,"Imported body uses the gameplay skeleton")
	for clip in ["idle","march","run","gather","talk","train","work","block","attack","hit","death"]:
		check(hero.animator != null and hero.animator.has_animation(clip),"Imported clip: "+clip)
	var previous_count := 1000000
	hero.sample_pose("gather",0.46)
	for level in 4:
		hero._reload(level)
		var count := triangles(hero)
		check(hero.active_model_path == Person.HERO_PATH % level,"The requested authored LOD is active")
		check(count > 0 and count < previous_count,"LOD%d really reduces triangles: %d < %d" % [level,count,previous_count])
		check(hero.animator.current_animation == "gather" and is_equal_approx(hero.phase,0.46),"LOD preserves action and pose phase")
		previous_count = count
	hero._reload(0)
	hero.sample_pose("hit",0.45)
	check(weight(hero,"BrowDown") > 0.5 and weight(hero,"JawOpen") > 0.2,"Hit animation has a visible facial reaction")
	check(is_zero_approx(weight(other,"BrowDown")) and is_zero_approx(weight(other,"JawOpen")),"Shared imported resources do not share facial weights")
	hero.sample_pose("talk",0.32)
	check(weight(hero,"JawOpen") > 0.05,"Silent talk clip drives expressive mouth motion")
	hero.reset_motion()
	var blink_max := 0.0
	var saw_open_after_blink := false
	for frame in 360:
		hero._process(1.0 / 60.0)
		blink_max = maxf(blink_max,weight(hero,"Blink_L"))
		if blink_max > 0.85 and is_zero_approx(weight(hero,"Blink_L")):
			saw_open_after_blink = true
	check(blink_max > 0.85 and saw_open_after_blink,"Live idle actually closes and reopens an eyelid")
	check(is_zero_approx(weight(other,"Blink_L")),"A second actor is not changed by the first actor's blink")
	other.free()
	hero.sample_pose("death",0.7)
	check(weight(hero,"Blink_L") > 0.99 and weight(hero,"Blink_R") > 0.99,"Death pose closes both eyelids")
	var near_mesh: WeakRef = weakref((hero.body.find_child("HeroBody",true,false) as MeshInstance3D).mesh)
	hero._reload(3)
	check(near_mesh.get_ref() == null,"Unused near geometry is released after a far LOD switch")
	for shape: String in Face.SHAPES:
		check(is_zero_approx(weight(hero,shape)),"Far LOD clears facial animation: "+shape)
	hero.configure("player","italia",18)
	hero._reload(0)
	check(weight(hero,"Mature") > 0.99 and is_equal_approx(hero.body.scale.y,1.14),"Adult selection applies the new age shape and height")
	var camera := Camera3D.new()
	root.add_child(camera)
	hero.profile = "balanced"
	for sample in [[8.0,0],[9.65,0],[10.6,1],[9.3,1],[8.3,0]]:
		camera.global_position = hero.global_position + Vector3.BACK * float(sample[0])
		hero.refresh_lod(camera)
		check(hero.detail == int(sample[1]),"LOD hysteresis preserves detail at %.2f metres" % float(sample[0]))
	camera.free()
	hero.configure("player","han",12)
	check(hero.active_model_path.begins_with("res://assets/village_characters/"),"Other origins retain their authored identity")
	hero.free()
	print("HERO_FACE_TEST ",checks," checks, ",failures," failed")
	quit(0 if failures == 0 else 1)
