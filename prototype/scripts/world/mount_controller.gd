extends Node3D
## Local mounted movement and collision. The scene remains in charge of input
## focus, access permission, player/horse identities, saves and horse animation.

signal state_changed(mounted: bool)
signal action_feedback(text: String)

const RiderPose := preload("res://scripts/world/mounted_rider_pose.gd")
const BOARD_RADIUS := 1.52
const BOARD_HEIGHT := 0.48
const SIDE_DISTANCE := 1.11
const FLOOR_SCAN := 0.50
const FLOOR_GAP := 0.025
const STILL_SPEED := 0.16
const WALK_SPEED := 1.20
const CANTER_SPEED := 3.40
const MIN_BOARDING_SIDE := 0.49
const ACCELERATION := 2.5
const BRAKING := 4.0
const TURN_SPEED := 2.35
const WORLD_COLLISION_LAYER := 1
const NO_POINT := Vector3.INF

var _player: CharacterBody3D
var _figure: Node3D
var _horse: CharacterBody3D
var _saddle: Node3D
var _shapes: Array[CollisionShape3D] = []
var _sole_offset := 0.90
var _saved_layer := 0
var _saved_mask := 0
var _saved_figure_basis := Basis.IDENTITY
var _boarding_origin := Vector3.ZERO
var _seat_offset := Vector3.ZERO
var _mounted := false
var _pending := false
var _speed := 0.0
var _pose := RiderPose.new()
var _probe := PhysicsShapeQueryParameters3D.new()


## The horse body origin lies at ground level and faces gameplay -Z. The
## saddle node is the rider pelvis socket (prefer a BoneAttachment3D).
## The rider and the horse stay in their own existing scene hierarchies.
func configure(rider: CharacterBody3D, figure: Node3D, horse: CharacterBody3D, saddle: Node3D, sole_offset := 0.90) -> bool:
	if _mounted or not is_instance_valid(rider) or not is_instance_valid(figure):
		return false
	if not is_instance_valid(horse) or not is_instance_valid(saddle) or horse == rider:
		return false
	if not rider.is_ancestor_of(figure) or not horse.is_ancestor_of(saddle):
		return false
	if not is_finite(sole_offset) or sole_offset <= 0.0:
		return false
	var colliders: Array[CollisionShape3D] = []
	for child: Node in rider.get_children():
		var collision := child as CollisionShape3D
		if collision != null and collision.shape != null and not collision.disabled:
			colliders.append(collision)
	if colliders.is_empty():
		return false
	_player = rider
	_figure = figure
	_horse = horse
	_saddle = saddle
	_sole_offset = sole_offset
	_shapes = colliders
	_probe.collide_with_areas = false
	_probe.collide_with_bodies = true
	_probe.margin = minf(0.010, maxf(0.002, rider.safe_margin))
	_pending = false
	return true


func is_mounted() -> bool:
	return _mounted


func riding_speed() -> float:
	return _speed


func riding_gait() -> StringName:
	if _speed < 0.13:
		return &"idle"
	if _speed >= 2.86:
		return &"canter"
	return &"trot" if _speed > 1.57 else &"walk"


func camera_exclusions() -> Array[RID]:
	var excluded: Array[RID] = []
	if is_instance_valid(_player):
		excluded.append(_player.get_rid())
	if _mounted and is_instance_valid(_horse):
		excluded.append(_horse.get_rid())
	return excluded


func interaction_label() -> String:
	if _mounted:
		return "Absteigen"
	return "Aufsteigen" if _nodes_ready() and _near_boarding() else ""


## A shared, one-shot queue for action buttons and keyboard. Call only when
## gameplay owns focus and this scene grants permission to ride.
func request_interact() -> bool:
	if interaction_label().is_empty():
		return false
	_pending = true
	return true


func clear_pending() -> void:
	_pending = false


func _exit_tree() -> void:
	if _mounted:
		_restore_walker(_boarding_origin, _saved_figure_basis, false)


## Call in the owner's physics callback with the same analog/keyboard axis
## given to on-foot movement. True consumes movement for this tick. A refused
## mount leaves on-foot movement intact. The first dismounted frame is settled.
func advance(delta: float, axis: Vector2, camera_yaw: float, faster: bool) -> bool:
	if not _nodes_ready():
		_pending = false
		if _mounted:
			_restore_walker(_boarding_origin, _saved_figure_basis)
			return true
		return false
	var was_mounted := _mounted
	if _pending:
		_pending = false
		if _mounted:
			_try_dismount()
		elif _near_boarding():
			_try_mount()
	if _mounted and was_mounted and delta > 0.0 and is_finite(delta):
		var direction := axis.limit_length(1.0) if axis.is_finite() else Vector2.ZERO
		_drive_horse(delta, direction, camera_yaw if is_finite(camera_yaw) else 0.0, faster)
	return _mounted or was_mounted


func _nodes_ready() -> bool:
	return is_instance_valid(_player) and _player.is_inside_tree() and is_instance_valid(_figure) and _figure.is_inside_tree() and is_instance_valid(_horse) and _horse.is_inside_tree() and is_instance_valid(_saddle) and _saddle.is_inside_tree() and _player.get_world_3d() == _horse.get_world_3d()


func _side_point(side: float) -> Vector3:
	var yaw := _horse.global_rotation.y
	return _saddle.global_position + Vector3(side * SIDE_DISTANCE, 0.0, 0.0).rotated(Vector3.UP, yaw)


func _near_boarding() -> bool:
	var rider := _player.global_position
	if absf(rider.y - _sole_offset - _horse.global_position.y) > BOARD_HEIGHT:
		return false
	var lateral := (rider - _saddle.global_position).dot(Vector3.RIGHT.rotated(Vector3.UP, _horse.global_rotation.y))
	if absf(lateral) < MIN_BOARDING_SIDE:
		return false
	var point := _side_point(signf(lateral))
	return Vector2(rider.x, rider.z).distance_squared_to(Vector2(point.x, point.z)) <= BOARD_RADIUS ** 2


func _floor_landing(side: float) -> Vector3:
	var at := _side_point(side)
	var reference_y := _horse.global_position.y
	var above := Vector3(at.x, reference_y + FLOOR_SCAN, at.z)
	var below := Vector3(at.x, reference_y - FLOOR_SCAN, at.z)
	var line := PhysicsRayQueryParameters3D.create(above, below, WORLD_COLLISION_LAYER, [_horse.get_rid(), _player.get_rid()])
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(line)
	if hit.is_empty() or (hit.normal as Vector3).dot(Vector3.UP) < cos(_player.floor_max_angle):
		return NO_POINT
	return (hit.position as Vector3) + Vector3.UP * (_sole_offset + FLOOR_GAP)


func _swept_clear(start: Vector3, end: Vector3) -> bool:
	var space := _player.get_world_3d().direct_space_state
	_probe.collision_mask = (_saved_mask if _mounted else _player.collision_mask) | WORLD_COLLISION_LAYER
	_probe.exclude = [_player.get_rid(), _horse.get_rid()]
	for shape: CollisionShape3D in _shapes:
		if not is_instance_valid(shape) or shape.shape == null:
			return false
		_probe.shape = shape.shape
		_probe.transform = Transform3D(_player.global_basis, start) * shape.transform
		_probe.motion = Vector3.ZERO
		if not space.intersect_shape(_probe, 1).is_empty():
			return false
		_probe.motion = end - start
		if _probe.motion.length_squared() > 0.0000001:
			var fractions := space.cast_motion(_probe)
			if fractions.size() < 2 or fractions[0] < 1.0:
				return false
	return true


func _flat_speed(body: CharacterBody3D) -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


func _try_mount() -> void:
	if _flat_speed(_horse) > STILL_SPEED:
		action_feedback.emit("Das Pferd muss zum Aufsteigen stehen.")
		return
	var origin := _player.global_position
	var near_side := -1.0 if origin.distance_squared_to(_side_point(-1.0)) <= origin.distance_squared_to(_side_point(1.0)) else 1.0
	var approach := _floor_landing(near_side)
	if not approach.is_finite() or Vector2(origin.x, origin.z).distance_squared_to(Vector2(approach.x, approach.z)) > BOARD_RADIUS ** 2:
		action_feedback.emit("Neben dem Pferd fehlt ein sicherer Aufstieg.")
		return
	if absf(origin.y - approach.y) > BOARD_HEIGHT:
		action_feedback.emit("Geh auf die gleiche Ebene wie das Pferd.")
		return
	if not _pose.start(_figure):
		action_feedback.emit("Die Reitfigur konnte nicht vorbereitet werden.")
		return
	_saved_figure_basis = _figure.basis
	_face_horse()
	if not _pose.seated(0.0):
		_pose.stop()
		_figure.basis = _saved_figure_basis
		action_feedback.emit("Die Sitzpose konnte nicht hergestellt werden.")
		return
	var seat := _saddle.global_position + origin - _pose.pelvis_world()
	var approach_raised := Vector3(approach.x, seat.y, approach.z)
	var walk_start := origin + Vector3.UP * FLOOR_GAP
	var walk_end := approach + Vector3.UP * FLOOR_GAP
	if not _swept_clear(walk_start, walk_end) or not _swept_clear(walk_end, approach_raised) or not _swept_clear(approach_raised, seat):
		_pose.stop()
		_figure.basis = _saved_figure_basis
		action_feedback.emit("Der Aufstieg ist versperrt.")
		return
	_saved_layer = _player.collision_layer
	_saved_mask = _player.collision_mask
	_boarding_origin = origin
	_player.collision_layer = 0
	_player.collision_mask = 0
	_player.velocity = Vector3.ZERO
	_horse.velocity = Vector3.ZERO
	_player.global_position = seat
	_seat_offset = seat - _saddle.global_position
	_player.reset_physics_interpolation()
	_mounted = true
	state_changed.emit(true)


func _try_dismount() -> void:
	if _flat_speed(_horse) > STILL_SPEED:
		action_feedback.emit("Halte zum Absteigen zuerst an.")
		return
	var start := _player.global_position
	for side: float in [-1.0, 1.0]:
		var landing := _floor_landing(side)
		if not landing.is_finite():
			continue
		var raised := Vector3(landing.x, maxf(start.y, landing.y), landing.z)
		if _swept_clear(start, raised) and _swept_clear(raised, landing):
			_restore_walker(landing, _figure.basis)
			return
	action_feedback.emit("Auf beiden Seiten fehlt Platz zum Absteigen.")


func _restore_walker(landing: Vector3, figure_basis: Basis, notify := true) -> void:
	_mounted = false
	_speed = 0.0
	_pose.stop()
	if is_instance_valid(_figure):
		_figure.basis = figure_basis
	if is_instance_valid(_player):
		_player.velocity = Vector3.ZERO
		if _player.is_inside_tree():
			_player.global_position = landing
		_player.collision_layer = _saved_layer
		_player.collision_mask = _saved_mask
		_player.reset_physics_interpolation()
	if notify:
		state_changed.emit(false)


func _face_horse() -> void:
	var yaw := _horse.global_rotation.y
	_figure.global_basis = Basis(Vector3.UP, yaw).scaled(_player.global_basis.get_scale() * _saved_figure_basis.get_scale())


func _drive_horse(delta: float, axis: Vector2, camera_yaw: float, faster: bool) -> void:
	var heading := _horse.global_rotation
	var direction := Vector3(axis.x, 0.0, axis.y).rotated(Vector3.UP, camera_yaw)
	var alignment := 0.0
	if direction.length_squared() > 0.001:
		heading.y = rotate_toward(heading.y, atan2(-direction.x, -direction.z), delta * TURN_SPEED)
		_horse.global_rotation = heading
		alignment = maxf(0.0, Vector3.FORWARD.rotated(Vector3.UP, heading.y).dot(direction.normalized()))
	var desired := Vector3.FORWARD.rotated(Vector3.UP, heading.y) * (CANTER_SPEED if faster else WALK_SPEED) * axis.length() * alignment
	var planar := Vector3(_horse.velocity.x, 0.0, _horse.velocity.z)
	var rate := ACCELERATION if desired.length_squared() > planar.length_squared() and planar.dot(desired) >= 0.0 else BRAKING
	planar = planar.move_toward(desired, rate * delta)
	var origin := _horse.global_position
	# Check headroom along the remaining motion with the rider's real shape.
	# The horse's own outer volume is swept by move_and_slide underneath it.
	var clearance := _saddle.global_position + _seat_offset
	if planar.length_squared() > 0.001 and not _swept_clear(clearance, clearance + planar * delta):
		planar = Vector3.ZERO
	var vertical := -0.30 if _horse.is_on_floor() else _horse.velocity.y - 19.6 * delta
	_horse.velocity = Vector3(planar.x, vertical, planar.z)
	_horse.move_and_slide()
	var actual := _horse.global_position - origin
	_speed = Vector2(actual.x, actual.z).length() / delta
	_face_horse()
	if _pose.seated(_speed / CANTER_SPEED):
		_seat_offset = _player.global_position - _pose.pelvis_world()
	_player.global_position = _saddle.global_position + _seat_offset
