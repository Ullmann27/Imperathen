extends RefCounted
## Missile mechanics for the level-A authority: launch, ballistic flight and
## aim. Pure functions on plain values; melee_core.gd owns the state, the
## phases (draw, hold, release, recover) and the contact with shields and
## bodies. All weapon values come from weapon_catalog.gd.
##
## Flight: gravity plus a speed loss per metre flown (`drag_per_m`),
## integrated at the core's 60 Hz. Aim is the flat-arc solution refined by
## flying the shot with that same law, so drag does not make shots fall
## short (the test measures the remaining error).

const Weapons = preload("res://scripts/domain/melee/weapon_catalog.gd")
const GRAVITY := 9.81
const MAX_FLIGHT_FRAMES := 600


## Unit direction for a yaw (0 = -Z, like a fighter's facing) and a pitch
## (radians, up positive).
static func direction(yaw: float, pitch: float) -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3(0.0, sin(pitch), -cos(pitch))


static func launch_speed(weapon_id: String) -> float:
	return float(Weapons.weapon(weapon_id).get("projectile", {}).get("speed_m_s", 0.0))


static func launch_energy(weapon_id: String) -> float:
	var p: Dictionary = Weapons.weapon(weapon_id).get("projectile", {})
	return 0.5 * float(p.get("mass_kg", 0.0)) * pow(float(p.get("speed_m_s", 0.0)), 2.0)


static func energy(weapon_id: String, velocity: Vector3) -> float:
	return 0.5 * float(Weapons.weapon(weapon_id).get("projectile", {}).get("mass_kg", 0.0)) * velocity.length_squared()


## Flat-arc launch angles without drag: {yaw, pitch, in_range}. Out of
## range the pitch is 45 degrees (the longest throw).
static func aim_vacuum(from: Vector3, to: Vector3, speed: float) -> Dictionary:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	var x := flat.length()
	var y := to.y - from.y
	var yaw := atan2(-flat.x, -flat.y) if x > 0.0001 else 0.0
	if x <= 0.0001 or speed <= 0.0:
		return {"yaw":yaw, "pitch":0.0, "in_range":false}
	var v2 := speed * speed
	var root := v2 * v2 - GRAVITY * (GRAVITY * x * x + 2.0 * y * v2)
	if root < 0.0:
		return {"yaw":yaw, "pitch":PI * 0.25, "in_range":false}
	return {"yaw":yaw, "pitch":atan((v2 - sqrt(root)) / (GRAVITY * x)), "in_range":true}


## Height at which a missile launched with `pitch` passes the horizontal
## distance `x`, flown with the real flight law; NAN if it lands earlier.
static func _height_at(weapon_id: String, pitch: float, x: float) -> float:
	var pos := Vector3.ZERO
	var vel := direction(0.0, pitch) * launch_speed(weapon_id)
	for i in MAX_FLIGHT_FRAMES:
		var next := advance(weapon_id, pos, vel, 1.0 / 60.0)
		var after: Vector3 = next[0]
		if -after.z >= x:
			return lerpf(pos.y, after.y, (x + pos.z) / maxf(0.000001, pos.z - after.z))
		if after.z >= pos.z:
			break
		pos = after
		vel = next[1]
	return NAN


## Launch angles of the weapon's missile from `from` to `to`: the flat arc,
## corrected for its drag by flying the shot (four refinements).
static func aim(weapon_id: String, from: Vector3, to: Vector3) -> Dictionary:
	var speed := launch_speed(weapon_id)
	var result := aim_vacuum(from, to, speed)
	if not bool(result.in_range):
		return result
	var x := Vector2(to.x - from.x, to.z - from.z).length()
	var wanted := to.y - from.y
	var raised := wanted
	for i in 4:
		var height := _height_at(weapon_id, float(result.pitch), x)
		if is_nan(height):
			return {"yaw":result.yaw, "pitch":PI * 0.25, "in_range":false}
		raised += wanted - height
		var again := aim_vacuum(Vector3.ZERO, Vector3(0.0, raised, -x), speed)
		if not bool(again.in_range):
			return {"yaw":result.yaw, "pitch":PI * 0.25, "in_range":false}
		result.pitch = again.pitch
	return result


## Largest aim error (radians) of a shooter: skill 0-100 moves between the
## weapon's novice and expert spread; fatigue (0-1) and holding the draw
## past the comfortable time widen it.
static func spread(weapon_id: String, skill: float, fatigue: float, held_s: float) -> float:
	var w := Weapons.weapon(weapon_id)
	var s: Dictionary = w.get("spread_deg", {})
	var base := lerpf(float(s.get("novice", 3.0)), float(s.get("expert", 1.0)), clampf(skill, 0.0, 100.0) / 100.0)
	var comfort := float(w.get("hold_comfort_s", w.get("phases", {}).get("hold_max_s", 1.0)))
	var strain := 0.0 if bool(w.get("holds_loaded", false)) else maxf(0.0, held_s - comfort) * 0.5
	return deg_to_rad(base * (1.0 + clampf(fatigue, 0.0, 1.0) + strain))


## One 60 Hz step of a missile: returns [position, velocity] after `dt`.
static func advance(weapon_id: String, position: Vector3, velocity: Vector3, dt: float) -> Array:
	var drag := float(Weapons.weapon(weapon_id).get("projectile", {}).get("drag_per_m", 0.0))
	var v := velocity + Vector3(0.0, -GRAVITY * dt, 0.0)
	v *= maxf(0.0, 1.0 - drag * v.length() * dt)
	return [position + v * dt, v]
