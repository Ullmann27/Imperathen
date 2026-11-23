extends Node

const ModelScript = preload("res://scripts/domain/world_model.gd")
const WorldScript = preload("res://scripts/world/game_world.gd")
const UIScript = preload("res://scripts/ui/game_ui.gd")
const AtlasScreen = preload("res://scripts/strategy/atlas_screen.gd")
const Seasons = preload("res://scripts/strategy/season_campaign.gd")
const Origins = preload("res://scripts/strategy/origins.gd")
const ValleyScene = preload("res://scripts/tactics/valley_scene.gd")
const OpeningStory = preload("res://scripts/story/opening_story.gd")
const OpeningDirector = preload("res://scripts/cinematic/opening_director.gd")
const OpeningOverlay = preload("res://scripts/ui/opening_overlay.gd")
const OpeningCheckpoint = preload("res://scripts/cinematic/opening_checkpoint.gd")
const VillageLife = preload("res://scripts/story/village_life.gd")
const VillageEconomy = preload("res://scripts/domain/village_economy.gd")
const Childhood = preload("res://scripts/story/childhood_story.gd")
const ChildhoodOpening = preload("res://scripts/story/childhood_opening.gd")
const VillageTrade = preload("res://scripts/domain/village_trade.gd")
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
var opening_director
var opening_overlay
var opening_sequence: Dictionary = {}
var opening_index := 0
var opening_elapsed := 0.0
var opening_paused := false
var opening_manual := false
var opening_checkpoint_failed := false
var pending_opening: Dictionary = {}
var frontier_npc := ""
var village_npc := ""
var village_tab := "overview"
var childhood_npc := ""


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
	if OS.is_debug_build() and OS.has_feature("android"):
		var diagnostics = preload("res://scripts/ui/android_village_diagnostics.gd").new()
		diagnostics.session = self
		add_child(diagnostics)
	print("IMPERATHEN_READY: Godot prototype, intro -> menu -> persistent frontier loop")


func _process(delta: float) -> void:
	if screen == "opening":
		_opening_process(delta)
		return
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
		var escort_limit: float = world.village_life_world.escort_progress_limit(model.data, delta)
		model.advance(delta, escort_limit)
		world.village_life_world.sync_escort(model.data, delta)
		world.set_frontier_time(float(model.data.world_seconds))
		ui.update_childhood_navigation(world.childhood_navigation())
		autosave_elapsed += delta
		if autosave_elapsed >= 45.0:
			autosave_elapsed = 0.0
			_save(false)
	refresh_elapsed += delta
	if refresh_pending and refresh_elapsed >= 0.12:
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if screen == "opening":
		return
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
	if screen == "opening" and is_instance_valid(opening_overlay):
		opening_overlay.handle_back()
	elif screen == "atlas":
		_leave_atlas()
	elif screen == "valley":
		_leave_valley()
	elif is_instance_valid(ui):
		ui.handle_back()


func _notification(what: int) -> void:
	if screen == "opening" and what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_opening_set_paused(true)
		_write_opening_checkpoint(false)
		if session_started:
			_save(false)
		return
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
	ui.update_state(_ui_state())
	ui.set_build_active(world.is_build_active())
	if screen == "playing":
		_check_special_dialog()


func _ui_state() -> Dictionary:
	# Presentation data is derived from the authoritative chapter and never saved.
	var state: Dictionary = model.data.duplicate(true)
	state["frontier_objective"] = model.get_frontier_objective()
	if state.get("village", {}).get("enabled", false):
		state["village_view"] = VillageLife.view(model.data)
		state["village_economy_view"] = VillageEconomy.view(model.data)
	if Childhood.enabled(model.data):
		state["childhood_view"] = model.get_childhood_view()
		state["village_economy_view"]["day"] = int(state.childhood_view.day)
		state["village_view"]["objective"] = str(state.childhood_view.title) + "\n" + str(state.childhood_view.text)
	return state


func _show_menu() -> void:
	_release_opening()
	frontier_npc = ""
	world.clear_frontier_focus()
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
	_release_opening()
	pending_opening = {}
	model.new_game(ui.origin_id, true, true)
	last_story_id = ""
	world.setup(model.data)
	session_started = true
	autosave_elapsed = 0.0
	mode = "person"
	world.set_active(false)
	var saved := _save(false)
	if saved.get("ok", false):
		_begin_opening(ChildhoodOpening.sequence() if Childhood.enabled(model.data) else OpeningStory.sequence(str(model.data.origin_id)))
		print("IMPERATHEN_SESSION_STARTED: saved frontier world")
	else:
		_resume()


func _continue_game() -> void:
	var result: Dictionary = model.load_game(SAVE_PATH)
	if not result.get("ok", false):
		ui.notify(str(result.get("message", "Der Spielstand konnte nicht geladen werden.")))
		return
	world.setup(model.data)
	pending_opening = {}
	session_started = true
	last_story_id = ""
	if not _restore_opening():
		_resume()
		ui.notify(str(result.get("message", "Spielstand geladen.")))
	print("IMPERATHEN_CONTINUED")


func _resume() -> void:
	if screen == "opening":
		_opening_set_paused(false)
		return
	if not session_started:
		_show_menu()
		return
	frontier_npc = ""
	village_npc = ""
	childhood_npc = ""
	world.clear_frontier_focus()
	if not pending_opening.is_empty():
		if not _save(false).get("ok", false):
			_pause()
			return
		var next_opening: Dictionary = pending_opening
		pending_opening = {}
		_begin_opening(next_opening)
		return
	screen = "playing"
	world.set_mode(mode)
	world.set_active(true)
	ui.show_game(_ui_state())
	ui.set_mode(mode)
	refresh_pending = true


func _pause() -> void:
	if screen == "opening":
		_opening_set_paused(true)
		return
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
	if screen == "opening":
		_write_opening_checkpoint(false)
	elif bool(result.get("ok", false)) and not pending_opening.is_empty():
		OpeningCheckpoint.write(str(model.data.world_id), str(pending_opening.id), 0, false)
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
	if screen == "opening" and action != "quality_changed":
		return
	match action:
		"childhood_open": _show_childhood_journal()
		"childhood_command": _childhood_command(str(payload.get("command", "")), payload.get("args", {}))
		"childhood_close", "trade_close": _resume()
		"trade_open": _show_trade()
		"trade_command": _trade_command(str(payload.get("command", "")), payload.get("args", {}))
		"village_panel": _show_village_panel(str(payload.get("tab", "overview")))
		"village_command": _village_command(str(payload.get("command", "")), payload.get("args", {}))
		"village_close": _resume()
		"village_block", "village_dodge":
			if screen == "playing":
				var defense_result := _command(action, {})
				if defense_result.get("ok", false):
					world.cue_village_defense(action)
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
			var companion_result := _command("choose_companion", {"choice": "help" if action == "companion_help" else "decline"})
			if companion_result.get("ok", false):
				ui.notify(OpeningStory.companion_reply(model.data))
			else:
				_show_companion()
		"train", "recruit": _command(action, payload)
		"skirmish": _command("start_skirmish", payload)
		"story_choice":
			_resume()
			var choice_result := _command("choose_story", payload)
			if not choice_result.get("ok", false):
				last_story_id = ""
				_check_special_dialog()
		"frontier_choice": _choose_frontier(payload)
		"frontier_close":
			if screen == "frontier_dialog":
				_resume()
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
		"childhood_interact": _show_childhood_dialog(str(payload.get("npc_id", "")))
		"companion_interact":
			if Childhood.enabled(model.data): _show_childhood_dialog(str(model.data.companion.id))
			else: _show_companion()
		"village_npc": _show_village_npc(str(payload.get("npc_id", "")))
		"village_panel": _show_village_panel("overview")
		"village_block", "village_dodge": _on_ui_action(action, payload)
		"frontier_talk": _show_frontier(str(payload.get("npc_id", "")))
		"mode_person", "mode_city", "mode_map": _on_ui_action(action, payload)
		"pause": _pause()
		_:
			_command(action, payload)


func _command(command: String, payload: Dictionary) -> Dictionary:
	var chapter_choice := screen == "frontier_dialog" and command == "frontier_choice"
	var village_choice := screen in ["village_panel", "village_dialog"] and command.begins_with("village_")
	var childhood_choice := screen == "childhood_dialog" and command == "childhood_choose"
	var trade_choice := screen == "trade_dialog" and command in ["village_trade_buy", "village_trade_sell"]
	if screen != "playing" and not chapter_choice and not village_choice and not childhood_choice and not trade_choice:
		return {"ok": false, "message": "Die Welt ist pausiert."}
	model.set_player_position(world.get_player_position())
	command_serial += 1
	var result: Dictionary = model.execute(command, payload, "%s_%d" % [run_id, command_serial])
	if not result.get("ok", false) or command not in ["receive_damage", "train"]:
		ui.notify(str(result.get("message", "")))
	_refresh()
	var persisted := true
	if result.get("ok", false) and (command in ["childhood_choose", "choose_companion", "train", "recruit", "resolve_skirmish", "choose_story", "frontier_talk", "frontier_choice"] or (command.begins_with("village_") and command not in ["village_strike", "village_block", "village_dodge"]) or model.data.progress.stage in ["aftermath", "fallen"]):
		persisted = bool(_save(false).get("ok", false))
	if result.get("ok", false) and command == "train":
		if persisted:
			_begin_opening(OpeningStory.adulthood(model.data))
		else:
			pending_opening = OpeningStory.adulthood(model.data)
			_pause()
	return result


func _show_childhood_dialog(npc_id := "") -> void:
	if screen != "playing" or not Childhood.enabled(model.data):
		return
	model.set_player_position(world.get_player_position())
	if not world.can_talk_childhood(npc_id):
		ui.notify("Geh zur Person oder zum angezeigten Ort. Türen und Wände trennen das Gespräch.")
		return
	childhood_npc = npc_id
	screen = "childhood_dialog"
	world.set_active(false)
	if not npc_id.is_empty():
		world.focus_village_npc(npc_id)
	var dialog: Dictionary = model.get_childhood_dialog(npc_id)
	dialog["close_action"] = "childhood_close"
	dialog["kicker"] = "DEIN DORF · TAG %d" % int(model.get_childhood_view().day)
	ui.show_frontier_dialog(dialog)


func _childhood_command(command: String, args: Dictionary) -> void:
	if screen != "childhood_dialog" or command != "childhood_choose":
		return
	var result := _command(command, args)
	var dialog: Dictionary = model.get_childhood_dialog(childhood_npc)
	dialog["feedback"] = str(result.get("message", ""))
	dialog["close_action"] = "childhood_close"
	dialog["kicker"] = "DEIN DORF · TAG %d" % int(model.get_childhood_view().day)
	ui.show_frontier_dialog(dialog)


func _show_childhood_journal() -> void:
	if screen not in ["playing", "paused"] or not Childhood.enabled(model.data):
		return
	screen = "childhood_journal"
	world.set_active(false)
	var view: Dictionary = model.get_childhood_view()
	var text := str(view.get("text", "")) + "\n\nTag %d · %d Jahre\n\n" % [view.day, view.age]
	for receipt: Dictionary in view.get("journal", []):
		var scene_id := str(receipt.get("scene_id", ""))
		if scene_id == "night_resolution":
			text += "• Die Nacht des Überfalls: " + ("Julia lebt. Silvanus und Sextus sind tot." if receipt.choice == "mother_survived" else "Julia, Silvanus und Sextus sind tot.") + "\n"
		elif Childhood.SCENES.has(scene_id):
			var scene: Dictionary = Childhood.SCENES[scene_id]
			for choice: Array in scene.choices:
				if str(choice[0]) == str(receipt.get("choice", "")):
					text += "• %s: %s\n" % [scene.title, choice[1]]
	if view.get("journal", []).is_empty():
		text += "Dein erster Morgen beginnt zu Hause bei Julia."
	ui.show_frontier_dialog({"title":str(view.get("title", "Dein Weg im Dorf")),"kicker":"MEIN WEG",
		"text":text,"choices":[],"close_action":"childhood_close"})


func _show_trade() -> void:
	if screen not in ["playing", "village_dialog", "trade_dialog"] or not Childhood.enabled(model.data):
		return
	model.set_player_position(world.get_player_position())
	if not world.can_trade():
		ui.notify("Cassia handelt mit dir, wenn du an ihrem Stand bist.")
		return
	screen = "trade_dialog"
	world.set_active(false)
	ui.show_frontier_dialog(_trade_dialog())


func _trade_dialog(feedback := "") -> Dictionary:
	var view: Dictionary = VillageTrade.view(model.data)
	return {"title":"Cassias Marktstand", "kicker":"VORRÄTE UND MÜNZEN", "text":str(view.get("text", "")),
		"npc_id":"cassia","choices":view.get("choices", []),"close_action":"trade_close","feedback":feedback}


func _trade_command(command: String, args: Dictionary) -> void:
	if screen != "trade_dialog" or command not in ["village_trade_buy", "village_trade_sell"]:
		return
	var result := _command(command, args)
	ui.show_frontier_dialog(_trade_dialog(str(result.get("message", ""))))


func _show_village_panel(tab := "overview") -> void:
	if not session_started or not model.data.get("village", {}).get("enabled", false):
		return
	if screen not in ["playing", "village_panel", "paused"]:
		return
	village_tab = tab if tab in ["overview", "work", "people", "map"] else "overview"
	screen = "village_panel"
	world.set_active(false)
	world.clear_frontier_focus()
	ui.show_village_panel(_ui_state(), village_tab)


func _show_village_npc(npc_id: String) -> void:
	if screen != "playing" or not VillageLife.NPCS.has(npc_id):
		return
	model.set_player_position(world.get_player_position())
	var at: Vector2 = VillageLife.actor_position(model.data, npc_id)
	var player: Vector3 = world.get_player_position()
	if Vector2(player.x, player.z).distance_to(at) > VillageLife.RANGE:
		ui.notify("Geh näher, um das Gespräch zu beginnen.")
		return
	if not model.data.village.social.npcs[npc_id].met:
		var result := _command("village_talk", {"npc_id":npc_id, "choice":"meet"})
		if not result.get("ok", false):
			return
	village_npc = npc_id
	screen = "village_dialog"
	world.set_active(false)
	world.focus_village_npc(npc_id)
	var dialog := VillageLife.dialogue(model.data, npc_id)
	if npc_id == "cassia" and Childhood.enabled(model.data):
		dialog.choices.append({"id":"open_trade","label":"Waren und Preise ansehen","action":"trade_open","payload":{}})
	ui.show_village_dialog(dialog)
	print("IMPERATHEN_VILLAGE_DIALOG: " + npc_id)


func _village_command(command: String, args: Dictionary) -> void:
	if not command.begins_with("village_") or screen not in ["playing", "village_panel", "village_dialog"]:
		return
	var previous_screen := screen
	var result := _command(command, args)
	if previous_screen == "village_panel":
		var state := _ui_state()
		state["village_feedback"] = str(result.get("message", ""))
		ui.show_village_panel(state, village_tab)
	elif previous_screen == "village_dialog" and not village_npc.is_empty():
		world.focus_village_npc(village_npc)
		var dialog := VillageLife.dialogue(model.data, village_npc)
		dialog["feedback"] = str(result.get("message", ""))
		ui.show_village_dialog(dialog)


func _show_frontier(npc_id: String) -> void:
	if screen != "playing":
		return
	var dialog: Dictionary = model.get_frontier_dialog(npc_id)
	if dialog.is_empty():
		var person: Dictionary = world.get_frontier_npc_info(npc_id)
		if person.is_empty():
			return
		var delta: Vector3 = world.get_player_position() - world.get_frontier_npc_position(npc_id)
		if Vector2(delta.x, delta.z).length() > 3.0:
			ui.notify("Geh näher, um das Gespräch zu beginnen.")
			return
		dialog = {"npc_id": npc_id, "title": "%s · %s" % [person.get("name", "Dorfbewohner"), person.get("occupation", "")], "text": str(person.get("greeting", "Guten Tag. Auf dem Markt erfährst du, was unser Dorf bewegt.")), "choices": []}
	else:
		var result := _command("frontier_talk", {"npc_id": npc_id})
		if not result.get("ok", false):
			return
		dialog = model.get_frontier_dialog(npc_id)
	frontier_npc = npc_id
	screen = "frontier_dialog"
	world.set_active(false)
	world.focus_frontier_npc(npc_id)
	ui.show_frontier_dialog(dialog)
	print("IMPERATHEN_FRONTIER_DIALOG: " + npc_id)


func _choose_frontier(payload: Dictionary) -> void:
	if screen != "frontier_dialog" or frontier_npc.is_empty():
		return
	if payload.get("npc_id") != frontier_npc or not payload.get("choice") is String:
		ui.notify("Diese Antwort gehört nicht zum geöffneten Gespräch.")
		return
	_command("frontier_choice", {"npc_id": frontier_npc, "choice": payload.choice})
	var dialog: Dictionary = model.get_frontier_dialog(frontier_npc)
	if dialog.is_empty():
		_resume()
	else:
		ui.show_frontier_dialog(dialog)


func _show_companion() -> void:
	var companion: Dictionary = model.data.get("companion", {})
	if not str(companion.get("choice", "")).is_empty():
		ui.notify(OpeningStory.companion_reply(model.data))
		return
	screen = "dialog"
	world.set_active(false)
	var dialogue: Dictionary = OpeningStory.companion_dialog(model.data)
	ui.show_dialog(str(dialogue.title), str(dialogue.text), dialogue.choices)


func _begin_opening(sequence: Dictionary, start_index: int = 0) -> void:
	_release_opening()
	if sequence.get("beats", []).is_empty():
		screen = "playing"
		_resume()
		return
	frontier_npc = ""
	world.clear_frontier_focus()
	opening_sequence = sequence.duplicate(true)
	var beats: Array = opening_sequence.beats
	beats.append({"id": "objective_handoff", "shot_id": "player", "speaker": "", "role": "",
		"text": str(sequence.get("objective_text", "")), "duration": 0.0,
		"chapter": str(sequence.get("title", "")), "location": str(sequence.get("location", "")),
		"objective": true, "final": true,
		"objective_title": str(sequence.get("objective_title", "Dein nächster Schritt")),
		"objective_text": str(sequence.get("objective_text", "")),
		"advance_label": "Zur Ausbildung" if int(model.data.player.age) >= 18 else "Ins Dorf"})
	screen = "opening"
	mode = "person"
	world.set_mode(mode)
	world.set_active(false)
	world.set_build_mode(false)
	world.prepare_cinematic_camera()
	ui.show_cinematic()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var preferences: Dictionary = ui.opening_preferences()
	opening_manual = bool(preferences.get("manual_reading", false))
	opening_index = clampi(start_index, 0, beats.size() - 1)
	opening_paused = false
	opening_checkpoint_failed = false
	opening_director = OpeningDirector.new()
	add_child(opening_director)
	opening_director.setup(world)
	opening_overlay = OpeningOverlay.new()
	add_child(opening_overlay)
	opening_overlay.configure(preferences)
	opening_overlay.advance_requested.connect(_opening_next)
	opening_overlay.pause_requested.connect(func(): _opening_set_paused(not opening_paused))
	opening_overlay.skip_requested.connect(_opening_skip)
	opening_overlay.reading_mode_changed.connect(_opening_reading_changed)
	_opening_present()
	print("IMPERATHEN_OPENING_STARTED " + str(opening_sequence.id))


func _opening_present() -> void:
	if screen != "opening" or not is_instance_valid(opening_overlay):
		return
	var beat: Dictionary = opening_sequence.beats[opening_index]
	opening_elapsed = 0.0
	opening_overlay.present(beat, opening_index, opening_sequence.beats.size())
	opening_overlay.set_paused(opening_paused)
	opening_director.play(str(beat.shot_id), maxf(0.1, float(beat.duration)), bool(ui.opening_preferences().reduce_motion))
	# One clock drives subtitle timing and camera travel. Reading mode can hold
	# the finished composition without skipping a sentence or simulating time.
	opening_director.set_process(false)
	opening_director.set_paused(opening_paused)
	if bool(beat.get("final", false)):
		opening_director.sample(str(beat.shot_id), 1.0)
		opening_overlay.set_progress(1.0)
	else:
		opening_overlay.set_progress(0.0)
	_write_opening_checkpoint(false)
	_log_opening_geometry.call_deferred()


func _opening_process(delta: float) -> void:
	if opening_paused or not is_instance_valid(opening_overlay):
		return
	var beat: Dictionary = opening_sequence.beats[opening_index]
	if bool(beat.get("final", false)):
		return
	var duration := maxf(0.1, float(beat.duration))
	opening_elapsed = minf(duration, opening_elapsed + maxf(0.0, delta))
	opening_director.sample(str(beat.shot_id), opening_elapsed / duration)
	opening_overlay.set_progress(opening_elapsed / duration)
	if opening_elapsed >= duration and not opening_manual:
		_opening_next()


func _opening_next() -> void:
	if screen != "opening" or opening_paused:
		return
	if opening_index >= opening_sequence.beats.size() - 1:
		_opening_finish()
		return
	opening_index += 1
	_opening_present()


func _opening_skip() -> void:
	if screen != "opening":
		return
	# Skipping cinematics still explains the objective, then waits for the player.
	opening_index = opening_sequence.beats.size() - 1
	opening_paused = false
	_opening_present()


func _opening_set_paused(value: bool) -> void:
	if screen != "opening":
		return
	opening_paused = value
	if is_instance_valid(opening_overlay):
		opening_overlay.set_paused(value)
	if is_instance_valid(opening_director):
		opening_director.set_paused(value)
	_log_opening_geometry.call_deferred()


func _log_opening_geometry() -> void:
	if not OS.is_debug_build() or screen != "opening":
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if screen != "opening" or not is_instance_valid(opening_overlay):
		return
	var buttons := {}
	for name_key: String in ["OpeningSkip", "OpeningAdvance", "OpeningPause"]:
		var button := opening_overlay.find_child(name_key, true, false) as Button
		if button != null and button.is_visible_in_tree():
			var point: Vector2 = get_viewport().get_screen_transform() * button.get_global_rect().get_center()
			buttons[name_key] = [point.x, point.y]
	print("IMPERATHEN_OPENING_READY " + JSON.stringify({"sequence": str(opening_sequence.id),
		"index": opening_index, "final": opening_index == opening_sequence.beats.size() - 1,
		"paused": opening_paused, "elapsed": opening_elapsed, "world_seconds": model.data.world_seconds,
		"companion_choice": model.data.companion.choice, "buttons": buttons}))


func _opening_reading_changed(value: bool) -> void:
	opening_manual = value
	ui.set_opening_reading(value)


func _write_opening_checkpoint(completed: bool) -> void:
	if opening_sequence.is_empty() or model == null:
		return
	var result := OpeningCheckpoint.write(str(model.data.world_id), str(opening_sequence.id), opening_index, completed)
	opening_checkpoint_failed = result != OK


func _restore_opening() -> bool:
	var checkpoint: Dictionary = OpeningCheckpoint.read(str(model.data.world_id))
	if checkpoint.is_empty() or bool(checkpoint.completed):
		return false
	var sequence: Dictionary = OpeningStory.sequence(str(model.data.origin_id)) if int(model.data.player.age) < 18 else OpeningStory.adulthood(model.data)
	if Childhood.enabled(model.data):
		sequence = ChildhoodOpening.sequence()
	if sequence.is_empty() or str(sequence.id) != str(checkpoint.sequence_id):
		return false
	if int(checkpoint.index) > sequence.beats.size():
		return false
	_begin_opening(sequence, int(checkpoint.index))
	return true


func _opening_finish() -> void:
	if screen != "opening":
		return
	_write_opening_checkpoint(true)
	var checkpoint_failed := opening_checkpoint_failed
	_release_opening()
	screen = "playing"
	_resume()
	if checkpoint_failed:
		ui.notify("Der Vorspann-Fortschritt konnte nicht gespeichert werden. Beim Fortsetzen kann die Szene erneut erscheinen.")
	print("IMPERATHEN_OPENING_COMPLETE")


func _release_opening() -> void:
	if is_instance_valid(opening_director):
		opening_director.finish()
		opening_director.queue_free()
	opening_director = null
	if is_instance_valid(opening_overlay):
		opening_overlay.finish()
		opening_overlay.queue_free()
	opening_overlay = null
	opening_sequence = {}
	opening_paused = false


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
	valley.hud.requested.connect(func(action: String, arg: String):
		if action == "quality":
			ui.set_quality(arg)
	)
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
