extends RefCounted
## Deterministic level-A decisions for an NPC fighter (raid raiders, front-rank
## duels handed down from level B). It only reads the melee state and returns
## a decision; the caller applies it through Core.command / Core.place, so the
## authority, timing and contact rules stay in melee_core.gd.
##
## Decision {"action": "attack"|"guard"|"release"|"dodge"|"approach"|"retreat"|"wait",
##           "args": {...}, "goal": Vector2 (approach/retreat only)}

const Core = preload("res://scripts/domain/melee/melee_core.gd")
const Tracks = preload("res://scripts/domain/melee/melee_tracks.gd")
const Geo = preload("res://scripts/domain/melee/melee_geometry.gd")

## How far inside the measured peak reach an attacker wants to stand (m).
const SPACING := 0.08
const EXHAUSTED := 25.0
## Walking pace in a fight (m/s) and how much slower backing away is.
const PACE := 1.4
const RETREAT_PACE := 0.6
## Fighting styles per warrior family (design data, not measurements):
## move weights, how far inside the measured reach they stand, and how often
## they read an incoming strike. Roman: stab from behind the scutum; Germanic
## axe: committed overhead/diagonal cuts at closer range; spear: keep the
## longer distance. Unknown kits fall back to equal weights.
const STYLES := {
	"legionary":{"weights":{"thrust":5.0, "cut_inward":1.5, "cut_outward":1.5, "overhead":0.7, "turn_cut":0.3}, "spacing":0.10, "skill":0.75},
	"axe_fighter":{"weights":{"axe_overhead":3.0, "axe_cut_inward":2.0, "axe_cut_outward":1.2}, "spacing":0.18, "skill":0.6},
	"spearman":{"weights":{"spear_thrust":1.0}, "spacing":0.05, "skill":0.65},
	"youth_unarmed":{"weights":{"jab_left":3.0, "jab_right":3.0, "front_kick":1.0}, "spacing":0.05, "skill":0.5}}


## `skill` (0..1) is the chance to read an incoming strike in time; fatigue
## and wavering morale lower it. The roll is seeded once per strike.
static func decide(state: Dictionary, id: String, target_id: String, skill: float = -1.0) -> Dictionary:
	var f := Core.fighter(state, id)
	var t := Core.fighter(state, target_id)
	if f.is_empty() or t.is_empty() or not bool(f.alive) or not bool(t.alive):
		return {"action":"wait", "args":{}}
	var style: Dictionary = STYLES.get(str(f.kit), {})
	if skill < 0.0:
		skill = float(style.get("skill", 0.7))
	if f.action in ["attack", "react", "down", "dodge"]:
		return {"action":"wait", "args":{}}
	var to_target := Vector2(float(t.x) - float(f.x), float(t.z) - float(f.z))
	var distance := to_target.length()
	# 1. Threat: the opponent's strike is live or about to be.
	if t.action == "attack":
		var timing := Tracks.timing(str(t.kit), str(t.move))
		var frame := Tracks.frame_of(float(t.t))
		var reach := Core.nominal_reach(str(t.kit), str(t.move), float(f.radius), float(t.scale))
		if frame <= int(timing.end) and distance <= reach + 0.25 and reads(state, f, t, skill):
			if bool(f.has_shield) and float(f.shield_integrity) > 0.0 and float(f.stamina) >= Core.GUARD_MIN_STAMINA:
				var guard_style := guard_for(state, f, t)
				if f.action != "guard" or str(f.guard_style) != guard_style:
					return {"action":"guard", "args":{"style":guard_style}}
				return {"action":"wait", "args":{}}
			if float(f.stamina) >= Core.DODGE_COST and frame < int(timing.peak) - 6:
				return {"action":"dodge", "args":{"style":"dodge_back"}}
	if f.action == "guard":
		return {"action":"release", "args":{}}
	# 2. Opening: a strike that would reach the body right now (guard torn
	#    open, shield arm spent, shield turned to the wrong side) is taken at
	#    once, even when tired.
	var opening := open_move(state, f, t, skill)
	if not opening.is_empty():
		return {"action":"attack", "args":{"move":opening}}
	# 3. Exhausted: step out of reach and recover.
	var best := best_move(state, f, t)
	if float(f.stamina) < EXHAUSTED or best.is_empty():
		var away := -to_target.normalized() if distance > 0.0001 else Vector2(0.0, 1.0)
		return {"action":"retreat", "args":{}, "goal":Vector2(float(f.x), float(f.z)) + away * 0.6}
	# 4. Close to the measured reach of the chosen move, then strike (pressure
	#    on the shield costs the defender stamina).
	var want := Core.nominal_reach(str(f.kit), str(best.move), float(t.radius), float(f.scale)) - float(style.get("spacing", SPACING))
	if float(t.stamina) < EXHAUSTED and t.action == "idle":
		# A spent opponent backs away: close by the ground he will give up
		# until the strike arrives, or it only cuts the air.
		var arrives := float(Tracks.timing(str(f.kit), str(best.move)).peak) / float(Tracks.FPS)
		want = maxf(float(f.radius) + float(t.radius) + 0.10, want - PACE * RETREAT_PACE * arrives)
	if distance > want:
		var goal := Vector2(float(t.x), float(t.z)) - to_target.normalized() * want
		return {"action":"approach", "args":{}, "goal":goal}
	return {"action":"attack", "args":{"move":best.move}}


static func reads(state: Dictionary, f: Dictionary, t: Dictionary, skill: float) -> bool:
	var chance := clampf(skill, 0.0, 1.0) * (1.0 - 0.4 * float(f.fatigue))
	if float(f.morale) < Core.MORALE_WAVERING:
		chance *= 0.75
	var started := int(state.frame) - Tracks.frame_of(float(t.t))
	return Geo.unit_random("%d:read:%s:%s:%d" % [int(state.seed), str(f.id), str(t.id), started]) < chance


## The style's preferred affordable move whose measured sweep, from where
## both stand now, reaches the opponent's body instead of the shield or the
## air ("" if none or if the fighter does not see it). Seeing an opening is
## a skill: the roll is seeded per quarter second.
static func open_move(state: Dictionary, f: Dictionary, t: Dictionary, skill: float) -> String:
	var distance := Vector2(float(t.x) - float(f.x), float(t.z) - float(f.z)).length()
	var weights: Dictionary = STYLES.get(str(f.kit), {}).get("weights", {})
	var found := ""
	var found_weight := 0.0
	for move: String in Tracks.moves_of(str(f.kit)):
		var weight := float(weights.get(move, 1.0 if weights.is_empty() else 0.0))
		if weight <= found_weight or Core.move_cost(str(f.kit), move) > float(f.stamina):
			continue
		if distance > Core.nominal_reach(str(f.kit), move, float(t.radius), float(f.scale)) + 0.05:
			continue
		var preview := Core.preview_strike(state, str(f.id), move, Core.aim_yaw(state, str(f.id), str(t.id), move))
		if preview.kind == "body" and preview.defender == t.id:
			found = move
			found_weight = weight
	if found.is_empty():
		return ""
	var sees := Geo.unit_random("%d:open:%s:%d" % [int(state.seed), str(f.id), int(state.frame) / 15]) < clampf(skill, 0.0, 1.0)
	return found if sees else ""


## Affordable move drawn from the family's style weights (seeded), so each
## warrior family fights differently without repeating one fixed pattern.
static func best_move(state: Dictionary, f: Dictionary, t: Dictionary) -> Dictionary:
	var weights: Dictionary = STYLES.get(str(f.kit), {}).get("weights", {})
	var options: Array = []
	var total := 0.0
	for move: String in Tracks.moves_of(str(f.kit)):
		if Core.move_cost(str(f.kit), move) > float(f.stamina):
			continue
		var weight := float(weights.get(move, 1.0 if weights.is_empty() else 0.0))
		if weight <= 0.0:
			continue
		total += weight
		options.append({"move":move, "weight":weight, "reach":Core.nominal_reach(str(f.kit), move, float(t.radius), float(f.scale))})
	if options.is_empty():
		return {}
	var roll := Geo.unit_random("%d:%d:ai:%s" % [int(state.seed), int(state.frame), str(f.id)]) * total
	for option: Dictionary in options:
		roll -= float(option.weight)
		if roll < 0.0:
			return option
	return options[options.size() - 1]


## Guard style from where the incoming weapon is: high for strikes that come
## from above head height, otherwise toward the side the tip is on.
static func guard_for(state: Dictionary, f: Dictionary, t: Dictionary) -> String:
	var timing := Tracks.timing(str(t.kit), str(t.move))
	var at := clampi(maxi(Tracks.frame_of(float(t.t)), int(timing.start)), 0, int(timing.frames) - 1)
	var seg := Core.strike_world(t, at)
	if seg.is_empty():
		return "guard_front"
	var tip: Vector3 = seg[1]
	if tip.y > float(f.height) * 0.92:
		return "guard_high"
	var local := Geo.to_local(Vector3(float(f.x), 0.0, float(f.z)), float(f.yaw), tip)
	if local.x > 0.35:
		return "guard_right"
	if local.x < -0.35:
		return "guard_left"
	return "guard_low" if tip.y < float(f.height) * 0.45 else "guard_front"


## Apply a decision with a simple step toward its goal (no pathfinding; the
## world adapter supplies collision through `motion_check(from, to)` if set).
static func apply(state: Dictionary, id: String, target_id: String, decision: Dictionary, delta: float, speed: float = PACE, motion_check: Callable = Callable()) -> Dictionary:
	var f := Core.fighter(state, id)
	match str(decision.action):
		"attack":
			# Turn the strike's own line onto the opponent, then commit.
			var before := float(f.yaw)
			Core.place(state, id, float(f.x), float(f.z), Core.aim_yaw(state, id, target_id, str(decision.args.get("move", ""))))
			var result := Core.command(state, id, "attack", decision.args)
			if not bool(result.ok):
				f.yaw = before
			return result
		"guard", "release", "dodge":
			Core.face(state, id, target_id)
			return Core.command(state, id, decision.action, decision.args)
		"approach", "retreat":
			var from := Vector2(float(f.x), float(f.z))
			var goal: Vector2 = decision.goal
			# Backing away is slower than closing in: a retreat can be caught.
			var step := from.move_toward(goal, speed * (RETREAT_PACE if decision.action == "retreat" else 1.0) * delta)
			if motion_check.is_valid():
				var checked: Variant = motion_check.call(from, step)
				if typeof(checked) == TYPE_VECTOR2:
					step = checked
			Core.place(state, id, step.x, step.y, float(f.yaw))
			Core.face(state, id, target_id)
			return {"ok":true, "message":decision.action}
	return {"ok":true, "message":"wait"}
