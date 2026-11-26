extends RefCounted
## Pure geometry for level-A contact: capsules, shield boxes, sweeps.
## No engine physics; deterministic and usable headless.

const EPS := 0.0000001


## Closest points between segments p1-q1 and p2-q2 (Ericson, RTCD 5.1.9).
## Returns [s, t, distance] with s,t the parameters on each segment.
static func segment_segment(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= EPS and e <= EPS:
		return [0.0, 0.0, p1.distance_to(p2)]
	if a <= EPS:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= EPS:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var denom := a * e - b * b
			s = clampf((b * f - c * e) / denom, 0.0, 1.0) if denom > EPS else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	var c1 := p1 + d1 * s
	var c2 := p2 + d2 * t
	return [s, t, c1.distance_to(c2)]


## Vertical body capsule of a fighter standing at `foot` (ground point).
static func body_axis(foot: Vector3, radius: float, height: float) -> Array:
	return [foot + Vector3(0.0, radius, 0.0), foot + Vector3(0.0, maxf(radius, height - radius), 0.0)]


## Entry parameter (0..1) of segment p->q into an oriented box inflated by
## `inflate` (the strike radius; a box-swept-sphere approximation), or -1.
static func segment_box(p: Vector3, q: Vector3, center: Vector3, u: Vector3, v: Vector3, half: Vector3, inflate: float) -> float:
	var n := u.cross(v).normalized()
	var axes := [u.normalized(), v.normalized(), n]
	var extents := [half.x + inflate, half.y + inflate, half.z + inflate]
	var t0 := 0.0
	var t1 := 1.0
	var d := q - p
	for i in 3:
		var axis: Vector3 = axes[i]
		var origin := (p - center).dot(axis)
		var dir := d.dot(axis)
		var ext: float = extents[i]
		if absf(dir) < EPS:
			if absf(origin) > ext:
				return -1.0
			continue
		var a := (-ext - origin) / dir
		var b := (ext - origin) / dir
		if a > b:
			var swap := a
			a = b
			b = swap
		t0 = maxf(t0, a)
		t1 = minf(t1, b)
		if t0 > t1:
			return -1.0
	return t0


## Horizontal unit direction of a yaw (Godot: forward is -Z at yaw 0).
static func forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func right(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


## Fighter-frame point to world: rotate by yaw, scale by body size.
static func to_world(origin: Vector3, yaw: float, scale: float, local: Vector3) -> Vector3:
	return origin + Basis(Vector3.UP, yaw) * (local * scale)


static func to_local(origin: Vector3, yaw: float, world: Vector3) -> Vector3:
	return Basis(Vector3.UP, -yaw) * (world - origin)


## Direction of `world_dir` relative to a facing: "front", "back", "left", "right".
static func side_of(yaw: float, world_dir: Vector3) -> String:
	var local := Basis(Vector3.UP, -yaw) * Vector3(world_dir.x, 0.0, world_dir.z)
	if local.length_squared() < EPS:
		return "front"
	var angle := rad_to_deg(atan2(local.x, -local.z))
	if absf(angle) <= 45.0:
		return "front"
	if absf(angle) >= 135.0:
		return "back"
	return "right" if angle > 0.0 else "left"


## Deterministic 32-bit FNV-1a; independent of engine hashing.
static func fnv(text: String) -> int:
	var h := 2166136261
	for byte in text.to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xffffffff
	return h


static func unit_random(seed_text: String) -> float:
	return float(fnv(seed_text)) / 4294967296.0
