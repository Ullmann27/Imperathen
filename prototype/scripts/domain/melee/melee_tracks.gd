extends RefCounted
## Read access to the measured strike tracks (melee_track_data.gd).
## Clip frames are 60 Hz. Points are in the fighter's own Godot frame
## (+X right, +Y up from the ground, -Z forward) at body scale 1.0.

const Data = preload("res://scripts/domain/melee/melee_track_data.gd")
const Geo = preload("res://scripts/domain/melee/melee_geometry.gd")
const FPS := 60
## Kits whose moves are the player's existing CombatActions techniques.
const PLAYER_UNARMED := "youth_unarmed"
const PLAYER_ARMED := "legionary"


static func key(kit: String, move: String) -> String:
	return kit + "/" + move


static func has_move(kit: String, move: String) -> bool:
	return Data.MOVES.has(key(kit, move))


static func move(kit: String, move_id: String) -> Dictionary:
	return Data.MOVES.get(key(kit, move_id), {})


static func kit(kit_id: String) -> Dictionary:
	return Data.KITS.get(kit_id, {})


static func moves_of(kit_id: String) -> Array[String]:
	var result: Array[String] = []
	for k: String in Data.MOVES:
		if k.begins_with(kit_id + "/"):
			result.append(k.substr(kit_id.length() + 1))
	return result


## Frame-exact phase boundaries derived from the displayed animation.
static func timing(kit_id: String, move_id: String) -> Dictionary:
	var m := move(kit_id, move_id)
	if m.is_empty():
		return {}
	return {"frames":int(m.frames), "duration":float(m.duration), "start":int(m.start), "peak":int(m.peak),
		"end":int(m.end), "start_s":float(m.start) / FPS, "peak_s":float(m.peak) / FPS, "end_s":float(m.end) / FPS,
		"reach":float(m.reach), "radius":float(m.radius), "family":str(m.family)}


static func frame_of(seconds: float) -> int:
	return int(floor(seconds * FPS + 0.000001))


## Strike capsule [base, tip] in the fighter frame at a clip frame.
static func segment(kit_id: String, move_id: String, frame: int) -> Array:
	var m := move(kit_id, move_id)
	if m.is_empty():
		return []
	var f := clampi(frame, 0, int(m.frames) - 1) * 3
	var base: Array = m.base
	var tip: Array = m.tip
	return [Vector3(base[f], base[f + 1], base[f + 2]), Vector3(tip[f], tip[f + 1], tip[f + 2])]


static func _shield_at(values: Array, frame: int) -> Array:
	var count := values.size() / 9
	if count == 0:
		return []
	var i := clampi(frame, 0, count - 1) * 9
	return [Vector3(values[i], values[i + 1], values[i + 2]), Vector3(values[i + 3], values[i + 4], values[i + 5]), Vector3(values[i + 6], values[i + 7], values[i + 8])]


## Shield frame [centre, width axis, height axis] during a strike, a guard
## (frame clamps to the held pose) or the idle stance.
static func shield(kit_id: String, pose_id: String, frame: int) -> Array:
	var m := move(kit_id, pose_id)
	if not m.is_empty() and m.has("shield"):
		return _shield_at(m.shield, frame)
	var g: Dictionary = Data.GUARDS.get(key(kit_id, pose_id), {})
	if not g.is_empty():
		return _shield_at(g.shield, frame)
	return []


static func guard_styles() -> Array[String]:
	return ["guard_front", "guard_high", "guard_low", "guard_left", "guard_right"]


## Sweep the strike capsule from clip frame-1 to frame against a vertical
## body capsule standing at `foot` (world ground point). `origin`/`yaw` place
## the attacker; `scale` is its body size relative to the measured rig.
## Returns {} or {point, along, substep, speed}. Substeps never exceed 3 cm.
static func sweep_body(kit_id: String, move_id: String, scale: float, origin: Vector3, yaw: float, frame: int, foot: Vector3, radius: float, height: float) -> Dictionary:
	var m := move(kit_id, move_id)
	if m.is_empty() or frame < 1:
		return {}
	var prev := segment(kit_id, move_id, frame - 1)
	var cur := segment(kit_id, move_id, frame)
	var a0 := Geo.to_world(origin, yaw, scale, prev[0])
	var b0 := Geo.to_world(origin, yaw, scale, prev[1])
	var a1 := Geo.to_world(origin, yaw, scale, cur[0])
	var b1 := Geo.to_world(origin, yaw, scale, cur[1])
	var strike_radius := float(m.radius) * scale
	var axis := Geo.body_axis(foot, radius, height)
	var steps := clampi(int(ceil(maxf((a1 - a0).length(), (b1 - b0).length()) / 0.03)), 1, 16)
	for k in range(1, steps + 1):
		var s := float(k) / float(steps)
		var a := a0.lerp(a1, s)
		var b := b0.lerp(b1, s)
		var closest := Geo.segment_segment(a, b, axis[0], axis[1])
		if float(closest[2]) <= strike_radius + radius:
			var along := float(closest[0])
			var velocity := ((a1 - a0) * FPS).lerp((b1 - b0) * FPS, along)
			return {"point":a.lerp(b, along), "along":along, "substep":s, "speed":velocity.length(), "velocity":velocity}
	return {}


## Fastest speed (m/s, scale 1) of the strike point at `along` (0 base ..
## 1 tip) between the live-window start and `frame`.
static func drive_speed(kit_id: String, move_id: String, frame: int, along: float) -> float:
	var m := move(kit_id, move_id)
	if m.is_empty():
		return 0.0
	var best := 0.0
	for f in range(maxi(1, int(m.start)), mini(frame, int(m.frames) - 1) + 1):
		var a := segment(kit_id, move_id, f - 1)
		var b := segment(kit_id, move_id, f)
		var p0: Vector3 = (a[0] as Vector3).lerp(a[1], along)
		var p1: Vector3 = (b[0] as Vector3).lerp(b[1], along)
		best = maxf(best, p0.distance_to(p1) * FPS)
	return best
