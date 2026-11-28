extends SceneTree
## Exercises the authored I-00/VID-A handoff and breakfast acting in production Main.

const Entry := preload("res://main.tscn")
const I01 := preload("res://scripts/story/i01_three_cups.gd")
const I01Film := preload("res://scripts/story/i01_film.gd")
const BreakfastActingScript := preload("res://scripts/world/village/breakfast_acting.gd")
const DialoguePlayerScript := preload("res://scripts/audio/dialogue_player.gd")
const SocialFocusScript := preload("res://scripts/visuals/social_focus.gd")

var game: Node
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Breakfast acting requires isolated settings and saves.")
		quit(2)
		return
	call_deferred("_run")


func check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)
	return value


func frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _data() -> Dictionary:
	var model: Object = game.get("model") as Object
	return model.get("data") as Dictionary


func _beat() -> Dictionary:
	var sequence: Dictionary = game.get("opening_sequence")
	var beats: Array = sequence.get("beats", [])
	var index: int = int(game.get("opening_index"))
	return beats[index] if index >= 0 and index < beats.size() else {}


func _at_seat(world: Node3D, actor: Node3D, seat: Vector2) -> bool:
	var expected := world.to_global(Vector3(seat.x, actor.global_position.y, seat.y))
	var actual := actor.global_position
	return Vector2(actual.x, actual.z).distance_to(Vector2(expected.x, expected.z)) < 0.35


func _angle_between(skeleton: Skeleton3D, bone_name: String, first: Quaternion, second: Quaternion) -> float:
	var bone := skeleton.find_bone(bone_name)
	return first.angle_to(second) if bone >= 0 else 0.0


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	game = Entry.instantiate() as Node
	root.add_child(game)
	await frames(4)
	game.set_process(false)
	game.set_physics_process(false)
	var ui := game.get("ui") as Node
	ui.set("_touch_enabled", true)
	ui.call("_finish_intro")
	game.call("_start_new_game")
	await frames(4)
	check(str(game.get("screen")) == "opening", "New game enters the opening sequence")
	var sequence: Dictionary = game.get("opening_sequence")
	check(str(sequence.get("id", "")) == "i00_aquileia", "The production route begins with I-00")
	game.call("_opening_skip")
	game.call("_opening_next")
	await frames(6)
	sequence = game.get("opening_sequence")
	check(str(sequence.get("id", "")) == I01Film.VID_A, "I-00 hands directly into VID-A")
	var choice_open: bool = false
	for _step: int in 2400:
		if str(game.get("screen")) != "opening":
			break
		var current := _beat()
		if bool(game.call("_film_choice_open", current)):
			choice_open = true
			break
		game.call("_opening_process", 0.1)
	check(choice_open, "VID-A reaches its actual help-or-yard choice")
	var overlay := game.get("opening_overlay") as Node
	var help_button := overlay.find_child("OpeningChoice_i01_help", true, false) as Button
	check(is_instance_valid(help_button) and help_button.is_visible_in_tree(), "The production help choice is visible")
	if is_instance_valid(help_button):
		help_button.pressed.emit()
		await frames(4)
		check(str(_data().get("village", {}).get("childhood", {}).get("screenplay", {}).get("i01_path", "")) == "help", "The real choice commits the help route")
	var world := game.get("world") as Node3D
	var life := world.get("village_life_world") as Node3D
	var acting := life.get("_breakfast_acting") as BreakfastActingScript
	var cinematic_voice := game.get("opening_voice") as DialoguePlayerScript
	check(str(game.get("screen")) == "opening" and cinematic_voice.is_active() and bool(cinematic_voice.current.get("voiced", false)), "The production film is voicing Julia after the real choice")
	acting.advance(world, life, 3.1, _data())
	check(acting.focus_id().is_empty(), "A voiced cinematic cannot start ambient breakfast acting")
	for _step: int in 2400:
		if str(game.get("screen")) != "opening":
			break
		var current := _beat()
		if bool(current.get("final", false)):
			break
		game.call("_opening_process", 0.1)
	overlay = game.get("opening_overlay") as Node
	overlay.call("_request_advance")
	await frames(8)
	check(str(game.get("screen")) == "playing", "VID-A returns control to the ordinary world")
	check(bool(world.get("_active")) and bool(life.get("active")), "The real world and resident update loop are active")
	var presentation := I01.presentation(_data())
	check(str(presentation.get("status", "")) == "pending" and int(_data().get("village", {}).get("childhood", {}).get("completed", []).size()) == 0, "Breakfast remains the current story state")
	var actors: Dictionary = life.get("actors")
	var julia := actors.get("julia") as Node3D
	var silvanus := actors.get("silvanus") as Node3D
	if not check(is_instance_valid(julia) and is_instance_valid(silvanus), "The actual family residents are present"):
		await _finish()
		return
	var julia_start := julia.global_position
	var silvanus_start := silvanus.global_position
	check(_at_seat(world, julia, I01.POINTS.julia_table), "Julia remains at her authored breakfast seat")
	check(_at_seat(world, silvanus, I01.POINTS.silvanus_table), "Silvanus remains at his authored breakfast seat")
	var julia_figure := julia.get_node_or_null("Figure") as Node3D
	var silvanus_figure := silvanus.get_node_or_null("Figure") as Node3D
	var julia_focus := julia_figure.get("_social_focus") as SocialFocusScript
	var listener_focus := silvanus_figure.get("_social_focus") as SocialFocusScript
	await frames(10)
	check(acting.focus_id() == "julia", "Julia takes the first silent gaze turn")
	check(str(julia_figure.get("clip")) == "idle" and not bool(julia_figure.get("_conversation_focused")), "Ambient acting leaves Julia's mouth and conversation focus idle")
	check(listener_focus.speaker == julia_figure, "Silvanus watches Julia while listening")
	var skeleton := julia_figure.find_child("Skeleton3D", true, false) as Skeleton3D
	var head_index := skeleton.find_bone("Head") if is_instance_valid(skeleton) else -1
	var head_before: Quaternion = skeleton.get_bone_pose_rotation(head_index) if head_index >= 0 else Quaternion.IDENTITY
	await frames(36)
	var head_after: Quaternion = skeleton.get_bone_pose_rotation(head_index) if head_index >= 0 else Quaternion.IDENTITY
	check(head_index >= 0 and _angle_between(skeleton, "Head", head_before, head_after) > 0.01, "The silent gaze animates Julia's head without a speaking pose")
	check(julia_focus.target() == silvanus_figure and listener_focus.target() == julia_figure, "Both residents resolve the real gaze targets")
	await frames(180)
	check(acting.focus_id() == "silvanus", "The silent gaze turn passes to Silvanus")
	check(str(silvanus_figure.get("clip")) == "idle" and not bool(silvanus_figure.get("_conversation_focused")), "Silvanus stays silent during the gaze turn")
	check(julia.global_position.distance_to(julia_start) < 0.15 and silvanus.global_position.distance_to(silvanus_start) < 0.15, "Neither resident is teleported during the acting turns")
	life.call("focus", "julia", (world.get_node("Player") as Node3D).global_position)
	await frames(3)
	check(acting.focus_id().is_empty() and str(life.get("focused")) == "julia" and bool(julia_figure.get("_conversation_focused")), "Player focus interrupts ambient gaze and retains its own interaction")
	life.call("clear_focus")
	await frames(8)
	silvanus_figure.call("cue", "hit")
	await frames(2)
	check(str(silvanus_figure.get("clip")) == "hit" and acting.focus_id().is_empty(), "A reaction interrupts the silent gaze instead of being overwritten")
	silvanus_figure.call("cancel_action")
	await frames(8)
	var camera := world.get_node_or_null("WorldCamera") as Camera3D
	check(is_instance_valid(camera), "The production world camera is available for LOD verification")
	if is_instance_valid(camera):
		var original_camera := camera.global_transform
		var world_physics := world.is_physics_processing()
		world.set_physics_process(false)
		var middle := (julia.global_position + silvanus.global_position) * 0.5
		camera.global_position = middle + Vector3(120.0, 40.0, 120.0)
		julia_figure.call("refresh_lod", camera)
		silvanus_figure.call("refresh_lod", camera)
		await frames(4)
		check(int(julia_figure.get("detail")) >= 2 and int(silvanus_figure.get("detail")) >= 2, "Both breakfast actors switch to distant LOD")
		check(acting.focus_id().is_empty(), "Distant LOD releases the close-range gaze cue")
		check(julia.global_position.distance_to(julia_start) < 0.15 and silvanus.global_position.distance_to(silvanus_start) < 0.15, "LOD changes leave both resident positions untouched")
		camera.global_transform = original_camera
		julia_figure.call("refresh_lod", camera)
		silvanus_figure.call("refresh_lod", camera)
		world.set_physics_process(world_physics)
		await frames(8)
		check(int(julia_figure.get("detail")) <= 1 and int(silvanus_figure.get("detail")) <= 1, "Close-range LOD restores the residents after returning")
	await _finish()


func _finish() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await frames(2)
	print(("OPERATION_PRIMA_BREAKFAST_ACTING_PASS" if failures.is_empty() else "OPERATION_PRIMA_BREAKFAST_ACTING_FAILED") + " checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
