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
	_test_frame_budget()
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


## The campaign starts on 1 May 58 BC; the tribal year started on 1 March.
## The tribal world therefore opens eight weeks behind the one world clock
## (61 days) and catches up in frame budgets. Tests of later time start from
## the caught-up world.
const OPENING_WEEKS := 8
const LONG_WEEKS := 34


func _new_childhood() -> Variant:
	var model = WorldModel.new()
	model.new_game("italia", true, true)
	return model


func _childhood() -> Variant:
	var model = _new_childhood()
	model.finish_tribes()
	return model


func _test_new_games() -> void:
	var model = _new_childhood()
	_check(model.data.schema_version == 6 and model.data.tribes.scenario == "bc58_rhine", "A new 58 BC childhood game carries the Rhine roster")
	_check(model._validate_state(model.data).is_empty(), "The new world validates: " + model._validate_state(model.data))
	_check(int(model.data.tribes.tick) == 0 and Tribes.calendar(model.data.tribes).year == -58, "The tribal calendar starts in spring 58 BC")
	_check(model.tribes_pending_weeks() == OPENING_WEEKS and Tribes.world_calendar_day(model.data) == 61, "On 1 May 58 BC the tribal year is 61 days old: eight weeks wait for the clock")
	model.finish_tribes()
	_check(int(model.data.tribes.tick) == OPENING_WEEKS and Tribes.calendar(model.data.tribes).year == -58 and int(model.data.tribes.extra_days) == 0, "The opening weeks are caught up; the tribal world counts no days of its own")
	var legacy = WorldModel.new()
	legacy.new_game("germania")
	_check(legacy.data.tribes.scenario == Tribes.NO_SCENARIO and legacy._validate_state(legacy.data).is_empty(), "A Trajan-era career gets no invented roster")


func _test_calendar_and_round_trip() -> void:
	var model = _childhood()
	var before: int = int(model.data.revision)
	model.advance(1.0)
	_check(int(model.data.tribes.tick) == OPENING_WEEKS, "One second of village time is no tribal week")
	var passed: Dictionary = model.pass_calendar_days(70, "Reise")
	_check(passed.ok and int(model.data.tribes.tick) == OPENING_WEEKS and model.tribes_pending_weeks() == 10 and int(model.data.revision) > before, "Seventy reported days queue ten weeks without running them in this frame: %s" % str(passed.message))
	var frames: int = model.finish_tribes()
	_check(int(model.data.tribes.tick) == OPENING_WEEKS + 10 and model.tribes_pending_weeks() == 0 and frames >= 10, "The ten weeks run over %d frame budgets" % frames)
	_check(Tribes.day(model.data.tribes) <= Tribes.world_calendar_day(model.data), "The tribal world never runs ahead of the shared calendar")
	var path := directory.path_join("round_trip.json")
	var saved: Dictionary = model.save_game(path)
	_check(saved.ok, "Save with tribes: " + str(saved.message))
	var loaded = WorldModel.new()
	var result: Dictionary = loaded.load_game(path)
	_check(result.ok, "Load with tribes: " + str(result.message))
	_check(_json(loaded.data.tribes) == _json(model.data.tribes), "Tribal state survives the atomic save exactly")
	_check(Tribes.is_validated(loaded.data.tribes), "The loaded tribal state needs no second full validation in its first frame")
	model.pass_calendar_days(35)
	loaded.pass_calendar_days(35)
	model.finish_tribes()
	loaded.finish_tribes()
	_check(int(model.data.tribes.tick) == OPENING_WEEKS + 15 and _json(loaded.data.tribes) == _json(model.data.tribes), "Saved and unsaved worlds continue identically")
	var rejected: Dictionary = model.pass_calendar_days(0)
	_check(not rejected.ok and int(model.data.tribes.tick) == OPENING_WEEKS + 15, "An empty time span is rejected")


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
	model.finish_tribes()
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
	_check(result.ok and result.recovered_backup and int(loaded.data.tribes.groups.ubii_rhine.stock.wealth) == int(model.data.tribes.groups.ubii_rhine.stock.wealth), "A save with unbooked goods falls back to the verified backup: " + str(result))


func _test_frame_budget() -> void:
	# One year of reported travel is caught up in frame budgets, never in one frame.
	var model = _childhood()
	var reference: Dictionary = Tribes.copy_state(model.data.tribes)
	# The childhood chapter allows no skipped life year, so the longest span
	# that stays in 58 BC is used: 238 days, 34 weeks.
	var long_days := LONG_WEEKS * Tribes.TICK_DAYS
	_check(not model.pass_calendar_days(364, "Reise").ok and model.tribes_pending_weeks() == 0, "A span that would skip a childhood year is rejected as a whole")
	_check(model.pass_calendar_days(long_days, "Reise").ok and model.tribes_pending_weeks() == LONG_WEEKS, "%d days of travel queue %d weeks" % [long_days, LONG_WEEKS])
	var budget: int = WorldModel.TRIBE_UNITS_PER_FRAME
	var frames := 0
	var over := 0
	var jumps := 0
	var commits := 0
	var times := []
	var last_tick := int(model.data.tribes.tick)
	while model.tribes_pending_weeks() > 0 and frames < 20000:
		var started := Time.get_ticks_usec()
		var report: Dictionary = model.pump_tribes()
		times.append(Time.get_ticks_usec() - started)
		frames += 1
		over += int(int(report.units) > budget)
		var now := int(model.data.tribes.tick)
		jumps += int(now - last_tick > 1 or (now != last_tick) != bool(report.committed))
		commits += int(report.committed)
		last_tick = now
	_check(model.tribes_pending_weeks() == 0 and commits == LONG_WEEKS, "All %d weeks were committed (%d frames)" % [LONG_WEEKS, frames])
	_check(over == 0, "No frame spent more than %d work units" % budget)
	_check(jumps == 0, "The committed world advances one finished week at a time, only on commit")
	_check(frames >= LONG_WEEKS * 4, "A week needs several frames instead of one spike (%d frames for %d weeks)" % [frames, LONG_WEEKS])
	Tribes.advance_ticks(reference, LONG_WEEKS)
	_check(_json(reference) == _json(model.data.tribes), "Budgeted weeks equal direct weeks bit for bit")
	times.sort()
	print("TRIBAL_FRAME desktop (development machine, loaded, relative only): p50 %d us, p95 %d us, p99 %d us, max %d us over %d frames of %d units" % [times[times.size() / 2], times[floori(times.size() * 0.95)], times[floori(times.size() * 0.99)], times.back(), frames, budget])
	# The world's own frame clock spends the same budget through advance().
	var world = _childhood()
	world.pass_calendar_days(28)
	var calls := 0
	var advance_over := 0
	while world.tribes_pending_weeks() > 0 and calls < 5000:
		world.advance(0.1)
		calls += 1
		advance_over += int(int(world.tribe_units_last_pump) > budget)
	_check(world.tribes_pending_weeks() == 0 and advance_over == 0, "advance() catches up four weeks within the frame budget (%d calls)" % calls)
	# A save in the middle of a week keeps the last committed week only.
	var first = _childhood()
	first.pass_calendar_days(21)
	for i in 5:
		first.pump_tribes()
	var mid_tick := int(first.data.tribes.tick)
	_check(not first._tribe_job.is_empty() and str(first._tribe_job.stage) in ["copy", "week", "check"], "The save happens while a week is in progress (%s)" % str(first._tribe_job.get("stage", "none")))
	var path := directory.path_join("mid_week.json")
	_check(first.save_game(path).ok, "Save in the middle of a week")
	var second = WorldModel.new()
	_check(second.load_game(path).ok and int(second.data.tribes.tick) == mid_tick, "The loaded world has the last committed week")
	first.finish_tribes()
	second.finish_tribes()
	_check(int(first.data.tribes.tick) == OPENING_WEEKS + 3 and _json(first.data.tribes) == _json(second.data.tribes), "Saved mid-week and uninterrupted runs reach the same week bit for bit (D-046)")
	# A change of the committed world restarts the week in progress.
	var restart = _childhood()
	restart.pass_calendar_days(14)
	restart.pump_tribes()
	restart.pass_calendar_days(7)
	restart.finish_tribes()
	_check(int(restart.data.tribes.tick) == OPENING_WEEKS + 3 and restart.tribe_job_error.is_empty(), "A job whose base changed starts again and reaches the calendar")

