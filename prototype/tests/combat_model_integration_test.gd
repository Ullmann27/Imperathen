extends SceneTree

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")
const Life = preload("res://scripts/story/village_life.gd")
var checks := 0
var failures: Array[String] = []
var directory := "user://combat_model_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	_test_practice_commands_and_persistence()
	_test_contradictory_mode_rejected()
	_test_clock_partition()
	_test_health_interruption_and_defense()
	_test_raid_finish_and_adult_training()
	_cleanup()
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("COMBAT_MODEL_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("COMBAT_MODEL_PASS" if failures.is_empty() else "COMBAT_MODEL_FAIL")
	quit(0 if failures.is_empty() else 1)


func _clear(_from: Vector2, _to: Vector2) -> bool:
	return true


func _stationary(from: Vector2, _to: Vector2) -> Vector2:
	return from


func _connect_geometry(model) -> void:
	# Domain tests deliberately provide deterministic geometry. Actual physics
	# rays and collision sweeps are covered by the separate world-scene test.
	model.combat_sight_check = _clear
	model.combat_motion_check = _stationary


func _new():
	var model = WorldModel.new()
	model.new_game("italia", true, true)
	_connect_geometry(model)
	_check(Combat.enabled(model.data), "New opted-in village uses action combat")
	_valid(model, "Initial action-combat world")
	return model


func _attack(model, target := "practice", technique := "jab_left", command_id := "") -> Dictionary:
	return model.execute("village_unarmed_attack", {"technique":technique, "target_id":target, "facing_x":0.0, "facing_z":-1.0}, command_id)


func _valid(model, label: String) -> void:
	var error: String = model._validate_state(model.data)
	_check(error.is_empty(), label + ": " + error)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _ok(result: Dictionary, label: String) -> void:
	_check(result.get("ok", false), label + ": " + str(result.get("message", "")))


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	return directory.path_join(name + ".json")


func _test_practice_commands_and_persistence() -> void:
	var model = _new()
	model.set_player_position(Vector3(0.0, 1.0, -6.0))
	var accepted := _attack(model, "practice", "jab_left", "practice-one")
	_ok(accepted, "Practice starts through WorldModel.execute")
	var before := JSON.stringify(model.data)
	_check(model.execute("village_unarmed_attack", {"technique":"jab_left", "target_id":"practice", "facing_x":0.0, "facing_z":-1.0}, "practice-one") == accepted, "Transport replay returns the existing accepted motion")
	_check(JSON.stringify(model.data) == before, "Replay cannot charge stamina twice")
	model.advance(0.1)
	_valid(model, "World after preparation tick")
	_check(model.data.village.unarmed.practice_hits == 0, "World button press and windup grant no practice")
	_ok(model.save_game(_path("windup")), "Real save during windup")
	var loaded = WorldModel.new()
	_ok(loaded.load_game(_path("windup")), "Real load of optional combat v1 state")
	_connect_geometry(loaded)
	loaded.advance(0.1)
	_check(loaded.data.village.unarmed.practice_hits == 1, "Loaded windup resolves a later real practice contact")
	_check(loaded.data.player.age == 12 and loaded.data.progress.training_hits == 0, "Child practice cannot grant adulthood or mandatory adult credits")
	_valid(loaded, "World after practice contact")
	_ok(loaded.save_game(_path("after-contact")), "Real save after resolved contact")
	var resumed = WorldModel.new()
	_ok(resumed.load_game(_path("after-contact")), "Real load after resolved contact")
	_connect_geometry(resumed)
	resumed.advance(0.5)
	_check(resumed.data.village.unarmed.practice_hits == 1, "Resume cannot repeat a contact already saved as resolved")
	before = JSON.stringify(resumed.data)
	_ok(resumed.execute("village_unarmed_attack", {"technique":"jab_left", "target_id":"practice", "facing_x":0.0, "facing_z":-1.0}, "practice-one"), "Original command replay survives save and load")
	_check(JSON.stringify(resumed.data) == before, "Persisted command identity does not begin another strike")
	for command: String in ["training_hit", "village_block", "village_dodge"]:
		before = JSON.stringify(resumed.data)
		_check(not resumed.execute(command, {}).ok and JSON.stringify(resumed.data) == before, "Old immediate path is unavailable in action mode: " + command)
	for command: String in ["strike_enemy", "village_strike"]:
		before = JSON.stringify(resumed.data)
		_check(not resumed.execute(command, {"enemy_id":"unknown"}).ok and JSON.stringify(resumed.data) == before, "Old direct damage command cannot bypass the window: " + command)
	_ok(_attack(resumed), "Second practice motion starts")
	resumed.advance(0.1)
	resumed.interrupt_combat()
	resumed.advance(0.8)
	_check(resumed.data.village.unarmed.practice_hits == 1 and not Combat.busy(resumed.data), "Pause API cancels the pending contact")
	_valid(resumed, "Interrupted world remains saveable")
	var legacy = WorldModel.new()
	legacy.new_game("italia", true)
	_check(not Combat.enabled(legacy.data), "Existing two-argument new-game contract retains its old mode")
	_ok(legacy.save_game(_path("legacy")), "Legacy village can still save")
	_ok(resumed.load_game(_path("legacy")), "Action-capable model can load a legacy village")
	_check(not Combat.enabled(resumed.data), "Loading legacy state does not invent pending combat")


func _test_contradictory_mode_rejected() -> void:
	var model = WorldModel.new()
	model.new_game("italia", true, true)
	model.data.village.enabled = false
	_check(not model._validate_state(model.data).is_empty(), "Unarmed state cannot coexist with a disabled village")
	var before := JSON.stringify(model.data)
	_check(not _attack(model).ok and JSON.stringify(model.data) == before, "Contradictory combat mode cannot accept a command or change state")
	var path := _path("contradictory-mode")
	_check(not model.save_game(path).ok and not FileAccess.file_exists(path), "Contradictory combat mode cannot become a saved softlock")


func _test_clock_partition() -> void:
	var fine = _new()
	var coarse = _new()
	fine.set_player_position(Vector3(0.0, 1.0, -6.0))
	coarse.set_player_position(Vector3(0.0, 1.0, -6.0))
	_ok(_attack(fine), "Fine-step practice starts")
	_ok(_attack(coarse), "Coarse-step practice starts")
	for frame in 62:
		fine.advance(0.01)
	coarse.advance(0.62)
	_valid(fine, "Fine frame partition")
	_valid(coarse, "Coarse frame partition")
	_check(fine.data.village.unarmed.practice_hits == 1 and coarse.data.village.unarmed.practice_hits == 1, "Fine and coarse world steps book one practice contact")
	_check(is_equal_approx(fine.data.village.unarmed.stamina, coarse.data.village.unarmed.stamina), "World step partition preserves stamina accounting")
	_check(fine.data.village.economy.ledger == coarse.data.village.economy.ledger, "Combat does not disturb economic conservation")


func _settled():
	var model = _new()
	model.set_player_position(Vector3(-8.0, 1.0, 2.0))
	for index in 3:
		_ok(model.execute("gather", {"node_id":"timber_0"}), "Collect genuine home materials")
	model.set_player_position(Vector3(-3.0, 1.0, 4.0))
	_ok(model.execute("choose_companion", {"choice":"help"}), "Retain the real companion choice")
	model.set_player_position(Vector3(8.0, 1.0, 5.0))
	_ok(model.execute("build", {"x":8.0, "z":5.0}), "Pay for the actual home")
	model.advance(12.0)
	_check(model.data.buildings[0].completed, "Nearby work finishes the home")
	for id: String in ["decimus", "aelia", "varro"]:
		var at: Vector2 = Life.actor_position(model.data, id)
		model.set_player_position(Vector3(at.x, 1.0, at.y))
		_ok(model.execute("village_talk", {"npc_id":id, "choice":"meet"}), "Meet an actual villager: " + id)
	model.set_player_position(Vector3(50.0, 1.0, 50.0))
	_valid(model, "Settled action-combat village")
	return model


func _active_raid():
	var model = _settled()
	model.advance(Life.FIRST_WARNING - float(model.data.village.social.seconds))
	_check(model.data.village.raid.status == "warning", "Required history starts a real raid warning")
	model.advance(Life.WARNING_SECONDS)
	_check(model.data.village.raid.active and model.data.village.raid.enemies.size() == 3, "Real elapsed warning spawns the raid roster")
	_valid(model, "Active raid before combat")
	return model


func _test_health_interruption_and_defense() -> void:
	var model = _active_raid()
	var enemy: Dictionary = model.data.village.raid.enemies[0]
	var id: String = enemy.id
	model.set_player_position(Vector3(enemy.x, 1.0, float(enemy.z) + 0.7))
	model.advance(0.8)
	var old_health: int = model.data.player.health
	_ok(_attack(model, id), "Begin a strike just before the real enemy hit")
	model.advance(0.2)
	_check(model.data.player.health < old_health, "A timed nearby enemy hit changes actual health")
	_check(model.data.village.unarmed.resolved_hits == 0 and not Combat.busy(model.data), "Receiving damage interrupts before pending attack contact")
	_check(model.data.village.health_delta == int(model.data.player.health) - 100 and model.data.encounter.damage_taken == 0, "Village damage preserves health ledger separately from legacy battles")
	_valid(model, "Health interruption transaction")
	model.advance(1.2)
	_ok(model.execute("village_unarmed_guard", {}), "Real unarmed guard starts")
	var blocks: int = model.data.village.raid.blocks
	old_health = model.data.player.health
	_check(blocks == 0, "Guard press alone does not award a successful block")
	model.advance(0.7)
	_check(model.data.village.raid.blocks == blocks + 1 and model.data.player.health == old_health, "Guard earns credit only by intercepting the actual next enemy hit")
	model.interrupt_combat()
	_check(model.data.village.raid.block_window == 0.0 and model.data.village.raid.dodge_window == 0.0, "Interrupt clears actual protection windows")
	_valid(model, "Defense transaction")


func _test_raid_finish_and_adult_training() -> void:
	var model = _active_raid()
	var attempts := 0
	while model.data.village.raid.active and attempts < 30:
		var target: Dictionary = {}
		for enemy: Dictionary in model.data.village.raid.enemies:
			if int(enemy.health) > 0:
				target = enemy.duplicate()
				break
		if target.is_empty():
			break
		model.set_player_position(Vector3(target.x, 1.0, float(target.z) + 0.7))
		var hits_before: int = model.data.village.unarmed.resolved_hits
		var result := _attack(model, target.id)
		_ok(result, "Actual raid attack begins")
		if not result.ok:
			break
		_check(model.data.village.unarmed.resolved_hits == hits_before, "Raid button press itself cannot book success")
		model.advance(0.25)
		_check(model.data.village.unarmed.resolved_hits == hits_before + 1, "Raid contact is accepted by the original life authority")
		model.set_player_position(Vector3(50.0, 1.0, 50.0))
		model.advance(1.0)
		_valid(model, "Raid hit and recovery")
		attempts += 1
	_check(not model.data.village.raid.active and model.data.village.raid.outcome == "defended", "Defeating actual enemies resolves the raid")
	_check(model.data.village.raid.completed == 1 and model.data.village.raid.won == 1, "Raid completion is booked exactly once")
	_check(model.data.village.raid.player_hits == model.data.village.unarmed.resolved_hits and model.data.village.raid.player_hits > 0, "New combat and original raid counters agree on actual hits")
	model.advance(1.0)
	_check(model.data.village.raid.completed == 1, "Further simulation cannot repeat raid completion")
	_ok(model.save_game(_path("raid-finished")), "Completed action-combat raid saves")
	var loaded = WorldModel.new()
	_ok(loaded.load_game(_path("raid-finished")), "Completed action-combat raid loads")
	_connect_geometry(loaded)
	_check(loaded.data.village.raid.won == 1 and loaded.data.village.unarmed.resolved_hits == model.data.village.unarmed.resolved_hits, "Combat proof and raid outcome survive the same save")
	loaded.set_player_position(Vector3(0.0, 1.0, -6.0))
	loaded.advance(maxf(0.0, 240.0 - float(loaded.data.village.social.seconds)))
	_ok(loaded.execute("train"), "Lived childhood and completed raid permit the real adult transition")
	_check(loaded.data.player.age == 18 and loaded.data.progress.stage == "training", "Adult training starts without fabricated completion")
	_check(not loaded.execute("training_hit", {}).ok, "Immediate old training command stays blocked for the adult")
	var prior_practice: int = loaded.data.village.unarmed.practice_hits
	for lesson in 3:
		_ok(_attack(loaded, "practice", "jab_left", "adult-lesson-%d" % lesson), "Adult starts a real practice motion")
		loaded.advance(0.7)
		_valid(loaded, "Adult practice contact")
	_check(loaded.data.village.unarmed.practice_hits == prior_practice + 3, "Adult contacts still count as real practice")
	_check(loaded.data.progress.training_complete and loaded.data.progress.training_hits == 3 and loaded.data.progress.stage == "trained", "Three real adult contacts complete mandatory training without an immediate-command bypass")
	_ok(loaded.save_game(_path("adult-complete")), "Completed real adult training saves")
	_exercise_legacy_damage(loaded)


func _exercise_legacy_damage(model) -> void:
	_ok(model.execute("recruit", {}), "Actual trained villager recruits one real person")
	_ok(model.execute("start_skirmish", {}), "Earned military encounter starts in the same action-combat career")
	if not model.data.encounter.active:
		return
	var target: Dictionary = model.data.encounter.enemies[0]
	model.set_player_position(Vector3(target.x, 1.0, float(target.z) + 0.7))
	var hits: int = model.data.village.unarmed.resolved_hits
	_ok(_attack(model, target.id), "Adult attack starts before a real incoming hit")
	var health: int = model.data.player.health
	_ok(model.execute("receive_damage", {"amount":3}), "Existing military damage path remains authoritative")
	_check(model.data.player.health == health - 3 and not Combat.busy(model.data), "Legacy incoming damage also interrupts a pending new attack")
	model.advance(0.7)
	_check(model.data.village.unarmed.resolved_hits == hits, "Legacy interrupted strike cannot land later")
	_valid(model, "Legacy damage and new action state")
	model.advance(1.3)
	_ok(model.execute("village_unarmed_guard", {}), "New guard is available in the earned adult encounter")
	health = model.data.player.health
	_ok(model.execute("receive_damage", {"amount":3}), "Actual legacy enemy contact meets guard")
	_check(model.data.player.health == health, "Unarmed guard protects against actual legacy encounter contact")
	_check(model.data.village.raid.block_window == 0.0, "A blocked legacy contact consumes its single protection window")
	model.advance(1.3)
	_ok(model.execute("village_unarmed_dodge", {}), "New dodge is available in the earned adult encounter")
	health = model.data.player.health
	_ok(model.execute("receive_damage", {"amount":3}), "Actual legacy enemy contact meets dodge")
	_check(model.data.player.health == health, "Timed dodge protects against actual legacy encounter contact")
	_check(model.data.village.raid.dodge_window == 0.0, "A dodged legacy contact consumes its single protection window")
	_valid(model, "Legacy defenses preserve every world ledger")
	model.advance(1.3)
	model.combat_sight_check = func(_from: Vector2, _to: Vector2) -> bool: return false
	var before := JSON.stringify(model.data)
	_check(not model.execute("receive_damage", {"amount":3}).ok and JSON.stringify(model.data) == before, "Legacy encounter also rejects incoming damage through an obstruction")


func _cleanup() -> void:
	var path := ProjectSettings.globalize_path(directory)
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
