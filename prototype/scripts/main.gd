extends Node

const ModelScript = preload("res://scripts/domain/world_model.gd")
const WorldScript = preload("res://scripts/world/game_world.gd")
const UIScript = preload("res://scripts/ui/game_ui.gd")
const SAVE_PATH = "user://imperathen_campaign.json"

var model
var world
var ui
var screen := "intro"
var mode := "person"
var session_started := false
var refresh_pending := true
var refresh_elapsed := 0.0
var autosave_elapsed := 0.0
var last_story_id := ""
var command_serial := 0
var run_id := ""


func _ready() -> void:
	get_tree().auto_accept_quit = false
	run_id = "%s_%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	model = ModelScript.new()
	model.new_game()
	model.changed.connect(_mark_changed)
	world = WorldScript.new()
	add_child(world)
	world.setup(model.data)
	world.action_requested.connect(_on_world_action)
	world.set_active(false)
	world.set_mode("city")
	ui = UIScript.new()
	add_child(ui)
	ui.action_requested.connect(_on_ui_action)
	world.set_quality(ui.get_quality())
	_setup_ambient()
	ui.show_intro()
	print("IMPERATHEN_READY: Godot prototype, intro -> menu -> persistent frontier loop")


func _process(delta: float) -> void:
	if screen == "playing":
		model.set_player_position(world.get_player_position())
		model.advance(delta)
		autosave_elapsed += delta
		if autosave_elapsed >= 45.0:
			autosave_elapsed = 0.0
			_save(false)
	refresh_elapsed += delta
	if refresh_pending and refresh_elapsed >= 0.12:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if screen == "playing":
			_pause()
		elif screen == "paused":
			_resume()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if session_started:
			if screen == "playing":
				_pause()
			_save(false)
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if session_started:
			if not _save(false).get("ok", false):
				_pause()
				return
		get_tree().quit()


func _mark_changed() -> void:
	refresh_pending = true


func _refresh() -> void:
	refresh_pending = false
	refresh_elapsed = 0.0
	world.sync_state(model.data)
	ui.update_state(model.data)
	ui.set_build_active(world.is_build_active())
	if screen == "playing":
		_check_special_dialog()


func _show_menu() -> void:
	screen = "menu"
	world.set_active(false)
	world.set_mode("city")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_menu(FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_PATH + ".bak"))


func _request_new_game() -> void:
	if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_PATH + ".bak"):
		screen = "dialog"
		world.set_active(false)
		ui.show_dialog("Ein neues Leben", "Eine neue Partie ersetzt den aktiven Spielstand. Die automatische Sicherung ist kein Archiv für frühere Partien. Wirklich neu beginnen?", [
			{"label": "Neues Leben beginnen", "action": "confirm_new_game"},
			{"label": "Zurück zum Hauptmenü", "action": "cancel_new_game"}
		])
	else:
		_start_new_game()


func _start_new_game() -> void:
	model.new_game()
	last_story_id = ""
	world.setup(model.data)
	session_started = true
	autosave_elapsed = 0.0
	_resume()
	var saved := _save(false)
	if saved.get("ok", false):
		ui.notify("Willkommen in der Grenzsiedlung. Sprich mit dem Gefährten und suche Holz.")


func _continue_game() -> void:
	var result: Dictionary = model.load_game(SAVE_PATH)
	if not result.get("ok", false):
		ui.notify(str(result.get("message", "Der Spielstand konnte nicht geladen werden.")))
		return
	world.setup(model.data)
	session_started = true
	last_story_id = ""
	_resume()
	ui.notify(str(result.get("message", "Spielstand geladen.")))


func _resume() -> void:
	if not session_started:
		_show_menu()
		return
	screen = "playing"
	world.set_mode(mode)
	world.set_active(true)
	ui.show_game(model.data)
	ui.set_mode(mode)
	refresh_pending = true


func _pause() -> void:
	if not session_started:
		return
	screen = "paused"
	world.set_active(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_pause()


func _save(show_feedback: bool = true) -> Dictionary:
	if not session_started:
		return {"ok": false, "message": "Es läuft noch keine Partie."}
	model.set_player_position(world.get_player_position())
	var result: Dictionary = model.save_game(SAVE_PATH)
	if show_feedback or not result.get("ok", false):
		ui.notify(str(result.get("message", "Spielstand gespeichert.")))
	return result


func _request_menu() -> void:
	if not session_started:
		_show_menu()
		return
	screen = "dialog"
	world.set_active(false)
	ui.show_dialog("Zurück zur Übersicht", "Deine Siedlung und alle bestätigten Entscheidungen werden vor der Rückkehr gespeichert.", [
		{"label": "Speichern und Hauptmenü", "action": "confirm_menu"},
		{"label": "Weiterspielen", "action": "resume"}
	])


func _set_mode(next_mode: String) -> void:
	if screen != "playing":
		return
	mode = next_mode
	world.set_mode(mode)
	ui.set_mode(mode)


func _on_ui_action(action: String, payload: Dictionary) -> void:
	match action:
		"intro_finished": _show_menu()
		"new_game": _request_new_game()
		"confirm_new_game": _start_new_game()
		"cancel_new_game": _show_menu()
		"continue": _continue_game()
		"pause": _pause()
		"resume": _resume()
		"save": _save()
		"menu": _request_menu()
		"confirm_menu":
			if _save(false).get("ok", false):
				_show_menu()
			else:
				_pause()
		"quit":
			if session_started and not _save(false).get("ok", false):
				return
			get_tree().quit()
		"mode_person": _set_mode("person")
		"mode_city": _set_mode("city")
		"mode_map": _set_mode("map")
		"quality_changed": world.set_quality(str(payload.get("profile", "balanced")))
		"move_axis":
			if screen == "playing":
				world.set_touch_move(Vector2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0))))
		"interact":
			if screen == "playing":
				world.perform_interaction()
		"attack":
			if screen == "playing":
				world.perform_attack()
		"cancel_build":
			if screen == "playing":
				world.set_build_mode(false)
		"build":
			if screen == "playing":
				_set_mode("city")
				world.set_build_mode(true)
				ui.notify("Wähle einen freien Bauplatz auf der markierten Fläche. Kosten: 8 Holz.")
		"companion_help", "companion_decline":
			_resume()
			_command("choose_companion", {"choice": "help" if action == "companion_help" else "decline"})
		"train", "recruit": _command(action, payload)
		"skirmish": _command("start_skirmish", payload)
		"story_choice":
			_resume()
			var choice_result := _command("choose_story", payload)
			if not choice_result.get("ok", false):
				last_story_id = ""
				_check_special_dialog()
		"death_menu": _show_menu()
		_:
			ui.notify("Diese Aktion ist im Prototyp noch nicht verfügbar: " + action)


func _on_world_action(action: String, payload: Dictionary) -> void:
	if action == "build_mode_changed":
		if ui != null:
			ui.set_build_active(bool(payload.get("active", false)))
		return
	if screen != "playing":
		return
	match action:
		"companion_interact": _show_companion()
		"mode_person", "mode_city", "mode_map": _on_ui_action(action, payload)
		"pause": _pause()
		_:
			_command(action, payload)


func _command(command: String, payload: Dictionary) -> Dictionary:
	if screen != "playing":
		return {"ok": false, "message": "Die Welt ist pausiert."}
	model.set_player_position(world.get_player_position())
	command_serial += 1
	var result: Dictionary = model.execute(command, payload, "%s_%d" % [run_id, command_serial])
	if not result.get("ok", false) or command != "receive_damage":
		ui.notify(str(result.get("message", "")))
	_refresh()
	if result.get("ok", false) and (command in ["choose_companion", "train", "recruit", "resolve_skirmish", "choose_story"] or model.data.progress.stage in ["aftermath", "fallen"]):
		_save(false)
	return result


func _show_companion() -> void:
	var companion: Dictionary = model.data.get("companion", {})
	if not str(companion.get("choice", "")).is_empty():
		ui.notify("Deine Entscheidung bleibt Teil eurer Geschichte. Vertrauen: %s" % companion.get("trust", 0))
		return
	screen = "dialog"
	world.set_active(false)
	ui.show_dialog("Ein Fremder am Brunnen", "Der junge Marcus trägt einen zerbrochenen Korb. Er braucht vier Holzstücke für die Reparatur. Hilfst du ihm, obwohl du selbst erst eine Unterkunft bauen musst?", [
		{"label": "Vier Holz teilen und helfen", "action": "companion_help", "choice": "help"},
		{"label": "Meine Vorräte behalte ich", "action": "companion_decline", "choice": "decline"},
		{"label": "Ich komme später wieder", "action": "resume"}
	])


func _check_special_dialog() -> void:
	if int(model.data.get("player", {}).get("health", 1)) <= 0:
		screen = "dialog"
		world.set_active(false)
		ui.show_dialog("Dein Weg endet hier", "Die Niederlage gehört zu diesem Lebenslauf. Du kannst zum Hauptmenü zurückkehren und ein neues Leben beginnen.", [{"label": "Zum Hauptmenü", "action": "death_menu"}])
		return
	var story: Dictionary = model.data.get("story", {})
	var choices: Array = story.get("choices", [])
	var story_id := str(story.get("id", JSON.stringify([story.get("title", ""), story.get("text", ""), choices]).sha256_text()))
	if not choices.is_empty() and story_id != last_story_id and not story_id.is_empty():
		last_story_id = story_id
		screen = "dialog"
		world.set_active(false)
		ui.show_dialog(str(story.get("title", "Deine Geschichte")), str(story.get("text", "")), choices)


func _setup_ambient() -> void:
	# Headless runs have no audio device. The dummy backend retains asynchronous
	# playback until its audio tick, so logic checks intentionally remain silent.
	if DisplayServer.get_name() == "headless":
		return
	if not ResourceLoader.exists("res://assets/frontier_ambience.wav"):
		return
	var ambience := AudioStreamPlayer.new()
	ambience.name = "FrontierAmbience"
	ambience.stream = load("res://assets/frontier_ambience.wav")
	ambience.volume_db = -15.0
	add_child(ambience)
	ambience.finished.connect(ambience.play)
	ambience.play()


func _exit_tree() -> void:
	var ambience := get_node_or_null("FrontierAmbience") as AudioStreamPlayer
	if ambience != null:
		ambience.stop()
		ambience.stream = null
