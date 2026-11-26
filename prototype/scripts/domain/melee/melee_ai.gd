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


## `skill` (0..1) is the chance to read an incoming strike in time; fatigue
## and wavering morale lower it. The roll is seeded once per strike.
static func decide(state: Dictionary, id: String, target_id: String, skill: float = 0.7) -> Dictionary:
	var f := Core.fighter(state, id)
	var t := Core.fighter(state, target_id)
	if f.is_empty() or t.is_empty() or not bool(f.alive) or not bool(t.alive):
		return {"action":"wait", "args":{}}
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
				var style := guard_for(state, f, t)
				if f.action != "guard" or str(f.guard_style) != style:
					return {"action":"guard", "args":{"style":style}}
				return {"action":"wait", "args":{}}
			if float(f.stamina) >= Core.DODGE_COST and frame < int(timing.peak) - 6:
				return {"action":"dodge", "args":{"style":"dodge_back"}}
	if f.action == "guard":
		return {"action":"release", "args":{}}
	# 2. Exhausted: step out of reach and recover.
	var best := best_move(state, f, t)
	if float(f.stamina) < EXHAUSTED or best.is_empty():
		var away := -to_target.normalized() if distance > 0.0001 else Vector2(0.0, 1.0)
		return {"action":"retreat", "args":{}, "goal":Vector2(float(f.x), float(f.z)) + away * 0.6}
	# 3. Close to the measured reach of the chosen move, then strike.
	var want := Core.nominal_reach(str(f.kit), str(best.move), float(t.radius), float(f.scale)) - SPACING
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


## Longest-reaching affordable move whose reach still covers the distance;
## ties broken by the seeded stream so fighters do not repeat one pattern.
static func best_move(state: Dictionary, f: Dictionary, t: Dictionary) -> Dictionary:
	var options: Array = []
	for move: String in Tracks.moves_of(str(f.kit)):
		if Core.move_cost(str(f.kit), move) > float(f.stamina):
			continue
		options.append({"move":move, "reach":Core.nominal_reach(str(f.kit), move, float(t.radius), float(f.scale))})
	if options.is_empty():
		return {}
	var pick := int(floor(Geo.unit_random("%d:%d:ai:%s" % [int(state.seed), int(state.frame), str(f.id)]) * options.size()))
	return options[clampi(pick, 0, options.size() - 1)]


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
static func apply(state: Dictionary, id: String, target_id: String, decision: Dictionary, delta: float, speed: float = 1.4, motion_check: Callable = Callable()) -> Dictionary:
	var f := Core.fighter(state, id)
	match str(decision.action):
		"attack", "guard", "release", "dodge":
			Core.face(state, id, target_id)
			return Core.command(state, id, decision.action, decision.args)
		"approach", "retreat":
			var from := Vector2(float(f.x), float(f.z))
			var goal: Vector2 = decision.goal
			var step := from.move_toward(goal, speed * delta)
			if motion_check.is_valid():
				var checked: Variant = motion_check.call(from, step)
				if typeof(checked) == TYPE_VECTOR2:
					step = checked
			Core.place(state, id, step.x, step.y, float(f.yaw))
			Core.face(state, id, target_id)
			return {"ok":true, "message":decision.action}
	return {"ok":true, "message":"wait"}
