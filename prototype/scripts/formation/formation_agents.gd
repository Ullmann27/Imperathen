extends RefCounted
## Level-B soldier agents (D-026, middle distance): one persistent agent per
## soldier uid in the battle model's authoritative roster.
##
## The battle model owns who exists, unit centres, facing, formation, strength,
## commands, morale and hit events. This layer owns only how each existing
## soldier physically gets to and keeps his place: speed, acceleration and turn
## limits by troop kind and load, stable slot assignment, wheeling, marching in
## step, charge surge and stop on contact, spacing and interpenetration.
## It never writes to the model. A soldier who leaves the roster dies here once
## and can never be recreated; level changes only alter how an agent is
## integrated, never whether it exists.

const Rules := preload("res://scripts/battle/battle_model.gd")
const Field := preload("res://scripts/battle/valley_field.gd")
const Slots := preload("res://scripts/battle/formation_slots.gd")
const Troop := preload("res://scripts/formation/troop_motion.gd")
const Soldier := preload("res://scripts/visuals/soldier_visual.gd")

const HZ := 30
const DT := 1.0 / 30.0
const TICKS_PER_STEP := 6
const LEVEL_A := 0
const LEVEL_B := 1
const LEVEL_C := 2
const SETTLE_M := 0.06
const RESUME_M := 0.14
const SAME_SPACING_M := 0.70
const FRIEND_SPACING_M := 0.66
const CONTACT_M := 0.92
const HARD_SAME_M := 0.58
const HARD_ENEMY_M := 0.78
const PUSH_M_S := 1.4
const ENEMY_BRAKE_BAND_M := 3.5
const CONTACT_SETTLE_M := 0.45
const CONTACT_DRESS_M_S := 0.8
const CONTACT_HOLD_M := 2.0
const ROCK_CLEARANCE_M := 0.3
const REFILE_DEG := Rules.REFILE_DEG
const WHEEL_SHARE := 0.8
const LEAD_MAX_M := 2.2
const LEAD_RATE := 1.5
const PHASE_LOCK := 0.012
const STEP_OFFSET := 0.04
const DEATH_SECONDS := 1.25
const GAIT_HOLD_TICKS := 12
const ACTION_SPEED_M_S := 0.08
const LEAVE_EDGE_M := 1.2
const LEAVE_SECONDS := 10.0
const ACTIONS := ["attack", "shoot", "block", "hit"]


class Agent:
	var uid := ""
	var squad := ""
	var side := ""
	var kind := "infantry"
	var role := "heavy"
	var appearance_seed := 0
	var military_rank := ""
	var troop_id := ""
	var limits: Dictionary = {}
	var pos := Vector2.ZERO
	var prev_pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var speed := 0.0
	var yaw := 0.0
	var prev_yaw := 0.0
	var phase := 0.0
	var prev_phase := 0.0
	var pose := "idle"
	var prev_pose := "idle"
	var gait := "idle"
	var model_pose := "idle"
	var model_target := Vector2.ZERO
	var model_slot := -1
	var action_restart := false
	var slot := 0
	var level := 1
	var level_since := -1e9
	var detail := 2
	var detail_since := -1e9
	var camera_distance := 0.0
	var visible := true
	var external := false
	var settled := true
	var drum_offset := 0.0
	var free_phase := 0.0
	var contact := false
	var died_at := -1.0
	var desired := Vector2.ZERO
	var heading := 0.0
	var reverse := false
	var cap := 0.0
	var stagger := 0
	var crowded := true
	var correction := Vector2.ZERO
	var gait_tick := -1000
	# Hot-loop copies of the troop limits and of the company (no lookups).
	var unit: Object = null
	var l_walk := 0.0
	var l_run := 0.0
	var l_charge := 0.0
	var l_accel := 0.0
	var l_brake := 0.0
	var l_turn := 0.0
	var l_lateral := 0.0
	var l_back := 0.0
	var serial := 0
	var foe_distance := INF
	var asleep := false
	var leaving := false
	var leave_since := 0.0


class Unit:
	var id := ""
	var side := ""
	var kind := "infantry"
	var culture := ""
	var formation := "line"
	var strength := 0
	var width := 0.0
	var status := "ready"
	var command := "hold"
	var target := ""
	var discipline := 0
	var morale := 0.0
	var prev_center := Vector2.ZERO
	var center := Vector2.ZERO
	var prev_facing := 0.0
	var model_facing := 0.0
	var facing := 0.0
	var frame_center := Vector2.ZERO
	var velocity := Vector2.ZERO
	var layout := ""
	var offsets: Array[Vector2] = []
	var owners: Array[String] = []
	var slot_world: Array[Vector2] = []
	var slot_last: Array[Vector2] = []
	var slot_vel: Array[Vector2] = []
	var half_width := 0.5
	var needs_match := true
	# Refiles are discrete authoritative front changes, not visual wheel lag.
	var refile_snapshot := -1
	var applied_refile_snapshot := -1
	var refiles := 0
	var rematches := 0
	var drum := 0.0
	var in_step := false
	var lead := 0.0
	var gap := INF
	var charging := false
	var members: Array[String] = []
	var limits: Dictionary = {}
	var initialised := false
	var step_sum := 0.0
	var step_count := 0
	var enemy_near := false


var agents: Dictionary = {}
var units: Dictionary = {}
var fallen: Dictionary = {}
var dead_uids: Dictionary = {}
var withdrawn_uids: Dictionary = {}
var tick := 0
var snapshot_step := -1
var counters := {"created": 0, "deaths": 0, "withdrawn": 0, "rejected_resurrections": 0,
	"rematches": 0, "refiles": 0, "substeps": 0, "skipped_ticks": 0, "external": 0}
var first_stride_probe := -1
var last_match := {}
var timing := {}
var first_stride: Dictionary = {}
# Flat spatial grid per side, 1 m cells over the bounded valley field.
const GRID_W := 57
const GRID_H := 45
var _cells: Dictionary = {}
var _used: Dictionary = {}
var _friends: Array = []
var _foes: Array = []
var _serial := 0
var _rock_centres := PackedVector2Array()
var _rock_radii := PackedFloat32Array()


## Agent clock: tick / HZ - Rules.STEP. Rendering and agents run one battle step
## behind the rules (as the previous interpolation did), so every agent target
## is an interpolation between two actual rule states.
func agent_time() -> float:
	return float(tick) / HZ - Rules.STEP


func _init() -> void:
	for rock in Field.ROCKS:
		_rock_centres.append(Vector2(rock.x, rock.z))
		# Same clearance as Field.project uses for slots (MARGIN + 0.01).
		_rock_radii.append(float(rock.radius) + ROCK_CLEARANCE_M + 0.01)


static func model_time(model) -> float:
	return model.steps * Rules.STEP + float(model.get("_remainder"))


## Fraction between the previous and the current agent tick at the presented
## time. Rig actors and distant instances use the same value.
func render_fraction(model) -> float:
	return clampf(model_time(model) * HZ - float(tick), 0.0, 1.0)


func advance(model) -> int:
	sync_model(model)
	var target := floori(model_time(model) * HZ + 0.000001)
	# Ticks [6k, 6k+6] interpolate rule states k-1 -> k. The tick just before a
	# new rule step still belongs to the previous pair and clamps to its end.
	var lower := (snapshot_step - 1) * TICKS_PER_STEP
	if tick < lower:
		# Several rule steps arrived in one frame. Agents keep their physical
		# state and continue from the oldest available rule interpolation.
		counters.skipped_ticks += lower - tick
		tick = lower
	var count := 0
	while tick < target:
		_substep()
		count += 1
	return count


static func _role(s: Dictionary, soldier_id: String) -> String:
	var role := "spear" if s.kind in ["spear", "skirmisher", "cavalry"] else ("archer" if s.kind == "archer" else "heavy")
	if soldier_id == s.officer_id and s.side == "ally" and s.kind == "infantry":
		role = "officer"
	return role


static func uid_of(man: Dictionary) -> String:
	return str(man.id)


func sync_model(model) -> void:
	if model.steps == snapshot_step and model.squads.size() == units.size():
		return
	var previous_step := snapshot_step
	var first := previous_step < 0
	if first:
		tick = floori(model_time(model) * HZ + 0.000001)
	snapshot_step = model.steps
	var seen := {}
	for s: Dictionary in model.squads.values():
		var u: Unit = units.get(s.id)
		if u == null:
			u = Unit.new()
			u.id = s.id
			units[s.id] = u
		_snapshot_unit(u, s, previous_step)
		if s.status == "withdrawn":
			# The rules take the company off the field once its centre reaches
			# the edge. Its men are alive: they keep running until they reach
			# the edge themselves and only then leave (no vanishing mid-field).
			for uid: String in u.members:
				if agents.has(uid):
					seen[uid] = true
					if not agents[uid].leaving:
						agents[uid].leaving = true
						agents[uid].leave_since = agent_time()
			continue
		var roster: Array = model.soldiers(s.id)
		var members: Array[String] = []
		for index in roster.size():
			var man: Dictionary = roster[index]
			var uid := uid_of(man)
			members.append(uid)
			seen[uid] = true
			if dead_uids.has(uid):
				counters.rejected_resurrections += 1
				members.pop_back()
				continue
			var agent: Agent = agents.get(uid)
			if agent == null:
				agent = _create(uid, s, man, u, index)
			if agent.squad != s.id:
				agent.squad = s.id
				agent.unit = u
				agent.side = s.side
				u.needs_match = true
			agent.appearance_seed = int(man.appearance_seed)
			agent.military_rank = str(man.military_rank)
			agent.troop_id = str(s.troop_id)
			if agent.kind != u.kind:
				agent.kind = u.kind
				_set_limits(agent, u)
			var pose := str(man.pose)
			agent.action_restart = agent.action_restart or (pose in ACTIONS and pose != agent.model_pose)
			agent.model_pose = pose
			agent.model_target = Vector2(man.x, man.z)
			agent.model_slot = int(man.slot.index)
			agent.role = _role(s, str(man.id))
		if members != u.members:
			u.needs_match = true
		u.members = members
	for uid: String in agents.keys():
		if not seen.has(uid):
			_die(uid)


func _snapshot_unit(u: Unit, s: Dictionary, previous_step: int) -> void:
	var center := Vector2(s.x, s.z)
	# Only adjacent rule snapshots establish a discrete turn. Accumulated
	# presentation lag or a skipped sequence is not evidence of re-filing.
	if u.initialised and snapshot_step == previous_step + 1 and absf(angle_difference(u.model_facing, float(s.facing))) > deg_to_rad(REFILE_DEG):
		u.refile_snapshot = snapshot_step
	u.prev_center = center if not u.initialised else u.center
	u.prev_facing = float(s.facing) if not u.initialised else u.model_facing
	u.center = center
	u.model_facing = float(s.facing)
	if not u.initialised:
		u.facing = float(s.facing)
		u.frame_center = center
		u.initialised = true
	u.side = s.side
	u.kind = "spear" if s.kind == "cavalry" and not s.mounted else s.kind
	u.culture = str(Rules.Catalog.troop(Rules.Catalog.load_default(), s.troop_id).get("culture", ""))
	u.discipline = int(s.discipline)
	u.morale = float(s.morale)
	u.status = s.status
	u.command = s.command
	u.target = s.target
	u.limits = Troop.limits(u.kind)
	u.in_step = u.culture == "roman" and u.discipline >= 65 and s.formation != "loose"
	var layout := "%s/%d/%.2f" % [s.formation, s.strength, float(s.width)]
	if layout != u.layout:
		u.layout = layout
		u.formation = s.formation
		u.strength = int(s.strength)
		u.width = float(s.width)
		var spacing := 2.1 if s.kind == "cavalry" else 1.0
		u.offsets = Slots.offsets(u.formation, u.strength, u.width / spacing)
		for i in u.offsets.size():
			u.offsets[i] *= spacing
		u.half_width = 0.5
		for offset in u.offsets:
			u.half_width = maxf(u.half_width, absf(offset.x))
		u.needs_match = true


func _set_limits(a: Agent, u: Unit) -> void:
	a.limits = u.limits
	a.l_walk = float(a.limits.walk)
	a.l_run = float(a.limits.run)
	a.l_charge = float(a.limits.charge)
	a.l_accel = float(a.limits.accel)
	a.l_brake = float(a.limits.brake)
	a.l_turn = deg_to_rad(float(a.limits.turn))
	a.l_lateral = float(a.limits.lateral_accel)
	a.l_back = float(a.limits.back)


func _create(uid: String, s: Dictionary, man: Dictionary, u: Unit, index: int) -> Agent:
	var a := Agent.new()
	a.uid = uid
	a.squad = s.id
	a.side = s.side
	a.kind = u.kind
	a.role = _role(s, str(man.id))
	a.appearance_seed = int(man.appearance_seed)
	a.military_rank = str(man.military_rank)
	a.troop_id = str(s.troop_id)
	a.unit = u
	_set_limits(a, u)
	a.pos = Vector2(man.x, man.z)
	a.prev_pos = a.pos
	a.yaw = float(s.facing) + PI
	a.prev_yaw = a.yaw
	a.heading = a.yaw
	a.stagger = posmod(uid.hash(), 3)
	_serial += 1
	a.serial = _serial
	a.model_pose = str(man.pose)
	a.model_target = a.pos
	# Individual offsets around the company step follow a golden-ratio sequence
	# of the roster position at first sight, so neighbours in a rank never share
	# an identical phase (not robotic) yet stay within +-0.04 cycles (in step).
	a.drum_offset = (fposmod(float(index) * 0.618034, 1.0) - 0.5) * 2.0 * STEP_OFFSET
	a.free_phase = fposmod(float(posmod(uid.hash(), 997)) / 997.0 + float(index) * 0.381966, 1.0)
	a.phase = fposmod(u.drum + a.drum_offset, 1.0) if u.in_step else a.free_phase
	a.prev_phase = a.phase
	a.pose = "wall" if u.formation == "shield_wall" else ("testudo" if u.formation == "testudo" else "idle")
	a.prev_pose = a.pose
	agents[uid] = a
	counters.created += 1
	return a


func _die(uid: String) -> void:
	var a: Agent = agents[uid]
	agents.erase(uid)
	dead_uids[uid] = true
	a.died_at = agent_time()
	a.prev_pos = a.pos
	a.prev_yaw = a.yaw
	a.prev_pose = a.pose
	a.pose = "death"
	a.phase = 0.0
	a.prev_phase = 0.0
	a.speed = 0.0
	a.vel = Vector2.ZERO
	fallen[uid] = a
	counters.deaths += 1


## Every slot assignment is a minimum-distance matching from where soldiers
## actually stand (greedy start, pairwise exchange). Sum-of-distance optimal
## assignments never cross paths, so a re-formed or thinned company does not
## shuffle men through each other. A model-provided slot index wins.
func _match(u: Unit, frame_center: Vector2) -> void:
	u.needs_match = false
	var n := mini(u.members.size(), u.offsets.size())
	u.owners.resize(u.offsets.size())
	u.owners.fill("")
	if n == 0:
		return
	counters.rematches += 1
	u.rematches += 1
	var world: Array[Vector2] = []
	for offset in u.offsets:
		world.append(Field.project(frame_center + offset.rotated(-u.facing)))
	var provided := true
	var occupied := {}
	for uid: String in u.members:
		var slot: int = agents[uid].model_slot
		if slot < 0 or slot >= u.offsets.size() or occupied.has(slot):
			provided = false
			break
		occupied[slot] = true
	if provided:
		# Record real assignments, including the authoritative fast path.
		# This evidence does not introduce a second slot authority.
		var authority_record := {"unit":u.id, "tick":tick, "source":"authority", "uids":[], "from":[], "to":[], "by_index":world.duplicate()}
		for uid: String in u.members:
			var slot: int = agents[uid].model_slot
			u.owners[slot] = uid
			agents[uid].slot = slot
			authority_record.uids.append(uid)
			authority_record.from.append(agents[uid].pos)
			authority_record.to.append(world[slot])
		last_match[u.id] = authority_record
		return
	var pairs := []
	for i in n:
		var p: Vector2 = agents[u.members[i]].pos
		for j in world.size():
			pairs.append([p.distance_squared_to(world[j]), i, j])
	pairs.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and (x[1] < y[1] or (x[1] == y[1] and x[2] < y[2]))))
	var slot_of := PackedInt32Array()
	slot_of.resize(n)
	slot_of.fill(-1)
	var taken := {}
	for pair in pairs:
		if slot_of[pair[1]] < 0 and not taken.has(pair[2]):
			slot_of[pair[1]] = pair[2]
			taken[pair[2]] = true
	# Pairwise exchange until no swap shortens the total walk. A crossing pair
	# can always be shortened (triangle inequality), so none remains.
	for sweep in 64:
		var improved := false
		for i in n:
			var pi: Vector2 = agents[u.members[i]].pos
			for k in range(i + 1, n):
				var pk: Vector2 = agents[u.members[k]].pos
				var now := pi.distance_to(world[slot_of[i]]) + pk.distance_to(world[slot_of[k]])
				var swapped := pi.distance_to(world[slot_of[k]]) + pk.distance_to(world[slot_of[i]])
				# Equal sums happen for men on one line; the squared walk then
				# prefers keeping their order so nobody walks through a comrade.
				var tie := absf(swapped - now) <= 0.0001 and pi.distance_squared_to(world[slot_of[k]]) + pk.distance_squared_to(world[slot_of[i]]) \
					< pi.distance_squared_to(world[slot_of[i]]) + pk.distance_squared_to(world[slot_of[k]]) - 0.000001
				if swapped < now - 0.0001 or tie:
					var keep := slot_of[i]
					slot_of[i] = slot_of[k]
					slot_of[k] = keep
					improved = true
		if not improved:
			break
	var record := {"unit": u.id, "tick": tick, "source":"fallback", "uids":[], "from": [], "to": [], "by_index": world.duplicate()}
	for i in n:
		agents[u.members[i]].slot = slot_of[i]
		u.owners[slot_of[i]] = u.members[i]
		record.uids.append(u.members[i])
		record.from.append(agents[u.members[i]].pos)
		record.to.append(world[slot_of[i]])
	last_match[u.id] = record


func _update_frame(u: Unit, f: float) -> void:
	var center := u.prev_center.lerp(u.center, f)
	var model_facing := lerp_angle(u.prev_facing, u.model_facing, f)
	u.velocity = (center - u.frame_center) / DT
	u.frame_center = center
	if u.refile_snapshot == snapshot_step:
		# The rules already chose the new rank authority for this discrete
		# front change. Consume the refile exactly once, and do not rotate
		# back toward the old interpolated front on later substeps.
		u.facing = u.model_facing
		if u.applied_refile_snapshot != snapshot_step:
			u.applied_refile_snapshot = snapshot_step
			u.needs_match = true
			u.refiles += 1
			counters.refiles += 1
	else:
		# Wheel about the centre: the outer file never exceeds 80 % of run speed.
		var rate := float(u.limits.run) * WHEEL_SHARE / maxf(1.0, u.half_width)
		u.facing = rotate_toward(u.facing, model_facing, rate * DT)
	if u.needs_match:
		_match(u, center)
	var count := u.offsets.size()
	var reset := u.slot_world.size() != count
	u.slot_world.resize(count)
	u.slot_last.resize(count)
	u.slot_vel.resize(count)
	var near_obstacle := absf(center.x) + u.half_width * 2.0 + 2.0 > Field.LIMIT.x or absf(center.y) + u.half_width * 2.0 + 2.0 > Field.LIMIT.y
	for r in _rock_centres.size():
		near_obstacle = near_obstacle or center.distance_to(_rock_centres[r]) < _rock_radii[r] + u.half_width * 2.0 + 2.0
	var basis_x := Vector2(cos(-u.facing), sin(-u.facing))
	var basis_y := Vector2(-basis_x.y, basis_x.x)
	for i in count:
		var offset: Vector2 = u.offsets[i]
		var world := center + basis_x * offset.x + basis_y * offset.y
		if near_obstacle:
			world = Field.project(world)
		if reset:
			u.slot_last[i] = world
		u.slot_vel[i] = (world - u.slot_last[i]) / DT if not reset else Vector2.ZERO
		u.slot_last[i] = world
		u.slot_world[i] = world


static func _index(p: Vector2) -> int:
	return clampi(floori(p.x) + 28, 0, GRID_W - 1) * GRID_H + clampi(floori(p.y) + 22, 0, GRID_H - 1)


func _build_grid() -> void:
	for side: String in _used:
		var cells: Array = _cells[side]
		for index in _used[side]:
			cells[index].clear()
		_used[side] = PackedInt32Array()
	for a: Agent in agents.values():
		if a.level == LEVEL_C:
			continue
		if not _cells.has(a.side):
			var cells := []
			cells.resize(GRID_W * GRID_H)
			for i in cells.size():
				cells[i] = []
			_cells[a.side] = cells
			_used[a.side] = PackedInt32Array()
		var index := _index(a.pos)
		var cell: Array = _cells[a.side][index]
		if cell.is_empty():
			_used[a.side].append(index)
		cell.append(a)


## Agents of one side (or of every other side) within reach cells; the
## result array is reused, so callers consume it before the next gather.
func _gather(side: String, same: bool, p: Vector2, reach: int, out: Array) -> void:
	out.clear()
	var cx := clampi(floori(p.x) + 28, 0, GRID_W - 1)
	var cz := clampi(floori(p.y) + 22, 0, GRID_H - 1)
	for key: String in _cells:
		if (key == side) != same:
			continue
		var cells: Array = _cells[key]
		for x in range(maxi(0, cx - reach), mini(GRID_W - 1, cx + reach) + 1):
			var base := x * GRID_H
			for z in range(maxi(0, cz - reach), mini(GRID_H - 1, cz + reach) + 1):
				var cell: Array = cells[base + z]
				if not cell.is_empty():
					out.append_array(cell)


## Closest opponent seen by any man of the company during the last decision
## (the opponent search in _avoid records it), so the charge needs no extra
## company-against-company scan.
func _front_gap(u: Unit) -> float:
	var gap := INF
	for uid: String in u.members:
		gap = minf(gap, agents[uid].foe_distance)
	return gap


func _enemy_gap(u: Unit) -> float:
	var foe: Unit = units.get(u.target) if u.target != "" else null
	if foe == null or foe.members.is_empty():
		var best := INF
		for other: Unit in units.values():
			if other.side != u.side and not other.members.is_empty() and other.status not in ["routed", "withdrawn", "destroyed"]:
				var d := u.center.distance_to(other.center)
				if d < best:
					best = d
					foe = other
	if foe == null:
		return INF
	var gap := INF
	for uid: String in u.members:
		var p: Vector2 = agents[uid].pos
		for other: String in foe.members:
			if agents.has(other):
				gap = minf(gap, p.distance_to(agents[other].pos))
	return gap


func _update_charge(u: Unit) -> void:
	var pursuing := u.command in ["attack", "flank", "attack_move"] and u.kind != "archer"
	pursuing = pursuing and u.status not in ["routed", "withdrawn", "destroyed"] and u.morale >= 45.0
	u.gap = (_front_gap(u) if u.enemy_near else INF) if pursuing else INF
	if pursuing and u.gap <= float(u.limits.charge_start_m):
		# The surge integrates the remaining gap: it accelerates into the charge
		# and decays to zero as the front ranks reach weapon contact.
		u.lead = clampf(u.lead + clampf(u.gap - CONTACT_M, -1.0, 1.0) * LEAD_RATE * DT, 0.0, LEAD_MAX_M)
		u.charging = u.gap > CONTACT_M + 0.6
	else:
		u.lead = move_toward(u.lead, 0.0, 0.5 * DT)
		u.charging = false


func _substep() -> void:
	tick += 1
	counters.substeps += 1
	var clock := Time.get_ticks_usec()
	var f := clampf(float(tick - snapshot_step * TICKS_PER_STEP) / TICKS_PER_STEP, 0.0, 1.0)
	for u: Unit in units.values():
		u.enemy_near = false
		for other: Unit in units.values():
			if other.side != u.side and not other.members.is_empty() and \
					u.frame_center.distance_to(other.frame_center) < 2.0 * maxf(u.half_width, other.half_width) + 10.0:
				u.enemy_near = true
	for u: Unit in units.values():
		if u.members.is_empty():
			continue
		_update_frame(u, f)
		_update_charge(u)
	_build_grid()
	for a: Agent in agents.values():
		a.prev_pos = a.pos
		a.prev_yaw = a.yaw
		a.prev_pose = a.pose
		a.prev_phase = fposmod(a.phase, 1.0) if a.pose in Soldier.LOOPING else a.phase
		a.phase = a.prev_phase
	clock = _lap("units", clock)
	for a: Agent in agents.values():
		if a.external:
			continue
		if a.level == LEVEL_C:
			_aggregate_member(a)
		else:
			_decide(a)
			_integrate(a)
	clock = _lap("steer", clock)
	_resolve_contacts()
	clock = _lap("contacts", clock)
	for u: Unit in units.values():
		u.step_sum = 0.0
		u.step_count = 0
	for a: Agent in agents.values():
		_animate(a)
	# The company step ("drum") advances with the average step its marching men
	# actually take, so the lock pulls stragglers toward the group, never ahead
	# of what their feet do.
	for u: Unit in units.values():
		if u.step_count > 0:
			u.drum = fposmod(u.drum + u.step_sum / u.step_count, 1.0)
	for uid: String in agents.keys():
		var a: Agent = agents[uid]
		if a.leaving and (absf(a.pos.x) > Field.LIMIT.x - LEAVE_EDGE_M or absf(a.pos.y) > Field.LIMIT.y - LEAVE_EDGE_M \
				or agent_time() - a.leave_since > LEAVE_SECONDS):
			agents.erase(uid)
			units[a.squad].members.erase(uid)
			withdrawn_uids[uid] = true
			counters.withdrawn += 1
	for uid: String in fallen.keys():
		var a: Agent = fallen[uid]
		a.prev_phase = a.phase
		a.prev_pose = "death"
		a.phase = minf(1.0, a.phase + DT / Soldier.clip_length(a.role, "death"))
		if agent_time() - a.died_at > DEATH_SECONDS:
			fallen.erase(uid)
	_lap("animate", clock)


func _lap(phase: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	timing[phase] = int(timing.get(phase, 0)) + now - since
	return now


## An off-camera member shares the company's movement and casualty resolution.
## Keep the last presented root so returning to a rig never snaps to a new slot.
func _aggregate_member(a: Agent) -> void:
	var u := a.unit
	if a.slot < 0 or a.slot >= u.slot_world.size():
		return
	var goal: Vector2 = u.slot_world[a.slot]
	if a.leaving:
		goal = a.pos + Vector2(-sin(u.facing), -cos(u.facing)) * 3.0
	a.pos = _aggregate_step(a.pos, Field.project(goal), a.l_run * DT)
	a.vel = (a.pos - a.prev_pos) / DT
	a.speed = a.vel.length()
	a.yaw = rotate_toward(a.yaw, atan2(a.vel.x, a.vel.y) if a.speed > 0.1 else u.facing + PI, a.l_turn * DT)
	a.asleep = false
	a.contact = false
	a.crowded = false
	a.correction = Vector2.ZERO


## The cheap aggregate movement still owns a physical root. A projected goal
## alone does not make the intervening segment safe: crossing a rock while C
## caused the later B contact solver to eject the soldier by over a metre.
## Use the same clearance as the existing individual contact solver, and
## choose a bounded tangent step if the immediate segment is obstructed.
func _aggregate_segment_clear(from: Vector2, to: Vector2) -> bool:
	if not from.is_finite() or not to.is_finite():
		return false
	if from != from.clamp(-Field.LIMIT, Field.LIMIT) or to != to.clamp(-Field.LIMIT, Field.LIMIT):
		return false
	var length := from.distance_to(to)
	for r in _rock_centres.size():
		var radius := float(_rock_radii[r])
		var centre := _rock_centres[r]
		if from.distance_squared_to(centre) > (radius + length) * (radius + length):
			continue
		var nearest := from if from == to else Geometry2D.get_closest_point_to_segment(centre, from, to)
		if nearest.distance_squared_to(centre) < (radius - 0.00001) * (radius - 0.00001):
			return false
	return true


func _aggregate_step(at: Vector2, goal: Vector2, stride: float) -> Vector2:
	if stride <= 0.0 or not at.is_finite() or not goal.is_finite():
		return at
	# A legacy/external invalid position is recovered at ordinary travel speed;
	# this is not a licence to teleport the agent or move its roster slot.
	if not _aggregate_segment_clear(at, at):
		return at.move_toward(Field.project(at), stride)
	var direct := at.move_toward(goal, stride)
	if _aggregate_segment_clear(at, direct):
		return direct
	var best := at
	var best_distance := INF
	for r in _rock_centres.size():
		var offset := at - _rock_centres[r]
		var radius := float(_rock_radii[r])
		if offset.length_squared() > (radius + stride + 0.002) * (radius + stride + 0.002):
			continue
		var normal := offset.normalized()
		for side: float in [-1.0, 1.0]:
			# A small outward bias gives the tangent a safe chord around the
			# existing clearance circle. Never increase the step length.
			var direction := (normal.orthogonal() * side + normal * 0.05).normalized()
			var candidate := (at + direction * stride).clamp(-Field.LIMIT, Field.LIMIT)
			if not _aggregate_segment_clear(at, candidate):
				continue
			var score := candidate.distance_squared_to(goal)
			if score < best_distance:
				best_distance = score
				best = candidate
	return best


## Steering decision: where this man wants to go and how fast (slot, surge,
## arrival braking, spacing, contact, rocks). Level C decides at a third of
## the rate (staggered by uid) and keeps integrating the last decision.
func _decide(a: Agent) -> void:
	var u: Unit = a.unit
	if a.slot >= u.slot_world.size():
		a.desired = Vector2.ZERO
		return
	if a.asleep:
		# A settled man in a still company with no opponent near and nobody
		# pressing him stands still without searching neighbours.
		if u.enemy_near or u.lead > 0.0 or u.slot_vel[a.slot].length_squared() > 0.0025 \
				or a.pos.distance_squared_to(u.slot_world[a.slot]) > RESUME_M * RESUME_M \
				or a.correction.length_squared() > 0.000001 or a.model_pose in ACTIONS:
			a.asleep = false
		else:
			a.desired = Vector2.ZERO
			a.reverse = false
			a.heading = a.yaw
			return
	var forward_unit := Vector2(-sin(u.facing), -cos(u.facing))
	var target: Vector2 = u.slot_world[a.slot] + forward_unit * u.lead
	if a.leaving:
		# Off the field along the company's way out, past its parked centre.
		target = a.pos + forward_unit * 3.0
	var slot_velocity: Vector2 = u.slot_vel[a.slot]
	var to := target - a.pos
	var dist := to.length()
	var cap := a.l_walk
	if u.status == "routed" or a.model_pose == "retreat" or a.leaving:
		cap = a.l_run
	if u.charging or dist > 2.5:
		cap = a.l_charge
	elif dist > 1.2:
		cap = maxf(cap, a.l_run)
	var desired := slot_velocity
	# The press holds a man only near his own place in a company that still
	# stands; a man cut off from it, routing or leaving disengages.
	var held := a.contact and dist < CONTACT_HOLD_M and u.status != "routed" and not a.leaving
	if held:
		# In the press men do not dress ranks to the centimetre and step at
		# most slowly into a gap.
		cap = minf(cap, CONTACT_DRESS_M_S)
	var settle := CONTACT_SETTLE_M if held else (RESUME_M if a.settled else SETTLE_M)
	if dist > settle:
		a.settled = false
		var approach := minf(sqrt(2.0 * a.l_brake * 0.6 * dist), 1.8 * dist)
		desired += to / dist * approach
	elif slot_velocity.length() < 0.05:
		a.settled = true
		desired = Vector2.ZERO
	if a.model_pose in ACTIONS and (held or (u.lead < 0.05 and dist < 1.0)):
		# A striking, shooting or bracing man plants his feet, also in the press.
		desired = Vector2.ZERO
	if desired.length() > cap:
		desired = desired.normalized() * cap
	desired = _avoid(a, desired)
	var face_yaw := u.facing + PI
	a.heading = face_yaw
	a.reverse = false
	var desired_speed := desired.length()
	if desired_speed > 0.04:
		var direction := desired / desired_speed
		var front := Vector2(sin(face_yaw), cos(face_yaw))
		if direction.dot(front) < -0.5 and (held or (desired_speed <= a.l_back * 1.5 and dist < 1.0 \
				and slot_velocity.length() < 0.3 and not u.charging)):
			# Step back facing the front; in contact never turn away.
			a.reverse = true
		elif held and direction.dot(front) < 0.3:
			# Sideways in the press: keep facing the enemy, no strafing glide.
			desired = Vector2.ZERO
		else:
			a.heading = atan2(direction.x, direction.y)
	elif absf(angle_difference(a.yaw, a.heading)) < deg_to_rad(8.0):
		# Standing men face the front only when clearly off it (no idle twitching).
		a.heading = a.yaw
	a.cap = cap
	a.desired = desired
	a.asleep = a.settled and desired == Vector2.ZERO and absf(a.speed) < 0.001 and not a.contact and not a.crowded \
		and not u.enemy_near and absf(angle_difference(a.yaw, a.heading)) < 0.001


## Kinematics every tick at every level: turn-rate limit (curvature-limited
## while walking), speed along the heading only (no sideways gliding),
## acceleration and braking limits.
func _integrate(a: Agent) -> void:
	var omega := a.l_turn
	if absf(a.speed) > 0.5:
		omega = minf(omega, a.l_lateral / absf(a.speed))
	a.yaw = rotate_toward(a.yaw, a.heading, omega * DT)
	var forward := Vector2(sin(a.yaw), cos(a.yaw))
	var along := a.desired.dot(forward)
	var wanted := 0.0
	if a.reverse:
		wanted = clampf(along, -a.l_back, 0.0)
	else:
		wanted = clampf(along, 0.0, a.cap)
		if absf(angle_difference(a.yaw, a.heading)) > deg_to_rad(70.0):
			wanted = 0.0
	var rate := a.l_accel if absf(wanted) > absf(a.speed) and wanted * a.speed >= 0.0 else a.l_brake
	a.speed = move_toward(a.speed, wanted, rate * DT)
	a.vel = forward * a.speed
	a.pos += a.vel * DT


func _avoid(a: Agent, desired: Vector2) -> Vector2:
	var push := Vector2.ZERO
	var contact := false
	var crowded := false
	var brake := a.l_brake
	var clamps := []
	var nearest_foe := INF
	if a.unit.enemy_near:
		# Near an enemy company the opponent search widens to ~3-4 m so a
		# charge can brake before contact.
		_gather(a.side, false, a.pos, 3, _foes)
		for b: Agent in _foes:
			var offset := a.pos - b.pos
			var d := offset.length()
			nearest_foe = minf(nearest_foe, d)
			if d >= CONTACT_M + ENEMY_BRAKE_BAND_M:
				continue
			var direction := offset / d if d > 0.0001 else Vector2(1, 0).rotated(float(a.serial % 628) * 0.01)
			# Opposing men: the approach toward one another is limited to what
			# can still be braked before weapon contact, counting the other
			# man's own approach. Braking never turns a man's back to the foe.
			crowded = crowded or d < CONTACT_M + 1.0
			if d < CONTACT_M + 0.15:
				contact = true
			if d < HARD_ENEMY_M + 0.04:
				push += direction * (HARD_ENEMY_M + 0.04 - d) / HARD_ENEMY_M * PUSH_M_S
			var allowed := sqrt(brake * maxf(0.0, d - CONTACT_M)) - maxf(0.0, b.vel.dot(direction))
			clamps.append([-direction, maxf(0.0, allowed)])
	_gather(a.side, true, a.pos, 1, _friends)
	for b: Agent in _friends:
		if b == a:
			continue
		var offset := a.pos - b.pos
		var d := offset.length()
		if d > 1.6:
			continue
		var direction := offset / d if d > 0.0001 else Vector2(1, 0).rotated(float(a.serial % 628) * 0.01)
		var radius := SAME_SPACING_M if a.squad == b.squad else FRIEND_SPACING_M
		if d < radius:
			push += direction * (radius - d) / radius * PUSH_M_S
			crowded = true
		if a.squad != b.squad:
			if d < 1.2:
				crowded = true
			# Men of another company are passed at a speed that can still
			# brake before bumping into them (the gait cannot show a shove).
			var allowed_friend := sqrt(brake * maxf(0.0, d - FRIEND_SPACING_M)) - maxf(0.0, b.vel.dot(direction))
			clamps.append([-direction, maxf(0.0, allowed_friend)])
		# Anticipation: deflect early toward the side of the predicted closest
		# approach, so the man turns around a comrade instead of bumping into
		# him (the gait cannot show a sideways shove).
		var relative := desired - b.vel
		var speed_squared := relative.length_squared()
		if speed_squared > 0.01:
			var t := -offset.dot(relative) / speed_squared
			if t > 0.0 and t < 1.2:
				var closest := offset + relative * t
				var miss := closest.length()
				if miss < radius + 0.1:
					var side := closest / miss if miss > 0.001 else Vector2(-relative.y, relative.x).normalized()
					desired += side * (radius + 0.1 - miss) / maxf(t, 0.3) * 0.8
		if d < radius + 0.25:
			var closing := -(desired - b.vel).dot(direction)
			if closing > 0.0:
				desired += direction * closing * clampf((radius + 0.25 - d) / 0.25, 0.0, 1.0)
	for r in _rock_centres.size():
		var offset := a.pos - _rock_centres[r]
		var radius := _rock_radii[r]
		if absf(offset.x) > radius + 0.4 or absf(offset.y) > radius + 0.4:
			continue
		var d := offset.length()
		if d < radius + 0.4 and d > 0.0001:
			var normal := offset / d
			var inward := -desired.dot(normal)
			if inward > 0.0:
				desired += normal * inward
			if d < radius:
				push += normal * (radius - d) / 0.4 * PUSH_M_S
	a.contact = contact
	a.crowded = crowded
	a.foe_distance = nearest_foe
	desired += push
	# The braking limit toward each opponent applies to the final wish,
	# including the shove of comrades behind.
	for clamp in clamps:
		var along: float = desired.dot(clamp[0])
		if along > clamp[1]:
			desired -= clamp[0] * (along - float(clamp[1]))
	return desired


## Position-level guarantee after integration: bodies never interpenetrate
## (two 0.28 m radii plus a small margin) and nobody stands inside a rock.
func _resolve_contacts() -> void:
	_build_grid()
	var pairs := []
	for a: Agent in agents.values():
		a.correction = Vector2.ZERO
	for a: Agent in agents.values():
		if a.asleep or a.level == LEVEL_C:
			continue
		_gather(a.side, true, a.pos, 1, _friends)
		_gather(a.side, false, a.pos, 1, _foes)
		_friends.append_array(_foes)
		for b: Agent in _friends:
			# Each pair once: by serial among awake men; an awake man always
			# takes the pair with a sleeping neighbour.
			if b == a or (b.serial <= a.serial and not b.asleep):
				continue
			var limit := HARD_ENEMY_M if a.side != b.side else HARD_SAME_M
			var offset := a.pos - b.pos
			if absf(offset.x) < limit + 0.1 and absf(offset.y) < limit + 0.1 and offset.length() < limit + 0.1:
				pairs.append([a, b, limit])
	# The pair list is short; four passes keep a deep company pressing into
	# the enemy from compressing its own men below the body limit.
	for iteration in 4:
		for pair in pairs:
			var a: Agent = pair[0]
			var b: Agent = pair[1]
			var limit: float = pair[2]
			var offset := a.pos - b.pos
			var d := offset.length()
			if d >= limit:
				continue
			var direction := offset / d if d > 0.0001 else Vector2(1, 0).rotated(float(a.serial % 628) * 0.01)
			var correction := minf((limit - d) * 0.5, 0.03)
			if not a.external:
				a.pos += direction * correction
				a.correction += direction * correction
			if not b.external:
				b.pos -= direction * correction
				b.correction -= direction * correction
	for a: Agent in agents.values():
		if not a.external and a.level != LEVEL_C:
			var before := a.pos
			a.pos = a.pos.clamp(-Field.LIMIT, Field.LIMIT)
			for r in _rock_centres.size():
				var offset := a.pos - _rock_centres[r]
				var radius := _rock_radii[r]
				if absf(offset.x) < radius and absf(offset.y) < radius and offset.length() < radius:
					a.pos = _rock_centres[r] + (offset.normalized() if offset.length() > 0.0001 else Vector2.RIGHT) * radius
			a.correction += a.pos - before


func _animate(a: Agent) -> void:
	var u: Unit = a.unit
	var forward := Vector2(sin(a.yaw), cos(a.yaw))
	var travelled := (a.pos - a.prev_pos).dot(forward)
	var s := a.speed
	var gait := "idle"
	if a.model_pose == "retreat" and absf(s) > 0.3:
		gait = "retreat"
	elif absf(s) >= 0.04:
		gait = "run" if s > Troop.RUN_ENTER or (a.gait == "run" and s > Troop.RUN_EXIT) else "march"
	if gait != a.gait and a.gait in Soldier.STRIDES and gait in Soldier.STRIDES and tick - a.gait_tick < GAIT_HOLD_TICKS:
		# Hold a walk/run choice briefly so speeds near the threshold do not
		# flicker between clips.
		gait = a.gait
	if gait != a.gait:
		a.gait_tick = tick
	a.gait = gait
	var pose := gait
	if a.model_pose in ACTIONS and absf(s) < ACTION_SPEED_M_S:
		# Action clips have no locomotion; they start once the man has stopped.
		pose = a.model_pose
	elif gait == "idle":
		pose = "wall" if u.formation == "shield_wall" else ("testudo" if u.formation == "testudo" else "idle")
	var restart := pose in ACTIONS and a.action_restart
	if pose == a.model_pose:
		a.action_restart = false
	if (pose != a.pose or restart) and pose in Soldier.STRIDES and a.pose in Soldier.STRIDES:
		# Walk <-> run keeps one continuous step phase (the rig crossfades).
		a.pose = pose
	elif pose != a.pose or restart:
		var start := 0.0
		if pose in Soldier.STRIDES:
			if u.in_step:
				# "Im Gleichschritt": a drilled company steps off on the same foot.
				start = fposmod(u.drum + a.drum_offset, 1.0)
			else:
				start = a.free_phase
		a.prev_phase = start
		a.phase = start
		a.pose = pose
	if pose in Soldier.STRIDES:
		var stride := float(Soldier.STRIDES[pose])
		var advance := travelled / stride
		if pose == "march":
			u.step_sum += advance
			u.step_count += 1
		if u.in_step and pose == "march":
			var error := wrapf(u.drum + a.drum_offset - a.phase, -0.5, 0.5)
			var bound := PHASE_LOCK * absf(advance)
			advance += clampf(error, -bound, bound)
		a.phase += advance
		a.free_phase = fposmod(a.phase, 1.0)
		if first_stride_probe >= 0 and first_stride.is_empty() and absf(travelled) > 0.0:
			first_stride = {"uid": a.uid, "pose": pose, "meters": absf(travelled)}
	else:
		a.phase += DT / Soldier.clip_length(a.role, pose)
		if pose not in Soldier.LOOPING:
			a.phase = minf(a.phase, 1.0)


## Hand a soldier to an individual-combat controller (level A). The agent keeps
## existing and keeps its uid; only its integration changes hands.
func release_external(uid: String) -> Dictionary:
	if not agents.has(uid):
		return {}
	var a: Agent = agents[uid]
	a.external = true
	counters.external += 1
	return state_of(a)


func update_external(uid: String, position: Vector2, yaw: float, phase: float, pose: String) -> bool:
	if not agents.has(uid) or not agents[uid].external:
		return false
	var a: Agent = agents[uid]
	a.pos = position
	a.yaw = yaw
	a.phase = phase
	a.pose = pose
	return true


func return_external(uid: String) -> bool:
	if not agents.has(uid):
		return false
	agents[uid].external = false
	agents[uid].settled = false
	return true


func state_of(a: Agent) -> Dictionary:
	return {"uid": a.uid, "squad": a.squad, "position": a.pos, "velocity": a.vel, "yaw": a.yaw,
		"phase": a.phase, "pose": a.pose, "level": a.level, "slot": a.slot}


## Interpolated presentation state at fraction f between the last two ticks.
static func continuous(a: Agent) -> bool:
	return a.prev_pose == a.pose or (a.prev_pose in Soldier.STRIDES and a.pose in Soldier.STRIDES)


func present_state(a: Agent, f: float) -> Dictionary:
	var p := a.prev_pos.lerp(a.pos, f)
	var phase := lerpf(a.prev_phase, a.phase, f) if continuous(a) else a.phase
	return {"position": Vector3(p.x, Rules.ground_height(p.x, p.y), p.y),
		"yaw": lerp_angle(a.prev_yaw, a.yaw, f), "pose": a.pose, "phase": phase}
