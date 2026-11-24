extends RefCounted
## A collision volume for the shoulder and conversation cameras.
## Resolve both the wanted boom and the final smoothed position: interpolating
## two safe endpoints can otherwise pass through a corner between them.

const RADIUS := 0.24
const MARGIN := 0.015
const CONTACT_GAP := 0.005
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
		return previous if previous.is_finite() else Vector3.ZERO
	# Godot cast_motion deliberately ignores shapes overlapping its start. Do
	# not turn that behavior into permission to cross a newly inserted wall.
	if not _clear(space,anchor):
		if previous.is_finite() and _clear(space,previous):
			_last_clear = previous
			return previous
		if _last_clear.is_finite() and _clear(space,_last_clear):
			return _last_clear
		return anchor
	var safe := _sweep(space,anchor,wanted)
	if previous.is_finite():
		safe = _sweep(space,anchor,previous.lerp(safe,clampf(smoothing,0.0,1.0)))
	_last_clear = safe
	return safe


func _clear(space: PhysicsDirectSpaceState3D, point: Vector3) -> bool:
	_query.transform = Transform3D(Basis.IDENTITY,point)
	_query.motion = Vector3.ZERO
	return space.intersect_shape(_query,1).is_empty()


func _sweep(space: PhysicsDirectSpaceState3D, anchor: Vector3, wanted: Vector3) -> Vector3:
	var motion := wanted-anchor
	var length := motion.length()
	if length <= 0.000001:
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
	# Keep the output safe when a backend's sweep and overlap tolerances differ.
	# The caller verified the anchor; narrow the same unobstructed segment only.
	var lower := 0.0
	var upper := distance/length
	for iteration in 12:
		var middle := (lower+upper)*0.5
		if _clear(space,anchor+motion*middle):
			lower = middle
		else:
			upper = middle
	return anchor+motion*lower
