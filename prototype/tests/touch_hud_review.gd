extends SceneTree
## Actual main-scene HUD capture plus native three-contact camera integration check.

const EntryScene = preload("res://main.tscn")
const Diagnostics = preload("res://scripts/ui/android_village_diagnostics.gd")
var game
var output := ""
var captures: Array[Dictionary] = []
var checks: Array[Dictionary] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless" or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("An isolated real viewport and output folder are required.")
		quit(2)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	game = EntryScene.instantiate()
	root.add_child(game)
	await _frames(3)
	game.ui.set("_touch_enabled", true)
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game", {})
	game._opening_skip()
	game._opening_next()
	await _frames(6)
	_check(game.screen == "playing" and int(game.model.data.player.age) == 12, "The actual new childhood start is playable")
	_check(game.world.get("_touch_camera_managed"), "Main routes touch-camera ownership to the actual world")
	var observer := Diagnostics.new()
	observer.session = game
	game.add_child(observer)
	observer.set_process(false)
	var before_observe := var_to_bytes(game.model.data)
	var observed: Dictionary = observer.snapshot()
	_check(var_to_bytes(game.model.data) == before_observe, "Android geometry observer does not mutate authoritative state")
	_check(observed.action_mode == "unarmed" and observed.action_runtime.mode == "person" and not observed.action_runtime.running, "Android observer identifies the actual new action mode")
	var controls_present := true
	for key: String in ["move_pad","interact","village","pace","techniques","attack","pause"]:
		controls_present = controls_present and observed.controls.has(key)
	_check(controls_present, "Android observer exposes current HUD controls including the renamed Dorf button")
	_check(observed.controls.move_pad.axis_points.has("right") and observed.controls.move_pad.visible, "Android movement coordinates come from the actual visible pad")
	await _capture("phone-1280x720")
	var old_yaw: float = game.world.get("_camera_yaw")
	var pad: Control = game.ui.get("_touch_pad")
	var pad_point := pad.get_global_rect().get_center() + Vector2(20,-30)
	var camera_point := Vector2(860,280)
	var attack_point := _button("attack").get_global_rect().get_center()
	_touch(40,true,pad_point)
	_touch(41,true,camera_point)
	_touch(42,true,attack_point)
	var held: Dictionary = observer.snapshot().action_runtime
	_check(held.movement_touch == 40 and held.camera_touches == 1 and held.action_touches == 1, "Android observer reports all three actual held native contacts")
	var drag := InputEventScreenDrag.new()
	drag.index = 41
	drag.position = camera_point + Vector2(20,10)
	drag.relative = Vector2(20,10)
	root.push_input(drag,true)
	_check(is_equal_approx(float(game.world.get("_camera_yaw")),wrapf(old_yaw-0.12,-PI,PI)), "One native camera drag changes actual yaw exactly once while move and attack are held")
	_check(not game.world.get("_touch_move").is_zero_approx(), "The actual world retains simultaneous movement")
	_check(game.world.get("_camera_contacts").is_empty(), "The world's old contact path cannot capture the same finger")
	_touch(42,false,attack_point)
	_touch(41,false,drag.position)
	_touch(40,false,pad_point)
	_check(game.world.get("_touch_move").is_zero_approx(), "Releasing movement forwards the neutral axis into the actual world")
	game.ui.action_requested.emit("pause", {})
	_check(game.screen == "paused" and game.ui.get("_view_state") == "pause", "Pause uses the actual main screen transition")
	var paused: Dictionary = observer.snapshot()
	_check(paused.action_runtime.movement_touch == -1 and paused.action_runtime.camera_touches == 0 and paused.action_runtime.action_touches == 0 and not paused.action_runtime.world_active, "Android observer confirms neutral captures in the actual pause screen")
	game.ui.action_requested.emit("resume", {})
	await _frames(4)
	_check(game.ui.get("_touch_look").contacts.is_empty() and game.world.get("_camera_contacts").is_empty(), "Resume has no old camera contact in either input owner")
	root.size = Vector2i(884,760)
	await _frames(6)
	await _capture("fold-884x760")
	_touch(43,true,_button("techniques").get_global_rect().get_center())
	_touch(43,false,_button("techniques").get_global_rect().get_center())
	await _frames(3)
	await _capture("fold-techniques-884x760")
	var listed: Dictionary = observer.snapshot()
	_check(listed.action_runtime.overlay == "techniques" and listed.controls.has("technique_jab_right") and not listed.controls.has("move_pad") and not listed.controls.has("pause"), "Android observer exposes selectable techniques without blocked controls behind the modal")
	var report := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"android_device_test":false,"source":"Actual main.tscn with a fresh childhood game and native multi-touch events","captures":captures,"checks":checks}
	var file := FileAccess.open(output.path_join("touch-hud-review.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	game.queue_free()
	await process_frame
	var failed := false
	for check in checks:
		if not check.ok:
			failed = true
	print("TOUCH_HUD_REVIEW_FAIL" if failed else "TOUCH_HUD_REVIEW_PASS")
	quit(1 if failed else 0)


func _button(action: String) -> Button:
	for button: Button in game.ui.get("_touch_actions"):
		if str(button.get_meta("touch_action","")) == action:
			return button
	return null


func _touch(index: int, pressed: bool, point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = point
	root.push_input(event,true)


func _frames(count: int) -> void:
	for index in count:
		await RenderingServer.frame_post_draw


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var saved := picture != null and not picture.is_empty() and picture.save_png(output.path_join(label+".png")) == OK
	_check(saved,"Actual rendered capture: "+label)
	captures.append({"file":label+".png","pixels":[picture.get_width(),picture.get_height()],"screen":game.screen,"ui_state":game.ui.get("_view_state"),"quality":game.world.get_quality_profile()})


func _check(ok: bool, message: String) -> void:
	checks.append({"ok":ok,"message":message})
	if not ok:
		printerr("FAIL: "+message)
