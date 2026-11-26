extends RefCounted
## Dynamic, player-controllable level-A combat camera. It frames the focused
## fighter and the opponent from over the focused fighter's shoulder, keeps
## both bodies inside the view, smooths with a critically damped spring and
## adds a short, energy-scaled impact shake on the exact contact frame.
## Presentation only; it never touches the melee state.

const TARGET_HEIGHT := 1.25
const MIN_DISTANCE := 2.6
const MAX_DISTANCE := 7.0
const SIDE_ANGLE := deg_to_rad(32.0)
const SMOOTH_TIME := 0.18
const MARGIN := deg_to_rad(6.0)
const SHAKE_TIME := 0.22

var fov_deg := 50.0
var aspect := 16.0 / 9.0
## Player control: orbit around the pair and zoom (1 = automatic distance).
var yaw_offset := 0.0
var zoom := 1.0
var position := Vector3.ZERO
var target := Vector3.ZERO
var _velocity := Vector3.ZERO
var _target_velocity := Vector3.ZERO
var _initialized := false
var _shake := 0.0
var _shake_t := 0.0
var _shake_seed := 0


func orbit(radians: float) -> void:
	yaw_offset = wrapf(yaw_offset + radians, -PI, PI)


func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, 0.6, 1.8)


## Impact from a melee event (hit/block/parry/guard_broken): amplitude grows
## with the logarithm of the impact energy.
func impact(event: Dictionary) -> void:
	if not event.get("type", "") in ["hit", "block", "parry", "guard_broken"]:
		return
	var energy := float(event.get("energy_j", 0.0))
	_shake = maxf(_shake, clampf(log(1.0 + energy) / log(1.0 + 300.0), 0.0, 1.0) * 0.05)
	_shake_t = 0.0
	_shake_seed = int(event.get("frame", 0))


## Desired (unsmoothed) camera position and look target.
func desired(focus: Vector3, opponent: Vector3) -> Dictionary:
	var a := Vector3(focus.x, 0.0, focus.z)
	var b := Vector3(opponent.x, 0.0, opponent.z)
	var line := b - a
	var separation := line.length()
	var forward := line / separation if separation > 0.001 else Vector3.FORWARD
	var look := a.lerp(b, 0.45) + Vector3(0.0, TARGET_HEIGHT, 0.0)
	# Behind the focused fighter, swung toward its right shoulder.
	var back := (-forward).rotated(Vector3.UP, -SIDE_ANGLE + yaw_offset)
	var distance := clampf((separation * 0.9 + 2.2) * zoom, MIN_DISTANCE, MAX_DISTANCE)
	var eye := Vector3.ZERO
	# Pull back until both bodies (head and feet) fit the horizontal and
	# vertical field of view with a margin.
	for i in 24:
		eye = look + back * distance + Vector3(0.0, 0.45 + distance * 0.12, 0.0)
		if _fits(eye, look, [a, b]) or distance >= MAX_DISTANCE:
			break
		distance = minf(MAX_DISTANCE, distance * 1.08)
	return {"position":eye, "target":look, "distance":distance}


func _fits(eye: Vector3, look: Vector3, bodies: Array) -> bool:
	var basis := Basis.looking_at(look - eye, Vector3.UP)
	var half_v := deg_to_rad(fov_deg) * 0.5 - MARGIN
	var half_h := atan(tan(deg_to_rad(fov_deg) * 0.5) * aspect) - MARGIN
	for body: Vector3 in bodies:
		for height: float in [0.05, 1.8]:
			var local := basis.inverse() * (body + Vector3(0.0, height, 0.0) - eye)
			if local.z >= -0.1:
				return false
			if absf(atan2(local.x, -local.z)) > half_h or absf(atan2(local.y, -local.z)) > half_v:
				return false
	return true


## Advance the smoothed camera; returns the Transform3D to apply.
func update(focus: Vector3, opponent: Vector3, delta: float) -> Transform3D:
	var want := desired(focus, opponent)
	if not _initialized:
		position = want.position
		target = want.target
		_initialized = true
	else:
		position = _spring(position, want.position, _velocity, delta, true)
		target = _spring(target, want.target, _target_velocity, delta, false)
	var xf := Transform3D(Basis.looking_at(target - position, Vector3.UP), position)
	if _shake > 0.0:
		_shake_t += delta
		var fade := maxf(0.0, 1.0 - _shake_t / SHAKE_TIME)
		var s := float(_shake_seed) * 0.37 + _shake_t * 61.0
		var offset := Vector3(sin(s * 1.7), sin(s * 2.3 + 1.1), 0.0) * _shake * fade * fade
		xf.origin += xf.basis * offset
		if fade <= 0.0:
			_shake = 0.0
	return xf


## Critically damped spring toward `goal` (frame-rate independent).
func _spring(current: Vector3, goal: Vector3, velocity: Vector3, delta: float, is_position: bool) -> Vector3:
	var omega := 2.0 / SMOOTH_TIME
	var x := omega * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - goal
	var temp := (velocity + change * omega) * delta
	var next_velocity := (velocity - temp * omega) * decay
	var result := goal + (change + temp) * decay
	if is_position:
		_velocity = next_velocity
	else:
		_target_velocity = next_velocity
	return result


func shaking() -> bool:
	return _shake > 0.0
