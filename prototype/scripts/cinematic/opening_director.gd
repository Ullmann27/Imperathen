extends Node3D
## Five authored shots in the production village. This camera owns no game state.
## The original camera, labels, transforms and selected quality survive skip/finish.

signal shot_started(shot_id: String)
signal shot_finished(shot_id: String)

const HistoricalStage = preload("res://scripts/cinematic/i00_stage.gd")
const I01Props = preload("res://scripts/world/village/i01_props.gd")
const SHOT_IDS := ["aquileia_detail", "legions_rain", "caesar_orders", "labienus_orders", "legions_depart", "valley", "market", "well", "plot", "player", "mission_dialogue", "mission_reaction", "i01_table_detail", "i01_shelf_cups", "i01_bed", "i01_choice", "i01_table_wide", "i01_topic_choice", "i01_cups_insert", "i01_close_speaker", "i01_react_boy", "i01_two_shot", "i01_react_julia", "duo_wide", "duo_close", "duo_react", "duo_ots", "duo_hands", "prop_insert"]
## I-01 shots inside the real family home (HB S. 13): table, cups and hands,
## the shelf, the boy's bed, the breakfast table and the table-talk choice.
const I01_SHOTS := ["i01_table_detail", "i01_shelf_cups", "i01_bed", "i01_choice", "i01_table_wide", "i01_topic_choice", "i01_cups_insert", "i01_close_speaker", "i01_react_boy", "i01_two_shot", "i01_react_julia"]
## Shot sizes of the table talk (VID-B): insert (cups), close (speaker),
## reaction close (boy, Julia), medium two-shot, wide (i01_table_wide).
## Interior film light: daylight through the north window (shadowed key),
## the hearth side as warm second source and a weak camera fill. The rig is
## presentation only, lives under the director and fades out with the handoff.
const INTERIOR_RIG_RADIUS := 6.5
## Dialogue grammar for any two people in the open world, derived from the
## live figures: wide two-shot, close on the speaker, reaction close on the
## boy, over-the-shoulder, insert on the speaker's hands and an insert on a
## named prop anchor (focus_key).
const DUO_SHOTS := ["duo_wide", "duo_close", "duo_react", "duo_ots", "duo_hands", "prop_insert"]
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
var _speaker_actor := ""
var _mission_rotations: Array[Dictionary] = []
var _cinematic_cast: Array[Node3D] = []
var _sun: DirectionalLight3D
var _environment: Environment
var _lighting: Dictionary = {}
var _i00_stage: Node3D
var _rig: Node3D
var _forge_glow: OmniLight3D
## Anchor key of the prop framed by "prop_insert" (set by the film owner).
var focus_key := ""
## False during silent pause and reaction beats (set by the film owner).
var speaking := true
var _speaker_posed := false
var _interior_film := false


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
	_release_cinematic_cast()
	_interior_film = false
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
	if key.begins_with("i01_"):
		return _world.to_global(I01Props.anchor(key))
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
		"i01_table_detail", "i01_shelf_cups", "i01_bed", "i01_choice", "i01_table_wide", "i01_topic_choice", "i01_cups_insert", "i01_close_speaker", "i01_react_boy", "i01_two_shot", "i01_react_julia":
			var framing := _i01_framing(shot_id)
			start = framing[0]
			end = framing[1]
			target_start = framing[2]
			target_end = framing[3]
			fov_start = framing[4]
			fov_end = framing[5]
		"duo_wide", "duo_close", "duo_react", "duo_ots", "duo_hands", "prop_insert":
			var duo := _duo_framing(shot_id)
			start = duo[0]
			end = duo[1]
			target_start = duo[2]
			target_end = duo[3]
			fov_start = duo[4]
			fov_end = duo[5]
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
	if shot_id in ["mission_dialogue","mission_reaction"] or shot_id in I01_SHOTS or shot_id in DUO_SHOTS:
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
		if speaking:
			_speaker.sample_pose("talk", fposmod(elapsed / 1.7, 1.0))
			_speaker_posed = true
		elif _speaker_posed:
			# A silent pause or reaction: nobody mouths a line.
			_speaker.reset_motion()
			_speaker_posed = false
	if shot_id == "player" and t >= 1.0:
		# Exact handoff, including any aspect-dependent camera basis. No jump.
		camera.global_transform = _game_camera.global_transform
		camera.fov = _game_camera.fov


## Over-the-shoulder and table framings derived from the live figures, with
## the authored anchors as fallback. Returns start, end, targets and lenses.
func _i01_framing(id: String) -> Array:
	var table := _anchor("i01_table")
	match id:
		"i01_table_detail":
			# Over the bread toward Julia's hands and upper body at the far side.
			return [table + Vector3(0.80, 0.62, 1.05), table + Vector3(0.35, 0.55, 0.95),
				table + Vector3(0.0, 0.05, -0.15), table + Vector3(-0.05, 0.28, -0.85), 44.0, 38.0]
		"i01_shelf_cups":
			var shelf := _anchor("i01_shelf")
			return [shelf + Vector3(1.45, 0.25, -0.55), shelf + Vector3(1.0, 0.12, -0.30),
				shelf + Vector3(0.0, 0.05, 0.0), shelf + Vector3(0.0, 0.02, 0.02), 44.0, 36.0]
		"i01_table_wide":
			return [table + Vector3(2.85, 1.10, 2.55), table + Vector3(2.55, 0.95, 2.30),
				table + Vector3(0.0, -0.10, 0.0), table + Vector3(-0.15, -0.05, 0.0), 58.0, 54.0]
		"i01_cups_insert":
			# Insert: the crooked cup in front, Silvanus' cup behind it.
			return [table + Vector3(-0.62, 0.30, 0.86), table + Vector3(-0.50, 0.26, 0.74),
				table + Vector3(0.32, 0.07, 0.30), table + Vector3(0.30, 0.07, 0.34), 33.0, 30.5]
		"i01_close_speaker", "i01_react_julia":
			# Close on the speaking (or listening) adult from the boy's side.
			var subject_id := "julia" if id == "i01_react_julia" else (mission_actor_id if mission_actor_id in ["julia", "silvanus"] else "silvanus")
			var subject := _mission_figure(subject_id)
			var listener := _mission_figure("player")
			var face := (subject.global_position if is_instance_valid(subject) else _anchor("i01_" + subject_id) + Vector3.UP * 0.9) + Vector3.UP * 0.42
			var toward := (listener.global_position if is_instance_valid(listener) else _anchor("i01_player_table") + Vector3.UP * 0.9) - face
			toward.y = 0.0
			toward = toward.normalized() if toward.length() > 0.1 else Vector3.BACK
			var side := Vector3.UP.cross(toward).normalized() * (0.34 if subject_id == "silvanus" else -0.34)
			return [face + toward * 1.42 + side + Vector3.UP * 0.03, face + toward * 1.20 + side * 0.85 + Vector3.UP * 0.02,
				face, face + Vector3.UP * 0.015, 35.0 if id == "i01_close_speaker" else 33.0, 31.5 if id == "i01_close_speaker" else 31.0]
		"i01_react_boy":
			# Reaction close on the listening boy from the adult's side.
			var listening := _mission_figure("player")
			var adult := _mission_figure(mission_actor_id if mission_actor_id in ["julia", "silvanus"] else "silvanus")
			var boy_face := (listening.global_position if is_instance_valid(listening) else _anchor("i01_player_table") + Vector3.UP * 0.9) + Vector3.UP * 0.36
			var away := (adult.global_position if is_instance_valid(adult) else _anchor("i01_silvanus") + Vector3.UP * 0.9) - boy_face
			away.y = 0.0
			away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
			var off := Vector3.UP.cross(away).normalized() * -0.30
			return [boy_face + away * 1.10 + off + Vector3.UP * 0.06, boy_face + away * 1.00 + off * 0.9 + Vector3.UP * 0.05,
				boy_face, boy_face + Vector3.UP * 0.01, 36.0, 34.0]
		"i01_two_shot":
			# Medium two-shot of both parents past the boy's shoulder.
			var child := _mission_figure("player")
			var mother := _mission_figure("julia")
			var father := _mission_figure("silvanus")
			var from := child.global_position if is_instance_valid(child) else _anchor("i01_player_table") + Vector3.UP * 0.9
			var a := mother.global_position if is_instance_valid(mother) else _anchor("i01_julia") + Vector3.UP * 0.9
			var b := father.global_position if is_instance_valid(father) else _anchor("i01_silvanus") + Vector3.UP * 0.9
			var middle := (a + b) * 0.5 + Vector3.UP * 0.30
			var ahead := middle - from
			ahead.y = 0.0
			ahead = ahead.normalized() if ahead.length() > 0.1 else Vector3.FORWARD
			var beside := Vector3.UP.cross(ahead).normalized()
			return [from - ahead * 1.05 - beside * 0.55 + Vector3.UP * 0.52, from - ahead * 0.90 - beside * 0.50 + Vector3.UP * 0.50,
				middle, middle, 50.0, 47.0]
		"i01_bed", "i01_choice", "i01_topic_choice":
			var boy := _mission_figure("player")
			var origin := boy.global_position if is_instance_valid(boy) else _anchor("i01_bed") + Vector3.UP * 0.9
			var partner := _mission_figure("silvanus" if id == "i01_topic_choice" else "julia")
			var facing := partner.global_position if is_instance_valid(partner) else _anchor("i01_silvanus" if id == "i01_topic_choice" else "i01_julia") + Vector3.UP * 0.9
			var direction := facing - origin
			direction.y = 0.0
			direction = direction.normalized() if direction.length() > 0.1 else Vector3.FORWARD
			var lateral := Vector3.UP.cross(direction).normalized()
			var shoulder := origin + Vector3.UP * 0.32
			var near := 0.70 if id == "i01_choice" else 0.85
			var rise := 0.0 if id != "i01_bed" else -0.12
			return [shoulder - direction * (near + 0.15) + lateral * 0.42 + Vector3.UP * (0.10 + rise),
				shoulder - direction * near + lateral * 0.36 + Vector3.UP * 0.10,
				facing + Vector3.UP * 0.42, facing + Vector3.UP * 0.45, 46.0, 42.0]
	return [table, table + Vector3.UP, table, table, 45.0, 45.0]


## Framings for two people standing anywhere in the world. The speaker is
## mission_actor_id, the other person is the boy.
func _duo_framing(id: String) -> Array:
	var speaker := _mission_figure(mission_actor_id)
	var boy := _mission_figure("player")
	var boy_at := boy.global_position if is_instance_valid(boy) else _anchor("player")
	var speaker_at := speaker.global_position if is_instance_valid(speaker) and speaker != boy else boy_at + Vector3(0.0, 0.0, -1.6)
	var axis := speaker_at - boy_at
	axis.y = 0.0
	var gap := clampf(axis.length(), 0.8, 5.0)
	axis = axis.normalized() if axis.length() > 0.1 else Vector3.FORWARD
	var side := Vector3.UP.cross(axis).normalized()
	var speaker_face := speaker_at + Vector3.UP * 0.42
	var boy_face := boy_at + Vector3.UP * 0.36
	match id:
		"duo_wide":
			var middle := (speaker_at + boy_at) * 0.5 + Vector3.UP * 0.12
			var back := maxf(3.1, gap * 1.7)
			return [middle + side * back - axis * 0.5 + Vector3.UP * 0.50, middle + side * (back - 0.35) - axis * 0.4 + Vector3.UP * 0.46,
				middle, middle, 52.0, 49.0]
		"duo_close":
			return [speaker_face - axis * 1.40 + side * 0.36 + Vector3.UP * 0.03, speaker_face - axis * 1.20 + side * 0.30 + Vector3.UP * 0.02,
				speaker_face, speaker_face + Vector3.UP * 0.015, 35.0, 32.0]
		"duo_react":
			return [boy_face + axis * 1.12 - side * 0.30 + Vector3.UP * 0.06, boy_face + axis * 1.02 - side * 0.27 + Vector3.UP * 0.05,
				boy_face, boy_face + Vector3.UP * 0.01, 36.0, 34.0]
		"duo_ots":
			var shoulder := boy_at + Vector3.UP * 0.32
			return [shoulder - axis * 0.95 + side * 0.42 + Vector3.UP * 0.10, shoulder - axis * 0.80 + side * 0.36 + Vector3.UP * 0.10,
				speaker_face, speaker_face + Vector3.UP * 0.03, 46.0, 42.0]
		"duo_hands":
			var hands := speaker_at - axis * 0.22 - Vector3.UP * 0.10
			return [hands - axis * 0.80 + side * 0.34 + Vector3.UP * 0.22, hands - axis * 0.68 + side * 0.28 + Vector3.UP * 0.19,
				hands, hands, 36.0, 32.5]
		"prop_insert":
			var prop := _anchor(focus_key) if not focus_key.is_empty() else speaker_at
			var from := boy_at - prop
			from.y = 0.0
			from = from.normalized() if from.length() > 0.1 else Vector3.BACK
			var beside := Vector3.UP.cross(from).normalized()
			return [prop + from * 0.66 + beside * 0.24 + Vector3.UP * 0.30, prop + from * 0.54 + beside * 0.19 + Vector3.UP * 0.26,
				prop, prop, 35.0, 31.5]
	return [boy_at, boy_at + Vector3.UP, boy_at, boy_at, 45.0, 45.0]


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


## Keep the actual live rig stable throughout the film, including reaction
## cuts. Replacing a LOD after FaceDriver.bind() invalidates its mesh targets.
func prepare_cinematic_cast(next_shot: String, actor_id: String) -> void:
	var ids: Array[String] = []
	if next_shot in I01_SHOTS or (_interior_film and next_shot in ["mission_dialogue", "mission_reaction"]):
		ids = ["player", "julia", "silvanus"]
	elif next_shot in DUO_SHOTS or next_shot in ["mission_dialogue", "mission_reaction"]:
		ids = ["player", actor_id]
	for id: String in ids:
		var figure := _mission_figure(id)
		if is_instance_valid(figure) and figure.has_method("set_cinematic_detail") and not _cinematic_cast.has(figure):
			figure.set_cinematic_detail(true)
			_cinematic_cast.append(figure)


func _release_cinematic_cast() -> void:
	for figure: Node3D in _cinematic_cast:
		if is_instance_valid(figure):
			figure.set_cinematic_detail(false)
	_cinematic_cast.clear()


func _change_speaker(next_shot: String) -> void:
	prepare_cinematic_cast(next_shot, mission_actor_id)
	if next_shot == shot_id and _speaker_actor == mission_actor_id and (is_instance_valid(_speaker) or next_shot in ["mission_dialogue","mission_reaction"]):
		return
	_release_speaker()
	_speaker_actor = mission_actor_id
	if next_shot in ["caesar_orders", "labienus_orders"]:
		var historical_id := "caesar" if next_shot == "caesar_orders" else "labienus"
		var figure := _ensure_i00_stage().call("speaker", historical_id) as Node3D
		if figure and figure.has_method("sample_pose") and figure.has_method("reset_motion"):
			_speaker = figure
	elif next_shot in I01_SHOTS or next_shot in DUO_SHOTS:
		# The named speaker of an I-01 shot uses the existing talk pose and
		# turns toward the boy (restored when the film releases the figures).
		_face_mission_pair()
		var speaking := _mission_figure(mission_actor_id)
		if is_instance_valid(speaking) and speaking.has_method("sample_pose") and speaking.has_method("reset_motion"):
			_speaker = speaking
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
	# Exterior shots reuse the existing sun and ambient fill. Interior I-01
	# shots add the film rig below; no quality-profile override is introduced.
	var weight := clampf(amount, 0.0, 1.0)
	var historical := shot_id in ["aquileia_detail","legions_rain","caesar_orders","labienus_orders","legions_depart"]
	var interior := _interior_weight()
	if is_instance_valid(_sun) and _lighting.has("sun_color"):
		var grade := Color(0.70, 0.76, 0.83) if historical else Color(1.0, 0.89, 0.75)
		var strength := 0.42 if historical else 0.26
		_sun.light_color = (_lighting.sun_color as Color).lerp(grade, strength * weight)
	if _environment and _lighting.has("ambient_energy"):
		var floor_level := 0.72 if historical else lerpf(0.90, INTERIOR_AMBIENT, interior)
		_environment.ambient_light_energy = float(_lighting.ambient_energy) * lerpf(1.0, floor_level, weight)
	_apply_interior_rig(weight * interior)
	_apply_forge_glow(weight)


const INTERIOR_AMBIENT := 0.50
const FORGE_GLOW_RADIUS := 9.0


## 1 while the film camera is inside the family home during an I-01 film,
## including the handoff shot that leaves from there; 0 everywhere else.
func _interior_weight() -> float:
	if not is_instance_valid(camera) or not is_instance_valid(_world):
		return 0.0
	if shot_id in I01_SHOTS:
		_interior_film = true
	elif shot_id not in ["mission_dialogue", "mission_reaction", "player"]:
		_interior_film = false
	if not _interior_film:
		return 0.0
	var table := _world.to_global(I01Props.anchor("i01_table"))
	return 1.0 if camera.global_position.distance_to(table) <= INTERIOR_RIG_RADIUS else 0.0


## Firelight of Sextus' forge for film shots near the hearth (HB S. 15):
## one warm, slowly breathing light at the embers. It exists only while a
## film camera is within reach of the forge and fades with the handoff.
func _apply_forge_glow(weight: float) -> void:
	var hearth := Vector3.INF
	if weight > 0.001 and (shot_id in DUO_SHOTS or shot_id in ["mission_dialogue", "mission_reaction", "player"]) and is_instance_valid(_world) and _world.has_method("get_cinematic_anchor") and is_instance_valid(camera):
		var value: Variant = _world.call("get_cinematic_anchor", "i04_hearth")
		# Unknown keys fall back to the player position; only a real hearth counts.
		if value is Vector3 and (value as Vector3).is_finite() and _world.get("i04_props") != null and camera.global_position.distance_to(value) <= FORGE_GLOW_RADIUS:
			hearth = value
	if not hearth.is_finite():
		if is_instance_valid(_forge_glow):
			_forge_glow.visible = false
		return
	if not is_instance_valid(_forge_glow):
		_forge_glow = OmniLight3D.new()
		_forge_glow.name = "ForgeGlow"
		_forge_glow.light_color = Color(1.0, 0.56, 0.26)
		_forge_glow.omni_range = 6.5
		_forge_glow.omni_attenuation = 1.4
		_forge_glow.shadow_enabled = true
		add_child(_forge_glow)
	_forge_glow.visible = true
	_forge_glow.global_position = hearth + Vector3(-0.35, 0.30, 0.25)
	var breathe := 1.0 if reduced_motion else 1.0 + 0.07 * sin(elapsed * 2.6) + 0.04 * sin(elapsed * 6.3 + 0.7)
	_forge_glow.light_energy = 2.4 * weight * breathe


func _apply_interior_rig(weight: float) -> void:
	if weight <= 0.001:
		if is_instance_valid(_rig):
			_rig.visible = false
		return
	if not is_instance_valid(_rig):
		_rig = Node3D.new()
		_rig.name = "I01FilmLights"
		add_child(_rig)
		var window := SpotLight3D.new()
		window.name = "WindowKey"
		window.light_color = Color(1.0, 0.95, 0.86)
		window.spot_range = 8.0
		window.spot_angle = 46.0
		window.spot_angle_attenuation = 0.8
		window.spot_attenuation = 0.9
		window.shadow_enabled = true
		window.shadow_bias = 0.06
		_rig.add_child(window)
		var hearth := OmniLight3D.new()
		hearth.name = "HearthWarm"
		hearth.light_color = Color(1.0, 0.63, 0.34)
		hearth.omni_range = 5.5
		hearth.omni_attenuation = 1.3
		_rig.add_child(hearth)
		var fill := OmniLight3D.new()
		fill.name = "CameraFill"
		fill.light_color = Color(0.78, 0.84, 0.95)
		fill.omni_range = 4.5
		fill.omni_attenuation = 1.1
		fill.light_specular = 0.0
		_rig.add_child(fill)
	_rig.visible = true
	var table := _world.to_global(I01Props.anchor("i01_table"))
	var key := _rig.get_node("WindowKey") as SpotLight3D
	key.global_position = table + Vector3(1.15, 1.45, -1.75)
	key.look_at(table + Vector3(-0.1, 0.25, 0.55), Vector3.UP)
	key.light_energy = 2.6 * weight
	var hearth_light := _rig.get_node("HearthWarm") as OmniLight3D
	hearth_light.global_position = table + Vector3(-1.25, 0.55, 1.95)
	# A slow, shallow breathing of the fire; no flicker in reduced motion.
	var breathe := 1.0 if reduced_motion else 1.0 + 0.05 * sin(elapsed * 2.3) + 0.03 * sin(elapsed * 5.1 + 1.0)
	hearth_light.light_energy = 1.25 * weight * breathe
	var fill_light := _rig.get_node("CameraFill") as OmniLight3D
	fill_light.global_position = camera.global_position + Vector3.UP * 0.25
	fill_light.light_energy = 0.30 * weight
