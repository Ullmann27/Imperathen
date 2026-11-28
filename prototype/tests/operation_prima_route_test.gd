extends "res://tests/i01_playthrough_test.gd"
## Adds the missing menu and I-00 re-entry path to the existing production playthrough.
## Run with isolated XDG data/config/cache directories and IMPERATHEN_ISOLATED_TEST=1:
## godot --headless --path prototype --fixed-fps 60 --script res://tests/operation_prima_route_test.gd

const OpeningCheckpoint = preload("res://scripts/cinematic/opening_checkpoint.gd")
const MainScript = preload("res://scripts/main.gd")


func _run() -> void:
	await _verify_menu_and_i00_resume()
	if not failures.is_empty():
		if is_instance_valid(game):
			game._release_opening()
			game.queue_free()
			await _prima_frames(4)
		print("OPERATION_PRIMA_ROUTE_FAILED checks=%d failures=%d" % [checks, failures.size()])
		quit(1)
		return
	await super._run()
	print(("OPERATION_PRIMA_ROUTE_PASS" if failures.is_empty() else "OPERATION_PRIMA_ROUTE_FAILED") + " checks=%d failures=%d" % [checks, failures.size()])


func _verify_menu_and_i00_resume() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	game = Entry.instantiate()
	root.add_child(game)
	await _prima_frames(4)
	game.ui._finish_intro()

	var settings: Button = _find_button(game.ui, "Einstellungen")
	check(settings != null, "Einstellungen sind im Produktionsmenü erreichbar")
	if settings != null:
		settings.pressed.emit()
		await _prima_frames(3)
		check(game.ui.get("_view_state") == "settings", "Menü öffnet die Produktionseinstellungen")
		var settings_screen: Node = game.ui.get("_screen") as Node
		var back: Button = _find_button(settings_screen, "Zurück") if settings_screen != null else null
		check(back != null, "Einstellungen bieten eine Rückkehr")
		if back != null:
			back.pressed.emit()
			await _prima_frames(3)
	check(game.ui.get("_view_state") == "menu", "Einstellungen führen zurück ins Hauptmenü")

	var new_life: Button = _find_button(game.ui, "Neues Leben")
	if not check(new_life != null and not new_life.disabled, "Neues Leben startet über das echte Menü"):
		return
	new_life.pressed.emit()
	await _prima_frames(4)
	if not check(game.screen == "opening" and game.opening_sequence.id == "i00_aquileia", "Neues Leben öffnet den I-00-Prolog"):
		return

	var world_id: String = str(game.model.data.world_id)
	var opening_index: int = game.opening_index
	var saved_state: String = JSON.stringify(game.model.data)
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var checkpoint: Dictionary = OpeningCheckpoint.read(world_id)
	check(game.opening_paused and checkpoint.get("sequence_id", "") == "i00_aquileia" and int(checkpoint.get("index", -1)) == opening_index, "Unterbrechung sichert die aktuelle I-00-Stelle")

	game._release_opening()
	game.queue_free()
	await _prima_frames(4)
	game = Entry.instantiate()
	root.add_child(game)
	await _prima_frames(4)
	game.ui._finish_intro()
	var resume: Button = _find_button(game.ui, "Fortsetzen")
	if not check(resume != null and not resume.disabled, "Gespeicherter Prolog ist über Fortsetzen erreichbar"):
		return
	resume.pressed.emit()
	await _prima_frames(6)
	check(game.screen == "opening" and game.opening_sequence.id == "i00_aquileia" and game.opening_index == opening_index, "Fortsetzen stellt denselben I-00-Prolog wieder her")
	check(str(game.model.data.world_id) == world_id and JSON.parse_string(JSON.stringify(game.model.data)) == JSON.parse_string(saved_state), "Fortsetzen ändert weder Welt noch Kampagnenzustand")

	game.opening_overlay.skip_requested.emit()
	var beats: Array = game.opening_sequence.beats
	var beat: Dictionary = beats[game.opening_index]
	check(game.screen == "opening" and game.opening_sequence.id == "i00_aquileia" and bool(beat.get("final", false)), "I-00-Skip wartet an der bestätigungspflichtigen Übergabe")
	check(JSON.parse_string(JSON.stringify(game.model.data)) == JSON.parse_string(saved_state), "I-00-Skip erzeugt keine Kampagnenhandlung")
	game.opening_overlay.advance_requested.emit()
	await _prima_frames(4)
	check(game.screen == "opening" and game.opening_sequence.id == "childhood_home", "Bestätigte Übergabe führt in den I-01-Familienmorgen")

	game._release_opening()
	game.queue_free()
	await _prima_frames(4)
	_clear_test_save()


func _prima_frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _clear_test_save() -> void:
	# The inherited playthrough starts clean; these files belong to this isolated XDG fixture.
	for path: String in [MainScript.SAVE_PATH, MainScript.SAVE_PATH + ".bak", OpeningCheckpoint.PATH, OpeningCheckpoint.PATH + ".pending"]:
		if FileAccess.file_exists(path):
			var result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			check(result == OK, "Test-Fixture wird vor bestehendem Playthrough zurückgesetzt: " + path.get_file())
