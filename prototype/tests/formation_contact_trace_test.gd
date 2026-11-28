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

func _run() -> void:
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
	print("FORMATION_CONTACT_TRACE ", JSON.stringify({"samples": samples, "phase_samples": phase_samples,
		"max_step_m": max_step, "max_phase": max_phase, "max_correction_m": max_correction,
		"step_limit_m": step_limit, "phase_limit": phase_limit, "worst_step": worst_step,
		"worst_phase": worst_phase, "worst_correction": worst_correction}))
	v.free()
	print("FORMATION_CONTACT_TRACE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
