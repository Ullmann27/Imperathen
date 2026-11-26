extends SceneTree

const Combat = preload("res://scripts/domain/combat_actions.gd")
const Tracks = preload("res://scripts/domain/melee/melee_tracks.gd")
const Geo = preload("res://scripts/domain/melee/melee_geometry.gd")
const RAIDER_RADIUS := 0.2046
const RAIDER_HEIGHT := 1.7045
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_attack_is_timed()
	_test_contact_conditions()
	_test_window_and_frame_steps()
	_test_practice_and_unlocks()
	_test_every_technique()
	_test_service_equipment()
	_test_save_resume()
	_test_interruptions()
	_test_stamina_and_defense()
	_test_rejected_commands_are_atomic()
	_test_state_validation()
	_test_legacy_and_presentation()
	_test_measured_contact_frames()
	_test_catalogue_matches_measurement()
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("COMBAT_ACTIONS_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("COMBAT_ACTIONS_PASS" if failures.is_empty() else "COMBAT_ACTIONS_FAIL")
	quit(0 if failures.is_empty() else 1)


func _fixture() -> Dictionary:
	var data := {
		"player":{"position":[0.0, 1.0, 0.0], "health":100, "age":12},
		"progress":{"career_terminal":false, "training_hits":0, "training_complete":false},
		"village":{"enabled":true, "raid":{"active":true, "enemies":[{"id":"raider", "x":0.0, "z":-0.7, "health":45}], "block_window":0.0, "dodge_window":0.0, "player_hits":0, "blocks":0, "dodges":0}},
		"encounter":{"active":false, "enemies":[]},
		"hit_calls":[]
	}
	Combat.start(data)
	return data


func _attack(data: Dictionary, technique := "jab_left", target_id := "raider", facing := Vector2(0.0, -1.0)) -> Dictionary:
	return Combat.execute(data, "village_unarmed_attack", {"technique":technique, "target_id":target_id, "facing_x":facing.x, "facing_z":facing.y})


func _clear(_from: Vector2, _to: Vector2) -> bool:
	return true


func _blocked(_from: Vector2, _to: Vector2) -> bool:
	return false


func _bad_sight(_from: Vector2, _to: Vector2) -> String:
	return "yes"


func _apply_hit(data: Dictionary, id: String, damage: int) -> bool:
	for encounter: Dictionary in [data.village.raid, data.encounter]:
		if not encounter.active:
			continue
		for enemy: Dictionary in encounter.enemies:
			if enemy.id == id and int(enemy.health) > 0:
				enemy.health = maxi(0, int(enemy.health) - damage)
				data.hit_calls.append({"id":id, "damage":damage})
				return true
	return false


func _reject_hit(_data: Dictionary, _id: String, _damage: int) -> bool:
	return false


func _step(data: Dictionary, delta: float) -> Dictionary:
	return Combat.advance(data, delta, _clear, _apply_hit)


func _snapshot(data: Dictionary) -> String:
	return JSON.stringify(data)


func _test_attack_is_timed() -> void:
	var data := _fixture()
	_check(_attack(data).ok, "A child can start the first unarmed straight")
	_check(data.village.raid.enemies[0].health == 45 and data.hit_calls.is_empty(), "Button press does not deal damage")
	_check(data.village.unarmed.stamina == 93.0, "Starting one motion pays its cost exactly once")
	_check(Combat.phase("jab_left", 0.0) == "windup", "Attack begins in preparation")
	var expected := _oracle_frame("jab_left", 1.0, Vector2.ZERO, 0.0, Vector2(0.0, -0.7), RAIDER_RADIUS, RAIDER_HEIGHT)
	_check(expected == 13, "Measured jab reaches a 0.7 m raider on clip frame 13 (oracle %d)" % expected)
	_step(data, (expected - 1) / 60.0 + 0.001)
	_check(data.hit_calls.is_empty(), "No damage before the frame the displayed fist touches the body")
	var contact := _step(data, 1.0 / 60.0)
	_check(contact.hit and data.village.raid.enemies[0].health == 39, "Damage is booked by callback during active window")
	_check(int(contact.get("contact_frame", -1)) == expected, "Hit carries its exact contact frame")
	_check(data.village.unarmed.resolved_hits == 1 and data.village.unarmed.resolved, "One actual accepted hit resolves the strike")
	_step(data, 0.1)
	_step(data, 0.1)
	_check(data.hit_calls.size() == 1 and Combat.phase("jab_left", data.village.unarmed.elapsed) == "recovery", "Later active and recovery samples do not repeat damage")
	var before := _snapshot(data)
	_check(not _attack(data).ok and _snapshot(data) == before, "Recovery rejects another button press atomically")
	_step(data, 0.24)
	_check(not Combat.busy(data) and data.village.unarmed.technique == "", "Recovery ends in a clean idle state")
	_check(Combat.validate(data).is_empty(), "Completed strike preserves valid v1 state")


func _test_contact_conditions() -> void:
	for condition: String in ["range", "behind", "overlap", "dead", "finished", "wall", "missing_geometry", "bad_geometry", "missing_authority"]:
		var data := _fixture()
		_check(_attack(data).ok, "Start before contact changes: " + condition)
		match condition:
			"range": data.village.raid.enemies[0].z = -1.46
			"behind": data.village.raid.enemies[0].z = 0.7
			"overlap": data.village.raid.enemies[0].z = -0.01
			"dead": data.village.raid.enemies[0].health = 0
			"finished": data.village.raid.active = false
		var sight: Callable = _clear
		var hit: Callable = _apply_hit
		if condition == "wall": sight = _blocked
		if condition == "missing_geometry": sight = Callable()
		if condition == "bad_geometry": sight = _bad_sight
		if condition == "missing_authority": hit = Callable()
		Combat.advance(data, 0.4, sight, hit)
		_check(data.hit_calls.is_empty() and data.village.unarmed.resolved_hits == 0, "No fictitious hit for " + condition)
		_check(data.village.unarmed.practice_hits == 0, "A combat miss grants no practice for " + condition)
	var rejected := _fixture()
	_attack(rejected)
	Combat.advance(rejected, 0.25, _clear, _reject_hit)
	_step(rejected, 0.05)
	_check(rejected.hit_calls.is_empty() and rejected.village.unarmed.resolved_hits == 0, "Rejected world transaction does not grant a hit or retry the same contact")
	var diagonal := _fixture()
	diagonal.village.raid.enemies[0].x = 0.7
	diagonal.village.raid.enemies[0].z = 0.0
	_attack(diagonal)
	_step(diagonal, 0.4)
	_check(diagonal.hit_calls.is_empty(), "A straight cannot strike a perpendicular target")


func _test_window_and_frame_steps() -> void:
	var moving := _fixture()
	moving.village.raid.enemies[0].z = -2.0
	_attack(moving)
	_step(moving, 0.2)
	_check(moving.hit_calls.is_empty() and not moving.village.unarmed.resolved, "Early active miss leaves contact window open")
	moving.village.raid.enemies[0].z = -0.68
	_step(moving, 0.04)
	_check(moving.hit_calls.size() == 1, "A target entering during the active window can be contacted once")
	var late := _fixture()
	late.village.raid.enemies[0].z = -2.0
	_attack(late)
	_step(late, 0.4)
	late.village.raid.enemies[0].z = -0.7
	_step(late, 0.1)
	_check(late.hit_calls.is_empty(), "A target entering during recovery cannot be hit")
	var coarse := _fixture()
	_attack(coarse)
	_step(coarse, 0.62)
	_check(coarse.hit_calls.size() == 1 and not Combat.busy(coarse), "A coarse tick crossing the active interval still resolves exactly once")
	var fine := _fixture()
	_attack(fine)
	for frame in 62:
		_step(fine, 0.01)
	_check(fine.hit_calls == coarse.hit_calls and fine.village.raid.enemies == coarse.village.raid.enemies, "Stationary contact agrees across fine and coarse time steps")
	_check(is_equal_approx(fine.village.unarmed.stamina, coarse.village.unarmed.stamina), "Busy-time stamina recovery is independent of tick partition")


func _test_practice_and_unlocks() -> void:
	var data := _fixture()
	data.player.position = [0.0, 1.0, -6.4]
	_check(not Combat.available(data, "hook_left"), "Hook begins locked until controlled practice")
	for attempt in 3:
		_check(_attack(data, "jab_left", "practice").ok, "Start controlled practice " + str(attempt))
		var result := _step(data, 0.62)
		_check(result.practice and not result.hit, "Practice event is separate from a combat hit")
	_check(data.village.unarmed.practice_hits == 3 and Combat.available(data, "hook_left"), "Three genuine practice contacts unlock the hook")
	_check(data.hit_calls.is_empty() and data.village.unarmed.resolved_hits == 0 and data.village.raid.player_hits == 0, "Practice never damages enemies or awards raid participation")
	_check(data.progress.training_hits == 0 and not data.progress.training_complete and data.player.age == 12, "Practice does not skip adult training or age the child")
	var air := _fixture()
	_attack(air, "jab_left", "air")
	_step(air, 0.8)
	_check(air.hit_calls.is_empty() and air.village.unarmed.practice_hits == 0, "Shadowboxing does not fabricate training progress")
	var far_post := _fixture()
	far_post.player.position = [0.0, 1.0, -6.0]
	_attack(far_post, "jab_left", "practice")
	_step(far_post, 0.62)
	_check(far_post.village.unarmed.practice_hits == 0, "A post 1 m away is beyond the displayed jab (0.52 m + 0.16 m post)")
	var wall := _fixture()
	wall.player.position = [0.0, 1.0, -6.4]
	_attack(wall, "jab_left", "practice")
	Combat.advance(wall, 0.62, _blocked, _apply_hit)
	_check(wall.village.unarmed.practice_hits == 0, "Practice cannot pass through a wall")


func _test_every_technique() -> void:
	var observed_damage := {}
	for id: String in Combat.TECHNIQUES:
		var data := _fixture()
		data.village.unarmed.practice_hits = 14
		if Combat.is_armed(id):
			_commission(data)
		var timing := Combat.measured(id)
		# Stand 2 cm inside the displayed peak, on the bearing of the strike.
		var target := _peak_target(id, 0.02)
		data.village.raid.enemies[0].x = target.x
		data.village.raid.enemies[0].z = target.y
		var scale := Combat.strike_scale(data, id)
		# Bracket: the sampled oracle with +-0.5 mm slack on the contact
		# distance gives the earliest and latest admissible frames.
		var loose := _oracle_frame(id, scale, Vector2.ZERO, 0.0, target, RAIDER_RADIUS, RAIDER_HEIGHT, 0.0005)
		var strict := _oracle_frame(id, scale, Vector2.ZERO, 0.0, target, RAIDER_RADIUS, RAIDER_HEIGHT, -0.0005)
		_check(loose >= int(timing.start) and strict <= int(timing.end) and loose <= strict, "Oracle finds a live contact frame: %s (%d..%d)" % [id, loose, strict])
		_check(_attack(data, id).ok, "Learned technique can start: " + id)
		var actual := -1
		for frame in range(1, int(timing.frames) + 1):
			var result := _step(data, 1.0 / 60.0)
			if not data.hit_calls.is_empty():
				actual = int(result.get("contact_frame", -1))
				_check(actual == frame, "%s: damage is booked on the frame it is computed" % id)
				break
		_check(actual >= loose and actual <= strict and actual >= int(timing.start), "Technique reaches a single contact on its measured frame: %s (oracle %d..%d, got %d)" % [id, loose, strict, actual])
		if not data.hit_calls.is_empty():
			observed_damage[id] = data.hit_calls[0].damage
		_step(data, float(Combat.TECHNIQUES[id].duration))
		_check(data.hit_calls.size() == 1 and not Combat.busy(data), "Technique recovers without repeating: " + id)
	_check(observed_damage.get("jab_left") == 6 and observed_damage.get("side_kick") == 12, "Different techniques have actual bounded damage differences")
	var short_reach := _fixture()
	short_reach.village.unarmed.practice_hits = 14
	var kick := _peak_target("side_kick", 0.02)
	short_reach.village.raid.enemies[0].x = kick.x
	short_reach.village.raid.enemies[0].z = kick.y
	_attack(short_reach, "headbutt")
	_step(short_reach, 0.76)
	_check(short_reach.hit_calls.is_empty(), "Headbutt cannot reach a kicking-distance target")
	_attack(short_reach, "side_kick")
	_step(short_reach, 1.2)
	_check(short_reach.hit_calls.size() == 1, "Sidekick can reach its distinct longer contact distance")


func _commission(data: Dictionary) -> void:
	data.player.age = 18
	data.player.role = "soldier"
	data.progress.training_complete = true
	data.progress.stage = "trained"


func _test_service_equipment() -> void:
	var data := _fixture()
	var before := _snapshot(data)
	_check(not Combat.available(data,"thrust"),"Child cannot receive a service sword")
	_check(not _attack(data,"thrust").ok and _snapshot(data)==before,"Rejected child sword attack is atomic")
	data.player.age = 18
	data.player.role = "trainee"
	_check(not Combat.available(data,"thrust"),"Age alone does not commission a soldier")
	_commission(data)
	_check(Combat.service_gear(data) and Combat.view(data).techniques.size()==15,"Completed adult training exposes five sword actions")
	data.village.raid.enemies[0].z = -1.4
	var expected := _oracle_frame("thrust", 1.0, Vector2.ZERO, 0.0, Vector2(0.0, -1.4), RAIDER_RADIUS, RAIDER_HEIGHT)
	_check(_attack(data,"thrust").ok,"Issued gladius uses existing action transaction")
	_step(data,(expected - 1) / 60.0 + 0.001)
	_check(data.hit_calls.is_empty(),"Sword windup cannot damage")
	_step(data,1.0 / 60.0)
	_check(data.hit_calls.size()==1 and data.hit_calls[0].damage==18,"Sword contact resolves on the displayed contact frame only (%d)" % expected)
	var restored: Dictionary = JSON.parse_string(JSON.stringify(data))
	_check(Combat.validate(restored).is_empty(),"Armed action fits the existing save schema")
	_step(restored,1.0)
	_check(restored.hit_calls.size()==1 and not Combat.busy(restored),"Restored sword action never repeats contact")
	var wall := _fixture()
	_commission(wall)
	wall.village.raid.enemies[0].z = -1.4
	_attack(wall,"overhead")
	Combat.advance(wall,1.2,_blocked,_apply_hit)
	_check(wall.hit_calls.is_empty(),"Weapon still requires actual unobstructed contact")


func _test_save_resume() -> void:
	var data := _fixture()
	_attack(data)
	_step(data, 0.1)
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(data))
	_check(Combat.validate(loaded).is_empty(), "JSON save in preparation retains the exact v1 contract")
	_step(loaded, 0.15)
	_check(loaded.hit_calls.size() == 1, "Loaded preparation resolves only after remaining windup")
	var after_hit: Dictionary = JSON.parse_string(JSON.stringify(loaded))
	_check(Combat.validate(after_hit).is_empty(), "JSON save after contact remains valid")
	_step(after_hit, 0.2)
	_step(after_hit, 0.3)
	_check(after_hit.hit_calls.size() == 1 and after_hit.village.unarmed.resolved_hits == 1, "Loading an active or recovering strike cannot duplicate its hit")
	_check(after_hit.village.unarmed.size() == 11, "No parallel combat state or extra save fields are introduced")


func _test_interruptions() -> void:
	for reason: String in ["hurt", "pause", "death", "terminal"]:
		var data := _fixture()
		_attack(data)
		_step(data, 0.1)
		if reason == "death":
			data.player.health = 0
		elif reason == "terminal":
			data.progress.career_terminal = true
		else:
			_check(Combat.interrupt(data), "External interruption acknowledges active motion: " + reason)
		_step(data, 0.4)
		_check(data.hit_calls.is_empty() and not Combat.busy(data), "Interrupted preparation cannot finish a pending hit: " + reason)
		_check(Combat.validate(data).is_empty(), "Interruption leaves a resumable idle state: " + reason)
	var spent := _fixture()
	_attack(spent)
	Combat.interrupt(spent)
	_check(spent.village.unarmed.stamina == 93.0, "Cancellation does not refund spent stamina")
	var defender := _fixture()
	Combat.execute(defender, "village_unarmed_guard", {})
	Combat.interrupt(defender)
	_check(defender.village.raid.block_window == 0.0 and defender.village.raid.dodge_window == 0.0, "Pause removes an armed defense window")


func _test_stamina_and_defense() -> void:
	var tired := _fixture()
	tired.village.unarmed.stamina = 6.0
	var before := _snapshot(tired)
	_check(not _attack(tired).ok and _snapshot(tired) == before, "Insufficient stamina rejects the whole attack")
	_step(tired, 0.5)
	_check(is_equal_approx(tired.village.unarmed.stamina, 12.0), "Idle time restores stamina")
	_check(_attack(tired).ok, "Recovered stamina permits a new action")
	_step(tired, 0.5)
	_check(is_equal_approx(tired.village.unarmed.stamina, 5.0), "Active attack and recovery cannot regenerate their own cost")
	_step(tired, 0.62)
	_check(is_equal_approx(tired.village.unarmed.stamina, 11.0), "Only actual idle part of a mixed time step regenerates stamina")
	for command: String in ["village_unarmed_guard", "village_unarmed_dodge"]:
		var data := _fixture()
		_check(Combat.execute(data, command, {}).ok, "Defense can start: " + command)
		before = _snapshot(data)
		_check(not _attack(data).ok and _snapshot(data) == before, "Defense and attack cannot overlap")
		_check(data.village.raid.blocks == 0 and data.village.raid.dodges == 0, "Merely pressing defense grants no successful defense")
		_check(data.village.raid.block_window > 0.0 if command.ends_with("guard") else data.village.raid.dodge_window > 0.0, "Defense supplies the real raid's limited window")
		_step(data, 0.9)
		_check(not Combat.busy(data), "Defense releases action lock after its duration")
		_check(data.village.raid.block_window == 0.0 and data.village.raid.dodge_window == 0.0, "Defense expiry cannot leave a stale window when the raid clock is paused")
		_check(Combat.validate(data).is_empty(), "Defense leaves a valid combat save")
	_step(tired, 1000.0)
	_check(tired.village.unarmed.stamina == 100.0, "Long idle time cannot overflow stamina")


func _test_rejected_commands_are_atomic() -> void:
	var data := _fixture()
	for args: Dictionary in [
		{"technique":"jab_left", "target_id":"raider", "facing_x":0.0},
		{"technique":"jab_left", "target_id":"raider", "facing_x":0.0, "facing_z":-1.0, "damage":999},
		{"technique":"sword_slash", "target_id":"raider", "facing_x":0.0, "facing_z":-1.0},
		{"technique":"jab_left", "target_id":"raider", "facing_x":0.0, "facing_z":0.0},
		{"technique":"jab_left", "target_id":"raider", "facing_x":NAN, "facing_z":-1.0},
		{"technique":"jab_left", "target_id":"raider", "facing_x":false, "facing_z":-1.0},
		{"technique":"jab_left", "target_id":[], "facing_x":0.0, "facing_z":-1.0},
		{"technique":"jab_left", "target_id":"unknown", "facing_x":0.0, "facing_z":-1.0}
	]:
		var before := _snapshot(data)
		_check(not Combat.execute(data, "village_unarmed_attack", args).ok and _snapshot(data) == before, "Invalid command cannot partly spend stamina or mutate state")
	var locked_before := _snapshot(data)
	_check(not _attack(data, "high_kick").ok and _snapshot(data) == locked_before, "Unlearned technique is a fully rejected transaction")
	_check(not Combat.execute(data, "village_unarmed_guard", {"shield":true}).ok, "A caller cannot invent a shield or equipment")
	for delta: float in [0.0, -1.0, NAN, INF, 3601.0]:
		var before := _snapshot(data)
		_step(data, delta)
		_check(_snapshot(data) == before, "Invalid clock input changes nothing")


func _test_state_validation() -> void:
	for broken: String in ["version", "extra", "missing", "stamina", "elapsed", "fractional_hits", "facing", "both_defenses", "pending_idle", "unknown_technique", "expired_pending", "attack_and_guard"]:
		var data := _fixture()
		match broken:
			"version": data.village.unarmed.version = 2
			"extra": data.village.unarmed.damage = 999
			"missing": data.village.unarmed.erase("resolved")
			"stamina": data.village.unarmed.stamina = INF
			"elapsed": data.village.unarmed.elapsed = -0.1
			"fractional_hits": data.village.unarmed.practice_hits = 0.5
			"facing": data.village.unarmed.facing = [0.0, 0.0]
			"both_defenses":
				data.village.unarmed.guard_remaining = 0.2
				data.village.unarmed.dodge_remaining = 0.2
			"pending_idle": data.village.unarmed.resolved = false
			"unknown_technique": data.village.unarmed.technique = "sword_slash"
			"expired_pending":
				_attack(data)
				data.village.unarmed.elapsed = 0.4
			"attack_and_guard":
				_attack(data)
				data.village.unarmed.guard_remaining = 0.2
		_check(not Combat.validate(data).is_empty(), "Corrupt save is rejected: " + broken)


func _test_legacy_and_presentation() -> void:
	var legacy := _fixture()
	legacy.village.erase("unarmed")
	var before := _snapshot(legacy)
	_check(not Combat.enabled(legacy) and Combat.validate(legacy).is_empty(), "Existing saves without optional state retain their previous mode")
	_check(not _attack(legacy).ok and _snapshot(legacy) == before, "New combat cannot mutate a legacy save implicitly")
	var data := _fixture()
	var readout := Combat.view(data)
	_check(readout.techniques.size() == 10 and readout.phase == "idle", "Presentation exposes all ten techniques and real phase")
	_check(is_equal_approx(float(readout.techniques[0].contact_peak), int(Combat.measured("jab_left").peak) / 60.0), "Presentation exposes the measured jab peak")
	readout.stamina = 0.0
	readout.techniques[0].damage = 10000
	_check(data.village.unarmed.stamina == 100.0 and Combat.TECHNIQUES.jab_left.damage == 6, "Changing presentation data cannot modify authority or catalogue")
	var old_fight := _fixture()
	old_fight.village.raid.active = false
	old_fight.encounter = {"active":true, "enemies":[{"id":"old_enemy", "x":0.0, "z":-0.7, "health":60}]}
	_check(_attack(old_fight, "jab_right", "old_enemy").ok, "Same resolver can target a real legacy encounter")
	_step(old_fight, 0.68)
	_check(old_fight.encounter.enemies[0].health == 53 and old_fight.hit_calls.size() == 1, "Legacy encounter damage still runs through the explicit authority callback")


## Independent brute-force oracle: densely samples the strike segment and the
## sweep between frames (no shared closest-point code) and returns the first
## live clip frame whose strike capsule touches the target capsule, or -1.
func _oracle_frame(id: String, scale: float, origin: Vector2, yaw: float, target: Vector2, radius: float, height: float, slack: float = 0.0005) -> int:
	var kit := Combat.strike_kit(id)
	var timing := Tracks.timing(kit, id)
	var strike_radius := float(timing.radius) * scale
	for frame in range(maxi(1, int(timing.start)), int(timing.end) + 1):
		var prev := Tracks.segment(kit, id, frame - 1)
		var cur := Tracks.segment(kit, id, frame)
		for k in range(1, 33):
			var s := k / 32.0
			var a := Geo.to_world(Vector3(origin.x, 0, origin.y), yaw, scale, (prev[0] as Vector3).lerp(cur[0], s))
			var b := Geo.to_world(Vector3(origin.x, 0, origin.y), yaw, scale, (prev[1] as Vector3).lerp(cur[1], s))
			for i in 41:
				var p := a.lerp(b, i / 40.0)
				var axis_y := clampf(p.y, radius, height - radius)
				if Vector3(p.x - target.x, p.y - axis_y, p.z - target.y).length() <= strike_radius + radius + slack:
					return frame
	return -1


## Raider position (x, z) where the displayed strike tip arrives at the
## animation peak, `inside` metres inside the raider's surface.
func _peak_target(id: String, inside: float) -> Vector2:
	var timing := Combat.measured(id)
	var tip: Vector3 = Tracks.segment(Combat.strike_kit(id), id, int(timing.peak))[1]
	var bearing := Vector2(tip.x, tip.z).normalized()
	return bearing * (Vector2(tip.x, tip.z).length() + float(timing.radius) + RAIDER_RADIUS - inside)


func _test_measured_contact_frames() -> void:
	# D-026: contact matches the visible animation and never precedes it.
	for id: String in Combat.TECHNIQUES:
		var timing := Combat.measured(id)
		# Place the raider where the displayed tip arrives at the peak, 1 mm
		# inside its surface, along the tip's own bearing.
		var target := _peak_target(id, 0.001)
		var data := _fixture()
		if Combat.is_armed(id):
			_commission(data)
		data.village.unarmed.practice_hits = 14
		data.village.raid.enemies[0].x = target.x
		data.village.raid.enemies[0].z = target.y
		_attack(data, id)
		var contact_frame := -1
		for frame in int(timing.frames) + 2:
			var result := _step(data, 1.0 / 60.0)
			if result.hit:
				contact_frame = int(result.contact_frame)
				_check(contact_frame == frame + 1, "%s: damage event fires on the frame it is computed" % id)
				break
		_check(contact_frame >= 0 and absi(contact_frame - int(timing.peak)) <= 1, "%s: contact within one frame of the animation peak (peak %d, contact %d)" % [id, int(timing.peak), contact_frame])
	var interrupted := _fixture()
	interrupted.village.unarmed.practice_hits = 14
	var kick_target := _peak_target("front_kick", 0.001)
	interrupted.village.raid.enemies[0].x = kick_target.x
	interrupted.village.raid.enemies[0].z = kick_target.y
	_attack(interrupted, "front_kick")
	_step(interrupted, (Combat.measured("front_kick").peak - 3) / 60.0)
	Combat.interrupt(interrupted)
	_step(interrupted, 1.2)
	_check(interrupted.hit_calls.is_empty() and interrupted.village.raid.enemies[0].health == 45, "A kick interrupted three frames before its peak deals no damage")


func _test_catalogue_matches_measurement() -> void:
	# The literal catalogue values are informational; they must equal the
	# measured track data so UI and target selection cannot drift.
	for id: String in Combat.TECHNIQUES:
		var spec: Dictionary = Combat.TECHNIQUES[id]
		var timing := Combat.measured(id)
		_check(absf(float(spec.windup) - int(timing.start) / 60.0) < 0.0001, "%s windup equals the measured live-window start" % id)
		_check(absf(float(spec.active) - (int(timing.end) - int(timing.start) + 1) / 60.0) < 0.0001, "%s active equals the measured live window" % id)
		_check(absf(float(spec.reach) - (float(timing.reach) + RAIDER_RADIUS)) < 0.001, "%s reach equals measured strike reach plus the raider capsule" % id)
		_check(is_equal_approx(float(timing.duration), float(spec.duration)), "%s track duration equals the technique duration" % id)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
