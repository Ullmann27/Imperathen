extends SceneTree

const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
var failed := 0
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(description)


func surface(shape: MeshInstance3D, label: String) -> StandardMaterial3D:
	for i in shape.mesh.get_surface_count():
		var source := shape.mesh.surface_get_material(i)
		if source.resource_name == label: return shape.get_active_material(i)
	return null


func metrics(person: Person) -> int:
	var result := 0
	for shape: MeshInstance3D in person.body.find_children("*","MeshInstance3D",true,false):
		if not shape.visible: continue
		for i in shape.mesh.get_surface_count():
			result += shape.mesh.surface_get_array_index_len(i)
	return result / 3


func run() -> void:
	var world := World.new()
	var model := Model.new()
	root.add_child(world)
	var swatches := {}
	for home: String in Person.COMPANIONS:
		model.new_game(home)
		world.setup(model.data)
		world.set_physics_process(false)
		var hero: Person = world.get_node("Player/Figure")
		var friend: Person = world.get_node("Marcus/Figure")
		var state_before := model.data.duplicate(true)
		for person: Person in [hero,friend]:
			var hero_asset := person.active_model_path.begins_with("res://assets/characters/hero_quality_")
			var civilian: MeshInstance3D = person.body.find_child("HeroBody" if hero_asset else "Civilian",true,false)
			var skeleton: Skeleton3D = person.body.find_children("*","Skeleton3D",true,false)[0]
			check(civilian.skin != null and skeleton.get_bone_count() == 15,home+" uses the imported skin")
			var face := surface(civilian,"HeroSkin" if hero_asset else "PortraitSkin")
			var expected: String = "hero_"+home if person == hero else Person.COMPANIONS[home]
			if hero_asset:
				check(face != null and face.albedo_texture != null,expected+" authored UV skin is preserved")
			else:
				check(face != null and face.albedo_texture.resource_path.ends_with("/"+expected+".webp"),expected+" face texture on visible skin")
			var garment := person.body.find_child("HeroTunic",true,false) as MeshInstance3D if hero_asset else civilian
			var tunic := surface(garment,"HeroLinen" if hero_asset else "Civilian_Linen")
			check(tunic != null and tunic.albedo_texture != null and tunic.normal_texture != null and tunic.roughness_texture != null,expected+" linen texture, normal and roughness")
			if person == hero: swatches[tunic.albedo_color.to_html()] = true
			if not hero_asset:
				for region: String in Person.COMPANIONS:
					check(person.body.find_child("Garment_"+region,true,false).visible == (region == home), expected+" only equips its regional garment")
			check(civilian.get_blend_shape_value(civilian.find_blend_shape_by_name("Companion")) == float(person == friend),expected+" identity shape")
			check(civilian.get_blend_shape_value(civilian.find_blend_shape_by_name("Mature")) == 0.0,expected+" youth shape")
		var previous := 1000000
		hero.sample_pose("gather",.46)
		for level in 4:
			hero._reload(level)
			var triangles := metrics(hero)
			check(triangles > 0 and triangles < previous,"%s LOD %d actual triangles %d < %d" % [home,level,triangles,previous])
			previous = triangles
			check(hero.animator.current_animation == "gather" and is_equal_approx(hero.animator.current_animation_position/hero.animator.current_animation_length,.46),"same posed frame at new LOD")
		for quality in ["low","balanced","high","very_high"]:
			world.set_quality(quality)
			check(hero.profile == quality and friend.profile == quality,"both live actors receive profile "+quality)
		check(model.data == state_before,home+" model unchanged by rendered choices")
	check(swatches.size() == 5,"all five home tunics use separate material tints")
	model.new_game()
	world.setup(model.data)
	var hero: Person = world.get_node("Player/Figure")
	var mentor: Person = world.get_node("TrainingGround/Mentor/Figure")
	hero._reload(0)
	var skeleton: Skeleton3D = hero.body.find_children("*","Skeleton3D",true,false)[0]
	for clip in ["idle","march","run","talk","gather","train","attack","work","block","hit","death"]:
		hero.sample_pose(clip,.48)
		check(hero.animator.current_animation == clip and hero.animator.current_animation_length > .25,clip+" actual GLB clip")
		var changed := false
		for joint in skeleton.get_bone_count():
			if skeleton.get_bone_pose_rotation(joint).angle_to(Quaternion.IDENTITY) > .015: changed = true
		check(changed,clip+" actually rotates the rig")
		check(not hero.body.find_child("PracticeBlade",true,false).visible,"child uses bare hands")
	world._player.position = World.TRAINING_LOCATION
	world._attack()
	check(hero.clip == "train" and mentor.animator.current_animation == "block","live training action triggers two independent clips")
	var state := model.data.duplicate(true)
	state.buildings = [{"id":"hut_1","x":8.0,"z":4.0,"progress":0.0,"completed":false}]
	state.player.age = 18
	state.squad.alive = 1
	state.encounter.enemies = [{"id":"rover","x":6.0,"z":7.0,"health":60}]
	world.sync_state(state)
	check(hero.clip == "work","new paid building starts work clip")
	hero._process(.1)
	var time_before := hero.phase
	state.buildings[0].progress = .12
	world.sync_state(state)
	check(hero.clip == "work" and is_equal_approx(hero.phase,time_before),"construction progress preserves work phase")
	var hero_asset := hero.active_model_path.begins_with("res://assets/characters/hero_quality_")
	var adult: MeshInstance3D = hero.body.find_child("HeroBody" if hero_asset else "Civilian",true,false)
	check(hero.body.scale.y > 1.10 and adult.get_blend_shape_value(adult.find_blend_shape_by_name("Mature")) > .99,"adult height and proportions")
	if hero_asset:
		check(surface(adult,"HeroSkin").albedo_texture != null,"adult keeps authored skin UV")
	else:
		check(surface(adult,"PortraitSkin").albedo_texture.resource_path.ends_with("/adult_italia.webp"),"adult Italian portrait UV")
	hero.sample_pose("train",.4)
	check(hero.body.find_child("PracticeBlade",true,false).visible,"adult practice equipment follows action")
	hero.sample_pose("idle",.4)
	check(not hero.body.find_child("PracticeBlade",true,false).visible,"idle stows equipment")
	for node_path in ["TrainingGround/Mentor/Figure","Squad/Recruit1/Figure","Encounter/rover/Figure"]:
		var soldier: Person = world.get_node(node_path)
		var previous := 1000000
		soldier.sample_pose("block",.43)
		for level in 4:
			soldier._reload(level)
			var count := metrics(soldier)
			check(count > 0 and count < previous and soldier.animator.current_animation == "block", "%s skinned LOD%d (%d triangles)" % [node_path,level,count])
			previous = count
	var camera: Camera3D = world.get_node("WorldCamera")
	mentor.sample_pose("block",.38)
	for distance: float in [100.0,1.25]:
		camera.global_position = mentor.global_position + Vector3.BACK * distance
		mentor.refresh_lod(camera)
		check(mentor.detail == (3 if distance > 50 else 0),"frozen camera distance immediately selects real NPC LOD")
		check(is_equal_approx(mentor.animator.current_animation_position / mentor.animator.current_animation_length,.38),"fixed photographic pose survives camera LOD")
	state.player.health = 70
	state.encounter.enemies[0].health = 30
	world.sync_state(state)
	check(hero.clip == "hit" and world.get_node("Encounter/rover/Figure").clip == "hit","actual health loss cues both figures")
	state.player.health = 0
	world.sync_state(state)
	check(hero.clip == "death","fallen player uses death pose")
	world.setup(state)
	check(hero.clip == "death","loading a fallen save restores the pose")
	world.setup(model.data)
	check(hero.clip == "idle","new life resets old death pose")
	world.free()
	print("VILLAGE_PERSON_TEST ",checks," checks, ",failed," failed")
	quit(1 if failed else 0)
