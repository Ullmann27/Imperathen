extends "res://tests/party_world_test.gd"
## The recorded pre-raid mission has three future casualties known by name.
## Exercise their actual campaign deaths while enrolled, with a surviving scout.

const MainSession = preload("res://scripts/main.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const FIXTURE := "res://tests/fixtures/mission_bridge_data/handoff_i08_report_v5.json"
const SCOUT := "vil:varro"


func _run() -> void:
	var path := "user://aftermath_%d.json" % Time.get_ticks_usec()
	var copied := DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE), ProjectSettings.globalize_path(path))
	var model := Model.new()
	if _check(copied == OK and model.load_game(path).ok, "Open the authentic pre-raid career"):
		party_world = World.new()
		root.add_child(party_world)
		party_world.setup(model.data)
		party_world.set_active(true)
		party_world.set_physics_process(false)
		model.npc_observations = party_world.npc_observations
		await physics_frame
		await _aftermath(model, path)
		party_world.queue_free()
		await process_frame
	for suffix in ["", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("PARTY_AFTERMATH_METRICS " + JSON.stringify(journey))
	print("PARTY_AFTERMATH_RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _aftermath(model: Model, path: String) -> void:
	var walker = party_world._story_companions
	for id: String in ["silvanus", "julia", "sextus"]:
		var body: CharacterBody3D = party_world.village_life_world.actors[id]
		_place(model, body.position + Vector3(0.95, 1, 0))
		if not _command(model, "party_invite", {"actor_uid":"vil:" + id}) or not _command(model,"party_supply",{"actor_uid":"vil:" + id,"quantity":1}):
			return
	var scout: CharacterBody3D = party_world.village_life_world.actors.varro
	_place(model, scout.position + Vector3(1.0, 1, 0.4))
	if not _command(model,"village_talk",{"npc_id":"varro","choice":"meet"}):
		return
	var father: CharacterBody3D = walker.actor("silvanus")
	if not await _arrive(scout.position, {Party.FATHER:father}, "supervision"):
		return
	if not _command(model,"party_hire",{"actor_uid":SCOUT}) or not _command(model,"party_assign",{"actor_uid":SCOUT,"assignment":"watch"}):
		return
	if not _command(model,"party_supply",{"actor_uid":SCOUT,"quantity":2}):
		return
	if not _reach(model, "i10_choice"):
		return
	party_world.sync_state(model.data)
	var session := MainSession.new()
	session.model = model
	_check(not session._can_visit_market(), "A market visit is unavailable during the protected decision")
	session.free()
	_check(not model.execute("party_order", {"actor_uid":"all","order":"follow"}).ok, "Optional requests cannot override I-10")
	_place(model, father.position + Vector3(0.6,1.0,0))
	_check(not model.execute("village_childhood_action",{"action_id":"i10_hide"}).ok, "A travelling father cannot move the protected night to the scout's station")
	var door := Vector3(Childhood.POINTS.father.x,0,Childhood.POINTS.father.y)
	_place(model,door + Vector3(0.6,1,0))
	if not await _arrive(door,{Party.FATHER:father},"night_home"):
		return
	if not _stage(model,"i10_hide") or not _stage(model,"i11_forge") or not _stage(model,"i12_father"):
		return
	for id: String in ["silvanus", "julia", "sextus"]:
		var uid := "vil:" + id
		var person := Party.resident(model.data, uid)
		var entry: Dictionary = model.data.world_state.party.members[uid]
		var body: CharacterBody3D = walker.actor(id)
		_check(not person.alive and person.health == 0 and entry.status == "dismissed" and entry.memories.has("Im Dorf verstorben."), "The authored loss retires the same party member: " + id)
		_check(not body.visible and body.collision_layer == 0 and party_world.get_cinematic_figure(id) == null, "Dead resident vanishes from the world, collisions and scene director: " + id)
		_check(not walker.departing_for_market(model.data,body.position).has(body) and not model.execute("party_invite",{"actor_uid":uid}).ok, "The dead cannot depart or return under the same name: " + id)
	var site: Vector2 = Childhood.view(model.data).point
	var position3 := Vector3(site.x, 0.0, site.y)
	_place(model, position3 + Vector3(0.95, 1, 0.3))
	if not await _arrive(position3, {SCOUT:scout}, "healer"):
		return
	if not _stage(model,"i13_morning"):
		return
	var survivor: Dictionary = model.data.world_state.party.members[SCOUT]
	_check(survivor.skills.get("perception",0) == 1 and survivor.memories.any(func(note: String) -> bool: return note.begins_with("i13_morning")), "The living scout's observation at Aurelia's survives the raid")
	if not _check(model.save_game(path).ok, "Persist the living and fallen after the joint morning"):
		return
	var loaded := Model.new()
	if not _check(loaded.load_game(path).ok, "Reload the actual post-raid party"):
		return
	party_world.setup(loaded.data)
	for id: String in ["silvanus", "julia", "sextus"]:
		_check(not walker.actor(id).visible and not Party.resident(loaded.data,"vil:" + id).alive, "Reload preserves the loss: " + id)
	_wound_recovery(loaded)


func _stage(model: Model, action: String) -> bool:
	model.capture_npc_observations()
	var view := Childhood.view(model.data)
	var at: Vector2 = view.point
	_place(model, Vector3(at.x,1.0,at.y))
	return _command(model, "village_childhood_action", {"action_id":action})


func _wound_recovery(model: Model) -> void:
	# Start with a controlled injury to the real scout's single health value.
	# Use the production meal accounting for both the travelling and home days.
	var record := Party.resident(model.data,SCOUT)
	record.health = 31
	var member: Dictionary = model.data.world_state.party.members[SCOUT]
	var ration_count := int(member.rations)
	if ration_count:
		Party.settle_days(model.data,1)
		_check(record.health == 32 and member.rations == ration_count-1, "A consumed personal ration helps the same wounded person recover on the road")
	Party.settle_days(model.data,2)
	_check(record.health <= 30 and member.order == "home" and not Party.healthy(model.data,SCOUT), "Missing meals weaken the scout and interrupt his assignment")
	var before := int(record.health)
	Economy._meal(model.data)
	_check(record.alive and record.health > before and Party.healthy(model.data,SCOUT), "The existing village meal and rest heal the same scout after returning")
