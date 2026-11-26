extends SceneTree
## I-01 „Die drei Becher“ domain contract through the real WorldModel.
## Positions are explicit fixture placements at authored points; this test
## proves state, consequences and persistence, not a measured walk.
## Handbook mapping: T01 (no weapon, no money cheat), the five I-01 cases from
## HB S. 13 (ohne Waffen, Film abgebrochen [domain half], NPC beim Brunnen
## abwesend, Hilfe abgelehnt, Save am Tisch) and the v3 -> v4 save migration.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")
var checks := 0
var failures: Array[String] = []
var directory := "user://i01_slice_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_test_fresh_start_t01()
	_test_help_path()
	_test_refused_help()
	_test_yard_contact_and_absent_marcus()
	_test_save_at_table()
	_test_replay_and_duplicates()
	_test_migration_v3_to_v4()
	_test_regular_start_money()
	_test_invented_success_text()
	print("I01_SLICE_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("I01_SLICE_PASS" if failures.is_empty() else "I01_SLICE_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition


func _new(regular := true):
	var model = WorldModel.new()
	model.new_game("italia", true, true, false, regular)
	return model


func _at(model, point: Vector2) -> void:
	model.set_player_position(Vector3(point.x, 1.35, point.y))


func _act(model, id: String, command_id := "") -> Dictionary:
	return model.execute("village_childhood_action", {"action_id":id}, command_id)


func _stage(model) -> String:
	return str(Childhood.view(model.data).get("stage", ""))


func _sp(model) -> Dictionary:
	return model.data.village.childhood.screenplay


func _trust(model, id: String) -> int:
	return int(model.data.village.childhood.relationships[id].trust)


func _path(name: String) -> String:
	return directory.path_join(name + ".json")


func _test_fresh_start_t01() -> void:
	var model = _new()
	var data: Dictionary = model.data
	_check(model._validate_state(data).is_empty(), "Fresh regular I-01 world validates: " + model._validate_state(data))
	_check(_stage(model) == "i01_choice", "A new life starts with the I-01 choice beat, not with an errand")
	_check(_sp(model).version == 4 and _sp(model).i01 == "pending" and _sp(model).i01_events.is_empty(), "Screenplay v4 starts the morning with an empty event ledger")
	_check(I01.cups(data) == {"julia":"shelf", "silvanus":"shelf", "player":"shelf"}, "All three cups start on the real shelf")
	var start := Vector2(float(data.player.position[0]), float(data.player.position[2]))
	_check(start.distance_to(I01.POINTS.home_bed) < 0.05, "The boy starts beside his actual bed")
	_check(Life.actor_position(data, "julia") == I01.POINTS.julia_table and Life.actor_position(data, "silvanus") == I01.POINTS.silvanus_table, "Julia and Silvanus are at the breakfast table during the open morning")
	# T01: no weapon, no armour item, no service gear, no money cheat.
	_check(not Combat.service_gear(data) and data.village.childhood.gear == "none" and data.village.childhood.carried.is_empty(), "T01: the child carries no weapon, loaned gear or item")
	_check(int(data.resources.denarii) == 0, "T01: a regular new life starts without own money")
	_check(int(data.player.age) == 12 and data.player.role == "child", "T01: the protagonist is a twelve-year-old child")
	var view: Dictionary = Childhood.view(data)
	_check(not str(view.hud_title).contains("I-01") and str(view.hud_title).contains("Familienhaus"), "HUD heading names occasion and place, not the mission ID: " + str(view.hud_title))
	_check(bool(view.in_first_mission), "The view flags the first mission for the reduced child HUD")
	var choices: Array = Childhood.dialogue(data, "julia").get("choices", [])
	var labels: Array = choices.map(func(c): return c.label)
	_check(labels == ["Mit Julia reden", "Beim Tischdecken helfen", "Erst in den Hof gehen"], "Julia offers talk, help and yard in the real dialogue: " + str(labels))
	_check(choices.all(func(c): return c.enabled), "The choice is reachable from the bed without walking")


func _test_help_path() -> void:
	var model = _new()
	var julia_before := _trust(model, "julia")
	var silvanus_before := _trust(model, "silvanus")
	_check(not _act(model, "i01_take_cups").ok, "Cups cannot be taken before the choice")
	_check(_act(model, "i01_help").ok, "Help choice commits")
	_check(_trust(model, "julia") == julia_before, "Choosing help alone grants no trust")
	_check(_stage(model) == "i01_take_cups", "Help leads to the real shelf")
	_check(not _act(model, "i01_take_cups").ok, "Cups cannot be taken from the bed")
	_at(model, I01.POINTS.home_shelf + Vector2(0.7, 0.0))
	_check(_act(model, "i01_take_cups").ok and I01.cups(model.data).values() == ["hand", "hand", "hand"], "All three cups are carried from the shelf")
	_check(Childhood.view(model.data).carried.has("Drei Becher vom Regal"), "Carried cups appear in the inventory view")
	_at(model, I01.POINTS.well)
	_check(not _act(model, "i01_well").ok, "Cups in hand block the jug at the well")
	_at(model, I01.POINTS.player_table)
	for owner: String in ["julia", "silvanus", "player"]:
		_check(_act(model, "i01_place_" + owner).ok, "Cup placed: " + owner)
	_check(_sp(model).i01_table_by == "player" and _trust(model, "julia") == julia_before + 1, "Actually set table records help and one trust")
	_check(_stage(model) == "i01_well", "Next objective is the well in the yard")
	_at(model, I01.POINTS.well + Vector2(1.6, 0.0))
	_check(_act(model, "i01_well").ok and _sp(model).i01_water == "jug", "Water fetched at the real well")
	_check(not _act(model, "i01_pour").ok, "Pouring needs the table")
	_at(model, I01.POINTS.player_table)
	_check(_act(model, "i01_pour").ok, "Water poured at the table")
	_check(_trust(model, "julia") == julia_before + 2 and _trust(model, "silvanus") == silvanus_before + 1 and model.data.village.childhood.relationships.julia.helped, "Water help adds the authored consequence once")
	_check(_stage(model) == "i01_meal" and _act(model, "i01_meal").ok, "Breakfast starts at the table")
	_check(I01.julia_reaction_id(model.data) == "I01_B_JULIA_FULL", "Julia's VID-B reaction follows actual full help")
	_check(not _act(model, "i01_topic_contact").ok, "No contact topic without an actual encounter")
	_check(_act(model, "i01_topic_workshop").ok and _sp(model).i01 == "complete", "Table talk completes the morning")
	_check(_stage(model) == "mother_morning" and model.data.village.childhood.completed.is_empty(), "The established family step follows without being completed")
	_check(Life.actor_position(model.data, "julia") == Childhood.POINTS.mother, "Julia returns to the house front after breakfast")
	_check(I01.presentation(model.data).cups.values() == ["table", "table", "table"], "Cups stay where they were placed")
	var events: Array = _sp(model).i01_events
	_check(events.size() == 10 and events.has("I-01.topic.workshop") and events.has("I-01.cups.table"), "Event ledger holds each decision exactly once: " + str(events))
	_check(model.data.village.history.events.any(func(e): return e.kind == "I-01.meal"), "Chronicle event carries the ledger event id")
	# Delayed hook: the workshop question returns in I-04.
	var hook := I01.hook_lines(model.data, "woodcutter_request")
	_check(hook.size() == 1 and hook[0].contains("Werkstatt"), "Workshop topic creates the authored I-04 hook")
	_check(model._validate_state(model.data).is_empty(), "Completed help path validates")


func _test_refused_help() -> void:
	# HB S. 13 case "Hilfe abgelehnt": Julia sets the table, the meal happens, no trust gain.
	var model = _new()
	var before := _trust(model, "julia")
	_check(_act(model, "i01_talk").ok, "Talk choice commits")
	_check(I01.cups(model.data).values() == ["table", "table", "table"] and _sp(model).i01_table_by == "julia", "Julia sets the table herself")
	_check(_stage(model) == "i01_well", "Julia's request for water is the next objective")
	_at(model, I01.POINTS.player_table)
	var optional: Array = Childhood.interactables(model.data).map(func(i): return i.action_id)
	_check(optional.has("i01_meal"), "Refusing remains possible: breakfast is offered at the table")
	_check(_act(model, "i01_meal").ok, "Breakfast happens without help")
	_check(_sp(model).i01_water == "silvanus" and _trust(model, "julia") == before, "Silvanus fetched water; no trust gain")
	_check(model.data.village.childhood.relationships.julia.declined and not model.data.village.childhood.relationships.julia.helped, "The open request is stored as declined, not as help")
	_check(I01.julia_reaction_id(model.data) == "I01_B_JULIA_DECLINED", "Julia reacts to the open request")
	_check(_act(model, "i01_topic_fields").ok and _stage(model) == "mother_morning", "Morning completes without help")
	_check(model._validate_state(model.data).is_empty(), "Refused path validates")
	# Yard without any help: absence, not declined.
	var yard = _new()
	_act(yard, "i01_yard")
	_at(yard, I01.POINTS.player_table)
	_check(_act(yard, "i01_meal").ok and not yard.data.village.childhood.relationships.julia.declined, "Going out first is not a refused request")
	_check(I01.julia_reaction_id(yard.data) == "I01_B_JULIA_ABSENT", "Julia reacts to absence")


func _test_yard_contact_and_absent_marcus() -> void:
	var model = _new()
	_act(model, "i01_yard")
	var marcus := I01.contact_position(model.data, "marcus", Vector2.ZERO)
	_at(model, marcus + Vector2(1.0, 0.0))
	_check(I01.contact_open(model.data, "marcus"), "Marcus is present at the well")
	_check(_act(model, "i01_contact_marcus").ok and _sp(model).i01_contacts == ["marcus"], "A concrete encounter with Marcus is recorded")
	_check(not model.data.companion.met and model.data.companion.choice == "" and int(model.data.companion.trust) == 0, "The encounter sets no companion/loyalty flag")
	_check(not _act(model, "i01_contact_marcus").ok, "The same encounter cannot be recorded twice")
	_at(model, I01.POINTS.player_table)
	_act(model, "i01_meal")
	_check(_act(model, "i01_topic_contact").ok and I01.topic_line(model.data).text.contains("Marcus"), "Table talk can tell the actual encounter")
	_check(model._validate_state(model.data).is_empty(), "Yard path with contact validates")
	# HB S. 13 case "NPC beim Brunnen abwesend".
	var absent = _new()
	_act(absent, "i01_yard")
	absent.data.village.behavior.people.marcus.activity = "absent"
	absent.data.village.behavior.people.marcus.reason = "unavailable"
	_at(absent, I01.contact_position(absent.data, "marcus", Vector2.ZERO) + Vector2(0.5, 0.0))
	_check(not I01.contact_open(absent.data, "marcus"), "Absent Marcus offers no contact")
	_check(not _act(absent, "i01_contact_marcus").ok and _sp(absent).i01_contacts.is_empty(), "No contact is recorded for an absent Marcus")
	_at(absent, I01.POINTS.player_table)
	_act(absent, "i01_meal")
	var topics: Array = Childhood.dialogue(absent.data, "silvanus").get("choices", []).map(func(c): return c.label)
	_check(topics.size() == 2 and not str(topics).contains("Marcus"), "No substitute contact line appears at the table: " + str(topics))


func _test_save_at_table() -> void:
	# HB S. 13 case "Save am Tisch": cups in hand / on the table survive resume.
	var model = _new()
	_act(model, "i01_help")
	_at(model, I01.POINTS.home_shelf + Vector2(0.7, 0.0))
	_act(model, "i01_take_cups")
	_at(model, I01.POINTS.player_table)
	_act(model, "i01_place_player")
	var before := I01.presentation(model.data)
	_check(_check(model.save_game(_path("table")).ok, "Save at the table"), "Save written")
	var loaded = WorldModel.new()
	_check(loaded.load_game(_path("table")).ok, "Load at the table")
	_check(I01.presentation(loaded.data) == before and I01.cups(loaded.data) == {"julia":"hand", "silvanus":"hand", "player":"table"}, "One cup on the table and two in hand after resume")
	_check(_sp(loaded).i01_events == _sp(model).i01_events, "Event ledger identical after resume")
	_check(_stage(loaded) == "i01_set_table" and _act(loaded, "i01_place_julia").ok, "Play continues at the same beat after resume")


func _test_replay_and_duplicates() -> void:
	var model = _new()
	var first := _act(model, "i01_help", "i01-help-once")
	var snapshot := JSON.stringify(model.data.village.childhood)
	var replay := _act(model, "i01_help", "i01-help-once")
	_check(first.ok and replay.ok and JSON.stringify(model.data.village.childhood) == snapshot, "An exact command retry returns the stored result without a second event")
	_check(not _act(model, "i01_help").ok and not _act(model, "i01_yard").ok, "A committed choice cannot be repeated or changed")
	var forged: Dictionary = model.data.duplicate(true)
	forged.village.childhood.screenplay.i01_events.append("I-01.choice.help")
	_check(not Childhood.validate(forged).is_empty(), "A duplicated ledger event is rejected")
	var invented: Dictionary = model.data.duplicate(true)
	invented.village.childhood.screenplay.i01_cups.julia = "table"
	_check(not Childhood.validate(invented).is_empty(), "A cup on the table without the placing event is rejected")


func _v3_save(model, completed: Array) -> Dictionary:
	var state: Dictionary = model.data.duplicate(true)
	for key: String in I01.KEYS:
		state.village.childhood.screenplay.erase(key)
	state.village.childhood.screenplay.version = 3
	state.village.childhood.completed = completed
	return state


func _write(path: String, state: Dictionary) -> void:
	var payload := JSON.stringify(state, "", true, true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format":WorldModel.SAVE_FORMAT, "format_version":1, "payload":payload, "sha256":payload.sha256_text()}))
	file.close()


func _test_migration_v3_to_v4() -> void:
	var model = _new(false)
	# A v3 save standing before the first family conversation.
	_write(_path("v3_start"), _v3_save(model, []))
	var start = WorldModel.new()
	_check(start.load_game(_path("v3_start")).ok, "v3 save before the family talk loads: " + str(start.load_game(_path("v3_start")).message))
	_check(_sp(start).version == 4 and _sp(start).i01 == "pending" and _sp(start).i01_events.is_empty() and _sp(start).i01_path == "", "Migration opens the new morning without completing anything")
	_check(_stage(start) == "i01_choice" and start.data.village.childhood.completed.is_empty(), "Migrated start continues at the I-01 choice")
	_check(int(start.data.resources.denarii) == WorldModel.DEVELOPMENT_START_DENARII, "Migration keeps the money stored in the old save")
	# A v3 save already past the family conversation.
	model.set_player_position(Vector3(Childhood.POINTS.mother.x, 1.0, Childhood.POINTS.mother.y))
	var past := _v3_save(model, ["mother_morning"])
	past.village.childhood.carried = ["household_coin"]
	_write(_path("v3_past"), past)
	var later = WorldModel.new()
	_check(later.load_game(_path("v3_past")).ok, "v3 save after the family talk loads")
	_check(_sp(later).i01 == "legacy" and _sp(later).i01_events.is_empty() and later.data.village.childhood.completed == ["mother_morning"], "Later saves keep progress and get no invented I-01 events")
	_check(_stage(later) == "fill_water", "Legacy save continues at its own next step")
	_check(later.save_game(_path("v4_again")).ok and WorldModel.new().load_game(_path("v4_again")).ok, "Migrated save re-saves and reloads as v4")
	var legacy_forged: Dictionary = later.data.duplicate(true)
	legacy_forged.village.childhood.screenplay.i01_events = ["I-01.choice.help"]
	_check(not Childhood.validate(legacy_forged).is_empty(), "A legacy save cannot carry invented I-01 events")


func _test_regular_start_money() -> void:
	var development = _new(false)
	_check(int(development.data.resources.denarii) == WorldModel.DEVELOPMENT_START_DENARII, "Development/test worlds keep the explicitly named 30-denarii fund")
	var regular = _new(true)
	_check(int(regular.data.resources.denarii) == 0, "Regular new life starts at 0 denarii")
	var legacy_career = WorldModel.new()
	legacy_career.new_game("germania", false, false, false, true)
	_check(int(legacy_career.data.resources.denarii) == 0, "Regular start without childhood also starts at 0 denarii")
	# An existing regular save with money keeps it on load.
	var rich: Dictionary = development.data.duplicate(true)
	rich.resources.denarii = 30
	_write(_path("old_money"), rich)
	var reloaded = WorldModel.new()
	_check(reloaded.load_game(_path("old_money")).ok and int(reloaded.data.resources.denarii) == 30, "Existing saves keep their stored denarii")


func _test_invented_success_text() -> void:
	var texts := ""
	for step: Dictionary in Childhood.STEPS.slice(0, 3):
		texts += JSON.stringify(step)
	_check(not texts.contains("stehen gefüllt"), "No I-01 step claims filled cups the world does not show")
	_check(not texts.contains("Hol bitte zuerst Wasser und füll unsere drei Becher"), "Julia's errand does not repeat the finished cup task")
