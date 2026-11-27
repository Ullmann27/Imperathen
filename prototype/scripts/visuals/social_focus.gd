extends RefCounted
## Physics-clock target selection: explicit speaker > dialog partner > a
## nearby visible person. One scan at 5 Hz, at most three candidate rays.
## No world queries in the render/animation path.
const PERIOD := 0.20
const NEAR_RANGE := 3.2
const DIALOG_RANGE := 5.5
const MIN_DOT := -0.10
var speaker: Node3D
var partner: Node3D
var ambient_target: Node3D
var ambient_enabled := true
var face_body := false
var _timer := 0.0
var _dwell := 0.0
var _cooldown := 0.0
var _last_ambient: Node3D
var _visible_target: Node3D
var _point := Vector3.INF

func set_dialog(target: Node3D, turn_body: bool = false) -> void:
	if partner == target and face_body == turn_body:
		return
	partner = target
	speaker = null
	face_body = turn_body
	_timer = 0.0
	_visible_target = null
	_point = Vector3.INF
	ambient_target = null

func set_speaker(target: Node3D) -> void:
	if speaker == target:
		return
	speaker = target
	_timer = 0.0
	_visible_target = null
	_point = Vector3.INF

func clear() -> void:
	set_dialog(null)
	speaker = null
	ambient_target = null
	_visible_target = null
	_point = Vector3.INF
	_timer = 0.0

func point() -> Vector3:
	return _point if is_instance_valid(_visible_target) and _visible_target.is_visible_in_tree() else Vector3.INF

func target() -> Node3D:
	return _visible_target if point().is_finite() else null

func _eligible(owner: Node3D, candidate: Node3D, limit: float, ambient: bool) -> bool:
	if not is_instance_valid(candidate) or candidate == owner or not candidate.is_inside_tree() or not candidate.is_visible_in_tree():
		return false
	if candidate.get_world_3d() != owner.get_world_3d() or not candidate.has_method("gaze_anchor"):
		return false
	if candidate.get("clip") == "death":
		return false
	var difference := candidate.global_position - owner.global_position
	var distance := difference.length()
	if distance < 0.20 or distance > limit:
		return false
	return not ambient or (-owner.global_basis.z.normalized()).dot(difference.normalized()) >= MIN_DOT

func _clear_line(owner: Node3D, candidate: Node3D) -> bool:
	var start: Vector3 = owner.call("gaze_anchor")
	var finish: Vector3 = candidate.call("gaze_anchor")
	if not start.is_finite() or not finish.is_finite() or start.distance_squared_to(finish) < 0.01:
		return false
	var excluded: Array[RID] = []
	for person: Node3D in [owner, candidate]:
		if person.get_parent() is CollisionObject3D:
			excluded.append((person.get_parent() as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(start, finish, 1, excluded)
	query.hit_from_inside = true
	return owner.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func update(owner: Node3D, delta: float, allow_ambient: bool) -> void:
	_timer -= delta
	_dwell -= delta
	_cooldown -= delta
	var explicit := is_instance_valid(speaker) or is_instance_valid(partner)
	if not explicit and (not ambient_enabled or not allow_ambient):
		ambient_target = null
		_visible_target = null
		_point = Vector3.INF
		return
	if _timer <= 0.0:
		_timer = PERIOD
		_visible_target = null
		if explicit:
			for candidate: Node3D in [speaker, partner]:
				if _eligible(owner, candidate, DIALOG_RANGE, false) and _clear_line(owner, candidate):
					_visible_target = candidate
					break
		else:
			if is_instance_valid(ambient_target) and _dwell <= 0.0:
				_last_ambient = ambient_target
				_cooldown = 2.2
				ambient_target = null
			if _eligible(owner, ambient_target, NEAR_RANGE + 0.25, true) and _clear_line(owner, ambient_target):
				_visible_target = ambient_target
			else:
				ambient_target = null
				var candidates: Array[Dictionary] = []
				for node: Node in owner.get_tree().get_nodes_in_group("village_people"):
					var person := node as Node3D
					if not _eligible(owner, person, NEAR_RANGE, true) or (_cooldown > 0.0 and person == _last_ambient):
						continue
					var offset := person.global_position - owner.global_position
					var front := (-owner.global_basis.z.normalized()).dot(offset.normalized())
					# A close, visible hostile is a relevant threat; combat
					# clips still exclusively own the pose.
					var score := offset.length() + (1.0 - front) * 1.2
					if person.get("role") == "enemy":
						score -= 0.5
					candidates.append({"node": person, "score": score})
				candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) < float(b.score))
				for i in mini(3, candidates.size()):
					var candidate := candidates[i].node as Node3D
					if _clear_line(owner, candidate):
						ambient_target = candidate
						_visible_target = candidate
						_dwell = 1.4
						break
	var limit := DIALOG_RANGE if explicit else NEAR_RANGE + 0.25
	if _eligible(owner, _visible_target, limit, not explicit):
		_point = _visible_target.call("gaze_anchor")
	else:
		_visible_target = null
		_point = Vector3.INF
