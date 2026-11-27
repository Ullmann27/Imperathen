extends SceneTree
## Decisions, real work attendance and saves; geometry is exercised separately.

const Model = preload("res://scripts/domain/world_model.gd")
const Behavior = preload("res://scripts/domain/npc_behavior.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const Weather := preload("res://scripts/domain/local_weather.gd")
const Calendar := preload("res://scripts/domain/world_calendar.gd")
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
	var legacy := Model.new()
	legacy.new_game("italia",true)
	_check(not Behavior.enabled(legacy.data),"Legacy village keeps its published simulation")
	var model := Model.new()
	model.new_game("italia",true,true)
	_check(Behavior.enabled(model.data) and model.data.village.behavior.people.size() == 42,"All 42 existing villagers and companion have one saved decision record")
	_check(model._validate_state(model.data).is_empty(),"New childhood world is strictly valid")
	_check(Behavior.profile("julia").interest == "family" and Behavior.profile("sextus").interest == "craft" and Behavior.profile("marcus").interest == "learning","Canonical family and mentor have distinct interests")
	_check(Behavior.profile("flavia") != Behavior.profile("marius"),"Residents have stable individual traits")
	var activities := {}
	for id: String in model.data.village.behavior.people:
		var view := Behavior.view(model.data,id)
		activities[view.activity] = true
		_check(not view.interest_label.is_empty() and not view.mood_label.is_empty() and not view.reason.is_empty(),"Visible motive and mood exist for "+id)
	_check(activities.size() >= 2,"Residents do not all choose one identical routine")
	_test_observations(model)
	_test_needs_and_work()
	_test_senses()
	_test_partition()
	_test_saves()
	if failures.is_empty():
		print("NPC behavior: %d checks passed" % checks)
		quit(0)
	else:
		print("NPC behavior: %d failures / %d checks" % [failures.size(),checks])
		quit(1)


func _test_observations(model: RefCounted) -> void:
	var before: Dictionary = model.data.village.behavior.people.flavia.duplicate(true)
	Behavior.observe(model.data,{"flavia":{"position":[NAN,0.0,1.0],"route_distance":2.0},"intruder":{"position":[1,0,1]}})
	_check(model.data.village.behavior.people.flavia == before and not model.data.village.behavior.people.has("intruder"),"Invalid observations cannot corrupt positions or create residents")
	Behavior.observe(model.data,{"flavia":{"position":[-16.0,0.0,5.0],"route_distance":2.0,"route_direction":-1}})
	_check(model.data.village.behavior.people.flavia.position == [-16.0,0.0,5.0] and model.data.village.behavior.people.flavia.route_direction == -1,"Actual world position and route direction are observed")
	_check(model._validate_state(model.data).is_empty(),"Observed positions preserve world validity")
	Behavior.observe(model.data,{"bassa":{"position":[-16.0,0.0,6.0],"route_distance":1.0}})
	_check(model.data.village.behavior.people.flavia.observed and model.data.village.behavior.people.bassa.observed,"Partial observations preserve other valid resident observations")
	var last_bassa: Array = model.data.village.behavior.people.bassa.position.duplicate()
	Behavior.observe(model.data,{"flavia":{"position":[-16.0,0.0,5.0],"route_distance":2.0}},true)
	_check(model.data.village.behavior.people.flavia.observed and not model.data.village.behavior.people.bassa.observed,"Complete snapshot invalidates a resident whose body is no longer visible")
	_check(model.data.village.behavior.people.bassa.position == last_bassa,"Visibility invalidation does not erase the last valid position")
	Behavior.observe(model.data,{"flavia":{"position":[NAN,0.0,1.0]}},true)
	_check(not model.data.village.behavior.people.flavia.observed,"Invalid current body data cannot remain an active observation")
	_check(model._validate_state(model.data).is_empty(),"Visibility changes preserve the existing save contract")


func _test_needs_and_work() -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	var tired: Dictionary = model.data.village.behavior.people.fabius
	tired.fatigue = 96.0
	tired.social_need = 0.0
	tired.next_decision = 0.0
	var partner: Dictionary = model.data.village.behavior.people.drusa
	partner.social_need = 0.0
	partner.fatigue = 5.0
	model.advance(0.5)
	_check(model.data.world_seconds == 0.5,"World actually advances with the behavior contract")
	_check(Behavior.view(model.data,"fabius").activity == "rest","Exhausted worker independently chooses a break")
	var wood := _place(model.data,"woodcamp")
	_check(wood.assigned == 2 and wood.available == 1 and not wood.working,"Rest removes real production attendance while retaining the one worker assignment")
	var ledger: Dictionary = model.data.village.economy.ledger.duplicate(true)
	model.advance(10.0)
	_check(model.data.village.economy.ledger.wood == ledger.wood,"Paused woodcamp cannot manufacture work output")
	_check(model.data.village.behavior.people.fabius.fatigue < 96.0,"A real break reduces fatigue")
	model.advance(70.0)
	_check(Behavior.view(model.data,"fabius").activity == "work","Recovered worker returns to the existing assignment")
	_check(model.data.village.economy.people.size() == 14,"Break and return never duplicate economic people")
	_check(model._validate_state(model.data).is_empty(),"Economic resource and time ledgers remain valid after decisions")


func _test_senses() -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	var data: Dictionary = model.data.duplicate(true)
	Behavior.observe(data,{
		"flavia":{"position":[-16.0,0.0,5.0],"route_distance":2.0},
		"bassa":{"position":[-16.0,0.0,6.0],"route_distance":0.0},
		"lucius":{"position":[-16.0,0.0,7.0],"route_distance":0.0}})
	data.village.behavior.people.flavia.social_need = 100.0
	data.village.behavior.people.bassa.social_need = 100.0
	data.village.behavior.people.flavia.next_decision = 0.0
	data.village.behavior.people.bassa.next_decision = 0.0
	_step(data,0.5)
	_check(Behavior.view(data,"flavia").activity == "socialize" and Behavior.view(data,"flavia").partner == "bassa","Nearby neighbor becomes an observed social goal")
	var conversation_fixture: Dictionary = data.village.behavior.people.duplicate(true)
	var speaker: Dictionary = conversation_fixture.flavia
	var listener: Dictionary = conversation_fixture.bassa
	listener.activity = "socialize"
	listener.partner = "lucius"
	_check(not Behavior._has_company("flavia",speaker,conversation_fixture,Vector2.ZERO),"A neighbor talking to someone else cannot satisfy this resident's need")
	listener.partner = "flavia"
	listener.position = [-16.0,0.0,7.5]
	_check(not Behavior._has_company("flavia",speaker,conversation_fixture,Vector2.ZERO),"An approaching partner outside conversation distance does not count as company")
	listener.position = [-16.0,0.0,6.0]
	_check(Behavior._has_company("flavia",speaker,conversation_fixture,Vector2.ZERO),"A close and mutually selected conversation does count as company")
	var need := float(data.village.behavior.people.flavia.social_need)
	_step(data,0.5)
	_check(data.village.behavior.people.flavia.social_need < need,"Mutual nearby conversation satisfies social need")
	Behavior.observe(data,{"bassa":{"position":[30.0,0.0,25.0],"route_distance":0.0}})
	need = float(data.village.behavior.people.flavia.social_need)
	_step(data,0.5)
	_check(data.village.behavior.people.flavia.social_need >= need,"An absent conversational partner cannot satisfy a social need remotely")
	data.player.position = [-16.0,1.0,5.6]
	_step(data,0.5)
	_check(Behavior.view(data,"flavia").activity == "yield","Close player contact causes a mobile passerby to give way")
	data.player.position = [-15.3,1.0,15.4]
	Behavior.observe(data,{"julia":{"position":[-15.3,0.0,14.8],"route_distance":0.0}})
	_step(data,0.5)
	_check(Behavior.view(data,"julia").activity == "space","Quest-anchored mother requests distance without inventing a movement")
	data.player.position = [60.0,1.0,50.0]
	# Explicit perception fixture: it does not claim a completed story raid.
	data.village.raid.active = true
	data.village.raid.enemies = [{"id":"probe","health":50,"x":-16.0,"z":3.0}]
	_step(data,0.5)
	_check(Behavior.view(data,"flavia").activity == "flee" and Behavior.view(data,"lucius").activity == "alert","Civilian and guard make distinct decisions about the same nearby danger")
	_check(data.village.behavior.people.flavia.memories.back().kind == "danger_seen","Observed danger leaves a bounded memory")
	data.village.raid.enemies[0].health = 0
	_step(data,0.5)
	_check(Behavior.view(data,"flavia").activity != "flee","A defeated enemy no longer triggers flight")
	data.village.raid.active = false
	data.strategy.turn = 2
	# Select an actual autumn rain period from the shared deterministic clock.
	var rainy: Dictionary={}
	var autumn := Calendar.to_jdn(-58,9,1)
	for day in 90:
		var candidate := Calendar.new_clock(autumn+day,9*3600)
		if float(Weather.sample(candidate,"italia",2).rain)>=0.35:
			rainy=candidate
			break
	_check(not rainy.is_empty(),"Shared autumn weather has a rain period")
	data.calendar.clock=rainy
	for person: Dictionary in data.village.behavior.people.values():
		person.next_decision = float(data.village.behavior.seconds)
	_step(data,0.5)
	_check(Behavior.view(data,"flavia").activity == "weather_pause" and Behavior.view(data,"lucius").activity == "patrol","Actual autumn weather interrupts outdoor activity but preserves guard duty")
	_check(Behavior.validate(data).is_empty(),"All perception decisions preserve their strict saved contract")


func _test_partition() -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	var whole: Dictionary = model.data.duplicate(true)
	var split: Dictionary = model.data.duplicate(true)
	_step(whole,12.5)
	for index in 50:
		_step(split,0.25)
	_check(whole.village.behavior == split.village.behavior,"Fixed decision ticks are invariant to frame partition with unchanged observations")


func _test_saves() -> void:
	var model := Model.new()
	model.new_game("italia",true,true)
	model.advance(7.25)
	Behavior.observe(model.data,{"flavia":{"position":[-16.0,0.0,5.0],"route_distance":2.0,"route_direction":-1}})
	var stored: Dictionary = model.data.village.behavior.duplicate(true)
	var path := "user://npc-behavior-roundtrip.json"
	_check(model.save_game(path).ok,"Strict save writes behavior and observed routes")
	var restored := Model.new()
	_check(restored.load_game(path).ok,"Strict save loads behavior")
	_check(_same(restored.data.village.behavior,stored),"Needs, current intention, memories and route direction survive JSON save/load")
	var legacy: Dictionary = model.data.duplicate(true)
	legacy.village.erase("behavior")
	var legacy_path := "user://npc-behavior-migration.json"
	_write_save(legacy_path,legacy)
	_check(restored.load_game(legacy_path).ok,"Previous childhood saves migrate to the optional behavior contract")
	_check(Behavior.enabled(restored.data) and restored.data.world_seconds == legacy.world_seconds and _same(restored.data.resources,legacy.resources) and _same(restored.data.village.childhood,legacy.village.childhood),"Migration preserves story, family identities, clock and goods")
	var before: Dictionary = restored.data.duplicate(true)
	var corrupt: Dictionary = model.data.duplicate(true)
	corrupt.village.behavior.people.flavia.fatigue = 101.0
	var bad_path := "user://npc-behavior-invalid.json"
	_write_save(bad_path,corrupt)
	_check(not restored.load_game(bad_path).ok and restored.data == before,"A malformed behavior record is rejected without replacing the current world")
	corrupt = legacy.duplicate(true)
	corrupt.village.social = []
	bad_path = "user://npc-behavior-invalid-legacy.json"
	_write_save(bad_path,corrupt)
	_check(not restored.load_game(bad_path).ok and restored.data == before,"Malformed old family data is rejected before the behavior initializer reads it")


func _place(data: Dictionary, id: String) -> Dictionary:
	for place: Dictionary in Economy.view(data).workplaces:
		if place.id == id:
			return place
	return {}


func _step(data: Dictionary, delta: float) -> void:
	data.world_seconds = float(data.world_seconds)+delta
	Behavior.advance(data,delta)


func _write_save(path: String, data: Dictionary) -> void:
	var payload := JSON.stringify(data,"",true,true)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"format":Model.SAVE_FORMAT,"format_version":1,"payload":payload,"sha256":payload.sha256_text()}))
	file.close()


func _same(left: Variant, right: Variant) -> bool:
	# JSON restores ordinary arrays and numeric variants. Compare every value,
	# allowing only sub-nanounit float round-trip error, not lost state.
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]:
		return absf(float(left)-float(right)) < 0.000000001
	if typeof(left) == TYPE_DICTIONARY and typeof(right) == TYPE_DICTIONARY:
		if left.size() != right.size():
			return false
		for key: Variant in left:
			if not right.has(key) or not _same(left[key],right[key]):
				return false
		return true
	if typeof(left) == TYPE_ARRAY and typeof(right) == TYPE_ARRAY:
		if left.size() != right.size():
			return false
		for index in left.size():
			if not _same(left[index],right[index]):
				return false
		return true
	return left == right
