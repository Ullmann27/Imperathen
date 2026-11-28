extends SceneTree
## Level-B formation agents and A/B/C level switching.
## godot --headless --path prototype --fixed-fps 60 --script res://tests/formation_agents_test.gd
##
## Identity: every frame the rendered soldier uids equal the rule model's living
## roster, nobody has two representations, and a fallen uid never returns, while
## the camera is thrown across every switching distance. Motion: speed, turn,
## acceleration, stride and spacing limits, slot matching without crossings,
## wheel, march in step, charge surge and stop at contact.

const Valley := preload("res://scripts/tactics/valley_scene.gd")
const TribalFigure := preload("res://scripts/visuals/valley_tribal_soldier.gd")
const Battle := preload("res://scripts/battle/battle_model.gd")
const Agents := preload("res://scripts/formation/formation_agents.gd")
const Levels := preload("res://scripts/formation/formation_levels.gd")
const Troop := preload("res://scripts/formation/troop_motion.gd")
const Ranks := preload("res://scripts/visuals/far_ranks.gd")
const Soldier := preload("res://scripts/visuals/soldier_visual.gd")
const HZ := 60.0
const LOD_JUMP_LIMIT := 0.04

var checks := 0
var failures := 0
var notes := {}


class Resurrecting extends "res://scripts/battle/battle_model.gd":
	## Rule model that wrongly lists a fallen soldier again after a while.
	var ghost := ""
	var ghost_after := -1

	func soldiers(id: String) -> Array:
		var result: Array = super.soldiers(id)
		if ghost != "" and ghost_after >= 0 and steps >= ghost_after and ghost.begins_with(id):
			result.append({"id": ghost, "x": squads[id].x, "z": squads[id].z, "facing": squads[id].facing, "pose": "idle"})
		return result


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


## ++ large: only the 180-soldier identity runs (a separate check group so
## each group stays well inside the runner's per-group timeout).
func _run() -> void:
	var large_only := "large" in OS.get_cmdline_user_args()
	if not large_only:
		_test_budgets_match_profiles()
		_test_hysteresis_and_cooldown()
		_test_budget_caps_and_counters()
		_test_motion_limits()
		_test_reform_without_crossing()
		_test_wheel_keeps_places()
		_test_charge_surge_and_contact()
		_test_resurrection_refused()
		_test_external_handover()
	for profile in ["balanced", "very_high"]:
		_test_identity_across_switches(profile, large_only)
	print("FORMATION_AGENTS_RESULT checks=%d failures=%d %s" % [checks, failures, JSON.stringify(notes)])
	if failures == 0:
		print("FORMATION_AGENTS_PASS")
	quit(1 if failures else 0)


func _test_budgets_match_profiles() -> void:
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/quality_profiles.json")).profiles
	for profile: String in profiles:
		var b: Dictionary = Levels.BUDGETS[profile]
		check(int(b.near_rigs) + int(b.mid_rigs) == int(profiles[profile].review_limits.animated_valley_actors),
			"Near + middle rig budget equals the animated actor review limit: " + profile)
		check(float(b.near_m) < float(b.mid_m) and float(b.mid_m) < float(b.aggregate_m), "Ordered level radii: " + profile)


func _agent(uid: String, x: float) -> Object:
	var a = Agents.Agent.new()
	a.uid = uid
	a.squad = "test"
	a.pos = Vector2(x, 0)
	a.level = Levels.LEVEL_C
	a.detail = Levels.DETAIL_FAR
	return a


func _assign(levels, agents: Dictionary, camera: Vector3, delta: float, blocked := {}) -> void:
	levels.assign(agents, camera, func(_p): return true, func(uid): return blocked.has(uid), delta)


func _test_hysteresis_and_cooldown() -> void:
	var levels = Levels.new()
	levels.profile = "balanced"
	var mid: float = Levels.BUDGETS.balanced.mid_m
	var a = _agent("u1", 0.0)
	var agents := {"u1": a}
	var camera := Vector3(0, 1.0, 0)
	var height := Battle.ground_height(0, 0)
	# Distances are measured from the camera to a point 1 m above the ground.
	camera.y = height + 1.0
	a.pos = Vector2(mid - 4.0, 0)
	_assign(levels, agents, camera, 2.0)
	check(a.level == Levels.LEVEL_B, "Inside the middle radius minus hysteresis becomes level B")
	var switches := 0
	var last_level: int = a.level
	for i in 40:
		# +-2 m around the threshold stays inside the +-3 m hysteresis band.
		a.pos = Vector2(mid + (2.0 if i % 2 == 0 else -2.0), 0)
		_assign(levels, agents, camera, 0.1)
		if a.level != last_level:
			switches += 1
			last_level = a.level
	check(switches == 0, "Oscillating +-2 m around the threshold never switches (hysteresis), got %d" % switches)
	a.pos = Vector2(mid + 4.0, 0)
	_assign(levels, agents, camera, 2.0)
	check(a.level == Levels.LEVEL_C, "Beyond threshold + hysteresis becomes level C")
	a.pos = Vector2(mid - 4.0, 0)
	_assign(levels, agents, camera, 0.2)
	check(a.level == Levels.LEVEL_C, "Return inside the switching band within the 1 s cooldown is held")
	_assign(levels, agents, camera, 0.9)
	check(a.level == Levels.LEVEL_B, "After the cooldown the soldier switches back")
	a.pos = Vector2(mid + 10.0, 0)
	_assign(levels, agents, camera, 0.05)
	check(a.level == Levels.LEVEL_C, "Far outside the band (camera jump) the switch is immediate despite the cooldown")
	# Rig detail: a rig holder that is mid crossfade keeps its rig.
	var b = _agent("u2", 5.0)
	agents = {"u2": b}
	_assign(levels, agents, camera, 2.0)
	check(b.detail == Levels.DETAIL_NEAR, "Close visible soldier receives a near rig")
	b.pos = Vector2(mid + 20.0, 0)
	_assign(levels, agents, camera, 2.0, {"u2": true})
	check(b.detail == Levels.DETAIL_NEAR, "A crossfading rig is not swapped (pose would jump)")
	_assign(levels, agents, camera, 0.05)
	check(b.detail == Levels.DETAIL_FAR, "Once the crossfade ends the distant soldier becomes an instance")


func _test_budget_caps_and_counters() -> void:
	for profile: String in Levels.BUDGETS:
		var levels = Levels.new()
		levels.profile = profile
		var b: Dictionary = Levels.BUDGETS[profile]
		var agents := {}
		var total := int(b.visible) + 300
		for i in total:
			var a = _agent("s%05d" % i, 2.0 + float(i) * 0.02)
			agents[a.uid] = a
		_assign(levels, agents, Vector3(0, 1.0 + Battle.ground_height(0, 0), 0), 2.0)
		var c: Dictionary = levels.last
		check(c.rigs_near <= int(b.near_rigs) and c.rigs_near + c.rigs_mid <= int(b.near_rigs) + int(b.mid_rigs), "Rig budget holds: " + profile)
		check(c.level_a <= int(b.near_rigs) and c.simulated_individual <= int(b.individual), "Level A and individual budgets hold: " + profile)
		check(c.visible <= int(b.visible) and c.aggregated == total - int(b.visible), "Visible budget aggregates the rest: " + profile)
		check(c.simulated_individual + c.simulated_aggregate == total and c.rigs_near + c.rigs_mid + c.far_instances + c.aggregated == total,
			"Counters account for every soldier exactly once: " + profile)
		check(c.animated == c.rigs_near + c.rigs_mid, "Animated actors are reported separately from visible instances: " + profile)
		notes["budget_" + profile] = [c.rigs_near, c.rigs_mid, c.far_instances, c.aggregated, c.simulated_individual]


## Runs the agents directly on a rule model (no rendering).
func _drive(model, agents, seconds: float, observe: Callable = Callable()) -> void:
	var frames := int(seconds * HZ)
	for i in frames:
		model.tick(1.0 / HZ)
		var before := {}
		for uid: String in agents.agents:
			var a = agents.agents[uid]
			before[uid] = [a.pos, a.yaw, a.speed, a.phase, a.pose]
		var ticks: int = agents.advance(model)
		if observe.is_valid() and ticks > 0:
			observe.call(before, ticks)


func _test_motion_limits() -> void:
	var model := Battle.new()
	var agents = Agents.new()
	agents.sync_model(model)
	model.order(["valley_guard"], "move", Vector2(-7, -2))
	model.order(["valley_spears"], "move", Vector2(5, -1))
	var worst := {"speed": 0.0, "accel_excess": 0.0, "turn_excess": 0.0, "stride": 0.0, "same": 9.0, "cross": 9.0,
		"drum": 0.0, "drum_samples": 0, "drum_in_step": 0, "drum_errors": [], "moving_since": -1.0, "t": 0.0}
	var observe := func(before: Dictionary, ticks: int) -> void:
		for uid: String in agents.agents:
			var a = agents.agents[uid]
			if not before.has(uid) or ticks != 1:
				continue
			var lim: Dictionary = a.limits
			worst.speed = maxf(worst.speed, absf(a.speed))
			var dv := absf(a.speed - float(before[uid][2]))
			worst.accel_excess = maxf(worst.accel_excess, dv - maxf(float(lim.accel), float(lim.brake)) * Agents.DT)
			var turn := absf(angle_difference(float(before[uid][1]), a.yaw))
			worst.turn_excess = maxf(worst.turn_excess, turn - deg_to_rad(float(lim.turn)) * Agents.DT)
			if a.pose == "march" and before[uid][4] == "march":
				var travelled: float = (a.pos - a.prev_pos).dot(Vector2(sin(a.yaw), cos(a.yaw)))
				var stepped: float = (a.phase - a.prev_phase) * float(Soldier.STRIDES.march)
				worst.stride = maxf(worst.stride, absf(stepped - travelled) - Agents.PHASE_LOCK * absf(travelled) * float(Soldier.STRIDES.march))
		for uid: String in agents.agents:
			var a = agents.agents[uid]
			for other: String in agents.agents:
				if other <= uid:
					continue
				var d: float = a.pos.distance_to(agents.agents[other].pos)
				if a.squad == agents.agents[other].squad:
					worst.same = minf(worst.same, d)
				else:
					worst.cross = minf(worst.cross, d)
		worst.t += ticks * Agents.DT
		var u = agents.units.valley_guard
		var enemy_near: bool = agents.units.ridge_guard.center.distance_to(u.center) < 10.0
		if u.velocity.length() > 1.5 and not enemy_near:
			if worst.moving_since < 0.0:
				worst.moving_since = worst.t
			if worst.t - worst.moving_since >= 1.5:
				for uid: String in u.members:
					var a = agents.agents[uid]
					if a.pose == "march":
						var error := absf(wrapf(a.phase - (u.drum + a.drum_offset), -0.5, 0.5))
						worst.drum = maxf(worst.drum, error)
						worst.drum_samples += 1
						worst.drum_errors.append(error)
						if error <= Agents.STEP_OFFSET + 0.02:
							worst.drum_in_step += 1
	_drive(model, agents, 9.0, observe)
	check(worst.speed <= float(Troop.KINDS.infantry.charge) + 0.001, "Soldier speed stays within the troop sprint limit: %.3f" % worst.speed)
	check(worst.accel_excess <= 0.0005, "Acceleration and braking stay within troop limits: excess %.4f m/s per tick" % worst.accel_excess)
	check(worst.turn_excess <= 0.0005, "Turn rate stays within the troop limit: excess %.4f rad per tick" % worst.turn_excess)
	check(worst.stride <= 0.0005, "Gait phase advances with distance walked (stride matched, lock <= 1.2 %%): %.4f m" % worst.stride)
	check(worst.same >= 2.0 * Troop.BODY_RADIUS - 0.005 and worst.cross >= 2.0 * Troop.BODY_RADIUS - 0.005,
		"No interpenetration inside or between companies: same %.3f m, other %.3f m" % [worst.same, worst.cross])
	var errors: Array = worst.drum_errors
	errors.sort()
	var median: float = errors[errors.size() / 2] if not errors.is_empty() else 1.0
	check(worst.drum_samples > 100 and float(worst.drum_in_step) >= 0.9 * worst.drum_samples,
		"A drilled company marches in step: %d of %d samples within %.2f cycles" % [worst.drum_in_step, worst.drum_samples, Agents.STEP_OFFSET + 0.02])
	check(median <= Agents.STEP_OFFSET, "Median step error of the marching company <= %.2f cycles: %.3f" % [Agents.STEP_OFFSET, median])
	worst.erase("drum_errors")
	worst.drum_median = median
	notes.motion = worst


func _test_reform_without_crossing() -> void:
	var model := Battle.new()
	var agents = Agents.new()
	agents.sync_model(model)
	_drive(model, agents, 1.0)
	var u = agents.units.valley_guard
	var starts := {}
	for uid: String in u.members:
		starts[uid] = agents.agents[uid].pos
	var rematches: int = agents.counters.rematches
	model.order(["valley_guard"], "form", "line")
	var before_tick: int = agents.tick
	_drive(model, agents, 6.0)
	check(agents.counters.rematches > rematches, "Changing formation re-matches places")
	var record: Dictionary = agents.last_match.get("valley_guard", {})
	check(int(record.get("tick", -1)) > before_tick, "The re-formation produced a recorded matching")
	var from: Array = record.get("from", [])
	var to: Array = record.get("to", [])
	var crossings := 0
	var matched := 0.0
	for i in from.size():
		matched += from[i].distance_to(to[i])
		for k in range(i + 1, from.size()):
			if Geometry2D.segment_intersects_segment(from[i], to[i], from[k], to[k]) != null:
				crossings += 1
				notes["crossing_%d_%d" % [i, k]] = [from[i], to[i], from[k], to[k]]
	check(crossings == 0, "Re-formed soldiers take non-crossing routes to their new places: %d crossings" % crossings)
	# Index assignment (member i -> slot i, as the rules order members) for the same positions.
	var by_index := 0.0
	var slots: Array = record.get("by_index", [])
	for i in from.size():
		by_index += from[i].distance_to(slots[i])
	var total := 0.0
	for uid: String in u.members:
		total += starts[uid].distance_to(agents.agents[uid].pos)
	check(matched <= by_index + 0.05, "Matched re-formation walks no farther than index assignment: %.2f vs %.2f m" % [matched, by_index])
	notes.reform = {"matched_m": matched, "index_m": by_index, "walked_m": total}


func _test_wheel_keeps_places() -> void:
	var model := Battle.new()
	var agents = Agents.new()
	agents.sync_model(model)
	_drive(model, agents, 0.5)
	# A move 45 deg off the front turns the company without changing its layout.
	check(model.order(["valley_spears"], "move", Vector2(9, 4)).ok, "Oblique move accepted")
	var refiles: int = agents.counters.refiles
	var rematches: int = agents.counters.rematches
	var u = agents.units.valley_spears
	var owners: Array = u.owners.duplicate()
	var seen := {"outer": 0.0, "turned": 0.0}
	var counter_start := {}
	for id: String in agents.units:
		var unit = agents.units[id]
		counter_start[id] = [unit.refiles, unit.rematches]
	var start_facing: float = u.facing
	var observe := func(_before: Dictionary, ticks: int) -> void:
		seen.turned = maxf(seen.turned, absf(angle_difference(start_facing, u.facing)))
		if ticks == 1:
			for uid: String in u.members:
				seen.outer = maxf(seen.outer, agents.agents[uid].speed)
	_drive(model, agents, 8.0, observe)
	check(seen.turned > deg_to_rad(30.0), "The company front actually turned (%.0f deg)" % rad_to_deg(seen.turned))
	var unit_deltas := {}
	for id: String in agents.units:
		var unit = agents.units[id]
		if counter_start.has(id):
			unit_deltas[id] = [int(unit.refiles) - int(counter_start[id][0]), int(unit.rematches) - int(counter_start[id][1])]
	notes.wheel_counters = {"global_refiles": agents.counters.refiles - refiles, "global_rematches": agents.counters.rematches - rematches, "units": unit_deltas, "target": "valley_spears"}
	check(agents.counters.refiles == refiles and agents.counters.rematches == rematches, "A front change below 75 deg wheels instead of re-filing")
	check(u.owners == owners, "Wheeling keeps every man in his place in the rank")
	check(seen.outer <= float(u.limits.charge) + 0.001 and seen.outer > 0.5, "Outer file speed during the wheel stays within limits: %.2f m/s" % seen.outer)
	var ready := 0
	for uid: String in u.members:
		if agents.agents[uid].pos.distance_to(u.slot_world[agents.agents[uid].slot]) < 0.3:
			ready += 1
	check(ready == u.members.size(), "After the wheel every man stands in his slot (%d/%d)" % [ready, u.members.size()])


func _test_charge_surge_and_contact() -> void:
	var model := Battle.new()
	var agents = Agents.new()
	agents.sync_model(model)
	model.order(["valley_guard"], "attack", "ridge_guard")
	var seen := {"peak": 0.0, "closest": 99.0, "contact_at": -1.0, "speed_at_contact": 0.0, "elapsed": 0.0}
	var observe := func(_before: Dictionary, ticks: int) -> void:
		seen.elapsed += ticks * Agents.DT
		var u = agents.units.valley_guard
		for uid: String in u.members:
			var a = agents.agents[uid]
			seen.peak = maxf(seen.peak, a.speed)
			for other: String in agents.units.ridge_guard.members:
				if agents.agents.has(other):
					seen.closest = minf(seen.closest, a.pos.distance_to(agents.agents[other].pos))
			if a.contact and seen.contact_at < 0.0:
				# Closing speed toward the nearest opponent when contact begins.
				var nearest = null
				for other: String in agents.units.ridge_guard.members:
					if agents.agents.has(other) and (nearest == null or a.pos.distance_to(agents.agents[other].pos) < a.pos.distance_to(nearest.pos)):
						nearest = agents.agents[other]
				if nearest != null:
					seen.contact_at = seen.elapsed
					seen.speed_at_contact = maxf(0.0, a.vel.dot(a.pos.direction_to(nearest.pos)))
	_drive(model, agents, 16.0, observe)
	check(seen.peak > Troop.RUN_ENTER, "Charging men accelerate into a run: peak %.2f m/s" % seen.peak)
	check(seen.contact_at > 0.0, "The charge reaches weapon contact")
	check(seen.speed_at_contact < 1.0, "The first man at contact has braked: closing %.2f m/s" % seen.speed_at_contact)
	check(seen.closest >= 2.0 * Troop.BODY_RADIUS, "Opposing men never interpenetrate: closest %.3f m" % seen.closest)
	notes.charge = seen


func _test_resurrection_refused() -> void:
	var model := Resurrecting.new()
	var agents = Agents.new()
	agents.sync_model(model)
	model.order(["valley_guard"], "attack", "ridge_guard")
	var fallen := ""
	for i in int(60 * HZ):
		model.tick(1.0 / HZ)
		agents.advance(model)
		if fallen == "" and not agents.dead_uids.is_empty():
			fallen = agents.dead_uids.keys()[0]
			model.ghost = fallen
			model.ghost_after = model.steps + 3
		if fallen != "" and model.steps > model.ghost_after + 5:
			break
	check(fallen != "", "A soldier falls in the engagement")
	check(not agents.agents.has(fallen) and agents.counters.rejected_resurrections > 0,
		"A fallen uid listed again by the rules is refused, not recreated")


func _test_external_handover() -> void:
	var model := Battle.new()
	var agents = Agents.new()
	agents.sync_model(model)
	_drive(model, agents, 0.5)
	var uid := "valley_guard_03"
	var created: int = agents.counters.created
	var state: Dictionary = agents.release_external(uid)
	check(not state.is_empty() and agents.agents[uid].external, "Level A hand-over keeps the agent and its uid")
	var target: Vector2 = state.position + Vector2(0.3, 0)
	check(agents.update_external(uid, target, state.yaw, state.phase, "attack"), "An external controller may drive the agent")
	_drive(model, agents, 0.5)
	check(agents.agents[uid].pos == target, "The B layer does not move an externally driven soldier")
	check(agents.return_external(uid) and not agents.agents[uid].external, "Control returns to level B")
	check(agents.counters.created == created and agents.agents.size() == model.summary().ally.strength + model.summary().enemy.strength,
		"Hand-over neither creates nor drops a soldier")


func _sole_points(actor: Node3D) -> Dictionary:
	var rig: Skeleton3D = actor.find_children("*", "Skeleton3D", true, false)[0]
	var to_root := actor.global_transform.affine_inverse() * rig.global_transform
	var result := {}
	for side in ["R", "L"]:
		var bone := rig.find_bone("Foot_" + side)
		var binding := rig.get_bone_global_pose(bone) * rig.get_bone_global_rest(bone).affine_inverse()
		result[side] = [to_root * (binding * Vector3(-.126 if side == "R" else .126, .011, -.065)),
			to_root * (binding * Vector3(-.126 if side == "R" else .126, .011, .175))]
	return result


func _foot_jump(feet: Dictionary, soles: Dictionary, gait: Color) -> float:
	var worst := 0.0
	for side in ["R", "L"]:
		for sole: Vector3 in soles[side]:
			var closest := INF
			for vertex: Vector3 in feet[side]:
				closest = minf(closest, sole.distance_to(Ranks.deformed_vertex(vertex, gait, 1.0)))
			worst = maxf(worst, closest)
	return worst


func _test_identity_across_switches(profile: String, large: bool) -> void:
	var label := profile + ("/180" if large else "/60")
	var v = Valley.new()
	var reference = Battle.new()
	if large:
		for model in [v.model, reference]:
			for s: Dictionary in model.squads.values().duplicate():
				model._add_squad(s.id, s.name, s.side, s.kind, s.formation, Vector2(s.x, s.z), s.strength * 3)
	check(JSON.stringify(reference.snapshot()) == JSON.stringify(v.model.snapshot()), label + ": reference rules start identical")
	root.add_child(v)
	v.set_quality(profile)
	v.paused = false
	var feet := {}
	for role: String in Soldier.ROLES + TribalFigure.FAMILIES.values():
		var silhouette: Mesh = Soldier.far_mesh(role) if role in Soldier.ROLES else TribalFigure.silhouette(role)
		var vertices: PackedVector3Array = silhouette.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		feet[role] = {"R": [], "L": []}
		for vertex in vertices:
			if vertex.y <= .10 and absf(vertex.x) <= .205:
				feet[role]["R" if vertex.x < 0 else "L"].append(vertex)
	var random := RandomNumberGenerator.new()
	random.seed = 58
	var dead := {}
	var last := {}
	var stats := {"frames": 0, "switches": 0, "measured": 0, "max_jump": 0.0, "max_step": 0.0, "max_phase_step": 0.0,
		"mismatch": 0, "duplicates": 0, "resurrected": 0, "budget": 0, "rule_drift": 0}
	var b: Dictionary = Levels.BUDGETS[profile]
	var orders := [[0.1, "valley_guard", "move", Vector2(-7, 2)], [0.1, "valley_spears", "deploy", {"start": Vector2(1, 6), "end": Vector2(8, 3.5)}],
		[6.0, "valley_guard", "form", "line"], [8.0, "valley_guard", "attack", "ridge_guard"], [8.0, "valley_spears", "attack", "ridge_spears"]]
	var limit_speed := float(Troop.KINDS.infantry.charge) + 0.05
	for i in range(1, int(32 * HZ)):
		var t := float(i) / HZ
		for entry in orders:
			if t >= float(entry[0]) and t - 1.0 / HZ < float(entry[0]):
				v.model.order([entry[1]], entry[2], entry[3])
				reference.order([entry[1]], entry[2], entry[3])
		if i % 9 == 0:
			# Throw the camera across every switching distance.
			v.focus = Vector2(random.randf_range(-12, 12), random.randf_range(-10, 12))
			v.distance = random.randf_range(5.0, 65.0)
			v.azimuth = random.randf_range(-1.0, 1.0)
			v._place_camera()
		var soles := {}
		for uid: String in v.actors:
			soles[uid] = _sole_points(v.actors[uid])
		var gaits := {}
		for uid: String in v.agents.agents:
			gaits[uid] = v.formation_far_gait(uid)
		v._process(1.0 / HZ)
		reference.tick(1.0 / HZ)
		stats.frames += 1
		var alive := {}
		var leaving_allowed := {}
		for s: Dictionary in v.model.squads.values():
			if s.strength > 0:
				for man: Dictionary in v.model.soldiers(s.id):
					if s.status == "withdrawn":
						leaving_allowed[Agents.uid_of(man)] = true
					else:
						alive[Agents.uid_of(man)] = true
		var states: Dictionary = v.formation_render_states()
		# Drawn = every man of a company on the field, plus men of a withdrawn
		# company still on their way to the edge (alive in the rules, marked leaving).
		var drawn_ok := alive.keys().all(func(uid): return states.has(uid))
		for uid: String in states:
			if not alive.has(uid) and not (leaving_allowed.has(uid) and bool(states[uid].leaving)):
				drawn_ok = false
		if not drawn_ok:
			stats.mismatch += 1
		for uid: String in leaving_allowed:
			alive[uid] = true
		stats.duplicates += v.formation_duplicate_count()
		for uid: String in states:
			var state: Dictionary = states[uid]
			if bool(state.represented) != (int(state.detail) <= Levels.DETAIL_FAR):
				stats.mismatch += 1
			if v.actors.has(uid):
				var a = v.agents.agents[uid]
				if v.actors[uid].face_seed != a.appearance_seed:
					stats.mismatch += 1
		for uid: String in alive:
			if dead.has(uid):
				stats.resurrected += 1
		for uid: String in last:
			if not alive.has(uid):
				dead[uid] = true
		var c: Dictionary = v.levels.last
		if c.rigs_near > int(b.near_rigs) or c.rigs_near + c.rigs_mid + c.dying_rigs > int(b.near_rigs) + int(b.mid_rigs) or c.visible > int(b.visible):
			stats.budget += 1
		for uid: String in states:
			var state: Dictionary = states[uid]
			if last.has(uid):
				var previous: Dictionary = last[uid]
				var step: float = Vector2(state.position.x, state.position.z).distance_to(Vector2(previous.position.x, previous.position.z))
				if step > stats.max_step:
					var a = v.agents.agents[uid]
					stats.worst_step = {"uid": uid, "t": t, "level": state.level, "previous_level": previous.level,
						"detail": state.detail, "previous_detail": previous.detail, "speed": a.speed,
						"correction": a.correction.length(), "contact": a.contact, "pose": state.pose}
				stats.max_step = maxf(stats.max_step, step)
				if state.pose in Soldier.STRIDES and previous.pose in Soldier.STRIDES:
					var phase_step := absf(wrapf(float(state.phase) - float(previous.phase), -0.5, 0.5))
					if phase_step > stats.max_phase_step:
						stats.worst_phase = {"uid": uid, "t": t, "family": state.visual_family, "pose": state.pose, "previous_pose": previous.pose, "phase": state.phase, "previous_phase": previous.phase, "detail": state.detail, "previous_detail": previous.detail, "level": state.level, "previous_level": previous.level}
					stats.max_phase_step = maxf(stats.max_phase_step, phase_step)
				if int(state.detail) != int(previous.detail):
					stats.switches += 1
					var jump := -1.0
					if int(previous.detail) <= 1 and int(state.detail) == Levels.DETAIL_FAR and soles.has(uid):
						jump = _foot_jump(feet[state.visual_family], soles[uid], gaits[uid])
					elif int(previous.detail) == Levels.DETAIL_FAR and int(state.detail) <= 1 and v.actors.has(uid):
						jump = _foot_jump(feet[state.visual_family], _sole_points(v.actors[uid]), v.formation_far_gait(uid))
					if jump >= 0.0:
						stats.measured += 1
						if jump > stats.max_jump:
							stats.worst_jump = {"uid": uid, "t": t, "family": state.visual_family, "pose": state.pose, "previous_pose": previous.pose, "phase": state.phase, "previous_phase": previous.phase, "detail": state.detail, "previous_detail": previous.detail, "level": state.level, "previous_level": previous.level}
						stats.max_jump = maxf(stats.max_jump, jump)
		last = states
		if v.model.outcome != "ongoing":
			break
	if JSON.stringify(v.model.snapshot()) != JSON.stringify(reference.snapshot()):
		stats.rule_drift += 1
	check(stats.mismatch == 0, label + ": rendered uids equal the living rule roster in every frame (%d mismatches)" % stats.mismatch)
	check(stats.duplicates == 0, label + ": no soldier has two representations (%d)" % stats.duplicates)
	check(stats.resurrected == 0 and v.agents.counters.rejected_resurrections == 0, label + ": no fallen uid returns")
	check(stats.budget == 0, label + ": rig, level and visible budgets hold in every frame (%d violations)" % stats.budget)
	check(stats.switches > 20 and stats.measured > 10, label + ": the camera path produced real level-of-detail switches (%d, %d measured)" % [stats.switches, stats.measured])
	check(stats.max_jump <= LOD_JUMP_LIMIT, label + ": foot pose jump at every actual switch <= 0.04 m (%.4f)" % stats.max_jump)
	check(stats.max_step <= limit_speed / HZ + 0.002, label + ": position continuous across switches, max %.4f m per frame" % stats.max_step)
	check(stats.max_phase_step <= limit_speed / HZ / float(Soldier.STRIDES.march) + 0.01, label + ": gait phase continuous across switches, max %.4f" % stats.max_phase_step)
	check(stats.rule_drift == 0, label + ": rendering and agents leave the rule simulation bit-identical")
	check(v.formation_counters().pooled_rigs <= v.MAX_POOLED_RIGS, label + ": inactive rig pool is bounded")
	notes["identity_" + label] = stats
	v.free()
