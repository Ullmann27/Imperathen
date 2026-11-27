extends SceneTree
## I-03 through the production Main: films, choice beats, Marcus' own way,
## the stall props and the exact handover to the play camera.
## Handbook mapping (HB S. 14, S. 29, S. 46): T19 (film start -> choice ->
## exact handoff), T20 (skip stops at the open choice, changes nothing), T21
## (Back / suspend / Continue at the same beat, no duplicate event), Marcus
## abwesend (no film, no stand-in), getrennte Route (Marcus walks himself),
## Gegenstand bereits bezahlt, world matches the result texts (coins, pot,
## salt, jug). Travel to the authored places before I-03 is fixture placement.

const Entry = preload("res://main.tscn")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I03 = preload("res://scripts/story/i03_shortcut.gd")
const I03Film = preload("res://scripts/story/i03_film.gd")
const Checkpoint = preload("res://scripts/cinematic/opening_checkpoint.gd")
var game
var checks := 0
var failures: Array[String] = []
var capture_dir := ""
var captures: Array = []
var size := Vector2i(1280, 720)


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("I-03 flow requires isolated settings and saves.")
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
		printerr("I03_FLOW_FAIL: " + message)
	return value


func frames(count := 4) -> void:
	for i in count:
		await process_frame


func _sp() -> Dictionary:
	return game.model.data.village.childhood.screenplay


## Saved numbers come back as floats; compare through one JSON round trip.
func _norm(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))


func _stage() -> String:
	return str(Childhood.view(game.model.data).get("stage", ""))


func _beat() -> Dictionary:
	return game.opening_sequence.beats[game.opening_index] if game.screen == "opening" else {}


func _ctx() -> Dictionary:
	return Childhood.i03_ctx(game.model.data)


func _place(point: Vector2) -> void:
	game.world.get_node("Player").position = Vector3(point.x, 1.35, point.y)
	game.model.set_player_position(game.world.get_player_position())
	game.world.sync_state(game.model.data)


func _place_marcus(point: Vector2) -> void:
	var body: Node3D = game.world._companion
	body.global_position = game.world.to_global(Vector3(point.x, body.position.y, point.y))
	game.model.capture_npc_observations()


func _marcus() -> Vector2:
	var at: Vector3 = game.world._companion.position
	return Vector2(at.x, at.z)


func _press_choice(action_id: String) -> bool:
	var button: Button = game.opening_overlay.find_child("OpeningChoice_" + action_id, true, false)
	if not check(button != null and button.is_visible_in_tree(), "Film choice button is visible: " + action_id):
		return false
	button.pressed.emit()
	await frames(4)
	return true


func _play_film(limit := 400.0) -> float:
	var played := 0.0
	while game.screen == "opening" and played < limit:
		var beat := _beat()
		if game._film_choice_open(beat) or bool(beat.get("final", false)):
			break
		game._opening_process(0.1)
		played += 0.1
	return played


func _finish_film() -> void:
	_play_film()
	if game.screen == "opening" and bool(_beat().get("final", false)):
		var exact: bool = game.opening_director.camera.global_transform.is_equal_approx(game.world.get_node("WorldCamera").global_transform)
		check(exact, "T19: the film ends exactly on the play camera (%s)" % str(game.opening_sequence.id))
		game.opening_overlay._request_advance()
		await frames(6)
	check(game.screen == "playing" and game.world.get_node("WorldCamera").current, "Control returns with the ordinary camera")


## Walks Marcus with the living-world director for up to `seconds`.
func _let_marcus_walk(seconds: float, until: Callable) -> float:
	var walked := 0.0
	game.world._active = true
	while walked < seconds and not until.call():
		game.world._story_companions.advance(1.0 / 30.0)
		walked += 1.0 / 30.0
	game.model.capture_npc_observations()
	return walked


## New life up to the lane: I-00/VID-A through the films, the rest of I-01
## and I-02 through the real commands with fixture placement.
func _to_lane() -> bool:
	game._start_new_game()
	await frames()
	game._opening_skip()
	game._opening_next()
	await frames(6)
	game._opening_skip()
	await _press_choice("i01_talk")
	game._opening_skip()
	game._opening_next()
	await frames(6)
	for _index in 40:
		if game.screen == "opening":
			# Films between the earlier steps: decide open choices, then leave.
			game._opening_skip()
			await frames(2)
			var open: Dictionary = _beat()
			if game._film_choice_open(open):
				await _press_choice(str(open.choices[0].action_id))
				game._opening_skip()
			game._opening_next()
			await frames(4)
			continue
		# Main rejects further childhood commands while the physical I-01
		# action is running. Wait before fixture placement, not after moving
		# the player away from the actual interaction. Never force the clock
		# or clear presentation state: exercise normal process frames.
		var props = game.world.i01_props
		if is_instance_valid(props) and props.water_interaction_active():
			var elapsed := 0.0
			var waited := 0
			while props.water_interaction_active() and elapsed < 12.0 and waited < 2400:
				await process_frame
				elapsed += root.get_process_delta_time()
				waited += 1
			if not check(not props.water_interaction_active(),
					"I-01 water action settles naturally before the next objective"):
				return false
		var view: Dictionary = Childhood.view(game.model.data)
		var stage := str(view.get("stage", ""))
		if stage == "i03_marcus":
			break
		_place(view.point)
		var npc := str(view.get("target_npc", ""))
		if not npc.is_empty() and not bool(Childhood.relationship(game.model.data, npc).get("met", false)):
			game.model.execute("village_talk", {"npc_id":npc, "choice":"meet"})
		view = Childhood.view(game.model.data)
		var action := "basket_check" if stage == "i02_basket" else str(view.actions[0].payload.action_id)
		var result: Dictionary = game._command("village_childhood_action", {"action_id":action})
		if not check(bool(result.get("ok", false)), "Reach the lane, step %s: %s" % [stage, str(result.get("message", ""))]):
			return false
		await frames(2)
	if game.screen == "opening":
		game._opening_skip()
		game._opening_next()
		await frames(4)
	return check(_stage() == "i03_marcus" and game.screen == "playing", "The lane with Marcus is the current objective")


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
	# Preserve all I-03 assertions on a valid setup. On setup failure the
	# test exits nonzero rather than reporting unrelated cascade failures.
	if await _to_lane():
		await _test_absent_marcus()
		await _test_vid_a()
		await _test_stall()
		await _test_vid_b_and_service()
		await _test_farewell()
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("i03-flow-report-%dx%d.json" % [size.x, size.y]), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks, "failures":failures, "captures":captures, "size":[size.x, size.y],
			"renderer":RenderingServer.get_current_rendering_method(),
			"note":"Engine frames from the production Main; travel to authored places is fixture placement, Marcus walks with the world director."}, "\t"))
		file.close()
	game.queue_free()
	await frames()
	print(("I03_FLOW_PASS" if failures.is_empty() else "I03_FLOW_FAILED") + " checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_absent_marcus() -> void:
	var lane: Vector2 = I03.POINTS.lane
	_place(lane + Vector2(9.0, 0.0))
	game._show_companion()
	await frames(3)
	check(game.screen == "playing", "From afar no film starts")
	# Marcus is not there: nobody stands in for him, nothing starts.
	game.world._companion.visible = false
	game.model.capture_npc_observations()
	game.model.data.village.behavior.people.marcus.activity = "absent"
	_place(lane + Vector2(1.0, 0.3))
	var before := JSON.stringify(game.model.data.village.childhood)
	game._show_companion()
	await frames(3)
	check(game.screen == "playing" and JSON.stringify(game.model.data.village.childhood) == before, "Marcus absent: no film, no event, no stand-in")
	check(game.world.get_cinematic_figure("marcus") == null, "No invisible substitute figure exists for the film")
	game.world._companion.visible = true
	game.model.data.village.behavior.people.marcus.activity = "rest"
	_place_marcus(lane)


func _test_vid_a() -> void:
	var before := _norm(game.model.data.village.childhood)
	game._show_companion()
	await frames(4)
	if not check(game.screen == "opening" and game.opening_sequence.id == I03Film.VID_A, "T19: reaching Marcus starts VID-A"):
		return
	check(str(_beat().shot_id) == "duo_hands" and str(_beat().line_id) == "I03_A_COINS", "The picture opens on the coins in Marcus' hand")
	check(_norm(game.model.data.village.childhood) == before, "A film start alone changes nothing")
	var director: Node3D = game.opening_director
	var marcus: Vector3 = game.world._companion.global_position
	var boy: Vector3 = game.world.get_player_position()
	director.mission_actor_id = "marcus"
	var wide: Dictionary = director.sample("duo_wide", 0.5)
	var to_marcus := (marcus - (wide.position as Vector3)).normalized()
	var to_boy := (boy - (wide.position as Vector3)).normalized()
	var forward: Vector3 = -(wide.transform as Transform3D).basis.z
	check(forward.dot(to_marcus) > 0.75 and forward.dot(to_boy) > 0.75, "The wide shot holds both boys in the same street")
	var close: Dictionary = director.sample("duo_close", 0.5)
	check(float(close.fov) < float(wide.fov) and (close.position as Vector3).distance_to(marcus) < (wide.position as Vector3).distance_to(marcus), "The close shot is tighter and nearer than the wide one")
	director.sample(str(_beat().shot_id), 0.0)
	await capture("vid-a-coins")
	# T20: skip lands on the open choice and decides nothing.
	game.opening_overlay._request_skip()
	await frames(3)
	check(str(_beat().get("id", "")) == "i03_a_choice" and game._film_choice_open(_beat()) and _norm(game.model.data.village.childhood) == before, "T20: skip stops at the route choice and chooses nothing")
	var choice_index: int = game.opening_index
	await capture("vid-a-choice")
	# T21: Back pauses, suspend checkpoints, Continue returns to the same beat.
	root.go_back_requested.emit()
	check(game.opening_paused, "T21: Back pauses the film")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var checkpoint: Dictionary = Checkpoint.read(str(game.model.data.world_id))
	check(checkpoint.get("sequence_id", "") == I03Film.VID_A and int(checkpoint.get("index", -1)) == choice_index, "T21: suspend checkpoints the choice beat")
	game._show_menu()
	game._continue_game()
	await frames(6)
	check(game.screen == "opening" and game.opening_sequence.id == I03Film.VID_A and game.opening_index == choice_index and _norm(game.model.data.village.childhood) == before, "T21: Continue returns to the same beat without an event")
	await _press_choice("i03_later")
	check(_sp().i03_route == "later" and _sp().i03_events == ["I-03.route.later"], "The route is committed once by the film choice")
	check(str(_beat().get("line_id", "")) == "I03_A_REACT_LATER", "Marcus answers the chosen route")
	await capture("vid-a-react")
	await _finish_film()
	check(_stage() == "i03_coin", "The stall is the next objective")


func _test_stall() -> void:
	var ctx := _ctx()
	var stall: Vector2 = I03.marcus_stall(ctx)
	# Getrennte Route / später treffen: Marcus walks to the stall himself.
	var start := _marcus().distance_to(stall)
	var walked := _let_marcus_walk(12.0, func() -> bool: return false)
	check(_marcus().distance_to(stall) < start - 3.0 and str(game.world._companion.get_meta("companion_mode", "")) == "errand", "Marcus walks his own way to the stall (%.1f m in %.1f s)" % [start - _marcus().distance_to(stall), walked])
	_place((ctx.cassia as Vector2) + Vector2(0.4, 2.2))
	if not bool(Childhood.relationship(game.model.data, "cassia").get("met", false)):
		game.model.execute("village_talk", {"npc_id":"cassia", "choice":"meet"})
	var early: Dictionary = game._command("village_childhood_action", {"action_id":"i03_watch"})
	check(not early.get("ok", false) and str(early.get("message", "")).contains("noch nicht"), "The dispute waits until Marcus has really arrived: " + str(early.get("message", "")))
	var rest := _let_marcus_walk(60.0, func() -> bool: return _marcus().distance_to(stall) <= 1.0)
	check(_marcus().distance_to(stall) <= 1.0, "Marcus arrives at the stall on foot (%.1f s more)" % rest)
	var props: Node3D = game.world.i03_props
	game.world.sync_state(game.model.data)
	check(props.get_node("StallGoods").visible and not props.coins_visible() and props.pot_fill() == "absent", "The measures stand on the stall; no coins lie on it before the dispute")
	# The stall is the table of the existing trading shelter where Cassia works.
	var table: Dictionary = game.world.village_life_world.workplaces.get("trade", {})
	var table_at: Vector3 = (table.node as Node3D).position if table.has("node") else Vector3.INF
	check(table_at.distance_to(Vector3(I03.STALL_TABLE.x, 0.0, I03.STALL_TABLE.z)) < 0.01, "The goods lie on the real trading table")
	var coins: Vector3 = game.world.get_cinematic_anchor("i03_coins")
	check(absf(coins.x - table_at.x) < 1.5 and absf(coins.z - table_at.z) < 0.6 and absf(coins.y - 0.925) < 0.02, "Coins rest on the table top inside its footprint")
	check((ctx.cassia as Vector2).distance_to(Vector2(I03.STALL_TABLE.x, I03.STALL_TABLE.z)) < 3.2, "Cassia stands at her stall")
	await capture("stall-before")
	var result: Dictionary = game._command("village_childhood_action", {"action_id":"i03_offer"})
	await frames(4)
	check(bool(result.get("ok", false)) and _sp().i03_events.has("I-03.promise.kept"), "The stance is taken at the stall; the promise to come was kept")
	check(props.coins_visible() and props.pot_fill() == "empty", "World matches the text: two asses and the empty pot lie on the stall")


func _test_vid_b_and_service() -> void:
	if not check(game.screen == "opening" and game.opening_sequence.id == I03Film.VID_B, "The committed stance opens VID-B"):
		return
	await capture("vid-b-stall")
	var ids: Array = game.opening_sequence.beats.map(func(b): return str(b.id))
	game.opening_index = ids.find("i03_b_coins")
	game._opening_present()
	var anchor: Vector3 = game.world.get_cinematic_anchor("i03_coins")
	var camera: Camera3D = game.opening_director.camera
	check(bool(_beat().get("silent", false)) and (-camera.global_basis.z).dot((anchor - camera.global_position).normalized()) > 0.97 and camera.global_position.distance_to(anchor) < 1.2, "The pause rests on the coins on the stall")
	check(not game.opening_overlay.find_child("OpeningSubtitlePanel", true, false).visible, "A silent pause shows no text panel")
	await capture("vid-b-coins")
	game.opening_index = ids.find("i03_b_cassia")
	game._opening_present()
	check(str(game._beat_cut(_beat(), 0.5).actor_id) == "marcus" and str(game._beat_cut(_beat(), 0.9).actor_id) == "cassia", "Marcus' reaction is cut into Cassia's explanation")
	await capture("vid-b-cassia")
	var before := JSON.stringify(game.model.data.village.childhood)
	game.opening_overlay._request_skip()
	await frames(3)
	check(str(_beat().get("id", "")) == "i03_b_choice" and JSON.stringify(game.model.data.village.childhood) == before, "T20: skip stops at the proposal and decides nothing")
	await capture("vid-b-choice")
	await _press_choice("i03_accept")
	check(str(_beat().get("line_id", "")) == "I03_B_RESOLVE_SERVICE" and _sp().i03_task == "service_fetch", "Cassia names the service because help was offered")
	await _finish_film()
	var props: Node3D = game.world.i03_props
	check(props.coins_visible() and props.pot_fill() == "empty", "Nothing is paid by the film: coins still lie there, the pot is empty")
	check(_stage() == "i03_service_fetch" and str(Childhood.view(game.model.data).hud_title).contains("Brunnen"), "The well is the objective: " + str(Childhood.view(game.model.data).hud_title))
	_place(I03.POINTS.well + Vector2(1.5, 0.3))
	game.ui.action_requested.emit("interact", {})
	await frames(4)
	check(_sp().i03_task == "service_bring" and props.jug_in_hand(), "The filled jug is really in the boy's hand")
	_check_market_grip(props, "Before LOD switch")
	var carried: Node3D = props._jug
	var actor = game.world._figure
	actor._reload((actor.detail+1)%4)
	await frames(6)
	check(is_instance_valid(carried) and carried == props._jug and carried.get_parent() == props and props.jug_in_hand(),"Market jug survives LOD replacement without being duplicated or freed")
	_check_market_grip(props, "After LOD switch")
	await capture("well-jug")
	_place((_ctx().cassia as Vector2) + Vector2(0.4, 2.2))
	game.model.capture_npc_observations()
	var bring: Dictionary = game._command("village_childhood_action", {"action_id":"i03_service_bring"})
	await frames(4)
	check(bool(bring.get("ok", false)) and not props.jug_in_hand() and not props.coins_visible() and props.pot_fill() == "large", "After the service the jug is gone, Cassia has the coins, the pot holds the large measure")
	var again: Dictionary = game._command("village_childhood_action", {"action_id":"i03_service_bring"})
	check(not again.get("ok", false) and str(again.get("message", "")).contains("bereits"), "Gegenstand bereits bezahlt: " + str(again.get("message", "")))
	await capture("stall-paid")
	if game.screen == "opening":
		game._opening_skip()
		game._opening_next()
		await frames(4)


# Test the measured local handle point on the live model against the hand
# pose rather than treating visibility as a contact test. The former origin
# offset fails this check even when the pitcher is visible.
func _check_market_grip(props: Node3D, label: String) -> void:
	var rig: Skeleton3D = props._skeleton
	var jug: Node3D = props._jug
	if not check(is_instance_valid(rig) and is_instance_valid(jug) and props._left_bone >= 0, label + ": live hand and pitcher"):
		return
	var wrist := rig.to_global(rig.get_bone_global_pose(props._left_bone).origin)
	var basis := jug.global_basis.orthonormalized()
	var grip := jug.to_global(Vector3(0.168, 0.28, 0.0))
	var palm := wrist + basis * Vector3(0.0, 0.0, 0.035)
	check(grip.distance_to(palm) <= 0.005, label + ": measured handle is within 5 mm of palm target (" + str(grip.distance_to(palm)) + ")")
	check(basis.y.dot(Vector3.UP) > 0.98, label + ": carried pitcher stays upright")


func _test_farewell() -> void:
	for _index in 6:
		if game.screen == "opening":
			break
		var view: Dictionary = Childhood.view(game.model.data)
		if str(view.stage) not in ["market_meeting", "market_purchase"]:
			break
		_place((_ctx().cassia as Vector2) + Vector2(0.4, 2.2))
		var step: Dictionary = game._command("village_childhood_action", {"action_id":str(view.actions[0].payload.action_id)})
		check(bool(step.get("ok", false)), "Julia's order: " + str(view.stage) + " " + str(step.get("message", "")))
		await frames(4)
	if not check(game.screen == "opening" and game.opening_sequence.id == I03Film.VID_C, "With the order bought VID-C opens at the stall"):
		return
	check(not game.model.data.companion.met, "Nothing is summarised about Marcus before they part")
	var lines: Array = game.opening_sequence.beats.map(func(b): return str(b.get("line_id", "")))
	check(lines.has("I03_C_OPEN_FRIENDLY"), "Marcus opens according to what happened: " + str(lines))
	await capture("vid-c-pot")
	game.opening_overlay._request_skip()
	await frames(3)
	var labels: Array = _beat().get("choices", []).map(func(c): return str(c.action_id))
	check(labels == ["i03_home_together", "i03_home_apart"], "No apology is offered without a dispute: " + str(labels))
	await capture("vid-c-choice")
	await _press_choice("i03_home_together")
	check(_sp().i03s == "complete" and game.model.data.companion.met and game.model.data.companion.choice == "help", "The parting summarises the stored memories")
	check(_sp().i03_events == ["I-03.route.later", "I-03.stance.offer", "I-03.promise.kept", "I-03.resolve.accept", "I-03.service.water", "I-03.service.done", "I-03.salt.large", "I-03.home.together"], "Ledger: " + str(_sp().i03_events))
	await _finish_film()
	check(_stage() == "deliver_food" and Childhood.validate(game.model.data).is_empty(), "Julia's order goes home")
	game.world.sync_state(game.model.data)
	check(game.world.i03_props.pot_fill() == "absent", "Marcus takes his pot with him")
	# Saving and continuing keeps the finished errand.
	game._show_menu()
	game._continue_game()
	await frames(6)
	check(_stage() == "deliver_food" and _sp().i03s == "complete" and game.model.data.companion.met, "Continue keeps the finished errand")


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
	var name := "%dx%d-i03-%s" % [size.x, size.y, id]
	check(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Saved " + name)
	var cam: Camera3D = root.get_camera_3d()
	captures.append({"id":id, "file":name + ".png", "screen":game.screen, "sequence":str(game.opening_sequence.get("id", "")) if game.screen == "opening" else "",
		"beat":str(_beat().get("id", "")), "shot_id":str(game.opening_director.shot_id) if game.screen == "opening" else "play",
		"camera":[cam.global_position.x, cam.global_position.y, cam.global_position.z] if cam else [], "fov":cam.fov if cam else 0.0})
