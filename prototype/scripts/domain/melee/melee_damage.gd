extends RefCounted
## The single per-hit damage entry point of level A (D-042, handbook p. 79):
##   Damage = weapon base x quality x competence x hit zone x protection
## modulated by attacker stamina, injuries, weapon wear and the actual
## contact (drive of the strike at its measured contact frame), clamped, with
## a reproducible roll supplied by the caller. Pure function, no side effects.
##
## Shield position enters through geometry: a strike that meets the shield
## box is resolved as a block before this function is called (no damage), so
## only strikes that reach the body arrive here.
##
## Interim home of the balance parameters. When the shared module
## prototype/scripts/battle/combat_formula.gd with
## prototype/assets/balance/combat_balance.json (troops branch) lands,
## compute() delegates to it with the same inputs (one-line switch) and this
## BALANCE table is removed, so no second formula remains.

const BALANCE := {
	"weapon_base":{"fist":6.0, "foot":11.0, "head":7.0, "gladius":16.0, "axe":20.0, "spear":18.0},
	"zone":{"head":1.5, "torso":1.0, "arm_weapon":0.7, "arm_shield":0.7, "leg":0.8, "neutral":1.0},
	## Fraction of damage passing the armour, by strike kind.
	"protection":{"mail":{"cut":0.45, "thrust":0.70, "blunt":0.80}, "wool_leather":{"cut":0.75, "thrust":0.85, "blunt":0.90},
		"linen":{"cut":0.90, "thrust":0.95, "blunt":1.0}, "none":{"cut":1.0, "thrust":1.0, "blunt":1.0}},
	## Equipment helps noticeably but can never replace training: its range is
	## narrower than competence's, and the two come from separate sources.
	"quality_range":[0.85, 1.25],
	"competence_range":[0.5, 1.5],
	"stamina_floor":0.75,
	"wear_floor":0.70,
	"contact_range":[0.3, 1.3],
	"injury":{"arm_wound":0.75},
	"variance":0.08,
	"damage_range":[1.0, 250.0],
}


## hit: weapon_base (or family), quality, competence, zone, armor,
## strike_kind, attacker_stamina (0..1), injuries (Array of {kind}),
## weapon_wear (0..1), contact_drive (sqrt(E/E_ref) at the contact frame),
## contact_frame, roll (0..1, seeded by the caller).
## Returns {"damage": int, "terms": {...}} - every factor is reported.
static func compute(hit: Dictionary) -> Dictionary:
	var b := BALANCE
	var base := float(hit.get("weapon_base", b.weapon_base.get(str(hit.get("family", "")), 0.0)))
	var quality := clampf(float(hit.get("quality", 1.0)), b.quality_range[0], b.quality_range[1])
	var competence := clampf(float(hit.get("competence", 1.0)), b.competence_range[0], b.competence_range[1])
	var zone := float(b.zone.get(str(hit.get("zone", "neutral")), 1.0))
	var armor: Dictionary = b.protection.get(str(hit.get("armor", "none")), b.protection.none)
	var protection := float(armor.get(str(hit.get("strike_kind", "blunt")), 1.0))
	var stamina := lerpf(b.stamina_floor, 1.0, smoothstep(0.0, 0.3, clampf(float(hit.get("attacker_stamina", 1.0)), 0.0, 1.0)))
	var injury := 1.0
	for entry: Variant in hit.get("injuries", []):
		if typeof(entry) == TYPE_DICTIONARY:
			injury *= float(b.injury.get(str(entry.get("kind", "")), 1.0))
	var wear := lerpf(1.0, b.wear_floor, clampf(float(hit.get("weapon_wear", 0.0)), 0.0, 1.0))
	var contact := clampf(float(hit.get("contact_drive", 1.0)), b.contact_range[0], b.contact_range[1])
	var variance := lerpf(1.0 - b.variance, 1.0 + b.variance, clampf(float(hit.get("roll", 0.5)), 0.0, 1.0))
	var raw := base * quality * competence * zone * protection * stamina * injury * wear * contact * variance
	var damage := int(clampf(roundf(raw), b.damage_range[0], b.damage_range[1])) if base > 0.0 else 0
	return {"damage":damage, "terms":{"weapon_base":base, "quality":quality, "competence":competence, "zone":zone,
		"protection":protection, "stamina":stamina, "injury":injury, "wear":wear, "contact":contact,
		"variance":variance, "contact_frame":int(hit.get("contact_frame", -1)), "raw":raw}}
