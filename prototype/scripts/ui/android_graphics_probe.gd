extends Node
## Runs only when a debug QA installation has an explicit app-private request.
## The driver operates the same village, settings, HUD and battle model as a player.

const PROFILES := ["low", "balanced", "high", "very_high"]
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

func _ready() -> void:
	mode = FileAccess.get_file_as_string("user://graphics-probe.txt").strip_edges()
	if mode not in ["soak", "renderer", "quick"]:
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
		if game.screen != "playing":
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

func _counters(scene: Node) -> Dictionary:
	var viewport := get_viewport()
	var lights := 0
	var shadows := 0
	for light in scene.find_children("*","Light3D",true,false):
		if light.is_visible_in_tree():
			lights += 1
			if light.shadow_enabled:
				shadows += 1
	var texture := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var buffers := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
	return {"draw_calls":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"visible_primitives":viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"texture_mib":texture / 1048576.0 if texture > 0 else null,"mesh_buffer_mib":buffers / 1048576.0 if buffers > 0 else null,
		"animated_valley_actors":scene.actors.size() if stage == "battle" else null,
		"visible_lights":lights,"shadow_casting_lights":shadows}

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
