extends RefCounted
## Combat value formula (decision D-042, handbook 3.0 p. 79), shared by the melee
## core (level A) and the formation battle (levels B/C).
##
##   damage = weapon_base × quality × competence × zone × protection × contact
##
## Every factor is computed in exactly one function below and clamped to the range in
## assets/balance/combat_balance.json. Stamina and injuries only enter competence,
## weapon wear only quality, armour/shield quality, wear, shield position and the
## defender's shield skill only protection, the actual contact moment only contact.
## INPUT_FACTORS documents which input feeds which factor; a test perturbs every input
## and checks that only those factors move. All functions are pure: they never change
## their arguments; wear and stamina are returned for the caller to book.
##
## resolve_hit(hit) – one blow (level A, or one representative blow for B/C):
##   weapon:   {family, quality 0-4, wear 0-1, strike?}  strike defaults per family
##   attacker: {skill 0-100, stamina 0-100, injuries: [kind], load_kg?}
##   defender: {skill 0-100, armor: {zone: {family, quality, wear}}, shield: {family,
##              quality, wear}?, health?}
##   zone:     head | torso | arm_weapon | arm_shield | leg
##   shield_cover: 0-1  share of the blow the shield takes (geometry at level A: 0 for a
##              body hit; shield_cover() for B/C)
##   ranged:   true for missiles (no parry by the defender's skill)
##   contact:  {time, start, peak, end} in seconds of the strike  OR  impact: 0.3-1.3
##              from physics; exactly one of them. Outside [start, end] there is no hit.
## returns {hit, damage, factors{…}, parts{…}, wear{weapon, shield, armor},
##          stamina_cost, strike, injury}
##
## unit_strike(strike) – one strike interval of a company (levels B/C):
##   mode: melee | ranged | pila, attackers: {count, skill, stamina, weapon, morale,
##   cohesion, formation, kind, charge, elevation}, defenders: {skill, armor, shield,
##   formation, braced, fouled, facing_dot}
## returns {casualties, per_hit, factors{engaged, blows, morale, cohesion, elevation,
##          formation, charge}, shield_cover, wear{weapon, shield, armor}}

const PATH := "res://assets/balance/combat_balance.json"
const FACTORS := ["weapon_base", "quality", "competence", "zone", "protection", "contact"]
const UNIT_FACTORS := ["engaged", "blows", "morale", "cohesion", "elevation", "formation", "charge"]
const ZONES := ["head", "torso", "arm_weapon", "arm_shield", "leg"]
## Which factors each input may move. A test perturbs every input and checks that
## exactly these factors change; no input reaches a factor that is not listed here.
## The hit zone selects both its multiplier and the armour piece that protects it; the
## weapon family also sets the default strike kind, which only armour reads.
const INPUT_FACTORS := {
	"weapon.family": ["weapon_base"],
	"weapon.strike": ["protection"],
	"weapon.quality": ["quality"],
	"weapon.wear": ["quality"],
	"attacker.skill": ["competence"],
	"attacker.stamina": ["competence"],
	"attacker.injuries": ["competence"],
	"zone": ["zone", "protection"],
	"defender.armor": ["protection"],
	"defender.shield": ["protection"],
	"defender.skill": ["protection"],
	"shield_cover": ["protection"],
	"ranged": ["protection"],
	"contact": ["contact"],
	"impact": ["contact"],
}
const UNIT_INPUT_FACTORS := {
	"attackers.count": ["engaged"],
	"mode": ["blows"],
	"attackers.morale": ["morale"],
	"attackers.cohesion": ["cohesion"],
	"attackers.elevation": ["elevation"],
	"attackers.formation": ["formation"],
	"attackers.kind": ["formation"],
	"attackers.charge": ["charge"],
}
## Ranged weapon names in the balance file (the thrown javelin is not the stabbing one).
const RANGED_WEAPON := {"bow": "bow", "sling": "sling", "javelin": "throw_javelin", "pilum": "pilum"}

static var _default := {}


static func balance() -> Dictionary:
	if _default.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		var problems := validate(parsed)
		if not problems.is_empty():
			push_error("combat_balance.json is invalid: " + str(problems))
			return {}
		_default = parsed
	return _default


static func _range(v: Variant) -> bool:
	return typeof(v) == TYPE_ARRAY and v.size() == 2 and typeof(v[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(v[1]) in [TYPE_INT, TYPE_FLOAT] and v[0] <= v[1]


static func _grades(v: Variant) -> bool:
	if typeof(v) != TYPE_ARRAY or v.size() != 5:
		return false
	for i in range(5):
		if typeof(v[i]) not in [TYPE_INT, TYPE_FLOAT] or v[i] <= 0 or (i > 0 and v[i] < v[i - 1]):
			return false
	return true


## Structural check of a balance document; returns the problems found.
static func validate(b: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(b) != TYPE_DICTIONARY or b.get("schema_version") != 1.0:
		problems.append("schema_version 1 fehlt")
		return problems
	for key in FACTORS + ["damage"]:
		if not _range(b.get("clamps", {}).get(key)):
			problems.append("clamps." + key)
	for key in UNIT_FACTORS + ["casualties"]:
		if not _range(b.get("unit", {}).get("clamps", {}).get(key)):
			problems.append("unit.clamps." + key)
	for path in [["quality", "grades"], ["armor", "quality_grades"], ["shields", "quality_grades"]]:
		if not _grades(b.get(path[0], {}).get(path[1])):
			problems.append("%s.%s muss fünf steigende Stufen Q0–Q4 haben" % path)
	for zone in ZONES:
		if typeof(b.get("zones", {}).get(zone)) not in [TYPE_INT, TYPE_FLOAT] or typeof(b.get("zone_mix", {}).get(zone)) not in [TYPE_INT, TYPE_FLOAT]:
			problems.append("zones/zone_mix." + zone)
	var mix := 0.0
	for zone in ZONES:
		mix += float(b.get("zone_mix", {}).get(zone, 0.0))
	if absf(mix - 1.0) > 0.0001:
		problems.append("zone_mix muss 1 ergeben")
	for id in b.get("weapons", {}):
		var w: Variant = b.weapons[id]
		if typeof(w) != TYPE_DICTIONARY or typeof(w.get("base")) not in [TYPE_INT, TYPE_FLOAT] or not w.get("strike") in b.get("strikes", []) or typeof(w.get("source")) != TYPE_STRING:
			problems.append("weapons." + str(id))
	for id in b.get("armor", {}).get("families", {}):
		var a: Dictionary = b.armor.families[id]
		for strike in b.get("strikes", []):
			if typeof(a.get("pass", {}).get(strike)) not in [TYPE_INT, TYPE_FLOAT] or a.pass[strike] < 0 or a.pass[strike] > 1:
				problems.append("armor.%s.pass.%s" % [id, strike])
	return problems


static func _f(b: Dictionary, path: Array) -> float:
	var v: Variant = b
	for key in path:
		v = v[key]
	return float(v)


static func _clamp(b: Dictionary, factor: String, value: float) -> float:
	var r: Array = b.clamps[factor]
	return clampf(value, float(r[0]), float(r[1]))


static func _unit_clamp(b: Dictionary, factor: String, value: float) -> float:
	var r: Array = b.unit.clamps[factor]
	return clampf(value, float(r[0]), float(r[1]))


static func _grade(table: Array, quality: Variant) -> float:
	return float(table[clampi(int(quality), 0, 4)])


## Waffenbasis: the weapon family's base value.
static func weapon_base(b: Dictionary, weapon: Dictionary) -> float:
	return _clamp(b, "weapon_base", _f(b, ["weapons", str(weapon.family), "base"]))


## Qualität: the weapon's grade, reduced by its wear.
static func quality(b: Dictionary, weapon: Dictionary) -> float:
	var wear := clampf(float(weapon.get("wear", 0.0)), 0.0, 1.0)
	return _clamp(b, "quality", _grade(b.quality.grades, weapon.get("quality", 2)) * (1.0 - wear * float(b.quality.wear_penalty)))


## Kompetenz: the attacker's skill, reduced by low stamina and by injuries.
static func competence(b: Dictionary, attacker: Dictionary) -> float:
	var c: Dictionary = b.competence
	var skill := clampf(float(attacker.get("skill", 50.0)), 0.0, 100.0)
	var value := float(c.skill_zero) + float(c.per_skill) * skill
	var stamina := clampf(float(attacker.get("stamina", 100.0)), 0.0, 100.0)
	value *= lerpf(float(c.stamina_floor), 1.0, minf(1.0, stamina / float(c.stamina_full_at)))
	for injury in attacker.get("injuries", []):
		value *= float(c.injuries.get(injury, 1.0))
	return _clamp(b, "competence", value)


## Trefferzone.
static func zone(b: Dictionary, zone_id: String) -> float:
	return _clamp(b, "zone", float(b.zones[zone_id]))


## Strike kind of a blow: explicit, else the weapon family's default.
static func strike(b: Dictionary, weapon: Dictionary) -> String:
	var kind := str(weapon.get("strike", ""))
	return kind if kind in b.strikes else str(b.weapons[str(weapon.family)].strike)


static func _armor_pass(b: Dictionary, defender: Dictionary, zone_id: String, kind: String) -> float:
	var piece: Dictionary = defender.get("armor", {}).get(zone_id, {})
	if piece.is_empty() or not b.armor.families.has(piece.get("family", "")):
		return 1.0
	var spec: Dictionary = b.armor.families[piece.family]
	if not zone_id in spec.zones:
		return 1.0
	var stops := (1.0 - float(spec.pass[kind])) * _grade(b.armor.quality_grades, piece.get("quality", 2))
	stops *= 1.0 - clampf(float(piece.get("wear", 0.0)), 0.0, 1.0) * float(b.armor.wear_penalty)
	return clampf(1.0 - stops, 0.0, 1.0)


## Share of a blow the shield stops when it covers it fully (shield quality and wear).
## The covered share itself is shield_cover.
static func shield_block(b: Dictionary, defender: Dictionary) -> float:
	var shield: Dictionary = defender.get("shield", {})
	if shield.is_empty() or not b.shields.families.has(shield.get("family", "")):
		return 0.0
	var s: Dictionary = b.shields
	var block := float(s.families[shield.family].block) * _grade(s.quality_grades, shield.get("quality", 2))
	return clampf(block * (1.0 - clampf(float(shield.get("wear", 0.0)), 0.0, 1.0) * float(s.wear_penalty)), 0.0, 1.0)


## The defender's skill turns melee blows aside (the only place defensive skill acts).
static func defense(b: Dictionary, defender: Dictionary, ranged: bool) -> float:
	if ranged:
		return 1.0
	return 1.0 - float(b.defense.parry_max) * clampf(float(defender.get("skill", 50.0)), 0.0, 100.0) / 100.0


## Schutzfaktor: armour on the hit zone, what the shield lets through and the defender's
## defensive skill.
static func protection(b: Dictionary, hit: Dictionary, kind: String) -> float:
	var defender: Dictionary = hit.get("defender", {})
	var cover := clampf(float(hit.get("shield_cover", 0.0)), 0.0, 1.0)
	var through := 1.0 - cover * shield_block(b, defender)
	return _clamp(b, "protection", _armor_pass(b, defender, str(hit.zone), kind) * through * defense(b, defender, bool(hit.get("ranged", false))))


## Kontakt: the actual moment of contact within the strike's active window, or a physics
## impact value from the melee core. Returns -1 when the contact is outside the window.
static func contact(b: Dictionary, hit: Dictionary) -> float:
	if hit.has("impact"):
		var r: Array = b.contact.impact_range
		return _clamp(b, "contact", clampf(float(hit.impact), float(r[0]), float(r[1])))
	var c: Dictionary = hit.contact
	var t := float(c.time)
	if t < float(c.start) or t > float(c.end):
		return -1.0
	var progress := clampf((t - float(c.start)) / maxf(0.0001, float(c.peak) - float(c.start)), 0.0, 1.0)
	return _clamp(b, "contact", lerpf(float(b.contact.minimum), 1.0, smoothstep(0.0, float(b.contact.full_at), progress)))


static func _check_hit(hit: Dictionary, b: Dictionary) -> String:
	if b.is_empty():
		return "Keine gültige Balancedatei."
	if not b.weapons.has(str(hit.get("weapon", {}).get("family", ""))):
		return "Unbekannte Waffenfamilie."
	if not str(hit.get("zone", "")) in ZONES:
		return "Unbekannte Trefferzone."
	if hit.has("impact") == hit.has("contact"):
		return "Genau eines von contact oder impact ist nötig."
	if hit.has("contact"):
		var c: Variant = hit.contact
		if typeof(c) != TYPE_DICTIONARY or not c.has_all(["time", "start", "peak", "end"]) or not (float(c.start) <= float(c.peak) and float(c.peak) <= float(c.end)):
			return "contact braucht time, start <= peak <= end."
	return ""


## One blow. Pure: inputs are never changed.
static func resolve_hit(hit: Dictionary, b: Dictionary = {}) -> Dictionary:
	if b.is_empty():
		b = balance()
	var problem := _check_hit(hit, b)
	if problem != "":
		return {"hit": false, "error": problem, "damage": 0.0}
	var weapon: Dictionary = hit.weapon
	var kind := strike(b, weapon)
	var k := contact(b, hit)
	var attacker: Dictionary = hit.get("attacker", {})
	var load := float(attacker.get("load_kg", 0.0))
	var cost := float(b.weapons[str(weapon.family)].cost) * (1.0 + maxf(0.0, load) / float(b.stamina.load_reference_kg))
	if k < 0.0:
		return {"hit": false, "damage": 0.0, "strike": kind, "stamina_cost": cost, "reason": "outside_window",
			"wear": {"weapon": 0.0, "shield": 0.0, "armor": 0.0}}
	var factors := {
		"weapon_base": weapon_base(b, weapon),
		"quality": quality(b, weapon),
		"competence": competence(b, attacker),
		"zone": zone(b, str(hit.zone)),
		"protection": protection(b, hit, kind),
		"contact": k,
	}
	var damage := 1.0
	for name in FACTORS:
		damage *= factors[name]
	damage = _clamp(b, "damage", damage)
	var defender: Dictionary = hit.get("defender", {})
	var cover := clampf(float(hit.get("shield_cover", 0.0)), 0.0, 1.0)
	var armored := _armor_pass(b, defender, str(hit.zone), kind) < 1.0
	var blocked := cover * shield_block(b, defender)
	var wear := {
		"weapon": float(b.wear.weapon_per_hit.shield) * blocked + float(b.wear.weapon_per_hit.armor if armored else b.wear.weapon_per_hit.flesh) * (1.0 - blocked),
		"shield": float(b.wear.shield_per_block) * blocked,
		"armor": float(b.wear.armor_per_absorb) * (1.0 - _armor_pass(b, defender, str(hit.zone), kind)) * (1.0 - blocked),
	}
	var result := {"hit": true, "damage": damage, "factors": factors, "strike": kind, "stamina_cost": cost, "wear": wear,
		"parts": {"shield_cover": cover, "shield_block": blocked, "armor_pass": _armor_pass(b, defender, str(hit.zone), kind)}}
	if defender.has("health"):
		var share := damage / maxf(0.001, float(defender.health))
		result.injury = "none" if damage <= 0.0 else ("light" if share < float(b.injury.light) else ("serious" if share < float(b.injury.serious) else ("crippling" if share < float(b.injury.crippling) else "fatal")))
	return result


## Share of blows a defender's shield takes, from the attack direction (dot of the
## defender's front with the direction to the attacker), formation, a braced stance and
## pila fouling (shield position for levels B/C).
static func shield_cover(b: Dictionary, defender: Dictionary, facing_dot: float, ranged: bool) -> float:
	var shield: Dictionary = defender.get("shield", {})
	if shield.is_empty() or not b.shields.families.has(shield.get("family", "")) or bool(defender.get("fouled", false)):
		return 0.0
	var s: Dictionary = b.shields
	var formation := str(defender.get("formation", ""))
	var side := "front" if formation == "orbis" or facing_dot >= float(s.cover.front_dot) else ("rear" if facing_dot <= float(s.cover.rear_dot) else "side")
	var cover := float(s.cover[side]) * float(s.families[shield.family].cover)
	if formation == "testudo" and ranged:
		cover = maxf(cover, float(s.testudo_missile_cover))
	elif formation in s.formation_cover and side == "front":
		cover *= float(s.formation_cover[formation])
	if bool(defender.get("braced", false)):
		cover *= float(s.braced_cover)
	return clampf(cover, 0.0, float(s.max_cover))


## Tactical company factors (levels B/C only), each applied once.
static func unit_factor(b: Dictionary, name: String, strike_input: Dictionary) -> float:
	var u: Dictionary = b.unit
	var a: Dictionary = strike_input.get("attackers", {})
	match name:
		"engaged":
			return _unit_clamp(b, name, float(a.get("count", 0)))
		"blows":
			var mode := str(strike_input.get("mode", "melee"))
			var weapon := str(a.get("weapon", {}).get("family", ""))
			var value: float = float(u.blows.melee) if mode == "melee" else float(u.accuracy.get(RANGED_WEAPON.get(weapon, weapon), 0.5))
			return _unit_clamp(b, name, value)
		"morale":
			return _unit_clamp(b, name, float(u.morale.base) + float(u.morale.per_point) * float(a.get("morale", 90.0)))
		"cohesion":
			return _unit_clamp(b, name, float(u.cohesion.base) + float(u.cohesion.per_point) * float(a.get("cohesion", 100.0)))
		"elevation":
			var r: Array = u.elevation.range
			return _unit_clamp(b, name, clampf(1.0 + float(u.elevation.per_metre) * float(a.get("elevation", 0.0)), float(r[0]), float(r[1])))
		"formation":
			var shape := str(a.get("formation", ""))
			var value := float(u.formation.get("%s:%s" % [shape, str(a.get("kind", ""))], u.formation.get(shape, 1.0)))
			return _unit_clamp(b, name, value)
		"charge":
			return _unit_clamp(b, name, float(u.charge) if bool(a.get("charge", false)) else 1.0)
	return 1.0


## One strike interval of a company against another: the expected blow over the zone mix,
## times the attackers who strike, their blows or accuracy and the tactical factors.
static func unit_strike(strike_input: Dictionary, b: Dictionary = {}) -> Dictionary:
	if b.is_empty():
		b = balance()
	var a: Dictionary = strike_input.get("attackers", {})
	var d: Dictionary = strike_input.get("defenders", {})
	var mode := str(strike_input.get("mode", "melee"))
	var weapon: Dictionary = a.get("weapon", {}).duplicate()
	if mode != "melee":
		weapon.family = RANGED_WEAPON.get(str(weapon.get("family", "")), str(weapon.get("family", "")))
	var cover := shield_cover(b, d, float(d.get("facing_dot", 1.0)), mode != "melee")
	var hit := {"weapon": weapon, "attacker": {"skill": a.get("skill", 50.0), "stamina": a.get("stamina", 100.0), "injuries": a.get("injuries", [])},
		"defender": {"skill": d.get("skill", 50.0), "armor": d.get("armor", {}), "shield": d.get("shield", {})},
		"shield_cover": cover, "impact": 1.0, "ranged": mode != "melee"}
	var per_hit := 0.0
	var wear := {"weapon": 0.0, "shield": 0.0, "armor": 0.0}
	for zone_id in ZONES:
		hit.zone = zone_id
		var r := resolve_hit(hit, b)
		if not r.hit:
			return {"casualties": 0.0, "per_hit": 0.0, "error": r.get("error", ""), "factors": {}, "shield_cover": cover, "wear": wear}
		var share := float(b.zone_mix[zone_id])
		per_hit += share * float(r.damage)
		for part in wear:
			wear[part] += share * float(r.wear[part])
	var factors := {}
	var casualties := per_hit / float(b.unit.soldier_health)
	for name in UNIT_FACTORS:
		factors[name] = unit_factor(b, name, strike_input)
		casualties *= factors[name]
	return {"casualties": _unit_clamp(b, "casualties", casualties), "per_hit": per_hit, "factors": factors, "shield_cover": cover, "wear": wear}


static func ranged_spec(weapon_family: String, b: Dictionary = {}) -> Dictionary:
	if b.is_empty():
		b = balance()
	return b.ranged.get(RANGED_WEAPON.get(weapon_family, weapon_family), {})
