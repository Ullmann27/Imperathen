extends RefCounted
## Simulation level (D-026: A near, B middle, C far) and render detail of every
## soldier agent, with hysteresis, cooldown and per-profile budgets
## (handbook p.43/45, design 3d). Only fields of existing agents change here:
## a switch never creates, removes or replaces a soldier.
##
## Level A: individual combat range. This branch has no individual-combat
##   controller; A soldiers use the level-B steering with full rigs, and
##   FormationAgents.release_external() hands one to such a controller.
## Level B: individual steering agents with spacing and collision.
## Level C: unit-bound placement (formation-rigid follow, no neighbour search).
## Render detail: 0 near rig, 1 middle rig, 2 distant instance, 3 aggregated
## (not drawn individually; counted, never shown as rendered).

const Field := preload("res://scripts/battle/valley_field.gd")
const LEVEL_A := 0
const LEVEL_B := 1
const LEVEL_C := 2
const DETAIL_NEAR := 0
const DETAIL_MID := 1
const DETAIL_FAR := 2
const DETAIL_AGGREGATE := 3
const LEVEL_NAMES := ["A", "B", "C"]
# Starting values (design 3d). near_rigs + mid_rigs equals the existing
# animated_valley_actors review limit of quality_profiles.json; distances are
# the previous near/middle LOD radii. "individual" caps level A+B agents. It
# comes from tests/formation_scale_benchmark.gd on the development desktop
# (GDScript, about 30-55 us per agent and 30 Hz tick: 128 agents ~ 4-6 ms per
# tick); it is not a measured Fold7 capacity.
const BUDGETS := {
	"low": {"near_rigs": 8, "mid_rigs": 16, "visible": 256, "individual": 64,
		"near_m": 13.0, "mid_m": 43.0, "aggregate_m": 120.0},
	"balanced": {"near_rigs": 12, "mid_rigs": 28, "visible": 512, "individual": 128,
		"near_m": 18.0, "mid_m": 48.0, "aggregate_m": 120.0},
	"high": {"near_rigs": 24, "mid_rigs": 40, "visible": 2000, "individual": 256,
		"near_m": 25.0, "mid_m": 67.0, "aggregate_m": 160.0},
	"very_high": {"near_rigs": 32, "mid_rigs": 58, "visible": 5000, "individual": 384,
		"near_m": 35.0, "mid_m": 90.0, "aggregate_m": 200.0},
}
const HYSTERESIS_M := 3.0
const COOLDOWN_S := 1.0

var profile := "balanced"
var clock := 0.0
var switches := {"level": 0, "detail": 0, "deferred_blend": 0, "deferred_cooldown": 0, "forced": 0}
var last := {}


func budget() -> Dictionary:
	return BUDGETS.get(profile, BUDGETS.balanced)


## Inside the switching band a recent switch is held for COOLDOWN_S. Outside
## it (2 x hysteresis beyond the threshold, e.g. a camera jump) a switch is
## immediate: the cooldown prevents flicker, it must not hide a real change.
static func _forced(distance: float, threshold: float) -> bool:
	return absf(distance - threshold) > 2.0 * HYSTERESIS_M


func assign(agents: Dictionary, camera_position: Vector3, in_view: Callable, blocked: Callable,
		delta: float, dying_rigs: int = 0) -> Dictionary:
	clock += maxf(0.0, delta)
	var b := budget()
	var ordered: Array = agents.values()
	for a in ordered:
		var p := Vector3(a.pos.x, Field.height(a.pos.x, a.pos.y) + 1.0, a.pos.y)
		a.camera_distance = camera_position.distance_to(p)
		a.visible = bool(in_view.call(p))
	ordered.sort_custom(func(x, y): return x.camera_distance < y.camera_distance or (x.camera_distance == y.camera_distance and x.uid < y.uid))
	_assign_levels(ordered, b)
	_assign_details(ordered, b, blocked, dying_rigs)
	last = count(agents, dying_rigs)
	return last


func _assign_levels(ordered: Array, b: Dictionary) -> void:
	var near_m := float(b.near_m)
	var mid_m := float(b.mid_m)
	var a_left := int(b.near_rigs)
	var individual_left := int(b.individual)
	for a in ordered:
		var d: float = a.camera_distance
		var want := LEVEL_C
		if d <= near_m - HYSTERESIS_M or (a.level == LEVEL_A and d <= near_m + HYSTERESIS_M):
			want = LEVEL_A
		elif d <= mid_m - HYSTERESIS_M or (a.level <= LEVEL_B and d <= mid_m + HYSTERESIS_M):
			want = LEVEL_B
		if want != a.level and clock - float(a.level_since) < COOLDOWN_S:
			var threshold := near_m if LEVEL_A in [want, a.level] else mid_m
			if _forced(d, threshold):
				switches.forced += 1
			else:
				want = a.level
				switches.deferred_cooldown += 1
		# Budgets are hard caps; they override a cooldown.
		if want == LEVEL_A and a_left <= 0:
			want = LEVEL_B
		if want <= LEVEL_B and individual_left <= 0:
			want = LEVEL_C
		if want != a.level:
			a.level = want
			a.level_since = clock
			switches.level += 1
		if a.level == LEVEL_A:
			a_left -= 1
		if a.level <= LEVEL_B:
			individual_left -= 1


func _assign_details(ordered: Array, b: Dictionary, blocked: Callable, dying_rigs: int) -> void:
	var mid_m := float(b.mid_m)
	var near_left := int(b.near_rigs)
	var rig_left := int(b.near_rigs) + int(b.mid_rigs) - dying_rigs
	var next := {}
	# 1. Rig holders that must not change now: a crossfade in progress (the
	#    pose would jump) or a recent switch inside the switching band.
	for a in ordered:
		if a.detail > DETAIL_MID:
			continue
		var hold: bool = bool(blocked.call(a.uid))
		if hold:
			switches.deferred_blend += 1
		elif a.visible and clock - float(a.detail_since) < COOLDOWN_S and a.level <= LEVEL_B and not _forced(a.camera_distance, mid_m):
			hold = true
		if not hold:
			continue
		if a.detail == DETAIL_NEAR and near_left > 0 and rig_left > 0:
			near_left -= 1
			rig_left -= 1
			next[a.uid] = DETAIL_NEAR
		elif a.detail == DETAIL_MID and rig_left > 0:
			rig_left -= 1
			next[a.uid] = DETAIL_MID
	# 2. Remaining rigs go to the nearest visible level A/B soldiers. Current
	#    holders rank HYSTERESIS_M closer, so equal distances do not trade rigs.
	var candidates := []
	for a in ordered:
		if next.has(a.uid) or not a.visible or a.level > LEVEL_B:
			continue
		var bonus := HYSTERESIS_M if a.detail <= DETAIL_MID else 0.0
		candidates.append([a.camera_distance - bonus, a.uid, a])
	candidates.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	for entry in candidates:
		var a = entry[2]
		var want := DETAIL_FAR
		if a.level == LEVEL_A and near_left > 0 and rig_left > 0:
			want = DETAIL_NEAR
		elif rig_left > 0:
			want = DETAIL_MID
		if want != a.detail and a.detail > DETAIL_MID and clock - float(a.detail_since) < COOLDOWN_S \
				and not _forced(a.camera_distance, mid_m):
			want = a.detail
			switches.deferred_cooldown += 1
		if want != a.detail and a.detail > DETAIL_MID and bool(blocked.call(a.uid)):
			# A distant man in the middle of a one-shot action gets his rig
			# when the action ends, not halfway through its footwork.
			want = a.detail
			switches.deferred_blend += 1
		if want == DETAIL_NEAR:
			near_left -= 1
			rig_left -= 1
		elif want == DETAIL_MID:
			rig_left -= 1
		next[a.uid] = want
	# 3. Everyone else: distant instance, or aggregated beyond the visible budget
	#    or the aggregation radius.
	var visible_left := int(b.visible)
	for a in ordered:
		if next.has(a.uid) and next[a.uid] <= DETAIL_MID and a.visible:
			visible_left -= 1
	for a in ordered:
		var want: int = next.get(a.uid, DETAIL_FAR)
		if want >= DETAIL_FAR:
			want = DETAIL_FAR
			if a.visible:
				if visible_left > 0 and a.camera_distance <= float(b.aggregate_m):
					visible_left -= 1
				else:
					want = DETAIL_AGGREGATE
		if want != a.detail:
			a.detail = want
			a.detail_since = clock
			switches.detail += 1


func count(agents: Dictionary, dying_rigs: int = 0) -> Dictionary:
	var result := {"profile": profile, "on_field": agents.size(), "level_a": 0, "level_b": 0, "level_c": 0,
		"simulated_individual": 0, "simulated_aggregate": 0, "rigs_near": 0, "rigs_mid": 0,
		"far_instances": 0, "aggregated": 0, "visible": 0, "animated": dying_rigs, "dying_rigs": dying_rigs,
		"budget": budget().duplicate(), "switches": switches.duplicate()}
	for a in agents.values():
		result["level_" + ["a", "b", "c"][a.level]] += 1
		if a.level <= LEVEL_B:
			result.simulated_individual += 1
		else:
			result.simulated_aggregate += 1
		match a.detail:
			DETAIL_NEAR:
				result.rigs_near += 1
				result.animated += 1
			DETAIL_MID:
				result.rigs_mid += 1
				result.animated += 1
			DETAIL_FAR:
				result.far_instances += 1
			DETAIL_AGGREGATE:
				result.aggregated += 1
		if a.visible and a.detail <= DETAIL_FAR:
			result.visible += 1
	return result
