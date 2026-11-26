extends "res://tests/companion_follow_test.gd"
## Reuse the regular I-01/I-03 playthrough. Player positions at conversations
## and pickups are fixture placement; companion displacement is engine physics.
## LEGIO_CAPTURE_DIR optionally saves a real viewport on a display-capable run.

const Party = preload("res://scripts/domain/travel_party.gd")
const DT := 1.0 / 60.0
var party_world: Node3D
var journey := {}


func _run() -> void:
	if not OS.get_environment("LEGIO_CAPTURE_DIR").is_empty():
		RenderingServer.render_loop_enabled = false
	var model := Model.new()
	model.new_game("italia", true, true, false, true)
	if _reach(model, "collect_kindling"):
		# Reproducible daylight for the reviewer. These six hours of prior
		# market time use the ordinary calendar operation of a campaign visit.
		if not OS.get_environment("LEGIO_CAPTURE_DIR").is_empty():
			_check(model.advance_city_visit(6 * 3600).ok, "Book the daylight fixture on the authoritative clock")
		await _wood_run(model)
	if failures.is_empty():
		await _regional_friend()
	if is_instance_valid(party_world):
		party_world.queue_free()
		await process_frame
	print("PARTY_WORLD_METRICS " + JSON.stringify(journey))
	print("PARTY_WORLD_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func _wood_run(model: Model) -> void:
	party_world = World.new()
	root.add_child(party_world)
	party_world.setup(model.data)
	party_world.set_active(true)
	party_world.set_physics_process(false)
	model.npc_observations = party_world.npc_observations
	model.npc_sight_check = party_world.npc_sight_clear
	await physics_frame
	var walker = party_world._story_companions
	var marcus: CharacterBody3D = walker.actor("marcus")
	var father: CharacterBody3D = walker.actor("silvanus")
	var bodies := {Party.FRIEND:marcus, Party.FATHER:father}
	for uid: String in bodies:
		var body: CharacterBody3D = bodies[uid]
		_place(model, body.global_position + Vector3(1.2, 1.0, 0.0))
		if not _command(model, "party_invite", {"actor_uid":uid}):
			return
		_check(body.get_meta("actor_uid") == uid, "The original body retains its canonical UID " + uid)
	var destination: Vector2 = Childhood.POINTS.wood_bundle
	_place(model, Vector3(destination.x + 0.7, 1.0, destination.y + 0.5))
	if not _command(model, "party_assign", {"actor_uid":Party.FRIEND,"assignment":"guide"}) or not _command(model, "party_order", {"actor_uid":Party.FATHER,"order":"wait"}):
		return
	var initial_marcus := marcus.global_position
	var initial_father := father.global_position
	for frame in 600:
		await physics_frame
		walker.advance(DT)
		if initial_marcus.distance_to(marcus.global_position) > 1.0:
			break
	_check(initial_marcus.distance_to(marcus.global_position) > 0.5, "The guide starts walking to the task")
	_check(initial_father.distance_to(father.global_position) < 0.001, "An individual waiting request holds Silvanus at his actual location")
	if not _command(model, "party_assign", {"actor_uid":Party.FATHER,"assignment":"carry"}):
		return
	var site := Vector3(destination.x, 0, destination.y)
	if not await _arrive(site, bodies, "woodcamp"):
		return
	await _capture_group(site, "i04-holzlager")
	model.capture_npc_observations()
	var blocked := model.data.duplicate(true)
	var blocked_feedback := preload("res://scripts/story/companion_story.gd").credit(blocked,"collect_kindling",destination,"",func(_from,_to): return false)
	_check(blocked_feedback.is_empty() and blocked.world_state.party == model.data.world_state.party,"An occluded mission site awards neither participation nor an eyewitness memory")
	var before: Dictionary = model.data.resources.duplicate()
	if not _command(model, "village_childhood_action", {"action_id":"collect_kindling"}):
		return
	var members: Dictionary = model.data.world_state.party.members
	_check(int(members[Party.FRIEND].skills.get("navigation", 0)) == 1 and int(members[Party.FATHER].skills.get("endurance", 0)) == 1, "Two present helpers gain the skills of their actual assignments")
	_check(before == model.data.resources and model.data.village.childhood.carried.count("kindling_bundle") == 1, "Exactly one mission bundle is picked up without creating ordinary goods")
	_check(not model.execute("village_childhood_action", {"action_id":"collect_kindling"}).ok, "A duplicate pickup gives no experience")
	var path := "user://party_world_%d.json" % Time.get_ticks_usec()
	if not _check(model.save_game(path).ok, "Save both helpers at the woodcamp"):
		return
	var loaded := Model.new()
	if not _check(loaded.load_game(path).ok, "Load the shared mission and both humans"):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	party_world.setup(loaded.data)
	party_world.set_active(true)
	loaded.npc_observations = party_world.npc_observations
	_check(marcus == walker.actor("marcus") and father == walker.actor("silvanus") and _flat_gap(marcus.global_position, site) < 3.5 and _flat_gap(father.global_position, site) < 3.5, "Save/load restores the same existing bodies at their observed locations")
	_check(loaded.data.world_state.party.members == members, "The individual assignments, memories and skill gains round-trip")
	if not _command(loaded, "party_dismiss", {"actor_uid":Party.FATHER}):
		return
	var craft_site: Vector2 = Life.actor_position(loaded.data, "sextus")
	var forge := Vector3(craft_site.x, 0.0, craft_site.y)
	_place(loaded, forge + Vector3(0.7, 1.0, 0.8))
	if not await _arrive(forge, {Party.FRIEND:marcus}, "forge"):
		return
	if not Life.relationship(loaded.data,"sextus").met:
		if not _command(loaded, "village_talk", {"npc_id":"sextus","choice":"meet"}):
			return
	if not _command(loaded, "village_childhood_action", {"action_id":"deliver_kindling"}):
		return
	members = loaded.data.world_state.party.members
	_check(int(members[Party.FRIEND].skills.navigation) == 2 and int(members[Party.FATHER].skills.endurance) == 1, "The task finishes when the carrier leaves; only its remaining guide gains the delivery memory")
	_check(not loaded.data.village.childhood.carried.has("kindling_bundle") and Childhood.current_step(loaded.data).id == "i04_work", "Sextus receives the bundle and opens the existing workshop visit")

	await _family_threshold(loaded, marcus)


func _family_threshold(model: Model, guide: CharacterBody3D) -> void:
	var house: Node3D = party_world.regional.get_node("baker_home")
	var walker = party_world._story_companions
	# Position fixture at the start of the actual household ramp. The rest of
	# the trial uses orders, capsule motion and the unmodified room geometry.
	guide.position = house.to_global(Vector3(0, 0.04, 5.4))
	guide.velocity = Vector3.ZERO
	walker.controllers["marcus"].reset()
	_place(model, house.to_global(Vector3(0.4, 1.4, -0.85)))
	if not _command(model, "party_order", {"actor_uid":Party.FRIEND, "order":"follow"}):
		return
	for tick in 900:
		await physics_frame
		walker.advance(DT)
		if house.to_local(guide.position).z < 3.8:
			break
	if not _check(house.to_local(guide.position).z < 3.8, "Marcus reaches the family's real entry ramp"):
		return
	if not _command(model, "party_order", {"actor_uid":Party.FRIEND, "order":"wait"}):
		return
	for tick in 450:
		await physics_frame
		walker.advance(DT)
		if house.to_local(guide.position).z > 4.35 and absf(house.to_local(guide.position).x) > 1.1:
			break
	_check(house.to_local(guide.position).z > 4.35 and absf(house.to_local(guide.position).x) > 1.1, "Waiting on the ramp physically clears the threshold for other walkers")
	if not _command(model, "party_order", {"actor_uid":Party.FRIEND, "order":"follow"}):
		return
	for tick in 1200:
		await physics_frame
		walker.advance(DT)
		if house.to_local(guide.position).z < 1.25:
			break
	var here := house.to_local(guide.position)
	journey.family_threshold = {"x":here.x, "foot_y":here.y, "z":here.z}
	_check(here.z < 1.25 and absf(here.y - Layout.HOUSE_FLOOR) < 0.09, "A returning guide walks through the real furnished doorway onto the raised family floor: " + str(here))


func _regional_friend() -> void:
	var model := Model.new()
	model.new_game("wa")
	party_world.setup(model.data)
	party_world.set_active(true)
	model.npc_observations = party_world.npc_observations
	_place(model, Vector3(-8.0, 1.0, 2.0))
	if not _command(model, "gather", {"node_id":"timber_0"}):
		return
	_place(model, Vector3(-3.0, 1.0, 4.0))
	if not _command(model,"choose_companion",{"choice":"help"}) or not _command(model, "party_invite", {"actor_uid":Party.FRIEND}):
		return
	var body: CharacterBody3D = party_world._companion
	var start := body.global_position
	_place(model, Vector3(2.0, 1.0, 7.0))
	var walker = party_world._story_companions
	for tick in 1200:
		await physics_frame
		walker.advance(DT)
		if _flat_gap(body.global_position, party_world.get_player_position()) < 1.8:
			break
	_check(body.get_meta("actor_uid") == Party.FRIEND and _flat_gap(start, body.position) > 3.0, "The existing non-Italian friend walks under the same canonical identity")
	if not _command(model, "party_supply", {"actor_uid":Party.FRIEND,"quantity":1}):
		return
	_check(not model.data.village.has("behavior") and model.data.world_state.party.members[Party.FRIEND].has("travel_position"), "A legacy career stores its body observation without a second village simulation")
	var path := "user://regional_friend_%d.json" % Time.get_ticks_usec()
	var saved := body.global_position
	var loaded := Model.new()
	var written := model.save_game(path)
	var restored := loaded.load_game(path) if written.ok else written
	if _check(written.ok and restored.ok, "Load the regional career with its moving friend: " + str(restored.message)):
		party_world.setup(loaded.data)
		_check(body.global_position.distance_to(saved) < 0.002, "The same regional friend is restored to its observed place")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _command(model: Model, command: String, args: Dictionary) -> bool:
	var result: Dictionary = model.execute(command, args)
	if not _check(result.ok, "%s %s: %s" % [command, str(args), str(result.message)]):
		return false
	party_world.sync_state(model.data)
	return true


func _place(model: Model, point: Vector3) -> void:
	party_world.get_node("Player").global_position = point
	model.set_player_position(point)


func _flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()


func _arrive(site: Vector3, bodies: Dictionary, label: String) -> bool:
	var walker = party_world._story_companions
	var previous := {}
	var travelled := {}
	for uid: String in bodies:
		previous[uid] = bodies[uid].global_position
		travelled[uid] = 0.0
	var largest_step := 0.0
	for frame in 4800:
		await physics_frame
		walker.advance(DT)
		var ready := true
		for uid: String in bodies:
			var at: Vector3 = bodies[uid].global_position
			var moved: float = _flat_gap(previous[uid], at)
			travelled[uid] += moved
			largest_step = maxf(largest_step, moved)
			previous[uid] = at
			ready = ready and _flat_gap(at, site) <= 3.0
		if ready:
			journey[label] = {"ticks":frame+1, "walked_metres":travelled, "maximum_step_m":largest_step}
			return _check(largest_step < 0.13, "The party walks to " + label + " without position jumps")
	return _check(false, "Helpers reach %s at %s (actual %s)" % [label, site, previous])


func _capture_group(site: Vector3, filename: String) -> void:
	var folder := OS.get_environment("LEGIO_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var camera := Camera3D.new()
	party_world.add_child(camera)
	camera.global_position = site + Vector3(2.3, 2.5, 5.0)
	camera.look_at(site + Vector3(0, 1.05, 0))
	camera.make_current()
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	_check(frame.save_png(folder.path_join(filename + ".png")) == OK, "Write the actual I-04 viewport")
	RenderingServer.render_loop_enabled = false
	camera.queue_free()
