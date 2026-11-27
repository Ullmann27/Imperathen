extends Node

const AudioBuses = preload("res://scripts/audio/audio_buses.gd")
const DialoguePlayer = preload("res://scripts/audio/dialogue_player.gd")
const VoiceLines = preload("res://scripts/audio/voice_lines.gd")
const FaceDriver = preload("res://scripts/audio/face_driver.gd")
const ModelScript = preload("res://scripts/domain/world_model.gd")
const GearMarket = preload("res://scripts/domain/gear_market.gd")
const WorldScript = preload("res://scripts/world/game_world.gd")
const Allegiance = preload("res://scripts/domain/campaign_allegiance.gd")
const TravelParty = preload("res://scripts/domain/travel_party.gd")
const UIScript = preload("res://scripts/ui/game_ui.gd")
const AtlasScreen = preload("res://scripts/strategy/atlas_screen.gd")
const Seasons = preload("res://scripts/strategy/season_campaign.gd")
const Origins = preload("res://scripts/strategy/origins.gd")
const ValleyScene = preload("res://scripts/tactics/valley_scene.gd")
const OpeningStory = preload("res://scripts/story/opening_story.gd")
const MissionCinematics = preload("res://scripts/story/mission_cinematics.gd")
const OpeningDirector = preload("res://scripts/cinematic/opening_director.gd")
const OpeningOverlay = preload("res://scripts/ui/opening_overlay.gd")
const OpeningCheckpoint = preload("res://scripts/cinematic/opening_checkpoint.gd")
const VillageLife = preload("res://scripts/story/village_life.gd")
const VillageEconomy = preload("res://scripts/domain/village_economy.gd")
const CombatActions = preload("res://scripts/domain/combat_actions.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const NpcBehavior = preload("res://scripts/domain/npc_behavior.gd")
const CityExploration = preload("res://scripts/world/city_exploration.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const I01Film = preload("res://scripts/story/i01_film.gd")
const I03 = preload("res://scripts/story/i03_shortcut.gd")
const I03Film = preload("res://scripts/story/i03_film.gd")
const I04Film = preload("res://scripts/story/i04_film.gd")
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
var opening_voice := DialoguePlayer.new()
var opening_voice_duration := 0.0
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
var gear_shop := "market"
var simulation_elapsed := 0.0
var city_exploration
var _campaign_market_visit := false
## True only while a film choice beat commits its childhood action.
var _film_committing := false


func _init() -> void:
	add_child(opening_voice)


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
	model.combat_sight_check = world.combat_sight_clear
	model.npc_sight_check = world.npc_sight_clear
	model.combat_motion_check = world.combat_safe_motion
	model.npc_observations = world.npc_observations
	model.raid_observations = world.raid_observations
	world.set_raid_physics_authority(true)
	world.set_active(false)
	world.set_mode("city")
	ui = UIScript.new()
	add_child(ui)
	ui.action_requested.connect(_on_ui_action)
	world.hud_prompts = true
	world.set_quality(ui.get_quality())
	_setup_ambient()
	# The title sequence is opaque; the village is not drawn underneath it.
	world.hide()
	if "--city-test" in OS.get_cmdline_user_args():
		screen = "menu"
		_open_city_exploration()
		return
	ui.show_intro()
	if OS.is_debug_build() and OS.has_feature("android"):
		var diagnostics = preload("res://scripts/ui/android_village_diagnostics.gd").new()
		diagnostics.session = self
		add_child(diagnostics)
	print("IMPERATHEN_READY: Godot prototype, intro -> menu -> persistent frontier loop")


func _process(delta: float) -> void:
	if screen == "city_exploration":
		return
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
		world.set_frontier_time(float(model.data.world_seconds))
		# Compass, local map and the context action follow the live world.
		ui.update_navigation(world.navigation_view())
		autosave_elapsed += delta
		if autosave_elapsed >= 45.0:
			autosave_elapsed = 0.0
			_save(false)
	refresh_elapsed += delta
	if refresh_pending and refresh_elapsed >= 0.12:
		_refresh()


func _physics_process(delta: float) -> void:
	if screen != "playing" or not is_instance_valid(world):
		return
	# Geometry queries, authoritative motion and contact windows share the
	# physics clock. Rendering or a slow UI refresh cannot create extra hits.
	model.set_player_position(world.get_player_position())
	if Childhood.enabled(model.data):
		simulation_elapsed += delta
		var fighting := CombatActions.busy(model.data) or bool(model.data.village.raid.active) or bool(model.data.encounter.active)
		if fighting or simulation_elapsed + 0.000001 >= 0.1:
			_flush_simulation()
	else:
		model.advance(delta)
	world.sync_combat_state(model.data)


func _flush_simulation() -> void:
	if simulation_elapsed <= 0.0 or not is_instance_valid(world):
		return
	var elapsed := simulation_elapsed
	simulation_elapsed = 0.0
	model.set_player_position(world.get_player_position())
	model.advance(elapsed)
	world.sync_combat_state(model.data)


func _unhandled_input(event: InputEvent) -> void:
	if screen == "city_exploration":
		return
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
	if screen == "city_exploration" and is_instance_valid(city_exploration):
		if city_exploration.market.is_open():
			city_exploration.market.close()
		else:
			city_exploration.set_paused(not city_exploration.paused)
	elif screen == "opening" and is_instance_valid(opening_overlay):
		opening_overlay.handle_back()
	elif screen == "atlas":
		_leave_atlas()
	elif screen == "valley":
		_leave_valley()
	elif is_instance_valid(ui):
		ui.handle_back()


func _notification(what: int) -> void:
	if screen == "city_exploration" and is_instance_valid(city_exploration):
		if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
			city_exploration.set_paused(true)
		elif what == NOTIFICATION_WM_CLOSE_REQUEST:
			if city_exploration.save_state() == OK:
				get_tree().quit()
		return
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
	world.set_political_context(model.politics_view())
	ui.update_state(_ui_state())
	ui.set_build_active(world.is_build_active())
	if screen == "playing":
		_check_special_dialog()


func _ui_state() -> Dictionary:
	# Presentation data is derived from the authoritative chapter and never saved.
	var state: Dictionary = model.data.duplicate(true)
	state["can_visit_market"] = _can_visit_market()
	state["frontier_objective"] = model.get_frontier_objective()
	if state.get("village", {}).get("enabled", false):
		state["village_view"] = VillageLife.view(model.data)
		state["village_economy_view"] = VillageEconomy.view(model.data)
		state["childhood_view"] = Childhood.view(model.data)
		state["combat_view"] = CombatActions.view(model.data)
		state["running"] = world.is_running()
	return state


func _show_menu() -> void:
	_release_opening()
	frontier_npc = ""
	world.clear_frontier_focus()
	screen = "menu"
	world.show()
	world.set_active(false)
	world.set_mode("city")
	world.set_menu_flight(not bool(ui.opening_preferences().get("reduce_motion", false)))
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
	# The player-facing entry is the only regular start: no own money (Game
	# Direction 26.11.2026); development/test worlds keep their named fund.
	model.new_game(ui.origin_id, true, true, false, true)
	simulation_elapsed = 0.0
	last_story_id = ""
	world.setup(model.data)
	session_started = true
	autosave_elapsed = 0.0
	mode = "person"
	world.set_active(false)
	var saved := _save(false)
	if saved.get("ok", false):
		_begin_opening(OpeningStory.historical_prologue() if Childhood.enabled(model.data) else OpeningStory.sequence(str(model.data.origin_id)))
		print("IMPERATHEN_SESSION_STARTED: saved frontier world")
	else:
		_resume()


func _continue_game() -> void:
	simulation_elapsed = 0.0
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
	_flush_simulation()
	screen = "paused"
	world.set_active(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.show_pause()
	print("IMPERATHEN_PAUSED")


func _save(show_feedback: bool = true) -> Dictionary:
	if not session_started:
		return {"ok": false, "message": "Es läuft noch keine Partie."}
	_flush_simulation()
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
		"touch_camera_managed": world.set_touch_camera_managed(bool(payload.get("enabled", false)))
		"movement_pace":
			if screen == "playing":
				world.set_running(bool(payload.get("running", false)))
		"select_technique": world.set_selected_technique(str(payload.get("technique", "jab_left")))
		"camera_look":
			if screen == "playing":
				world.apply_camera_look(Vector2(float(payload.get("x", 0)), float(payload.get("y", 0))))
		"camera_zoom":
			if screen == "playing":
				world.apply_camera_zoom(float(payload.get("factor", 1.0)))
		"village_unarmed_guard", "village_unarmed_dodge":
			if screen == "playing":
				_command(action, {})
		"combat_palette":
			if screen == "playing":
				ui.show_combat_palette(_ui_state())

		"gear_panel": _show_gear_panel(str(payload.get("shop_id", "market")))
		"gear_command": _gear_command(str(payload.get("command", "")), payload.get("args", {}))
		"party_folio", "party_wheel": _show_party(action)
		"party_command": _party_command(str(payload.get("command", "")), payload.get("args", {}))
		"village_panel": _show_village_panel(str(payload.get("tab", "overview")))
		"village_command": _village_command(str(payload.get("command", "")), payload.get("args", {}))
		"village_close": _resume()
		"village_block", "village_dodge":
			if screen == "playing":
				var defense_result := _command(action, {})
				if defense_result.get("ok", false):
					world.cue_village_defense(action)
		"atlas_demo": _open_atlas(true)
		"city_exploration": _open_city_exploration(false, false, true)
		"imperial_city_exploration": _open_city_exploration(false, false, true, true)
		"campaign_market": _open_city_exploration(true)
		"regional_goal":
			if screen == "village_panel":
				world.select_route(str(payload.get("id","mission")))
				_resume()
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
		"map_route":
			if screen=="playing" and mode=="map":
				world.select_route(str(payload.get("id","mission")))
				_set_mode("person")
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
				world.perform_attack(str(payload.get("technique", "")))
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
			# Legacy careers only. The childhood decides nothing about Marcus by
			# a button; I-03 stores what actually happened on the market errand.
			if Childhood.enabled(model.data):
				return
			var companion_result := _command("choose_companion", {"choice": "help" if action == "companion_help" else "decline"})
			if companion_result.get("ok", false):
				ui.notify(OpeningStory.companion_reply(model.data))
			else:
				_show_companion()
		"i01_contact_marcus":
			_resume()
			_command("village_childhood_action", {"action_id":"i01_contact_marcus"})
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
	if action == "combat_interrupt":
		_flush_simulation()
		model.interrupt_combat()
		return
	if action == "build_mode_changed":
		if ui != null:
			ui.set_build_active(bool(payload.get("active", false)))
		return
	if screen != "playing":
		return
	match action:
		"village_unarmed_attack":
			_command(action, payload)
		"companion_interact": _show_companion()
		"village_npc": _show_village_npc(str(payload.get("npc_id", "")))
		"village_panel": _show_village_panel("overview")
		"freight_receipt": ui.notify(preload("res://scripts/domain/regional_freight.gd").status(model.data.village.economy))
		"waystation_market":
			if world.at_waystation() and _can_visit_market():
				_open_city_exploration(true,true)
			else:
				ui.notify("Die Reise zum Stadtmarkt ist während dieser Aufgabe unterbrochen.")
		"politics_records": _show_council_records()
		"combat_palette": _on_ui_action(action,payload)
		"village_block", "village_dodge": _on_ui_action(action, payload)
		"frontier_talk": _show_frontier(str(payload.get("npc_id", "")))
		"mode_person", "mode_city", "mode_map": _on_ui_action(action, payload)
		"pause": _pause()
		_:
			_command(action, payload)


func _command(command: String, payload: Dictionary) -> Dictionary:
	var chapter_choice := screen == "frontier_dialog" and command == "frontier_choice"
	var political_choice := screen == "village_dialog" and village_npc == "decimus" and command in ["politics_help", "politics_audience"]
	var party_choice := screen in ["party_wheel","party_folio","village_dialog","dialog"] and (command == "choose_adult_path" or TravelParty.COMMAND_FIELDS.has(command) or Allegiance.COMMAND_FIELDS.has(command))
	var village_choice := screen in ["village_panel", "village_dialog"] and command.begins_with("village_")
	var gear_choice := screen == "gear_panel" and GearMarket.COMMAND_FIELDS.has(command)
	if screen != "playing" and not chapter_choice and not village_choice and not political_choice and not party_choice and not gear_choice and not _film_committing:
		return {"ok": false, "message": "Die Welt ist pausiert."}
	if command == "village_childhood_action" and screen == "playing" and is_instance_valid(world.i01_props) and world.i01_props.water_interaction_active() and str(payload.get("action_id","")) != "i01_meal":
		return {"ok":false,"message":"Warte, bis die Wasserhandlung abgeschlossen ist."}
	_flush_simulation()
	model.set_player_position(world.get_player_position())
	command_serial += 1
	var realtime_combat := CombatActions.COMMAND_FIELDS.has(command)
	# Real-time button presses are guarded by the active movement, not stored
	# as thousands of permanent economic orders. Their consequences are saved.
	var command_id := "" if realtime_combat else "%s_%d" % [run_id, command_serial]
	var political_command := command.begins_with("politics_")
	var investigation_command := command.begins_with("village_investigation_")
	var durable_change := command in ["choose_adult_path","village_dispatch_grain"] or investigation_command or political_command or TravelParty.COMMAND_FIELDS.has(command) or Allegiance.COMMAND_FIELDS.has(command) or gear_choice
	var previous_data: Dictionary = model.data.duplicate(true) if durable_change else {}
	if command == "village_childhood_action" or party_choice or investigation_command:
		# Presence checks (Marcus at the lane or the stall) use the bodies as
		# they stand now, not an older observation.
		model.capture_npc_observations()
	var previous_childhood_step: Dictionary = Childhood.current_step(model.data) if command == "village_childhood_action" and Childhood.enabled(model.data) else {}
	var result: Dictionary = model.execute(command, payload, command_id)
	if result.get("ok",false) and command == "village_childhood_action" and is_instance_valid(world.i01_props):
		world.i01_props.begin_jug_action(str(payload.get("action_id","")))
	if not _film_committing and (not result.get("ok", false) or (not realtime_combat and command not in ["receive_damage", "train"])):
		ui.notify(str(result.get("message", "")))
	_refresh()
	var persisted := true
	if result.get("ok", false) and (command in ["choose_companion", "train", "recruit", "resolve_skirmish", "choose_story", "frontier_talk", "frontier_choice"] or (command.begins_with("village_") and not realtime_combat and command not in ["village_strike", "village_block", "village_dodge"]) or durable_change or model.data.progress.stage in ["aftermath", "fallen"]):
		persisted = bool(_save(false).get("ok", false))
		if durable_change and not persisted:
			model.data = previous_data
			_refresh()
			var save_feedback := "Decimus' Eintrag konnte nicht gespeichert werden. Die Änderung wurde zurückgenommen." if political_command else "Der Gefährtenauftrag konnte nicht gespeichert werden. Die Änderung wurde zurückgenommen."
			if investigation_command:
				save_feedback = "Die Aussage konnte nicht gespeichert werden. Sie wurde zurückgenommen."
			if gear_choice:
				save_feedback = "Die Ausrüstungsbuchung konnte nicht gespeichert werden. Sie wurde zurückgenommen."
			if command == "village_dispatch_grain":
				save_feedback = "Der Ladeschein konnte nicht gespeichert werden. Getreide und Denare bleiben am Ausgangsort."
			ui.notify(save_feedback)
			return {"ok": false, "message": save_feedback}
	# The return with water starts the next film; do not make the boy repeat
	# breakfast as a second interaction after his actual pouring action.
	if result.get("ok",false) and persisted and screen == "playing" and command == "village_childhood_action" and str(payload.get("action_id","")) == "i01_pour":
		world.i01_props.begin_film_pour()
		var breakfast := _command("village_childhood_action",{"action_id":"i01_meal"})
		if not breakfast.get("ok",false):
			world.i01_props.settle_film_pour()
		return result
	if result.get("ok", false) and command == "train" and not Childhood.enabled(model.data):
		if persisted:
			_begin_opening(OpeningStory.adulthood(model.data))
		else:
			pending_opening = OpeningStory.adulthood(model.data)
			_pause()
	elif result.get("ok",false) and not previous_childhood_step.is_empty() and not _film_committing:
		var transition := MissionCinematics.sequence_for(model.data,previous_childhood_step,Childhood.current_step(model.data))
		if not transition.is_empty():
			if persisted:
				_begin_opening(transition)
			else:
				pending_opening = transition
				_pause()
	return result


func _refresh_gear_sites() -> void:
	model.gear_sites = {}
	var here: Vector3 = world.get_player_position()
	var residents: Node3D = world.village_life_world
	if is_instance_valid(residents):
		for shop_id: String in ["market", "smith", "outfitter"]:
			var npc_id: String = {"market": "cassia", "smith": "sextus", "outfitter": "severus"}[shop_id]
			var actor: Variant = residents.actors.get(npc_id)
			if is_instance_valid(actor) and actor.visible and VillageLife.is_available(model.data, npc_id):
				var at: Vector3 = residents.actor_position(npc_id)
				if at.is_finite() and (here.distance_to(at) > GearMarket.RANGE or world.npc_sight_clear(here, at)):
					model.gear_sites[shop_id] = at
	if Childhood.enabled(model.data):
		var point: Vector2 = Childhood.POINTS["family_rest"]
		model.gear_sites["home"] = Vector3(point.x, 1.2925, point.y)


func _show_gear_panel(shop_id: String = "market", feedback: String = "") -> void:
	if not session_started or screen not in ["paused", "gear_panel"]:
		return
	if int(model.data.player.get("age", 0)) < 18 or not model.data.village.get("enabled", false):
		return
	var catalog := GearMarket.catalog()
	if not catalog.get("errors", []).is_empty() or not catalog.shops.has(shop_id):
		ui.notify("Der Ausrüstungskatalog ist nicht verfügbar.")
		return
	_flush_simulation()
	world.set_active(false)
	screen = "gear_panel"
	gear_shop = shop_id
	model.set_player_position(world.get_player_position())
	_refresh_gear_sites()
	if not GearMarket.enabled(model.data):
		var result := _command("gear_enable", {})
		if not result.get("ok", false):
			_pause()
			ui.notify(str(result.get("message", "")))
			return
	ui.show_gear_panel(GearMarket.view(model.data, gear_shop, model.gear_sites), feedback)


func _gear_command(command: String, args: Dictionary) -> void:
	if screen != "gear_panel" or not GearMarket.COMMAND_FIELDS.has(command) or command == "gear_enable":
		return
	_refresh_gear_sites()
	var result := _command(command, args)
	_show_gear_panel(gear_shop, str(result.get("message", "")))


func _show_party(page: String, feedback := "") -> void:
	if not session_started or screen not in ["playing","party_wheel","party_folio"]:
		return
	_flush_simulation()
	world.set_active(false)
	screen = page
	var data: Dictionary = model.party_view()
	var figures := {}
	if page == "party_folio":
		for member: Dictionary in data.members:
			var uid := str(member.actor_uid)
			var figure_id := "marcus" if uid == TravelParty.FRIEND else TravelParty.local_id(model.data, uid)
			figures[uid] = world.get_cinematic_figure(figure_id)
	ui.show_party(page, data, figures, feedback)


func _party_command(command: String, args: Dictionary) -> void:
	if command != "choose_adult_path" and not TravelParty.COMMAND_FIELDS.has(command) and not Allegiance.COMMAND_FIELDS.has(command):
		return
	var uid := str(args.get("actor_uid", ""))
	var invite := command in ["party_invite","party_hire","party_mend"]
	if invite:
		if (screen != "village_dialog" or uid != "vil:" + village_npc) and (screen != "dialog" or village_npc != model.data.companion.id or uid != TravelParty.FRIEND):
			return
	elif screen not in ["party_wheel","party_folio"]:
		return
	var result := _command(command, args)
	var message := str(result.get("message", ""))
	if invite or (screen == "party_wheel" and result.get("ok", false)) or (command == "party_train" and result.get("ok", false)):
		_resume()
		ui.notify(message)
	elif screen == "party_folio":
		_show_party(screen, message)


func _invite_choice(uid: String) -> Dictionary:
	if model.data.world_state.get("party", {}).get("members", {}).get(uid, {}).get("status", "") == "active":
		return {}
	var person := TravelParty.resident(model.data, uid)
	if not person.is_empty() and (not person.alive or int(person.health) <= 0):
		return {}
	return {"id":"travel_together", "label":"Um persönliche Begleitung bitten", "command":"party_invite",
		"payload":{"actor_uid":uid}, "enabled":true, "reason":""}


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
	if screen != "playing" or not VillageLife.has_npc(model.data,npc_id):
		return
	model.set_player_position(world.get_player_position())
	model.capture_npc_observations()
	var at: Vector2 = VillageLife.actor_position(model.data, npc_id)
	var player: Vector3 = world.get_player_position()
	if Vector2(player.x, player.z).distance_to(at) > VillageLife.RANGE:
		ui.notify("Geh näher, um das Gespräch zu beginnen.")
		return
	if not VillageLife.relationship(model.data,npc_id).get("met",false):
		var result := _command("village_talk", {"npc_id":npc_id, "choice":"meet"})
		if not result.get("ok", false):
			return
	village_npc = npc_id
	screen = "village_dialog"
	world.set_active(false)
	world.focus_village_npc(npc_id)
	ui.show_village_dialog(_npc_dialog(npc_id))
	print("IMPERATHEN_VILLAGE_DIALOG: " + npc_id)


func _village_command(command: String, args: Dictionary) -> void:
	if command.begins_with("village_investigation_") and (screen != "village_dialog" or village_npc != str(args.get("npc_id","decimus"))):
		return
	var political_choice := screen == "village_dialog" and village_npc == "decimus" and command in ["politics_help", "politics_audience"]
	if command in ["party_invite","party_hire"]:
		_party_command(command, args)
		return
	if not political_choice and (not command.begins_with("village_") or screen not in ["playing", "village_panel", "village_dialog"]):
		return
	var previous_screen := screen
	var result := _command(command, args)
	if screen == "opening" or screen == "paused":
		return
	if previous_screen == "village_panel":
		var state := _ui_state()
		state["village_feedback"] = str(result.get("message", ""))
		ui.show_village_panel(state, village_tab)
	elif previous_screen == "village_dialog" and not village_npc.is_empty():
		world.focus_village_npc(village_npc)
		var dialog := _npc_dialog(village_npc)
		dialog["feedback"] = str(result.get("message", ""))
		ui.show_village_dialog(dialog)


func _npc_dialog(npc_id: String) -> Dictionary:
	var dialog := VillageLife.dialogue(model.data, npc_id)
	if not Childhood.companion_specs(model.data).has(npc_id):
		dialog = _dialog_with_behavior(dialog, npc_id)
	if npc_id == "decimus" and VillageLife.relationship(model.data, npc_id).get("met", false):
		_append_political_choices(dialog, model.politics_view())
	if VillageLife.has_npc(model.data,npc_id) and not TravelParty.protected(model.data):
		var uid := "vil:" + npc_id
		var invite := _invite_choice(uid)
		if not invite.is_empty():
			var bond := VillageLife.relationship(model.data, npc_id)
			if (npc_id == "silvanus" and Childhood.enabled(model.data)) or TravelParty.willing_resident(model.data,uid):
				dialog.choices.append(invite)
			if npc_id in ["aurelia","varro"] and bond.get("met", false):
				var role := "Heilerin" if npc_id == "aurelia" else "Ortskundigen"
				dialog.choices.append({"id":"hire_specialist", "command":"party_hire",
					"label":"Als %s anwerben · 2 Denare pro Tag" % role, "payload":{"actor_uid":uid}})
	return dialog


func _append_political_choices(dialog: Dictionary, politics: Dictionary) -> void:
	if not bool(politics.get("can_discuss", false)) or dialog.is_empty():
		return
	var choices: Array = dialog.get("choices", [])
	for option: Dictionary in politics.get("options", []):
		if option.command not in ["politics_help", "politics_audience"]:
			continue
		var args: Dictionary = option.get("args", {})
		choices.append({"id": str(option.command) + "_" + str(args.get("route", "")),
			"command": option.command, "payload": args, "label": option.label,
			"enabled": option.enabled, "reason": option.get("reason", "")})
	dialog["choices"] = choices
	var recommendation: Dictionary = politics.get("recommendation", {})
	if recommendation.is_empty():
		dialog["text"] += "\n\nAm Südweg ist eine Bohle locker. Ich brauche Holz für die Reparatur. Wenn du keins hast, schau vom festen Rand aus nach, wo die Auflage fehlt."
	else:
		dialog["text"] += "\n\nDeine Hilfe steht auf meiner Tafel. Meine Empfehlung bleibt. Wenn du erwachsen bist, nehme ich mir Zeit für dein Anliegen."


func _show_council_records() -> void:
	var politics: Dictionary = model.politics_view()
	var recommendation: Dictionary = politics.get("recommendation", {})
	var text := "Südweg · Prüfen, ob die Bohlen am Ablauf fest aufliegen."
	if not recommendation.is_empty():
		var note := "Vier Holzstücke zur Ausbesserung übernommen." if recommendation.route == "wood" else "Meldung über die ausgespülte Auflage angenommen."
		text = "%s\n\nSüdweg · %s\nPersönliche Empfehlung von Decimus vermerkt." % [recommendation.date, note]
		if not str(politics.get("learning", "")).is_empty():
			text += "\nAus der Dorfhilfe gelernt · " + str(politics.learning)
	village_npc = ""
	screen = "village_dialog"
	world.set_active(false)
	ui.show_village_dialog({"title": "Amtstafel · Ratstube von Valdora", "text": text, "choices": []})


func _dialog_with_behavior(original: Dictionary, npc_id: String) -> Dictionary:
	var dialog: Dictionary = original.duplicate(true)
	var behavior: Dictionary = NpcBehavior.view(model.data, npc_id)
	var greeting := str(behavior.get("greeting", ""))
	if not greeting.is_empty() and not dialog.is_empty():
		dialog["text"] = greeting + "\n\n" + str(dialog.get("text", ""))
	return dialog


func _show_frontier(npc_id: String) -> void:
	if screen != "playing":
		return
	var dialog: Dictionary = {} if Childhood.enabled(model.data) else model.get_frontier_dialog(npc_id)
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
	ui.show_frontier_dialog(_dialog_with_behavior(dialog, npc_id))
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
		ui.show_frontier_dialog(_dialog_with_behavior(dialog, frontier_npc))


func _show_companion() -> void:
	var companion: Dictionary = model.data.get("companion", {})
	var childhood_view: Dictionary = Childhood.view(model.data)
	var stage := str(childhood_view.get("stage", ""))
	if Childhood.enabled(model.data) and stage in ["i03_marcus", "i03_farewell"]:
		# I-03 VID-A / VID-C start when the boy actually reaches Marcus. No
		# film, reward or stand-in while Marcus is absent or out of reach.
		model.capture_npc_observations()
		var first_option := "i03_together" if stage == "i03_marcus" else "i03_home_apart"
		var blocked := Childhood.i03_reason(model.data, first_option)
		if not blocked.is_empty():
			ui.notify(blocked)
			return
		var film: Dictionary = I03Film.vid_a(model.data, Childhood.i03_ctx(model.data)) if stage == "i03_marcus" else I03Film.vid_c(model.data, Childhood.i03_ctx(model.data))
		_begin_opening(film)
		return
	if Childhood.enabled(model.data) and not companion.get("met", false) and str(model.data.village.childhood.screenplay.get("i03s", "")) == "pending" and not str(model.data.village.childhood.screenplay.get("i03_route", "")).is_empty():
		# During the errand Marcus has his own business; he only says where he is headed.
		model.capture_npc_observations()
		var boy_at: Vector3 = world.get_player_position()
		var friend_at: Vector3 = world._companion.global_position
		if Vector2(boy_at.x-friend_at.x, boy_at.z-friend_at.z).length() > Childhood.NPC_RANGE or not world._companion.visible:
			ui.notify("Geh näher zu Marcus, um mit ihm zu sprechen.")
			return
		screen = "dialog"
		world.set_active(false)
		world.focus_companion_gaze()
		ui.show_dialog("Marcus · auf dem Weg zum Markt", "»Erst das Salz. Wir sehen uns an Cassias Stand.«", [{"label":"Weitergehen", "action":"resume", "enabled":true, "reason":""}])
		return
	if Childhood.enabled(model.data) and not companion.get("met", false):
		# Before I-03 Marcus only greets. The former hut dialogue ("4 Holz
		# teilen") belongs to legacy careers and never sets a companion choice.
		model.capture_npc_observations()
		var here: Vector3 = world.get_player_position()
		var marcus_at: Vector3 = world._companion.global_position
		if Vector2(here.x-marcus_at.x, here.z-marcus_at.z).length() > Childhood.NPC_RANGE or not world._companion.visible:
			ui.notify("Geh näher zu Marcus, um mit ihm zu sprechen.")
			return
		screen = "dialog"
		world.set_active(false)
		var greeting_choices: Array = []
		var greeting := "»Morgen! Ich muss weiter, der Eimer wartet nicht.«"
		if I01.contact_open(model.data, "marcus"):
			greeting = I01.contact_line("marcus")
			var why := Childhood.i01_reason(model.data, "i01_contact_marcus")
			greeting_choices.append({"label":"Kurz zuhören und antworten", "action":"i01_contact_marcus", "enabled":why.is_empty(), "reason":why})
		greeting_choices.append({"label":"Weitergehen", "action":"resume", "enabled":true, "reason":""})
		world.focus_companion_gaze()
		ui.show_dialog("Marcus · am Brunnen", greeting, greeting_choices)
		return
	if companion.get("met", false):
		model.capture_npc_observations()
		var player: Vector3 = world.get_player_position()
		var at: Vector3 = world._companion.global_position
		if Vector2(player.x-at.x, player.z-at.z).length() > Childhood.NPC_RANGE or not world._companion.visible:
			ui.notify("Geh näher, um das Gespräch zu beginnen.")
			return
		var authored := Childhood.companion_dialogue(model.data, "marcus") if Childhood.enabled(model.data) else {"title":Origins.PEOPLES[model.data.origin_id].companion,"text":OpeningStory.companion_reply(model.data)}
		if authored.is_empty():
			authored = {"title":"Marcus · Valdora", "text":"»Was hast du heute vor?«"}
		var options := []
		var invite := _invite_choice(TravelParty.FRIEND)
		var mending := TravelParty.mending_choice(model.data)
		if not mending.is_empty() and not TravelParty.protected(model.data):
			# Kreative spätere Gesprächsoption. Die ursprünglichen I-03-Zeilen
			# und die dokumentierte Entscheidung bleiben im Drehbuch erhalten.
			var line := "»Mein Tragegestell ist gebrochen. Wenn du mir helfen willst, brauche ich zwei Streben.«"
			var label := "Hilfe beim Tragegestell zusagen"
			if mending == "deliver":
				line = "»Hast du die zwei Holzstücke für unser Tragegestell?«"
				label = "Tragegestell gemeinsam reparieren · 2 Holz"
			authored.text += "\n\n" + line
			options.append({"label":label,"action":"party_command","payload":{"command":"party_mend","args":{"actor_uid":TravelParty.FRIEND,"step":mending}}})
			options.append({"label":"Gespräch beenden","action":"resume"})
		elif not invite.is_empty() and not TravelParty.protected(model.data):
			options.append({"label":invite.label,"action":"party_command","payload":{"command":invite.command,"args":invite.payload}})
			options.append({"label":"Gespräch beenden","action":"resume"})
		screen = "dialog"
		village_npc = str(companion.id)
		world.set_active(false)
		world.focus_companion_gaze()
		world._companion.get_node("Figure").set_conversation_focus(true)
		ui.show_dialog(str(authored.title), str(authored.text), options)
		return
	screen = "dialog"
	world.set_active(false)
	world.focus_companion_gaze()
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
		"advance_label": str(sequence.get("handoff_label","Zur Ausbildung" if int(model.data.player.age) >= 18 else "Ins Dorf"))})
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
	opening_overlay.choice_requested.connect(_opening_choose)
	_opening_present()
	print("IMPERATHEN_OPENING_STARTED " + str(opening_sequence.id))


func _opening_present() -> void:
	if screen != "opening" or not is_instance_valid(opening_overlay):
		return
	var beat: Dictionary = opening_sequence.beats[opening_index]
	if is_instance_valid(world.i01_props) and (opening_sequence.id != I01Film.VID_B or opening_index > 0):
		world.i01_props.settle_film_pour()
	if bool(beat.get("await_choice", false)) and not _film_choice_open(beat) and opening_index < opening_sequence.beats.size() - 1:
		# Resumed after the choice was committed: never offer or commit it twice.
		opening_index += 1
		_opening_present()
		return
	opening_elapsed = 0.0
	var shown: Dictionary = beat.duplicate(true)
	shown["choice_open"] = _film_choice_open(beat)
	opening_overlay.present(shown, opening_index, opening_sequence.beats.size())
	opening_overlay.set_paused(opening_paused)
	var cut := _beat_cut(beat, 0.0)
	# Materialize the actual close rig before the speech driver takes references.
	opening_director.prepare_cinematic_cast(str(cut.shot_id), str(cut.actor_id))
	opening_director.prepare_cinematic_cast(str(cut.shot_id), str(beat.get("speaker_id", "")))
	_update_opening_voice(beat)
	opening_director.mission_actor_id = str(cut.actor_id)
	opening_director.focus_key = str(beat.get("anchor", ""))
	opening_director.speaking = _film_actor_speaks(beat,str(cut.actor_id))
	opening_director.play(str(cut.shot_id), maxf(0.1, maxf(float(beat.duration), opening_voice_duration) * float(cut.span)), bool(ui.opening_preferences().reduce_motion))
	# One clock drives subtitle timing and camera travel. Reading mode can hold
	# the finished composition without skipping a sentence or simulating time.
	opening_director.set_process(false)
	opening_director.set_paused(opening_paused)
	if bool(beat.get("final", false)):
		opening_director.sample(str(cut.shot_id), 1.0)
		opening_overlay.set_progress(1.0)
	else:
		opening_overlay.set_progress(0.0)
	_write_opening_checkpoint(false)
	_log_opening_geometry.call_deferred()


func _update_opening_voice(beat: Dictionary) -> void:
	_stop_opening_voice()
	if bool(beat.get("silent", false)) or bool(beat.get("final", false)) or bool(beat.get("await_choice", false)):
		return
	var phrase := str(beat.get("text", ""))
	var speaker := str(beat.get("speaker", ""))
	var line := VoiceLines.find(phrase,speaker)
	if line.is_empty() or str(line.speaker_id) != VoiceLines.speaker_id(speaker):
		return
	var stream := VoiceLines.stream_for(line)
	if stream == null:
		return
	var speaker_figure: Node3D = world.get_cinematic_figure(str(line.speaker_id))
	if speaker_figure != null:
		var face := FaceDriver.new()
		face.blink_enabled = false
		face.process_priority = 20
		opening_voice.add_child(face)
		face.bind(speaker_figure)
		opening_voice.face = face
	opening_voice.play(phrase, speaker)
	opening_voice.set_paused(opening_paused)
	opening_voice_duration = stream.get_length()


func _stop_opening_voice() -> void:
	opening_voice.stop()
	if is_instance_valid(opening_voice.face):
		opening_voice.face.queue_free()
		opening_voice.face = null
	opening_voice_duration = 0.0


func _opening_process(delta: float) -> void:
	if opening_paused or not is_instance_valid(opening_overlay):
		return
	var beat: Dictionary = opening_sequence.beats[opening_index]
	if bool(beat.get("final", false)):
		return
	var duration := maxf(0.1, maxf(float(beat.duration), opening_voice_duration))
	opening_elapsed = minf(duration, opening_elapsed + maxf(0.0, delta))
	if opening_sequence.id == I01Film.VID_B and opening_index == 0 and is_instance_valid(world.i01_props):
		world.i01_props.sample_film_pour(opening_elapsed)
	var cut := _beat_cut(beat, opening_elapsed / duration)
	if str(cut.shot_id) != opening_director.shot_id or str(cut.actor_id) != opening_director.mission_actor_id:
		# A cut inside the line (reaction shot): same clock, new composition.
		opening_director.mission_actor_id = str(cut.actor_id)
		opening_director.speaking = _film_actor_speaks(beat,str(cut.actor_id))
		opening_director.play(str(cut.shot_id), maxf(0.1, duration * float(cut.span)), bool(ui.opening_preferences().reduce_motion))
		opening_director.set_process(false)
		opening_director.set_paused(opening_paused)
	opening_director.sample(str(cut.shot_id), float(cut.local))
	opening_overlay.set_progress(opening_elapsed / duration)
	# AwaitChoice holds only this scene (HB S. 29); the composition stays.
	# Silent pauses carry no sentence, so reading mode does not hold them.
	if opening_elapsed >= duration and (not opening_manual or bool(beat.get("silent", false))) and not _film_choice_open(beat):
		_opening_next()


## The shot of a beat at a normalized time. A beat may list "cuts"
## ([{at, shot_id, actor_id}], ascending "at" in 0..1) to change the shot size
## or show a reaction while the same line continues. Returns the shot, the
## actor it frames, the cut's share of the beat and the time inside the cut.
func _film_actor_speaks(beat: Dictionary, actor_id: String) -> bool:
	if bool(beat.get("silent",false)) or bool(beat.get("final",false)) or bool(beat.get("await_choice",false)):
		return false
	var speaker := VoiceLines.speaker_id(str(beat.get("speaker_id",beat.get("speaker",""))))
	if speaker in ["","narrator","player"]:
		return false
	return actor_id.is_empty() or VoiceLines.speaker_id(actor_id) == speaker


func _beat_cut(beat: Dictionary, fraction: float) -> Dictionary:
	var result := {"shot_id":str(beat.shot_id), "actor_id":str(beat.get("actor_id", "")), "span":1.0, "local":clampf(fraction, 0.0, 1.0)}
	var cuts: Array = beat.get("cuts", [])
	if cuts.is_empty() or bool(ui.opening_preferences().reduce_motion):
		return result
	var begin := 0.0
	var finish := 1.0
	for index in cuts.size():
		var at := clampf(float(cuts[index].get("at", 0.0)), 0.0, 1.0)
		if fraction + 0.000001 < at:
			finish = at
			break
		begin = at
		finish = 1.0
		result.shot_id = str(cuts[index].get("shot_id", beat.shot_id))
		result.actor_id = str(cuts[index].get("actor_id", beat.get("actor_id", "")))
	result.span = maxf(0.02, finish - begin)
	result.local = clampf((fraction - begin) / float(result.span), 0.0, 1.0)
	return result


func _opening_next() -> void:
	if screen != "opening" or opening_paused:
		return
	if _film_choice_open(opening_sequence.beats[opening_index]):
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
	# An open decision is never skipped or made for the player (HB S. 29, T20).
	var target: int = opening_sequence.beats.size() - 1
	for index in range(opening_index, opening_sequence.beats.size()):
		if _film_choice_open(opening_sequence.beats[index]):
			target = index
			break
	opening_index = target
	opening_paused = false
	_opening_present()


func _film_choice_open(beat: Dictionary) -> bool:
	if not bool(beat.get("await_choice", false)) or not Childhood.enabled(model.data):
		return false
	return str(Childhood.current_step(model.data).get("id", "")) == str(beat.get("choice_step", ""))


## A film choice is committed by the same checked childhood transaction as the
## in-world dialogue. The following beats are rebuilt from the new state.
func _opening_choose(action_id: String) -> void:
	if screen != "opening" or opening_paused or opening_sequence.is_empty():
		return
	var beat: Dictionary = opening_sequence.beats[opening_index]
	if not _film_choice_open(beat):
		return
	var offered := false
	for option: Dictionary in beat.get("choices", []):
		offered = offered or str(option.get("action_id", "")) == action_id
	if not offered:
		return
	_film_committing = true
	var result := _command("village_childhood_action", {"action_id": action_id})
	_film_committing = false
	if not result.get("ok", false):
		if is_instance_valid(opening_overlay):
			opening_overlay.show_choice_feedback(str(result.get("message", "")))
		return
	var next_index := opening_index + 1
	var rebuilt := _film_sequence(str(opening_sequence.get("id", "")))
	if rebuilt.is_empty():
		_opening_finish()
		return
	_begin_opening(rebuilt, next_index)
	print("IMPERATHEN_FILM_CHOICE " + action_id)


func _film_sequence(sequence_id: String) -> Dictionary:
	if sequence_id == "childhood_home":
		return OpeningStory.childhood(model.data)
	if sequence_id == I01Film.VID_B:
		return I01Film.restore(model.data, sequence_id)
	if sequence_id in I03Film.IDS:
		return I03Film.restore(model.data, sequence_id, Childhood.i03_ctx(model.data))
	if sequence_id in I04Film.IDS:
		return I04Film.restore(model.data, sequence_id, Childhood.i04_ctx(model.data))
	return {}


func _opening_set_paused(value: bool) -> void:
	if screen != "opening":
		return
	opening_paused = value
	opening_voice.set_paused(value)
	if is_instance_valid(opening_overlay):
		opening_overlay.set_paused(value)
	if is_instance_valid(opening_director):
		opening_director.set_paused(value)
	_log_opening_geometry.call_deferred()


func _log_opening_geometry() -> void:
	if not OS.is_debug_build() or screen != "opening" or not is_inside_tree() or is_queued_for_deletion():
		return
	# Bound one-shot signals are disconnected when this node is freed.
	# An awaited coroutine would instead resume after scene destruction.
	var tree := get_tree()
	if not tree.process_frame.is_connected(_log_opening_geometry_next_frame):
		tree.process_frame.connect(_log_opening_geometry_next_frame, CONNECT_ONE_SHOT)


func _log_opening_geometry_next_frame() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or screen != "opening":
		return
	var tree := get_tree()
	if not tree.process_frame.is_connected(_emit_opening_geometry):
		tree.process_frame.connect(_emit_opening_geometry, CONNECT_ONE_SHOT)


func _emit_opening_geometry() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or screen != "opening" or not is_instance_valid(opening_overlay):
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
	var sequence: Dictionary = {}
	var sequence_id := str(checkpoint.sequence_id)
	if Childhood.enabled(model.data):
		if sequence_id == "i00_aquileia":
			sequence = OpeningStory.historical_prologue()
		elif sequence_id == "childhood_home":
			sequence = OpeningStory.childhood(model.data)
		elif sequence_id == I01Film.VID_B:
			sequence = I01Film.restore(model.data, sequence_id)
		elif sequence_id in I03Film.IDS:
			sequence = I03Film.restore(model.data, sequence_id, Childhood.i03_ctx(model.data))
		elif sequence_id in I04Film.IDS:
			sequence = I04Film.restore(model.data, sequence_id, Childhood.i04_ctx(model.data))
		elif sequence_id.begins_with(MissionCinematics.PREFIX):
			sequence = MissionCinematics.restore(model.data,sequence_id)
	else:
		sequence = OpeningStory.sequence(str(model.data.origin_id)) if int(model.data.player.age) < 18 else OpeningStory.adulthood(model.data)
	if sequence.is_empty() or str(sequence.id) != sequence_id:
		return false
	if int(checkpoint.index) > sequence.beats.size():
		return false
	_begin_opening(sequence, int(checkpoint.index))
	return true


func _opening_finish() -> void:
	if screen != "opening":
		return
	var chain_to := str(opening_sequence.get("chain_to", ""))
	var finished_id := str(opening_sequence.get("id", ""))
	_write_opening_checkpoint(true)
	var checkpoint_failed := opening_checkpoint_failed
	_release_opening()
	if chain_to == "childhood_home" and Childhood.enabled(model.data):
		_begin_opening(OpeningStory.childhood(model.data))
		if checkpoint_failed:
			ui.notify("Der Prolog-Fortschritt konnte nicht gespeichert werden. Die Kindheitsszene läuft weiter; beim Fortsetzen kann der Prolog erneut erscheinen.")
		print("IMPERATHEN_OPENING_CHAINED " + finished_id + " -> childhood_home")
		return
	screen = "playing"
	_resume()
	if checkpoint_failed:
		ui.notify("Der Vorspann-Fortschritt konnte nicht gespeichert werden. Beim Fortsetzen kann die Szene erneut erscheinen.")
	print("IMPERATHEN_OPENING_COMPLETE")


func _release_opening() -> void:
	if not opening_sequence.is_empty() and is_instance_valid(world.i01_props):
		world.i01_props.settle_film_pour()
	_stop_opening_voice()
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
	AudioBuses.ensure_layout()
	ambience.bus = AudioBuses.AMBIENCE
	add_child(ambience)
	ambience.finished.connect(ambience.play)
	ambience.play()


func _exit_tree() -> void:
	if is_instance_valid(world) and world.get_parent() == null:
		world.free()
	var ambience := get_node_or_null("FrontierAmbience") as AudioStreamPlayer
	if ambience != null:
		ambience.stop()
		ambience.stream = null


func _log_menu_geometry() -> void:
	# Debug builds expose only this button's screen coordinates so Android smoke
	# checks can tap the actual laid-out control without guessed pixel positions.
	if not OS.is_debug_build() or screen != "menu" or not is_inside_tree() or is_queued_for_deletion():
		return
	var tree := get_tree()
	if not tree.process_frame.is_connected(_log_menu_geometry_next_frame):
		tree.process_frame.connect(_log_menu_geometry_next_frame, CONNECT_ONE_SHOT)


func _log_menu_geometry_next_frame() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or screen != "menu":
		return
	var tree := get_tree()
	if not tree.process_frame.is_connected(_emit_menu_geometry):
		tree.process_frame.connect(_emit_menu_geometry, CONNECT_ONE_SHOT)


func _emit_menu_geometry() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or screen != "menu":
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
	if demo:
		valley.model = valley.Rules.new(valley.Rules.DEFAULT_SEED, valley.Rules.Muster.scenario(valley.Rules.VALLEY_SCENARIO, []))
		valley.message = "Erwachsenenprüfung · Vor Übungsbeginn kannst du im Aufgebot weitere Freiwillige ausrüsten."
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
	if not demo:
		var appointment: String = valley.Rules.campaign_authority(model.data)
		valley.model.set_commander(appointment)
		valley.message = "Dir wird für diesen Einsatz die Passwache unterstellt." if appointment != "" else "Du beobachtest das Gefecht ohne eigenes Kommando."
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
	if not demo:
		# One world state for the atlas: the date of the world clock and the
		# tribal situation of this save, which keeps living in frame budgets
		# while the atlas pauses the walkable world.
		atlas.time = model.world_time()
		atlas.tribes = model.data.tribes
		atlas.tribes_pump = model.pump_tribes
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
		atlas.time = model.world_time()
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


func _can_visit_market() -> bool:
	var data: Dictionary = model.data
	if not data.get("village", {}).get("enabled", false) or data.progress.career_terminal:
		return false
	if TravelParty.protected(data) or not data.story.choices.is_empty():
		return false
	return not Childhood.enabled(data) or str(data.village.childhood.screenplay.get("i01", "")) in ["complete", "legacy"]


func _open_city_exploration(campaign_visit := false, from_road := false, imperial_visit := false, monument_entry := false) -> void:
	var passengers: Array[CharacterBody3D] = []
	if is_instance_valid(city_exploration):
		return
	if campaign_visit:
		if (screen != ("playing" if from_road else "paused")) or (from_road and not world.at_waystation()) or not session_started or not _can_visit_market():
			return
		if not _save(false).ok:
			return
		passengers = world._story_companions.departing_for_market(model.data, world.get_player_position())
		model.npc_observations = Callable()
	elif screen != "menu":
		return
	_campaign_market_visit = campaign_visit
	world.set_active(false)
	world.hide()
	# Hidden village bodies would otherwise obstruct the separate test city.
	remove_child(world)
	ui.hide()
	ui.process_mode = Node.PROCESS_MODE_DISABLED
	city_exploration = CityExploration.new()
	city_exploration.profile = ui.get_quality()
	if campaign_visit:
		city_exploration.campaign = model
		city_exploration.party_visit.passengers = passengers
		city_exploration.campaign_path = SAVE_PATH
		city_exploration.world_jdn = int(model.data.calendar.clock.jdn)
		# The same authored monument is available in the persistent campaign
		# whenever the authoritative historical date permits it.
		city_exploration.use_flavian_kit = true
	elif imperial_visit:
		city_exploration.world_jdn = preload("res://scripts/domain/world_calendar.gd").to_jdn(100, 6, 1)
		city_exploration.use_flavian_kit = true
		# The normal free tour keeps its own dated position. The direct monument
		# visit is disposable and never replaces either the old or campaign save.
		city_exploration.persist = not monument_entry
		city_exploration.save_path = "user://imperathen_imperial_city_exploration.json"
		city_exploration.start_at_colosseum = monument_entry
	elif "--horse-test" in OS.get_cmdline_user_args():
		city_exploration.enable_riding_trial = true
		city_exploration.persist = false
	city_exploration.leave_requested.connect(_leave_city_exploration)
	city_exploration.story_requested.connect(_start_story_from_city)
	screen = "city_exploration"
	add_child(city_exploration)

func _start_story_from_city() -> void:
	if _campaign_market_visit:
		return
	# The city tour has its own save. Starting the campaign must go through
	# the normal confirmation and must never delete an existing life silently.
	_leave_city_exploration()
	_request_new_game()

func _leave_city_exploration() -> void:
	if not is_instance_valid(city_exploration):
		return
	city_exploration.party_visit.return_to_village()
	remove_child(city_exploration)
	city_exploration.queue_free()
	city_exploration = null
	add_child(world)
	ui.process_mode = Node.PROCESS_MODE_INHERIT
	ui.show()
	world.get_node("WorldCamera").current = true
	if _campaign_market_visit:
		model.npc_observations = world.npc_observations
		_campaign_market_visit = false
		world.show()
		_resume()
	else:
		_show_menu()
