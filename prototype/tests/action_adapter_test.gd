extends SceneTree
## Short real-scene regressions for the combat authority/presentation boundary.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const WorldScene = preload("res://scripts/world/game_world.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")
var model = WorldModel.new()
var world = WorldScene.new()
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.add_child(world)
	world.set_physics_process(false)
	world.action_requested.connect(_on_action)
	_reset()
	await physics_frame
	await _test_camera_interrupts()
	await _test_dodge_authority_interrupt()
	_test_damage_pose_priority()
	_test_air_contact()
	await _test_participant_identity()
	_test_legacy_collision_reset()
	world.free()
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("ACTION_ADAPTER_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("ACTION_ADAPTER_PASS" if failures.is_empty() else "ACTION_ADAPTER_FAIL")
	quit(0 if failures.is_empty() else 1)


func _reset() -> void:
	model.new_game("italia", true, false, true)
	world.setup(model.data)
	world.set_active(true)
	model.combat_sight_check = world.combat_sight_clear
	model.combat_motion_check = world.combat_safe_motion


func _on_action(command: String, payload: Dictionary) -> void:
	if command == "combat_interrupt":
		model.interrupt_combat()
	elif Combat.COMMAND_FIELDS.has(command):
		var result: Dictionary = model.execute(command, payload)
		_check(result.ok, "World action is accepted by the model: " + command)


func _attack() -> void:
	var result: Dictionary = model.execute("village_unarmed_attack", {
		"technique":"jab_left", "target_id":"air", "facing_x":0.0, "facing_z":-1.0,
	})
	_check(result.ok, "Real attack command starts the presentation fixture")
	world.sync_combat_state(model.data)
	_check(world._figure.clip == "jab_left", "Pending authority drives the selected technique on the actual figure")


func _test_camera_interrupts() -> void:
	for mode: String in ["city", "map"]:
		_reset()
		_check(model.execute("village_unarmed_dodge", {}).ok, mode + ": dodge starts")
		world.sync_combat_state(model.data)
		_check(Combat.busy(model.data) and world._dodge_remaining > 0.0, mode + ": defense owns a real pending movement")
		world.set_mode(mode)
		_check(not Combat.busy(model.data), mode + ": camera change interrupts authority")
		_check(world._dodge_remaining == 0.0, mode + ": camera change removes queued physical dodge")
		_check(model.data.village.unarmed.stamina == 84.0, mode + ": interruption does not refund paid stamina")
		world.set_mode("person")
		var before: Vector3 = world.get_player_position()
		for frame in 3:
			await physics_frame
			world._physics_process(1.0 / 60.0)
		var after: Vector3 = world.get_player_position()
		_check(Vector2(before.x, before.z).distance_to(Vector2(after.x, after.z)) < 0.001, mode + ": returning to person cannot resume phantom dodge")


func _test_dodge_authority_interrupt() -> void:
	_reset()
	_check(model.execute("village_unarmed_dodge", {}).ok, "Dodge interruption fixture starts through authority")
	world.sync_combat_state(model.data)
	_check(world._dodge_remaining > 0.0, "An accepted dodge starts real physical motion")
	model.interrupt_combat()
	world.sync_combat_state(model.data)
	_check(not Combat.busy(model.data) and world._dodge_remaining == 0.0, "Domain interruption also cancels remaining physical dodge time")
	var before: Vector3 = world.get_player_position()
	for frame in 4:
		await physics_frame
		world._physics_process(1.0 / 60.0)
	var after: Vector3 = world.get_player_position()
	_check(Vector2(before.x, before.z).distance_to(Vector2(after.x, after.z)) < 0.001, "An interrupted dodge cannot continue moving the player")
	_check(model.execute("village_unarmed_dodge", {}).ok, "Second accepted dodge prepares reset regression")
	world.sync_combat_state(model.data)
	_check(world._dodge_remaining > 0.0, "Reset regression owns unfinished physical dodge time")
	_reset()
	_check(world._dodge_remaining == 0.0 and not Combat.busy(model.data), "A fresh world setup cannot inherit old physical dodge time")


func _test_damage_pose_priority() -> void:
	for event: String in ["hit", "death"]:
		_reset()
		_attack()
		model.interrupt_combat()
		# A health snapshot tests the real sync_state cue order without inventing
		# an encounter or taking a long gameplay route just to exercise the view.
		var snapshot: Dictionary = model.data.duplicate(true)
		snapshot.player.health = 0 if event == "death" else 97
		snapshot.village.health_delta = int(snapshot.player.health) - 100
		world.sync_state(snapshot)
		_check(world._figure.clip == event, event + ": interrupted attack cannot overwrite the health cue during sync")
		world._actions.reset()
		_check(world._figure.clip == event, event + ": adapter reset preserves damage animation")
		world.set_active(false)
		_check(world._figure.clip == event, event + ": pausing preserves damage animation")
		_reset()
		_attack()
		world._figure.cue(event)
		world.set_active(false)
		_check(world._figure.clip == event, event + ": direct pause reset preserves damage over its previously owned attack")
	_reset()
	_attack()
	world._actions.reset()
	_check(world._figure.clip == "idle", "Reset still cancels an ordinary owned attack pose")
	world._figure.cue("work")
	world._actions.reset()
	_check(world._figure.clip == "work", "Adapter without an owned combat pose preserves unrelated work")


func _test_air_contact() -> void:
	_reset()
	world.perform_attack("jab_left")
	_check(model.data.village.unarmed.target_id == "air", "Real target selection chooses air away from targets")
	_check(model.data.village.unarmed.practice_hits == 0 and model.data.village.unarmed.resolved_hits == 0, "Air button press awards no contact")
	world.sync_combat_state(model.data)
	model.advance(0.25)
	world.sync_combat_state(model.data)
	_check(model.data.village.unarmed.practice_hits == 0 and model.data.village.unarmed.resolved_hits == 0, "An active air strike awards neither practice nor damage")
	model.advance(0.6)
	world.sync_combat_state(model.data)
	_check(not Combat.busy(model.data) and world._figure.clip == "idle", "Air strike completes recovery and releases its pose")


func _test_participant_identity() -> void:
	_reset()
	var target: Node3D = world.village_life_world.actors["aelia"]
	var bystander: Node3D = world.village_life_world.actors["varro"]
	target.visible = true
	bystander.visible = true
	world._actions.sync_personal_space()
	# Both residents are within the endpoint tolerance. Only the exact target
	# may be excluded; the closer-to-source third person remains an obstruction.
	target.global_position = Vector3(100.0, 0.0, 100.0)
	bystander.global_position = Vector3(100.0, 0.0, 99.8)
	world._player.global_position = Vector3(100.0, 1.0, 98.5)
	var target_body := target as CollisionObject3D
	var bystander_body := bystander as CollisionObject3D
	_check(target_body != null and bystander_body != null, "Resident identity uses the native civilian collision bodies")
	var children_before := target.get_child_count()
	for repeat in 12:
		world._actions.sync_personal_space()
	_check(target.get_child_count() == children_before, "Repeated sync does not add duplicate bodies beside the native PersonalSpace shape")
	await physics_frame
	var excluded: Array[RID] = world._actions._bodies_at(Vector2(100.0, 100.0))
	_check(excluded.has(target_body.get_rid()), "Contact excludes the intended target body")
	_check(not excluded.has(bystander_body.get_rid()), "Contact does not exempt a nearby third person")
	_check(not world.combat_sight_clear(Vector2(100.0, 98.5), Vector2(100.0, 100.0)), "Real physics ray is blocked by the nearby third person")
	bystander_body.collision_layer = 0
	world._actions.sync_personal_space()
	_check(bystander_body.collision_layer == 0, "Combat sync preserves a native civilian body disabled by its owner")
	await physics_frame
	_check(world.combat_sight_clear(Vector2(100.0, 98.5), Vector2(100.0, 100.0)), "Removing only the third-person obstruction restores the ray")


func _test_legacy_collision_reset() -> void:
	_reset()
	_check(world._actions._personal_bodies.size() > 0 and world._player.collision_mask == 13, "New mode creates actual personal space and player collision mask")
	model.new_game("italia", true)
	world.setup(model.data)
	_check(not Combat.enabled(model.data) and world._player.collision_mask == 9, "Legacy village keeps native civilians and removes only optional combat colliders")
	_check(_all_personal_space_disabled(), "Legacy village disables every previously created personal-space body")
	model.new_game("germania", true, true)
	world.setup(model.data)
	_check(not Combat.enabled(model.data) and world._player.collision_mask == 9, "A different origin retains the shared civilian collision mask without enabling combat")
	_check(_all_personal_space_disabled(), "A different origin cannot inherit stale personal-space collisions")


func _all_personal_space_disabled() -> bool:
	for body: StaticBody3D in world._actions._personal_bodies:
		if is_instance_valid(body) and body.collision_layer != 0:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
