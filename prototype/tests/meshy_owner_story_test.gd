extends SceneTree
## Production world, real rigged story character, saved identity and dialogue.
const Person := preload("res://scripts/visuals/village_person.gd")
const Registry := preload("res://scripts/visuals/meshy_character_registry.gd")
const Village := preload("res://scripts/world/village_life_world.gd")
const Model := preload("res://scripts/domain/world_model.gd")
const Childhood := preload("res://scripts/story/village_childhood.gd")
const MissionData := preload("res://scripts/story/mission_data.gd")
const SkinTest := preload("res://tests/motion_skin_measurement.gd")
const CLIPS := ["idle","march","run","talk","work","gather","train","attack","block","hit","death"]
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(why)

func _run() -> void:
	var model := Model.new()
	model.new_game("italia",true,true,false,true)
	var village := Village.new()
	root.add_child(village)
	village.set_physics_process(false)
	var before: Dictionary = model.data.duplicate(true)
	village.sync_state(model.data,"balanced")
	var actor := village.get_node_or_null("Resident_sextus") as CharacterBody3D
	check(is_instance_valid(actor),"Sextus exists as a physical story resident")
	if not is_instance_valid(actor):
		quit(1)
		return
	var figure := actor.get_node("Figure") as Person
	check(figure.resident_id == "sextus","Saved story identity survives model selection")
	check(actor.get_node("Nameplate").text.contains("Dorfschmied"),"Profession matches the story")
	check(model.data == before,"Presentation does not mutate quest, economy or relationships")
	var required := OS.get_environment("IMPERATHEN_REQUIRE_SEXTUS") == "1"
	if required:
		check(Registry.has_complete_set("unit_legacy_blacksmith"),"All four exact owner derivative files imported")
	if not Registry.has_complete_set("unit_legacy_blacksmith"):
		check(not figure.active_model_path.contains("unit_legacy_blacksmith"),"Safe fallback when private derivative is unstaged")
	else:
		figure.set_process(false)
		check(figure._uses_owner_civilian(),"Sextus uses the owner model on the actual story actor")
		for level in 4:
			figure._reload(level)
			check(figure.active_model_path == Registry.PATH % ["unit_legacy_blacksmith",level],"Sextus retains exact identity in LOD " + str(level))
			check(figure.animator != null,"Actual animator")
			for action: String in CLIPS:
				check(figure.animator.has_animation(action),"Imported action " + action)
			figure.sample_pose("march",0.13)
			var rig := figure._motion.skeleton
			var foot := rig.get_bone_global_pose(rig.find_bone("Foot_R")).origin
			figure.sample_pose("march",0.65)
			check(foot.distance_to(rig.get_bone_global_pose(rig.find_bone("Foot_R")).origin) > 0.12,"Real leg moves")
			var skin := SkinTest.new()
			skin.bind(figure.body)
			check(skin.errors.is_empty(),"Actual skin measurement binds")
			for action: String in ["idle","march","run","talk","work","attack","death"]:
				for at: float in [0.15,0.45,0.8]:
					figure.sample_pose(action,at)
					var result: Dictionary = skin.sample()
					check(bool(result.finite) and int(result.skin_edge_violations)==0,"Real geometry remains coherent: "+action+" LOD "+str(level))
			figure.sample_pose("work",0.30)
			var hand := rig.get_bone_global_pose(rig.find_bone("Hand_R")).origin
			figure.sample_pose("work",0.70)
			check(hand.distance_to(rig.get_bone_global_pose(rig.find_bone("Hand_R")).origin)>0.025,"Smith has animated work movement")
		figure.reset_motion()
		village.focus("sextus",actor.global_position+Vector3(0,0,-1))
		check(figure.clip == "talk","Existing story interaction starts actual speaking pose")
		village.clear_focus()
		check(not figure._conversation_focused,"Conversation exits cleanly")
		figure.reset_motion()
		figure.drive(1.30)
		figure._check_lod=10000.0
		for i in 30:
			figure._process(1.0/60.0)
		check(figure.clip=="march","Owner figure participates in normal locomotion")
		figure.drive(0.0)
		figure.reset_motion()
		figure.set_resident_prop("basket")
		figure._process(1.0/60.0)
		check(is_instance_valid(figure._resident_prop) and figure._resident_prop.visible,"Actual hand carries existing prop")
		figure.set_resident_prop("")
	var other := Person.new()
	root.add_child(other)
	other.configure_resident("italia",40,"civilian_man",1,null,"vil:vibius")
	check(not other.configure_meshy("unit_legacy_blacksmith"),"Do not clone Sextus onto Vibius")
	other.configure("player","italia",12)
	check(not other.configure_meshy("unit_legacy_blacksmith"),"Do not replace original youth")
	other.free()
	check(model.data == before,"Role and animation tests do not change authoritative story")
	village.free()
	print("MESHY_OWNER_STORY_PASS" if failures==0 else "MESHY_OWNER_STORY_FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
