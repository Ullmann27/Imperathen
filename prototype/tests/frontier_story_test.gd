extends SceneTree
## Exercises the real WorldModel transaction/save path, not a copied chapter simulation.
const Model = preload("res://scripts/domain/world_model.gd")
const Chapter = preload("res://scripts/story/frontier_chapter.gd")
var checks := 0
var failures: Array[String] = []
var directory := "user://frontier_story_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	_test_childhood_and_presence()
	_test_choices_and_exactly_once_rewards()
	_test_actual_work_and_pause_boundary()
	_test_every_vocation_and_cost_path()
	_test_save_migration_and_resume()
	_test_malformed_input_and_forged_saves()
	_test_other_origins_and_terminal_life()
	_cleanup()
	for failure in failures:
		printerr("FRONTIER_FAIL " + failure)
	print("FRONTIER_STORY_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("FRONTIER_STORY_PASS" if failures.is_empty() else "FRONTIER_STORY_FAIL")
	quit(0 if failures.is_empty() else 1)


func _test_childhood_and_presence() -> void:
	var model = Model.new()
	var before := _snapshot(model)
	_check(not model.execute("frontier_talk", {"npc_id": "livia"}).ok and _snapshot(model) == before, "Distant dialogue cannot discover a person")
	for npc_id: String in Chapter.NPCS:
		_move(model, npc_id)
		_check(model.execute("frontier_talk", {"npc_id": npc_id}).ok, "Child can know resident " + npc_id)
		var dialog: Dictionary = model.get_frontier_dialog(npc_id)
		_check(dialog.text.length() > 100 and dialog.choices.is_empty(), "Child has a real peaceful conversation without adult choices: " + npc_id)
	var count: int = model.data.chronicle.size()
	model.execute("frontier_talk", {"npc_id": "titus"})
	_check(model.data.chronicle.size() == count and model.data.frontier.met.size() == 4, "Repeat conversations do not duplicate meetings or fill chronicle")
	_check(not model.get_frontier_objective().active and model.data.player.age == 12, "Optional conversations preserve the original childhood objective")
	_move(model, "livia")
	before = _snapshot(model)
	_check(not model.execute("frontier_choice", {"npc_id": "livia", "choice": "share"}).ok and _snapshot(model) == before, "Child cannot pay for or skip to adult chapter")


func _test_choices_and_exactly_once_rewards() -> void:
	var model = _ready_chapter()
	_check(model.get_frontier_objective().npc_id == "livia", "Completed old chapter points to Livia")
	_move(model, "livia")
	var before := _snapshot(model)
	_check(not model.execute("frontier_choice", {"npc_id": "livia", "choice": "share"}).ok and _snapshot(model) == before, "Choice requires speaking before acting")
	model.execute("frontier_talk", {"npc_id": "livia"})
	var grain: int = model.data.resources.grain
	var trust: int = model.data.companion.trust
	var accepted: Dictionary = model.execute("frontier_choice", {"npc_id": "livia", "choice": "share"}, "share-once")
	_check(accepted.ok and model.data.resources.grain == grain - 2 and model.data.companion.trust == trust + 2, "Share commits its real cost and relationship together")
	before = _snapshot(model)
	_check(model.execute("frontier_choice", {"npc_id": "livia", "choice": "share"}, "share-once") == accepted and _snapshot(model) == before, "Repeated accepted command ID is mutation-free")
	_check(not model.execute("frontier_choice", {"npc_id": "livia", "choice": "reserve"}).ok and _snapshot(model) == before, "Another choice cannot rewrite an earlier scene")
	_choose(model, "cassian", "open")
	var money: int = model.data.resources.denarii
	_choose(model, "titus", "pay")
	_check(model.data.resources.denarii == money - 4 and model.data.frontier.step == 3, "Paid preparation debits exactly four and advances")
	_choose(model, "aulus", "supply")
	_move(model, "titus")
	model.execute("frontier_talk", {"npc_id": "titus"})
	var last: Dictionary = model.execute("frontier_choice", {"npc_id": "titus", "choice": "handover"}, "handover-once")
	_check(last.ok and model.data.resources.denarii == money + 4 and model.data.frontier.completed, "Eight denarii are paid exactly once after paid preparation")
	_check(model.data.frontier.vocation == "supply" and model.data.player.role == "soldier" and not model.data.progress.career_terminal, "Recommendation preserves actual old rank and does not end career")
	before = _snapshot(model)
	_check(not model.execute("frontier_choice", {"npc_id": "titus", "choice": "handover"}).ok and _snapshot(model) == before, "New command cannot claim completed handover again")
	var path := _path("reward")
	_check(model.save_game(path).ok, "Completed chapter saves")
	var loaded = Model.new()
	_check(loaded.load_game(path).ok and loaded.data.frontier == model.data.frontier, "All narrative choices survive reload")
	before = _snapshot(loaded)
	_check(loaded.execute("frontier_choice", {"npc_id": "titus", "choice": "handover"}, "handover-once") == last and _snapshot(loaded) == before, "Reloaded idempotency retains exact accepted answer without payout")
	_check(loaded.get_frontier_dialog("cassian").text.contains("offenen Vermerk") and loaded.get_frontier_dialog("livia").text.contains("zwei Getreide"), "Later residents remember specific choices")


func _test_actual_work_and_pause_boundary() -> void:
	var model = _ready_chapter()
	_choose(model, "livia", "reserve")
	_choose(model, "cassian", "letter")
	_choose(model, "titus", "work")
	var clock: float = model.data.world_seconds
	_check(model.data.frontier.work_seconds == 0.0 and model.data.frontier.step == 2, "Accepting work never completes it instantly")
	var frozen := _snapshot(model)
	model.get_frontier_dialog("titus")
	model.get_frontier_objective()
	_check(_snapshot(model) == frozen, "Dialogue/objective queries never advance paused simulation")
	model.set_player_position(Vector3(3.0, 1.0, 27.01))
	model.advance(5.0)
	_check(model.data.frontier.work_seconds == 0.0, "Outside three metres no wagon work occurs")
	_move(model, "titus")
	model.advance(5.0)
	_check(is_equal_approx(model.data.frontier.work_seconds, 5.0) and model.data.frontier.step == 2, "Only actual elapsed presence supplies work")
	_check(model.get_frontier_dialog("titus").choices.is_empty(), "Cannot switch to paid branch after starting own work")
	var path := _path("work")
	_check(model.save_game(path).ok, "Half-completed wagon work saves")
	var resumed = Model.new()
	_check(resumed.load_game(path).ok and resumed.data.frontier.work_seconds == 5.0, "Reload resumes exact work without a completion grant")
	resumed.advance(6.0)
	_check(resumed.data.frontier.step == 2 and resumed.data.frontier.work_seconds == 11.0, "Eleven seconds is still incomplete")
	resumed.advance(1.0)
	_check(resumed.data.frontier.step == 3 and resumed.data.frontier.work_seconds == 12.0, "Twelfth actual second completes preparation")
	_check(is_equal_approx(resumed.data.world_seconds - clock, 17.0), "Away time belongs to world clock but not to work")
	var history: int = resumed.data.chronicle.size()
	resumed.advance(30.0)
	_check(resumed.data.chronicle.size() == history and resumed.data.frontier.work_seconds == 12.0, "Completed work cannot book a second completion")
	_check(resumed._validate_state(resumed.data).is_empty(), "Completed labour satisfies actual strict domain invariants")


func _test_every_vocation_and_cost_path() -> void:
	for provisions: String in ["share", "reserve"]:
		for report: String in ["open", "letter"]:
			for preparation: String in ["work", "pay"]:
				for vocation: String in ["guard", "supply", "craft"]:
					var model = _ready_chapter()
					var grain: int = model.data.resources.grain
					var money: int = model.data.resources.denarii
					_choose(model, "livia", provisions)
					_choose(model, "cassian", report)
					_choose(model, "titus", preparation)
					if preparation == "work":
						model.advance(12.0)
					_choose(model, "aulus", vocation)
					_choose(model, "titus", "handover")
					_check(model.data.frontier.completed and model.data.frontier.vocation == vocation, "Every offered vocational path reaches its real handover")
					_check(model.data.resources.grain == grain - (2 if provisions == "share" else 0) and model.data.resources.denarii == money + 8 - (4 if preparation == "pay" else 0), "Combined choices preserve exact grain and money conservation")
					_check(model.get_frontier_objective().complete and model.get_frontier_dialog("aulus").text.contains(Chapter.VOCATIONS[vocation]), "Ending and later conversation retain chosen vocation")


func _test_save_migration_and_resume() -> void:
	var model = _ready_chapter()
	_choose(model, "livia", "reserve")
	_choose(model, "cassian", "letter")
	var old: Dictionary = model.data.duplicate(true)
	old.frontier = Chapter.new_state()
	# No narrative choices changed a resource in this branch; remove the new schema field.
	old.erase("frontier")
	old.erase("village")
	old.resources.erase("stone")
	old.schema_version = 3
	var path := _path("legacy_v3")
	_write_save(path, old)
	var original_bytes := FileAccess.get_file_as_string(path)
	var restored = Model.new()
	_check(restored.load_game(path).ok and restored.data.schema_version == Model.SCHEMA_VERSION and restored.data.frontier == Chapter.new_state(), "Real schema3 snapshot gains a fresh optional chapter and current schema")
	_check(restored.data.story.choice == "protect" and restored.data.resources == model.data.resources, "Migration preserves the original chosen branch and resources")
	_check(FileAccess.get_file_as_string(path) == original_bytes, "Migration never rewrites source save bytes on load")
	_check(restored.get_frontier_objective().npc_id == "livia", "Migrated adult save can start from the actual first scene")
	var current := _path("current")
	_check(model.save_game(current).ok, "Midchapter current save succeeds")
	_check(restored.load_game(current).ok and restored.data.frontier.report == "letter" and restored.get_frontier_objective().npc_id == "titus", "Midchapter load restores exact next resident")


func _test_malformed_input_and_forged_saves() -> void:
	var model = _ready_chapter()
	_move(model, "livia")
	var before := _snapshot(model)
	for bad_args in [{}, {"npc_id": 4}, {"npc_id": "missing"}, {"npc_id": "livia", "extra": 1}]:
		_check(not model.execute("frontier_talk", bad_args).ok and _snapshot(model) == before, "Invalid talk arguments do not mutate")
	for bad_args in [{"npc_id": "livia"}, {"npc_id": "livia", "choice": []}, {"npc_id": "livia", "choice": "share", "grain": -2}, {"npc_id": false, "choice": "share"}]:
		_check(not model.execute("frontier_choice", bad_args).ok and _snapshot(model) == before, "Malformed choice cannot change ledger")
	var clean = Model.new()
	for kind: String in ["missing", "type", "extra", "step", "fraction", "met", "duplicate", "child", "money", "work", "work_time", "vocation", "completion", "time", "schema"]:
		var altered: Dictionary = clean.data.duplicate(true)
		match kind:
			"missing": altered.erase("frontier")
			"type": altered.frontier = []
			"extra": altered.frontier["reward"] = 8
			"step": altered.frontier.step = 9
			"fraction": altered.frontier.step = 1.5
			"met": altered.frontier.met = [12]
			"duplicate": altered.frontier.met = ["livia", "livia"]
			"child": altered.frontier.step = 1; altered.frontier.provisions = "reserve"; altered.frontier.met = ["livia"]
			"money": altered.resources.denarii += 8
			"work": altered.frontier.preparation = "pay"
			"work_time": altered.frontier.work_seconds = 1.0
			"vocation": altered.frontier.vocation = "emperor"
			"completion": altered.frontier.completed = true
			"time": altered.frontier.completed_at = 0.0
			"schema": altered.frontier.schema = 2
		var path := _path("invalid_" + kind)
		_write_save(path, altered)
		_check(not model.load_game(path).ok and _snapshot(model) == before, "Rehashed malformed narrative save rejected atomically: " + kind)
	# A current-version save cannot masquerade as legacy while carrying a new field.
	var fake_old: Dictionary = clean.data.duplicate(true)
	fake_old.schema_version = 3
	_write_save(_path("fake_old"), fake_old)
	_check(not model.load_game(_path("fake_old")).ok and _snapshot(model) == before, "Unrecognized mixed-version state is not silently migrated")


func _test_other_origins_and_terminal_life() -> void:
	for origin_id: String in ["germania", "han", "wa", "vistula"]:
		var model = Model.new()
		model.new_game(origin_id)
		_move(model, "livia")
		var before := _snapshot(model)
		_check(model.get_frontier_dialog("livia").is_empty() and not model.get_frontier_objective().active, "Roman story never replaces another origin's identity")
		_check(not model.execute("frontier_talk", {"npc_id": "livia"}).ok and _snapshot(model) == before, "Other origin cannot activate a Roman resident command")
		_check(model._validate_state(model.data).is_empty(), "Untouched alternative origin still validates")
	var dying = _trained()
	dying.execute("start_skirmish")
	dying.set_player_position(Vector3(6.0, 1.0, -10.0))
	for index in 13:
		dying.advance(1.3)
		dying.execute("receive_damage", {"amount": 8})
	var frozen := _snapshot(dying)
	_check(dying.data.progress.career_terminal and not dying.execute("frontier_talk", {"npc_id": "livia"}).ok and _snapshot(dying) == frozen, "A dead protagonist cannot restart life through optional dialogue")


func _trained():
	var model = Model.new()
	model.set_player_position(Vector3(-8.0, 1.0, 2.0))
	for index in 3:
		model.execute("gather", {"node_id": "timber_0"})
	model.set_player_position(Vector3(-3.0, 1.0, 4.0))
	model.execute("choose_companion", {"choice": "help"})
	model.execute("build", {"x": 8.0, "z": 5.0})
	model.set_player_position(Vector3(8.0, 1.0, 5.0))
	model.advance(12.0)
	model.set_player_position(Vector3(0.0, 1.0, -7.0))
	model.execute("train")
	for index in 3:
		model.advance(0.65)
		model.execute("training_hit")
	model.execute("recruit")
	return model


func _ready_chapter():
	var model = _trained()
	model.execute("start_skirmish")
	for enemy in model.data.encounter.enemies.duplicate(true):
		model.set_player_position(Vector3(enemy.x, 1.0, enemy.z))
		for strike in 3:
			model.advance(0.65)
			if model.data.encounter.active:
				model.execute("strike_enemy", {"enemy_id": enemy.id})
	model.execute("choose_story", {"choice": "protect"})
	_check(model.data.progress.chapter_complete and model._validate_state(model.data).is_empty(), "Fixture reaches chapter through actual childhood, training and combat")
	return model


func _move(model, npc_id: String) -> void:
	model.set_player_position(Chapter.npc_position(npc_id))


func _choose(model, npc_id: String, choice: String) -> void:
	_move(model, npc_id)
	var talked: Dictionary = model.execute("frontier_talk", {"npc_id": npc_id})
	var result: Dictionary = model.execute("frontier_choice", {"npc_id": npc_id, "choice": choice})
	_check(talked.ok and result.ok, "Actual choice accepted: %s/%s (%s)" % [npc_id, choice, result.message])


func _snapshot(model) -> String:
	return JSON.stringify(model.data)


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	return directory.path_join(name + ".json")


func _write_save(path: String, state: Dictionary) -> void:
	var payload := JSON.stringify(state)
	var envelope := JSON.stringify({"format": Model.SAVE_FORMAT, "format_version": 1, "payload": payload, "sha256": payload.sha256_text()})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(envelope)
	file.close()


func _cleanup() -> void:
	var folder := DirAccess.open(directory)
	if folder == null:
		return
	for filename in folder.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
