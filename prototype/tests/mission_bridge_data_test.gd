extends SceneTree
## Aufgezeichnete Laufzeitdaten vom unveränderten Handoff 94bb7cdd.
## Grenzfälle prüfen den Selektor direkt; gespeicherte echte Model-Durchläufe
## prüfen zusätzlich Envelope, Laden und Fortsetzung über öffentliche Befehle.

const Childhood = preload("res://scripts/story/village_childhood.gd")
const MissionData = preload("res://scripts/story/mission_data.gd")
const WorldModel = preload("res://scripts/domain/world_model.gd")
const Life = preload("res://scripts/story/village_life.gd")
const FIXTURES := "res://tests/fixtures/mission_bridge_data/"
const MOVED_IDS := ["i02_basket", "i02_correct", "i08_tracks", "i08_report", "i10_choice", "i11_forge", "i12_father", "i13_morning", "i14_oath"]
var checks := 0
var failures: Array[String] = []
var directory := "user://mission_bridges_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "handoff_runtime.json"))
	if typeof(baseline) != TYPE_DICTIONARY or baseline.get("schema_version", 0) != 1:
		_check(false, "Die unveränderte Runtime-Fixture ist lesbar")
	else:
		_test_runtime(baseline)
		_test_recorded_saves()
	_cleanup()
	print("MISSION_BRIDGE_DATA_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("MISSION_BRIDGE_DATA_PASS" if failures.is_empty() else "MISSION_BRIDGE_DATA_FAIL")
	quit(0 if failures.is_empty() else 1)


func _test_runtime(baseline: Dictionary) -> void:
	var ids := []
	for step: Dictionary in Childhood.STEPS:
		ids.append(step.id)
	_check(ids == baseline.legacy_step_ids, "Alle 35 Save-relevanten Schritt-IDs behalten ihre Indizes")
	_check(_json(Childhood.CARRIED_EFFECTS) == baseline.carried_effects_json, "Gegenstandsübergaben bleiben bytegleich")
	_check(_json(Childhood.SOURCE_MISSION_BY_STEP) == baseline.source_missions_json, "Bestehende Stammschritte behalten ihre Missionszuordnung")
	var bridges := MissionData.bridge_steps("band1")
	_check(bridges.size() == MOVED_IDS.size(), "Die sieben neuen Dateien liefern genau neun getrennte Brückenschritte")
	for id: String in MOVED_IDS:
		_check(bridges.has(id) and _json(bridges.get(id, {})) == baseline.bridge_runtime_json[id], "Ausgelagerter Runtime-Schritt bytegleich: " + id)
		_check(not ids.has(id), "Brücke wurde nicht in childhood.completed eingefügt: " + id)
	var seen := {}
	for scenario: Dictionary in baseline.selector_cases:
		var selected: Dictionary = Childhood._screenplay_step(scenario.state)
		var expected: String = baseline.bridge_runtime_json[scenario.expected_id]
		_check(_json(selected) == expected, "Aufgezeichneter Selektorfall: " + str(scenario.name))
		seen[scenario.expected_id] = true
		if not selected.is_empty():
			# Früher erzeugte jede Rückgabe ein neues Dictionary. Fremde Leser
			# dürfen deshalb auch nach dem Refactor keine Katalogdaten ändern.
			selected["text"] = "mutierte Testansicht"
			_check(_json(Childhood._screenplay_step(scenario.state)) == expected, "Leseisolation: " + str(scenario.name))
	_check(seen.size() == 13, "Alle zwölf Brücken einschließlich I-03/I-07 und die leere Rückgabe sind erfasst")
	if "--exact-runtime" in OS.get_cmdline_user_args():
		# Einmaliger vollständiger AP-2-Nachweis vor AP-1-Textkorrekturen.
		# Dauerhaft unveränderlich bleiben die IDs/Effekte und Bridge-Texte oben.
		_check(_json(Childhood.STEPS) == baseline.legacy_steps_json, "AP-2: sämtliche 35 Stammschritt-Dictionaries bytegleich")
		print("MISSION_BRIDGE_EXACT_RUNTIME steps_sha256=%s" % _json(Childhood.STEPS).sha256_text())


func _test_recorded_saves() -> void:
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) == OK, "Temporärer Save-Ordner angelegt")
	var cases := {
		"i02_correct":{"action":"basket_correct", "next":"i03_marcus"},
		"i08_report":{"action":"i08_report", "next":"family_evening"},
		"i10_choice":{"action":"i10_hide", "next":"i11_forge"}
	}
	for stage: String in cases:
		var original := FileAccess.get_file_as_string(FIXTURES + "handoff_" + stage + "_v5.json")
		var envelope: Dictionary = JSON.parse_string(original)
		var state: Dictionary = JSON.parse_string(envelope.payload)
		var path := directory.path_join(stage + ".json")
		var file := FileAccess.open(path, FileAccess.WRITE)
		if not _check(file != null, "Unveränderten Handoff-Spielstand in Testordner kopieren: " + stage):
			continue
		file.store_string(original)
		file.close()
		var model = WorldModel.new()
		var loaded: Dictionary = model.load_game(path)
		if not _check(loaded.ok, "Aufgezeichneten v5-Envelope laden: " + stage + ": " + str(loaded.message)):
			continue
		_check(model.data.schema_version == WorldModel.SCHEMA_VERSION and model.data.village.childhood.screenplay.version == 3, "Aktuelles Saveschema, unveränderter Brückenstand: " + stage)
		_check(_save_json(model.data.village.childhood) == _save_json(state.village.childhood), "Kindheitsfortschritt bleibt vollständig erhalten: " + stage)
		_check(_save_json(model.data.companion) == _save_json(state.companion), "Gespeicherte Marcus-Wahl bleibt erhalten: " + stage)
		var view: Dictionary = Childhood.view(model.data)
		_check(view.stage == stage, "Aufgezeichneter Spielstand setzt an derselben Brücke fort: " + stage)
		var point: Vector2 = view.point
		model.set_player_position(Vector3(point.x, 1.0, point.y))
		var npc: String = view.get("target_npc", "")
		if not npc.is_empty() and not Life.relationship(model.data, npc).get("met", false):
			_check(model.execute("village_talk", {"npc_id":npc, "choice":"meet"}).ok, "Vorhandenen Gesprächspartner treffen: " + npc)
		var action: String = cases[stage].action
		var applied: Dictionary = model.execute("village_childhood_action", {"action_id":action})
		if not _check(applied.ok, "Geladene Brücke über echten Befehl abschließen: " + stage + ": " + str(applied.message)):
			continue
		_check(Childhood.view(model.data).stage == cases[stage].next, "Bestehender Folgeschritt nach Save/Load: " + stage + " → " + str(Childhood.view(model.data).stage))
		var completed := _json(model.data.village.childhood)
		_check(model.save_game(path).ok, "Nach Fortsetzung erneut speichern: " + stage)
		var resumed = WorldModel.new()
		_check(resumed.load_game(path).ok and _json(resumed.data.get("village", {}).get("childhood", {})) == completed, "Erneuter Save/Load erhält das Ergebnis: " + stage)


func _cleanup() -> void:
	var folder := DirAccess.open(directory)
	if folder == null:
		return
	for name: String in folder.get_files():
		folder.remove(name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _save_json(value: Variant) -> String:
	# Der Loader stellt Schema-Integer wieder her; JSON.parse liest dieselben
	# Zahlen als Float. Ein gleicher JSON-Rundlauf normalisiert nur diese Typen.
	return _json(JSON.parse_string(_json(value)))


func _check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition
