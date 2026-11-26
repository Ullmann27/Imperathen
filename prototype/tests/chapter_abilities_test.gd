extends SceneTree
## Chapter I abilities: stable catalog IDs with Band-1 sources, earned only through
## the real WorldModel journey, persisted in schema-v5 saves (including saves that
## predate the record) and effective in free village commands after their mission.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const Abilities = preload("res://scripts/story/chapter_abilities.gd")
const STABLE_IDS := ["ch1_look_before_force", "ch1_price_is_promise", "ch1_read_tracks"]
var checks := 0
var failures: Array[String] = []
var directory := "user://chapter_abilities_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_test_catalog()
	_test_journey_persistence_and_effects()
	print("CHAPTER_ABILITIES_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("CHAPTER_ABILITIES_PASS" if failures.is_empty() else "CHAPTER_ABILITIES_FAIL")
	quit(0 if failures.is_empty() else 1)


func _test_catalog() -> void:
	_check(Abilities.ids() == STABLE_IDS, "Ability IDs are stable and append-only: " + str(Abilities.ids()))
	var arc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/story/campaign_arc.json"))
	var titles := {}
	for mission: Dictionary in arc.bands[0].main_missions:
		titles[mission.id] = mission.title
	for item: Dictionary in Abilities.catalog():
		var mission: String = item.mission
		_check(titles.has(mission), "Ability mission exists in Band 1: " + item.id)
		_check(str(item.source).begins_with("Band 1 · Abschnitt „%s · %s“ · Tabelle" % [mission, titles.get(mission, "?")]), "Ability source cites the Band-1 section: " + item.id)
		_check(str(item.effect_status).begins_with("Ergänzung"), "Invented game values are marked as additions: " + item.id)
		if item.grant.has("completed"):
			_check(Childhood.SOURCE_MISSION_BY_STEP.get(item.grant.completed, "") == mission, "Granting step belongs to the cited mission: " + item.id)


func _test_journey_persistence_and_effects() -> void:
	var model = WorldModel.new()
	model.new_game("italia", true, true)
	_check(model.data.village.abilities == {"version":1, "earned":[]}, "A fresh childhood starts without abilities")
	_check(Economy.emergency_food_price(model.data) == 6, "Baseline emergency food price is unchanged")
	if not _until(model, "forge_quench"):
		return
	_check(Abilities.has(model.data, "ch1_look_before_force") and model.data.village.abilities.earned.size() == 1, "Finding the crack at the anvil (I-05) teaches the first lesson")
	if not _until(model, "smith_apprentice"):
		return
	_check(Abilities.has(model.data, "ch1_price_is_promise") and Economy.emergency_food_price(model.data) == 5, "Delivering the promised grip (I-06) makes the merchant price a real one-denarius advantage")
	_ok(model.save_game(_path("mid")), "Save with earned abilities")
	var resumed = WorldModel.new()
	_ok(resumed.load_game(_path("mid")), "Reload keeps abilities")
	_check(resumed.data.village.abilities.earned == ["ch1_look_before_force", "ch1_price_is_promise"] and typeof(resumed.data.village.abilities.version) == TYPE_INT, "Earned abilities and integer version survive the round trip")
	# A schema-v5 save written before abilities existed derives them from saved facts.
	var legacy: Dictionary = resumed.data.duplicate(true)
	legacy.village.erase("abilities")
	_write(_path("before-abilities"), legacy)
	var migrated = WorldModel.new()
	_ok(migrated.load_game(_path("before-abilities")), "Load a v5 save that predates the ability record")
	_check(migrated.data.schema_version == WorldModel.SCHEMA_VERSION and migrated.data.village.abilities.earned == ["ch1_look_before_force", "ch1_price_is_promise"], "Migration reaches the current schema and restores proven abilities")
	var forged: Dictionary = resumed.data.duplicate(true)
	forged.village.abilities.earned.append("ch1_unknown")
	_write(_path("forged"), forged)
	_check(not WorldModel.new().load_game(_path("forged")).ok, "Unknown ability IDs are rejected")
	var dropped: Dictionary = resumed.data.duplicate(true)
	dropped.village.abilities.earned = ["ch1_look_before_force"]
	_write(_path("dropped"), dropped)
	_check(not WorldModel.new().load_game(_path("dropped")).ok, "A save cannot silently lose an ability its facts prove")
	if not _until(resumed, "i08_report"):
		return
	_check(Abilities.has(resumed.data, "ch1_read_tracks") and Abilities.effect_value(resumed.data, "scout_insight_bonus") == 1.0, "Securing hoof prints (I-08) teaches track reading")
	if not _until(resumed, "night_rest"):
		return
	# I-09 optional visit authored in mission data reaches the real dialogue path.
	_check(str(Childhood.dialogue(resumed.data, "sextus").get("text", "")).contains("Eine Klinge verzeiht dir keinen Gedanken"), "I-09 evening visit to Sextus shows his Band 1 line")
	if not _complete(resumed):
		return
	_ok(resumed.execute("village_childhood_begin_raid"), "Release the night raid after the chapter beginning")
	_check(resumed.data.village.raid.active, "The raid is the real free village combat system")
	_ok(resumed.execute("village_unarmed_guard"), "Guard in the raid with the real unarmed combat command")
	_check(is_equal_approx(float(resumed.data.village.unarmed.guard_remaining), 1.05) and is_equal_approx(float(resumed.data.village.raid.block_window), 0.95), "The I-05 lesson lengthens guard 0.85 → 1.05 s and block window 0.75 → 0.95 s outside its mission")
	_check(resumed._validate_state(resumed.data).is_empty(), "The longer guard is a valid persistent state: " + resumed._validate_state(resumed.data))
	_check(resumed.data.village.abilities.earned == STABLE_IDS, "All three chapter-I abilities remain earned after their missions")


# Helpers mirror tests/village_childhood_test.gd: authoritative points, real commands.
func _at(model, point: Vector2) -> void:
	model.set_player_position(Vector3(point.x, 1.0, point.y))


func _meet(model, id: String) -> bool:
	_at(model, Life.actor_position(model.data, id))
	if Life.relationship(model.data, id).get("met", false):
		return true
	return _ok(model.execute("village_talk", {"npc_id":id, "choice":"meet"}), "Meet " + id)


func _action(model, id: String) -> Dictionary:
	return model.execute("village_childhood_action", {"action_id":id})


func _current(model) -> String:
	return str(Childhood.view(model.data).get("stage", "invalid"))


func _complete(model) -> bool:
	var view: Dictionary = Childhood.view(model.data)
	var stage := str(view.get("stage", ""))
	var screenplay_actions := {"i02_basket":"basket_check", "i02_correct":"basket_correct", "i03_marcus":"marcus_friend",
		"i07_water_fetch":"i07_water_fetch", "i07_water_bring":"i07_water_bring",
		"i08_tracks":"i08_inspect", "i08_report":"i08_report"}
	if screenplay_actions.has(stage):
		_at(model, view.point)
		if not str(view.get("target_npc", "")).is_empty() and not _meet(model, str(view.target_npc)):
			return false
		return _ok(_action(model, screenplay_actions[stage]), "Screenplay step " + stage)
	if int(view.get("completed_steps", 999)) >= Childhood.STEPS.size():
		return false
	var step: Dictionary = Childhood.STEPS[int(view.completed_steps)]
	_at(model, view.point)
	if step.has("npc") and not _meet(model, step.npc):
		return false
	if step.has("seconds"):
		if not _ok(_action(model, "begin_" + str(step.id)), "Begin " + str(step.id)):
			return false
		model.advance(float(step.seconds))
	var selected: String = "market_fair" if step.id == "market_trade" else str(step.id)
	return _ok(_action(model, selected), "Step " + selected)


func _until(model, stage: String) -> bool:
	for _index in Childhood.STEPS.size() + 16:
		if _current(model) == stage:
			return true
		if not _complete(model):
			return false
	_check(false, "Stage reachable: " + stage)
	return false


func _path(name: String) -> String:
	return directory.path_join(name + ".json")


func _write(path: String, state: Dictionary) -> void:
	var payload := JSON.stringify(state)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format":WorldModel.SAVE_FORMAT, "format_version":1, "payload":payload, "sha256":payload.sha256_text()}))
	file.close()


func _ok(result: Dictionary, message: String) -> bool:
	_check(bool(result.get("ok", false)), message + ": " + str(result.get("message", "")))
	return bool(result.get("ok", false))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
