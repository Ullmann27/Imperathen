extends RefCounted
## Raider melee timing in one place (owner decision D-026: every blow matches
## the visible animation, no damage before the weapon's contact frame, every
## received hit shows its own reaction).
##
## Rule side (VillageLife) and presentation (VillageLifeWorld, VillagePerson)
## read only these functions. A general melee core that derives attack phases
## from animation hit frames can replace this module without touching the
## raid route or the save format (attack_timer keeps its v1 meaning: seconds
## until the next blow resolves).

## Rule tick of VillageLife (seconds). The blow resolves on a tick boundary.
const RULE_STEP := 0.1
## Contact frame of the imported "attack" clips, in seconds at clip speed:
## the frame of greatest forward reach of the weapon, measured on the actual
## rigs (tests/raid_strike_timing_test.gd re-measures both).
##   hand axe (Meshy axe fighter): far end of the 0.62 m haft, 0.71 m in
##   front of the body centre at 0.20 s
##   spear (frontier spearman): spear end 1.03 m in front at 0.40 s
const CLIP_CONTACT_SECONDS := {
	"res://assets/meshy/characters/unit_germanic_axe_fighter_": 0.20,
	"res://assets/characters/frontier_spearman_": 0.40,
}
## Forward weapon reach at the contact frame, measured with the timings above.
const CLIP_WEAPON_REACH_M := {
	"res://assets/meshy/characters/unit_germanic_axe_fighter_": 0.71,
	"res://assets/characters/frontier_spearman_": 1.03,
}
## Body radius of the player capsule the weapon has to touch.
const TARGET_RADIUS_M := 0.28
## Time from one resolved blow to the next one, and the clock a raider starts
## with when it (re)enters reach. Both lie above the wind-up, so neither a
## resolved blow nor an approach ever begins a visible swing.
const INTERVAL_SECONDS := 1.8
const APPROACH_SECONDS := 0.9
const UNKNOWN_CLIP_CONTACT_FRACTION := 0.5


## Seconds between the start of the visible swing and the blow. Derived from
## the slowest raider clip's contact frame, on the rule tick; faster clips are
## retimed to the same contact (clip_time), never the damage moved earlier.
static func windup_seconds() -> float:
	var slowest := 0.0
	for seconds: float in CLIP_CONTACT_SECONDS.values():
		slowest = maxf(slowest, seconds)
	return ceilf(slowest / RULE_STEP - 0.000001) * RULE_STEP


## Centre-to-centre distance within which a blow can land: the shortest
## measured weapon reach plus the target's body radius (0.71 + 0.28 m), so a
## damaging blow is visibly in contact with either weapon.
static func reach() -> float:
	var shortest := INF
	for metres: float in CLIP_WEAPON_REACH_M.values():
		shortest = minf(shortest, metres)
	return snappedf(shortest + TARGET_RADIUS_M, 0.05)


## Raiders stop closing in here, safely inside the reach.
static func engage_distance() -> float:
	return reach() - 0.1


## True while the visible swing runs (the blow is committed and resolves).
static func swinging(attack_timer: float) -> bool:
	return attack_timer <= windup_seconds() + 0.000001


## Contact frame of the attack clip on a given model.
static func clip_contact_seconds(model_path: String, clip_length: float) -> float:
	for prefix: String in CLIP_CONTACT_SECONDS:
		if model_path.begins_with(prefix):
			return float(CLIP_CONTACT_SECONDS[prefix])
	return clip_length * UNKNOWN_CLIP_CONTACT_FRACTION


## Clip time after `elapsed` seconds of a swing whose contact frame must be
## reached after `windup` seconds. The wind-up is time-scaled to land on the
## blow; the follow-through plays at the clip's own speed.
static func clip_time(elapsed: float, windup: float, contact: float) -> float:
	if windup <= 0.0:
		return contact + maxf(0.0, elapsed)
	if elapsed <= windup:
		return contact * maxf(0.0, elapsed) / windup
	return contact + elapsed - windup
