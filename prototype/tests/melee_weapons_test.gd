extends SceneTree
## Data-driven weapons (D-050): catalogue, missiles through the level-A core
## (draw, hold, release, flight, shield, body) and the impact event hub that
## an audio system attaches to. No damage before the missile's path arrives.

const Core = preload("res://scripts/domain/melee/melee_core.gd")
const Tracks = preload("res://scripts/domain/melee/melee_tracks.gd")
const Data = preload("res://scripts/domain/melee/melee_track_data.gd")
const Weapons = preload("res://scripts/domain/melee/weapon_catalog.gd")
const Ranged = preload("res://scripts/domain/melee/melee_ranged.gd")
const Feedback = preload("res://scripts/domain/melee/melee_feedback.gd")
const Impacts = preload("res://scripts/domain/melee/combat_impacts.gd")
const Formula = preload("res://scripts/battle/combat_formula.gd")
const DT := 1.0 / 60.0
var checks := 0
var failures: Array[String] = []
var table: Array[String] = []
var heard: Array = []


func _initialize() -> void:
	_test_catalogue()
	_test_bow_timeline_and_contact_frame()
	_test_hold_lower_and_crossbow()
	_test_interrupted_draw()
	_test_shield_and_pilum()
	_test_formula_for_missiles()
	_test_miss_and_range()
	_test_skill_dispersion()
	_test_determinism_and_resume()
	_test_impact_hub()
	for line in table:
		print(line)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("MELEE_WEAPONS_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("MELEE_WEAPONS_PASS" if failures.is_empty() else "MELEE_WEAPONS_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _range(shooter_weapon: String, distance: float, seed := 5, shooter := {}, target := {}, target_kit := "axe_fighter") -> Dictionary:
	var state := Core.new_state(seed)
	Core.add_fighter(state, "s", "legionary", {"team":"rome", "ranged":[shooter_weapon], "skill":100.0}.merged(shooter, true))
	Core.add_fighter(state, "t", target_kit, {"team":"tribe", "z":-distance}.merged(target, true))
	Core.face(state, "t", "s")
	return state


func _run(state: Dictionary, frames: int, stop_types: Array = []) -> Array:
	var log: Array = []
	for i in frames:
		var events := Core.step(state, DT)
		log.append_array(events)
		for e: Dictionary in events:
			if e.type in stop_types:
				return log
	return log


func _first(log: Array, type: String) -> Dictionary:
	for e: Dictionary in log:
		if e.type == type:
			return e
	return {}


func _test_catalogue() -> void:
	var doc := Weapons.document()
	_check(not doc.is_empty() and Weapons.validate(doc).is_empty(), "weapons.json is valid")
	for cls: String in ["melee", "thrown", "bow", "crossbow"]:
		_check(not Weapons.of_class(cls).is_empty(), "The catalogue has a weapon of class %s" % cls)
	var families := {}
	for key: String in Data.MOVES:
		families[str(Data.MOVES[key].family)] = true
	for family: String in families:
		_check(Weapons.has(family) and not Weapons.is_ranged(family) and Weapons.effective_mass(family) > 0.0, "Measured strike family %s is a catalogued close-combat weapon" % family)
	for id: String in Weapons.ids():
		var cost := Weapons.stamina_cost(id)
		_check(cost > 0.0 and is_equal_approx(cost, float(Formula.balance().weapons[Weapons.balance_family(id)].cost)), "%s: stamina cost is the shared balance value (%.0f)" % [id, cost])
		_check(Weapons.is_ranged(id) == (not Weapons.ranged_timing(id).is_empty()), "%s: only missiles have draw/release phases" % id)
	var now := Weapons.available_in(-58)
	_check("gladius" in now and "pilum" in now and "bow" in now and "sling" in now and not "crossbow" in now, "58 BC offers gladius, pilum, bow and sling but no crossbow (%s)" % str(now))
	_check("crossbow" in Weapons.available_in(1200), "A later era finds the crossbow without code changes")
	# A weapon of another era is one data entry: no code knows its name.
	var extended: Dictionary = doc.duplicate(true)
	extended.weapons["longsword"] = {"class":"melee", "mechanism":"cut_thrust", "material":"iron", "strike_kind":"cut", "effective_mass_kg":2.1,
		"valid_from":1250, "valid_to":1550, "attestation":"design_assumption", "timing_source":"measured_clip", "balance_family":"sword_long"}
	_check(Weapons.validate(extended).is_empty(), "A later-era weapon is accepted as a plain data entry")
	var broken: Dictionary = doc.duplicate(true)
	broken.weapons.bow.material = "plastic"
	broken.weapons.pilum.erase("projectile")
	broken.weapons.axe.balance_family = "nowhere"
	_check(Weapons.validate(broken).size() >= 3, "Unknown materials, missing projectiles and missing balance entries are refused")
	var source := FileAccess.get_file_as_string("res://scripts/domain/melee/melee_core.gd")
	for id: String in Weapons.ids():
		# ("head" is also the name of a hit zone.)
		if id != "head":
			_check(not source.contains("\"" + id + "\""), "melee_core.gd does not name the weapon %s" % id)


## Independent oracle: own integration of the same published flight law and
## dense sampling of every frame's path against the upright body capsule.
func _oracle_hit_frame(weapon_id: String, origin: Vector3, velocity: Vector3, foot: Vector3, radius: float, height: float) -> int:
	var p: Dictionary = Weapons.weapon(weapon_id).projectile
	var pos := origin
	var v := velocity
	for frame in range(1, 600):
		v.y -= 9.81 * DT
		v *= 1.0 - float(p.drag_per_m) * v.length() * DT
		var next := pos + v * DT
		for i in range(1, 401):
			var q := pos.lerp(next, i / 400.0)
			var axis_y := clampf(q.y, foot.y + radius, foot.y + height - radius)
			if Vector3(q.x - foot.x, q.y - axis_y, q.z - foot.z).length() <= radius + float(p.radius_m):
				return frame
		pos = next
	return -1


func _test_bow_timeline_and_contact_frame() -> void:
	var timing := Weapons.ranged_timing("bow")
	for distance: float in [6.0, 12.0, 18.0]:
		var state := _range("bow", distance, 5, {}, {"armor":"none"})
		state.fighters.t.has_shield = false
		var ammo := int(state.fighters.s.ammo.bow)
		var stamina := float(state.fighters.s.stamina)
		_check(Core.command(state, "s", "draw", {"weapon":"bow", "target":"t"}).ok, "The archer starts the draw")
		_check(is_equal_approx(stamina - float(state.fighters.s.stamina), Weapons.stamina_cost("bow")), "The draw costs the balance file's stamina")
		_check(not Core.command(state, "s", "attack", {"move":"thrust"}).ok, "No sword stroke while the bow is drawn")
		var log: Array = []
		var health_before_hit := true
		var hit := {}
		for i in 400:
			var events := Core.step(state, DT)
			log.append_array(events)
			hit = _first(events, "projectile_hit")
			if not hit.is_empty():
				break
			health_before_hit = health_before_hit and float(state.fighters.t.health) == 100.0
		var draw := _first(log, "draw")
		var release := _first(log, "release")
		_check(int(draw.get("frame", -1)) == 1, "%.0f m: the draw event fires on the first frame of the draw" % distance)
		_check(int(release.get("frame", -1)) == int(timing.draw) + int(timing.release), "%.0f m: release on exactly the last frame of the release phase (%d)" % [distance, int(release.get("frame", -1))])
		_check(int(release.get("ammo_left", -1)) == ammo - 1 and is_equal_approx(float(release.energy_j), 37.5), "%.0f m: one arrow leaves with its launch energy (37.5 J)" % distance)
		_check(not hit.is_empty() and health_before_hit, "%.0f m: no damage before the arrow arrives" % distance)
		if hit.is_empty() or release.is_empty():
			continue
		var target: Dictionary = state.fighters.t
		var expected := _oracle_hit_frame("bow", release.point, (release.direction_vector as Vector3) * float(release.speed_m_s),
			Vector3(float(target.x), 0.0, -distance), float(target.radius), float(target.height))
		_check(int(hit.frame) == int(release.frame) + expected, "%.0f m: the hit is booked on the frame the arrow's path reaches the body (frame %d, oracle %d)" % [distance, int(hit.frame), int(release.frame) + expected])
		_check(int(hit.flight_frames) == expected and int(hit.frame) - int(release.frame) >= int(floor((distance - 1.2) / 50.0 * 60.0)), "%.0f m: flight time matches the distance (%d frames)" % [distance, int(hit.flight_frames)])
		_check(100.0 - float(target.health) == float(hit.damage) and int(hit.damage) > 0, "%.0f m: health drops by exactly the formula's damage (%d)" % [distance, int(hit.damage)])
		_check(float(hit.energy_j) < 37.5 and float(hit.damage_terms.contact) < 1.0, "%.0f m: the arrow has lost energy in flight (%.1f J)" % [distance, float(hit.energy_j)])
		_check((state.projectiles as Array).is_empty(), "%.0f m: the arrow is gone after its hit (no second hit)" % distance)
		table.append("Bogen %.0f m: draw Frame %d, release Frame %d, Treffer Frame %d (Flug %d Frames), %s, %d Schaden, %.1f J, Reaktion %s" % [distance, int(draw.frame), int(release.frame), int(hit.frame), int(hit.flight_frames), hit.zone, int(hit.damage), float(hit.energy_j), hit.reaction])


func _test_hold_lower_and_crossbow() -> void:
	var timing := Weapons.ranged_timing("bow")
	var state := _range("bow", 10.0)
	state.fighters.t.has_shield = false
	Core.command(state, "s", "draw", {"weapon":"bow"})
	var log := _run(state, int(timing.draw) + 30)
	_check(_first(log, "release").is_empty() and str(state.fighters.s.ranged.phase) == "hold", "Without an aim the drawn bow is held")
	var before := float(state.fighters.s.stamina)
	_run(state, 60)
	_check(before - float(state.fighters.s.stamina) > 2.5, "Holding a drawn bow drains stamina (%.1f per s)" % (before - float(state.fighters.s.stamina)))
	var frame := int(state.frame)
	_check(Core.command(state, "s", "loose", {"target":"t"}).ok, "The held bow can be loosed")
	log = _run(state, 30, ["release"])
	_check(int(_first(log, "release").get("frame", -1)) == frame + int(timing.release), "A held shot leaves after exactly the release phase")
	# Holding too long: the arm gives way, no shot, the arrow is kept.
	var tired := _range("bow", 10.0)
	Core.command(tired, "s", "draw", {"weapon":"bow"})
	log = _run(tired, int(timing.draw) + int(timing.hold_max) + 5)
	_check(not _first(log, "lowered").is_empty() and _first(log, "release").is_empty() and int(tired.fighters.s.ammo.bow) == 24 and tired.fighters.s.action == "idle", "An over-held bow is lowered without a shot")
	_check(Core.command(tired, "s", "lower").ok and not Core.command(tired, "s", "loose", {"target":"t"}).ok, "Nothing can be loosed from a lowered bow")
	# Crossbow: long span, then it stays loaded without effort.
	var span := Weapons.ranged_timing("crossbow")
	var cross := _range("crossbow", 10.0)
	cross.fighters.t.has_shield = false
	Core.command(cross, "s", "draw", {"weapon":"crossbow"})
	_run(cross, int(span.draw) + 1)
	var loaded := float(cross.fighters.s.stamina)
	log = _run(cross, 600)
	_check(str(cross.fighters.s.ranged.get("phase", "")) == "hold" and float(cross.fighters.s.stamina) >= loaded and _first(log, "lowered").is_empty(), "A spanned crossbow stays loaded for ten seconds without draining stamina")
	Core.command(cross, "s", "loose", {"target":"t"})
	log = _run(cross, 120, ["projectile_hit"])
	_check(not _first(log, "projectile_hit").is_empty() and int(span.draw) > 3 * int(timing.draw), "The crossbow spans far longer than a bow draws (%d vs %d frames) and then shoots" % [int(span.draw), int(timing.draw)])
	_check(not Core.command(_range("pilum", 5.0), "s", "draw", {"weapon":"bow"}).ok, "A weapon that is not carried cannot be drawn")
	var empty := _range("pilum", 5.0, 5, {"ammo":{"pilum":0}})
	_check(not Core.command(empty, "s", "draw", {"weapon":"pilum"}).ok, "No throw without a pilum left")


func _test_interrupted_draw() -> void:
	# An axe lands on an unshielded thrower in the middle of the wind-up.
	var timing := Tracks.timing("axe_fighter", "axe_overhead")
	var tip: Vector3 = Tracks.segment("axe_fighter", "axe_overhead", int(timing.peak))[1]
	var spot := Vector2(tip.x, tip.z).normalized() * (Vector2(tip.x, tip.z).length() + float(timing.radius) + float(Tracks.kit("legionary").radius) - 0.03)
	var state := Core.new_state(3)
	Core.add_fighter(state, "t", "axe_fighter", {"team":"tribe"})
	Core.add_fighter(state, "s", "legionary", {"team":"rome", "ranged":["pilum"], "x":spot.x, "z":spot.y})
	Core.face(state, "s", "t")
	state.fighters.s.has_shield = false
	Core.command(state, "t", "attack", {"move":"axe_overhead"})
	_run(state, int(timing.peak) - 20)
	_check(Core.command(state, "s", "draw", {"weapon":"pilum", "target":"t"}).ok, "The legionary starts his throw under the falling axe")
	var log := _run(state, 120)
	var hit := _first(log, "hit")
	var cut_short := false
	for e: Dictionary in log:
		cut_short = cut_short or (e.type == "interrupted" and e.get("weapon", "") == "pilum")
	_check(not hit.is_empty() and hit.reaction != "absorbed" and cut_short, "The axe hit (%s) breaks off the throw in its %s phase" % [hit.get("reaction", "-"), "draw"])
	_check(_first(log, "release").is_empty() and int(state.fighters.s.ammo.pilum) == 2 and (state.projectiles as Array).is_empty(), "A throw interrupted before its release frame throws nothing and keeps the pilum")
	table.append("Unterbrochener Wurf: Axthieb (%s) trifft im Ausholen -> kein Wurf, Pila übrig %d" % [hit.get("reaction", "-"), int(state.fighters.s.ammo.pilum)])


func _test_shield_and_pilum() -> void:
	# Frontal pilum into a raised scutum: it sticks, bends and fouls the shield.
	var state := _range("pilum", 9.0, 5, {}, {}, "legionary")
	Core.command(state, "t", "guard", {"style":"guard_front"})
	_run(state, 30)
	Core.command(state, "s", "draw", {"weapon":"pilum", "target":"t"})
	var log := _run(state, 200, ["projectile_block", "projectile_hit", "projectile_miss"])
	var block := _first(log, "projectile_block")
	_check(not block.is_empty() and bool(block.get("lodged", false)) and float(state.fighters.t.health) == 100.0, "A pilum thrown at the front of a guarding legionary sticks in the scutum, no damage")
	_check(int(state.fighters.t.shield_fouled) == 1 and is_equal_approx(Core._shield_burden(state.fighters.t), 1.5), "The bent pilum fouls the shield: every later block costs half again as much")
	_check(float(state.fighters.t.shield_integrity) < 1.0 and float(block.get("stamina_cost", 0.0)) > 0.0, "The shield and the shield arm pay for the catch (integrity %.2f, stamina %.1f)" % [float(state.fighters.t.shield_integrity), float(block.get("stamina_cost", 0.0))])
	table.append("Pilum 9 m auf Scutum-Frontdeckung: %s, steckt=%s, %.0f J, Schildintegrität %.2f, Ausdauer %.1f" % [block.get("type", "-"), str(block.get("lodged", false)), float(block.get("energy_j", 0.0)), float(state.fighters.t.shield_integrity), float(block.get("stamina_cost", 0.0))])
	# The same throw into the back: nothing covers it.
	var back := _range("pilum", 9.0, 5, {}, {}, "legionary")
	back.fighters.t.yaw = float(back.fighters.t.yaw) + PI
	Core.command(back, "s", "draw", {"weapon":"pilum", "target":"t"})
	log = _run(back, 200, ["projectile_block", "projectile_hit", "projectile_miss"])
	var hit := _first(log, "projectile_hit")
	_check(not hit.is_empty() and hit.get("direction", "") == "back" and int(hit.damage) > 0, "The same pilum from behind hits the body (%s)" % hit.get("zone", "-"))
	table.append("Pilum 9 m in den Rücken (Kettenhemd): %s, %d Schaden, %.0f J, Reaktion %s" % [hit.get("zone", "-"), int(hit.get("damage", 0)), float(hit.get("energy_j", 0.0)), hit.get("reaction", "-")])
	var scatter := Feedback.for_event(block)
	_check(not scatter.is_empty() and scatter.bursts.map(func(x): return x.kind).has("splinters") and scatter.sound.id == "wood_chop", "A pilum in the shield board throws splinters like an axe in wood")
	_check(Feedback.for_event({"type":"projectile_miss", "energy_j":30.0, "surface_material":"soil"}).bursts[0].kind == "dust", "A missile in the ground raises dust")
	# Arrow sticks without fouling; a sling bullet glances off.
	for weapon: String in ["bow", "sling"]:
		var s := _range(weapon, 9.0, 5, {}, {}, "legionary")
		Core.command(s, "t", "guard", {"style":"guard_front"})
		_run(s, 30)
		Core.command(s, "s", "draw", {"weapon":weapon, "target":"t"})
		var b := _first(_run(s, 300, ["projectile_block", "projectile_hit", "projectile_miss"]), "projectile_block")
		_check(not b.is_empty() and int(s.fighters.t.shield_fouled) == 0 and (bool(b.get("lodged", false)) == (weapon == "bow") or b.get("surface_material", "") != "wood"), "%s on the scutum: %s, the shield stays usable" % [weapon, "sticks" if weapon == "bow" else "glances off"])


func _test_formula_for_missiles() -> void:
	var results := {}
	for label: String in ["bare", "mail", "skilled_defender", "novice_shooter"]:
		var target := {"armor":"none"}
		var shooter := {}
		if label == "mail":
			target = {"armor":"mail"}
		elif label == "skilled_defender":
			target = {"armor":"none", "skill":95.0}
		elif label == "novice_shooter":
			shooter = {"skill":20.0}
		var state := _range("bow", 6.0, 5, shooter, target)
		state.fighters.t.has_shield = false
		Core.command(state, "s", "draw", {"weapon":"bow", "target":"t"})
		results[label] = _first(_run(state, 200, ["projectile_hit", "projectile_miss"]), "projectile_hit")
	var bare: Dictionary = results.bare
	_check(not bare.is_empty() and is_equal_approx(float(bare.damage_terms.weapon_base), float(Formula.balance().weapons.bow.base)) and bare.strike_kind == "arrow", "An arrow's damage is the shared formula with the bow's balance base")
	_check(bare.zone == "torso" and not (results.mail as Dictionary).is_empty() and results.mail.zone == "torso" and int(results.mail.damage) < int(bare.damage) and results.mail.surface_material == "iron", "Mail stops part of the arrow (%d vs %d)" % [int(results.mail.get("damage", 0)), int(bare.damage)])
	_check(not (results.skilled_defender as Dictionary).is_empty() and int(results.skilled_defender.damage) == int(bare.damage), "A defender's weapon skill does not parry missiles")
	var novice: Dictionary = results.novice_shooter
	_check(novice.is_empty() or int(novice.damage) < int(bare.damage), "An untrained archer's hit is weaker")
	table.append("Pfeil 6 m, Rumpf: ungerüstet %d, Kettenhemd %d, geübter Verteidiger %d, ungeübter Schütze %s" % [int(bare.damage), int(results.mail.damage), int(results.skilled_defender.damage), str(novice.get("damage", "verfehlt"))])


func _test_miss_and_range() -> void:
	for weapon: String in ["pilum", "javelin", "bow", "crossbow", "sling"]:
		var state := Core.new_state(1)
		Core.add_fighter(state, "s", "legionary", {"team":"rome", "ranged":[weapon], "skill":100.0})
		var pitch := deg_to_rad(20.0)
		Core.command(state, "s", "draw", {"weapon":weapon, "yaw":0.0, "pitch":pitch})
		var log := _run(state, 1200, ["projectile_miss"])
		var release := _first(log, "release")
		var miss := _first(log, "projectile_miss")
		_check(not miss.is_empty() and miss.surface_material == "soil" and absf((miss.point as Vector3).y) < 0.001, "%s: a shot into the open lands on the ground" % weapon)
		if miss.is_empty():
			continue
		var flown := Vector2((miss.point as Vector3).x - (release.point as Vector3).x, (miss.point as Vector3).z - (release.point as Vector3).z).length()
		# Vacuum range from the actual launch direction and height.
		var v: Vector3 = (release.direction_vector as Vector3) * float(release.speed_m_s)
		var t := (v.y + sqrt(v.y * v.y + 2.0 * 9.81 * (release.point as Vector3).y)) / 9.81
		var vacuum := Vector2(v.x, v.z).length() * t
		_check(flown <= vacuum + 0.05 and flown > vacuum * 0.80, "%s: range %.1f m is the ballistic range minus drag (vacuum %.1f m)" % [weapon, flown, vacuum])
		table.append("%s 20°: Reichweite %.1f m (ohne Luftwiderstand %.1f m), Abflug %.1f m/s, %.0f J, Aufschlag %.0f J" % [weapon, flown, vacuum, float(release.speed_m_s), float(release.energy_j), float(miss.energy_j)])
	# Aim without drag stays inside the body at level-A distances.
	for weapon: String in ["pilum", "bow", "sling"]:
		var speed := Ranged.launch_speed(weapon)
		var distance := 12.0 if weapon == "pilum" else 30.0
		var from := Vector3(0.0, 1.5, 0.0)
		var to := Vector3(0.0, 1.1, -distance)
		var aim := Ranged.aim(weapon, from, to)
		var pos := from
		var vel := Ranged.direction(float(aim.yaw), float(aim.pitch)) * speed
		var error := INF
		for i in 600:
			var next := Ranged.advance(weapon, pos, vel, DT)
			if (next[0] as Vector3).z <= to.z:
				var s := (pos.z - to.z) / (pos.z - (next[0] as Vector3).z)
				error = absf(pos.lerp(next[0], s).y - to.y)
				break
			pos = next[0]
			vel = next[1]
		_check(bool(aim.in_range) and error < 0.01, "%s: the drag-corrected aim lands on the aim point at %.0f m (%.4f m off)" % [weapon, distance, error])
		var flat := Ranged.aim_vacuum(from, to, speed)
		_check(float(aim.pitch) > float(flat.pitch), "%s: the correction raises the shot against drag" % weapon)
	_check(not bool(Ranged.aim("pilum", Vector3.ZERO, Vector3(0.0, 0.0, -200.0)).in_range), "A target beyond the weapon's range is reported as out of range")
	# A wall stops the missile.
	var walled := _range("bow", 10.0)
	walled.fighters.t.has_shield = false
	Core.command(walled, "s", "draw", {"weapon":"bow", "target":"t"})
	var log: Array = []
	for i in 200:
		log.append_array(Core.step(walled, DT, func(a: Vector3, b: Vector3) -> bool: return not (a.z > -5.0 and b.z <= -5.0)))
	_check(_first(log, "projectile_hit").is_empty() and _first(log, "projectile_miss").get("surface_material", "") == "world" and float(walled.fighters.t.health) == 100.0, "A wall between archer and target stops the arrow")


func _test_skill_dispersion() -> void:
	var hits := {}
	for skill: float in [10.0, 90.0]:
		var count := 0
		for seed in range(1, 41):
			var state := _range("bow", 25.0, seed, {"skill":skill})
			state.fighters.t.has_shield = false
			Core.command(state, "s", "draw", {"weapon":"bow", "target":"t"})
			if not _first(_run(state, 200, ["projectile_hit", "projectile_miss"]), "projectile_hit").is_empty():
				count += 1
		hits[skill] = count
	_check(int(hits[90.0]) > int(hits[10.0]) and int(hits[90.0]) >= 30, "At 25 m a trained archer hits far more often than a beginner (%d vs %d of 40)" % [int(hits[90.0]), int(hits[10.0])])
	table.append("Bogen 25 m, 40 Schüsse: Fertigkeit 90 trifft %d, Fertigkeit 10 trifft %d" % [int(hits[90.0]), int(hits[10.0])])


func _test_determinism_and_resume() -> void:
	var logs: Array = []
	for run in 2:
		var state := _range("javelin", 11.0, 77, {"skill":60.0})
		Core.command(state, "s", "draw", {"weapon":"javelin", "target":"t"})
		logs.append(var_to_str(_run(state, 240)))
	_check(logs[0] == logs[1], "The same seed gives the same throw, flight and outcome")
	var whole := _range("javelin", 11.0, 77, {"skill":60.0})
	whole.fighters.t.has_shield = false
	Core.command(whole, "s", "draw", {"weapon":"javelin", "target":"t"})
	var expected := var_to_str(_run(whole, 240))
	var first := _range("javelin", 11.0, 77, {"skill":60.0})
	first.fighters.t.has_shield = false
	Core.command(first, "s", "draw", {"weapon":"javelin", "target":"t"})
	var log := _run(first, 45)
	_check((first.projectiles as Array).size() == 1, "The javelin is in the air at the save point")
	var resumed: Dictionary = JSON.parse_string(JSON.stringify(first))
	log.append_array(_run(resumed, 195))
	_check(var_to_str(log) == expected, "A state saved as JSON with a javelin in flight resumes to the identical outcome")
	# Uneven ticks give the same frames.
	var uneven := _range("javelin", 11.0, 77, {"skill":60.0})
	uneven.fighters.t.has_shield = false
	Core.command(uneven, "s", "draw", {"weapon":"javelin", "target":"t"})
	var ulog: Array = []
	var time := 0.0
	var k := 0
	while time < 4.0 - 0.00001:
		var d := minf([0.004, 0.031, 0.0167, 0.05][k % 4], 4.0 - time)
		ulog.append_array(Core.step(uneven, d))
		time += d
		k += 1
	_check(var_to_str(ulog) == expected, "Any tick partition gives the same missile events")


func _hear(record: Dictionary) -> void:
	heard.append(record)


func _test_impact_hub() -> void:
	_check(not Impacts.has_listeners() and Impacts.publish([{"type":"hit"}]) == 0, "Without a listener nothing is published")
	Impacts.connect_listener(_hear)
	# Melee: swing at the start of the live window, impact on the contact frame.
	var reach := Core.nominal_reach("legionary", "cut_inward", float(Tracks.kit("axe_fighter").radius)) - 0.02
	var state := Core.new_state(7)
	Core.add_fighter(state, "a", "legionary", {"team":"rome"})
	var tip: Vector3 = Tracks.segment("legionary", "cut_inward", int(Tracks.timing("legionary", "cut_inward").peak))[1]
	var spot := Vector2(tip.x, tip.z).normalized() * reach
	Core.add_fighter(state, "d", "axe_fighter", {"team":"tribe", "x":spot.x, "z":spot.y})
	Core.face(state, "d", "a")
	state.fighters.d.has_shield = false
	Core.command(state, "a", "attack", {"move":"cut_inward"})
	var log := _run(state, 80, ["hit"])
	var hit := _first(log, "hit")
	var swing := heard.filter(func(r): return r.kind == "swing")
	var impact := heard.filter(func(r): return r.kind == "impact")
	_check(swing.size() == 1 and int(swing[0].clip_frame) == int(Tracks.timing("legionary", "cut_inward").start) and swing[0].material_b == "air", "One swing record at the first frame of the measured live window")
	_check(impact.size() == 1 and not hit.is_empty(), "One impact record for the hit")
	if impact.size() == 1 and not hit.is_empty():
		var r: Dictionary = impact[0]
		_check(int(r.frame) == int(hit.frame) and int(r.clip_frame) == int(hit.clip_frame) and int(r.frame) > int(swing[0].frame), "The impact record carries the contact frame of the hit")
		_check(r.material_a == "iron" and r.material_b == "leather" and r.weapon_id == "gladius" and r.weapon_class == "melee" and r.outcome == "hit", "Materials A/B and weapon class of a gladius cut on leather (%s on %s)" % [r.material_a, r.material_b])
		_check(is_equal_approx(float(r.energy_j), float(hit.energy_j)) and (r.position as Vector3).is_equal_approx(hit.point) and (r.direction as Vector3).length() > 0.99, "Energy, position and direction are the contact's own values")
	for r: Dictionary in heard:
		for field: String in Impacts.FIELDS:
			_check(r.has(field), "Record %s has the field %s" % [r.kind, field])
	# Block on the shield.
	heard.clear()
	var block := Core.new_state(7)
	Core.add_fighter(block, "a", "axe_fighter", {"team":"tribe"})
	var front := Core.nominal_reach("axe_fighter", "axe_overhead", float(Tracks.kit("legionary").radius)) - 0.05
	Core.add_fighter(block, "d", "legionary", {"team":"rome", "z":-front})
	Core.face(block, "d", "a")
	Core.command(block, "d", "guard", {"style":"guard_high"})
	_run(block, 30)
	Core.command(block, "a", "attack", {"move":"axe_overhead"})
	_run(block, 80, ["block", "parry", "guard_broken", "hit"])
	var on_shield := heard.filter(func(r): return r.kind == "impact")
	_check(on_shield.size() == 1 and on_shield[0].outcome in ["block", "parry", "guard_broken"] and on_shield[0].material_a == "iron" and on_shield[0].material_b in ["wood", "bronze", "iron"], "An axe on the scutum is an impact of iron on the shield's material (%s)" % (on_shield[0].material_b if on_shield.size() == 1 else "-"))
	# Missiles: draw, release, impact, with weapon class.
	for weapon: String in ["bow", "crossbow", "pilum"]:
		heard.clear()
		var s := _range(weapon, 7.0, 5, {}, {"armor":"mail"})
		s.fighters.t.has_shield = false
		Core.command(s, "s", "draw", {"weapon":weapon, "target":"t"})
		var events := _run(s, 400, ["projectile_hit", "projectile_miss"])
		var kinds := heard.map(func(r): return r.kind)
		_check(kinds == ["draw", "release", "impact"], "%s: draw, release and impact are published in order (%s)" % [weapon, str(kinds)])
		if kinds != ["draw", "release", "impact"]:
			continue
		var cls := Weapons.weapon_class(weapon)
		_check(heard[0].weapon_class == cls and heard[1].weapon_class == cls and heard[2].weapon_class == cls and heard[2].weapon_id == weapon, "%s: every record names the weapon class %s" % [weapon, cls])
		_check(int(heard[1].frame) == int(_first(events, "release").frame) and (heard[1].position as Vector3).is_equal_approx(_first(events, "release").point) and float(heard[1].energy_j) > 0.0, "%s: the release record carries the release frame, point and launch energy" % weapon)
		_check(heard[2].material_a == "iron" and heard[2].material_b == "iron" and int(heard[2].frame) == int(_first(events, "projectile_hit").frame) and is_equal_approx(float(heard[2].energy_j), float(_first(events, "projectile_hit").energy_j)), "%s: the impact record is iron on mail at the hit frame with the missile's energy there (%s on %s)" % [weapon, heard[2].material_a, heard[2].material_b])
		if weapon != "pilum":
			_check(heard[0].material_a == "wood" and heard[0].material_b in ["sinew", "hemp"] and heard[1].material_a in ["sinew", "hemp"], "%s: draw and release name stave and string" % weapon)
		table.append("Hub %s: draw Frame %d, release Frame %d (%.1f J), impact Frame %d (%s auf %s, %.1f J)" % [weapon, int(heard[0].frame), int(heard[1].frame), float(heard[1].energy_j), int(heard[2].frame), heard[2].material_a, heard[2].material_b, float(heard[2].energy_j)])
	# Private simulations for level B stay silent.
	heard.clear()
	Core.simulate_strike("legionary", "thrust", "axe_fighter", 1.0, 90.0)
	_check(heard.is_empty(), "simulate_strike publishes nothing (no phantom sounds)")
	Impacts.disconnect_listener(_hear)
	_check(not Impacts.has_listeners(), "The listener can detach again")
