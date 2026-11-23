extends SceneTree
## Independent integration of money, real story wages, migration and save envelopes.
## Fixture teleports exercise domain routes; this is not a timed player walkthrough.

const World = preload("res://scripts/domain/world_model.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Trade = preload("res://scripts/domain/village_trade.gd")
var checks := 0
var failures: Array[String] = []
var paths: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model := World.new()
	model.new_game("italia", true, true)
	_check(model.data.village.childhood.enabled, "explicit new childhood uses the integrated model")
	var money_before := _wallet(model.data)
	var grain_before := int(model.data.resources.grain)
	_to_cassia(model)
	var args := {"resource":"grain", "quantity":1, "quote_revision":0}
	var purchase: Dictionary = model.execute("village_trade_buy", args, "integrated-grain-0")
	_check(purchase.ok, "whole-model market transaction: " + purchase.message)
	_check(_wallet(model.data) == money_before - 3 and model.data.resources.grain == grain_before + 1, "actual shared world goods and small coins change together")
	var after_purchase := JSON.stringify(model.data)
	var duplicate: Dictionary = model.execute("village_trade_buy", args, "integrated-grain-0")
	_check(duplicate == purchase and JSON.stringify(model.data) == after_purchase, "world command receipt returns prior result without another payment")
	var save_path := _path("mid-market")
	_check(model.save_game(save_path).ok, "actual save envelope accepts exact new market ledger")
	var restored := World.new()
	var loaded: Dictionary = restored.load_game(save_path)
	_check(loaded.ok, "load actual mid-market save: " + loaded.message)
	_check(restored.data.village.trade == model.data.village.trade and restored.data.resources == model.data.resources, "reload preserves every coin and item counter")
	_check(typeof(restored.data.village.trade.change_asses) == TYPE_INT, "coin remainder restored as a real integer")
	var after_load := JSON.stringify(restored.data)
	_check(restored.execute("village_trade_buy", args, "integrated-grain-0") == purchase and JSON.stringify(restored.data) == after_load, "old command ID remains idempotent across restart")
	_check(not restored.execute("village_trade_buy", args).ok and JSON.stringify(restored.data) == after_load, "consumed quote without command ID is also blocked after restart")
	model = restored
	var change_before := int(model.data.village.trade.change_asses)
	var wage_before := _wallet(model.data)
	var route := ["promise","deliver","join","inspect","return","tell","sleep","ask","help","take","careful"]
	for choice: String in route:
		if not _choose(model, choice):
			break
	_check(model.data.village.childhood.scene_id == "smith_account", "actual authored work reaches the once-paid smith receipt")
	_check(_wallet(model.data) == wage_before + 16, "the real one-Denar story wage is added exactly once")
	_check(int(model.data.village.trade.change_asses) == change_before, "story wage does not discard market small change")
	_check(int(model.data.village.trade.cash_delta_asses) == -3, "story wage is not falsely booked against Cassia's till")
	var wage_state := JSON.stringify(model.data)
	_check(not model.execute("childhood_choose", {"scene_id":"smith_work", "choice":"careful"}).ok and JSON.stringify(model.data) == wage_state, "completed work cannot be resubmitted for duplicate pay")
	var before_seconds := float(model.data.world_seconds)
	model.advance(5.0)
	_check(is_equal_approx(float(model.data.world_seconds), before_seconds + 5.0) and int(model.data.village.trade.change_asses) == change_before, "real economy time preserves independent coin remainder (seconds=%s, change=%s/%s)" % [model.data.world_seconds, model.data.village.trade.change_asses, change_before])
	var wage_path := _path("mid-story")
	_check(model.save_game(wage_path).ok, "world-wide resource conservation still permits save after wage and economy tick")
	var wage_loaded := World.new()
	_check(wage_loaded.load_game(wage_path).ok, "mid-work account survives full save validation")
	_check(wage_loaded.data.resources == model.data.resources and wage_loaded.data.village.childhood.scene_id == "smith_account", "restart retains money and the exact authored scene")
	_to_cassia(wage_loaded)
	var quote := int(wage_loaded.data.village.trade.revision)
	_check(wage_loaded.execute("village_trade_sell", {"resource":"wood", "quantity":1, "quote_revision":quote}).ok, "post-restart trade coexists with story resource ledger")
	_check(Trade.validate(wage_loaded.data).is_empty(), "conservation holds after integrated buy, wage and sale")
	_test_old_save()
	for path: String in paths:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	for failure: String in failures:
		push_error(failure)
	print(JSON.stringify({"suite":"village_trade_model", "checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)


func _test_old_save() -> void:
	var legacy := World.new()
	legacy.new_game("italia", true)
	var expected_resources: Dictionary = legacy.data.resources.duplicate(true)
	var expected_people: Array = legacy.data.village.economy.people.duplicate(true)
	var state: Dictionary = legacy.data.duplicate(true)
	state.schema_version = 5
	state.village.erase("childhood")
	state.village.erase("trade")
	var payload := JSON.stringify(state, "", true, true)
	var envelope := JSON.stringify({"format":World.SAVE_FORMAT, "format_version":1, "payload":payload, "sha256":payload.sha256_text()})
	var path := _path("schema5")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(envelope)
	file.close()
	var loaded := World.new()
	var result: Dictionary = loaded.load_game(path)
	_check(result.ok, "a real schema-five envelope migrates: " + result.message)
	_check(loaded.data.schema_version == 6 and not loaded.data.village.childhood.enabled, "legacy life is not forced back into childhood")
	_check(loaded.data.resources == expected_resources and loaded.data.village.economy.people == expected_people, "migration preserves old money, goods and real resident identities")
	_check(loaded.data.village.trade.change_asses == 0 and loaded.data.village.trade.ledger.denarii == 0, "migration creates no spendable player money")
	_check(FileAccess.get_file_as_string(path) == envelope, "loading a legacy save does not rewrite its original bytes")
	_to_cassia(loaded)
	_check(loaded.execute("village_trade_buy", {"resource":"grain", "quantity":1, "quote_revision":0}).ok, "migrated village can trade through the same actual command route")
	_check(loaded.save_game(_path("migrated-trade")).ok, "migration followed by change-making passes the new saved balance")


func _choose(model: RefCounted, choice: String) -> bool:
	var objective: Dictionary = model.get_childhood_objective()
	if not objective.has("position"):
		_check(false, "story objective missing before " + choice)
		return false
	model.set_player_position(Vector3(float(objective.position[0]), 1.0, float(objective.position[1])))
	var scene_id := str(model.data.village.childhood.scene_id)
	var result: Dictionary = model.execute("childhood_choose", {"scene_id":scene_id, "choice":choice})
	_check(result.ok, "actual scene " + scene_id + "/" + choice + ": " + result.message)
	return result.ok


func _to_cassia(model: RefCounted) -> void:
	var point: Vector2 = Life.actor_position(model.data, "cassia")
	model.set_player_position(Vector3(point.x, 1.0, point.y))


func _wallet(data: Dictionary) -> int:
	return int(data.resources.denarii) * 16 + int(data.village.trade.change_asses)


func _path(label: String) -> String:
	var path := "user://chat-b-trade-%s-%d.json" % [label, Time.get_ticks_usec()]
	paths.append(path)
	return path


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
