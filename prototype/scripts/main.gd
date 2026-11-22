extends Node

const ModelScript = preload("res://scripts/domain/world_model.gd")
const WorldScript = preload("res://scripts/world/game_world.gd")
const UIScript = preload("res://scripts/ui/game_ui.gd")
const AtlasScreen = preload("res://scripts/strategy/atlas_screen.gd")
const Seasons = preload("res://scripts/strategy/season_campaign.gd")
const Origins = preload("res://scripts/strategy/origins.gd")
const ValleyScene = preload("res://scripts/tactics/valley_scene.gd")
const SAVE_PATH = "user://imperathen_campaign.json"

var model
var world
var ui
var screen := "intro"
var mode := "person"
var atlas
var atlas_return := ""
var valley
var valley_demo := false
var session_started := false
var refresh_pending := true
var refresh_elapsed := 0.0
var autosave_elapsed := 0.0
var last_story_id := ""
var command_serial := 0
var run_id := ""


func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	get_window().go_back_requested.connect(_on_go_back_requested)
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
	if screen == "atlas":
		return
	if screen == "valley":
		if not valley_demo and not valley.paused:
			autosave_elapsed += delta
			if autosave_elapsed >= 15:
				autosave_elapsed = 0
				_save(false)
		return
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
		if screen == "atlas":
			_leave_atlas()
			get_viewport().set_input_as_handled()
			return
		if screen == "playing":
			_pause()
		elif screen == "paused":
			_resume()
		get_viewport().set_input_as_handled()


func _on_go_back_requested() -> void:
	# The window signal is the single Android Back entry point. Handling the
	# preceding node notification too would process one request twice.
	if screen == "atlas":
		_leave_atlas()
	elif screen == "valley":
		_leave_valley()
	elif is_instance_valid(ui):
		ui.handle_back()


func _notification(what: int) -> void:
	if screen == "atlas" and is_instance_valid(atlas):
		if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
			if not atlas.demo and session_started:
				_save(false)
			return
	if screen == "valley" and is_instance_valid(valley):
		if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
			valley.paused = true
			valley.reset_gesture()
			if not valley_demo:
				_save(false)
			return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if session_started and screen == "playing":
			_pause()
		return
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
	_log_menu_geometry.call_deferred()


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
	model.new_game(ui.origin_id)
	last_story_id = ""
	world.setup(model.data)
	session_started = true
	autosave_elapsed = 0.0
	_resume()
	var saved := _save(false)
	if saved.get("ok", false):
		ui.notify(Origins.PEOPLES[model.data.origin_id].intro)
		print("IMPERATHEN_SESSION_STARTED: saved frontier world")


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
	print("IMPERATHEN_CONTINUED")


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
	print("IMPERATHEN_PAUSED")


func _save(show_feedback: bool = true) -> Dictionary:
	if not session_started:
		return {"ok": false, "message": "Es läuft noch keine Partie."}
	model.set_player_position(world.get_player_position())
	if screen == "valley" and not valley_demo:
		model.checkpoint_valley(valley.model)
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
		"atlas_demo": _open_atlas(true)
		"atlas": _open_atlas(false)
		"valley_demo": _open_valley(true)
		"valley": _open_valley(false)
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
		"quality_changed":
			var selected_profile: String = str(payload.get("profile", "balanced"))
			world.set_quality(selected_profile)
			if is_instance_valid(valley):
				valley.set_quality(selected_profile)
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
	ui.show_dialog("Ein Fremder am Brunnen", "%s Vier Holzstücke genügen für die Reparatur. Möchtest du teilen?" % Origins.PEOPLES[model.data.origin_id].intro, [
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
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy":
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


func _log_menu_geometry() -> void:
	# Debug builds expose only this button's screen coordinates so Android smoke
	# checks can tap the actual laid-out control without guessed pixel positions.
	if not OS.is_debug_build() or screen != "menu":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if screen != "menu":
		return
	var button := _find_start_button(ui)
	if button != null:
		var center := button.get_global_rect().get_center()
		var position := get_viewport().get_screen_transform() * center
		print("IMPERATHEN_MENU_READY " + JSON.stringify({"new_game": [position.x, position.y]}))


func _find_start_button(node: Node) -> Button:
	if node is Button and node.text == "Neues Leben":
		return node
	for child: Node in node.get_children():
		var found := _find_start_button(child)
		if found != null:
			return found
	return null


func _open_valley(demo: bool) -> void:
	if valley != null:
		return
	if demo:
		if screen != "menu":
			return
	elif screen not in ["paused", "playing"] or not model.data.progress.skirmish_won or not model.data.story.choices.is_empty():
		ui.notify("Verteidige zuerst das Dorf und schließe die Folgeentscheidung ab.")
		return
	valley = ValleyScene.new()
	if not demo and not model.data.valley.is_empty():
		if not valley.model.restore(model.data.valley.snapshot):
			valley.free()
			valley = null
			ui.notify("Das Talgefecht konnte nicht wiederhergestellt werden.")
			return
	valley_demo = demo
	valley.profile = ui.get_quality()
	valley.leave_requested.connect(_leave_valley)
	valley.battle_finished.connect(_valley_finished)
	world.set_active(false)
	world.hide()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.hide()
	ui.process_mode = Node.PROCESS_MODE_DISABLED
	screen = "valley"
	autosave_elapsed = 0.0
	add_child(valley)


func _valley_finished() -> void:
	if not valley_demo:
		_save(false)


func _leave_valley() -> void:
	if not valley_demo and not _save(false).ok:
		valley.paused = true
		valley.message = "Speichern fehlgeschlagen. Bitte erneut versuchen."
		return
	var was_demo := valley_demo
	valley_demo = false
	remove_child(valley)
	valley.queue_free()
	valley = null
	world.process_mode = Node.PROCESS_MODE_INHERIT
	ui.process_mode = Node.PROCESS_MODE_INHERIT
	world.show()
	ui.show()
	world.get_node("WorldCamera").current = true
	if was_demo:
		_show_menu()
	else:
		_resume()


func _open_atlas(demo: bool) -> void:
	if atlas or (screen != "menu" if demo else screen not in ["paused","playing"]):
		return
	atlas_return = screen
	atlas = AtlasScreen.new()
	atlas.demo = demo
	atlas.data = Seasons.new_game(ui.origin_id) if demo else model.data.strategy
	atlas.selected = atlas.data.home
	atlas.pass_status = "" if demo else model.data.valley.get("outcome","")
	atlas.young = not demo and model.data.player.age < 18
	atlas.can_act = demo or (model.data.progress.skirmish_won and model.data.story.choices.is_empty() and not model.data.progress.career_terminal)
	world.hide()
	world.set_active(false)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	ui.hide()
	ui.process_mode = Node.PROCESS_MODE_DISABLED
	screen = "atlas"
	atlas.leave_requested.connect(_leave_atlas)
	atlas.acted.connect(_act_atlas)
	add_child(atlas)


func _act_atlas(command: String,target: String) -> void:
	if not atlas or not atlas.can_act:
		return
	var result: Dictionary
	if atlas.demo:
		result = Seasons.act(atlas.data,command,target)
	else:
		result = model.act_region(command,target)
		atlas.data = model.data.strategy
		if result.ok:
			var saved := _save(false)
			if not saved.ok:
				result.message += " " + saved.message
	atlas.refresh(result.message)


func _leave_atlas() -> void:
	if not atlas:
		return
	if not atlas.demo and not _save(false).ok:
		atlas.refresh("Der Spielstand konnte nicht geschrieben werden.")
		return
	remove_child(atlas)
	atlas.queue_free()
	atlas = null
	world.show()
	world.process_mode = Node.PROCESS_MODE_INHERIT
	ui.process_mode = Node.PROCESS_MODE_INHERIT
	ui.show()
	if atlas_return == "menu":
		_show_menu()
	elif atlas_return == "paused":
		_pause()
	else:
		_resume()
