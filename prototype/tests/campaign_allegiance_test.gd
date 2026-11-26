extends SceneTree

const Model = preload("res://scripts/domain/world_model.gd")
const Party = preload("res://scripts/domain/travel_party.gd")
const Allegiance = preload("res://scripts/domain/campaign_allegiance.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Tribes = preload("res://scripts/domain/tribal_world.gd")
const FIXTURE := "res://tests/fixtures/mission_bridge_data/handoff_i10_choice_v5.json"

var checks := 0
var failures := 0
var model := Model.new()
var path := OS.get_temp_dir().path_join("legio-allegiance-%d.json" % Time.get_ticks_usec())

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",description)
	return ok

func act(command: String, args: Dictionary, expected := true) -> bool:
	var before := "" if expected else JSON.stringify(model.data)
	var result := model.execute(command,args)
	if not expected:
		check(before == JSON.stringify(model.data),command+" leaves the state intact")
	return check(result.ok == expected,command + " " + str(args) + " → " + str(result.message))

func meet(id: String) -> void:
	var point := Life.actor_position(model.data,id)
	model.set_player_position(Vector3(point.x,1,point.y))
	if not Life.relationship(model.data,id).get("met",false):
		act("village_talk",{"npc_id":id,"choice":"meet"})

func _run() -> void:
	var copy := DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE),path)
	if check(copy == OK and model.load_game(path).ok,"Load the original recorded childhood save"):
		_campaign()
	for suffix in ["",".bak"]:
		DirAccess.remove_absolute(path+suffix)
	print("CAMPAIGN_ALLEGIANCE_RESULT checks=%d failures=%d" % [checks,failures])
	if not failures:
		print("CAMPAIGN_ALLEGIANCE_PASS")
	quit(1 if failures else 0)

func _campaign() -> void:
	act("party_declare",{"target":"free"},false)
	var point: Vector2 = Childhood.view(model.data).point
	model.set_player_position(Vector3(point.x,1,point.y))
	if not act("village_childhood_action",{"action_id":"i10_hide"}):
		return
	act("party_declare",{"target":"civil"},false)
	for stage in ["i11_forge","i12_father","i13_morning","i14_oath"]:
		var view := Childhood.view(model.data)
		if not check(str(view.get("stage","")) == stage,"Reach "+stage):
			return
		if not str(view.get("target_npc","")).is_empty():
			meet(view.target_npc)
		point = view.point
		model.set_player_position(Vector3(point.x,1,point.y))
		if not act("village_childhood_action",{"action_id":stage}):
			return
	var aged := model.execute("choose_adult_path",{"path":"civil"})
	if not check(aged.ok and model.data.player.age >= 18,"Six years elapse on the campaign calendar: "+str(aged.message)):
		return
	meet("cassia")
	var target := ""
	for gid: String in model.data.tribes.groups:
		if Allegiance._delegation(model.data,gid) and Tribes._rel(model.data.tribes,gid,"player","trust") < 5:
			target = gid
			break
	if not check(not target.is_empty(),"A historically registered community accepts delegations"):
		return
	act("party_declare",{"target":target},false)
	var grain := int(model.data.resources.grain)
	var trust := Tribes._rel(model.data.tribes,target,"player","trust")
	act("party_envoy",{"target":target})
	check(int(model.data.resources.grain) == grain-2 and Tribes._rel(model.data.tribes,target,"player","trust") == trust+6,"Tracked delivery reaches the recipient and changes trust")
	act("party_envoy",{"target":target},false)
	act("party_declare",{"target":target})
	check(Allegiance.affiliation(model.data) == target and not Allegiance.roman_command(model.data),"Tribal allegiance closes Roman command")
	act("party_declare",{"target":"free"},false)
	act("recruit",{},false)
	act("city_issue_service",{"shop_id":"armorer"},false)
	meet("aurelia")
	act("party_hire",{"actor_uid":"vil:aurelia"})
	model.set_player_position(Vector3(-8,1,2))
	act("gather",{"node_id":"timber_0"})
	meet("aelia")
	act("village_talk",{"npc_id":"aelia","choice":"help"})
	act("party_invite",{"actor_uid":"vil:aelia"})
	act("party_declare",{"target":"free"})
	check(Allegiance.affiliation(model.data) == "free" and model.data.world_state.party.members["vil:aelia"].order != "home","A known village friend publicly supports an independent party")
	check(model.data.world_state.party.members["vil:aurelia"].order == "home" and model.data.world_state.party.members["vil:aurelia"].status == "active","A neutral paid healer keeps her own identity and belongings")
	meet("decimus")
	act("party_declare",{"target":"civil"})
	check(Allegiance.affiliation(model.data) == "civil","An adult may choose civilian life")
	act("party_declare",{"target":"rome"})
	check(not Allegiance.roman_command(model.data),"Returning one's loyalty does not reinstate military authority")
	act("party_declare",{"target":"service"},false)
	check(model.save_game(path).ok,"Political choices save through the campaign")
	var restored := Model.new()
	check(restored.load_game(path).ok and restored.data.world_state.allegiance == model.data.world_state.allegiance,"Recorded allegiance and diplomacy survive reload")
