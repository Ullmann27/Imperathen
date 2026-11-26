extends SceneTree
## Scripted I-01 playthrough with the real game loop (fixed 60 Hz): films run
## on Main's own clock at accelerated test speed, the boy walks by the regular move_axis input through
## the house door to the well and back, and every action uses the regular
## interact/dialogue controls. It reports simulated seconds per phase. This is
## a reproducible engine measurement of one scripted route, not a human
## playtest: reading pauses, exploration and decision time are not included.
## Manual run (the full simulation can take several minutes):
## godot --headless --path prototype --fixed-fps 60 --script res://tests/i01_playthrough_test.gd

const Entry = preload("res://main.tscn")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const Life = preload("res://scripts/story/village_life.gd")
const STEP := 1.0 / 60.0
const FILM_TEST_SPEED := 8.0
var game
var checks := 0
var failures: Array[String] = []
var phases: Array[Dictionary] = []
var walked := 0.0
var capture_dir := ""


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("The playthrough requires isolated settings and saves.")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir=") and DisplayServer.get_name() != "headless":
			capture_dir = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
			RenderingServer.render_loop_enabled = false
	_run.call_deferred()


func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failures.append(message)
		printerr("I01_PLAYTHROUGH_FAIL: " + message)
	return value


func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	# Keep QA movement at 60 Hz without drawing every intermediate frame.
	RenderingServer.render_loop_enabled = true
	await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty() and image.save_png(capture_dir.path_join(label + ".png")) == OK, "Engine-Aufnahme: " + label)
	RenderingServer.render_loop_enabled = false


func _phase(name: String, seconds: float, kind: String) -> void:
	phases.append({"phase":name, "seconds":snappedf(seconds, 0.01), "kind":kind})


## Plays the current film on Main's clock until a choice or the handoff.
func _watch(name: String, limit := 240.0) -> void:
	var elapsed := 0.0
	Engine.time_scale = FILM_TEST_SPEED
	while game.screen == "opening" and elapsed < limit:
		var beat: Dictionary = game.opening_sequence.beats[game.opening_index]
		if game._film_choice_open(beat) or bool(beat.get("final", false)):
			break
		await process_frame
		elapsed += STEP * FILM_TEST_SPEED
	Engine.time_scale = 1.0
	_phase(name, elapsed, "film")


func _choose(action_id: String) -> void:
	var button: Button = game.opening_overlay.find_child("OpeningChoice_" + action_id, true, false)
	check(button != null, "Film choice available: " + action_id)
	if button != null:
		button.pressed.emit()
	for i in 4:
		await process_frame


func _confirm_handoff() -> void:
	game.opening_overlay._request_advance()
	for i in 6:
		await process_frame


## Walks through waypoints with the regular camera-relative movement input.
## When the body stops against furniture, a wall edge or a person, it steers
## around like a player would (alternating 70° sidesteps), within a time cap.
func _walk(name: String, waypoints: Array, limit := 90.0) -> void:
	var elapsed := 0.0
	var player: CharacterBody3D = game.world.get_node("Player")
	var detours := 0
	for target: Vector2 in waypoints:
		var last := Vector2(player.global_position.x, player.global_position.z)
		var stuck := 0.0
		var sidestep := 0.0
		var side := 1.0
		while elapsed < limit:
			var at := Vector2(player.global_position.x, player.global_position.z)
			var to := target - at
			if to.length() < 0.35:
				break
			var world_dir := Vector3(to.x, 0.0, to.y).normalized()
			if sidestep > 0.0:
				world_dir = world_dir.rotated(Vector3.UP, side * deg_to_rad(70.0))
				sidestep -= STEP
			var axis := world_dir.rotated(Vector3.UP, -float(game.world.get("_camera_yaw")))
			game.ui.action_requested.emit("move_axis", {"x":axis.x, "y":axis.z})
			await physics_frame
			elapsed += STEP
			var now := Vector2(player.global_position.x, player.global_position.z)
			walked += now.distance_to(last)
			stuck = stuck + STEP if now.distance_to(last) < 0.003 else 0.0
			last = now
			if stuck > 0.4 and sidestep <= 0.0:
				detours += 1
				sidestep = 0.7
				side = -side
				stuck = 0.0
		if elapsed >= limit:
			check(false, "%s: did not reach %s within %.0f s (at %s)" % [name, target, limit, Vector2(player.global_position.x, player.global_position.z)])
			break
	game.ui.action_requested.emit("move_axis", {"x":0.0, "y":0.0})
	for i in 30:
		await physics_frame
	elapsed += 30 * STEP
	phases.append({"phase":name, "seconds":snappedf(elapsed, 0.01), "kind":"walk", "detours":detours})


func _interact(label: String) -> void:
	game.ui.action_requested.emit("interact", {})
	for i in 6:
		await process_frame
	_phase(label, 6 * STEP, "action")


func _dialogue_choice(caption: String) -> void:
	for i in 4:
		await process_frame
	var button := _find_button(game.ui, caption)
	check(button != null, "Dialogue choice visible: " + caption)
	if button != null:
		button.pressed.emit()
	for i in 6:
		await process_frame


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	game = Entry.instantiate()
	root.add_child(game)
	for i in 4:
		await process_frame
	game.ui._finish_intro()
	var new_life := _find_button(game.ui, "Neues Leben")
	if not check(new_life != null, "Neues Leben ist im Hauptmenü erreichbar"):
		quit(1)
		return
	new_life.pressed.emit()
	for i in 4:
		await process_frame
	check(game.screen == "opening" and game.opening_sequence.id == "i00_aquileia", "I-00 öffnet mit echtem Filmablauf")
	await _capture("01-prolog")
	await _watch("I-00 Prolog")
	await _confirm_handoff()
	await _watch("VID-A bis zur Wahl")
	check(game._film_choice_open(game.opening_sequence.beats[game.opening_index]), "VID-A waits for the choice")
	await _capture("02-morgenwahl")
	await _choose("i01_help")
	await _watch("VID-A Reaktion und Übergabe")
	await _confirm_handoff()
	check(game.screen == "playing", "Control returns at the bed")
	check(int(game.model.data.player.age) == 12 and int(game.model.data.resources.denarii) == 0, "Regulärer Start als Zwölfjähriger ohne eigenes Geld")
	await _capture("03-familienhaus")
	# Measured level route: the door ramp leads out toward the provision store,
	# so the way to the well goes around its south side (probe of real colliders).
	var door_in := Vector2(-13.0, 12.2)
	var door_out := Vector2(-13.0, 15.7)
	var store_corner := Vector2(-13.0, 17.4)
	var store_east := Vector2(-8.1, 17.4)
	var to_well := [door_in, door_out, store_corner, store_east, Vector2(-8.1, 7.6)]
	var from_well := [store_east, store_corner, door_out, door_in, I01.POINTS.player_table]
	await _walk("Bett -> Regal", [Vector2(-12.6, 11.55), Vector2(-14.5, 11.7)])
	await _interact("Becher nehmen")
	await _walk("Regal -> Tisch", [I01.POINTS.player_table])
	for i in 3:
		await _interact("Becher abstellen")
	check(game.model.data.village.childhood.screenplay.i01_table_by == "player", "Three cups set on the table by walking and interacting")
	await _walk("Tisch -> Brunnen", to_well)
	await _capture("04-brunnen")
	await _interact("Wasser schöpfen")
	await _walk("Brunnen -> Tisch", from_well)
	await _interact("Becher füllen")
	await _interact("Frühstück")
	check(game.screen == "opening" and game.opening_sequence.id == "i01_vid_b", "Breakfast opens VID-B")
	await _watch("VID-B bis zur Themenwahl")
	await _capture("05-tischgespraech")
	await _choose("i01_topic_workshop")
	await _watch("VID-B Antwort und Übergabe")
	await _confirm_handoff()
	# Julia clears the table: her errand and the jug are both at the table.
	# Silvanus leaves for his door work on his own; Julia is addressed across
	# the table once he has passed (otherwise he is the nearest person).
	var waited := 0.0
	while waited < 10.0:
		var father_body: Vector3 = game.world.village_life_world.actor_position("silvanus")
		var me: Vector3 = game.world.get_player_position()
		if Vector2(father_body.x - me.x, father_body.z - me.z).length() > 3.4:
			break
		await physics_frame
		waited += STEP
	_phase("Silvanus geht hinaus (warten)", waited, "walk")
	await _interact("Julia ansprechen")
	await _dialogue_choice("Mit Mutter den Morgen besprechen")
	game._resume()
	for i in 6:
		await process_frame
	await _interact("Krug nehmen")
	# Silvanus walks from the table to his door work on his own; follow the
	# body the world actually shows instead of a stored point.
	await _walk("Tisch -> Silvanus", [door_in, door_out])
	for attempt in 3:
		var body: Vector3 = game.world.village_life_world.actor_position("silvanus")
		var here: Vector3 = game.world.get_player_position()
		if Vector2(body.x - here.x, body.z - here.z).length() < 1.6:
			break
		var approach := Vector2(body.x, body.z) + (Vector2(here.x, here.z) - Vector2(body.x, body.z)).normalized() * 1.1
		await _walk("Silvanus folgen", [approach], 30.0)
	await _interact("Silvanus ansprechen")
	await _dialogue_choice("Vater den Krug bringen")
	await _watch("VID-C Übergang zu I-02")
	await _confirm_handoff()
	check(Childhood.view(game.model.data).stage == "i02_basket", "I-01 is complete and I-02 begins")
	await _reload_at_basket()
	var totals := {"film":0.0, "walk":0.0, "action":0.0}
	for phase: Dictionary in phases:
		totals[phase.kind] += float(phase.seconds)
	var report := {"route":"help path, workshop topic, scripted waypoints", "phases":phases,
		"totals_seconds":totals, "walked_metres":snappedf(walked, 0.1),
		"excluded":"reading pauses beyond authored beat durations, decision time, exploration, dialogue reading",
		"events":game.model.data.village.childhood.screenplay.i01_events}
	print("I01_PLAYTHROUGH_REPORT " + JSON.stringify(report))
	game.queue_free()
	for i in 3:
		await process_frame
	print(("I01_PLAYTHROUGH_PASS" if failures.is_empty() else "I01_PLAYTHROUGH_FAILED") + " checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _reload_at_basket() -> void:
	var before: Dictionary = game.model.data.duplicate(true)
	var before_position: Vector3 = game.world.get_player_position()
	game.ui.action_requested.emit("save", {})
	check(FileAccess.file_exists(game.SAVE_PATH), "Spielstand über Spiel-UI geschrieben")
	game.queue_free()
	for i in 4:
		await process_frame
	game = Entry.instantiate()
	root.add_child(game)
	for i in 4:
		await process_frame
	game.set_process(false)
	game.ui._finish_intro()
	var resume := _find_button(game.ui, "Fortsetzen")
	if not check(resume != null and not resume.disabled, "Fortsetzen ist nach neuem Aufbau der Hauptszene aktiv"):
		return
	resume.pressed.emit()
	for i in 6:
		await process_frame
	var after: Dictionary = game.model.data
	check(Childhood.view(after).stage == "i02_basket" and game.screen == "playing", "Fortsetzen erreicht denselben Auftrag")
	check(after.world_id == before.world_id, "Fortsetzen behält die Welt-ID")
	check(after.village.childhood.screenplay.i01_events == before.village.childhood.screenplay.i01_events, "I‑01-Erinnerungen überstehen Laden ohne Duplikate")
	check(game.world.get_player_position().distance_to(before_position) < 0.25, "Fortsetzen setzt die Figur am gespeicherten Ort ab")
	await _capture("06-auf-der-schwelle")


func _find_button(node: Node, caption: String) -> Button:
	if node is Button and (node as Button).text.strip_edges().begins_with(caption) and (node as Button).is_visible_in_tree():
		return node
	for child: Node in node.get_children():
		var found := _find_button(child, caption)
		if found != null:
			return found
	return null
