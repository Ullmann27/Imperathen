extends SceneTree
## Focused reproduction of the hidden level-B root/phase spike in the
## original balanced/180 camera replay (run 46096417387). The existing
## formation tests remain untouched. This is diagnostic, not visual approval.
const Valley := preload("res://scripts/tactics/valley_scene.gd")
const Agents := preload("res://scripts/formation/formation_agents.gd")
const Field := preload("res://scripts/battle/valley_field.gd")
const Soldier := preload("res://scripts/visuals/soldier_visual.gd")
const Troop := preload("res://scripts/formation/troop_motion.gd")
const UID := "ridge_spears_04"
const HZ := 60.0
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)

func _xy(p: Vector2) -> Array:
	return [p.x, p.y]

func _rock_clearance(p: Vector2) -> Dictionary:
	var distance := INF
	var index := -1
	for i in Field.ROCKS.size():
		var rock: Dictionary = Field.ROCKS[i]
		var clearance := p.distance_to(Vector2(rock.x, rock.z)) - float(rock.radius) - Field.MARGIN - .01
		if clearance < distance:
			distance = clearance
			index = i
	return {"rock": index, "clearance_m": distance}

func _capture(v, a: Agents.Agent) -> Dictionary:
	var nearest_friend := INF
	var nearest_enemy := INF
	var close_count := 0
	for b: Agents.Agent in v.agents.agents.values():
		if b == a or b.level == Agents.LEVEL_C:
			continue
		var distance := a.pos.distance_to(b.pos)
		if a.side == b.side:
			nearest_friend = minf(nearest_friend, distance)
		else:
			nearest_enemy = minf(nearest_enemy, distance)
		if distance < 1.0:
			close_count += 1
	var delta := a.pos - a.prev_pos
	return {"tick": v.agents.tick, "rule_step": v.model.steps, "fraction": v.agents.render_fraction(v.model),
		"level": a.level, "detail": a.detail, "slot": a.slot, "model_slot": a.model_slot,
		"root": _xy(a.pos), "previous_root": _xy(a.prev_pos), "velocity": _xy(a.vel),
		"correction": _xy(a.correction), "correction_m": a.correction.length(),
		"raw_step_m": delta.length(), "integrated_speed_m": (a.vel * Agents.DT).length(),
		"decomposition_residual_m": (delta - a.vel * Agents.DT - a.correction).length(),
		"pose": a.pose, "previous_pose": a.prev_pose, "phase": a.phase, "previous_phase": a.prev_phase,
		"yaw": a.yaw, "speed": a.speed, "contact": a.contact, "crowded": a.crowded,
		"rock_before": _rock_clearance(a.prev_pos), "rock_after": _rock_clearance(a.pos),
		"clear_segment": Field.clear_segment(a.prev_pos, a.pos), "nearby_count": close_count,
		"friend_m": nearest_friend if is_finite(nearest_friend) else -1.0,
		"enemy_m": nearest_enemy if is_finite(nearest_enemy) else -1.0}

## Cross each real obstacle in both directions at ordinary C travel speed.
## No path-grid setup or fixture teleport can bypass the production helper.
func _aggregate_routes() -> void:
	var agents := Agents.new()
	var stride := float(Troop.KINDS.infantry.run) * Agents.DT
	for i in Field.ROCKS.size():
		var rock: Dictionary = Field.ROCKS[i]
		var centre := Vector2(rock.x, rock.z)
		var radius := float(rock.radius) + Field.MARGIN + 0.12
		for sign: float in [-1.0, 1.0]:
			var at := centre + Vector2(radius * sign, 0.0)
			var goal := centre - Vector2(radius * sign, 0.0)
			var legal := true
			var longest := 0.0
			for step in 480:
				if at.distance_to(goal) <= 0.002:
					break
				var next := agents._aggregate_step(at, goal, stride)
				longest = maxf(longest, next.distance_to(at))
				legal = legal and Field.clear_segment(at, next) and agents._aggregate_segment_clear(at, next)
				at = next
			check(legal, "Rock %d side %+.0f: every actual aggregate segment clears the original obstacle" % [i, sign])
			check(longest <= stride + 0.00001 and at.distance_to(goal) <= 0.002, "Rock %d side %+.0f: bounded route reaches its opposite endpoint" % [i, sign])

## Exercise actual broadphase/sweep with both directions of a C/B promotion,
## original hard spacing, free travel and a legacy overlap escaping outward.
func _body_sweep_cases() -> void:
	var system := Agents.new()
	var a := Agents.Agent.new()
	var b := Agents.Agent.new()
	a.uid = "sweep_a"
	b.uid = "sweep_b"
	a.side = "ally"
	b.side = "enemy"
	a.pos = Vector2(-1, 0)
	b.pos = Vector2.ZERO
	system.agents[a.uid] = a
	system.agents[b.uid] = b
	for level: int in [Agents.LEVEL_B, Agents.LEVEL_C]:
		a.level = level
		b.level = Agents.LEVEL_C if level == Agents.LEVEL_B else Agents.LEVEL_B
		system._build_grid(true)
		var hit := system._body_step(a, Vector2(-.6, 0))
		check(hit.distance_to(b.pos) >= Agents.HARD_ENEMY_M and hit.distance_to(a.pos) <= .4 and hit.x > a.pos.x, "B/C swept contact stops at original enemy clearance")
		check(system._body_step(a, Vector2(-1, .4)).is_equal_approx(Vector2(-1, .4)), "Unobstructed tangent travel remains unchanged")
	b.side = "ally"
	a.pos = Vector2(-.8, 0)
	system._build_grid(true)
	var friendly := system._body_step(a, Vector2(-.4, 0))
	check(friendly.distance_to(b.pos) >= Agents.HARD_SAME_M and friendly.x > a.pos.x, "Friendly sweep preserves original hard body spacing")
	a.pos = Vector2(-.5, 0)
	system._build_grid(true)
	check(system._body_step(a, Vector2(-.4, 0)).is_equal_approx(a.pos), "Legacy overlap cannot deepen")
	check(system._body_step(a, Vector2(-.9, 0)).is_equal_approx(Vector2(-.9, 0)), "Legacy overlap may escape outward without teleport")

func _run() -> void:
	_aggregate_routes()
	_body_sweep_cases()
	var v = Valley.new()
	for s: Dictionary in v.model.squads.values().duplicate():
		v.model._add_squad(s.id, s.name, s.side, s.kind, s.formation, Vector2(s.x, s.z), s.strength * 3)
	root.add_child(v)
	v.set_quality("balanced")
	v.paused = false
	check(v.agents.agents.size() == 180, "Original 180-agent scenario")
	var random := RandomNumberGenerator.new()
	random.seed = 58
	var orders := [[0.1, "valley_guard", "move", Vector2(-7, 2)],
		[0.1, "valley_spears", "deploy", {"start": Vector2(1, 6), "end": Vector2(8, 3.5)}],
		[6.0, "valley_guard", "form", "line"], [8.0, "valley_guard", "attack", "ridge_guard"],
		[8.0, "valley_spears", "attack", "ridge_spears"]]
	var previous: Dictionary = {}
	var max_step := 0.0
	var max_phase := 0.0
	var max_correction := 0.0
	var minimum_rock_clearance := INF
	var worst_step: Dictionary = {}
	var worst_phase: Dictionary = {}
	var worst_correction: Dictionary = {}
	var samples := 0
	var phase_samples := 0
	var speed_limit := float(Troop.KINDS.infantry.charge) + .05
	var step_limit := speed_limit / HZ + .002
	var phase_limit := speed_limit / HZ / float(Soldier.STRIDES.march) + .01
	for i in range(1, int(32 * HZ)):
		var t := float(i) / HZ
		for entry in orders:
			if t >= float(entry[0]) and t - 1.0 / HZ < float(entry[0]):
				v.model.order([entry[1]], entry[2], entry[3])
		if i % 9 == 0:
			v.focus = Vector2(random.randf_range(-12, 12), random.randf_range(-10, 12))
			v.distance = random.randf_range(5.0, 65.0)
			v.azimuth = random.randf_range(-1.0, 1.0)
			v._place_camera()
		var before: Dictionary = {}
		if v.agents.agents.has(UID):
			before = _capture(v, v.agents.agents[UID])
		v._process(1.0 / HZ)
		var states: Dictionary = v.formation_render_states()
		if states.has(UID):
			var state: Dictionary = states[UID]
			var after := _capture(v, v.agents.agents[UID])
			minimum_rock_clearance = minf(minimum_rock_clearance, float(after.rock_after.clearance_m))
			samples += 1
			var evidence := {"uid": UID, "time_s": t, "before": before, "after": after,
				"rendered_detail": state.detail, "rendered_level": state.level, "represented": state.represented}
			if not previous.is_empty():
				var p: Vector3 = previous.position
				var q: Vector3 = state.position
				var step := Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z))
				evidence["previous_rendered_detail"] = previous.detail
				evidence["previous_rendered_level"] = previous.level
				evidence["rendered_step_m"] = step
				if step > max_step:
					max_step = step
					worst_step = evidence.duplicate(true)
				if state.pose in Soldier.STRIDES and previous.pose in Soldier.STRIDES:
					phase_samples += 1
					var phase_step := absf(wrapf(float(state.phase) - float(previous.phase), -.5, .5))
					evidence["rendered_phase_step"] = phase_step
					if phase_step > max_phase:
						max_phase = phase_step
						worst_phase = evidence.duplicate(true)
			if float(after.correction_m) > max_correction:
				max_correction = float(after.correction_m)
				worst_correction = evidence.duplicate(true)
			previous = state
		else:
			previous = {}
		if v.model.outcome != "ongoing":
			break
	check(samples > 100 and phase_samples > 10, "Target is actually sampled during locomotion")
	check(max_step <= step_limit, "Original rendered root-step limit (%.6f <= %.6f)" % [max_step, step_limit])
	check(max_phase <= phase_limit, "Original wrapped gait-phase limit (%.6f <= %.6f)" % [max_phase, phase_limit])
	check(minimum_rock_clearance >= -0.0001, "Replayed UID never penetrates the original rock clearance (%.6f m)" % minimum_rock_clearance)
	print("FORMATION_CONTACT_TRACE ", JSON.stringify({"samples": samples, "phase_samples": phase_samples,
		"max_step_m": max_step, "max_phase": max_phase, "max_correction_m": max_correction, "minimum_rock_clearance_m": minimum_rock_clearance,
		"step_limit_m": step_limit, "phase_limit": phase_limit, "worst_step": worst_step,
		"worst_phase": worst_phase, "worst_correction": worst_correction}))
	v.free()
	print("FORMATION_CONTACT_TRACE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
