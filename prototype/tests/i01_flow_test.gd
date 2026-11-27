extends SceneTree
## I-01 through the production Main, UI, overlay, director and world.
## Travel between authored points uses explicit fixture placement (not a timed
## walk); every quest change goes through the real interaction/command path.
## Handbook mapping: T19 (film start -> choice -> exact handoff), T20 (skip at
## an open choice), T21 (Back/suspend/continue at the same beat, no duplicate
## events), I-01 "Film abgebrochen", "Save am Tisch" (world props), "NPC beim
## Brunnen abwesend" (hidden Marcus), child HUD per HB S. 13/44, VID-C.
## Optional: -- --capture-dir=<dir> saves engine frames (needs a display).

const Entry = preload("res://main.tscn")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const I01Film = preload("res://scripts/story/i01_film.gd")
const VoiceLines = preload("res://scripts/audio/voice_lines.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Checkpoint = preload("res://scripts/cinematic/opening_checkpoint.gd")
var game
var checks := 0
var failures: Array[String] = []
var capture_dir := ""
var captures: Array = []
var timing := {}
var size := Vector2i(1280, 720)


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("I-01 flow requires isolated settings and saves.")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()


func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failures.append(message)
		printerr("I01_FLOW_FAIL: " + message)
	return value


func frames(count := 4) -> void:
	for i in count:
		await process_frame


func _childhood() -> Dictionary:
	return game.model.data.village.childhood


func _events() -> Array:
	return _childhood().screenplay.i01_events.duplicate()


func _beat() -> Dictionary:
	return game.opening_sequence.beats[game.opening_index] if game.screen == "opening" else {}


func _place(point: Vector2) -> void:
	game.world.get_node("Player").position = Vector3(point.x, 1.35, point.y)
	game.model.set_player_position(game.world.get_player_position())
	game.world.sync_state(game.model.data)


func _interact() -> void:
	game.ui.action_requested.emit("interact", {})
	await frames(3)


func _press_choice(action_id: String) -> bool:
	var button: Button = game.opening_overlay.find_child("OpeningChoice_" + action_id, true, false)
	if not check(button != null and button.is_visible_in_tree(), "Film choice button is visible: " + action_id):
		return false
	button.pressed.emit()
	await frames(4)
	return true


## Runs the film clock like Main._process would, until a choice or the end.
func _play_film(limit := 400.0) -> float:
	var played := 0.0
	while game.screen == "opening" and played < limit:
		var beat := _beat()
		if game._film_choice_open(beat) or bool(beat.get("final", false)):
			break
		game._opening_process(0.1)
		played += 0.1
	return played


func _start() -> void:
	game._start_new_game()
	await frames()
	check(game.screen == "opening" and game.opening_sequence.id == "i00_aquileia", "New Life begins with I-00")
	game._opening_skip()
	game._opening_next()
	await frames(6)
	check(game.screen == "opening" and game.opening_sequence.id == I01Film.VID_A and game.opening_index == 0, "I-00 chains into VID-A")


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = size
	game = Entry.instantiate()
	root.add_child(game)
	await frames()
	game.set_process(false)
	game.set_physics_process(false)
	game.ui._touch_enabled = true
	game.ui._finish_intro()
	_check_i01_voice_catalog()
	await _test_vid_a_normal()
	await _test_hud_and_props()
	await _test_vid_b_interrupted()
	await _test_marcus_and_vid_c()
	await _test_vid_a_skip_and_resume()
	await _test_film_aborted_equivalence()
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("i01-flow-report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks, "failures":failures, "captures":captures, "timing_film_seconds":timing,
			"size":[size.x, size.y], "renderer":RenderingServer.get_current_rendering_method(),
			"note":"Engine frames from the production Main; travel between authored points is fixture placement, not a timed walk."}, "\t"))
		file.close()
	game.queue_free()
	await frames()
	print(("I01_FLOW_PASS" if failures.is_empty() else "I01_FLOW_FAILED") + " checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _prop_at_hand(prop: Node3D, hand: String, offset: Vector3) -> bool:
	var rig: Skeleton3D = game.world._figure._motion.skeleton
	if not is_instance_valid(prop) or not prop.visible or not is_instance_valid(rig):
		return false
	var bone := rig.find_bone(hand)
	if bone < 0:
		return false
	var reference := rig.get_bone_global_rest(bone).basis.inverse() * offset
	var expected := rig.to_global(rig.get_bone_global_pose(bone) * reference)
	return prop.global_position.distance_to(expected) < 0.002


## Cover every authored branch, not just the one dialogue path the player
## selects during the integration playthrough.
func _check_i01_voice_catalog() -> void:
	var mission: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(I01.SOURCE))
	for id: String in mission.slice.lines:
		var authored: Dictionary = mission.slice.lines[id]
		_check_exact_voice(str(authored.text), str(authored.speaker_id), id)
	for step: Dictionary in mission.steps:
		if not str(step.get("text", "")).is_empty():
			_check_exact_voice(str(step.text), str(step.npc), str(step.id))
		if not str(step.get("result", "")).is_empty():
			_check_exact_voice(str(step.result), "narrator", str(step.id) + ".result")


func _check_exact_voice(text: String, speaker: String, id: String) -> void:
	var line := VoiceLines.find(text)
	if not check(not line.is_empty() and str(line.get("text", "")) == text and str(line.get("speaker_id", "")) == VoiceLines.speaker_id(speaker), "Exact authored I-01 recording and speaker: " + id):
		return
	var audio := VoiceLines.stream_for(line)
	var track := VoiceLines.viseme_track(line)
	check(audio != null and audio.get_length() > 0.0, "Imported I-01 audio stream is playable: " + id)
	check(str(track.get("line_id", "")) == str(line.line_id) and str(track.get("text_key", "")) == VoiceLines.text_key(text) and not track.get("segments", []).is_empty(), "Aligned I-01 mouth track belongs to this recording: " + id)


func _test_vid_a_normal() -> void:
	# T19: normal film start, AwaitChoice, commit, exact handoff to play.
	await _start()
	check(game.opening_voice.is_active() and str(game.opening_voice.current.get("line_id", "")) == "I01_A_TABLE" and game.opening_voice_duration > 0.0, "Production VID-A actually starts its restored original voice")
	var before := JSON.stringify(game.model.data)
	var shots: Array[String] = []
	var played := 0.0
	while game.screen == "opening" and played < 200.0:
		var beat := _beat()
		if not shots.has(str(beat.shot_id)):
			shots.append(str(beat.shot_id))
			await capture("vid-a-%d-%s" % [game.opening_index, beat.id])
		if game._film_choice_open(beat):
			break
		game._opening_process(0.1)
		played += 0.1
	timing["vid_a_to_choice"] = snappedf(played, 0.1)
	var beat := _beat()
	check(beat.get("id", "") == "i01_a_choice" and game._film_choice_open(beat), "T19: VID-A reaches its choice beat in normal playback")
	check(shots.slice(0, 3) == ["i01_table_detail", "i01_shelf_cups", "i01_bed"], "VID-A shows table, cups/shelf and bed in authored order: " + str(shots))
	check(JSON.stringify(game.model.data) == before, "Playing VID-A to the choice mutates nothing")
	for i in 300:
		game._opening_process(0.1)
	check(game.opening_index == 3 and JSON.stringify(game.model.data) == before, "AwaitChoice holds the scene; 30 s idle neither advances nor chooses")
	game.opening_overlay._request_advance()
	await frames()
	check(game.opening_index == 3, "Advance cannot pass an open choice")
	check(await _press_choice("i01_help"), "Choose help inside the film")
	check(_events() == ["I-01.choice.help"] and _childhood().screenplay.i01_path == "help", "The film choice commits exactly one event through the model")
	check(str(_beat().get("id", "")) == "i01_a_react" and str(_beat().text).contains("Becher vom oberen Brett"), "Julia reacts to the actual choice")
	var rest := _play_film()
	timing["vid_a_after_choice"] = snappedf(rest, 0.1)
	check(bool(_beat().get("final", false)), "VID-A ends with the objective handoff")
	var final_camera: Transform3D = game.opening_director.camera.global_transform
	check(final_camera.is_equal_approx(game.world.get_node("WorldCamera").global_transform), "T19: last shot lands exactly on the play camera")
	await capture("vid-a-handoff")
	game.opening_overlay._request_advance()
	await frames(6)
	check(game.screen == "playing" and game.world.get_node("WorldCamera").current and game.world.get("_active"), "T19: control returns with the ordinary camera")
	var at: Vector3 = game.world.get_player_position()
	check(Vector2(at.x, at.z).distance_to(I01.POINTS.home_bed) < 0.3, "Control starts at the boy's actual bed")
	check(Childhood.view(game.model.data).stage == "i01_take_cups", "Help leads to the shelf objective")


func _test_hud_and_props() -> void:
	game.ui.show_game(game._ui_state())
	await frames(4)
	var objective: Array = game.ui._objective(game._ui_state())
	check(not str(objective[0]).contains("I-01") and str(objective[0]).contains("Familienhaus"), "HUD objective shows occasion and place, not the mission ID: " + str(objective[0]))
	for action in ["attack", "guard", "dodge", "techniques"]:
		check(_action_button(action) == null, "No combat control on the child's I-01 HUD: " + action)
	check(_action_button("interact") != null and _action_button("pace") != null, "Interaction and walking pace remain on the HUD")
	check(not str(game.ui._hud_labels.squad.text).contains("Truppe") and not str(game.ui._hud_labels.squad.text).contains("Moral"), "No troop or morale for the child")
	for metric in ["wood", "grain", "denarii"]:
		check(not game.ui._hud_labels[metric].visible, "Village stock does not occupy the first-mission HUD: " + metric)
	var compass: Control = game.ui._screen.find_child("VillageCompass", true, false)
	game.ui.update_navigation(game.world.navigation_view())
	check(compass != null and not compass.visible, "Inside the family home with an in-house goal the compass steps aside")
	game.ui.update_navigation({"player":Vector2(-7.0, 7.0), "target":I01.POINTS.home_shelf, "has_target":true, "heading":0.0})
	check(compass.visible, "The objective map returns as soon as the boy is outside")
	await capture("hud-i01-start")
	game.ui._show_journal()
	await frames(3)
	var journal_text := _all_text(game.ui._screen)
	check(not journal_text.contains("Truppe") and journal_text.contains("Familie") and journal_text.contains("Du trägst"), "Journal shows family and carried things instead of troop/morale")
	game._resume()
	await frames(3)
	# WP2: real props follow the saved state.
	var props = game.world.i01_props
	for owner in I01.CUPS:
		check(props.cup_location(owner) == "shelf", "Cup starts on the real shelf: " + owner)
	_place(I01.POINTS.home_shelf + Vector2(0.75, -0.1))
	await _interact()
	check(I01.cups(game.model.data).values() == ["hand", "hand", "hand"], "Interaction at the shelf takes the three cups")
	for owner in I01.CUPS:
		check(props.cup_location(owner) == "hand", "Cup follows the boy's hand: " + owner)
	var carried_cup: Node3D = props.cup_node("silvanus")
	var actor = game.world._figure
	var previous_body: Node3D = actor.body
	actor._reload((actor.detail + 1) % 4)
	await frames(3)
	check(not is_instance_valid(previous_body), "The carried-cup test really replaced the character body")
	check(is_instance_valid(carried_cup) and props.cup_node("silvanus") == carried_cup
		and carried_cup.get_parent() == props and props.cup_location("silvanus") == "hand",
		"Carried cup survives model replacement as the same visible node")
	check(_prop_at_hand(carried_cup, "Hand_R", props.HAND_CUPS.silvanus),
		"The same cup follows the new model's right hand within 2 mm")
	await capture("cups-in-hand")
	check(game.ui._hud_labels.compact_life.text.contains("Drei Becher"), "Carried cups appear contextually on the objective card")
	_place(I01.POINTS.player_table)
	await _interact()
	check(I01.cups(game.model.data).julia == "table" and props.cup_location("julia") == "table", "First cup stands at Julia's place")
	# Save am Tisch: one cup on the table, two in hand, through Main.
	var events := _events()
	check(game._save(false).ok, "Save at the table through Main")
	game._show_menu()
	game._continue_game()
	await frames(6)
	check(game.screen == "playing" and I01.cups(game.model.data) == {"julia":"table", "silvanus":"hand", "player":"hand"} and _events() == events, "Continue restores cups in hand and on the table without new events")
	check(game.world.i01_props.cup_location("julia") == "table" and game.world.i01_props.cup_location("silvanus") == "hand", "World props match the restored state")
	_place(I01.POINTS.player_table)
	await _interact()
	await _interact()
	check(_childhood().screenplay.i01_table_by == "player", "All three cups set by the player")
	await capture("table-set")
	_place(I01.POINTS.home_jug)
	await _interact()
	check(_childhood().screenplay.i01_water == "empty_jug" and props.jug_in_hand() and not props.full_jug_carried(), "Real pickup gives the empty jug")
	await frames(40)
	await capture("empty-jug")
	_place(I01.POINTS.well + Vector2(1.5, 0.3))
	await _interact()
	check(_childhood().screenplay.i01_water == "jug", "Real well action fills the jug")
	check(props.jug_animating(), "Well action starts a visible pickup, not just a fixed hand prop")
	var carried_jug: Node3D = props.jug_node()
	actor._reload((actor.detail + 1) % 4)
	# The fixed fixture positions the capsule above the floor. Inspect the
	# next stable hand pose after it lands and the replacement enters the rig.
	await frames(120)
	check(props.get_meta("well_visual_bound",false), "Real imported bucket and rope are bound")
	await capture("well-rope-lift")
	await frames(145)
	await capture("well-bucket-pour")
	await frames(160)
	check(not props.jug_animating(),"Well lift and filling have completed")
	check(is_instance_valid(carried_jug) and props.jug_node() == carried_jug
		and carried_jug.get_parent() == props and props.full_jug_carried(),
		"The filled jug survives a second model replacement and remains in two-hand carry")
	_place(I01.POINTS.player_table)
	await _interact()
	check(_childhood().screenplay.i01_water == "poured" and game.screen == "opening" and game.opening_sequence.id == I01Film.VID_B, "Return with water directly opens the continuation film")
	check(not props.jug_in_hand() and props.jug_animating(),"Film owns the actual sequential pour")
	game._opening_process(1.55)
	check(props._water.julia.visible and not props._water.silvanus.visible and not props._water.player.visible,"Only first cup is filling")
	check(props._water_motion.stream.any(func(item: MeshInstance3D)->bool: return item.visible),"The water stream is actual visible geometry")
	var first_focus: Vector3 = props.cinematic_pour_focus()
	check(first_focus.is_finite(), "First pour has a live world-space camera focus")
	_check_live_pour_focus(props, "julia")
	await capture("film-first-cup-pour")
	game._opening_process(1.75)
	check(props._water.julia.visible and props._water.silvanus.visible and not props._water.player.visible,"Second cup starts after first, not before")
	_check_live_pour_focus(props, "silvanus")
	check(props.cinematic_pour_focus().distance_to(first_focus) > 0.2, "Insert follows the physical receiver instead of a fixed tabletop point")
	await capture("film-second-cup-pour")
	game._opening_process(1.75)
	check(props._water.player.visible,"Third cup is now filling")
	_check_live_pour_focus(props, "player")
	await capture("film-third-cup-pour")
	game._opening_process(1.60)
	check(not props.jug_animating() and carried_jug.global_position.distance_to(props.world_point(props.JUG_TABLE)) < .025,"The same jug settles at the real table")
	check(not props.cinematic_pour_focus().is_finite(), "Finished pour releases the dynamic camera focus")
	for owner: String in I01.CUPS:
		check(props._water[owner].visible,"Filled water remains visible in "+owner)


func _check_live_pour_focus(props: Node3D, owner: String) -> void:
	var cup: Node3D = props.cup_node(owner)
	var expected := cup.to_global(Vector3(.033 if owner == "player" else 0.0, .147, 0)).lerp(
		props.jug_node().to_global(props.JUG_MOUTH), 0.5)
	var focus: Vector3 = props.cinematic_pour_focus()
	check(focus.is_equal_approx(expected), "Camera focus matches real water endpoints: " + owner)
	var camera: Camera3D = game.opening_director.camera
	var direction := (focus - camera.global_position).normalized()
	check((-camera.global_basis.z).normalized().dot(direction) > 0.98, "Camera looks at the live pour: " + owner)


## D-052 film dialogue: several shot sizes, reaction shots inside a line,
## silent pauses, the interior light rig and stable voice ids. Runs on the
## first beat of VID-B and restores the film clock afterwards.
func _check_vid_b_direction() -> void:
	var beats: Array = game.opening_sequence.beats
	var shots := {}
	var pauses := 0
	var reactions := 0
	for beat: Dictionary in beats:
		shots[str(beat.shot_id)] = true
		for cut: Dictionary in beat.get("cuts", []):
			shots[str(cut.shot_id)] = true
			if str(cut.shot_id).begins_with("i01_react"):
				reactions += 1
		if bool(beat.get("silent", false)):
			pauses += 1
			check(str(beat.text).is_empty() and str(beat.line_id).is_empty() and float(beat.duration) >= 2.0 and float(beat.duration) <= 4.0, "A pause carries no line and lasts 2–4 s: " + str(beat.id))
		elif not bool(beat.get("await_choice", false)) and not bool(beat.get("final", false)):
			check(not str(beat.get("line_id", "")).is_empty() and not str(beat.get("speaker_id", "")).is_empty(), "Spoken beat keeps line_id and speaker_id: " + str(beat.id))
	for wanted: String in ["i01_table_wide", "i01_two_shot", "i01_close_speaker", "i01_cups_insert", "i01_react_boy", "i01_react_julia", "i01_topic_choice"]:
		check(shots.has(wanted), "VID-B uses shot size " + wanted)
	check(pauses >= 3 and reactions >= 2, "VID-B has dramatic pauses (%d) and reaction cuts (%d)" % [pauses, reactions])
	var ids: Array = beats.map(func(b): return str(b.get("line_id", "")))
	check(ids.has("I01_B_TABLE") and ids.has("I01_B_SEXTUS"), "Line ids of the table talk are unchanged for the voice session")
	var director: Node3D = game.opening_director
	# Distinct compositions: every shot size has its own lens and distance.
	var table: Vector3 = game.world.to_global(preload("res://scripts/world/village/i01_props.gd").anchor("i01_table"))
	var fovs := {}
	for shot: String in ["i01_table_wide", "i01_two_shot", "i01_close_speaker", "i01_cups_insert", "i01_react_boy"]:
		director.mission_actor_id = "silvanus"
		var frame: Dictionary = director.sample(shot, 0.5)
		fovs[shot] = float(frame.fov)
		check((frame.position as Vector3).distance_to(table) < 6.0, "Shot stays inside the family home: " + shot)
	check(fovs.i01_table_wide > fovs.i01_two_shot and fovs.i01_two_shot > fovs.i01_close_speaker and fovs.i01_close_speaker > fovs.i01_cups_insert, "Lenses narrow from wide to insert: " + str(fovs))
	# A reaction cut inside Silvanus' line keeps the line and changes the frame.
	var telling: Dictionary = beats[ids.find("I01_B_SEXTUS")]
	check(str(game._beat_cut(telling, 0.1).shot_id) == "i01_close_speaker" and str(game._beat_cut(telling, 0.55).shot_id) == "i01_react_boy" and str(game._beat_cut(telling, 0.9).shot_id) == "i01_close_speaker", "The boy's reaction is cut into Silvanus' line")
	var cut: Dictionary = game._beat_cut(telling, 0.58)
	check(float(cut.local) > 0.0 and float(cut.local) < 1.0 and is_equal_approx(float(cut.span), 0.24), "The reaction cut has its own clock inside the line")
	# Light: window key with shadow, warm hearth, weak camera fill, darker ambient.
	var rig := director.get_node_or_null("I01FilmLights") as Node3D
	if check(rig != null and rig.visible, "Interior film light rig is active at the table"):
		var key := rig.get_node("WindowKey") as SpotLight3D
		var hearth := rig.get_node("HearthWarm") as OmniLight3D
		var fill := rig.get_node("CameraFill") as OmniLight3D
		check(key.shadow_enabled and key.light_energy > hearth.light_energy and hearth.light_energy > fill.light_energy and fill.light_energy > 0.0, "Key, warm second source and fill keep a clear ratio")
		check(hearth.light_color.r > hearth.light_color.b * 2.0 and key.light_color.b > hearth.light_color.b, "Hearth is warm, window light is daylight")
		check(game.world.find_children("*", "WorldEnvironment", true, false)[0].environment.ambient_light_energy < float(director._lighting.ambient_energy) * 0.6, "Ambient fill is lowered for the interior scene")
	# Restore the running beat exactly.
	director.mission_actor_id = str(_beat().get("actor_id", ""))
	director.sample(str(_beat().shot_id), 0.0)


func _test_vid_b_interrupted() -> void:
	# T20 at VID-B: skip lands on the topic choice without choosing.
	var before := JSON.stringify(game.model.data.village.childhood)
	await capture("vid-b-0-table")
	_check_vid_b_direction()
	var choice_index: int = game.opening_sequence.beats.map(func(b): return str(b.id)).find("i01_b_choice")
	game.opening_overlay._request_skip()
	await frames(3)
	check(str(_beat().get("id", "")) == "i01_b_choice" and game._film_choice_open(_beat()), "T20: skip stops at the open table-talk choice")
	check(JSON.stringify(game.model.data.village.childhood) == before, "T20: skip makes no choice")
	await capture("vid-b-choice")
	# T21: Android Back pauses; suspension checkpoints; Continue resumes here.
	root.go_back_requested.emit()
	check(game.opening_paused, "T21: Back pauses the film at the choice")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var checkpoint: Dictionary = Checkpoint.read(str(game.model.data.world_id))
	check(checkpoint.get("sequence_id", "") == I01Film.VID_B and int(checkpoint.get("index", -1)) == choice_index, "T21: suspend checkpoints the choice beat")
	game._show_menu()
	game._continue_game()
	await frames(6)
	check(game.screen == "opening" and game.opening_sequence.id == I01Film.VID_B and game.opening_index == choice_index and JSON.stringify(game.model.data.village.childhood) == before, "T21: Continue returns to the same beat without duplicate events")
	var labels: Array = game.opening_sequence.beats[choice_index].choices.map(func(c): return c.label)
	check(labels == ["Nach der Werkstatt fragen", "Nach der Feldarbeit fragen"], "No contact topic without an actual encounter: " + str(labels))
	await _press_choice("i01_topic_workshop")
	check(_childhood().screenplay.i01 == "complete" and _events().count("I-01.topic.workshop") == 1, "Topic committed once")
	check(str(_beat().get("id", "")) == "i01_b_reply" and str(_beat().text).contains("Angeln"), "Silvanus answers the chosen topic")
	await capture("vid-b-reply")
	_play_film()
	# Seamless return: the last shot ends on the play camera with the film
	# light faded out; afterwards light and ambient are exactly as before.
	check(bool(_beat().get("final", false)) and game.opening_director.camera.global_transform.is_equal_approx(game.world.get_node("WorldCamera").global_transform)
		and is_equal_approx(game.opening_director.camera.fov, game.world.get_node("WorldCamera").fov), "VID-B ends exactly on the play camera")
	var ambient_before := float(game.opening_director._lighting.get("ambient_energy", -1.0))
	var film_rig := game.opening_director.get_node_or_null("I01FilmLights") as Node3D
	check(film_rig == null or not film_rig.visible, "Film light is off when the play camera takes over")
	game.opening_overlay._request_advance()
	await frames(6)
	check(is_equal_approx(game.world.find_children("*", "WorldEnvironment", true, false)[0].environment.ambient_light_energy, ambient_before), "Ambient light is restored after the film")
	check(game.screen == "playing" and Childhood.view(game.model.data).stage == "mother_morning", "After VID-B the established family step follows")
	check(game.world.i01_props.cup_location("player") == "table", "Visible cup stays at its place after the film")


func _test_marcus_and_vid_c() -> void:
	# Marcus before I-03: greeting only, no hut dialogue, no companion decision.
	var marcus: Vector3 = game.world._companion.global_position
	_place(Vector2(marcus.x + 1.0, marcus.z))
	game._show_companion()
	await frames(3)
	var text := _all_text(game.ui._screen)
	check(game.screen == "dialog" and text.contains("Marcus") and not text.contains("Holz") and not game.model.data.companion.met, "Marcus greets before I-03 without the old hut dialogue or a companion flag")
	game._resume()
	await frames(2)
	# VID-C at the I-01/I-02 border.
	var mother: Vector2 = Life.actor_position(game.model.data, "julia")
	_place(mother + Vector2(0.6, 0.6))
	check(game._command("village_childhood_action", {"action_id":"mother_morning"}).ok, "Julia's errand after breakfast")
	_place(I01.POINTS.player_table)
	check(game._command("village_childhood_action", {"action_id":"fill_water"}).ok, "Jug taken from the breakfast table")
	var props = game.world.i01_props
	var jug: Node3D = props.jug_node()
	await frames(40)
	check(_prop_at_hand(jug, "Hand_L", props.JUG_HAND), "The jug is carried in the boy's hand")
	var father: Vector2 = Life.actor_position(game.model.data, "silvanus")
	_place(father + Vector2(0.6, 0.6))
	check(game._command("village_childhood_action", {"action_id":"father_morning"}).ok, "Jug handed to Silvanus")
	await frames(4)
	check(game.screen == "opening" and str(game.opening_sequence.id) == "mission_transition_father_morning", "VID-C plays at the I-01/I-02 border")
	var ids: Array = game.opening_sequence.beats.map(func(b): return str(b.id))
	check(ids.has("i01_c_parents") and not ids.has("i01_c_marcus"), "VID-C has the parents' variant and no contact offer without a contact: " + str(ids))
	check(str(game.opening_sequence.beats[ids.find("i01_c_parents")].text).contains("Becher deckt"), "VID-C reminds of the actual help")
	await capture("vid-c")
	game._opening_skip()
	game._opening_next()
	await frames(4)
	check(game.screen == "playing", "VID-C hands back to play")
	await frames(40)
	check(not props.jug_in_hand() and not jug.visible,"Father handoff never leaves a jug stuck to the player")
	# HUD after I-01: combat controls return in ordinary village life.
	game.ui.show_game(game._ui_state())
	await frames(3)
	check(_action_button("attack") != null, "After I-01 the existing practice controls are reachable again")


func _test_vid_a_skip_and_resume() -> void:
	# T20/T21 on VID-A in a fresh life; also absent Marcus and contact choice.
	await _start()
	var before := JSON.stringify(game.model.data)
	game.opening_overlay._request_skip()
	await frames(3)
	check(str(_beat().get("id", "")) == "i01_a_choice" and JSON.stringify(game.model.data) == before, "T20: skipping VID-A lands on the open choice and chooses nothing")
	game.opening_overlay._request_skip()
	await frames(2)
	check(game.opening_index == 3, "A second skip cannot pass the open choice")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game._show_menu()
	game._continue_game()
	await frames(6)
	check(game.screen == "opening" and game.opening_sequence.id == I01Film.VID_A and game.opening_index == 3 and _childhood().screenplay.i01_events.is_empty() and _childhood().screenplay.i01_path == "", "T21: Continue resumes VID-A at the choice with an empty ledger")
	await _press_choice("i01_yard")
	check(I01.cups(game.model.data).values() == ["table", "table", "table"] and _childhood().screenplay.i01_table_by == "julia", "Yard: Julia sets the table herself")
	game._opening_skip()
	game._opening_next()
	await frames(6)
	check(game.screen == "playing", "Yard path hands over to play")
	# NPC beim Brunnen abwesend: hidden Marcus offers no contact or substitute.
	game.world._companion.visible = false
	var marcus: Vector3 = game.world._companion.global_position
	_place(Vector2(marcus.x + 0.8, marcus.z))
	game._show_companion()
	await frames(2)
	check(game.screen == "playing" and _childhood().screenplay.i01_contacts.is_empty(), "Hidden Marcus: no dialogue, no contact, no substitute")
	game.world._companion.visible = true
	game._show_companion()
	await frames(3)
	var contact := _find_button(game.ui._screen, "Kurz zuhören")
	check(contact != null, "Present Marcus offers a concrete encounter during I-01")
	if contact != null:
		contact.pressed.emit()
		await frames(4)
	check(_childhood().screenplay.i01_contacts == ["marcus"] and not game.model.data.companion.met, "Encounter recorded as an event, not as a companion flag")
	await capture("yard-marcus")
	_place(I01.POINTS.player_table)
	await _interact()
	check(game.screen == "opening" and game.opening_sequence.id == I01Film.VID_B, "Breakfast happens without help")
	var julia_beats: Array = game.opening_sequence.beats.filter(func(b): return str(b.id) == "i01_b_julia")
	check(julia_beats.size() == 1 and str(julia_beats[0].text).contains("draußen"), "Julia reacts to the absence")
	game._opening_skip()
	await frames(2)
	var labels: Array = _beat().choices.map(func(c): return c.label)
	check(labels.has("Von Marcus erzählen"), "Table talk offers the actual encounter: " + str(labels))
	await _press_choice("i01_topic_contact")
	check(str(_beat().text).contains("Marcus"), "Julia answers about the actual encounter")
	game._opening_skip()
	game._opening_next()
	await frames(4)
	# Delayed hooks of the encounter: VID-C offer line and the I-03 memory.
	for step in ["mother_morning", "fill_water", "father_morning"]:
		var target: Vector2 = Childhood.view(game.model.data).point
		_place(target + Vector2(0.5, 0.5) if step != "fill_water" else I01.POINTS.player_table)
		check(game._command("village_childhood_action", {"action_id":step}).ok, "Family step after the yard morning: " + step)
	await frames(3)
	var ids: Array = game.opening_sequence.beats.map(func(b): return str(b.id)) if game.screen == "opening" else []
	check(ids.has("i01_c_marcus") and ids.has("i01_c_parents"), "VID-C names the place Marcus mentioned, only after the real encounter: " + str(ids))
	check(ids.has("i01_c_parents") and str(game.opening_sequence.beats[ids.find("i01_c_parents")].text).begins_with("»Geh nur"), "VID-C bids a friendly farewell when the boy did not help")
	game._opening_skip()
	game._opening_next()
	await frames(4)
	var aurelia: Vector2 = Life.actor_position(game.model.data, "aurelia")
	_place(aurelia + Vector2(0.6, 0.0))
	if not Life.relationship(game.model.data, "aurelia").get("met", false):
		game.model.execute("village_talk", {"npc_id":"aurelia", "choice":"meet"})
	check(game._command("village_childhood_action", {"action_id":"basket_check"}).ok, "I-02 basket checked")
	await frames(3)
	if game.screen == "opening":
		game._opening_skip()
		game._opening_next()
		await frames(4)
	check(Childhood.view(game.model.data).stage == "i03_marcus", "I-03 follows")
	var at: Vector3 = game.world._companion.global_position
	_place(Vector2(at.x + 0.8, at.z))
	game._show_companion()
	await frames(3)
	# Reaching Marcus starts I-03 VID-A; the morning at the well is recalled
	# there because the encounter is in the I-01 ledger.
	var recalled: Array = game.opening_sequence.get("beats", []).filter(func(b): return str(b.get("line_id", "")) == "I03_A_HOOK_WELL") if game.screen == "opening" else []
	check(recalled.size() == 1 and str(recalled[0].text).contains("Heute Morgen am Brunnen"), "I-03 recalls the shared morning at the well (memory, not a loyalty value)")
	if game.screen == "opening":
		game._opening_skip()
		await _press_choice("i03_together")
		game._opening_skip()
		game._opening_next()
	await frames(4)
	check(game.screen == "playing" and Childhood.view(game.model.data).stage == "i03_coin", "The chosen route hands back to play on the way to the stall")


func _test_film_aborted_equivalence() -> void:
	# "Film abgebrochen": watching VID-B fully or skipping it leads to the same state.
	var results: Array[String] = []
	for watch in [true, false]:
		await _start()
		game._opening_skip()
		await frames(2)
		await _press_choice("i01_talk")
		game._opening_skip()
		game._opening_next()
		await frames(4)
		_place(I01.POINTS.player_table)
		await _interact()
		if not check(game.screen == "opening" and game.opening_sequence.id == I01Film.VID_B, "VID-B opens (watch=%s)" % watch):
			return
		if watch:
			timing["vid_b_to_choice"] = snappedf(_play_film(), 0.1)
		else:
			game._opening_skip()
			await frames(2)
		await _press_choice("i01_topic_fields")
		if watch:
			timing["vid_b_after_choice"] = snappedf(_play_film(), 0.1)
		else:
			game._opening_skip()
		game._opening_next()
		await frames(4)
		check(game.screen == "playing", "VID-B returns to play (watch=%s)" % watch)
		var child: Dictionary = game.model.data.village.childhood.duplicate(true)
		results.append(JSON.stringify([child.screenplay, child.relationships, child.completed, child.carried]))
	check(results.size() == 2 and results[0] == results[1], "Film abgebrochen: skipping VID-B gives exactly the watched result")
	check(game.model.data.village.childhood.relationships.julia.declined, "Talk path without water stores Julia's open request")


func _action_button(action: String) -> Button:
	for button: Button in game.ui._touch_actions:
		if is_instance_valid(button) and str(button.get_meta("touch_action", "")) == action and button.is_visible_in_tree():
			return button
	return null


func _find_button(node: Node, caption: String) -> Button:
	if node is Button and (node as Button).text.begins_with(caption) and (node as Button).is_visible_in_tree():
		return node
	for child: Node in node.get_children():
		var found := _find_button(child, caption)
		if found != null:
			return found
	return null


func _all_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += (node as Label).text + "\n"
	elif node is Button:
		text += (node as Button).text + "\n"
	for child: Node in node.get_children():
		text += _all_text(child)
	return text


func capture(id: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		check(false, "Real rendered image for " + id)
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var name := "%dx%d-%s" % [size.x, size.y, id]
	check(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Saved " + name)
	captures.append({"id":id, "file":name + ".png", "width":image.get_width(), "height":image.get_height(), "label":"engine render (gl_compatibility, software rasterizer)"})
