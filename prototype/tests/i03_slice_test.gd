extends SceneTree
## I-03 „Marcus kennt eine Abkürzung“ domain contract through the real
## WorldModel. Positions are explicit fixture placements at authored points.
## Handbook mapping (HB S. 14 and S. 70): Marcus abwesend, Gegenstand bereits
## bezahlt, getrennte Route, kein verstecktes Loyalitätsflag, alternative
## Wahl/Verzicht, Save/Load vor und nach der Entscheidung, kein Reward bei
## bloßem Filmstart, plus the v4 -> v5 save migration.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I03 = preload("res://scripts/story/i03_shortcut.gd")
const I03Film = preload("res://scripts/story/i03_film.gd")
const Cinematics = preload("res://scripts/story/mission_cinematics.gd")
const Support = preload("res://tests/i03_support.gd")
var checks := 0
var failures: Array[String] = []
var directory := "user://i03_slice_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_test_data_contract()
	_test_clarify_path()
	_test_service_path_and_paid_once()
	_test_debt_and_dispute()
	_test_apology()
	_test_separate_route_and_promise()
	_test_marcus_absent()
	_test_no_hidden_flag()
	_test_save_load()
	_test_films_follow_state()
	_test_migration_v4_to_v5()
	print("I03_SLICE_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("I03_SLICE_PASS" if failures.is_empty() else "I03_SLICE_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition


func _act(model, id: String) -> Dictionary:
	return model.execute("village_childhood_action", {"action_id":id})


## Saved numbers come back as floats; compare through one JSON round trip.
func _norm(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))


func _stage(model) -> String:
	return Support.stage(model)


func _sp(model) -> Dictionary:
	return model.data.village.childhood.screenplay


func _events(model) -> Array:
	return _sp(model).i03_events


## A regular new life played up to the lane with Marcus (I-01 and I-02 with
## their first authored options, through the real commands).
func _at_lane():
	var model = WorldModel.new()
	model.new_game("italia", true, true, false, true)
	for _index in 40:
		var view: Dictionary = Childhood.view(model.data)
		var stage := str(view.get("stage", ""))
		if stage == "i03_marcus":
			return model
		var point: Vector2 = view.point
		model.set_player_position(Vector3(point.x, 1.35, point.y))
		var npc := str(view.get("target_npc", ""))
		if not npc.is_empty() and not bool(Childhood.relationship(model.data, npc).get("met", false)):
			model.execute("village_talk", {"npc_id":npc, "choice":"meet"})
		view = Childhood.view(model.data)
		var action := "basket_check" if stage == "i02_basket" else str(view.actions[0].payload.action_id)
		if not _check(_act(model, action).ok, "Reach the lane: " + stage):
			return model
	_check(false, "The lane with Marcus is reached")
	return model


## Plays the family order up to the farewell stage.
func _buy_order(model) -> void:
	for _index in 4:
		var view: Dictionary = Childhood.view(model.data)
		if str(view.get("stage", "")) in ["i03_farewell", "deliver_food"]:
			return
		var point: Vector2 = view.point
		model.set_player_position(Vector3(point.x, 1.35, point.y))
		if not _check(_act(model, str(view.actions[0].payload.action_id)).ok, "Family order step " + str(view.stage)):
			return


func _test_data_contract() -> void:
	var slice: Dictionary = I03.slice()
	_check(str(slice.source).contains("S. 14") and str(slice.source).contains("kein Wortlaut"), "Source and draft status of the lines are declared")
	for event_id: String in slice.consequences:
		var c: Dictionary = slice.consequences[event_id]
		_check(c.has("immediate_effect") and c.has("delayed_hook") and c.has("long_term_effect") and c.has("speaker_id") and c.has("line_id"), "Consequence contract complete: " + event_id)
		if not str(c.line_id).is_empty():
			_check(slice.lines.has(c.line_id), "Consequence names an existing line: " + event_id)
	for line_id: String in slice.lines:
		_check(str(slice.lines[line_id].speaker_id) in ["marcus", "cassia", "chronik"] and str(slice.lines[line_id].text).length() > 8, "Line has speaker and text: " + line_id)
	_check(int(slice.prices.marcus_asses) == int(slice.prices.small_measure_asses) and int(slice.prices.large_measure_asses) - int(slice.prices.marcus_asses) == 1, "The conflict is a real missing coin: two asses, the large measure costs three")


func _test_clarify_path() -> void:
	var model = _at_lane()
	_check(not model.data.companion.met and _sp(model).i03s == "pending" and _events(model).is_empty(), "I-03 starts with nothing decided about Marcus")
	var far: Dictionary = _act(model, "i03_together")
	_check(not far.ok and str(far.message).contains("näher"), "The route is chosen next to Marcus, not from afar: " + str(far.message))
	_check(Support.play_stage(model).ok and _sp(model).i03_route == "together" and _stage(model) == "i03_coin", "Going together leads to the stall")
	_check(I03.marcus_station(model.data, Childhood.i03_ctx(model.data)) == "follow", "Marcus walks with the boy")
	# Physical presence: the dispute needs Marcus at the stall and the boy there.
	Support.place_player(model, (Childhood.i03_ctx(model.data).cassia as Vector2) + Vector2(0.0, 2.0))
	model.execute("village_talk", {"npc_id":"cassia", "choice":"meet"})
	Support.place_marcus(model, I03.POINTS.lane)
	var early: Dictionary = _act(model, "i03_watch")
	_check(not early.ok and str(early.message).contains("noch nicht am Stand"), "No talk across the village: Marcus must have arrived: " + str(early.message))
	_check(Support.play_stage(model).ok and _sp(model).i03_stance == "watch" and _stage(model) == "i03_resolve", "Watching opens Cassia's explanation")
	_check(Support.play_stage(model).ok and _sp(model).i03_task == "measure" and _sp(model).i03 == "pending", "Clarifying asks for the real measuring, nothing is paid yet")
	_check(model.data.village.childhood.screenplay.i03_salt == "", "A proposal alone fills no pot")
	_check(Support.play_stage(model).ok and _sp(model).i03_salt == "small" and _sp(model).i03 == "complete", "The small measure is filled by the boy's own action")
	_check(_stage(model) == "market_meeting" and not model.data.companion.met, "Julia's order follows; Marcus is not summarised yet")
	_buy_order(model)
	_check(_stage(model) == "i03_farewell" and model.data.village.childhood.carried.has("family_parcel"), "With the parcel in hand the farewell opens")
	_check(Support.play_stage(model).ok and _sp(model).i03s == "complete" and _sp(model).i03_home == "together", "They walk home together")
	_check(model.data.companion.met and model.data.companion.choice == "help" and _sp(model).i03_outcome == "friend", "Summary is derived from the memories when they part")
	var wanted := ["I-03.route.together", "I-03.stance.watch", "I-03.resolve.clarify", "I-03.salt.small", "I-03.home.together"]
	_check(_events(model) == wanted, "Ledger holds exactly the played events: " + str(_events(model)))
	_check(_stage(model) == "deliver_food" and Childhood.validate(model.data).is_empty(), "The order goes home; state validates")


func _test_service_path_and_paid_once() -> void:
	var model = _at_lane()
	Support.play_stage(model)
	_check(Support.play_stage(model, {"i03_coin":"i03_offer"}).ok and _sp(model).i03_stance == "offer", "Help is offered")
	var money: int = int(model.data.resources.denarii)
	_check(money == 0 and model.data.village.childhood.carried.has("household_coin"), "The boy has no own money; the household coin is reserved")
	_check(Support.play_stage(model, {"i03_resolve":"i03_accept"}).ok and _stage(model) == "i03_service_fetch", "Accepting the large measure asks for a service instead of the third as")
	_check(model.data.village.childhood.carried.has("household_coin"), "The household coin is not spent on Marcus' salt")
	var wrong_place: Dictionary = _act(model, "i03_service_fetch")
	_check(not wrong_place.ok and str(wrong_place.message).contains("Brunnen"), "Water is drawn at the well only")
	_check(Support.play_stage(model).ok and model.data.village.childhood.carried.has("stall_water") and _sp(model).i03_salt == "", "The jug is carried; nothing is paid by fetching alone")
	_check(I03.marcus_station(model.data, Childhood.i03_ctx(model.data)) == "follow", "Marcus comes along to the well")
	_check(Support.play_stage(model).ok and not model.data.village.childhood.carried.has("stall_water") and _sp(model).i03_salt == "large", "Delivered water pays the third as")
	# Gegenstand bereits bezahlt: no second payment, no second reward.
	var before := JSON.stringify(model.data.village.childhood)
	for repeated: String in ["i03_service_bring", "i03_service_fetch", "i03_measure", "i03_accept"]:
		var again: Dictionary = _act(model, repeated)
		_check(not again.ok, "Already paid: " + repeated + " is refused")
	_check(JSON.stringify(model.data.village.childhood) == before, "A refused repeat changes nothing")
	_check(_events(model).count("I-03.service.done") == 1 and int(model.data.resources.denarii) == money, "The service is stored once and creates no money")
	_buy_order(model)
	_check(not model.data.village.childhood.carried.has("household_coin") and model.data.village.childhood.carried.has("family_parcel"), "The household coin buys exactly Julia's order")
	_check(Support.play_stage(model).ok and model.data.companion.choice == "help", "Friendly parting after real help")
	_check(I03.hook_lines(model.data, "deliver_food").size() == 1 and str(Childhood.dialogue(_near_julia(model), "julia").text).contains("Wasser getragen"), "Julia mentions the service only because it happened")


func _near_julia(model) -> Dictionary:
	var view: Dictionary = Childhood.view(model.data)
	var point: Vector2 = view.point
	model.set_player_position(Vector3(point.x, 1.35, point.y))
	return model.data


func _test_debt_and_dispute() -> void:
	var model = _at_lane()
	Support.play_stage(model)
	_check(Support.play_stage(model, {"i03_coin":"i03_object"}).ok, "The boy contradicts Marcus")
	_check(Support.play_stage(model, {"i03_resolve":"i03_accept"}).ok and _sp(model).i03_salt == "debt" and _sp(model).i03 == "complete", "Without an offer the third as becomes Marcus' debt")
	_check(_events(model).has("I-03.salt.debt") and not _events(model).has("I-03.service.water"), "Debt is a stored fact, no service is invented")
	_buy_order(model)
	_check(I03.farewell_open_id(model.data) == "I03_C_OPEN_DISPUTE", "Marcus addresses the open dispute")
	var labels: Array = Childhood.view(model.data).actions.map(func(a): return str(a.payload.action_id))
	_check(labels.has("i03_apologise") and not labels.has("i03_home_alone"), "An apology is offered while the dispute is open: " + str(labels))
	_check(Support.play_stage(model, {"i03_farewell":"i03_home_together"}).ok, "Walking together without settling it")
	_check(model.data.companion.choice == "decline" and I03.farewell_reply_id(model.data) == "I03_C_TOGETHER_TENSE", "The dispute stays open; the summary and the line say so")
	_check(I03.hook_lines(model.data, "deliver_food").size() == 1, "Julia hears about the debt")


func _test_apology() -> void:
	var model = _at_lane()
	Support.play_stage(model)
	Support.play_stage(model, {"i03_coin":"i03_object"})
	Support.play_stage(model, {"i03_resolve":"i03_refuse"})
	_check(_sp(model).i03_salt == "none", "No purchase is a valid end")
	_buy_order(model)
	_check(Support.play_stage(model, {"i03_farewell":"i03_apologise"}).ok and _sp(model).i03_apology and _sp(model).i03_home == "together", "The boy apologises")
	_check(model.data.companion.choice == "help" and _events(model).has("I-03.apology") and I03.farewell_reply_id(model.data) == "I03_C_APOLOGY", "The apology is stored and settles the dispute")
	var friendly = _at_lane()
	Support.play_errand(friendly)
	_buy_order(friendly)
	var none: Dictionary = _act(friendly, "i03_apologise")
	_check(not none.ok, "No apology without a dispute: " + str(none.message))


func _test_separate_route_and_promise() -> void:
	var apart = _at_lane()
	_check(Support.play_stage(apart, {"i03_marcus":"i03_apart"}).ok and I03.marcus_station(apart.data, Childhood.i03_ctx(apart.data)) == "stall", "Separate route: Marcus goes to the stall by himself")
	_check(Support.play_errand(apart, Support.RIVAL) and not _events(apart).has("I-03.promise.kept"), "A separate route makes no promise")
	var later = _at_lane()
	_check(Support.play_stage(later, {"i03_marcus":"i03_later"}).ok and not _events(later).has("I-03.promise.kept"), "Promising to come is not yet keeping it")
	_check(Support.play_stage(later).ok and _events(later).has("I-03.promise.kept"), "The promise counts as kept when the boy really stands at the stall with Marcus")


func _test_marcus_absent() -> void:
	var model = _at_lane()
	model.data.village.behavior.people.marcus.activity = "absent"
	model.data.village.behavior.people.marcus.reason = "unavailable"
	var before := JSON.stringify(model.data.village.childhood)
	Support.place_player(model, I03.POINTS.lane + Vector2(1.0, 0.0))
	for action: String in ["i03_together", "i03_later", "i03_apart"]:
		var refused: Dictionary = _act(model, action)
		_check(not refused.ok and str(refused.message).contains("nicht an der Gasse"), "Absent Marcus: no route talk, no stand-in: " + action)
	_check(JSON.stringify(model.data.village.childhood) == before and not model.data.companion.met, "Absence changes nothing and rewards nothing")
	# He was there for the lane but does not come to the stall.
	var missed = _at_lane()
	Support.play_stage(missed, {"i03_marcus":"i03_later"})
	missed.data.village.behavior.people.marcus.activity = "absent"
	Support.place_player(missed, (Childhood.i03_ctx(missed.data).cassia as Vector2) + Vector2(0.0, 2.0))
	missed.execute("village_talk", {"npc_id":"cassia", "choice":"meet"})
	var options: Array = Childhood.view(missed.data).actions.map(func(a): return str(a.payload.action_id))
	_check(options == ["i03_missed"], "Without Marcus at the stall only his absence can be stated: " + str(options))
	_check(not _act(missed, "i03_watch").ok, "No dispute without Marcus")
	_check(_act(missed, "i03_missed").ok and _sp(missed).i03_salt == "none" and _sp(missed).i03s == "complete", "The errand with Marcus ends without a dispute")
	_check(_events(missed) == ["I-03.route.later", "I-03.marcus.missed", "I-03.home.alone"] and not _events(missed).has("I-03.promise.kept"), "Only the facts are stored: " + str(_events(missed)))
	_check(Cinematics.sequence_for(missed.data, {"id":"market_purchase", "source_mission":"I-03"}, {"id":"i03_farewell"}).is_empty(), "No farewell film is built for an absent Marcus")
	_check(_stage(missed) == "market_meeting" and Childhood.validate(missed.data).is_empty(), "Julia's order stays playable")


func _test_no_hidden_flag() -> void:
	var model = _at_lane()
	for old: String in ["marcus_friend", "marcus_rival"]:
		_check(not _act(model, old).ok, "The former friend/rival button does not exist: " + old)
	_check(not model.execute("choose_companion", {"choice":"help"}).ok or not model.data.companion.met, "No other command decides Marcus during the childhood")
	Support.play_errand(model)
	_check(not model.data.companion.met and model.data.companion.choice == "" and int(model.data.companion.trust) == 0, "No relationship value moves before the two part")
	# Tampering with the summary against the stored memories is rejected.
	_buy_order(model)
	Support.play_stage(model)
	var forged: Dictionary = model.data.duplicate(true)
	forged.companion.choice = "decline"
	forged.companion.trust = -5
	forged.village.childhood.screenplay.i03_outcome = "rival"
	_check(not Childhood.validate(forged).is_empty(), "A summary that contradicts the memories is invalid")
	forged = model.data.duplicate(true)
	forged.village.childhood.screenplay.i03_events.append("I-03.apology")
	_check(not Childhood.validate(forged).is_empty(), "An invented memory is invalid")
	forged = model.data.duplicate(true)
	forged.village.childhood.screenplay.i03_salt = "large"
	_check(not Childhood.validate(forged).is_empty(), "Salt without the paid service is invalid")


func _test_save_load() -> void:
	var model = _at_lane()
	var points := 0
	for _index in 12:
		var stage := _stage(model)
		if not stage.begins_with("i03_") and stage not in ["market_meeting", "market_purchase"]:
			break
		var path := directory.path_join("stage-%d.json" % points)
		_check(model.save_game(path).ok, "Save at " + stage)
		var copy = WorldModel.new()
		_check(copy.load_game(path).ok and _norm(copy.data.village.childhood) == _norm(model.data.village.childhood) and _norm(copy.data.companion) == _norm(model.data.companion) and _stage(copy) == stage, "Load returns to the same point: " + stage)
		points += 1
		if stage.begins_with("i03_"):
			if not _check(Support.play_stage(model, {"i03_coin":"i03_offer", "i03_resolve":"i03_accept"}).ok, "Continue after loading: " + stage):
				break
		else:
			_buy_order(model)
	_check(points >= 7, "Saved before and after every decision (%d points)" % points)


func _test_films_follow_state() -> void:
	var model = _at_lane()
	var index: Dictionary = Childhood.i03_ctx(model.data)
	var before := JSON.stringify(model.data)
	var a: Dictionary = I03Film.vid_a(model.data, index)
	var choice_a: Array = a.beats.filter(func(b): return bool(b.get("await_choice", false)))
	_check(choice_a.size() == 1 and str(choice_a[0].choice_step) == "i03_marcus" and choice_a[0].choices.size() == 3, "VID-A ends in the route choice")
	_check(JSON.stringify(model.data) == before, "Building or starting a film changes nothing (no reward for a film start)")
	_check(str(a.beats[0].shot_id) == "duo_hands", "VID-A opens on the coins in Marcus' hand before the wider picture")
	Support.play_stage(model)
	Support.play_stage(model, {"i03_coin":"i03_object"})
	var b: Dictionary = Cinematics.sequence_for(model.data, {"id":"i03_coin", "mission":"I-03"}, Childhood.current_step(model.data))
	_check(str(b.get("id", "")) == I03Film.VID_B, "The committed stance opens VID-B")
	var lines: Array = b.beats.map(func(x): return str(x.get("line_id", "")))
	_check(lines.has("I03_B_CASSIA") and lines.has("I03_B_MARCUS_OBJECT") and not lines.has("I03_B_MARCUS_OFFER"), "Marcus reacts to the stored stance")
	var silent: Array = b.beats.filter(func(x): return bool(x.get("silent", false)))
	_check(silent.size() >= 3 and str(silent[0].anchor) == "i03_coins", "VID-B has pauses; the first rests on the coins")
	for beat: Dictionary in b.beats:
		if not bool(beat.get("silent", false)) and not bool(beat.get("await_choice", false)):
			_check(not str(beat.line_id).is_empty() and str(beat.speaker_id) in ["marcus", "cassia", "chronik"], "Spoken beat keeps stable ids: " + str(beat.id))
	Support.play_stage(model, {"i03_resolve":"i03_refuse"})
	_check(str(I03Film.restore(model.data, I03Film.VID_B, index).beats.filter(func(x): return str(x.id) == "i03_b_reply")[0].line_id) == "I03_B_RESOLVE_REFUSE", "The rebuilt film answers the committed proposal")
	_check(I03Film.restore(model.data, I03Film.VID_A, index).is_empty(), "VID-A is not replayed after the stall")
	_buy_order(model)
	var c: Dictionary = I03Film.vid_c(model.data, index)
	_check(str(c.beats[1].line_id) == "I03_C_OPEN_DISPUTE" and c.beats[2].choices.size() == 3, "VID-C opens with the dispute and offers the apology")


func _test_migration_v4_to_v5() -> void:
	# A v4 save standing before I-03 gets the playable errand.
	var early = _at_lane()
	for key: String in I03.KEYS:
		early.data.village.childhood.screenplay.erase(key)
	early.data.village.childhood.screenplay.version = 4
	_check(Childhood.migrate_screenplay(early.data) and _sp(early).i03s == "pending" and _sp(early).version == 5 and Childhood.validate(early.data).is_empty(), "An undecided v4 save gets the errand")
	_check(_stage(early) == "i03_marcus", "It continues at the lane")
	# A v4 save with the former decision keeps it untouched.
	var decided = _at_lane()
	for key: String in I03.KEYS:
		decided.data.village.childhood.screenplay.erase(key)
	var s: Dictionary = decided.data.village.childhood.screenplay
	s.version = 4
	s.i03 = "complete"
	s.i03_outcome = "rival"
	decided.data.companion.met = true
	decided.data.companion.choice = "decline"
	decided.data.companion.trust = -5
	var companion_before := JSON.stringify(decided.data.companion)
	_check(Childhood.migrate_screenplay(decided.data) and _sp(decided).i03s == "legacy" and _sp(decided).i03_events.is_empty(), "A decided v4 save is marked legacy; no memory is invented")
	_check(JSON.stringify(decided.data.companion) == companion_before and _sp(decided).i03_outcome == "rival", "The stored decision is unchanged")
	_check(Childhood.validate(decided.data).is_empty() and _stage(decided) == "market_meeting", "The legacy save validates and continues with Julia's order")
	_check(not _act(decided, "i03_together").ok, "A legacy save cannot replay the errand")
