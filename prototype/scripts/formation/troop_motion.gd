extends RefCounted
## Physical movement limits of level-B soldier agents by troop kind and carried
## load. Engineering starting values for the valley prototype; each is checked by
## tests/formation_agents_test.gd and measured in formation_motion_measurement.gd.
##
## The battle model moves a company centre at 1.85 m/s (column 2.3, retreat 3.0,
## rout 3.3 m/s). Soldiers must be able to keep up and recover a displaced slot,
## so the walking gait reaches 2.45 m/s and the run 3.6-4.2 m/s. Load is battle
## kit only (no marching pack): helmet, mail, shield, weapons.

const BODY_MASS_KG := 68.0
const KINDS := {
	# walk: top speed of the march clip. run: sustained run. charge: closing sprint.
	# accel/brake: m/s2 along the heading. turn: deg/s while standing.
	# lateral_accel: m/s2 cap of centripetal acceleration while walking a curve.
	# back: slow backward step that keeps the front (ranks dressing to the rear).
	"infantry": {"walk": 2.45, "run": 3.6, "charge": 4.1, "accel": 2.3, "brake": 4.6,
		"turn": 150.0, "lateral_accel": 4.2, "back": 0.6, "load_kg": 27.0, "charge_start_m": 9.0},
	"spear": {"walk": 2.4, "run": 3.5, "charge": 3.8, "accel": 2.1, "brake": 4.3,
		"turn": 130.0, "lateral_accel": 3.6, "back": 0.55, "load_kg": 24.0, "charge_start_m": 7.0},
	"archer": {"walk": 2.5, "run": 4.0, "charge": 4.0, "accel": 2.7, "brake": 5.0,
		"turn": 170.0, "lateral_accel": 4.8, "back": 0.65, "load_kg": 14.0, "charge_start_m": 0.0},
}
const RUN_ENTER := 2.65
const RUN_EXIT := 2.3
const BODY_RADIUS := 0.28


## Limits after the load penalty. Heavier kit lowers top speed, acceleration and
## turn rate in proportion to the load share of total moving mass.
static func limits(kind: String, extra_load_kg: float = 0.0) -> Dictionary:
	var base: Dictionary = KINDS.get(kind, KINDS.infantry)
	var load := maxf(0.0, float(base.load_kg) + extra_load_kg)
	var share := load / (BODY_MASS_KG + load)
	# Reference: the infantry kit (27 kg) keeps the tabulated values.
	var reference := float(base.load_kg) / (BODY_MASS_KG + float(base.load_kg))
	var factor := clampf(1.0 - 0.9 * (share - reference), 0.6, 1.15)
	var result := base.duplicate()
	for key in ["walk", "run", "charge", "accel", "turn", "lateral_accel"]:
		result[key] = float(base[key]) * factor
	result.load_kg = load
	result.factor = factor
	return result
