extends SceneTree
## The tribal world inside the real WorldModel: shared calendar, atomic save,
## schema v5 -> v6 migration and strict validation of the saved state.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Tribes = preload("res://scripts/domain/tribal_world.gd")
const FIXTURES := "res://tests/fixtures/mission_bridge_data/"
var checks := 0
var failures: Array[String] = []
var directory := "user://tribal_save_test"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_test_new_games()
	_test_calendar_and_round_trip()
	_test_v5_migration()
	_test_legacy_migration()
	_test_rejections()
	if failures.is_empty():
		print("TRIBAL_SAVE_PASS %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			print("FAILED: ", failure)
		print("TRIBAL_SAVE_FAIL %d failures / %d checks" % [failures.size(), checks])
		quit(1)


func _check(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failures.append(description)
	return condition


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _childhood() -> Variant:
	var model = WorldModel.new()
	model.new_game("italia", true, true)
	return model


func _test_new_games() -> void:
	var model = _childhood()
	_check(model.data.schema_version == 6 and model.data.tribes.scenario == "bc58_rhine", "A new 58 BC childhood game carries the Rhine roster")
	_check(model._validate_state(model.data).is_empty(), "The new world validates: " + model._validate_state(model.data))
	_check(int(model.data.tribes.tick) == 0 and Tribes.calendar(model.data.tribes).year == -58, "The tribal calendar starts in spring 58 BC")
	var legacy = WorldModel.new()
	legacy.new_game("germania")
	_check(legacy.data.tribes.scenario == Tribes.NO_SCENARIO and legacy._validate_state(legacy.data).is_empty(), "A Trajan-era career gets no invented roster")


func _test_calendar_and_round_trip() -> void:
	var model = _childhood()
	var before: int = int(model.data.revision)
	model.advance(1.0)
	_check(int(model.data.tribes.tick) == 0, "One second of village time is no tribal week")
	var passed: Dictionary = model.pass_calendar_days(70, "Reise")
	_check(passed.ok and int(model.data.tribes.tick) == 10 and int(model.data.revision) > before, "Seventy reported days run ten weekly ticks: %s" % str(passed.message))
	_check(Tribes.day(model.data.tribes) <= Tribes.world_calendar_day(model.data), "The tribal world never runs ahead of the shared calendar")
	var path := directory.path_join("round_trip.json")
	var saved: Dictionary = model.save_game(path)
	_check(saved.ok, "Save with tribes: " + str(saved.message))
	var loaded = WorldModel.new()
	var result: Dictionary = loaded.load_game(path)
	_check(result.ok, "Load with tribes: " + str(result.message))
	_check(_json(loaded.data.tribes) == _json(model.data.tribes), "Tribal state survives the atomic save exactly")
	model.pass_calendar_days(35)
	loaded.pass_calendar_days(35)
	_check(int(model.data.tribes.tick) == 15 and _json(loaded.data.tribes) == _json(model.data.tribes), "Saved and unsaved worlds continue identically")
	var rejected: Dictionary = model.pass_calendar_days(0)
	_check(not rejected.ok and int(model.data.tribes.tick) == 15, "An empty time span is rejected")


func _test_v5_migration() -> void:
	var source := FIXTURES + "handoff_i10_choice_v5.json"
	var text := FileAccess.get_file_as_string(source)
	_check(not text.is_empty(), "Recorded v5 childhood save exists")
	var envelope: Dictionary = JSON.parse_string(text)
	var payload: Dictionary = JSON.parse_string(envelope.payload)
	_check(int(payload.schema_version) == 5 and not payload.has("tribes"), "Fixture is a genuine v5 save without tribes")
	var path := directory.path_join("v5.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var model = WorldModel.new()
	var result: Dictionary = model.load_game(path)
	_check(result.ok, "v5 save loads: " + str(result.message))
	if not result.ok:
		return
	_check(model.data.schema_version == 6 and model.data.tribes.scenario == "bc58_rhine" and int(model.data.tribes.tick) == 0, "v5 childhood save gains the opening Rhine roster")
	# The loader restores schema integers that JSON.parse reads as floats.
	_check(_json(JSON.parse_string(_json(model.data.village.childhood))) == _json(JSON.parse_string(_json(payload.village.childhood))), "Migration leaves the childhood story untouched")
	var target := floori(Tribes.world_calendar_day(model.data) / float(Tribes.TICK_DAYS))
	for i in 8:
		model.advance(0.1)
	_check(int(model.data.tribes.tick) == target, "Elapsed calendar weeks are caught up after load (%d of %d)" % [int(model.data.tribes.tick), target])
	var again := directory.path_join("v6.json")
	_check(model.save_game(again).ok and WorldModel.new().load_game(again).ok, "Migrated world saves and loads as v6")


func _test_legacy_migration() -> void:
	var model = WorldModel.new()
	model.new_game("italia")
	var old: Dictionary = model.data.duplicate(true)
	old.erase("tribes")
	old.erase("village")
	old.schema_version = 4
	var payload := JSON.stringify(old, "", true, true)
	var envelope := JSON.stringify({"format": WorldModel.SAVE_FORMAT, "format_version": 1, "payload": payload, "sha256": payload.sha256_text()})
	var path := directory.path_join("v4.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(envelope)
	file.close()
	var loaded = WorldModel.new()
	var result: Dictionary = loaded.load_game(path)
	_check(result.ok and loaded.data.schema_version == 6 and loaded.data.tribes.scenario == Tribes.NO_SCENARIO, "v4 career migrates through v5 to v6 without a roster: " + str(result.message))


func _test_rejections() -> void:
	var model = _childhood()
	model.pass_calendar_days(14)
	var ahead: Dictionary = model.data.duplicate(true)
	ahead.tribes.tick = int(ahead.tribes.tick) + 100
	_check(not model._validate_state(ahead).is_empty(), "A tribal world ahead of the calendar is rejected")
	var cheat: Dictionary = model.data.duplicate(true)
	cheat.tribes.groups.ubii_rhine.stock.wealth = int(cheat.tribes.groups.ubii_rhine.stock.wealth) + 50
	_check(model._validate_state(cheat).contains("Ledgerbilanz"), "Goods without a booking are rejected inside the world contract")
	var path := directory.path_join("tampered.json")
	_check(model.save_game(path).ok, "Valid save written")
	var payload := JSON.stringify(cheat, "", true, true)
	var envelope := JSON.stringify({"format": WorldModel.SAVE_FORMAT, "format_version": 1, "payload": payload, "sha256": payload.sha256_text()})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(envelope)
	file.close()
	var loaded = WorldModel.new()
	var result: Dictionary = loaded.load_game(path)
	_check(result.ok and result.recovered_backup and int(loaded.data.tribes.groups.ubii_rhine.stock.wealth) == int(model.data.tribes.groups.ubii_rhine.stock.wealth), "A save with unbooked goods falls back to the verified backup")
