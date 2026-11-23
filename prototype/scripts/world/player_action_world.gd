extends RefCounted
## Geometry adapter for the authoritative combat state. Never awards damage.

const Combat = preload("res://scripts/domain/combat_actions.gd")
const PEOPLE_LAYER := 4
const CIVILIAN_LAYER := 8
var world: Node3D
var state: Dictionary = {}
var selected := "jab_left"
var _last_technique := ""
var _guarding := false
var _dodging := false
var _body_shape := CapsuleShape3D.new()
var _personal_bodies: Array[StaticBody3D] = []


func _init(scene: Node3D) -> void:
	world = scene
	_body_shape.radius = 0.28
	_body_shape.height = 1.78


func sync(data: Dictionary) -> void:
	state = data
	if not Combat.enabled(data) or not world._active:
		return
	var combat: Dictionary = data.village.unarmed
	var technique := str(combat.technique)
	if not technique.is_empty():
		world._figure.sample_combat(technique, float(combat.elapsed) / float(Combat.TECHNIQUES[technique].duration))
	elif not _last_technique.is_empty():
		if world._figure.clip not in ["hit", "death"]:
			world._figure.cancel_action()
	_last_technique = technique
	var guarding := float(combat.guard_remaining) > 0.0
	var dodging := float(combat.dodge_remaining) > 0.0
	if guarding and not _guarding:
		world._figure.cue("block")
	if dodging and not _dodging:
		world.cue_village_defense("village_dodge")
	if _dodging and not dodging:
		world._dodge_remaining = 0.0
	_guarding = guarding
	_dodging = dodging
	world._figure.set_equipment(false, false)
	world._training_label.text = "Übungsplatz\nKontrollierte Treffer: %d" % int(combat.practice_hits)


func reset() -> void:
	world._dodge_remaining = 0.0
	var owns_pose := not _last_technique.is_empty() or _guarding or _dodging
	_last_technique = ""
	_guarding = false
	_dodging = false
	if world._figure != null and owns_pose and world._figure.clip not in ["hit", "death"]:
		world._figure.cancel_action()


func attack() -> void:
	if not Combat.enabled(state) or not Combat.TECHNIQUES.has(selected):
		return
	var direction := Vector3.FORWARD.rotated(Vector3.UP, world._figure.rotation.y)
	var facing := Vector2(direction.x, direction.z).normalized()
	var source := Vector2(world._player.position.x, world._player.position.z)
	var spec: Dictionary = Combat.TECHNIQUES[selected]
	var closest := float(spec.reach) + 0.3
	var target_id := "air"
	var targets: Array = []
	if bool(state.village.raid.active):
		targets.append_array(state.village.raid.enemies)
	if bool(state.encounter.active):
		targets.append_array(state.encounter.enemies)
	for enemy: Dictionary in targets:
		var offset := Vector2(float(enemy.x), float(enemy.z)) - source
		if int(enemy.health) > 0 and offset.length() > 0.05 and offset.length() < closest and facing.dot(offset.normalized()) >= float(spec.arc_dot):
			closest = offset.length()
			target_id = str(enemy.id)
	var practice := Combat.PRACTICE_POINT - source
	if target_id == "air" and practice.length() > 0.05 and practice.length() <= float(spec.reach) + 0.3 and facing.dot(practice.normalized()) >= float(spec.arc_dot):
		target_id = "practice"
	world.action_requested.emit("village_unarmed_attack", {"technique":selected, "target_id":target_id, "facing_x":facing.x, "facing_z":facing.y})


func sight_clear(from: Vector2, to: Vector2) -> bool:
	if not world.is_inside_tree() or not from.is_finite() or not to.is_finite():
		return false
	var height: float = float(world._player.global_position.y) + 0.15
	var query := PhysicsRayQueryParameters3D.create(Vector3(from.x, height, from.y), Vector3(to.x, height, to.y), 1 | 2 | PEOPLE_LAYER | CIVILIAN_LAYER)
	# Exclude the two participating bodies by identity/location, never the wall
	# near a target. Other residents still obstruct the line of contact.
	var excluded: Array[RID] = _bodies_at(from)
	for rid: RID in _bodies_at(to):
		if not excluded.has(rid):
			excluded.append(rid)
	query.exclude = excluded
	query.hit_from_inside = true
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func safe_actor_motion(from: Vector2, to: Vector2) -> Vector2:
	if not world.is_inside_tree() or not from.is_finite() or not to.is_finite():
		return from
	var motion := Vector3(to.x - from.x, 0, to.y - from.y)
	if motion.length_squared() < 0.00000001:
		return from
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _body_shape
	query.transform = Transform3D(Basis.IDENTITY, Vector3(from.x, 0.92, from.y))
	query.motion = motion
	query.margin = 0.015
	query.collision_mask = 1 | 2 | PEOPLE_LAYER | CIVILIAN_LAYER
	query.exclude = _bodies_at(from)
	var result := world.get_world_3d().direct_space_state.cast_motion(query)
	return from + Vector2(motion.x, motion.z) * maxf(0.0, float(result[0]) - 0.01) if result.size() == 2 else from


func sync_personal_space() -> void:
	var enabled := Combat.enabled(state)
	world._player.collision_mask = (1 | PEOPLE_LAYER | CIVILIAN_LAYER) if enabled else (1 | CIVILIAN_LAYER)
	for index in range(_personal_bodies.size() - 1, -1, -1):
		var body := _personal_bodies[index]
		if not is_instance_valid(body):
			_personal_bodies.remove_at(index)
			continue
		body.collision_layer = PEOPLE_LAYER if enabled and body.is_visible_in_tree() else 0
	if not enabled:
		return
	for actor: Node3D in world.population.actors.values():
		_ensure_body(actor, 0.9)
	for actor: Node3D in world.village_life_world.actors.values():
		_ensure_body(actor, 0.9)
	_ensure_body(world._companion, 0.0)
	var mentor := world.get_node_or_null("TrainingGround/Mentor") as Node3D
	if mentor != null:
		_ensure_body(mentor, 0.0)


func _ensure_body(actor: Node3D, center_y: float) -> void:
	# Civilian actors already own their collision body and its life-state layer.
	# PersonalSpace on those actors is the shape, not a child StaticBody3D.
	if actor is CollisionObject3D:
		return
	var body := actor.get_node_or_null("PersonalSpace") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = "PersonalSpace"
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = _body_shape
		shape.position.y = center_y
		body.add_child(shape)
		actor.add_child(body)
		_personal_bodies.append(body)
	body.collision_layer = PEOPLE_LAYER if actor.is_visible_in_tree() else 0


func _bodies_at(point: Vector2) -> Array[RID]:
	var result: Array[RID] = []
	var nearest: Node3D = null
	var distance := 0.4
	var actors: Array = world._enemy_views.values()
	actors.append_array(world.village_life_world.raiders.values())
	actors.append_array(world.population.actors.values())
	actors.append_array(world.village_life_world.actors.values())
	actors.append(world._companion)
	actors.append(world._player)
	for actor: Node3D in actors:
		if not is_instance_valid(actor):
			continue
		var next_distance := Vector2(actor.global_position.x, actor.global_position.z).distance_to(point)
		if next_distance < distance:
			distance = next_distance
			nearest = actor
	# Only one participating person per endpoint is exempted. A third nearby
	# resident must remain an obstacle, even when authored routes overlap.
	if nearest != null:
		if nearest is CollisionObject3D:
			result.append((nearest as CollisionObject3D).get_rid())
		for child: Node in nearest.find_children("*", "CollisionObject3D", true, false):
			result.append((child as CollisionObject3D).get_rid())
	if point.distance_to(Combat.PRACTICE_POINT) < 0.01:
		for child: Node in world.get_node("TrainingGround").find_children("*", "CollisionObject3D", true, false):
			# The post itself is the legal practice target, not the nearby mentor.
			if child.name != "PersonalSpace":
				result.append((child as CollisionObject3D).get_rid())
	return result
