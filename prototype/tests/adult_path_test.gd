extends SceneTree
## Replay the recorded family, then take each voluntary adult route.
const Main = preload("res://scripts/main.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Party = preload("res://scripts/domain/travel_party.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Battle = preload("res://scripts/battle/battle_model.gd")
const Clock = preload("res://scripts/domain/world_clock.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const FIXTURE := "res://tests/fixtures/mission_bridge_data/handoff_i10_choice_v5.json"
var checks := 0
var failures := 0
var consent_state: Dictionary = {}
var path := OS.get_temp_dir().path_join("legio-adult-%d.json" % Time.get_ticks_usec())

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
	return ok

func act(model, command: String, args: Dictionary, expected := true) -> bool:
	var before := "" if expected else JSON.stringify(model.data)
	var result: Dictionary = model.execute(command, args)
	if not expected:
		check(before == JSON.stringify(model.data), command + " rejected atomically")
	return check(result.ok == expected, command + " " + str(args) + " → " + str(result.message))

func _run() -> void:
	var model := Model.new()
	var copied := DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE), path)
	if check(copied == OK and model.load_game(path).ok, "Load the recorded I-10 campaign"):
		_exercise(model)
		if not consent_state.is_empty() and OS.get_environment("IMPERATHEN_ISOLATED_TEST") == "1":
			await _press_folio_choices()
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("ADULT_PATH_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

func _exercise(model) -> void:
	var uid := Party.FATHER
	for action in ["i10_hide", "i11_forge", "i12_father", "i13_morning", "i14_oath"]:
		check(model.party_view().adult_paths.is_empty(), "Folio offers no early adult route at " + action)
		act(model,"choose_adult_path",{"path":"training"},false)
		act(model,"train",{},false)
		var view := Childhood.view(model.data)
		var npc := str(view.target_npc)
		if not npc.is_empty() and not Life.relationship(model.data,npc).get("met",false):
			_go(model,Life.actor_position(model.data,npc))
			act(model,"village_talk",{"npc_id":npc,"choice":"meet"})
		_go(model,view.point)
		if not act(model,"village_childhood_action",{"action_id":action}):
			return
		if action == "i10_hide":
			_go(model,Party.position(model.data,uid))
			if not act(model,"party_invite",{"actor_uid":uid}):
				return
			act(model,"party_order",{"actor_uid":uid,"order":"home"})
	check(model.data.player.age == 12 and model.party_view().adult_paths == ["civil","training"],
		"Speaking the oath only unlocks the choice")
	var before: Dictionary = model.data.duplicate(true)
	consent_state = before.duplicate(true)
	var skipped := before.duplicate(true)
	var skipped_days := Calendar.add_calendar_years(Clock.jdn(before),6) - Clock.jdn(before)
	Clock.book(skipped,"wait",skipped_days * Clock.DAY,"Test")
	check(not model._validate_state(skipped).is_empty(), "Ordinary waiting cannot silently take the place of a life decision")
	act(model,"choose_adult_path",{"path":"imperator"},false)
	act(model,"recruit",{},false)
	var first: Dictionary = model.execute("choose_adult_path",{"path":"civil"},"consent-civil")
	if not check(first.ok,"Civilian handoff: " + first.message):
		return
	var date := Clock.jdn(model.data)
	check(date == Calendar.add_calendar_years(Clock.jdn(before),6), "Six full calendar years, including leap days")
	check(model.data.player.role == "civilian" and model.data.progress.stage == "civil" and model.data.player.age == 18,
		"Independent adult civilian, no training or military authority")
	check(model.data.world_state.time.counts.jump == 1 and model.data.resources == before.resources, "One booked jump, no free gear or pay")
	check(model.data.companion.choice == before.companion.choice and model.data.village.childhood == before.village.childhood,
		"The departed family and Marcus’s decision remain part of the campaign")
	check(model.data.world_state.party.members[uid] == before.world_state.party.members[uid],
		"The deceased Silvanus retains his individual record across the jump")
	var revision: int = model.data.revision
	check(model.execute("choose_adult_path",{"path":"civil"},"consent-civil") == first and model.data.revision == revision,
		"Repeating the original request cannot book time twice")
	check(model.party_view().adult_paths == ["training"] and Battle.campaign_authority(model.data).is_empty(),
		"A civilian may later volunteer; no authority is granted")
	act(model,"recruit",{},false)
	act(model,"choose_adult_path",{"path":"civil"},false)
	if not check(model.save_game(path).ok, "Civil campaign save"):
		return
	var enlisted := Model.new()
	if not check(enlisted.load_game(path).ok and enlisted.data.player.role == "civilian", "Civil career survives load"):
		return
	if not act(enlisted,"choose_adult_path",{"path":"training"}):
		return
	var direct := Model.new()
	direct.data = before
	if not act(direct,"choose_adult_path",{"path":"training"}):
		return
	check(Clock.jdn(direct.data) == date and Clock.jdn(enlisted.data) == date and enlisted.data.world_state.time.counts.jump == 1,
		"Both routes reach the same day; later enrolment books no second jump")
	check(direct.data.resources == enlisted.data.resources and direct.data.village.childhood == enlisted.data.village.childhood,
		"Both routes keep the same possessions, objective and authored consequences")
	check(enlisted.data.player.role == "trainee" and enlisted.party_view().adult_paths.is_empty(), "Voluntary trainee with no patrol yet")
	act(enlisted,"recruit",{},false)
	act(enlisted,"train",{},false)
	act(enlisted,"training_hit",{},false)
	# The adult uses the measured youth jab track at body scale 1.14.
	# The old 1.3 m fixture is outside the actual swept capsule. Keep it
	# as a negative control instead of broadening the production hit reach.
	enlisted.set_player_position(Vector3(0,1,-5.7))
	enlisted.combat_sight_check = func(_from: Vector2, _to: Vector2): return true
	var practice_before := int(enlisted.data.village.unarmed.practice_hits)
	if not act(enlisted,"village_unarmed_attack",{"technique":"jab_left","target_id":"practice","facing_x":0.0,"facing_z":-1.0}):
		return
	enlisted.advance(1.0)
	check(int(enlisted.data.progress.training_hits) == 0 and int(enlisted.data.village.unarmed.practice_hits) == practice_before,
		"Out-of-reach adult jab grants neither training nor practice")
	# At 0.6 m the scaled measured jab first contacts on clip frame 8
	# (60 Hz); the nominal peak frame 13 is not the first contact.
	enlisted.set_player_position(Vector3(0,1,-6.4))
	for hit in 3:
		if not act(enlisted,"village_unarmed_attack",{"technique":"jab_left","target_id":"practice","facing_x":0.0,"facing_z":-1.0}):
			return
		enlisted.advance(0.05)
		check(int(enlisted.data.progress.training_hits) == hit, "Windup grants no training hit")
		enlisted.advance(0.05)
		check(int(enlisted.data.progress.training_hits) == hit, "Active window before physical contact grants no hit")
		enlisted.advance(0.05)
		check(int(enlisted.data.progress.training_hits) == hit + 1, "Training contact once after the measured crossing")
		enlisted.advance(0.85)
		check(int(enlisted.data.progress.training_hits) == hit + 1, "Remaining active and recovery frames cannot repeat training credit")
	check(enlisted.data.player.role == "soldier" and enlisted.data.progress.training_complete, "Three actual hits finish the training")
	if not act(enlisted,"recruit",{}):
		return
	check(enlisted.data.squad.alive == 1 and enlisted.data.world_state.party.members.has(uid),
		"Recruitment coexists with earlier personal company")
	check(enlisted.save_game(path).ok, "Military campaign save")
	var restored := Model.new()
	check(restored.load_game(path).ok and restored.data.player.role == "soldier" and restored.data.progress.training_hits == 3,
		"Same adult, patrol and trained profession after reload")

	if not act(enlisted,"start_skirmish",{}):
		return
	for enemy: Dictionary in enlisted.data.encounter.enemies.duplicate(true):
		# The same measured adult jab cannot reach a raider at 1 m.
		# A 0.7 m separation permits real capsule contact.
		enlisted.set_player_position(Vector3(enemy.x,1,float(enemy.z) + 1.0))
		if not act(enlisted,"village_unarmed_attack",{"technique":"jab_left","target_id":enemy.id,"facing_x":0.0,"facing_z":-1.0}):
			return
		enlisted.advance(1.0)
		var missed: Dictionary = enlisted.data.encounter.enemies.filter(func(row): return row.id == enemy.id)[0]
		check(int(missed.health) == int(enemy.health), "Out-of-reach strike cannot injure the patrol opponent")
		enlisted.set_player_position(Vector3(enemy.x,1,float(enemy.z) + 0.7))
		for strike in 10:
			var actual: Dictionary = enlisted.data.encounter.enemies.filter(func(row): return row.id == enemy.id)[0]
			if actual.health <= 0:
				break
			var before_health := int(actual.health)
			if not act(enlisted,"village_unarmed_attack",{"technique":"jab_left","target_id":enemy.id,"facing_x":0.0,"facing_z":-1.0}):
				return
			enlisted.advance(0.05)
			var early: Dictionary = enlisted.data.encounter.enemies.filter(func(row): return row.id == enemy.id)[0]
			check(int(early.health) == before_health, "Patrol windup cannot injure the opponent")
			enlisted.advance(0.15)
			var contacted: Dictionary = enlisted.data.encounter.enemies.filter(func(row): return row.id == enemy.id)[0]
			var after_contact := int(contacted.health)
			if not check(after_contact < before_health, "Patrol health changes only on genuine swept contact"):
				return
			enlisted.advance(2.0)
			var recovered: Dictionary = enlisted.data.encounter.enemies.filter(func(row): return row.id == enemy.id)[0]
			check(int(recovered.health) == after_contact, "One strike cannot damage an opponent twice")
	if not check(enlisted.data.progress.skirmish_won,"Real contacts finish the adult patrol encounter"):
		return
	if not act(enlisted,"choose_story",{"choice":"protect"}):
		return
	var battle := Battle.new()
	check(battle.set_commander(Battle.campaign_authority(enlisted.data)), "Earned pass watch delegates one squad")
	check(battle.order(["valley_spears"],"hold").ok and not battle.order(["valley_guard"],"hold").ok,
		"Actual delegated orders respect the available squads")
	battle.tick(1.0)
	check(enlisted.checkpoint_valley(battle) and enlisted.save_game(path).ok,"Campaign valley time agrees with the persistent village on saving")
	check(enlisted.act_region("advance",str(enlisted.data.strategy.home)).ok and enlisted.save_game(path).ok,
		"An ensuing regional season keeps the same campaign saveable")
	var campaign := Model.new()
	check(campaign.load_game(path).ok and campaign.data.progress.skirmish_won and campaign.data.strategy.turn == 1,
		"The same childhood campaign reloads after army orders and a strategic turn")

func _go(model, point: Vector2) -> void:
	model.set_player_position(Vector3(point.x,1,point.y))


func _press_folio_choices() -> void:
	var game := Main.new()
	root.add_child(game)
	await process_frame
	game.model.data = consent_state
	game.session_started = true
	game.world.show()
	game.world.setup(game.model.data)
	game._resume()
	for label in ["Gefolge", "Gefährten ansehen", "Sechs Jahre später · Zivilleben"]:
		if not _press(game,label):
			game.queue_free()
			return
	check(game.model.data.progress.stage == "civil" and game.screen == "party_folio", "Folio button completed the civilian transition")
	var saved := Model.new()
	check(saved.load_game(Main.SAVE_PATH).ok and saved.data.player.role == "civilian", "Main saved the civilian path to the live campaign slot")
	if _press(game,"Die Wachausbildung aufnehmen"):
		check(game.model.data.progress.stage == "training" and game.model.data.world_state.time.counts.jump == 1,
			"Main accepts the later training request exactly once")
		check(saved.load_game(Main.SAVE_PATH).ok and saved.data.player.role == "trainee", "Main saved the later career change")
	game.queue_free()
	await process_frame

func _press(game, caption: String) -> bool:
	for button: Button in game.ui._screen.find_children("*", "Button", true, false):
		if button.text == caption and button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			return check(true, caption)
	return check(false, "Missing visible control: " + caption)
