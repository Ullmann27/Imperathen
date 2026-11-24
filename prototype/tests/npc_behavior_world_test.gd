extends SceneTree
## Production bodies, swept collisions and animation following an actual intention.

const Model = preload("res://scripts/domain/world_model.gd")
const World = preload("res://scripts/world/game_world.gd")
const Behavior = preload("res://scripts/domain/npc_behavior.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(true)
	world.set_physics_process(false)
	model.npc_observations = world.npc_observations
	await physics_frame
	await physics_frame
	_check(world.population.actors.size() == 26 and world.village_life_world.actors.size() == 15,"Decisions reuse all existing residents without duplicate bodies")
	var population: Node3D = world.population
	var actor: CharacterBody3D = population.actors.marcellus
	var behavior: Dictionary = model.data.village.behavior.people.marcellus
	var original := actor.position
	behavior.activity = "explore"
	behavior.reason = "curiosity"
	population.sync_behavior(model.data)
	for tick in 20:
		await physics_frame
		population.advance_to(float(tick+1)*0.1)
	_check(actor.position.distance_to(original) > 1.0,"Curiosity causes real collision-checked movement along a village path")
	_check(float(population.behavior_observations().marcellus.route_distance) > 1.0,"Observed route progress follows the actual body")
	_check(actor.get_meta("activity","") == "march" and actor.get_node("Figure").speed > 0.1,"Walking intent is visible through the production locomotion driver")
	# A resident may become tired anywhere, not only at the workplace.
	behavior.activity = "rest"
	behavior.reason = "tired"
	var offsite_rest := actor.position
	var offsite_distance := float(population.behavior_observations().marcellus.route_distance)
	for tick in 7:
		await physics_frame
		population.advance_to(population.seconds+0.1)
	_check(actor.position.distance_to(offsite_rest) < 0.04,"Rest away from work stops actual travel at the current position")
	_check(is_equal_approx(float(population.behavior_observations().marcellus.route_distance),offsite_distance),"Rest does not rewind the resident's route progress")
	_check(actor.get_node("Figure").speed < 0.06,"Offsite rest stops the actual locomotion driver")
	behavior.activity = "work"
	behavior.reason = "daily_work"
	for tick in 24:
		await physics_frame
		population.advance_to(population.seconds+0.1)
	_check(actor.position.distance_to(original) < 0.15,"Work choice returns through the same safe corridor to the workplace")
	_check(actor.get_meta("intent","") == "work" and actor.get_node("Figure").speed < 0.06,"The resident stops before working")
	behavior.activity = "rest"
	behavior.reason = "tired"
	var resting := actor.position
	for tick in 7:
		await physics_frame
		population.advance_to(population.seconds+0.1)
	_check(actor.position.distance_to(resting) < 0.04,"A break actually stops travel instead of only changing a caption")
	_check(actor.get_node("Figure").speed < 0.06,"A resting resident does not walk in place")
	# Human proximity uses the same physical body; a swept step cannot go through
	# a nearby building while attempting to be courteous.
	behavior.activity = "yield"
	behavior.reason = "personal_space"
	population.update_nearby(actor.global_position+Vector3(-.7,.9,0),true)
	var before_yield := actor.position
	for tick in 6:
		await physics_frame
		population.advance_to(population.seconds+0.1)
	_check(actor.position.x > before_yield.x+0.08,"A passerby physically gives the nearby player some room")
	_check(actor.position.distance_to(original) < .8,"Courtesy stays inside a bounded local corridor")
	# Authoritative family/quest locations and hitboxes stay aligned.
	for id: String in ["julia","silvanus","sextus"]:
		var at := Life.actor_position(model.data,id)
		var actual: Vector3 = world.village_life_world.actor_position(id)
		_check(Vector2(actual.x,actual.z).is_equal_approx(at),"Quest and physical position remain identical for "+id)
		_check(world.village_life_world.actors[id].collision_layer == Layout.CITIZEN_LAYER,"Alive quest resident keeps the expected physical body: "+id)
	Behavior.observe(model.data,world.npc_observations())
	_check(model.data.village.behavior.people.marcellus.observed and model.data.village.behavior.people.julia.observed,"The live observer records background and story people")
	_check(model._validate_state(model.data).is_empty(),"World observations do not change domain or resource validity")
	var saved_position: Array = model.data.village.behavior.people.marcellus.position.duplicate()
	var saved_distance := float(model.data.village.behavior.people.marcellus.route_distance)
	population.advance_to(0.0,true)
	_check(actor.position.is_equal_approx(Vector3(float(saved_position[0]),float(saved_position[1]),float(saved_position[2]))),"Reload placement restores the saved physical position")
	_check(is_equal_approx(float(population.behavior_observations().marcellus.route_distance),saved_distance),"Reload placement preserves route progress")
	# Block the next route segment with a real collision shape, then observe
	# travel. No direct position assignment is allowed to tunnel past it.
	behavior.activity = "explore"
	behavior.reason = "curiosity"
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.25,2.4,2.4)
	shape.shape = box
	wall.position = actor.position+Vector3(.9,1.2,0)
	wall.add_child(shape)
	world.add_child(wall)
	await physics_frame
	for tick in 30:
		await physics_frame
		population.advance_to(float(tick+1)*0.1)
	_check(actor.position.x < wall.position.x-.35,"An autonomous goal cannot move its real body through a wall")
	_check(actor.get_meta("yielding",false),"Blocked autonomous movement is recorded rather than teleported")
	population.set_active(false)
	var paused: Array = population.snapshot()
	population.advance_to(15.0)
	_check(population.snapshot() == paused,"Pausing stops autonomous movement and its animation driver")
	_check_raider_binding(world,model.data)
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("NPC behavior world: %d checks passed" % checks)
		quit(0)
	else:
		print("NPC behavior world: %d failures / %d checks" % [failures.size(),checks])
		quit(1)


func _check_raider_binding(world: Node3D, data: Dictionary) -> void:
	# Isolated presentation fixture: no battle commands, rewards or live-save
	# mutation. Exercise the real VillageLifeWorld creation/binding path.
	var original := JSON.stringify(data)
	var fixture := data.duplicate(true)
	fixture.village.raid.active = true
	fixture.village.raid.status = "active"
	fixture.village.raid.enemies = [{"id":"binding_raider","x":-5.0,"z":-62.0,
		"health":45,"max_health":45,"attack_timer":0.9,"loot_timer":0.0}]
	world.village_life_world.sync_state(fixture,"balanced")
	var raiders: Dictionary = world.village_life_world.raiders
	_check(raiders.has("binding_raider"),"Production village raid creates the observed attacker body")
	if not raiders.has("binding_raider"):
		return
	var raider: Node3D = raiders.binding_raider
	var figure: Node3D = raider.get_node("Figure")
	_check(raider.visible and raider.get_node("Body").collision_layer == 1,"Live attacker keeps its existing domain collision binding")
	_check(figure.meshy_asset_id == "unit_germanic_axe_fighter" and figure.active_model_path.begins_with("res://assets/meshy/characters/unit_germanic_axe_fighter_"),"VillageLifeWorld selects the actual imported Meshy axe fighter")
	figure.set_process(false)
	figure._process(.13)
	var rigs: Array[Node] = figure.body.find_children("*","Skeleton3D",true,false)
	var meshes: Array[Node] = figure.body.find_children("*","MeshInstance3D",true,false)
	var skinned_bodies := 0
	for mesh: MeshInstance3D in meshes:
		if mesh.skin != null:
			skinned_bodies += 1
	_check(rigs.size() == 1 and skinned_bodies == 1 and rigs[0].get_bone_count() == 15,"Bound raider carries exactly one imported skinned body and one 15-joint rig")
	_check(figure.animator != null and figure.animator.has_animation("march") and figure.animator.has_animation("attack") and figure.clip == "march","Raid movement reaches the actual imported locomotion clip")
	if rigs.size() == 1:
		var rig := rigs[0] as Skeleton3D
		var foot := rig.find_bone("Foot_R")
		if foot >= 0:
			rig.force_update_all_bone_transforms()
			var before := rig.get_bone_global_pose(foot).origin
			figure._process(.13)
			rig.force_update_all_bone_transforms()
			_check(before.distance_to(rig.get_bone_global_pose(foot).origin) > .001,"Production raid driver animates the bound foot")
		else:
			_check(false,"Bound raid rig exposes its animated foot")
	_check(JSON.stringify(data) == original,"Rendering a raid fixture cannot grant rewards or mutate the live domain")
