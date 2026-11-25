extends RefCounted
## Resolve a camera volume before and after smoothing. Vector3.INF means no
## verified local placement is available; callers must not apply that value.

const RADIUS := 0.24
const MARGIN := 0.015
const CONTACT_GAP := 0.005
const RECOVERY_LIMIT := 1.0
const RECOVERY_STEPS := 8
var _shape := SphereShape3D.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _last_clear := Vector3.INF


func _init() -> void:
	_shape.radius = RADIUS
	_query.shape = _shape
	_query.margin = MARGIN
	_query.collision_mask = 1
	_query.collide_with_areas = false
	_query.collide_with_bodies = true


func reset() -> void:
	_last_clear = Vector3.INF


func place(space: PhysicsDirectSpaceState3D, anchor: Vector3, wanted: Vector3,
		previous: Vector3, smoothing: float, excluded: Array[RID] = []) -> Vector3:
	_query.exclude = excluded
	if not anchor.is_finite() or not wanted.is_finite() or not is_finite(smoothing):
		return _verified_history(space,previous)
	var sweep_anchor := anchor
	# cast_motion ignores initial overlaps. Retain verified history, or recover
	# a clear origin locally before using any motion cast.
	if not _clear(space,anchor):
		var history := _verified_history(space,previous)
		if history.is_finite():
			return history
		sweep_anchor = _recover_anchor(space,anchor,wanted)
		if not sweep_anchor.is_finite():
			return Vector3.INF
	var safe := _sweep(space,sweep_anchor,wanted)
	if previous.is_finite():
		safe = _sweep(space,sweep_anchor,previous.lerp(safe,clampf(smoothing,0.0,1.0)))
	_last_clear = safe
	return safe


func _verified_history(space: PhysicsDirectSpaceState3D, previous: Vector3) -> Vector3:
	if previous.is_finite() and _clear(space,previous):
		_last_clear = previous
		return previous
	if _last_clear.is_finite() and _clear(space,_last_clear):
		return _last_clear
	return Vector3.INF


func _recover_anchor(space: PhysicsDirectSpaceState3D, anchor: Vector3,
		wanted: Vector3) -> Vector3:
	var candidate := anchor
	for iteration in RECOVERY_STEPS:
		if _clear(space,candidate):
			return candidate
		# _clear prepared the same stationary query. Contact pairs are ordered
		# query-shape point, obstacle point; their difference separates them.
		var contacts := space.collide_shape(_query,16)
		var correction := Vector3.ZERO
		for pair_index in range(0,contacts.size()-1,2):
			var separation: Vector3 = contacts[pair_index+1]-contacts[pair_index]
			if separation.is_finite() and separation.length_squared() > correction.length_squared():
				correction = separation
		if correction.length_squared() <= 0.00000001:
			break
		candidate += correction + correction.normalized()*(MARGIN+CONTACT_GAP)
		if not candidate.is_finite() or candidate.distance_squared_to(anchor) > RECOVERY_LIMIT*RECOVERY_LIMIT:
			break
	if candidate.is_finite() and candidate.distance_squared_to(anchor) <= RECOVERY_LIMIT*RECOVERY_LIMIT and _clear(space,candidate):
		return candidate
	# Backends may report an overlap without usable contact depths. The fixed
	# local search is bounded; every accepted position is verified separately.
	var preferred := (wanted-anchor).normalized()
	for distance: float in [RADIUS+MARGIN+CONTACT_GAP,0.5,RECOVERY_LIMIT]:
		if preferred.is_finite() and not preferred.is_zero_approx():
			candidate = anchor+preferred*distance
			if _clear(space,candidate):
				return candidate
		for x in range(-1,2):
			for y in range(-1,2):
				for z in range(-1,2):
					if x == 0 and y == 0 and z == 0:
						continue
					candidate = anchor+Vector3(x,y,z).normalized()*distance
					if _clear(space,candidate):
						return candidate
	return Vector3.INF


func _clear(space: PhysicsDirectSpaceState3D, point: Vector3) -> bool:
	if not point.is_finite():
		return false
	_query.transform = Transform3D(Basis.IDENTITY,point)
	_query.motion = Vector3.ZERO
	return space.intersect_shape(_query,1).is_empty()


func _sweep(space: PhysicsDirectSpaceState3D, anchor: Vector3, wanted: Vector3) -> Vector3:
	var motion := wanted-anchor
	var length := motion.length()
	if not is_finite(length) or length <= 0.000001:
		return anchor
	_query.transform = Transform3D(Basis.IDENTITY,anchor)
	_query.motion = motion
	var fractions := space.cast_motion(_query)
	if fractions.size() != 2 or not is_finite(fractions[0]):
		return anchor
	var distance := length*clampf(fractions[0],0.0,1.0)
	if fractions[0] < 1.0:
		distance = maxf(0.0,distance-CONTACT_GAP)
	var candidate := anchor+motion*(distance/length)
	if _clear(space,candidate):
		return candidate
	# The caller verified the origin; narrow the same unobstructed segment.
	var lower := 0.0
	var upper := distance/length
	for iteration in 12:
		var middle := (lower+upper)*0.5
		if _clear(space,anchor+motion*middle):
			lower = middle
		else:
			upper = middle
	return anchor+motion*lower
