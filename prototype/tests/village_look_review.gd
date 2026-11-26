extends SceneTree
## Reproducible Valdora look-development shots through the real game path
## (main.tscn -> new life -> village). Four fixed views per quality profile:
##   start         the I-01 start view inside the family house (game camera)
##   path          third-person view along the village lane (game camera rig)
##   conversation  over-the-shoulder two-shot of the player and a resident
##   overview      a wide elevated view over the village
## Positions are restored after every shot; the canonical world state is
## compared before and after each profile and reported on any difference.
## Writes <label>-<shot>-<profile>.png and look.json with render counters.
## Frame times come from whatever renderer runs the script (often software):
## they are a relative indicator between shots, never device performance.
## Usage: --script res://tests/village_look_review.gd ++ <out_dir> [label] [frames] [profiles,csv]

const SHOTS := ["start", "path", "conversation", "overview"]
const PATH_POSITION := Vector3(0.9, 0.0, 12.5)
const PATH_YAW := 0.0
const PATH_PITCH := 0.24
const OVERVIEW_EYE := Vector3(31.0, 17.5, 33.0)
const OVERVIEW_TARGET := Vector3(-4.0, 1.0, -9.0)
var output: String
var label := "look"
var frames := 4
var profiles: Array = ["balanced", "very_high"]
var game
var report := {}
var errors: Array[String] = []
var _turned := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("A graphical viewport, isolated XDG directory and output path are required.")
		quit(2)
		return
	output = args[0]
	if args.size() > 1:
		label = args[1]
	if args.size() > 2:
		frames = clampi(args[2].to_int(), 2, 120)
	if args.size() > 3:
		profiles = Array(args[3].split(",", false))
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	report = {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(),
		"output_pixels": [root.size.x, root.size.y], "frames_per_measurement": frames,
		"note": "Frame times are relative indicators on this renderer/driver, not device performance.",
		"shots": {}}
	game.ui._finish_intro()
	game._start_new_game()
	for attempt in 4:
		if game.screen != "opening":
			break
		game._opening_skip()
		game._opening_next()
		await process_frame
	if game.screen != "playing":
		errors.append("Opening did not hand over to play: " + str(game.screen))
	for i in 12: await physics_frame
	game._refresh()
	game._save(false)
	game._continue_game()
	game.set_process(false)
	game.world.set_physics_process(false)
	game.world._camera_initialized = false
	game.world._update_camera(0)
	game._refresh()
	game.ui._toast_panel.hide()
	game.ui.hide()
	var world = game.world
	var camera: Camera3D = world._camera
	var start := {"player": world._player.global_position, "yaw": world._camera_yaw, "pitch": world._camera_pitch,
		"camera": camera.global_transform, "fov": camera.fov, "figure_yaw": world._figure.rotation.y}
	var snapshot: String = JSON.stringify(game.model.data)
	report.start_state = {"world_sha256": snapshot.sha256_text(), "player": str(start.player), "camera": str(start.camera)}
	report.player_lift = start.player.y - _floor(start.player)
	world.set_presentation_time(4.0)
	Engine.time_scale = 0
	for profile: String in profiles:
		game.ui.set_quality(profile)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		for shot: String in SHOTS:
			if not await _frame(shot, start):
				continue
			await _settle()
			var stats := await _measure()
			stats.camera = str(camera.global_transform)
			if not report.shots.has(shot):
				report.shots[shot] = {}
			report.shots[shot][profile] = stats
			_capture("%s-%s-%s" % [label, shot, profile])
			_restore(start)
		var now: String = JSON.stringify(game.model.data)
		if _without_revision(snapshot) != _without_revision(now):
			errors.append("World state changed in %s: %s" % [profile, _differences(JSON.parse_string(snapshot), JSON.parse_string(now), "")])
	report.errors = errors
	var file := FileAccess.open(output.path_join(label + "-look.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("VILLAGE_LOOK_REVIEW ", JSON.stringify(errors))
	Engine.time_scale = 1
	game.free()
	quit(0 if errors.is_empty() else 1)


func _frame(shot: String, start: Dictionary) -> bool:
	var world = game.world
	var camera: Camera3D = world._camera
	match shot:
		"start":
			_restore(start)
			world._camera_initialized = false
			world._update_camera(0)
		"path":
			_place_player(PATH_POSITION, PATH_YAW)
			world._camera_yaw = PATH_YAW
			world._camera_pitch = PATH_PITCH
			world._camera_initialized = false
			world._update_camera(0)
		"conversation":
			# Over-the-shoulder two-shot: the player stands at talking distance on
			# open floor, the resident turns to the player, the camera sits behind
			# the player's shoulder.
			var id := _conversation_partner()
			if id.is_empty():
				errors.append("No visible resident for the conversation shot")
				return false
			var at: Vector3 = world.village_life_world.actor_position(id)
			var actor: Node3D = world.village_life_world.actors[id]
			var body: Node3D = actor.get_node("Figure") if actor.has_node("Figure") else actor
			var facing := -body.global_basis.z
			facing.y = 0
			facing = facing.normalized() if facing.length() > .1 else Vector3.BACK
			var away := _open_direction(at, [facing, -facing, facing.rotated(Vector3.UP, PI / 2), facing.rotated(Vector3.UP, -PI / 2)])
			_place_player(at + away * 1.35, atan2(away.x, away.z))
			_turned = {"node": body, "yaw": body.global_rotation.y}
			body.global_rotation.y = atan2(away.x, away.z) + PI
			var feet: Vector3 = world.get_player_position() - Vector3.UP * float(report.player_lift)
			var side := Vector3.UP.cross(-away).normalized()
			camera.fov = 44.0
			camera.global_position = feet + away * 1.15 - side * .52 + Vector3.UP * 1.62
			camera.look_at(Vector3(at.x, feet.y, at.z) + Vector3.UP * 1.42 - side * .18, Vector3.UP)
			report["conversation_partner"] = id
			report["conversation_layout"] = {"partner": str(at), "direction": str(away), "player": str(world.get_player_position()), "camera": str(camera.global_position)}
		"overview":
			camera.global_position = OVERVIEW_EYE
			camera.look_at(OVERVIEW_TARGET, Vector3.UP)
	for figure in root.get_tree().get_nodes_in_group("village_people"):
		if figure.has_method("refresh_lod") and figure.is_visible_in_tree():
			figure.refresh_lod(camera)
	world.population.update_nearby(world.get_player_position(), true)
	return true


## First direction from `at` with level floor 1.35 m away and a clear chest-high line.
func _open_direction(at: Vector3, candidates: Array) -> Vector3:
	var world = game.world
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ground := _floor(at + Vector3.UP * .5)
	for direction: Vector3 in candidates:
		var stand: Vector3 = at + direction * 1.35
		if absf(_floor(Vector3(stand.x, ground + .5, stand.z)) - ground) > .3:
			continue
		var line := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2 + direction * .35, stand + Vector3.UP * 1.2 + direction * .6, 1, [world._player.get_rid()])
		if space.intersect_ray(line).is_empty():
			return direction
	errors.append("No open floor beside the conversation partner")
	return candidates[0]


func _conversation_partner() -> String:
	var life = game.world.village_life_world
	for id in ["julia", "silvanus", "sextus", "cassia"]:
		if life.actors.has(id) and (life.actors[id] as Node3D).is_visible_in_tree():
			return id
	return ""


func _place_player(at: Vector3, yaw: float) -> void:
	# Keep the capsule's authored height above whatever floor is under it.
	var world = game.world
	var lift: float = float(report.get("player_lift", 1.0))
	world._player.global_position = Vector3(at.x, _floor(at) + lift, at.z)
	world._figure.rotation.y = yaw


func _floor(at: Vector3) -> float:
	var world = game.world
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 1.0, at.z), Vector3(at.x, at.y - 6.0, at.z), 1, [world._player.get_rid()])
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else 0.0


func _restore(start: Dictionary) -> void:
	var world = game.world
	if not _turned.is_empty():
		(_turned.node as Node3D).global_rotation.y = float(_turned.yaw)
		_turned = {}
	if not world._village_focus.is_empty():
		world.clear_frontier_focus()
	world._player.global_position = start.player
	world._figure.rotation.y = start.figure_yaw
	world._camera_yaw = start.yaw
	world._camera_pitch = start.pitch
	world._camera.fov = start.fov
	world._camera.global_transform = start.camera


func _settle() -> void:
	for i in 5: await RenderingServer.frame_post_draw


func _measure() -> Dictionary:
	var rid := root.get_viewport_rid()
	var wall := []
	var cpu := []
	var gpu := []
	var calls := []
	var primitives := []
	var objects := []
	var previous := Time.get_ticks_usec()
	for i in frames:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		wall.append((now - previous) / 1000.0)
		previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		calls.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		primitives.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
		objects.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME))
	return {"wall_ms_p50": _median(wall), "viewport_cpu_ms_p50": _median(cpu), "viewport_gpu_ms_p50": _median(gpu),
		"draw_calls": _median(calls), "primitives": _median(primitives), "objects": _median(objects),
		"shadow_draw_calls": root.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"shadow_primitives": root.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"render_scale": root.scaling_3d_scale,
		"texture_mib": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		"buffer_mib": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		"video_mib": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0}


## "revision" counts model notifications (e.g. the quality setting), not world content.
func _without_revision(json: String) -> String:
	var data: Dictionary = JSON.parse_string(json)
	data.erase("revision")
	return JSON.stringify(data)


func _differences(before: Variant, after: Variant, path: String) -> Array:
	if typeof(before) == TYPE_DICTIONARY and typeof(after) == TYPE_DICTIONARY:
		var found := []
		for key in before.keys() + after.keys():
			if before.get(key) != after.get(key) and not found.has(path + "/" + str(key)):
				found.append_array(_differences(before.get(key), after.get(key), path + "/" + str(key)))
		return found.slice(0, 8)
	return [path] if before != after else []


func _median(values: Array) -> float:
	values.sort()
	return float(values[values.size() / 2])


func _capture(name: String) -> void:
	var shot := root.get_texture().get_image()
	if shot == null or shot.is_empty() or shot.save_png(output.path_join(name + ".png")) != OK:
		errors.append("Empty viewport capture: " + name)
