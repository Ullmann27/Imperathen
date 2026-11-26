extends SceneTree
## Rendered-soldier kinematics of the production valley scene.
##
## godot --headless --path prototype --fixed-fps 60 \
##   --script res://tests/formation_motion_measurement.gd ++ <profile> <report.json> [large|normal] [seconds]
##
## The probe observes what is drawn: rig actor roots, the distant MultiMesh
## roots (CPU mirror of rank_stride.gdshader), pose, gait phase and detail per
## soldier id. It never writes to the battle model. One scripted, deterministic
## encounter covers march, wheel/re-form, charge contact, melee casualties and a
## camera dolly that crosses every LOD boundary repeatedly.

const Valley = preload("res://scripts/tactics/valley_scene.gd")
const Rules = preload("res://scripts/battle/battle_model.gd")
const Field = preload("res://scripts/battle/valley_field.gd")
const Ranks = preload("res://scripts/visuals/far_ranks.gd")
const Soldier = preload("res://scripts/visuals/soldier_visual.gd")
const HZ := 60.0
const BODY := 0.28
const FOOT_LEVER := 0.16
const SLIP_WINDOW := 30
const DRILL_SPACING := 0.70
const GAITS := ["march", "run", "retreat"]
const WINDOWS := [["approach", 0.0, 8.0], ["charge", 8.0, 20.0], ["battle", 20.0, 1e9]]

var profile := "balanced"
var output := ""
var large := false
var seconds := 70.0
var v
var tracks := {}
var dead := {}
var metrics := {}
var lod := {}
var identity := {}
var far_feet := {}
var rig_soles := {}
var frame := 0
var started_usec := 0
var report := {}
var figures_seen := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: ++ <profile> <report.json> [large]")
		quit(2)
		return
	profile = args[0]
	output = args[1]
	large = args.size() > 2 and args[2] == "large"
	if args.size() > 3:
		seconds = clampf(args[3].to_float(), 1.0, 120.0)
	_run.call_deferred()


func _blank() -> Dictionary:
	return {"soldier_frames": 0, "max_speed_m_s": 0.0, "speeds": [], "max_accel_m_s2": 0.0, "accels": [],
		"max_turn_deg_s": 0.0, "turns": [], "max_slip_speed_m_s": 0.0, "max_slip_0_5s_m": 0.0,
		"slip_windows_over_0_04_m": 0, "slip_windows_over_0_015_m": 0, "slip_windows": 0,
		"max_translation_slip_0_5s_m": 0.0, "translation_windows_over_0_04_m": 0, "translation_windows_over_0_015_m": 0,
		"max_rotation_slip_0_5s_m": 0.0, "worst": {}, "translation_over_0_04_by_pose": {},
		"same_unit_overlap_max_m": 0.0, "same_unit_overlap_pairs": 0, "same_unit_spacing_violations": 0,
		"cross_unit_overlap_max_m": 0.0, "cross_unit_overlap_pairs": 0, "rock_overlap_max_m": 0.0,
		"pair_samples": 0, "min_same_unit_distance_m": 1e9, "same_unit_closer_0_62_m": 0,
		"max_model_deviation_m": 0.0, "deviations": [],
		"max_formation_deviation_m": 0.0, "formation_deviations": []}


func _run() -> void:
	v = Valley.new()
	if large:
		for s: Dictionary in v.model.squads.values().duplicate():
			v.model._add_squad(s.id, s.name, s.side, s.kind, s.formation, Vector2(s.x, s.z), s.strength * 3)
	root.add_child(v)
	v.set_quality(profile)
	v.focus = Vector2(-7, 8)
	v.distance = 26
	v._place_camera()
	v.paused = false
	for w in WINDOWS:
		metrics[w[0]] = _blank()
	metrics.all = _blank()
	lod = {"events": 0, "rig_to_far": 0, "far_to_rig": 0, "rig_to_rig": 0, "level_changes": 0,
		"max_foot_jump_m": 0.0, "foot_jumps": [], "max_root_jump_m": 0.0, "worst": {},
		"min_seconds_between_switches": 1e9, "switches_within_1s": 0, "body_rebuilds": 0,
		"figure_bodies": 0, "figure_bodies_after_2s": 0}
	identity = {"duplicates": 0, "resurrections": 0, "unknown_rendered": 0, "missing_rendered": 0,
		"deaths": 0, "max_alive": 0, "alive_end": 0, "uids_seen": 0}
	for role: String in Soldier.ROLES:
		var vertices: PackedVector3Array = Soldier.far_mesh(role).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var feet := {"R": [], "L": []}
		for vertex in vertices:
			if vertex.y <= .10 and absf(vertex.x) <= .205:
				feet["R" if vertex.x < 0 else "L"].append(vertex)
		far_feet[role] = feet
	started_usec = Time.get_ticks_usec()
	var step_usec: Array = []
	var total := int(seconds * HZ)
	_observe(0.0)
	for i in range(1, total + 1):
		var t := float(i) / HZ
		_script(t)
		_snapshot_rigs()
		var before := Time.get_ticks_usec()
		v._process(1.0 / HZ)
		step_usec.append(Time.get_ticks_usec() - before)
		frame = i
		_observe(t)
		if i == int(2.0 * HZ) and v.has_method("formation_counters"):
			report["counters_at_2s"] = v.formation_counters()
		if v.model.outcome != "ongoing":
			break
	step_usec.sort()
	report_and_quit(step_usec)


func _script(t: float) -> void:
	var m = v.model
	if _at(t, 0.05):
		m.order(["valley_guard"], "move", Vector2(-7, 2))
		m.order(["valley_spears"], "deploy", {"start": Vector2(1, 6), "end": Vector2(8, 3.5)})
	if _at(t, 6.0):
		m.order(["valley_guard"], "form", "line")
	if _at(t, 8.0):
		m.order(["valley_guard"], "attack", "ridge_guard")
		m.order(["valley_spears"], "attack", "ridge_spears")
		m.order(["valley_bows"], "focus_fire", "ridge_guard")
	# The camera follows the line companies and dollies through every LOD band.
	var guard: Dictionary = m.squads.valley_guard
	v.focus = v.focus.lerp(Vector2(guard.x, guard.z), 0.05)
	v.distance = 26.0 + 20.0 * sin(TAU * t / 16.0)
	v.azimuth = 0.6 * sin(TAU * t / 40.0)
	v._place_camera()


func _at(t: float, mark: float) -> bool:
	return t >= mark and t - 1.0 / HZ < mark


func _role(s: Dictionary, id: String) -> String:
	var role := "spear" if s.kind == "spear" else ("archer" if s.kind == "archer" else "heavy")
	if id == s.officer_id and s.side == "ally" and s.kind == "infantry":
		role = "officer"
	return role


func _alive() -> Dictionary:
	var result := {}
	for s: Dictionary in v.model.squads.values():
		if s.strength <= 0:
			continue
		# A withdrawn company is alive and leaving: its men may still be drawn
		# on their way to the edge, but need not be.
		for man: Dictionary in v.model.soldiers(s.id):
			var uid: String = man.get("uid", man.id)
			result[uid] = {"squad": s.id, "side": s.side, "x": man.x, "z": man.z, "role": _role(s, man.id),
				"withdrawn": s.status == "withdrawn"}
	return result


func _states(alive: Dictionary) -> Dictionary:
	if v.has_method("formation_render_states"):
		return v.formation_render_states()
	# Baseline adapter: the same interpolation ValleyScene._process applies.
	var fraction := clampf(v.frame_remainder / Rules.STEP, 0.0, 1.0)
	var result := {}
	for id: String in alive:
		if not v.motion.has(id):
			continue
		var track: Dictionary = v.motion[id]
		var entry := {"position": track.start.lerp(track.end, fraction),
			"yaw": lerp_angle(track.start_yaw, track.yaw, fraction), "pose": track.pose,
			"phase": lerpf(track.phase0, track.phase1, fraction), "detail": 2, "role": alive[id].role}
		if v.actors.has(id):
			entry.position = v.actors[id].position
			entry.yaw = v.actors[id].rotation.y
			entry.detail = v.actors[id].detail
		result[id] = entry
	return result


func _far_gait(id: String, state: Dictionary) -> Color:
	if v.has_method("formation_far_gait"):
		return v.formation_far_gait(id)
	return Ranks.gait_data(state.pose, state.phase, state.phase)


func _sole_points(actor: Node3D) -> Dictionary:
	var rigs := actor.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		return {}
	var rig: Skeleton3D = rigs[0]
	var to_root := actor.global_transform.affine_inverse() * rig.global_transform
	var result := {}
	for side in ["R", "L"]:
		var bone := rig.find_bone("Foot_" + side)
		if bone < 0:
			return {}
		var binding := rig.get_bone_global_pose(bone) * rig.get_bone_global_rest(bone).affine_inverse()
		result[side] = [to_root * (binding * Vector3(-.126 if side == "R" else .126, .011, -.065)),
			to_root * (binding * Vector3(-.126 if side == "R" else .126, .011, .175))]
	return result


func _rig_nodes() -> Dictionary:
	if v.has_method("formation_rig_nodes"):
		return v.formation_rig_nodes()
	return v.actors


func _snapshot_rigs() -> void:
	rig_soles.clear()
	var nodes: Dictionary = _rig_nodes()
	for id: String in nodes:
		var actor: Node3D = nodes[id]
		if is_instance_valid(actor) and not actor.is_queued_for_deletion():
			var body: Variant = actor.get("_body")
			var key := "%d/%d" % [actor.get_instance_id(), body.get_instance_id() if body else 0]
			if not figures_seen.has(key):
				figures_seen[key] = true
				lod.figure_bodies += 1
				if frame > int(2.0 * HZ):
					lod.figure_bodies_after_2s += 1
			rig_soles[id] = {"soles": _sole_points(actor), "body": actor.get("_body"), "node": actor,
				"clip": str(actor.get("state")), "blending": actor.has_method("blending") and actor.blending()}


func _foot_jump(role: String, soles: Dictionary, gait: Color) -> float:
	var worst := 0.0
	for side in ["R", "L"]:
		if not soles.has(side):
			continue
		for sole: Vector3 in soles[side]:
			var closest := INF
			for vertex: Vector3 in far_feet[role][side]:
				closest = minf(closest, sole.distance_to(Ranks.deformed_vertex(vertex, gait, 1.0)))
			worst = maxf(worst, closest)
	return worst


func _push(sample: Dictionary, key: String, list_key: String, value: float) -> void:
	sample[key] = maxf(float(sample[key]), value)
	sample[list_key].append(value)


func _window(t: float) -> String:
	for w in WINDOWS:
		if t >= w[1] and t < w[2]:
			return w[0]
	return "battle"


func _observe(t: float) -> void:
	var alive := _alive()
	var states := _states(alive)
	var window: Dictionary = metrics[_window(t)]
	identity.max_alive = maxi(identity.max_alive, alive.size())
	identity.alive_end = alive.size()
	for uid: String in alive:
		if dead.has(uid):
			identity.resurrections += 1
	for uid: String in states:
		if not alive.has(uid):
			identity.unknown_rendered += 1
	for uid: String in alive:
		if not states.has(uid) and not alive[uid].withdrawn:
			identity.missing_rendered += 1
	if v.has_method("formation_duplicate_count"):
		identity.duplicates += v.formation_duplicate_count()
	else:
		var far_count := 0
		for role: String in v.far_ranks.instance_tracks:
			far_count += v.far_ranks.instance_tracks[role].ends.size()
		var rigs := 0
		for id: String in v.actors:
			if alive.has(id):
				rigs += 1
		identity.duplicates += maxi(0, rigs + far_count - alive.size())
	for uid: String in tracks.keys():
		if not alive.has(uid):
			dead[uid] = true
			identity.deaths += 1
			tracks.erase(uid)
	var dt := 1.0 / HZ
	var rigs_now: Dictionary = _rig_nodes()
	var places := {}
	for uid: String in alive:
		if not places.has(alive[uid].squad):
			places[alive[uid].squad] = []
		places[alive[uid].squad].append(Vector2(alive[uid].x, alive[uid].z))
	for uid: String in states:
		if not alive.has(uid):
			continue
		var state: Dictionary = states[uid]
		var p := Vector2(state.position.x, state.position.z)
		var deviation := p.distance_to(Vector2(alive[uid].x, alive[uid].z))
		for sample: Dictionary in [window, metrics.all]:
			if deviation > float(sample.max_model_deviation_m):
				sample.worst.deviation = {"uid": uid, "t": snappedf(t, 0.001), "m": deviation,
					"status": v.model.squads[alive[uid].squad].status, "command": v.model.squads[alive[uid].squad].command}
			_push(sample, "max_model_deviation_m", "deviations", deviation)
		# Shape agreement: distance to the nearest rule-model member position of
		# the same company, whoever the model assigns to that place.
		var nearest := INF
		for place: Vector2 in places[alive[uid].squad]:
			nearest = minf(nearest, p.distance_to(place))
		for sample: Dictionary in [window, metrics.all]:
			if nearest > float(sample.max_formation_deviation_m):
				sample.worst.formation_deviation = {"uid": uid, "t": snappedf(t, 0.001), "m": nearest,
					"status": v.model.squads[alive[uid].squad].status, "command": v.model.squads[alive[uid].squad].command}
			_push(sample, "max_formation_deviation_m", "formation_deviations", nearest)
		if not tracks.has(uid):
			tracks[uid] = {"p": p, "history": [p], "yaw": float(state.yaw), "vel": Vector2.ZERO, "phase": float(state.phase),
				"pose": str(state.pose), "detail": int(state.detail), "slips": [], "switch_t": -1e9,
				"level": str(state.get("level", ""))}
			identity.uids_seen += 1
			continue
		var track: Dictionary = tracks[uid]
		var history: Array = track.history
		history.append(p)
		if history.size() > 5:
			history.pop_front()
		var dp: Vector2 = p - track.p
		var dyaw := absf(angle_difference(float(track.yaw), float(state.yaw)))
		var vel := dp / dt
		var pose := str(state.pose)
		# Translation slip: root travel that the visible gait phase does not
		# account for. Rotation slip: planted feet swept by a root yaw change.
		var translation := 0.0
		if pose == "death":
			translation = 0.0
		elif pose in GAITS and str(track.pose) in GAITS:
			var dphi := fposmod(float(state.phase) - float(track.phase) + 0.5, 1.0) - 0.5
			var forward := Vector2(sin(float(state.yaw)), cos(float(state.yaw)))
			translation = (dp - forward * dphi * float(Soldier.STRIDES[pose])).length()
		else:
			translation = dp.length()
		var rotation := 0.0 if pose == "death" else dyaw * FOOT_LEVER
		var slip := translation + rotation
		var slips: Array = track.slips
		slips.append(Vector2(translation, rotation))
		if slips.size() > SLIP_WINDOW:
			slips.pop_front()
		var moved := Vector2.ZERO
		for value: Vector2 in slips:
			moved += value
		var accumulated := moved.x + moved.y
		var context := {"uid": uid, "t": snappedf(t, 0.001), "pose": pose, "previous_pose": track.pose,
			"detail": int(state.detail), "level": str(state.get("level", "")),
			"squad": alive[uid].squad, "status": v.model.squads[alive[uid].squad].status,
			"command": v.model.squads[alive[uid].squad].command}
		for sample: Dictionary in [window, metrics.all]:
			sample.soldier_frames += 1
			if vel.length() > float(sample.max_speed_m_s):
				sample.worst.speed = context.merged({"m_s": vel.length()})
			_push(sample, "max_speed_m_s", "speeds", vel.length())
			# Acceleration over 1/30 s intervals (one agent tick), so a speed
			# change applied once per tick is not reported twice as large.
			var accel := 0.0
			if history.size() >= 5:
				var recent: Vector2 = (history[4] - history[2]) / (2.0 * dt)
				var earlier: Vector2 = (history[2] - history[0]) / (2.0 * dt)
				accel = (recent - earlier).length() / (2.0 * dt)
			if accel > float(sample.max_accel_m_s2):
				sample.worst.accel = context.merged({"m_s2": accel})
			_push(sample, "max_accel_m_s2", "accels", accel)
			if rad_to_deg(dyaw) / dt > float(sample.max_turn_deg_s):
				sample.worst.turn = context.merged({"deg_s": rad_to_deg(dyaw) / dt})
			_push(sample, "max_turn_deg_s", "turns", rad_to_deg(dyaw) / dt)
			sample.max_slip_speed_m_s = maxf(sample.max_slip_speed_m_s, slip / dt)
			if slips.size() == SLIP_WINDOW:
				if accumulated > float(sample.max_slip_0_5s_m):
					sample.worst.slip = context.merged({"m": accumulated, "translation_m": moved.x, "rotation_m": moved.y})
				sample.max_slip_0_5s_m = maxf(sample.max_slip_0_5s_m, accumulated)
				sample.max_translation_slip_0_5s_m = maxf(sample.max_translation_slip_0_5s_m, moved.x)
				sample.max_rotation_slip_0_5s_m = maxf(sample.max_rotation_slip_0_5s_m, moved.y)
				sample.slip_windows += 1
				if accumulated > 0.04:
					sample.slip_windows_over_0_04_m += 1
				if accumulated > 0.015:
					sample.slip_windows_over_0_015_m += 1
				if moved.x > 0.04:
					sample.translation_windows_over_0_04_m += 1
					var kind := "gait" if pose in GAITS else ("action" if pose in ["attack", "hit", "shoot", "block"] else "stance")
					if pose != str(track.pose):
						kind += "_change"
					sample.translation_over_0_04_by_pose[kind] = int(sample.translation_over_0_04_by_pose.get(kind, 0)) + 1
				if moved.x > 0.015:
					sample.translation_windows_over_0_015_m += 1
		# Level-of-detail switches at the same instant: rig pose versus far mirror.
		var detail := int(state.detail)
		if detail != int(track.detail):
			lod.events += 1
			var since: float = t - float(track.switch_t)
			lod.min_seconds_between_switches = minf(lod.min_seconds_between_switches, since)
			if since < 1.0:
				lod.switches_within_1s += 1
			track.switch_t = t
			var jump := -1.0
			if int(track.detail) < 2 and detail >= 2:
				lod.rig_to_far += 1
				if rig_soles.has(uid) and not rig_soles[uid].soles.is_empty():
					jump = _foot_jump(str(state.role), rig_soles[uid].soles, track.get("far_gait", _far_gait(uid, state)))
			elif int(track.detail) >= 2 and detail < 2:
				lod.far_to_rig += 1
				if rigs_now.has(uid):
					jump = _foot_jump(str(state.role), _sole_points(rigs_now[uid]), _far_gait(uid, state))
			else:
				lod.rig_to_rig += 1
			if jump >= 0.0:
				lod.foot_jumps.append(jump)
				if jump > lod.max_foot_jump_m:
					lod.max_foot_jump_m = jump
					lod.worst = {"uid": uid, "t": t, "pose": pose, "phase": state.phase, "from": track.detail, "to": detail,
						"previous_pose": track.pose, "rig_clip": rig_soles.get(uid, {}).get("clip", ""),
						"rig_blending": rig_soles.get(uid, {}).get("blending", false)}
		# A figure that rebuilt its body in place (instancing a new scene).
		if rig_soles.has(uid) and rigs_now.has(uid) and rig_soles[uid].node == rigs_now[uid] \
				and rig_soles[uid].body != rigs_now[uid].get("_body"):
			lod.body_rebuilds += 1
		if str(state.get("level", "")) != str(track.level):
			lod.level_changes += 1
		track.p = p
		track.yaw = float(state.yaw)
		track.vel = vel
		track.phase = float(state.phase)
		track.pose = pose
		track.detail = detail
		track.level = str(state.get("level", ""))
		track.far_gait = _far_gait(uid, state)
	if frame % 2 == 0:
		_pairs(states, alive, window)


func _pairs(states: Dictionary, alive: Dictionary, window: Dictionary) -> void:
	var grid := {}
	var points := {}
	for uid: String in states:
		if not alive.has(uid) or str(states[uid].pose) == "death":
			continue
		var p := Vector2(states[uid].position.x, states[uid].position.z)
		points[uid] = p
		var cell := Vector2i(floori(p.x), floori(p.y))
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(uid)
		for rock in Field.ROCKS:
			var inside: float = float(rock.radius) + BODY - p.distance_to(Vector2(rock.x, rock.z))
			for sample: Dictionary in [window, metrics.all]:
				sample.rock_overlap_max_m = maxf(sample.rock_overlap_max_m, inside)
	for uid: String in points:
		var p: Vector2 = points[uid]
		var cell := Vector2i(floori(p.x), floori(p.y))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for other: String in grid.get(cell + Vector2i(dx, dz), []):
					if other <= uid:
						continue
					var d: float = p.distance_to(points[other])
					var same: bool = alive[uid].squad == alive[other].squad
					for sample: Dictionary in [window, metrics.all]:
						sample.pair_samples += 1
						if d < 2.0 * BODY:
							var key := "same_unit_overlap_max_m" if same else "cross_unit_overlap_max_m"
							if 2.0 * BODY - d > float(sample[key]):
								sample.worst[key] = {"a": uid, "b": other, "m": 2.0 * BODY - d, "t": snappedf(float(frame) / HZ, 0.001),
									"a_level": str(states[uid].get("level", "")), "b_level": str(states[other].get("level", "")),
									"a_status": v.model.squads[alive[uid].squad].status, "b_status": v.model.squads[alive[other].squad].status}
							if same:
								sample.same_unit_overlap_pairs += 1
								sample.same_unit_overlap_max_m = maxf(sample.same_unit_overlap_max_m, 2.0 * BODY - d)
							else:
								sample.cross_unit_overlap_pairs += 1
								sample.cross_unit_overlap_max_m = maxf(sample.cross_unit_overlap_max_m, 2.0 * BODY - d)
						if same and d < DRILL_SPACING:
							sample.same_unit_spacing_violations += 1
						if same:
							sample.min_same_unit_distance_m = minf(sample.min_same_unit_distance_m, d)
							if d < 0.62:
								sample.same_unit_closer_0_62_m += 1


func _percentile(values: Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	values.sort()
	return float(values[clampi(ceili(values.size() * q) - 1, 0, values.size() - 1)])


func report_and_quit(step_usec: Array) -> void:
	var summary := {}
	for key: String in metrics:
		var sample: Dictionary = metrics[key]
		var row := {}
		for field: String in sample:
			if typeof(sample[field]) != TYPE_ARRAY:
				row[field] = sample[field]
		row.p99_speed_m_s = _percentile(sample.speeds, .99)
		row.p99_accel_m_s2 = _percentile(sample.accels, .99)
		row.p99_turn_deg_s = _percentile(sample.turns, .99)
		row.p99_model_deviation_m = _percentile(sample.deviations, .99)
		row.p99_formation_deviation_m = _percentile(sample.formation_deviations, .99)
		summary[key] = row
	var lod_row := lod.duplicate()
	lod_row.erase("foot_jumps")
	lod_row.p95_foot_jump_m = _percentile(lod.foot_jumps, .95)
	lod_row.measured_switches = lod.foot_jumps.size()
	var counters := {}
	if v.has_method("formation_counters"):
		counters = v.formation_counters()
		counters["rig_instantiations_after_2s"] = int(counters.rig_instantiations) - int(report.get("counters_at_2s", {}).get("rig_instantiations", 0))
	var result := {"profile": profile, "large": large, "frames": frame, "seconds": frame / HZ,
		"outcome": v.model.outcome, "model_steps": v.model.steps,
		"adapter": "formation_render_states" if v.has_method("formation_render_states") else "baseline_tracks",
		"metrics": summary, "lod": lod_row, "identity": identity, "counters": counters,
		"process_usec": {"p50": _percentile(step_usec, .5), "p95": _percentile(step_usec, .95), "p99": _percentile(step_usec, .99)},
		"notes": "Translation slip: rendered root travel minus gait phase x clip stride; non-gait poses count all root travel. Rotation slip: |yaw change| x 0.16 m planted-foot lever. Sums over 0.5 s windows. References: crowd 0.04 m, human 0.015 m (motion_quality_gate.py FAMILY_LIMITS)."}
	var handle := FileAccess.open(output, FileAccess.WRITE)
	if handle:
		handle.store_string(JSON.stringify(result, "  ") + "\n")
		handle.close()
	print("FORMATION_MEASURED ", JSON.stringify({"profile": profile, "frames": frame, "max_speed": summary.all.max_speed_m_s,
		"max_slip_0_5s": summary.all.max_slip_0_5s_m, "same_overlap": summary.all.same_unit_overlap_max_m,
		"cross_overlap": summary.all.cross_unit_overlap_max_m, "lod_jump": lod.max_foot_jump_m, "identity": identity}))
	v.free()
	quit(0)
