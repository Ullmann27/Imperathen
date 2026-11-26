extends SceneTree
## Combat camera: framing, player control, smoothing and impact shake.

const Cam = preload("res://scripts/visuals/melee_camera.gd")
const Core = preload("res://scripts/domain/melee/melee_core.gd")
const Geo = preload("res://scripts/domain/melee/melee_geometry.gd")
const DT := 1.0 / 60.0
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_framing()
	_test_control()
	_test_smoothing()
	_test_shake()
	_test_own_shield_never_blocks_the_view()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("MELEE_CAMERA_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("MELEE_CAMERA_PASS" if failures.is_empty() else "MELEE_CAMERA_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent projection check with a real Camera3D-equivalent frustum.
func _inside(xf: Transform3D, cam, point: Vector3) -> bool:
	var local := xf.basis.inverse() * (point - xf.origin)
	if local.z >= 0.0:
		return false
	var half_v: float = tan(deg_to_rad(cam.fov_deg) * 0.5)
	var half_h: float = half_v * cam.aspect
	return absf(local.x / -local.z) <= half_h and absf(local.y / -local.z) <= half_v


func _test_framing() -> void:
	for separation: float in [0.9, 1.6, 2.4, 3.5]:
		for heading: float in [0.0, 1.3, -2.4]:
			var cam = Cam.new()
			var a := Vector3(3.0, 0.0, -2.0)
			var b := a + Vector3(-sin(heading), 0.0, -cos(heading)) * separation
			var xf: Transform3D = cam.update(a, b, DT)
			for body: Vector3 in [a, b]:
				for h: float in [0.05, 1.8]:
					_check(_inside(xf, cam, body + Vector3(0, h, 0)), "Both fighters fully framed at %.1f m, heading %.1f" % [separation, heading])
			# Over the focused fighter's shoulder: the camera is behind it.
			var behind := (xf.origin - a)
			behind.y = 0.0
			_check(behind.dot(b - a) < 0.0, "Camera stands behind the focused fighter")


func _test_control() -> void:
	var cam = Cam.new()
	var a := Vector3.ZERO
	var b := Vector3(0, 0, -1.6)
	var before: Transform3D = cam.update(a, b, DT)
	cam.orbit(deg_to_rad(60.0))
	cam.zoom_by(1.4)
	var after := before
	for i in 120:
		after = cam.update(a, b, DT)
	var angle_before := atan2(before.origin.x, before.origin.z)
	var angle_after := atan2(after.origin.x, after.origin.z)
	_check(absf(wrapf(angle_after - angle_before, -PI, PI)) > deg_to_rad(45.0), "Player orbit moves the camera around the pair")
	_check(Vector2(after.origin.x, after.origin.z).length() > Vector2(before.origin.x, before.origin.z).length(), "Player zoom pulls the camera back")
	for body: Vector3 in [a, b]:
		_check(_inside(after, cam, body + Vector3(0, 1.0, 0)), "Framing holds after player control")


func _test_smoothing() -> void:
	var cam = Cam.new()
	var a := Vector3.ZERO
	var b := Vector3(0, 0, -1.6)
	cam.update(a, b, DT)
	var last: Vector3 = cam.position
	var fastest := 0.0
	# The fighters jump 1.5 m sideways (a dodge plus a stagger in one frame).
	for i in 90:
		var xf: Transform3D = cam.update(a + Vector3(1.5, 0, 0), b + Vector3(1.5, 0, 0), DT)
		fastest = maxf(fastest, xf.origin.distance_to(last) / DT)
		last = xf.origin
	_check(fastest < 12.0, "Camera eases after a sudden jump (max %.2f m/s)" % fastest)
	var settled: Dictionary = cam.desired(a + Vector3(1.5, 0, 0), b + Vector3(1.5, 0, 0))
	_check(last.distance_to(settled.position) < 0.02, "Camera settles on the new framing within 1.5 s")


func _test_shake() -> void:
	var cam = Cam.new()
	var a := Vector3.ZERO
	var b := Vector3(0, 0, -1.4)
	var calm: Transform3D = cam.update(a, b, DT)
	cam.impact({"type":"hit", "energy_j":230.0, "frame":12})
	var shaken: Transform3D = cam.update(a, b, DT)
	_check(shaken.origin.distance_to(calm.origin) > 0.005, "A heavy impact shakes the camera on its contact frame")
	cam.impact({"type":"whiff", "energy_j":300.0})
	for i in 20:
		cam.update(a, b, DT)
	_check(not cam.shaking(), "The shake decays within 0.33 s")
	var weak = Cam.new()
	var strong = Cam.new()
	weak.update(a, b, DT)
	strong.update(a, b, DT)
	weak.impact({"type":"block", "energy_j":5.0, "frame":3})
	strong.impact({"type":"block", "energy_j":250.0, "frame":3})
	_check(strong._shake > weak._shake, "Shake amplitude grows with impact energy")


func _test_own_shield_never_blocks_the_view() -> void:
	# The real scutum of a legionary in a high guard, from the melee core.
	for guard: String in ["guard_high", "guard_front", "guard_right"]:
		var state := Core.new_state(1)
		Core.add_fighter(state, "rome", "legionary", {"team":"r"})
		Core.add_fighter(state, "axe", "axe_fighter", {"team":"t", "x":0.1, "z":-1.5})
		Core.face(state, "rome", "axe")
		Core.command(state, "rome", "guard", {"style":guard})
		Core.step(state, 0.5)
		var shield: Array = Core.shield_world(state.fighters.rome)
		var occluder := [shield[0], shield[1], shield[2], Core.shield_half(state.fighters.rome)]
		var cam = Cam.new()
		var a := Vector3(float(state.fighters.rome.x), 0, float(state.fighters.rome.z))
		var b := Vector3(float(state.fighters.axe.x), 0, float(state.fighters.axe.z))
		var plain: Dictionary = cam.desired(a, b)
		var aware: Dictionary = cam.desired(a, b, occluder)
		var blocked := false
		for h: float in [1.25, 1.6]:
			blocked = blocked or Geo.segment_box(aware.position, b + Vector3(0, h, 0), occluder[0], occluder[1], occluder[2], occluder[3], 0.0) >= 0.0
		_check(not blocked, "%s: the opponent's chest and head stay visible past the own scutum (side %.0f deg)" % [guard, float(aware.side_deg)])
		var xf := Transform3D(Basis.looking_at(aware.target - aware.position, Vector3.UP), aware.position)
		_check(_inside(xf, cam, b + Vector3(0, 1.0, 0)) and _inside(xf, cam, a + Vector3(0, 1.0, 0)), "%s: both fighters stay framed while avoiding the shield" % guard)
		print("camera %s: side %.0f deg (plain %.0f deg)" % [guard, float(aware.side_deg), float(plain.side_deg)])
