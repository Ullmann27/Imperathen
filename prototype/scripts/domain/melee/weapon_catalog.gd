extends RefCounted
## Epoch-independent weapon definitions (D-050), read from
## assets/combat/weapons.json. A weapon is data only: its class (unarmed,
## melee, thrown, bow, crossbow, sling), its mechanism (how it delivers
## energy), its materials (for impact sound and particles) and the physical
## values the level-A authority needs. Adding a weapon of a later era is one
## entry there plus its `balance_family` in assets/balance/combat_balance.json
## (D-042 keeps balance apart from physics); no code changes.
##
## Melee timing always comes from the measured strike tracks
## (melee_track_data.gd). Ranged phases have no animation clip yet; their
## durations are authored values (`timing_source`), to be replaced by a
## measured release frame once draw/throw clips exist.

const Formula = preload("res://scripts/battle/combat_formula.gd")
const PATH := "res://assets/combat/weapons.json"
const ATTESTATIONS := ["attested", "plausible", "design_assumption"]
const RANGED_KEYS := ["phases", "projectile", "release_point", "spread_deg", "ammo", "hold_stamina_per_s"]

static var _doc := {}


static func document() -> Dictionary:
	if _doc.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		var problems := validate(parsed)
		if not problems.is_empty():
			push_error("weapons.json is invalid: " + str(problems))
			return {}
		_doc = parsed
	return _doc


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(document().get("weapons", {}).keys())
	result.sort()
	return result


static func has(id: String) -> bool:
	return document().get("weapons", {}).has(id)


static func weapon(id: String) -> Dictionary:
	return document().get("weapons", {}).get(id, {})


static func weapon_class(id: String) -> String:
	return str(weapon(id).get("class", ""))


static func is_ranged(id: String) -> bool:
	return weapon_class(id) in document().get("ranged_classes", [])


static func of_class(cls: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in ids():
		if weapon_class(id) == cls:
			result.append(id)
	return result


## Weapons usable in a given year (negative = BC), e.g. the 58 BC campaign.
static func available_in(year: int) -> Array[String]:
	var result: Array[String] = []
	for id: String in ids():
		var w := weapon(id)
		if int(w.valid_from) <= year and year <= int(w.valid_to):
			result.append(id)
	return result


static func material(id: String) -> String:
	return str(weapon(id).get("material", ""))


## Material that meets the target: the projectile's head for missiles.
static func impact_material(id: String) -> String:
	var w := weapon(id)
	if w.has("projectile"):
		return str(w.projectile.material)
	return str(w.get("material", ""))


static func effective_mass(id: String) -> float:
	return float(weapon(id).get("effective_mass_kg", 0.0))


## Weapon family in the shared balance file (damage base, stamina cost).
static func balance_family(id: String) -> String:
	return str(weapon(id).get("balance_family", id))


## Stamina cost of one strike/shot: the shared balance value (D-042).
static func stamina_cost(id: String) -> float:
	return float(Formula.balance().get("weapons", {}).get(balance_family(id), {}).get("cost", 0.0))


## A kick leaves the striker on one leg while it is in the air.
static func one_legged(id: String) -> bool:
	return bool(weapon(id).get("one_legged", false))


static func strike_kind(id: String, move_id: String = "") -> String:
	var w := weapon(id)
	return str(w.get("move_kinds", {}).get(move_id, w.get("strike_kind", "blunt")))


## Ranged phase lengths in whole 60 Hz frames.
static func ranged_timing(id: String) -> Dictionary:
	var w := weapon(id)
	if not w.has("phases"):
		return {}
	var p: Dictionary = w.phases
	return {"draw":maxi(1, roundi(float(p.draw_s) * 60.0)), "hold_max":maxi(1, roundi(float(p.hold_max_s) * 60.0)),
		"release":maxi(1, roundi(float(p.release_s) * 60.0)), "recover":maxi(1, roundi(float(p.recover_s) * 60.0)),
		"source":str(w.get("timing_source", "authored"))}


static func _number(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v))


## Structural validation of a weapons document; returns the problems found.
static func validate(doc: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(doc) != TYPE_DICTIONARY or doc.get("schema_version") != 1.0 or typeof(doc.get("weapons")) != TYPE_DICTIONARY:
		errors.append("schema_version 1 / weapons fehlt")
		return errors
	var balance: Dictionary = Formula.balance().get("weapons", {})
	for id: String in doc.weapons:
		var w: Variant = doc.weapons[id]
		if typeof(w) != TYPE_DICTIONARY:
			errors.append("%s: kein Objekt" % id)
			continue
		if not str(w.get("class", "")) in doc.get("classes", []):
			errors.append("%s: unbekannte Klasse" % id)
		if not str(w.get("mechanism", "")) in doc.get("mechanisms", []):
			errors.append("%s: unbekannter Mechanismus" % id)
		if not str(w.get("material", "")) in doc.get("materials", []):
			errors.append("%s: unbekanntes Material" % id)
		if not str(w.get("strike_kind", "")) in doc.get("strike_kinds", []):
			errors.append("%s: unbekannte Schlagart" % id)
		if not _number(w.get("valid_from")) or not _number(w.get("valid_to")) or float(w.valid_from) > float(w.valid_to):
			errors.append("%s: Zeitspanne" % id)
		if not str(w.get("attestation", "")) in ATTESTATIONS:
			errors.append("%s: Belegstufe fehlt" % id)
		if not balance.has(str(w.get("balance_family", ""))):
			errors.append("%s: balance_family fehlt in combat_balance.json" % id)
		if str(w.get("class", "")) in doc.get("ranged_classes", []):
			for key: String in RANGED_KEYS:
				if not w.has(key):
					errors.append("%s: Fernwaffe ohne %s" % [id, key])
			var p: Variant = w.get("projectile", {})
			if typeof(p) != TYPE_DICTIONARY or not _number(p.get("mass_kg")) or float(p.get("mass_kg")) <= 0.0 or not _number(p.get("speed_m_s")) or float(p.get("speed_m_s")) <= 0.0 or not _number(p.get("radius_m")) or float(p.get("radius_m")) <= 0.0 or not _number(p.get("drag_per_m")) or not str(p.get("material", "")) in doc.get("materials", []):
				errors.append("%s: Geschoss braucht Masse, Tempo, Radius, Widerstand und Material" % id)
			var ph: Variant = w.get("phases", {})
			if typeof(ph) != TYPE_DICTIONARY or not ph.has_all(["draw_s", "hold_max_s", "release_s", "recover_s"]):
				errors.append("%s: Phasen unvollständig" % id)
			var rp: Variant = w.get("release_point", [])
			if typeof(rp) != TYPE_ARRAY or rp.size() != 3:
				errors.append("%s: release_point" % id)
		elif not _number(w.get("effective_mass_kg")) or float(w.effective_mass_kg) <= 0.0:
			errors.append("%s: Nahkampfwaffe ohne wirksame Masse" % id)
	return errors
