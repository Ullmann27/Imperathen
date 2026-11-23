extends Node3D
## Five authored shots in the production village. This camera owns no game state.
## The original camera, labels, transforms and selected quality survive skip/finish.

signal shot_started(shot_id: String)
signal shot_finished(shot_id: String)

const SHOT_IDS := ["valley", "market", "well", "plot", "player"]
const DEFAULT_ANCHORS := {
	"road": Vector3(0, 0, 18),
	"market": Vector3(-14, 0, 4),
	"companion": Vector3(-3, 0, 4),
	"plot": Vector3(14.5, 0, 4.5),
	"player": Vector3(0, 1, 8),
	"training": Vector3(0, 0, -7),
}

var camera: Camera3D
var active := false
var paused := false
var reduced_motion := false
var shot_id := ""
var elapsed := 0.0
var duration := 1.0
var _world: Node3D
var _game_camera: Camera3D
var _labels: Array[Dictionary] = []
var _original_camera_current := false
var _completed := false
var _speaker: Node3D
var _sun: DirectionalLight3D
var _environment: Environment
var _lighting: Dictionary = {}


func setup(world: Node3D) -> bool:
	finish()
	_world = world
	if not is_instance_valid(world):
		_game_camera = null
		return false
	_game_camera = world.get_node_or_null("WorldCamera") as Camera3D
	if _game_camera == null:
		return false
	if camera == null:
		camera = Camera3D.new()
		camera.name = "OpeningCamera"
		camera.near = 0.12
		camera.far = 300.0
		camera.current = false
		add_child(camera)
	set_process(false)
	return true


func play(next_shot: String, seconds: float, reduce_motion := false) -> bool:
	if next_shot not in SHOT_IDS or not is_finite(seconds) or not is_instance_valid(_world) or not is_instance_valid(_game_camera):
		return false
	_begin()
	_change_speaker(next_shot)
	shot_id = next_shot
	duration = maxf(0.1, seconds)
	elapsed = 0.0
	reduced_motion = reduce_motion
	paused = false
	_completed = false
	_apply_sample(0.0)
	set_process(true)
	shot_started.emit(shot_id)
	return true


func set_paused(value: bool) -> void:
	paused = value


func sample(next_shot: String, normalized_time: float) -> Dictionary:
	# Deterministic sampling uses the same shot code as playback, for render review.
	if next_shot not in SHOT_IDS or not is_finite(normalized_time) or not is_instance_valid(_game_camera):
		return {}
	_begin()
	_change_speaker(next_shot)
	shot_id = next_shot
	elapsed = clampf(normalized_time, 0.0, 1.0) * duration
	_apply_sample(clampf(normalized_time, 0.0, 1.0))
	return snapshot()


func snapshot() -> Dictionary:
	if camera == null:
		return {}
	return {"shot_id": shot_id, "time": elapsed, "duration": duration,
		"position": camera.global_position, "transform": camera.global_transform,
		"fov": camera.fov, "active": active, "paused": paused,
		"reduced_motion": reduced_motion}


func finish() -> void:
	set_process(false)
	if not active:
		return
	active = false
	_release_speaker()
	_apply_grade(0.0)
	_lighting.clear()
	paused = false
	_completed = false
	for item: Dictionary in _labels:
		if is_instance_valid(item.node):
			item.node.visible = item.visible
	_labels.clear()
	if is_instance_valid(camera):
		camera.current = false
	if is_instance_valid(_game_camera) and _original_camera_current:
		_game_camera.make_current()


func _exit_tree() -> void:
	finish()


func _begin() -> void:
	if active:
		return
	active = true
	_original_camera_current = _game_camera.current
	_sun = _world.get_node_or_null("AfternoonSun") as DirectionalLight3D
	var environments := _world.find_children("*", "WorldEnvironment", true, false)
	_environment = (environments[0] as WorldEnvironment).environment if not environments.is_empty() else null
	if _sun:
		_lighting["sun_color"] = _sun.light_color
	if _environment:
		_lighting["ambient_energy"] = _environment.ambient_light_energy
	_labels.clear()
	for node: Node in _world.find_children("*", "Label3D", true, false):
		_labels.append({"node": node, "visible": node.visible})
		node.hide()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.make_current()


func _process(delta: float) -> void:
	if not active or paused or _completed:
		return
	elapsed = minf(duration, elapsed + maxf(0.0, delta))
	_apply_sample(elapsed / duration)
	if elapsed >= duration:
		_completed = true
		shot_finished.emit(shot_id)


func _anchor(key: String) -> Vector3:
	if is_instance_valid(_world) and _world.has_method("get_cinematic_anchor"):
		var value: Variant = _world.call("get_cinematic_anchor", key)
		if value is Vector3 and (value as Vector3).is_finite():
			return value
	if key == "player":
		var actor := _world.get_node_or_null("Player") as Node3D
		if actor:
			return actor.global_position
	if key == "companion":
		var actor := _world.get_node_or_null("Marcus") as Node3D
		if actor:
			return actor.global_position - Vector3.UP * 0.9
	return _world.to_global(DEFAULT_ANCHORS[key])


func _apply_sample(normalized_time: float) -> void:
	var t := clampf(normalized_time, 0.0, 1.0)
	# A calm, fixed composition replaces all camera travel in reduced-motion mode.
	if reduced_motion:
		t = 1.0 if shot_id == "player" else 0.5
	var eased := t * t * (3.0 - 2.0 * t)
	var start: Vector3
	var end: Vector3
	var target_start: Vector3
	var target_end: Vector3
	var fov_start := 49.0
	var fov_end := 46.0
	match shot_id:
		"valley":
			var anchor := _anchor("road")
			start = anchor + Vector3(12.5, 10.2, 17.5)
			end = anchor + Vector3(8.0, 7.1, 10.5)
			target_start = anchor + Vector3(-1.5, 1.1, -22.0)
			target_end = anchor + Vector3(-2.0, 1.3, -17.0)
			fov_start = 56.0
			fov_end = 52.0
		"market":
			# Livia speaks from outside the frame until her authored resident asset
			# exists in the integrated world. This shot does not substitute a man.
			var anchor := _anchor("market")
			start = anchor + Vector3(6.0, 2.15, 2.8)
			end = anchor + Vector3(4.7, 1.85, 2.3)
			target_start = anchor + Vector3(-1.0, 1.20, -1.6)
			target_end = anchor + Vector3(-0.7, 1.15, -1.1)
			fov_start = 53.0
			fov_end = 49.0
		"well":
			var anchor := _anchor("companion")
			start = anchor + Vector3(3.4, 1.85, -3.4)
			end = anchor + Vector3(2.5, 1.55, -2.9)
			target_start = anchor + Vector3(-0.5, 0.86, 0.0)
			target_end = anchor + Vector3(-0.25, 0.90, 0.0)
			fov_start = 49.0
			fov_end = 45.0
		"plot":
			var anchor := _anchor("plot")
			start = anchor + Vector3(-11.0, 2.8, 8.0)
			end = anchor + Vector3(-8.5, 2.2, 6.4)
			target_start = anchor + Vector3(0.0, 0.15, 0.0)
			target_end = anchor + Vector3(0.8, 0.35, -1.4)
			fov_start = 54.0
			fov_end = 52.0
		"player":
			var ground := _anchor("player") - Vector3.UP * 0.9
			start = ground + Vector3(-1.5, 1.55, -2.4)
			end = _game_camera.global_position
			target_start = ground + Vector3(0.0, 1.10, 0.0)
			target_end = _game_camera.global_position - _game_camera.global_basis.z * 4.0
			fov_start = 40.0
			fov_end = _game_camera.fov
		_:
			return
	camera.global_position = start.lerp(end, eased)
	if shot_id == "player":
		var ground := _anchor("player") - Vector3.UP * 0.9
		# The return passes beside the player; a straight interpolation would
		# cross the actor while moving from their face to the shoulder camera.
		var handle_a := ground + Vector3(-3.0, 1.7, -1.6)
		var handle_b := ground + Vector3(-3.0, 1.9, 3.3)
		camera.global_position = start.bezier_interpolate(handle_a, handle_b, end, eased)
	var target := target_start.lerp(target_end, eased)
	if camera.global_position.distance_squared_to(target) > 0.001:
		camera.look_at(target, Vector3.UP)
	camera.fov = lerpf(fov_start, fov_end, eased)
	_apply_grade(1.0 - eased if shot_id == "player" else 1.0)
	if is_instance_valid(_speaker):
		_speaker.sample_pose("talk", fposmod(elapsed / 1.7, 1.0))
	if shot_id == "player" and t >= 1.0:
		# Exact handoff, including any aspect-dependent camera basis. No jump.
		camera.global_transform = _game_camera.global_transform
		camera.fov = _game_camera.fov


func _change_speaker(next_shot: String) -> void:
	if next_shot == shot_id and is_instance_valid(_speaker):
		return
	_release_speaker()
	if next_shot == "well":
		var figure := _world.get_node_or_null("Marcus/Figure") as Node3D
		if figure and figure.has_method("sample_pose") and figure.has_method("reset_motion"):
			_speaker = figure


func _release_speaker() -> void:
	if is_instance_valid(_speaker):
		_speaker.reset_motion()
	_speaker = null


func _apply_grade(amount: float) -> void:
	# Reuse the existing sun and ambient fill. No extra lights, shadows,
	# postprocessing requirement or quality-profile override is introduced.
	var weight := clampf(amount, 0.0, 1.0)
	if is_instance_valid(_sun) and _lighting.has("sun_color"):
		_sun.light_color = (_lighting.sun_color as Color).lerp(Color(1.0, 0.89, 0.75), 0.26 * weight)
	if _environment and _lighting.has("ambient_energy"):
		_environment.ambient_light_energy = float(_lighting.ambient_energy) * lerpf(1.0, 0.90, weight)
