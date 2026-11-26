extends SceneTree
## D-042 combat value formula: factor sources, clamps, contact window, purity, the value
## of gear against the value of training, and a reproducible veteran-versus-novice duel.

const Formula := preload("res://scripts/battle/combat_formula.gd")

var checks := 0
var failures := 0
var metrics := {}


func _initialize() -> void:
	var b := Formula.balance()
	check(not b.is_empty() and Formula.validate(b).is_empty(), "Central balance file validates")
	if b.is_empty():
		_finish()
		return
	_test_validation(b)
	_test_product_and_clamps(b)
	_test_factor_sources(b)
	_test_unit_sources(b)
	_test_contact(b)
	_test_shield_cover(b)
	_test_gear_versus_training(b)
	_test_duel(b)
	_test_purity(b)
	_finish()


func _finish() -> void:
	print("COMBAT_FORMULA_RESULT checks=%d failures=%d metrics=%s" % [checks, failures, JSON.stringify(metrics)])
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func _base_hit() -> Dictionary:
	return {
		"weapon": {"family": "gladius", "quality": 2, "wear": 0.1},
		"attacker": {"skill": 50.0, "stamina": 80.0, "injuries": []},
		"defender": {"skill": 50.0, "armor": {"torso": {"family": "lorica_hamata", "quality": 2, "wear": 0.0},
			"head": {"family": "helmet_montefortino", "quality": 2, "wear": 0.0}}, "shield": {"family": "scutum", "quality": 2, "wear": 0.0}},
		"zone": "torso", "shield_cover": 0.4,
		"contact": {"time": 0.35, "start": 0.30, "peak": 0.40, "end": 0.55},
	}


func _test_validation(b: Dictionary) -> void:
	var broken: Dictionary = b.duplicate(true)
	broken.clamps.erase("competence")
	check(not Formula.validate(broken).is_empty(), "A missing clamp is rejected")
	broken = b.duplicate(true)
	broken.quality.grades = [1.0, 0.9, 1.1, 1.2, 1.3]
	check(not Formula.validate(broken).is_empty(), "Quality grades must rise from Q0 to Q4")
	broken = b.duplicate(true)
	broken.zone_mix.head = 0.5
	check(not Formula.validate(broken).is_empty(), "The zone mix must sum to one")
	var bad := _base_hit()
	bad.erase("contact")
	check(Formula.resolve_hit(bad, b).has("error"), "A blow needs a contact time or a physics impact")
	bad = _base_hit()
	bad.impact = 1.0
	check(Formula.resolve_hit(bad, b).has("error"), "Contact time and impact together are refused (one contact factor)")
	bad = _base_hit()
	bad.weapon.family = "trident"
	check(Formula.resolve_hit(bad, b).has("error"), "Unknown weapons are refused")


func _test_product_and_clamps(b: Dictionary) -> void:
	var worst := 0.0
	var inside := true
	for skill in [0.0, 25.0, 60.0, 100.0, 250.0]:
		for q in [-3, 0, 2, 4, 9]:
			for zone in Formula.ZONES:
				for cover in [0.0, 0.5, 1.0, 3.0]:
					var hit := _base_hit()
					hit.attacker.skill = skill
					hit.weapon.quality = q
					hit.weapon.wear = 5.0 if q == 9 else 0.2
					hit.zone = zone
					hit.shield_cover = cover
					hit.attacker.stamina = -40.0 if q == -3 else 100.0
					var r := Formula.resolve_hit(hit, b)
					var product := 1.0
					for name in Formula.FACTORS:
						var range: Array = b.clamps[name]
						inside = inside and r.factors[name] >= range[0] and r.factors[name] <= range[1]
						product *= r.factors[name]
					worst = maxf(worst, absf(clampf(product, b.clamps.damage[0], b.clamps.damage[1]) - r.damage))
					inside = inside and r.damage >= b.clamps.damage[0] and r.damage <= b.clamps.damage[1]
	check(inside, "Every factor and the damage stay inside their configured clamps, even for absurd inputs")
	check(worst < 0.000001, "Damage is exactly the clamped product of the listed factors (no hidden multiplier)")
	var r := Formula.resolve_hit(_base_hit(), b)
	check(r.factors.keys() == Formula.FACTORS, "The breakdown lists exactly the handbook factors plus contact")


func _changed(a: Dictionary, c: Dictionary) -> Array:
	var moved := []
	for name in a:
		if not is_equal_approx(float(a[name]), float(c[name])):
			moved.append(name)
	moved.sort()
	return moved


func _test_factor_sources(b: Dictionary) -> void:
	var listed := {}
	for input in Formula.INPUT_FACTORS:
		for factor in Formula.INPUT_FACTORS[input]:
			check(factor in Formula.FACTORS, "Input %s names a real factor" % input)
			listed[factor] = true
	check(listed.size() == Formula.FACTORS.size(), "Every factor has at least one declared input")
	var base: Dictionary = Formula.resolve_hit(_base_hit(), b).factors
	var cases := {
		"weapon.family": func(h): h.weapon.family = "spear",
		"weapon.strike": func(h): h.weapon.strike = "cut",
		"weapon.quality": func(h): h.weapon.quality = 4,
		"weapon.wear": func(h): h.weapon.wear = 0.9,
		"attacker.skill": func(h): h.attacker.skill = 75.0,
		"attacker.stamina": func(h): h.attacker.stamina = 20.0,
		"attacker.injuries": func(h): h.attacker.injuries = ["arm_wound"],
		"zone": func(h): h.zone = "head",
		"defender.armor": func(h): h.defender.armor.torso.quality = 4,
		"defender.shield": func(h): h.defender.shield.quality = 0,
		"defender.skill": func(h): h.defender.skill = 90.0,
		"shield_cover": func(h): h.shield_cover = 0.9,
		"ranged": func(h): h.ranged = true,
		"contact": func(h): h.contact.time = 0.31,
	}
	for input in cases:
		var hit := _base_hit()
		cases[input].call(hit)
		var moved := _changed(base, Formula.resolve_hit(hit, b).factors)
		var declared: Array = Formula.INPUT_FACTORS[input].duplicate()
		declared.sort()
		check(moved == declared, "Input %s moves exactly %s (moved %s)" % [input, str(declared), str(moved)])
	var with_impact := _base_hit()
	with_impact.erase("contact")
	with_impact.impact = 0.8
	var low: Dictionary = Formula.resolve_hit(with_impact, b).factors
	with_impact.impact = 1.2
	check(_changed(low, Formula.resolve_hit(with_impact, b).factors) == ["contact"], "A physics impact moves only the contact factor")
	check(cases.size() + 1 == Formula.INPUT_FACTORS.size(), "Every declared input is exercised")


func _unit_input() -> Dictionary:
	return {"mode": "melee", "attackers": {"count": 10, "skill": 50.0, "stamina": 90.0, "weapon": {"family": "spear", "quality": 2, "wear": 0.0},
		"morale": 80.0, "cohesion": 90.0, "formation": "line", "kind": "spear", "charge": false, "elevation": 0.0},
		"defenders": {"skill": 50.0, "armor": {}, "shield": {"family": "shield_round", "quality": 2, "wear": 0.0}, "formation": "line", "braced": false, "fouled": false, "facing_dot": 1.0}}


func _test_unit_sources(b: Dictionary) -> void:
	var base := Formula.unit_strike(_unit_input(), b)
	check(base.factors.keys() == Formula.UNIT_FACTORS, "Company factors are exactly the declared tactical list")
	var expected: float = base.per_hit / b.unit.soldier_health
	for name in Formula.UNIT_FACTORS:
		expected *= base.factors[name]
	check(absf(expected - base.casualties) < 0.0000001, "Company casualties are the expected blow times the listed factors")
	var cases := {
		"attackers.count": func(u): u.attackers.count = 4,
		"mode": func(u): u.mode = "ranged",
		"attackers.morale": func(u): u.attackers.morale = 30.0,
		"attackers.cohesion": func(u): u.attackers.cohesion = 50.0,
		"attackers.elevation": func(u): u.attackers.elevation = 1.0,
		"attackers.formation": func(u): u.attackers.formation = "phalanx",
		"attackers.kind": func(u): u.attackers.kind = "infantry",
		"attackers.charge": func(u): u.attackers.charge = true,
	}
	var phalanx := _unit_input()
	phalanx.attackers.formation = "phalanx"
	var phalanx_base: Dictionary = Formula.unit_strike(phalanx, b).factors
	for input in cases:
		var u := _unit_input() if input != "attackers.kind" else phalanx.duplicate(true)
		cases[input].call(u)
		var reference: Dictionary = base.factors if input != "attackers.kind" else phalanx_base
		var moved := _changed(reference, Formula.unit_strike(u, b).factors)
		var declared: Array = Formula.UNIT_INPUT_FACTORS[input].duplicate()
		check(moved == declared, "Company input %s moves exactly %s (moved %s)" % [input, str(declared), str(moved)])
	var charged := _unit_input()
	charged.attackers.charge = true
	check(is_equal_approx(Formula.unit_strike(charged, b).casualties / base.casualties, b.unit.charge), "The charge bonus is applied once and only as its configured factor")


func _test_contact(b: Dictionary) -> void:
	var early := _base_hit()
	early.contact.time = 0.30
	var peak := _base_hit()
	peak.contact.time = 0.40
	var late := _base_hit()
	late.contact.time = 0.60
	var e := Formula.resolve_hit(early, b)
	var p := Formula.resolve_hit(peak, b)
	var l := Formula.resolve_hit(late, b)
	check(e.hit and p.hit and e.damage < p.damage and is_equal_approx(e.factors.contact, b.contact.minimum), "A blow caught at the start of its window carries less than one at its peak")
	check(not l.hit and l.damage == 0.0 and l.reason == "outside_window", "No damage outside the strike's active window")


func _test_shield_cover(b: Dictionary) -> void:
	var d := {"shield": {"family": "scutum", "quality": 2, "wear": 0.0}, "formation": "line"}
	var front := Formula.shield_cover(b, d, 1.0, false)
	var side := Formula.shield_cover(b, d, 0.0, false)
	var rear := Formula.shield_cover(b, d, -1.0, false)
	check(front > side and side > rear and rear == 0.0, "The shield covers the front, partly the side, not the back")
	var wall := d.duplicate(true)
	wall.formation = "shield_wall"
	var braced := d.duplicate(true)
	braced.braced = true
	check(Formula.shield_cover(b, wall, 1.0, false) > front and Formula.shield_cover(b, braced, 1.0, false) > front, "Shield wall and a braced stance raise the cover")
	var testudo := d.duplicate(true)
	testudo.formation = "testudo"
	var ring := d.duplicate(true)
	ring.formation = "orbis"
	check(Formula.shield_cover(b, testudo, -1.0, true) >= b.shields.testudo_missile_cover and Formula.shield_cover(b, ring, -1.0, false) > 0.0, "Testudo covers missiles from any side; the orbis has no rear")
	var fouled := d.duplicate(true)
	fouled.fouled = true
	check(Formula.shield_cover(b, fouled, 1.0, false) == 0.0, "Pila-fouled shields cover nothing")


func _kit_hit(skill: float, q: int, zone: String, cover: float, defender_skill: float, defender_q: int, stamina: float) -> Dictionary:
	return {"weapon": {"family": "gladius", "quality": q, "wear": 0.0},
		"attacker": {"skill": skill, "stamina": stamina, "injuries": []},
		"defender": {"skill": defender_skill, "health": 100.0, "armor": {"torso": {"family": "lorica_hamata", "quality": defender_q, "wear": 0.0},
			"head": {"family": "helmet_montefortino", "quality": defender_q, "wear": 0.0}}, "shield": {"family": "scutum", "quality": defender_q, "wear": 0.0}},
		"zone": zone, "shield_cover": cover, "contact": {"time": 0.40, "start": 0.30, "peak": 0.40, "end": 0.55}}


func _test_gear_versus_training(b: Dictionary) -> void:
	var fine: float = Formula.resolve_hit(_kit_hit(40.0, 4, "torso", 0.0, 40.0, 2, 100.0), b).damage
	var plain: float = Formula.resolve_hit(_kit_hit(40.0, 1, "torso", 0.0, 40.0, 2, 100.0), b).damage
	metrics["q4_over_q1_damage"] = snappedf(fine / plain, 0.001)
	check(fine / plain >= 1.15 and fine / plain <= 1.30, "Quality gear is a noticeable advantage (Q4/Q1 = %.3f)" % (fine / plain))
	# All of a novice's gear (weapon, armour and shield Q4) against one training step
	# (25 skill) in ordinary Q1 gear: the trained man deals more than he receives.
	var holds := true
	var tightest := INF
	for low in range(5, 50, 5):
		var trained: float = Formula.resolve_hit(_impact_hit(low + 25.0, 1, low, 4), b).damage
		var green: float = Formula.resolve_hit(_impact_hit(float(low), 4, low + 25.0, 1), b).damage
		holds = holds and trained > green
		tightest = minf(tightest, trained / green)
	metrics["training_over_gear_min_ratio"] = snappedf(tightest, 0.001)
	check(holds, "One step of training outweighs a full Q1-to-Q4 kit for every novice level (min exchange ratio %.3f)" % tightest)


func _impact_hit(skill: float, q: int, defender_skill: float, defender_q: int) -> Dictionary:
	var hit := _kit_hit(skill, q, "torso", 0.45, defender_skill, defender_q, 100.0)
	hit.erase("contact")
	hit.impact = 1.0
	return hit


## A deterministic exchange of blows: both sides strike in turn, each through the same
## fixed zone and shield-cover sequence; stamina is spent and partly recovered per blow.
func _duel(a: Dictionary, d: Dictionary, a_first: bool, b: Dictionary, offset: int = 0) -> Dictionary:
	var zones := ["torso", "arm_shield", "torso", "head", "leg", "torso", "arm_weapon", "torso"]
	var covers := [0.6, 0.3, 0.5, 0.2, 0.7, 0.4]
	var fighters := [a.duplicate(true), d.duplicate(true)]
	for f in fighters:
		f.health = 100.0
		f.stamina = 100.0
	var turn := 0 if a_first else 1
	var blows := [0, 0]
	for round_index in 200:
		var striker: Dictionary = fighters[turn]
		var target: Dictionary = fighters[1 - turn]
		# Each fighter walks the same zone and cover sequence with his own blow count,
		# so neither side is handed the head or the open guard more often.
		var k: int = blows[turn] + offset
		blows[turn] += 1
		var hit := _kit_hit(striker.skill, striker.q, zones[k % zones.size()], covers[k % covers.size()], target.skill, target.q, striker.stamina)
		var r := Formula.resolve_hit(hit, b)
		target.health -= r.damage
		striker.stamina = clampf(striker.stamina - r.stamina_cost + 9.0, 0.0, 100.0)
		if target.health <= 0.0:
			return {"winner": 0 if turn == 0 else 1, "rounds": round_index + 1, "left": striker.health}
		turn = 1 - turn
	return {"winner": -1, "rounds": 200, "left": 0.0}


func _test_duel(b: Dictionary) -> void:
	var veteran := {"skill": 62.0, "q": 1}
	var novice := {"skill": 25.0, "q": 4}
	var results := []
	var wins := 0
	var closest := INF
	for offset in 24:
		for first in [true, false]:
			var r := _duel(veteran, novice, first, b, offset)
			results.append(r)
			if r.winner == 0:
				wins += 1
				closest = minf(closest, r.left)
	metrics["duel_veteran_q1_vs_novice_q4"] = {"veteran_wins": wins, "duels": results.size(), "lowest_health_left": snappedf(closest, 0.01), "first": results[0]}
	check(wins == results.size(), "A veteran in ordinary gear beats a novice in master-quality gear in every one of %d sequence variants (won %d)" % [results.size(), wins])
	var gear := _duel({"skill": 25.0, "q": 4}, {"skill": 25.0, "q": 1}, false, b)
	check(gear.winner == 0, "Between equal novices the better equipped one wins")
	check(_duel(veteran, novice, true, b, 0) == results[0], "The duel is reproducible")


func _test_purity(b: Dictionary) -> void:
	var hit := _base_hit()
	var copy := hit.duplicate(true)
	Formula.resolve_hit(hit, b)
	var strike := _unit_input()
	var strike_copy := strike.duplicate(true)
	Formula.unit_strike(strike, b)
	check(hit == copy and strike == strike_copy, "The formula never changes its inputs")
	var r := Formula.resolve_hit(_kit_hit(50.0, 2, "torso", 0.5, 50.0, 2, 100.0), b)
	check(r.wear.weapon > 0.0 and r.wear.shield > 0.0 and r.wear.armor > 0.0 and r.injury in ["light", "serious"], "Wear and injury are returned for the caller to book")
	var loaded := _base_hit()
	loaded.attacker.load_kg = 30.0
	check(Formula.resolve_hit(loaded, b).stamina_cost > Formula.resolve_hit(_base_hit(), b).stamina_cost, "Armour and load raise the stamina cost")
