extends SceneTree
## I-04 „Der Freund meines Vaters“ – workshop visit, domain contract through
## the real WorldModel (fixture placement at authored points).
## Handbook mapping (HB S. 15 and S. 71): andere Route (message to Fabius),
## Ablehnung (watch first), Prop- und Erinnerungsbestand, keine doppelte
## Belohnung für geliefertes Holz, keine Waffe für das Kind, NPC nicht
## verfügbar, Save/Load vor und nach der Entscheidung, v5 -> v6 migration.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I04 = preload("res://scripts/story/i04_workshop.gd")
const I04Film = preload("res://scripts/story/i04_film.gd")
const Cinematics = preload("res://scripts/story/mission_cinematics.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")
const Support = preload("res://tests/i03_support.gd")
var checks := 0
var failures: Array[String] = []
var directory := "user://i04_slice_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_test_data_contract()
	_test_stack_path()
	_test_message_route()
	_test_watch_refusal()
	_test_sextus_absent()
	_test_films()
	_test_save_load()
	_test_migration_v5_to_v6()
	print("I04_SLICE_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("I04_SLICE_PASS" if failures.is_empty() else "I04_SLICE_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition


func _act(model, id: String) -> Dictionary:
	return model.execute("village_childhood_action", {"action_id":id})


func _stage(model) -> String:
	return str(Childhood.view(model.data).get("stage", ""))


func _sp(model) -> Dictionary:
	return model.data.village.childhood.screenplay


func _norm(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))


## Plays the current stage with its first authored option at its real place.
func _play(model, action := "") -> Dictionary:
	var view: Dictionary = Childhood.view(model.data)
	var stage := str(view.get("stage", ""))
	if stage.begins_with("i03_"):
		return Support.play_stage(model)
	var point: Vector2 = view.point
	model.set_player_position(Vector3(point.x, 1.35, point.y))
	var npc := str(view.get("target_npc", ""))
	if not npc.is_empty() and not bool(Childhood.relationship(model.data, npc).get("met", false)):
		model.execute("village_talk", {"npc_id":npc, "choice":"meet"})
	view = Childhood.view(model.data)
	if action.is_empty():
		action = "basket_check" if stage == "i02_basket" else str(view.actions[0].payload.action_id)
	return _act(model, action)


## A regular new life played up to the open workshop visit.
func _at_forge(goal := "i04_work"):
	var model = WorldModel.new()
	model.new_game("italia", true, true, false, true)
	for _index in 80:
		if _stage(model) == goal:
			return model
		if not _check(_play(model).ok, "Reach the forge: " + _stage(model)):
			return model
	_check(false, "The workshop visit is reached")
	return model


func _test_data_contract() -> void:
	var slice: Dictionary = I04.slice()
	_check(str(slice.source).contains("S. 15") and str(slice.source).contains("kein Wortlaut"), "Source and draft status are declared")
	for event_id: String in slice.consequences:
		var c: Dictionary = slice.consequences[event_id]
		_check(c.has("immediate_effect") and c.has("delayed_hook") and c.has("long_term_effect") and c.has("speaker_id") and c.has("line_id") and c.relationship.is_empty(), "Consequence contract complete, no bare relationship number: " + event_id)
		if not str(c.line_id).is_empty():
			_check(slice.lines.has(c.line_id), "Consequence names an existing line: " + event_id)
	var all_text := JSON.stringify(slice.lines)
	_check(not all_text.contains("Schwert") and not all_text.contains("Hufeisen"), "No sword for the child and no nailed horseshoe in 58 BC")


func _test_stack_path() -> void:
	var model = _at_forge()
	var wood := int(model.data.resources.wood)
	var money := int(model.data.resources.denarii)
	var trust := int(model.data.village.childhood.relationships.sextus.trust)
	_check(_sp(model).i04s == "pending" and _sp(model).i04_events.is_empty() and not model.data.village.childhood.carried.has("kindling_bundle"), "The visit opens with the bundle delivered and nothing decided")
	model.set_player_position(Vector3(0.0, 1.35, 0.0))
	var far: Dictionary = _act(model, "i04_stack")
	_check(not far.ok and str(far.message).contains("Schmiede"), "The work is chosen in the forge, not from afar: " + str(far.message))
	_check(_play(model, "i04_stack").ok and _stage(model) == "i04_stack_take", "Stacking starts at the delivered bundle")
	var wrong: Dictionary = _act(model, "i04_stack_put")
	_check(not wrong.ok, "Nothing can be stacked before it is taken")
	for trip in I04.STICKS:
		_check(_play(model).ok and bool(_sp(model).i04_hand) and str(Childhood.view(model.data).carried).contains("Kleinholz"), "Trip %d: an armful is in the boy's arm" % (trip + 1))
		var early: Dictionary = _act(model, "i04_stack_put")
		_check(not early.ok and str(early.message).contains("Blasebalg"), "It is put down at the bellows only")
		_check(_play(model).ok and not bool(_sp(model).i04_hand) and int(_sp(model).i04_sticks) == trip + 1, "Trip %d: stacked beside the bellows" % (trip + 1))
	_check(_stage(model) == "i04_topic" and _sp(model).i04_events == ["I-04.work.stack", "I-04.stack.done"], "The finished stack opens the talk at the anvil")
	# Keine doppelte Belohnung: no wood, no money, no second stacking.
	var before := JSON.stringify(model.data.village.childhood)
	for repeated: String in ["i04_stack_take", "i04_stack_put", "i04_stack", "deliver_kindling"]:
		_check(not _act(model, repeated).ok, "No second reward or repeat: " + repeated)
	_check(JSON.stringify(model.data.village.childhood) == before and int(model.data.resources.wood) == wood and int(model.data.resources.denarii) == money, "Stacking pays nothing and repeats change nothing")
	_check(I04.work_line_id(model.data) == "I04_B_WORK_STACK", "Sextus will name the stacked wood")
	_check(_play(model, "i04_topic_craft").ok and _sp(model).i04s == "complete" and I04.nail_kept(model.data), "Asking about the craft ends the visit; the nail stays on the anvil block")
	_check(int(model.data.village.childhood.relationships.sextus.trust) == trust, "No bare trust number is added by the visit")
	_check(not Combat.service_gear(model.data) and model.data.village.childhood.gear == "none", "The child leaves the forge without weapon or service gear")
	_check(_stage(model) == "apprentice_permission" and Childhood.validate(model.data).is_empty(), "The father's permission follows")
	var remembered: Array = I04.hook_lines(model.data, "apprentice_permission")
	_check(remembered.size() == 1 and str(remembered[0]).contains("geschichtet"), "Silvanus mentions the stacked wood because it happened")
	var forged: Dictionary = model.data.duplicate(true)
	forged.village.childhood.screenplay.i04_events.append("I-04.note.given")
	_check(not Childhood.validate(forged).is_empty(), "An invented memory is invalid")
	forged = model.data.duplicate(true)
	forged.village.childhood.screenplay.i04_sticks = 1
	_check(not Childhood.validate(forged).is_empty(), "A talk without the finished work is invalid")


func _test_message_route() -> void:
	var model = _at_forge()
	_check(_play(model, "i04_message").ok and model.data.village.childhood.carried.has("sextus_note") and _stage(model) == "i04_note_give", "Other route: the boy carries Sextus' wax tablet")
	_check(str(Childhood.view(model.data).hud_title).contains("Fabius"), "The HUD names Fabius: " + str(Childhood.view(model.data).hud_title))
	var ctx: Dictionary = Childhood.i04_ctx(model.data)
	model.set_player_position(Vector3((ctx.sextus as Vector2).x, 1.35, (ctx.sextus as Vector2).y))
	var here: Dictionary = _act(model, "i04_note_give")
	_check(not here.ok and str(here.message).contains("Fabius"), "The message is handed over at Fabius, not in the forge")
	_check(not _act(model, "i04_stack_take").ok and int(_sp(model).i04_sticks) == 0, "The other work is not done on the side")
	_check(_play(model).ok and not model.data.village.childhood.carried.has("sextus_note") and _sp(model).i04_note == "given", "Fabius has the message")
	_check(not _act(model, "i04_note_give").ok and _sp(model).i04_events == ["I-04.work.message", "I-04.note.given"], "The message is delivered once")
	_check(_stage(model) == "i04_topic" and I04.work_line_id(model.data) == "I04_B_WORK_MESSAGE", "Back at the anvil Sextus names the errand")
	_check(_play(model, "i04_topic_riding").ok and not I04.nail_kept(model.data), "No workpiece without the craft talk")
	_check(str(I04.hook_lines(model.data, "apprentice_permission")).contains("Nachricht"), "Silvanus mentions the errand")
	# Both ways are independent: the later smith steps stay reachable.
	for _index in 3:
		if not _check(_play(model).ok, "Later I-04 step after the message route: " + _stage(model)):
			break
	_check(model.data.village.childhood.completed.has("smith_trial"), "The trial morning is arranged after the message route as well")


func _test_watch_refusal() -> void:
	var model = _at_forge()
	_check(_play(model, "i04_watch").ok and _stage(model) == "i04_topic" and int(_sp(model).i04_sticks) == 0, "Refusal: watching leads straight to the anvil")
	_check(I04.work_line_id(model.data) == "I04_B_WORK_WATCH" and _sp(model).i04_events == ["I-04.work.watch"], "Only the decision to watch is stored")
	_check(_play(model, "i04_topic_father").ok and _sp(model).i04s == "complete", "The lesson happens without help")
	_check(str(I04.hook_lines(model.data, "apprentice_permission")).contains("hingesehen"), "Silvanus mentions the watching")
	var beats: Array = I04Film.vid_c_beats(model.data, "c", "l")
	_check(beats.size() == 1 and str(beats[0].line_id) == "I04_C_LESSON_FATHER", "VID-C names what the boy asked about")


func _test_sextus_absent() -> void:
	var model = _at_forge()
	# Sextus is called to the militia: he is not in his forge.
	model.data.village.militia.append("sextus")
	var before := JSON.stringify(model.data.village.childhood)
	var ctx: Dictionary = Childhood.i04_ctx(model.data)
	model.set_player_position(Vector3((ctx.sextus as Vector2).x, 1.35, (ctx.sextus as Vector2).y))
	for action: String in ["i04_stack", "i04_message", "i04_watch"]:
		var refused: Dictionary = _act(model, action)
		_check(not refused.ok, "Sextus absent: the command is refused: %s (%s)" % [action, str(refused.message)])
		_check(Childhood.i04_reason(model.data, action).contains("nicht in der Schmiede"), "Sextus absent: nobody runs his workshop: " + action)
	_check(JSON.stringify(model.data.village.childhood) == before, "Absence changes nothing")


func _test_films() -> void:
	var model = _at_forge()
	var ctx: Dictionary = Childhood.i04_ctx(model.data)
	var before := JSON.stringify(model.data)
	var previous := {}
	for step: Dictionary in Childhood.STEPS:
		if step.id == "deliver_kindling":
			previous = step
	var a: Dictionary = Cinematics.sequence_for(model.data, previous, Childhood.current_step(model.data))
	_check(str(a.get("id", "")) == I04Film.VID_A and JSON.stringify(model.data) == before, "The delivered bundle opens VID-A; a film start changes nothing")
	_check(str(a.beats[0].shot_id) == "prop_insert" and str(a.beats[0].anchor) == "i04_hearth", "VID-A opens on the fire before the people")
	var lines: Array = a.beats.map(func(b): return str(b.get("line_id", "")))
	_check(lines.has("I04_A_SILVANUS") and lines.has("I04_A_MEMORY"), "Silvanus introduces the boy; Sextus answers with their shared memory")
	var choice: Array = a.beats.filter(func(b): return bool(b.get("await_choice", false)))
	_check(choice.size() == 1 and str(choice[0].choice_step) == "i04_work" and choice[0].choices.size() == 3, "VID-A ends in the choice of work")
	_play(model, "i04_watch")
	var b: Dictionary = Cinematics.sequence_for(model.data, {"id":"i04_work", "mission":"I-04"}, Childhood.current_step(model.data))
	_check(str(b.get("id", "")) == I04Film.VID_B and str(b.beats[0].anchor) == "i04_tongs", "VID-B opens on the two tongs on the anvil")
	_check(b.beats.filter(func(x): return bool(x.get("silent", false))).size() >= 2, "VID-B has pauses")
	for beat: Dictionary in b.beats:
		if not bool(beat.get("silent", false)) and not bool(beat.get("await_choice", false)):
			_check(not str(beat.line_id).is_empty() and str(beat.speaker_id) in ["sextus", "silvanus", "chronik"], "Spoken beat keeps stable ids: " + str(beat.id))
	_play(model, "i04_topic_craft")
	var rebuilt: Dictionary = I04Film.restore(model.data, I04Film.VID_B, ctx)
	var reply: Dictionary = rebuilt.beats.filter(func(x): return str(x.id) == "i04_b_reply")[0]
	_check(str(reply.line_id) == "I04_B_TOPIC_CRAFT" and reply.cuts.any(func(c): return str(c.shot_id) == "prop_insert") and str(reply.anchor) == "i04_nail", "The handover of the nail is shown on the object")
	_check(I04Film.restore(model.data, I04Film.VID_A, ctx).is_empty(), "VID-A is not replayed after the talk")


func _test_save_load() -> void:
	var model = _at_forge()
	var points := 0
	for _index in 10:
		var stage := _stage(model)
		if not stage.begins_with("i04_"):
			break
		var path := directory.path_join("stage-%d.json" % points)
		_check(model.save_game(path).ok, "Save at " + stage)
		var copy = WorldModel.new()
		_check(copy.load_game(path).ok and _norm(copy.data.village.childhood) == _norm(model.data.village.childhood) and _stage(copy) == stage, "Load returns to the same point: " + stage)
		points += 1
		if not _check(_play(model).ok, "Continue after loading: " + stage):
			break
	_check(points == 6, "Saved before and after every decision and carry (%d points)" % points)


func _test_migration_v5_to_v6() -> void:
	var early = _at_forge("deliver_kindling")
	for key: String in I04.KEYS:
		early.data.village.childhood.screenplay.erase(key)
	early.data.village.childhood.screenplay.erase("investigation")
	early.data.village.childhood.screenplay.version = 5
	_check(Childhood.migrate_screenplay(early.data) and _sp(early).i04s == "pending" and _sp(early).version == Childhood.SCREENPLAY_VERSION and Childhood.validate(early.data).is_empty(), "A v5 save still carrying the bundle gets the visit: " + Childhood.validate(early.data))
	var late = _at_forge()
	for key: String in I04.KEYS:
		late.data.village.childhood.screenplay.erase(key)
	late.data.village.childhood.screenplay.erase("investigation")
	late.data.village.childhood.screenplay.version = 5
	_check(Childhood.migrate_screenplay(late.data) and _sp(late).i04s == "legacy" and _sp(late).i04_events.is_empty(), "A v5 save past the delivery is marked legacy; nothing is invented")
	_check(Childhood.validate(late.data).is_empty() and _stage(late) == "apprentice_permission", "It continues with the father's permission")
	_check(not _act(late, "i04_stack").ok and I04Film.vid_c_beats(late.data, "c", "l").is_empty(), "A legacy save cannot replay the visit and gets no invented line")
