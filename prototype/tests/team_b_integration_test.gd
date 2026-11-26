extends SceneTree
## Integration der drei Team-B-Verträge mit echter Speicherdatei, Weltphysik
## und dem vorhandenen Bewohnerpanel. Platzierte Sichtproben sind Testfixtures.

const Model = preload("res://scripts/domain/world_model.gd")
const Behavior = preload("res://scripts/domain/npc_behavior.gd")
const Social = preload("res://scripts/domain/npc_social_memory.gd")
const Life = preload("res://scripts/story/village_life.gd")
const CompanionStory = preload("res://scripts/story/companion_story.gd")
const World = preload("res://scripts/world/game_world.gd")
const UI = preload("res://scripts/ui/game_ui.gd")
var checks := 0
var failures: Array[String] = []
var directory := "user://team_b_%d" % Time.get_ticks_usec()


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	_test_initial_staff_and_migration()
	_test_save_and_replay()
	await _test_geometry_and_panel()
	for suffix in ["legacy.save", "social.save", "social.save.bak", "broken.save", "marcus.save"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(suffix)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("TEAM_B_INTEGRATION_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("TEAM_B_INTEGRATION_PASS" if failures.is_empty() else "TEAM_B_INTEGRATION_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition


func _new():
	var model := Model.new()
	model.new_game("italia", true, true)
	return model


func _person(data: Dictionary, id: String) -> Dictionary:
	for person: Dictionary in data.village.economy.people:
		if person.id == id:
			return person
	return {}


func _write_save(state: Dictionary, filename: String) -> String:
	var path := directory.path_join(filename)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var payload := JSON.stringify(state)
	var envelope := {"format":Model.SAVE_FORMAT, "format_version":1,
		"payload":payload, "sha256":payload.sha256_text()}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	return path


func _test_initial_staff_and_migration() -> void:
	var model = _new()
	_check(_person(model.data, "cassia").assignment == "trade" and _person(model.data, "antonia").assignment == "trade", "Neue Kindheit: zwei vorhandene Erwachsene am Handelsplatz")
	_check(_person(model.data, "antonia").profession == "Töpferin" and model.data.village.economy.people.size() == 14, "Beruf und Identität bleiben erhalten; keine zusätzliche Arbeitskraft erfunden")
	_check(_person(model.data, "silvanus").assignment == "idle", "Vater und Begleiter wird nicht als zweite Handelsarbeitskraft gebunden")
	_check(model.data.schema_version == Model.SCHEMA_VERSION and model._validate_state(model.data).is_empty(), "Neue Partie bewahrt den aktuellen Weltvertrag")
	var legacy: Dictionary = model.data.duplicate(true)
	legacy.village.behavior.erase("social")
	_person(legacy, "antonia").assignment = "idle"
	var original_economy: Dictionary = legacy.village.economy.duplicate(true)
	var restored := Model.new()
	_check(restored.load_game(_write_save(legacy, "legacy.save")).ok, "Alter gültiger Spielstand ohne soziale Erinnerungen lädt durch die echte Speicher-API")
	_check(restored.data.village.behavior.social.pairs.is_empty(), "Migration erfindet keine vergangenen Bekanntschaften")
	_check(restored.data.village.economy == original_economy and _person(restored.data, "antonia").assignment == "idle", "Migration verteilt bestehende Einwohner und Waren nicht neu")
	var broken: Dictionary = restored.data.duplicate(true)
	broken.village.behavior.social = {"version":1, "pairs":{"unknown:unknown":{}}}
	var before: Dictionary = restored.data.duplicate(true)
	_check(not restored.load_game(_write_save(broken, "broken.save")).ok, "Vorhandene beschädigte Sozialdaten werden abgelehnt")
	_check(restored.data == before, "Abgelehntes Laden bewahrt die gesamte laufende Welt")


func _conversation(model, first: String, second: String, a: Vector3, b: Vector3) -> void:
	Behavior.observe(model.data, {first:{"position":[a.x,a.y,a.z]},second:{"position":[b.x,b.y,b.z]}}, true)
	for id: String in [first, second]:
		var person: Dictionary = model.data.village.behavior.people[id]
		person.activity = "socialize"
		person.reason = "company"
		person.partner = second if id == first else first
		person.social_need = 100.0
		person.fatigue = 5.0
		person.next_decision = float(model.data.world_seconds) + 4.0


func _test_save_and_replay() -> void:
	var model = _new()
	model.set_player_position(Vector3(70.0, 0.9, 70.0))
	var source := Vector3(-16.0, 0.0, 5.0)
	var target := Vector3(-16.0, 0.0, 6.0)
	for index in 16:
		_conversation(model, "flavia", "bassa", source, target)
		model.advance(0.5)
	var memory: Dictionary = model.data.village.behavior.social.duplicate(true)
	_check(Social.relationship(memory, "flavia", "bassa").encounters == 1, "Ein Gespräch entsteht durch echte WorldModel-Zeitschritte")
	_check(model.save_game(directory.path_join("social.save")).ok, "Soziale Erinnerung in tatsächlichen Save-Envelope geschrieben")
	var restored := Model.new()
	_check(restored.load_game(directory.path_join("social.save")).ok, "Sozialer Spielstand vollständig geladen")
	_check(restored.data.village.behavior.social == memory, "Dauer, Begegnung und Wiederholungsschutz überstehen Neustart exakt")
	var read_before: Dictionary = restored.data.duplicate(true)
	var relationships: Array = Behavior.social_neighbors(restored.data, "flavia")
	_check(relationships.size() == 1 and relationships[0].id == "bassa", "Persistente Bekanntschaft bleibt nach Ende des Gesprächs abrufbar")
	_check(restored.data == read_before, "Beziehungsansicht verändert weder Erinnerung noch Ressourcen")
	for item in [model, restored]:
		_conversation(item, "flavia", "bassa", source, target)
		item.advance(0.5)
	_check(model.data.village.behavior.social == restored.data.village.behavior.social, "Fortsetzung nach Neustart stimmt mit ununterbrochener Simulation überein")
	_check(Social.relationship(restored.data.village.behavior.social, "flavia", "bassa").encounters == 1, "Fortsetzung zählt dasselbe Gespräch nicht doppelt")
	_check(restored._validate_state(restored.data).is_empty(), "Gemeinsame NPC-, Wirtschafts- und Spieluhr bleibt gültig")


func _test_geometry_and_panel() -> void:
	var model = _new()
	var world := World.new()
	root.add_child(world)
	world.setup(model.data)
	world.set_active(false)
	world.set_physics_process(false)
	model.npc_sight_check = world.npc_sight_clear
	var a := Vector3(800.0, 10.0, 800.0)
	var b := Vector3(801.0, 10.0, 800.0)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1, 3.0, 2.0)
	collision.shape = box
	wall.add_child(collision)
	root.add_child(wall)
	wall.position = Vector3(800.5, 11.5, 800.0)
	world._player.position.y = 400.0
	await physics_frame
	await physics_frame
	_check(not world.npc_sight_clear(a, b), "Echte Wand sperrt NPC-Sicht auf eigener Höhe unabhängig von Spielerhöhe")
	_check(world.npc_sight_clear(a + Vector3(0,0,2), b + Vector3(0,0,2)), "Freier Weg neben derselben Wand ist sichtbar")
	_check(not world.npc_sight_clear(Vector3(NAN,0,0), b), "Ungültige Sichtkoordinate wird abgelehnt")
	model.set_player_position(Vector3(70.0,0.9,70.0))
	for index in 16:
		_conversation(model, "flavia", "bassa", a, b)
		model.advance(0.5)
	_check(model.data.village.behavior.social.pairs.is_empty(), "WorldModel vergibt durch reale Mauer kein Gespräch und keine Bekanntschaft")
	# Marcus' historical save coordinate is the body midpoint, while all other
	# residents report feet. Test the real observation and the old restore path.
	world._companion.global_position = a
	world._companion.visible = true
	var observation: Dictionary = world.npc_observations()
	_check(observation.has("marcus") and is_equal_approx(float(observation.marcus.position[1]), a.y + 0.9), "Echte Marcus-Beobachtung bewahrt den historischen Mittelpunkt im Save")
	box.size.y = 1.8
	wall.position.y = a.y + 0.9
	await physics_frame
	for index in 16:
		_conversation(model, "marcus", "flavia", a + Vector3.UP * 0.9, b)
		model.advance(0.5)
	_check(not model.data.village.behavior.social.pairs.has(Social.pair_key("marcus", "flavia")), "Marcus blickt von Fußhöhe plus Augenoffset und nicht über die niedrige Testwand")
	_check(is_equal_approx(float(model.data.village.behavior.people.marcus.position[1]), a.y + 0.9), "Sichtnormalisierung verändert Marcus' gespeicherte Höhe nicht")
	_check(model.save_game(directory.path_join("marcus.save")).ok, "Marcus-Mittelpunkt wird mit realem Speichervertrag geschrieben")
	var restored := Model.new()
	_check(restored.load_game(directory.path_join("marcus.save")).ok, "Marcus-Spielstand lädt ohne neue Positionsmigration")
	var companion_probe: Dictionary = restored.data.duplicate(true)
	companion_probe.companion.met = true
	_check(CompanionStory.restored_position(companion_probe, "marcus", Vector3.INF).is_equal_approx(a), "Bestehender Begleiterpfad rekonstruiert denselben Fußpunkt ohne Bodenversatz")
	wall.free()
	await physics_frame
	_check(world.npc_sight_clear(a, b), "Entfernte Wand gibt denselben realen Sichtstrahl frei")
	for index in 16:
		_conversation(model, "flavia", "bassa", a, b)
		model.advance(0.5)
	_check(Social.relationship(model.data.village.behavior.social,"flavia","bassa").encounters == 1, "Freie Sicht aktiviert im identischen Modell tatsächlich das Gespräch")
	world.free()
	await process_frame
	# A known family resident receives a view of a simulated acquaintance.
	model = _new()
	model.set_player_position(Vector3(70.0,0.9,70.0))
	for index in 16:
		_conversation(model, "julia", "silvanus", Vector3(-12,0,12), Vector3(-11,0,12))
		model.advance(0.5)
	var ui := UI.new()
	root.add_child(ui)
	await process_frame
	var before: Dictionary = model.data.duplicate(true)
	ui.show_village_panel(model.data, "people")
	await process_frame
	var labels := ""
	for label: Label in ui._screen.find_children("*", "Label", true, false):
		labels += label.text + "\n"
	_check(labels.contains("Silvanus · Vertrauter Nachbar"), "Vorhandenes Bewohnerpanel zeigt gespeicherte Bekanntschaft beim bekannten Familienmitglied")
	_check(model.data == before, "Panelanzeige bleibt vollständig lesend")
	ui.free()
	await process_frame
