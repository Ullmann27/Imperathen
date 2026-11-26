extends RefCounted
## Transient city projection borrowing the exact bodies from the detached
## village. City coordinates never overwrite the campaign's village anchors.
const Party = preload("res://scripts/domain/travel_party.gd")
const Follow = preload("res://scripts/story/companion_follow.gd")
var passengers: Array[CharacterBody3D] = []
var returning := {}
var walkers := {}


func _arrival(city: Node3D, player: CharacterBody3D, body: CharacterBody3D, slot: int) -> Variant:
	var space := city.get_world_3d().direct_space_state
	var capsule := body.get_node_or_null("PersonalSpace") as CollisionShape3D
	if capsule == null:
		for node: Node in body.get_children():
			if node is CollisionShape3D:
				capsule = node
				break
	if capsule == null:
		return null
	for attempt in 16:
		var ring := 1.4 + 0.7 * floori(float(attempt) / 8.0)
		var offset := Vector3.BACK.rotated(Vector3.UP, (slot * 3 + attempt) * TAU / 8.0) * ring
		var at := player.position + offset
		var cast := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.55, at + Vector3.DOWN * 1.55, 1)
		var hit := space.intersect_ray(cast)
		if hit.is_empty() or hit.normal.y < 0.75 or absf(hit.position.y - player.position.y + 0.9) > 0.5:
			continue
		var feet: Vector3 = hit.position + Vector3.UP * 0.025
		var fit := PhysicsShapeQueryParameters3D.new()
		fit.collision_mask = 3
		fit.shape = capsule.shape
		fit.transform.origin = feet + capsule.position
		if space.intersect_shape(fit, 1).is_empty():
			return feet
	return null


func advance(city: Node3D, player: CharacterBody3D, data: Dictionary, delta: float) -> void:
	for slot in passengers.size():
		var body := passengers[slot]
		var uid: String = body.get_meta("actor_uid")
		var member: Dictionary = data.world_state.party.members.get(uid, {})
		var resident := Party.resident(data, uid)
		if not resident.get("alive", true):
			if walkers.has(body):
				body.hide()
				body.collision_layer = 0
				walkers[body].pause(body)
			continue
		if int(resident.get("health", 100)) <= 30 or member.get("status", "") != "active" or member.get("order", "") not in ["follow", "assist"]:
			if walkers.has(body):
				walkers[body].pause(body)
				body.get_node("Figure").drive(0.0)
			continue
		if not walkers.has(body):
			var at: Variant = _arrival(city, player, body, slot)
			if at == null:
				continue
			returning[body] = {"parent":body.get_parent(), "transform":body.transform,
				"layer":body.collision_layer, "mask":body.collision_mask}
			body.reparent(city, false)
			body.position = at
			body.reset_physics_interpolation()
			body.collision_layer = 2
			body.collision_mask = 3
			body.velocity = Vector3.ZERO
			walkers[body] = Follow.new()
		var walker: Follow = walkers[body]
		var target := player.global_position
		var gap := Vector2(body.position.x - target.x, body.position.z - target.z).length()
		walker.move(body, target, delta, 4.1 if gap > 5.0 else 2.3, 1.5 + 0.8 * slot)
		body.get_node("Figure").drive(walker.actual_speed)


func pause() -> void:
	for body: CharacterBody3D in walkers:
		walkers[body].pause(body)
		body.get_node("Figure").drive(0.0)


func return_to_village() -> void:
	for body: CharacterBody3D in returning:
		var anchor: Dictionary = returning[body]
		body.reparent(anchor.parent, false)
		body.transform = anchor.transform
		body.collision_layer = anchor.layer
		body.collision_mask = anchor.mask
		body.velocity = Vector3.ZERO
		body.reset_physics_interpolation()
		body.get_node("Figure").drive(0.0)
	passengers.clear()
	returning.clear()
	walkers.clear()
