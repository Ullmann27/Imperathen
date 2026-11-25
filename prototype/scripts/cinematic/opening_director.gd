extends Node3D
## Five authored shots in the production village. This camera owns no game state.
## The original camera, labels, transforms and selected quality survive skip/finish.

signal shot_started(shot_id: String)
signal shot_finished(shot_id: String)

const HistoricalStage = preload("res://scripts/cinematic/i00_stage.gd")
const SHOT_IDS := ["aquileia_detail", "legions_rain", "caesar_orders", "labienus_orders", "legions_depart", "valley", "market", "well", "plot", "player", "mission_dialogue", "mission_reaction"]
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
var mission_actor_id := ""
var _mission_rotations: Array[Dictionary] = []
var _sun: DirectionalLight3D
var _environment: Environment
var _lighting: Dictionary = {}
var _i00_stage: Node3D


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
	if is_instance_valid(_i00_stage):
		_i00_stage.visible = false
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


func _ensure_i00_stage() -> Node3D:
	if not is_instance_valid(_i00_stage):
		_i00_stage = HistoricalStage.new()
		_i00_stage.name = "I00AquileiaStage"
		add_child(_i00_stage)
		_i00_stage.call("ensure_built")
	_i00_stage.visible = true
	return _i00_stage


func _anchor(key: String) -> Vector3:
	if key.begins_with("i00_"):
		var historical_anchor: Variant = _ensure_i00_stage().call("anchor", key)
		return historical_anchor if historical_anchor is Vector3 else Vector3.ZERO
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
		"aquileia_detail":
			var anchor := _anchor("i00_standard")
			start = anchor + Vector3(0.85, 1.35, 1.55)
			end = anchor + Vector3(0.48, 1.15, 1.0)
			target_start = anchor + Vector3(0.0, 2.0, 0.0)
			target_end = anchor + Vector3(0.0, 1.75, -0.1)
			fov_start = 42.0
			fov_end = 38.0
		"legions_rain":
			var anchor := _anchor("i00_legions")
			start = anchor + Vector3(17.0, 8.4, 18.0)
			end = anchor + Vector3(12.0, 6.2, 13.5)
			target_start = anchor + Vector3(0.0, 1.2, -5.5)
			target_end = anchor + Vector3(0.0, 1.0, -8.0)
			fov_start = 57.0
			fov_end = 51.0
		"caesar_orders":
			var anchor := _anchor("i00_caesar")
			start = anchor + Vector3(3.2, 1.95, 3.1)
			end = anchor + Vector3(2.45, 1.72, 2.55)
			target_start = anchor + Vector3(0.0, 1.35, 0.0)
			target_end = anchor + Vector3(0.0, 1.42, 0.0)
			fov_start = 48.0
			fov_end = 43.0
		"labienus_orders":
			var anchor := _anchor("i00_labienus")
			start = anchor + Vector3(-3.0, 1.9, 3.0)
			end = anchor + Vector3(-2.35, 1.68, 2.45)
			target_start = anchor + Vector3(0.0, 1.35, 0.0)
			target_end = anchor + Vector3(0.0, 1.40, 0.0)
			fov_start = 48.0
			fov_end = 44.0
		"legions_depart":
			var anchor := _anchor("i00_road")
			start = anchor + Vector3(14.0, 7.0, 18.0)
			end = anchor + Vector3(9.0, 5.2, 12.0)
			target_start = anchor + Vector3(0.0, 1.0, 8.0)
			target_end = anchor + Vector3(0.0, 1.0, 3.0)
			fov_start = 55.0
			fov_end = 50.0
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
		"mission_dialogue", "mission_reaction":
			var focus_id := mission_actor_id if shot_id == "mission_dialogue" else "player"
			var figure := _mission_figure(focus_id)
			var partner := _mission_figure("player" if shot_id == "mission_dialogue" else mission_actor_id)
			if not is_instance_valid(figure):
				figure = _mission_figure("player")
			var anchor := figure.global_position if is_instance_valid(figure) else _anchor("player")
			var forward := -figure.global_basis.z if is_instance_valid(figure) else Vector3.FORWARD
			forward.y = 0.0
			if is_instance_valid(partner) and partner != figure:
				var between := partner.global_position-anchor
				between.y = 0.0
				if between.length() > 0.2 and between.length() < 5.5:
					forward = between.normalized()
			if forward.length_squared() < 0.001:
				forward = Vector3.FORWARD
			forward = forward.normalized()
			var lateral := Vector3.UP.cross(forward).normalized()
			var face := anchor + Vector3.UP * 0.39
			start = face + forward * 2.35 + lateral * 0.9 + Vector3.UP * 0.16
			end = face + forward * 1.80 + lateral * 0.52 + Vector3.UP * 0.10
			target_start = face
			target_end = face + Vector3.UP * 0.02
			fov_start = 43.0
			fov_end = 38.0
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
	if shot_id in ["mission_dialogue","mission_reaction"]:
		# Avoid placing a cutscene camera beyond a wall; only presentation moves.
		var desired := camera.global_position
		var query := PhysicsRayQueryParameters3D.create(target,desired,1)
		var collision := get_world_3d().direct_space_state.intersect_ray(query)
		if not collision.is_empty():
			var hit: Vector3 = collision.position
			var direction := (desired-target).normalized()
			var shortened := hit-direction*0.16
			if shortened.distance_to(target)>0.26:
				camera.global_position = shortened
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


func _mission_figure(actor_id: String) -> Node3D:
	if not actor_id.is_empty() and is_instance_valid(_world) and _world.has_method("get_cinematic_figure"):
		return _world.call("get_cinematic_figure",actor_id) as Node3D
	return null


func _face_mission_pair() -> void:
	var npc := _mission_figure(mission_actor_id)
	var player := _mission_figure("player")
	if not is_instance_valid(npc) or not is_instance_valid(player) or npc == player:
		return
	var direction := npc.global_position-player.global_position
	direction.y=0.0
	if direction.length()<0.25 or direction.length()>5.5:
		return
	for pair: Array in [[player,direction],[npc,-direction]]:
		var figure: Node3D = pair[0]
		var look: Vector3 = pair[1]
		_mission_rotations.append({"node":figure,"rotation":figure.global_rotation})
		var angle := figure.global_rotation
		angle.y=atan2(-look.x,-look.z)
		figure.global_rotation=angle


func _change_speaker(next_shot: String) -> void:
	if next_shot == shot_id and (is_instance_valid(_speaker) or next_shot in ["mission_dialogue","mission_reaction"]):
		return
	_release_speaker()
	if next_shot in ["caesar_orders", "labienus_orders"]:
		var historical_id := "caesar" if next_shot == "caesar_orders" else "labienus"
		var figure := _ensure_i00_stage().call("speaker", historical_id) as Node3D
		if figure and figure.has_method("sample_pose") and figure.has_method("reset_motion"):
			_speaker = figure
	elif next_shot in ["mission_dialogue","mission_reaction"]:
		_face_mission_pair()
		if next_shot == "mission_dialogue":
			var figure := _mission_figure(mission_actor_id)
			if is_instance_valid(figure) and figure.has_method("sample_pose") and figure.has_method("reset_motion"):
				_speaker = figure
	elif next_shot == "well":
		var figure := _world.get_node_or_null("Marcus/Figure") as Node3D
		if figure and figure.has_method("sample_pose") and figure.has_method("reset_motion"):
			_speaker = figure


func _release_speaker() -> void:
	if is_instance_valid(_speaker):
		_speaker.reset_motion()
	_speaker = null
	for entry: Dictionary in _mission_rotations:
		if is_instance_valid(entry.node):
			entry.node.global_rotation = entry.rotation
	_mission_rotations.clear()


func _apply_grade(amount: float) -> void:
	# Reuse the existing sun and ambient fill. No extra lights, shadows,
	# postprocessing requirement or quality-profile override is introduced.
	var weight := clampf(amount, 0.0, 1.0)
	var historical := shot_id in ["aquileia_detail","legions_rain","caesar_orders","labienus_orders","legions_depart"]
	if is_instance_valid(_sun) and _lighting.has("sun_color"):
		var grade := Color(0.70, 0.76, 0.83) if historical else Color(1.0, 0.89, 0.75)
		var strength := 0.42 if historical else 0.26
		_sun.light_color = (_lighting.sun_color as Color).lerp(grade, strength * weight)
	if _environment and _lighting.has("ambient_energy"):
		_environment.ambient_light_energy = float(_lighting.ambient_energy) * lerpf(1.0, 0.72 if historical else 0.90, weight)
