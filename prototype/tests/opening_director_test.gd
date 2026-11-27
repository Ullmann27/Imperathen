extends SceneTree
## Camera playback must remain presentation-only through skip, pause and teardown.

const Director = preload("res://scripts/cinematic/opening_director.gd")
class SpeakingFigure:
	extends Node3D
	var sampled := "idle"
	var reset_count := 0
	var age := 22
	var pinned := false
	func set_cinematic_detail(enabled: bool) -> void:
		pinned = enabled
	func sample_pose(action: String, _phase: float) -> void:
		sampled = action
	func reset_motion() -> void:
		sampled = "idle"
		reset_count += 1

class FilmWorld:
	extends Node3D
	var cast: Dictionary = {}
	func get_cinematic_figure(id: String) -> Node3D:
		return cast.get(id) as Node3D

var checks := 0
var errors: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		errors.append(message)
		printerr(message)


func _run() -> void:
	var stage := FilmWorld.new()
	root.add_child(stage)
	var gameplay := Camera3D.new()
	gameplay.name = "WorldCamera"
	stage.add_child(gameplay)
	gameplay.position = Vector3(2, 3, 11)
	gameplay.look_at(Vector3(0, 1, 3))
	gameplay.fov = 54.0
	gameplay.make_current()
	var actor := Node3D.new()
	actor.name = "Player"
	actor.position = Vector3(0, 1, 8)
	stage.add_child(actor)
	var companion := Node3D.new()
	companion.name = "Marcus"
	companion.position = Vector3(-3, 0.9, 4)
	stage.add_child(companion)
	var speaking := SpeakingFigure.new()
	speaking.name = "Figure"
	companion.add_child(speaking)
	stage.cast = {"julia": speaking}
	var label := Label3D.new()
	stage.add_child(label)
	var hidden := Label3D.new()
	hidden.visible = false
	stage.add_child(hidden)
	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.light_color = Color(1.0, 0.98, 0.93)
	stage.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	var original_light := sun.light_color
	var director := Director.new()
	stage.add_child(director)
	var actor_before := actor.transform
	var gameplay_before := gameplay.transform
	_check(director.setup(stage), "Setup finds the named production camera")
	_check(not director.play("unknown", 5.0), "Unknown shots cannot seize the camera")
	_check(gameplay.current and label.visible, "Rejected shot preserves the gameplay camera and labels")
	_check(not director.play("valley", NAN), "Invalid duration cannot create a non-finite camera")
	_check(director.sample("valley", NAN).is_empty(), "Invalid seek cannot create a non-finite camera")
	_check(director.play("valley", 7.0), "Valley shot starts")
	_check(director.camera.current and not gameplay.current, "The cinematic owns a separate current camera")
	_check(sun.light_color != original_light and environment.environment.ambient_light_energy < 0.6, "Existing light is subtly graded without adding a light")
	_check(not label.visible and not hidden.visible, "World labels stay out of the cinematic")
	var before: Transform3D = director.camera.global_transform
	director.set_paused(true)
	director._process(2.0)
	_check(director.camera.global_transform == before and is_zero_approx(director.elapsed), "Pause freezes camera travel and elapsed time")
	director.set_paused(false)
	director._process(3.5)
	_check(not director.camera.global_transform.is_equal_approx(before), "Unpaused playback travels through the real scene")
	var emitted: Array[String] = []
	director.shot_finished.connect(func(id: String): emitted.append(id))
	director._process(10.0)
	director._process(10.0)
	_check(emitted == ["valley"], "Shot completion emits exactly once")
	for id: String in Director.SHOT_IDS:
		_check(director.play(id, 4.0), "Authored shot starts: " + id)
		for t: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var state: Dictionary = director.sample(id, t)
			_check((state.position as Vector3).is_finite() and (state.position as Vector3).y > 0.4, "Sample remains finite and above ground: " + id + " " + str(t))
			_check(float(state.fov) >= 30.0 and float(state.fov) <= 65.0, "Authored lens stays in range")
	director.sample("player", 1.0)
	_check(director.camera.global_transform.is_equal_approx(gameplay.global_transform) and is_equal_approx(director.camera.fov, gameplay.fov), "Final pose exactly matches the gameplay camera")
	_check(actor.transform == actor_before and gameplay.transform == gameplay_before, "Neither player nor original camera is moved")
	# The generated camera grammar must preserve screen direction in a real
	# two-person layout and when either parent is the active speaker.
	stage.cast["player"] = actor
	stage.cast["silvanus"] = speaking
	for speaker_id: String in ["julia", "silvanus"]:
		director.mission_actor_id = speaker_id
		var axis := speaking.global_position - actor.global_position
		axis.y = 0.0
		var normal := Vector3.UP.cross(axis.normalized())
		var centre := actor.global_position.lerp(speaking.global_position, 0.5)
		var close: Array = director._duo_framing("duo_close")
		var reverse: Array = director._duo_framing("duo_react")
		var adult: Array = director._i01_framing("i01_close_speaker")
		var child: Array = director._i01_framing("i01_react_boy")
		for sample_index: int in [0, 1]:
			_check((Vector3(close[sample_index]) - centre).dot(normal) * (Vector3(reverse[sample_index]) - centre).dot(normal) > 0.0,
				"Dialogue reverse shot preserves the 180-degree axis: " + speaker_id)
			_check((Vector3(adult[sample_index]) - centre).dot(normal) * (Vector3(child[sample_index]) - centre).dot(normal) > 0.0,
				"Family reaction preserves the adult's side of the dialogue axis: " + speaker_id)
	stage.cast.erase("player")
	stage.cast.erase("silvanus")
	director.mission_actor_id = ""
	director.prepare_cinematic_cast("i01_close_speaker", "julia")
	_check(speaking.pinned, "Story actor uses close detail before voice binding")
	director.play("well", 10.0, true)
	_check(speaking.sampled == "talk" and speaking.age == 22, "The existing grown companion gestures without changing age or identity")
	before = director.camera.global_transform
	director._process(5.0)
	_check(director.camera.global_transform == before, "Reduced-motion framing remains still")
	director.finish()
	director.finish()
	_check(speaking.sampled == "idle" and speaking.reset_count > 0, "Leaving the shot releases the companion pose")
	_check(not speaking.pinned, "Film teardown releases the detail lock")
	_check(gameplay.current and label.visible and not hidden.visible, "Repeated finish restores the camera and original label visibility")
	_check(sun.light_color.is_equal_approx(original_light) and is_equal_approx(environment.environment.ambient_light_energy, 0.6), "Finish restores the original light and ambient energy")
	_check(not director.active and not director.is_processing(), "Finished director consumes no per-frame work")
	director.play("market", 11.0)
	director.free()
	_check(gameplay.current and label.visible and not hidden.visible, "Unexpected director teardown restores the world")
	stage.free()
	print("OPENING_DIRECTOR_TEST ", checks, " checks ", JSON.stringify(errors))
	quit(0 if errors.is_empty() else 1)
