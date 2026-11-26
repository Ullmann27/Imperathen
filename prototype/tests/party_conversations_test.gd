extends "res://tests/companion_follow_test.gd"
## Mission transactions use normal I-01..04 progression; positions at the
## conversation and work sites are deterministic fixture observations.
const Party = preload("res://scripts/domain/travel_party.gd")
const Talk = preload("res://scripts/domain/party_conversations.gd")
const M := Party.FRIEND
const F := Party.FATHER
const V := "vil:varro"
var model := Model.new()
var samples := {}
var save_path := OS.get_temp_dir().path_join("party-conversation-%d.json" % Time.get_ticks_usec())

func place(point: Vector2, people: Array) -> void:
	model.set_player_position(Vector3(point.x,1,point.y))
	samples.clear()
	for uid: String in people:
		samples[Party.local_id(model.data,uid)] = {"position":[point.x,0,point.y]}

func act(cmd: String,args: Dictionary,expect := true) -> bool:
	var before := model.data.duplicate(true) if not expect else {}
	var result := model.execute(cmd,args)
	if not expect:
		_check(model.data == before,"Rejected decision is atomic")
	return _check(result.ok == expect,"%s %s: %s" % [cmd,args,result.message])

func _run() -> void:
	model.new_game("italia",true,true)
	if _reach(model,"collect_kindling"):
		await _test_shared()
	for ext in ["",".bak"]:
		DirAccess.remove_absolute(save_path+ext)
	print("PARTY_CONVERSATIONS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _test_shared() -> void:
	model.npc_observations = func(): return samples
	for uid: String in [M,F,V]:
		var point := Party.position(model.data,uid)
		place(point,[uid,F])
		if uid == V:
			if not act("village_talk",{"npc_id":"varro","choice":"meet"}): return
		var cmd := "party_hire" if uid == V else "party_invite"
		if not act(cmd,{"actor_uid":uid}): return
		if not act("party_assign",{"actor_uid":uid,"assignment":"carry" if uid == F else "guide"}): return
	var wood: Vector2 = Childhood.view(model.data).point
	place(wood,[M,F,V])
	if not act("village_childhood_action",{"action_id":"collect_kindling"}): return
	var party: Dictionary = model.data.world_state.party
	if not _check(party.get("outings",[]).size() == 1,"A successful real pickup records one outing"): return
	var outing: Dictionary = party.outings[0]
	_check(outing.roles == {M:"guide",F:"carry",V:"guide"} and outing.jdn == model.data.calendar.clock.jdn,"Actual roles, three different IDs and date of observation")
	var offers := {}
	for person: Dictionary in model.party_view().members:
		offers[person.actor_uid] = person.conversation.offer
	_check(offers[F].role == "carry" and offers[M].role == "guide" and offers[V].line.contains("beide"),"Goals and competition yield personally worded proposals")
	var forged: Array = party.outings.duplicate(true)
	forged[0].step = "deliver_kindling"
	_check(not Talk.validate(model.data,forged,Story.task_roles).is_empty(),"A memory of an uncompleted future task is rejected")
	var repeated: Array = party.outings.duplicate(true)
	repeated.append(outing.duplicate(true))
	_check(not Talk.validate(model.data,repeated,Story.task_roles).is_empty(),"A restored record cannot count the same witnessed task twice")
	place(wood+Vector2(15,2),[])
	act("party_exchange",{"actor_uid":M,"step":"collect_kindling","choice":"accept"},false)
	place(wood,[M,F,V])
	if not act("party_assign",{"actor_uid":M,"assignment":"watch"}): return
	if not act("party_exchange",{"actor_uid":M,"step":"collect_kindling","choice":"accept"}): return
	_check(model.data.world_state.party.members[M].assignment == "guide","An accepted proposal changes the actual assignment used by movement")
	act("party_exchange",{"actor_uid":M,"step":"collect_kindling","choice":"accept"},false)
	act("party_exchange",{"actor_uid":F,"step":"collect_kindling","choice":"decline"})
	_check(model.data.world_state.party.members[F].assignment == "carry","Declining preserves the existing personal task")
	if not _check(model.save_game(save_path).ok,"Save dialog answers with mission and inventories"): return
	var restored := Model.new()
	if not _check(restored.load_game(save_path).ok,"Reload the regular save"): return
	_check(restored.data.world_state.party.outings == model.data.world_state.party.outings,"The same dated participants and answers survive loading")
	var original := model
	model = restored
	model.npc_observations = func(): return samples
	if not _deliver([M,F,V]): return
	act("party_exchange",{"actor_uid":V,"step":"collect_kindling","choice":"accept"},false)
	var graph := Talk.opinions(model.data,M)
	_check(Talk.stance(model.data,M,F,graph) == "friendly","Cooperating as guide and carrier twice builds friendship")
	_check(Talk.stance(model.data,M,V,graph) == "wary","A pair that repeatedly insists on guiding forms a rivalry")
	act("party_delegate",{"actor_uid":M,"leader_uid":V},false)
	act("party_delegate",{"actor_uid":M,"leader_uid":F})
	if not _check(model.save_game(save_path).ok,"Save rivalry and friendship"): return
	if not _check(restored.load_game(save_path).ok,"Reload rivalry and friendship"): return
	await _answer_in_folio()
	var view := Talk.row(restored.data,M)
	_check(view.contacts.size() == 2 and str(view.contacts).contains("Freundschaft") and str(view.contacts).contains("Rivalität"),"The folio resolves continuing opinions by canonical IDs")
	# Alternate continuation from the first outing. The missing body of a
	# deceased resident must never receive credit even if observed at the site.
	model = original
	act("party_dismiss",{"actor_uid":F})
	var casualty := Party.resident(model.data,V)
	casualty.alive = false
	casualty.health = 0
	if not _deliver([M,F,V]): return
	party = model.data.world_state.party
	_check(party.outings[1].roles == {M:"guide"} and party.members[V].status == "dismissed","Departed and deceased actors receive no fresh memory")
	act("party_exchange",{"actor_uid":V,"step":"collect_kindling","choice":"accept"},false)
	act("party_hire",{"actor_uid":V},false)
	_check(Talk.row(model.data,V).entries.size() == 1,"The dead person's earlier dated memory survives")
	_check(model.save_game(save_path).ok,"Dismissals, death and the different audience persist")
	if not _check(restored.load_game(save_path).ok,"Reload alternate outcome"): return
	_check(not Party.resident(restored.data,V).alive and restored.data.world_state.party.outings == party.outings,"Reload never revives a departed witness")
	await process_frame

func _deliver(people: Array) -> bool:
	var forge: Vector2 = Childhood.view(model.data).point
	place(forge,people)
	if not Life.relationship(model.data,"sextus").met and not act("village_talk",{"npc_id":"sextus","choice":"meet"}):
		return false
	return act("village_childhood_action",{"action_id":"deliver_kindling"})

func _answer_in_folio() -> void:
	root.size = Vector2i(960,640)
	root.content_scale_size = Vector2i.ZERO
	var ui := UI.new()
	root.add_child(ui)
	ui.party_target = M
	ui.show_party("party_folio",model.party_view(),{},"")
	await process_frame
	var yes := ui._screen.find_child("Einverstanden",true,false) as Button
	if not _check(is_instance_valid(yes),"The normal personal folio displays the task proposal"):
		ui.free()
		return
	var scroll := ui._screen.find_children("*","ScrollContainer",true,false)[0] as ScrollContainer
	scroll.ensure_control_visible(yes)
	var output := OS.get_environment("LEGIO_SOCIAL_FRAME")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		for frame in 25:
			await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_webp(output,true,.92)==OK,"Actual exchange viewport exported")
	ui.action_requested.connect(func(action: String,payload: Dictionary):
		if action == "party_command":
			_check(model.execute(payload.command,payload.args).ok,"The folio command reaches the validated model"))
	yes.pressed.emit()
	_check(model.data.world_state.party.outings[-1].answers.get(M)=="accept","The normal answer button settles the correct witnessed outing")
	ui.free()
