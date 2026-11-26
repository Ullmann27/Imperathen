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


func _test_vid_a_normal() -> void:
	# T19: normal film start, AwaitChoice, commit, exact handoff to play.
	await _start()
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
	check(game.ui._screen.find_child("VillageCompass", true, false) != null, "The objective map stays reachable")
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
	_place(I01.POINTS.well + Vector2(1.5, 0.3))
	await _interact()
	check(_childhood().screenplay.i01_water == "jug", "Real well action fills the jug")
	_place(I01.POINTS.player_table)
	await _interact()
	check(_childhood().screenplay.i01_water == "poured" and game.world.i01_props._water.julia.visible, "Poured water is visible in the cups")
	await _interact()
	check(game.screen == "opening" and game.opening_sequence.id == I01Film.VID_B, "Breakfast at the table opens VID-B")


func _test_vid_b_interrupted() -> void:
	# T20 at VID-B: skip lands on the topic choice without choosing.
	var before := JSON.stringify(game.model.data.village.childhood)
	await capture("vid-b-0-table")
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
	check(checkpoint.get("sequence_id", "") == I01Film.VID_B and int(checkpoint.get("index", -1)) == 3, "T21: suspend checkpoints the choice beat")
	game._show_menu()
	game._continue_game()
	await frames(6)
	check(game.screen == "opening" and game.opening_sequence.id == I01Film.VID_B and game.opening_index == 3 and JSON.stringify(game.model.data.village.childhood) == before, "T21: Continue returns to the same beat without duplicate events")
	var labels: Array = game.opening_sequence.beats[3].choices.map(func(c): return c.label)
	check(labels == ["Nach der Werkstatt fragen", "Nach der Feldarbeit fragen"], "No contact topic without an actual encounter: " + str(labels))
	await _press_choice("i01_topic_workshop")
	check(_childhood().screenplay.i01 == "complete" and _events().count("I-01.topic.workshop") == 1, "Topic committed once")
	check(str(_beat().get("id", "")) == "i01_b_reply" and str(_beat().text).contains("Angeln"), "Silvanus answers the chosen topic")
	await capture("vid-b-reply")
	_play_film()
	game.opening_overlay._request_advance()
	await frames(6)
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
	check(game.world.i01_props.jug_node().get_parent() != game.world.i01_props, "The jug is carried in the boy's hand")
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
	check(str(game.opening_sequence.beats[2].text).contains("draußen"), "Julia reacts to the absence")
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
	check(_all_text(game.ui._screen).contains("Heute Morgen am Brunnen"), "I-03 recalls the shared morning at the well (memory, not a loyalty value)")
	game._resume()
	await frames(2)


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
