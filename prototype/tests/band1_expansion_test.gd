extends SceneTree
## Band 1 expansion beyond the first alignment: I-07 water task (story core
## „Wasser, Nachricht und kurze Kontrollrunde“), screenplay bridge v3 save
## migration. Everything runs through WorldModel commands.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Life = preload("res://scripts/story/village_life.gd")
var checks := 0
var failures: Array[String] = []
var directory := "user://band1_expansion_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_test_i07_water_and_migration()
	print("BAND1_EXPANSION_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("BAND1_EXPANSION_PASS" if failures.is_empty() else "BAND1_EXPANSION_FAIL")
	quit(0 if failures.is_empty() else 1)


func _test_i07_water_and_migration() -> void:
	var model = WorldModel.new()
	model.new_game("italia", true, true)
	_check(model.data.village.childhood.screenplay.version == Childhood.SCREENPLAY_VERSION, "Fresh childhood writes screenplay bridge v3")
	if not _until(model, "borrow_gear"):
		return
	var before_water: Dictionary = model.data.duplicate(true)
	_check(model.data.village.childhood.screenplay.i07_water == "locked", "Water stays locked before the watch gear is borrowed")
	if not _complete(model):
		return
	var view: Dictionary = Childhood.view(model.data)
	_check(view.stage == "i07_water_fetch" and view.title == "I-07 · Der kranke Wachmann", "After borrowing gear, I-07 asks for water first: " + str(view.get("stage")))
	_check(not model.execute("village_childhood_action", {"action_id":"watch_post"}).ok, "The watch post cannot be skipped past the water task")
	var at_water: Dictionary = model.data.duplicate(true)
	_at(model, view.point)
	_check(_action(model, "i07_water_fetch").ok, "Fill the jug at the house")
	_check(model.data.village.childhood.screenplay.i07_water == "carry", "The filled jug is a saved state")
	_check(not _action(model, "i07_water_bring").ok, "Water is only delivered at the gate itself")
	_ok(model.save_game(_path("carry")), "Save while carrying water")
	var resumed = WorldModel.new()
	_ok(resumed.load_game(_path("carry")), "Reload while carrying water")
	_check(_current(resumed) == "i07_water_bring", "Carry state survives the round trip")
	_at(resumed, Childhood.view(resumed.data).point)
	_check(_action(resumed, "i07_water_bring").ok, "Deliver water at the gate")
	_check(_current(resumed) == "watch_post", "After the water, the supervised watch post follows")
	_check(str(Childhood.dialogue(resumed.data, "silvanus").get("text", "")).contains("Mut ist leicht, wenn nichts auf dem Spiel steht."), "Optional visit: Silvanus carries I-07 line 08 at the watch post")
	var after_water: Dictionary = resumed.data.duplicate(true)
	if not _until(resumed, "watch_message"):
		return
	var past_post: Dictionary = resumed.data.duplicate(true)
	# Screenplay v2 saves (written before this round) migrate without retroactive completion.
	_check(_migrated(before_water).i07_water == "locked", "v2 save before the gear: water locked")
	_check(_migrated(at_water).i07_water == "pending", "v2 save standing at the watch post gets the water task")
	_check(_migrated(past_post).i07_water == "legacy", "v2 save past the watch post keeps water as legacy, not as done work")
	var migrated_now := _load(_as_v2(at_water))
	_check(migrated_now.ok and _current_data(migrated_now.state) == "i07_water_fetch", "Migrated v2 save continues with the water task")
	var forged: Dictionary = before_water.duplicate(true)
	forged.village.childhood.screenplay.i07_water = "complete"
	_check(not _load(forged).ok, "Water cannot be marked done before the gear is borrowed")
	var forged_skip: Dictionary = after_water.duplicate(true)
	forged_skip.village.childhood.screenplay.i07_water = "carry"
	forged_skip.village.childhood.completed.append("watch_post")
	_check(not _load(forged_skip).ok, "The watch post cannot be completed while water is still being carried")


func _as_v2(state: Dictionary) -> Dictionary:
	var old: Dictionary = state.duplicate(true)
	var screenplay: Dictionary = old.village.childhood.screenplay
	for key: String in ["i07_water"]:
		screenplay.erase(key)
	screenplay.version = 2
	return old


func _migrated(state: Dictionary) -> Dictionary:
	var result := _load(_as_v2(state))
	_check(result.ok, "v2 save loads: " + str(result.get("message", "")))
	return result.get("state", {}).get("village", {}).get("childhood", {}).get("screenplay", {})


func _load(state: Dictionary) -> Dictionary:
	var path := _path("probe_%d" % checks)
	_write(path, state)
	var model = WorldModel.new()
	var result: Dictionary = model.load_game(path)
	if result.get("ok", false):
		result["state"] = model.data
	return result


func _current_data(data: Dictionary) -> String:
	return str(Childhood.view(data).get("stage", "invalid"))


# Helpers mirror tests/chapter_abilities_test.gd: authoritative points, real commands.
func _complete(model) -> bool:
	var view: Dictionary = Childhood.view(model.data)
	var stage := str(view.get("stage", ""))
	if stage.begins_with("i0") or stage.begins_with("i1"):
		_at(model, view.point)
		if not str(view.get("target_npc", "")).is_empty() and not _meet(model, str(view.target_npc)):
			return false
		var actions: Array = view.get("actions", [])
		if actions.is_empty():
			return false
		return _ok(_action(model, str(actions[0].payload.action_id)), "Screenplay step " + stage)
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
	for _index in Childhood.STEPS.size() + 20:
		if _current(model) == stage:
			return true
		if not _complete(model):
			return false
	_check(false, "Stage reachable: " + stage)
	return false


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
