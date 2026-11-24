extends RefCounted
## Small, deterministic local pedestrian planner. Every candidate leg is swept
## using the actual CharacterBody3D shape, not a point ray or a teleport.
## This is intentionally bounded; it is not a village-wide navigation mesh.

const MAX_DIRECT_DISTANCE := 6.0
const MAX_PATH_LENGTH := 10.0
const ARRIVAL := 0.10


static func plan(body: CharacterBody3D, target: Vector3) -> Array[Vector3]:
	var start := body.global_position
	target.y = start.y
	var delta := target-start
	var distance := delta.length()
	if not is_finite(distance) or distance > MAX_DIRECT_DISTANCE or distance <= ARRIVAL:
		return []
	if clear_leg(body,start,target):
		return [target]
	var side := Vector3(-delta.z,0.0,delta.x).normalized()
	var middle := start.lerp(target,0.5)
	var best: Array[Vector3] = []
	var best_length := MAX_PATH_LENGTH
	# A fixed budget: at most eight intermediate points, two sweeps each.
	# Try both sides; retain the shortest physically clear candidate.
	for offset: float in [0.85,1.4,2.0,2.6]:
		for direction: float in [-1.0,1.0]:
			var via := middle+side*offset*direction
			var length := start.distance_to(via)+via.distance_to(target)
			if length >= best_length:
				continue
			if clear_leg(body,start,via) and clear_leg(body,via,target):
				best = [via,target]
				best_length = length
	return best


static func clear_leg(body: CharacterBody3D, start: Vector3, target: Vector3) -> bool:
	var from := body.global_transform
	from.origin = start
	return not body.test_move(from,target-start)
