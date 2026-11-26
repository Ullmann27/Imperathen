extends Node
## Runs only when a debug QA installation has an explicit app-private request.
## The driver operates the same village, settings, HUD and battle model as a player.
## Mode "views" renders the fixed renderer-comparison views of
## scripts/rendering/render_bench.gd in all four profiles (D-033/D-034), so a
## Fold7 run is directly comparable with tests/render_comparison.gd.

const PROFILES := ["low", "balanced", "high", "very_high"]
const Bench = preload("res://scripts/rendering/render_bench.gd")
## Device sampling per view: settle, then measure (about 0.5 s and 4 s at 60 FPS).
## The flag file may override them: "views <settle> <measure>".
const VIEW_SETTLE_FRAMES := 30
const VIEW_MEASURE_FRAMES := 240
var view_settle := VIEW_SETTLE_FRAMES
var view_measure := VIEW_MEASURE_FRAMES
const PHASE_SECONDS := 300.0
var output: FileAccess
var mode := ""
var phase := 0
var village_profile := -1
var stage := "village"
var phase_usec := 0
var last_frame := 0
var last_step := 0
var previous_battle := 0
var total_steps := 0
var round_number := 0
var frames := []
var last_flush := 0
var last_progress := 0
var phase_started := 0
var animation_census := {}

func _ready() -> void:
	var request := FileAccess.get_file_as_string("user://graphics-probe.txt").strip_edges().split(" ", false)
	mode = request[0] if not request.is_empty() else ""
	if mode == "views" and request.size() >= 3:
		view_settle = clampi(request[1].to_int(), 1, 600)
		view_measure = clampi(request[2].to_int(), 2, 3600)
	if mode not in ["soak", "renderer", "quick", "views"]:
		queue_free()
		return
	output = FileAccess.open("user://graphics-frames.jsonl", FileAccess.WRITE)
	process_priority = 100
	_write({"event":"device","mode":mode,"method":RenderingServer.get_current_rendering_method(),
		"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"architecture":Engine.get_architecture_name(),"version":Engine.get_version_info().string})
	# The game UI may change viewport settings while constructing the main scene.
	set_process(true)

func _write(row: Dictionary) -> void:
	row.elapsed_usec = Time.get_ticks_usec()
	output.store_line(JSON.stringify(row))
	output.flush()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_RESUMED:
		last_frame = 0

func _process(_delta: float) -> void:
	var game = get_tree().current_scene
	if not is_instance_valid(game) or not is_instance_valid(game.get("ui")):
		return
	if stage == "village":
		if game.screen == "intro":
			game.ui._finish_intro()
			return
		if game.screen == "menu":
			game._on_ui_action("continue" if FileAccess.file_exists(game.SAVE_PATH) else "new_game", {})
			return
		if mode == "views" and game.screen == "opening":
			# A fresh QA install has no save; the bench needs the village, not the story.
			game._opening_skip()
			game._opening_next()
			return
		if game.screen != "playing":
			return
		if mode == "views":
			set_process(false)
			_views(game)
			return
		if village_profile >= 0:
			var actual: String = game.world.get_quality_profile()
			if actual != PROFILES[village_profile] or game.ui.get_quality() != actual:
				_fail("Village profile did not propagate")
				return
			_write({"event":"village_profile","quality":actual,"visible":game.world.is_visible_in_tree(),"scene":game.screen,
				"metrics":_counters(game.world)})
		village_profile += 1
		if village_profile < PROFILES.size():
			game.ui.set_quality(PROFILES[village_profile])
			return
		if mode == "renderer":
			_finish()
			return
		game._show_menu()
		stage = "battle"
		return
	if game.screen == "menu":
		game._on_ui_action("valley_demo", {})
		return
	if game.screen != "valley" or not is_instance_valid(game.valley):
		return
	var valley = game.valley
	if valley.model.outcome != "ongoing":
		_flush()
		_write({"event":"round_end","round":round_number,"steps":valley.model.steps,"outcome":valley.model.outcome})
		last_frame = 0
		game._leave_valley()
		return
	if previous_battle != valley.get_instance_id() or valley.profile != PROFILES[phase]:
		previous_battle = valley.get_instance_id()
		animation_census.clear()
		valley.hud.quality_picker.select(phase)
		valley.hud.quality_picker.item_selected.emit(phase)
		if valley.profile != PROFILES[phase] or game.ui.get_quality() != valley.profile:
			_fail("Valley profile did not propagate")
			return
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
		last_frame = 0
	if valley.paused:
		valley.hud.pause_button.pressed.emit()
		round_number += 1
		last_step = valley.model.steps
		last_frame = 0
		if valley.paused:
			_fail("Fortsetzen did not unpause the battle")
		return
	var now := Time.get_ticks_usec()
	if last_frame == 0:
		last_frame = now
		last_progress = now
		if phase_started == 0:
			phase_started = now
		return
	var frame_usec := now - last_frame
	last_frame = now
	if frame_usec > 20000000:
		_write({"event":"excluded_gap","quality":PROFILES[phase],"seconds":frame_usec / 1000000.0})
		last_progress = now
		return
	var step := int(valley.model.steps)
	if step > last_step:
		total_steps += step - last_step
		last_progress = now
	if now - last_progress > 20000000:
		_fail("Unpaused battle stopped advancing")
		return
	last_step = step
	phase_usec += frame_usec
	var rid := get_viewport().get_viewport_rid()
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	frames.append([frame_usec * 0.001, cpu if cpu > 0 else null, gpu if gpu > 0 else null])
	if now - last_flush >= 5000000:
		_flush()
		_write({"event":"sample","quality":PROFILES[phase],"round":round_number,"step":step,"total_steps":total_steps,
			"active_usec":phase_usec,"metrics":_counters(valley)})
	if phase_usec >= int((1.0 if mode == "quick" else PHASE_SECONDS) * 1000000):
		_flush()
		_write({"event":"phase_end","quality":PROFILES[phase],"active_usec":phase_usec,
			"wall_usec":now-phase_started,"total_steps":total_steps,"round":round_number})
		phase += 1
		if phase == PROFILES.size():
			_finish()
		else:
			phase_usec = 0
			phase_started = 0
			last_frame = 0

## Same views, cameras, harness night and counters as the desktop comparison.
## Simulation, input and time are frozen while measuring and restored afterwards.
func _views(game: Node) -> void:
	for i in 30:
		await get_tree().process_frame
	var world = game.world
	var start: Dictionary = Bench.village_start(world)
	var previous_profile: String = game.ui.get_quality()
	game.set_process(false)
	world.set_physics_process(false)
	world.set_presentation_time(4.0)
	Engine.time_scale = 0
	_write({"event":"views_start","renderer":Bench.renderer_info(),"views":Bench.VILLAGE_VIEWS,
		"settle_frames":view_settle,"measure_frames":view_measure})
	for profile: String in PROFILES:
		game.ui.set_quality(profile)
		for view: String in Bench.VILLAGE_VIEWS:
			if not Bench.stage_village(world, view, start):
				_fail("Unknown bench view " + view)
				return
			for i in view_settle:
				await Bench.next_frame(get_tree())
			var stats: Dictionary = await Bench.measure(get_viewport(), view_measure)
			stats.engine = Bench.engine_state(get_viewport(), world)
			_write({"event":"view","quality":profile,"view":view,"metrics":stats})
			print("IMPERATHEN_RENDER_BENCH " + JSON.stringify({"quality":profile,"view":view,
				"renderer":stats.engine.renderer.method,"wall_ms_p50":stats.wall_ms_p50,"wall_ms_p95":stats.wall_ms_p95,
				"gpu_ms_p50":stats.render_gpu_ms_p50,"draw_calls":stats.draw_calls,"primitives":stats.primitives,
				"video_mib":stats.video_mib,"rss_mib":stats.rss_mib}))
			Bench.restore_village(world, start)
	Engine.time_scale = 1
	game.ui.set_quality(previous_profile)
	world.set_physics_process(true)
	game.set_process(true)
	_finish()


func _counters(scene: Node) -> Dictionary:
	var viewport := get_viewport()
	var lights := 0
	var shadows := 0
	for light in scene.find_children("*","Light3D",true,false):
		if light.is_visible_in_tree():
			lights += 1
			if light.shadow_enabled:
				shadows += 1
	if stage == "village" or animation_census.is_empty():
		animation_census = _animations(scene)
	var texture := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var buffers := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
	return {"draw_calls":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"visible_primitives":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"texture_mib":texture / 1048576.0 if texture > 0 else null,"mesh_buffer_mib":buffers / 1048576.0 if buffers > 0 else null,
		"animated_valley_actors":scene.actors.size() if stage == "battle" else null,
		"visible_lights":lights,"shadow_casting_lights":shadows, "animation_keys":animation_census.keys_total,
		"shared_animation_clips":animation_census.clips, "animation_only_resident_mib":null}

func _animations(scene: Node) -> Dictionary:
	# Shared clips are counted once per scene/profile. Godot does not publish
	# animation-only resident bytes; PSS and graphics memory are measured separately.
	var visited := {}
	var keys := 0
	for player: AnimationPlayer in scene.find_children("*", "AnimationPlayer", true, false):
		for clip in player.get_animation_list():
			var animation := player.get_animation(clip)
			var id := animation.get_instance_id()
			if visited.has(id):
				continue
			visited[id] = true
			for track in animation.get_track_count():
				keys += animation.track_get_key_count(track)
	return {"clips":visited.size(),"keys_total":keys}

func _flush() -> void:
	if not frames.is_empty():
		_write({"event":"frames","quality":PROFILES[phase],"rows":frames})
		frames.clear()
	last_flush = Time.get_ticks_usec()

func _finish() -> void:
	_write({"event":"done","steps":total_steps,"mode":mode})
	print("IMPERATHEN_GRAPHICS_PROBE_DONE ",mode)
	set_process(false)

func _fail(reason: String) -> void:
	_write({"event":"error","reason":reason})
	push_error(reason)
	set_process(false)
