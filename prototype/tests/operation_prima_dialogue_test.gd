extends SceneTree

const Person := preload("res://scripts/visuals/village_person.gd")
const Speech := preload("res://scripts/audio/face_driver.gd")
const Lines := preload("res://scripts/audio/voice_lines.gd")
const I01 := preload("res://scripts/story/i01_three_cups.gd")
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("PRIMA_DIALOGUE_FAIL: ", message)

func _run() -> void:
	var actor := Person.new()
	root.add_child(actor)
	actor.configure("player", "italia", 12)
	var skin := actor.body.find_child("HeroBody", true, false) as MeshInstance3D
	var face := Speech.new()
	root.add_child(face)
	face.blink_enabled = false # The production cinematic actor owns the eyelids.
	face.bind(actor)
	var line: Dictionary = I01.line("I01_A_TABLE")
	var entry: Dictionary = Lines.find(str(line.text), str(line.speaker_id))
	var track: Dictionary = Lines.viseme_track(entry)
	var left: int = skin.find_blend_shape_by_name("Blink_L") if skin else -1
	var right: int = skin.find_blend_shape_by_name("Blink_R") if skin else -1
	_check(left >= 0 and right >= 0 and not track.get("segments", []).is_empty(), "imported blink targets and VID-A speech track")
	if left >= 0 and right >= 0:
		skin.set_blend_shape_value(left, 0.84)
		skin.set_blend_shape_value(right, 0.72)
		face.set_track(track, func() -> float: return 0.5)
		face._process(1.0 / 60.0)
		_check(is_equal_approx(skin.get_blend_shape_value(left), 0.84), "speech did not force the actor's left eyelid open")
		face.clear()
		_check(is_equal_approx(skin.get_blend_shape_value(right), 0.72), "cut or interruption did not cancel the actor's blink")
	face.free()
	actor.free()
	print("PRIMA_DIALOGUE_RESULT failures=", failures)
	quit(0 if failures == 0 else 1)
