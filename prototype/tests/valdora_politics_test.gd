extends SceneTree
## WorldModel command/save coverage. Position assignments set up each interaction;
## the separate engine route proves that these spots are reachable by walking.

const Model = preload("res://scripts/domain/world_model.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Politics = preload("res://scripts/domain/valdora_politics.gd")
const V5_FIXTURE := "res://tests/fixtures/mission_bridge_data/handoff_i02_correct_v5.json"
var checks := 0
var failures: Array[String] = []
var folder := "user://valdora_politics_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_test_child_report()
	_test_adult_wood_and_audience()
	_test_legacy_migration()
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("VALDORA_POLITICS_%s %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, description: String) -> bool:
	checks += 1
	if not ok:
		failures.append(description)
	return ok


func _set_position(model: Model, point: Vector2) -> void:
	model.set_player_position(Vector3(point.x, 1.0, point.y))


func _meet(model: Model) -> void:
	_set_position(model, Life.actor_position(model.data, Politics.OFFICIAL_ID))
	var result := model.execute("village_talk", {"npc_id":Politics.OFFICIAL_ID,"choice":"meet"})
	_check(result.ok, "The existing steward is met through his actual dialogue: " + result.message)


func _test_child_report() -> void:
	var model := Model.new()
	model.new_game("italia", true, true, false, true)
	_check(model.data.player.age == 12 and model.data.resources.denarii == 0, "Campaign prologue starts at twelve with no money")
	_meet(model)
	var before := JSON.stringify(model.data)
	_check(not model.politics_view().survey_pending and not model.execute("politics_help", {"route":"wood"}).ok and JSON.stringify(model.data) == before, "The civic errand never displaces I-01")
	var path := folder.path_join("after_morning.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(V5_FIXTURE))
	file.close()
	var loaded := model.load_game(path)
	if not _check(loaded.ok, "Load a recorded campaign from after breakfast: " + loaded.message):
		return
	_meet(model)
	_check(model.politics_view().survey_pending and model.politics_view().report_point == Politics.SURVEY_POINT, "The marker can appear while out of interaction range")
	before = JSON.stringify(model.data)
	_check(not model.execute("politics_survey").ok and JSON.stringify(model.data) == before, "A survey from the steward's doorstep fails without state changes")
	_check(not model.execute("politics_help", {"route":"road"}).ok, "A report requires the actual visit")
	_check(not model.execute("politics_help", {"route":"official_rank"}).ok, "A caller cannot invent a political outcome")
	_set_position(model, Politics.SURVEY_POINT)
	_check(model.execute("politics_survey", {}, "inspect-south").ok, "Visit the physical survey point by valid project coordinates")
	_check(not model.politics_view().survey_pending, "The completed survey has no lingering marker")
	before = JSON.stringify(model.data)
	_check(not model.execute("politics_help", {"route":"road"}).ok and JSON.stringify(model.data) == before, "The report can only be delivered to the steward")
	_set_position(model, Life.actor_position(model.data, Politics.OFFICIAL_ID))
	var funds: Dictionary = model.data.resources.duplicate()
	var stamp: Dictionary = model.data.calendar.clock.duplicate()
	var report := model.execute("politics_help", {"route":"road"}, "tell-decimus")
	_check(report.ok, "A child can carry out age-appropriate help: " + report.message)
	_check(model.data.resources == funds, "The report spends no goods or money")
	var view := model.politics_view()
	_check(view.recommendation.get("route") == "road" and view.relationship.respect == 4 and view.relationship.actor_id == "vil:decimus", "The visit and report create personal respect and a recommendation")
	var events: Array = view.events
	if _check(events.size() == 2, "Exactly one survey and one report are recorded"):
		_check(events[0].id == Politics.SURVEY and events[1].id == Politics.ROAD_HELP, "Report events are chronological")
		_check(events[1].jdn == stamp.jdn and events[1].second == stamp.second, "Report is dated on the authoritative clock")
	_check(str(model.data.chronicle.back().text).contains("58 v. Chr."), "The existing chronicle presents the campaign date")
	before = JSON.stringify(model.data)
	_check(model.execute("politics_help", {"route":"road"}, "tell-decimus") == report, "The same command ID returns its recorded result")
	_check(not model.execute("politics_help", {"route":"wood"}).ok and not model.execute("politics_audience").ok and JSON.stringify(model.data) == before, "Second reward and child's formal audience both fail atomically")
	path = folder.path_join("report.json")
	_check(model.save_game(path).ok, "Save the recorded recommendation")
	var restored := Model.new()
	_check(restored.load_game(path).ok and restored.politics_view() == view, "Load the exact recommendation and dated events")


func _test_adult_wood_and_audience() -> void:
	var model := Model.new()
	model.new_game("italia", true)
	_check(model.pass_calendar_days(2195, "Zeit für die Erwachsenen-Prüflaufbahn", "wait").ok and model.data.player.age == 18, "Use an adult fixture through the ordinary world calendar")
	_meet(model)
	var before := JSON.stringify(model.data)
	_check(not model.execute("politics_audience").ok and not model.execute("politics_help", {"route":"wood"}).ok and JSON.stringify(model.data) == before, "An adult still needs a personal recommendation and a real timber reserve")
	model.set_player_position(Vector3(-8.0, 1.0, 2.0))
	_check(model.execute("gather", {"node_id":"timber_0"}).ok, "Collect wood from an existing resource node")
	_set_position(model, Life.actor_position(model.data, Politics.OFFICIAL_ID))
	var initial_wood: int = model.data.resources.wood
	var initial_ledger: int = model.data.village.social.ledger.wood
	_check(model.execute("politics_help", {"route":"wood"}).ok, "Give actual wood to the shared project")
	_check(model.data.resources.wood == initial_wood - 4 and model.data.village.social.ledger.wood == initial_ledger - 4, "Village wood balance and reserves agree")
	var view := model.politics_view()
	_check(view.events.size() == 1 and view.recommendation.get("route") == "wood" and view.relationship.respect == 2, "A different route creates its own support record and relation")
	_check(not view.survey_pending, "A decided donation makes the survey optional pathway irrelevant")
	_check(model.execute("politics_audience").ok and model.politics_view().recommendation.get("audience", false), "An adult with local recommendation receives an audience")
	_check(model.data.progress.stage == "prologue" and model.data.frontier.vocation.is_empty(), "A civic audience never enrolls the player in a career")
	before = JSON.stringify(model.data)
	_check(not model.execute("politics_audience").ok and JSON.stringify(model.data) == before, "An audience cannot be awarded twice")
	var skewed: Dictionary = model.data.duplicate(true)
	skewed.world_state.politics.events[1].jdn += 1
	_check(not model._validate_state(skewed).is_empty(), "Future political events are rejected on load")
	skewed = model.data.duplicate(true)
	skewed.world_state.politics.events[1].id = Politics.WOOD_HELP
	_check(not model._validate_state(skewed).is_empty(), "Duplicated support event is rejected on load")


func _test_legacy_migration() -> void:
	var model := Model.new()
	model.new_game("italia", true, true)
	var old: Dictionary = model.data.duplicate(true)
	old.world_state.version = 1
	old.world_state.erase("politics")
	var path := folder.path_join("legacy.json")
	var payload := JSON.stringify(old, "", true, true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format":Model.SAVE_FORMAT,"format_version":1,"payload":payload,"sha256":payload.sha256_text()}))
	file.close()
	var restored := Model.new()
	var result := restored.load_game(path)
	_check(result.ok, "A v6 save with the original world-state block migrates: " + result.message)
	if result.ok:
		_check(restored.data.world_state.version == 2 and restored.politics_view().events.is_empty(), "Migration begins with no invented introductions or favors")
		var current_path := folder.path_join("current.json")
		var current := Model.new()
		_check(model.save_game(current_path).ok and current.load_game(current_path).ok, "Read the same world's v2 control save")
		_check(restored.data == current.data, "Migration produces the same time, assets and people as an ordinary reload")
