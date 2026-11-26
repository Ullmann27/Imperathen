extends SceneTree
## Level-A melee core: frame-accurate contact, geometry, reactions, state.

const Core = preload("res://scripts/domain/melee/melee_core.gd")
const Tracks = preload("res://scripts/domain/melee/melee_tracks.gd")
const Geo = preload("res://scripts/domain/melee/melee_geometry.gd")
const AI = preload("res://scripts/domain/melee/melee_ai.gd")
const Damage = preload("res://scripts/domain/melee/melee_damage.gd")
const Formula = preload("res://scripts/battle/combat_formula.gd")
const DT := 1.0 / 60.0
var checks := 0
var failures: Array[String] = []
var table: Array[String] = []


func _initialize() -> void:
	_test_contact_frames_every_move()
	_test_whiff_out_of_reach()
	_test_interrupted_swing()
	_test_block_front_and_side()
	_test_parry_window()
	_test_dodge_is_geometric()
	_test_reaction_direction_and_strength()
	_test_stamina_fatigue_guard_break()
	_test_injury_and_morale()
	_test_determinism_and_partition()
	_test_json_resume()
	_test_shield_integrity()
	_test_measured_motion_limits()
	_test_shield_coverage()
	_test_ai_guard_choice()
	_test_ai_duel()
	_test_simulate_strike()
	_test_fighting_styles()
	_test_damage_formula()
	_test_hitstop_scales_with_impact()
	for line in table:
		print(line)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("MELEE_CORE_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("MELEE_CORE_PASS" if failures.is_empty() else "MELEE_CORE_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Defender position where the attacker's displayed tip arrives at the
## animation peak, `inside` metres inside the defender's body surface.
func _peak_spot(kit: String, move: String, defender_radius: float, inside: float) -> Vector2:
	var timing := Tracks.timing(kit, move)
	var tip: Vector3 = Tracks.segment(kit, move, int(timing.peak))[1]
	var flat := Vector2(tip.x, tip.z)
	return flat.normalized() * (flat.length() + float(timing.radius) + defender_radius - inside)


func _duel(attacker_kit: String, defender_kit: String, spot: Vector2, seed := 7) -> Dictionary:
	var state := Core.new_state(seed)
	Core.add_fighter(state, "a", attacker_kit, {"team":"rome"})
	Core.add_fighter(state, "d", defender_kit, {"team":"tribe", "x":spot.x, "z":spot.y})
	Core.face(state, "d", "a")
	return state


func _run(state: Dictionary, frames: int, stop_types: Array = []) -> Array:
	var log: Array = []
	for i in frames:
		var events := Core.step(state, DT)
		log.append_array(events)
		var done := false
		for e: Dictionary in events:
			if e.type in stop_types:
				done = true
		if done:
			break
	return log


func _first(log: Array, type: String) -> Dictionary:
	for e: Dictionary in log:
		if e.type == type:
			return e
	return {}


## Independent oracle (dense sampling, own distance code) for the first live
## frame whose swept strike touches an unshielded body capsule.
func _oracle(kit: String, move: String, spot: Vector2, radius: float, height: float, slack: float) -> int:
	var timing := Tracks.timing(kit, move)
	for frame in range(maxi(1, int(timing.start)), int(timing.end) + 1):
		var prev := Tracks.segment(kit, move, frame - 1)
		var cur := Tracks.segment(kit, move, frame)
		for k in range(1, 33):
			var s := k / 32.0
			var a: Vector3 = (prev[0] as Vector3).lerp(cur[0], s)
			var b: Vector3 = (prev[1] as Vector3).lerp(cur[1], s)
			for i in 41:
				var p := a.lerp(b, i / 40.0)
				var axis_y := clampf(p.y, radius, height - radius)
				if Vector3(p.x - spot.x, p.y - axis_y, p.z - spot.y).length() <= float(timing.radius) + radius + slack:
					return frame
	return -1


func _test_contact_frames_every_move() -> void:
	table.append("| Rig/Bewegung | Dauer | Live-Fenster (Frames) | Animations-Peak | Kontakt am Peak-Ziel | Kontakt 2 cm näher | Reichweite |")
	table.append("|---|---|---|---|---|---|---|")
	for key: String in Tracks.Data.MOVES:
		var kit := key.get_slice("/", 0)
		var move := key.get_slice("/", 1)
		var defender := "legionary" if kit != "legionary" else "axe_fighter"
		var body := Tracks.kit(defender)
		var timing := Tracks.timing(kit, move)
		var results := []
		for inside: float in [0.001, 0.02]:
			var spot := _peak_spot(kit, move, float(body.radius), inside)
			var state := _duel(kit, defender, spot)
			state.fighters.d.has_shield = false
			Core.command(state, "a", "attack", {"move":move})
			var health := float(state.fighters.d.health)
			var contact := -1
			for frame in range(1, int(timing.frames) + 1):
				var events := Core.step(state, DT)
				var hit := _first(events, "hit")
				if hit.is_empty():
					_check(float(state.fighters.d.health) == health, "%s: no damage before the displayed contact (frame %d)" % [key, frame])
					continue
				contact = int(hit.clip_frame)
				_check(contact == frame, "%s: the damage event is emitted on the frame it is computed" % key)
				break
			var loose := _oracle(kit, move, spot, float(body.radius), float(body.height), 0.0005)
			var strict := _oracle(kit, move, spot, float(body.radius), float(body.height), -0.0005)
			_check(contact >= loose and contact <= strict and contact >= int(timing.start), "%s at %.3f m inside: contact %d within oracle %d..%d" % [key, inside, contact, loose, strict])
			if inside < 0.01:
				_check(absi(contact - int(timing.peak)) <= 1, "%s: contact within one frame of the animation peak (peak %d, contact %d)" % [key, int(timing.peak), contact])
			results.append(contact)
		table.append("| %s | %.2f s | %d–%d | %d (%.3f s) | %d (%.3f s) | %d (%.3f s) | %.2f m |" % [key, float(timing.duration), int(timing.start), int(timing.end), int(timing.peak), int(timing.peak) / 60.0, results[0], results[0] / 60.0, results[1], results[1] / 60.0, float(timing.reach)])


func _test_whiff_out_of_reach() -> void:
	var timing := Tracks.timing("axe_fighter", "axe_overhead")
	var spot := _peak_spot("axe_fighter", "axe_overhead", 0.18, -0.30)
	var state := _duel("axe_fighter", "legionary", spot)
	# Without its scutum: the shield face stands 0.72 m in front of the body
	# axis and would (correctly) still meet the axe at this distance.
	state.fighters.d.has_shield = false
	Core.command(state, "a", "attack", {"move":"axe_overhead"})
	var log := _run(state, int(timing.frames) + 2)
	var whiff := _first(log, "whiff")
	_check(not whiff.is_empty() and int(whiff.clip_frame) == int(timing.end), "Out-of-reach overhead whiffs exactly when its live window closes")
	_check(_first(log, "hit").is_empty() and float(state.fighters.d.health) == 100.0, "A whiff never damages")
	_check(state.fighters.a.action == "idle", "The whiffing fighter recovers through the full clip")


func _test_interrupted_swing() -> void:
	# The axe overhead peaks at frame 33; a gladius thrust reaches the same
	# distance by frame ~25. The quicker thrust lands first and interrupts.
	var state := Core.new_state(11)
	Core.add_fighter(state, "rome", "legionary", {"team":"rome"})
	Core.add_fighter(state, "axe", "axe_fighter", {"team":"tribe", "x":0.0, "z":-1.55})
	Core.face(state, "axe", "rome")
	state.fighters.axe.has_shield = false
	Core.command(state, "axe", "attack", {"move":"axe_overhead"})
	Core.command(state, "rome", "attack", {"move":"thrust"})
	var log := _run(state, 80)
	var interrupted := _first(log, "interrupted")
	var hit := _first(log, "hit")
	_check(not hit.is_empty() and hit.attacker == "rome", "The faster thrust lands first")
	_check(not interrupted.is_empty() and interrupted.fighter == "axe", "The overhead is interrupted before its contact")
	_check(float(state.fighters.rome.health) == 100.0, "An interrupted swing deals no damage")
	var whiffs := 0
	for e: Dictionary in log:
		if e.type in ["hit", "block", "parry"] and e.attacker == "axe":
			whiffs += 1
	_check(whiffs == 0, "The interrupted axe never produces a contact event")


func _block_case(guard: String, attacker_angle_deg: float) -> Dictionary:
	# Defender at the origin facing -Z; attacker placed on a bearing
	# relative to the defender's facing, at its thrust peak distance.
	var spot := _peak_spot("legionary", "thrust", float(Tracks.kit("axe_fighter").radius), 0.02)
	var distance := spot.length()
	var bearing := deg_to_rad(attacker_angle_deg)
	var state := Core.new_state(3)
	Core.add_fighter(state, "d", "axe_fighter", {"team":"tribe"})
	Core.add_fighter(state, "a", "legionary", {"team":"rome", "x":sin(bearing) * distance, "z":-cos(bearing) * distance})
	Core.face(state, "a", "d")
	# Rotate the attacker so the thrust's own bearing points at the defender.
	state.fighters.a.yaw = float(state.fighters.a.yaw) + atan2(spot.x, -spot.y)
	if not guard.is_empty():
		Core.command(state, "d", "guard", {"style":guard})
		Core.step(state, 0.5)
	Core.command(state, "a", "attack", {"move":"thrust"})
	var log := _run(state, 60, ["hit", "block", "parry", "whiff", "guard_broken"])
	for e: Dictionary in log:
		if e.type in ["hit", "block", "parry", "whiff", "guard_broken"]:
			return e
	return {}


func _test_block_front_and_side() -> void:
	var front := _block_case("guard_front", 0.0)
	var side := _block_case("guard_front", 90.0)
	var left := _block_case("guard_left", -45.0)
	var right := _block_case("guard_right", 45.0)
	var none := _block_case("", 0.0)
	_check(front.get("type", "") == "block" and front.get("braced", false), "A frontal thrust meets the raised round shield")
	_check(side.get("type", "") == "hit", "The same thrust from the weapon side passes the front guard (%s)" % side.get("type", "-"))
	_check(left.get("type", "") == "block", "A guard turned to the front-left covers a 45-degree left attack (%s)" % left.get("type", "-"))
	_check(right.get("type", "") == "block", "A guard turned to the front-right covers a 45-degree right attack (%s)" % right.get("type", "-"))
	_check(none.get("type", "") == "block" and not none.get("braced", true), "Without a guard the shield held in stance intercepts a frontal thrust unbraced")
	var rows := []
	for guard: String in ["", "guard_front", "guard_left", "guard_right"]:
		var row := []
		for angle: float in [-90.0, -45.0, 0.0, 45.0, 90.0]:
			var r := _block_case(guard, angle)
			row.append("%s%s" % [r.get("type", "-"), ("/" + str(r.get("zone", ""))) if r.get("type", "") == "hit" else ""])
		rows.append("%s: %s" % [guard if not guard.is_empty() else "ohne Deckung", ", ".join(row)])
	table.append("Block-Matrix Gladius-Stoß gegen Axtkämpfer (Angriffswinkel -90/-45/0/45/90°, negativ = Schildseite): " + " | ".join(rows))


func _test_parry_window() -> void:
	var spot := _peak_spot("legionary", "thrust", float(Tracks.kit("axe_fighter").radius), 0.02)
	var peak := int(Tracks.timing("legionary", "thrust").peak)
	# Just-in-time: the guard rises 8 frames (0.13 s) before the peak.
	var late := _duel("legionary", "axe_fighter", spot)
	Core.command(late, "a", "attack", {"move":"thrust"})
	var log := _run(late, peak - 8)
	_check(Core.command(late, "d", "guard", {"style":"guard_front"}).ok, "Late guard can be raised")
	log.append_array(_run(late, 60, ["block", "parry", "hit"]))
	var parry := _first(log, "parry")
	_check(not parry.is_empty(), "A guard raised within %.2f s of contact parries" % Core.PARRY_WINDOW)
	var staggered := false
	for e: Dictionary in log:
		if e.type == "reaction" and e.fighter == "a" and e.kind == "parried":
			staggered = true
	_check(staggered, "A parry staggers the attacker")
	# Early: the guard was up for half a second before the thrust began.
	var early := _duel("legionary", "axe_fighter", spot)
	Core.command(early, "d", "guard", {"style":"guard_front"})
	_run(early, 30)
	Core.command(early, "a", "attack", {"move":"thrust"})
	var elog := _run(early, 60, ["block", "parry", "hit"])
	_check(not _first(elog, "block").is_empty() and _first(elog, "parry").is_empty(), "A long-held guard blocks but does not parry")
	table.append("Parade: Deckung %d Frames vor dem Peak → %s; 30 Frames vorher gehalten → %s" % [8, parry.get("type", "-"), _first(elog, "block").get("type", "-")])


func _test_dodge_is_geometric() -> void:
	var spot := _peak_spot("axe_fighter", "axe_overhead", float(Tracks.kit("legionary").radius), 0.05)
	for dodge: bool in [false, true]:
		var state := _duel("axe_fighter", "legionary", spot)
		state.fighters.d.has_shield = false
		Core.command(state, "a", "attack", {"move":"axe_overhead"})
		_run(state, 10)
		if dodge:
			_check(Core.command(state, "d", "dodge", {"style":"dodge_back"}).ok, "Dodge starts")
		var log := _run(state, 70)
		var hit := _first(log, "hit")
		if dodge:
			_check(hit.is_empty() and not _first(log, "whiff").is_empty(), "A timely backstep takes the body out of the measured arc (no invulnerability frames)")
			var moved := Vector2(float(state.fighters.d.x), float(state.fighters.d.z)).distance_to(spot)
			_check(moved > 0.5 and moved < 0.6, "Backstep root motion moves 0.55 m (moved %.3f)" % moved)
		else:
			_check(not hit.is_empty(), "Without the dodge the same overhead lands")


func _test_reaction_direction_and_strength() -> void:
	# Spear thrust into a youth: heavy impulse against low poise.
	var spot := _peak_spot("spearman", "spear_thrust", float(Tracks.kit("youth_unarmed").radius), 0.03)
	var state := _duel("spearman", "youth_unarmed", spot)
	Core.command(state, "a", "attack", {"move":"spear_thrust"})
	var log := _run(state, 60, ["hit"])
	var hit := _first(log, "hit")
	var reaction := _first(log, "reaction")
	_check(hit.get("direction", "") == "front" and reaction.get("direction", "") == "front", "A thrust from ahead is a frontal hit and reaction")
	_check(reaction.get("kind", "") in ["stagger", "stumble", "down"], "A spear thrust at least staggers a light youth (%s)" % reaction.get("kind", "-"))
	# Youth jab into a legionary's back: light impulse against high poise.
	var jab := _peak_spot("youth_unarmed", "jab_right", float(Tracks.kit("legionary").radius), 0.02)
	var back := Core.new_state(5)
	Core.add_fighter(back, "a", "youth_unarmed", {"team":"village"})
	Core.add_fighter(back, "d", "legionary", {"team":"rome", "x":jab.x, "z":jab.y})
	Core.face(back, "d", "a")
	back.fighters.d.yaw = float(back.fighters.d.yaw) + PI
	Core.command(back, "a", "attack", {"move":"jab_right"})
	var blog := _run(back, 40, ["hit"])
	var bhit := _first(blog, "hit")
	_check(bhit.get("direction", "") == "back", "A jab into the back is classified from behind (%s)" % bhit.get("direction", "-"))
	_check(bhit.get("reaction", "") in ["absorbed", "flinch"], "A child's jab barely moves an armoured adult (%s)" % bhit.get("reaction", "-"))
	_check(float(bhit.get("impulse_ratio", 9.0)) < float(hit.get("impulse_ratio", 0.0)), "Impulse ratio orders the reactions by strength")
	table.append("Reaktionen: Speerstoß→Jugendlicher %s (Impuls/Stand %.2f, %.0f J); Jugend-Gerade→Legionär von hinten %s (%.3f, %.1f J)" % [reaction.get("kind"), float(hit.get("impulse_ratio", 0)), float(hit.get("energy_j", 0)), bhit.get("reaction"), float(bhit.get("impulse_ratio", 0)), float(bhit.get("energy_j", 0))])


func _test_stamina_fatigue_guard_break() -> void:
	var state := Core.new_state(1)
	Core.add_fighter(state, "a", "axe_fighter", {"team":"tribe"})
	var before := float(state.fighters.a.stamina)
	Core.command(state, "a", "attack", {"move":"axe_overhead"})
	_check(is_equal_approx(float(state.fighters.a.stamina), before - Core.move_cost("axe_fighter", "axe_overhead")), "An attack pays its stamina cost once at the start")
	_check(float(state.fighters.a.fatigue) > 0.0, "Exertion accumulates fatigue")
	_run(state, 70)
	state.fighters.a.stamina = 3.0
	_check(not Core.command(state, "a", "attack", {"move":"axe_overhead"}).ok, "An exhausted fighter cannot start a heavy swing")
	_check(not Core.command(state, "a", "dodge", {"style":"dodge_back"}).ok, "Nor dodge")
	# Guard break: a braced block costs stamina proportional to impact energy.
	var spot := _peak_spot("axe_fighter", "axe_overhead", float(Tracks.kit("legionary").radius), 0.02)
	var duel := _duel("axe_fighter", "legionary", spot)
	Core.command(duel, "d", "guard", {"style":"guard_high"})
	_run(duel, 30)
	duel.fighters.d.stamina = 6.0
	Core.command(duel, "a", "attack", {"move":"axe_overhead"})
	var log := _run(duel, 60, ["block", "guard_broken", "hit"])
	var broken := _first(log, "guard_broken")
	_check(not broken.is_empty(), "A heavy blow on an exhausted guard breaks it")
	_check(duel.fighters.d.action == "react" and duel.fighters.d.react.kind == "guard_broken", "Guard break staggers the defender")
	var fresh := _duel("axe_fighter", "legionary", spot)
	Core.command(fresh, "d", "guard", {"style":"guard_high"})
	_run(fresh, 30)
	Core.command(fresh, "a", "attack", {"move":"axe_overhead"})
	var block := _first(_run(fresh, 60, ["block", "hit"]), "block")
	_check(not block.is_empty() and float(block.stamina_cost) >= 3.0 and float(block.stamina_cost) <= 40.0, "A rested guard absorbs the axe for an energy-dependent cost (%s)" % str(block.get("stamina_cost", "-")))
	table.append("Ausdauer: Axt-Überkopf auf Legionärs-Hochdeckung kostet %.1f Ausdauer bei %.0f J; erschöpfte Deckung bricht" % [float(block.get("stamina_cost", 0)), float(block.get("energy_j", 0))])


func _test_injury_and_morale() -> void:
	var spot := _peak_spot("axe_fighter", "axe_cut_inward", float(Tracks.kit("youth_unarmed").radius), 0.03)
	var injuries := 0
	var morale_events := []
	var state := _duel("axe_fighter", "youth_unarmed", spot, 99)
	state.fighters.d.health = 500.0
	state.fighters.d.max_health = 500.0
	for round in 8:
		state.fighters.a.stamina = 100.0
		Core.place(state, "d", spot.x, spot.y, float(state.fighters.d.yaw))
		Core.face(state, "d", "a")
		state.fighters.d.action = "idle"
		state.fighters.d.react = {}
		Core.command(state, "a", "attack", {"move":"axe_cut_inward"})
		for e: Dictionary in _run(state, 70):
			if e.type == "injury":
				injuries += 1
				_check(e.kind in ["concussion", "bleeding", "arm_wound", "shield_arm_wound", "leg_wound"], "Injury kind follows the hit zone")
			if e.type == "morale" and e.fighter == "d":
				morale_events.append(e.state)
	_check(injuries > 0, "Repeated axe cuts injure (seeded, %d injuries)" % injuries)
	_check("wavering" in morale_events, "Taking hits drives morale to wavering (%s)" % str(morale_events))
	_check(float(state.fighters.d.morale) < float(state.fighters.a.morale), "The attacker's morale stays above the battered defender's")
	var ext := Core.morale_event(state, "a", -80.0, "ally_fell")
	_check(not ext.is_empty() and ext[0].state == "breaking", "Level B can push an external morale event (ally fell) to breaking")
	# Effects: arm wound slows and weakens; leg wound shortens the dodge.
	var hurt := Core.new_state(1)
	Core.add_fighter(hurt, "x", "legionary", {})
	hurt.fighters.x.injuries.append({"kind":"arm_wound", "zone":"arm_weapon", "severity":0.5, "frame":0})
	hurt.fighters.x.injuries.append({"kind":"leg_wound", "zone":"leg", "severity":0.5, "frame":0})
	_check(Core._tempo(hurt.fighters.x) < 1.0, "A weapon-arm wound slows the clip tempo")
	Core.command(hurt, "x", "dodge", {"style":"dodge_back"})
	_run(hurt, 40)
	var moved := Vector2(float(hurt.fighters.x.x), float(hurt.fighters.x.z)).length()
	_check(moved < 0.40, "A leg wound shortens the backstep (%.3f m)" % moved)
	table.append("Verletzungen in 8 Axthieben (Seed 99): %d; Moral des Verteidigers %.1f (%s)" % [injuries, float(state.fighters.d.morale), str(morale_events)])


func _exchange_log(seed: int, partition: Array) -> String:
	var state := Core.new_state(seed)
	Core.add_fighter(state, "rome", "legionary", {"team":"rome"})
	Core.add_fighter(state, "tribe", "axe_fighter", {"team":"tribe", "x":0.1, "z":-1.45})
	Core.face(state, "tribe", "rome")
	var log: Array = []
	var script := [[0, "rome", "attack", {"move":"cut_inward"}], [5, "tribe", "guard", {"style":"guard_front"}], [70, "tribe", "release", {}],
		[72, "tribe", "attack", {"move":"axe_cut_outward"}], [80, "rome", "guard", {"style":"guard_front"}], [150, "rome", "release", {}],
		[152, "rome", "attack", {"move":"thrust"}], [220, "tribe", "attack", {"move":"axe_overhead"}]]
	var elapsed := 0
	var p := 0
	while elapsed < 320:
		for entry: Array in script:
			if int(entry[0]) == elapsed:
				Core.command(state, entry[1], entry[2], entry[3])
		var step := mini(int(partition[p % partition.size()]), 320 - elapsed)
		p += 1
		# Never step across a scripted command frame.
		for entry: Array in script:
			if int(entry[0]) > elapsed and int(entry[0]) < elapsed + step:
				step = int(entry[0]) - elapsed
		for e: Dictionary in Core.step(state, step * DT):
			log.append(JSON.stringify(e))
		elapsed += step
	return "\n".join(log) + "\n" + JSON.stringify(state.fighters)


func _test_determinism_and_partition() -> void:
	var fine := _exchange_log(42, [1])
	var coarse := _exchange_log(42, [7, 3, 11])
	var again := _exchange_log(42, [1])
	_check(fine == again, "Same seed and commands replay identically")
	_check(fine == coarse, "Event log and state are independent of the tick partition")
	_check(fine.contains("\"type\":\"block\"") or fine.contains("\"type\":\"hit\""), "The scripted exchange produces contact events")
	var series := _hit_series(42)
	_check(series == _hit_series(42), "A seeded series of real hits replays identically")
	var differs := false
	for seed in [1, 2, 3, 4, 5]:
		if _hit_series(seed) != series:
			differs = true
	_check(differs, "Seeded damage/injury variance changes outcomes across seeds")


func _hit_series(seed: int) -> String:
	var spot := _peak_spot("axe_fighter", "axe_cut_inward", float(Tracks.kit("legionary").radius), 0.03)
	var state := _duel("axe_fighter", "legionary", spot, seed)
	state.fighters.d.has_shield = false
	state.fighters.d.health = 400.0
	var out := []
	for round in 6:
		state.fighters.a.stamina = 100.0
		Core.place(state, "d", spot.x, spot.y, 0.0)
		Core.face(state, "d", "a")
		state.fighters.d.action = "idle"
		state.fighters.d.react = {}
		Core.command(state, "a", "attack", {"move":"axe_cut_inward"})
		for e: Dictionary in _run(state, 70):
			if e.type in ["hit", "injury"]:
				out.append("%s:%s:%s" % [e.type, str(e.get("damage", "")), str(e.get("kind", ""))])
	return ",".join(out)


func _test_json_resume() -> void:
	var spot := _peak_spot("legionary", "cut_outward", float(Tracks.kit("axe_fighter").radius), 0.02)
	var a := _duel("legionary", "axe_fighter", spot)
	a.fighters.d.has_shield = false
	Core.command(a, "a", "attack", {"move":"cut_outward"})
	_run(a, 12)
	var b: Dictionary = JSON.parse_string(JSON.stringify(a))
	var la := _run(a, 80)
	var lb := _run(b, 80)
	_check(JSON.stringify(la) == JSON.stringify(lb), "A swing saved mid-windup resolves identically after a JSON round trip")
	var hits := 0
	for e: Dictionary in lb:
		if e.type == "hit":
			hits += 1
	_check(hits == 1, "The resumed swing books exactly one hit")


func _test_shield_integrity() -> void:
	var spot := _peak_spot("axe_fighter", "axe_overhead", float(Tracks.kit("legionary").radius), 0.02)
	var state := _duel("axe_fighter", "legionary", spot)
	var broke := false
	for round in 40:
		state.fighters.a.stamina = 100.0
		state.fighters.d.stamina = 100.0
		if state.fighters.d.action != "guard":
			state.fighters.d.action = "idle"
			Core.command(state, "d", "guard", {"style":"guard_high"})
		Core.command(state, "a", "attack", {"move":"axe_overhead"})
		for e: Dictionary in _run(state, 65):
			if e.type == "shield_broken":
				broke = true
		if broke:
			break
	_check(broke and float(state.fighters.d.shield_integrity) <= 0.0, "Repeated axe blows split the scutum")
	_check(Core.shield_world(state.fighters.d).is_empty(), "A broken shield no longer blocks")


func _test_measured_motion_limits() -> void:
	for key: String in Tracks.Data.MOVES:
		var m: Dictionary = Tracks.Data.MOVES[key]
		_check(float(m.support_slip_m) <= 0.015, "%s: planted feet slide %.4f m (motion-gate limit 0.015)" % [key, float(m.support_slip_m)])
		_check(float(m.driving_bone_top_speed) <= 12.0, "%s: driving bone %.2f m/s within the 12 m/s rig limit" % [key, float(m.driving_bone_top_speed)])
		_check(float(m.pelvis_outside_support_m) <= 0.02, "%s: pelvis stays over the support line (%.3f m)" % [key, float(m.pelvis_outside_support_m)])


func _test_shield_coverage() -> void:
	# Horizontal half-angle covered by the raised shield, seen from the
	# defender's body axis: atan(half width / distance of the shield face).
	var result := {}
	for kit: String in ["legionary", "axe_fighter", "spearman"]:
		var shield: Array = Tracks.shield(kit, "guard_front", 11)
		var c: Vector3 = shield[0]
		var spec: Dictionary = Tracks.kit(kit).shield
		var half := float(spec.radius) if spec.shape == "disc" else float(spec.half[0])
		var distance := Vector2(c.x, c.z).length()
		result[kit] = rad_to_deg(atan(half / distance))
		var vertical := float(spec.radius) if spec.shape == "disc" else float(spec.half[1])
		table.append("Schild %s: Breite ±%.2f m, Höhe ±%.2f m, Mitte %.2f m vor der Körperachse auf %.2f m Höhe → Deckungswinkel ±%.0f°" % [kit, half, vertical, distance, c.y, result[kit]])
	_check(result.legionary > result.axe_fighter, "The wide scutum covers a wider angle than the round shield")


func _test_ai_guard_choice() -> void:
	var spot := _peak_spot("axe_fighter", "axe_overhead", float(Tracks.kit("legionary").radius), 0.02)
	var state := _duel("axe_fighter", "legionary", spot)
	Core.command(state, "a", "attack", {"move":"axe_overhead"})
	_run(state, 22)
	var decision := AI.decide(state, "d", "a", 1.0)
	_check(decision.action == "guard" and decision.args.style == "guard_high", "AI raises a high guard against a descending axe (%s)" % JSON.stringify(decision))
	AI.apply(state, "d", "a", decision, DT)
	var log := _run(state, 40, ["block", "parry", "hit"])
	_check(not _first(log, "block").is_empty() or not _first(log, "parry").is_empty(), "The chosen guard actually stops the axe")


func _ai_duel(seed: int, rome_shield := true) -> Dictionary:
	var state := Core.new_state(seed)
	Core.add_fighter(state, "rome", "legionary", {"team":"rome", "x":0.0, "z":0.0})
	Core.add_fighter(state, "tribe", "axe_fighter", {"team":"tribe", "x":0.3, "z":-4.0})
	state.fighters.rome.has_shield = rome_shield
	var counts := {}
	var min_gap := INF
	var finite := true
	for frame in 60 * 25:
		for pair: Array in [["rome", "tribe"], ["tribe", "rome"]]:
			AI.apply(state, pair[0], pair[1], AI.decide(state, pair[0], pair[1]), DT)
		for e: Dictionary in Core.step(state, DT):
			counts[e.type] = int(counts.get(e.type, 0)) + 1
		var a: Dictionary = state.fighters.rome
		var b: Dictionary = state.fighters.tribe
		for f: Dictionary in [a, b]:
			finite = finite and is_finite(float(f.x)) and is_finite(float(f.z)) and is_finite(float(f.health)) and is_finite(float(f.stamina))
		if bool(a.alive) and bool(b.alive):
			min_gap = minf(min_gap, Vector2(float(a.x) - float(b.x), float(a.z) - float(b.z)).length() - float(a.radius) - float(b.radius))
		if not bool(a.alive) or not bool(b.alive):
			break
	return {"counts":counts, "gap":min_gap, "finite":finite, "state":JSON.stringify(state.fighters)}


func _test_ai_duel() -> void:
	var first := _ai_duel(8)
	var again := _ai_duel(8)
	var c: Dictionary = first.counts
	_check(first.state == again.state, "An AI duel replays identically for one seed")
	_check(first.finite, "AI duel state stays finite")
	_check(int(c.get("block", 0)) + int(c.get("parry", 0)) >= 3, "Two shield-bearers close to the measured reach and catch frontal strikes (%s)" % JSON.stringify(c))
	var o := {}
	var gap := INF
	for seed in range(1, 7):
		var open := _ai_duel(seed, false)
		gap = minf(gap, float(open.gap))
		for key: String in open.counts:
			o[key] = int(o.get(key, 0)) + int(open.counts[key])
	_check(int(o.get("hit", 0)) >= 1, "Without a shield the fallible defence lets real hits through (seeds 1-6: %s)" % JSON.stringify(o))
	_check(gap >= -0.01, "No interpenetration in the open duels (%.3f m)" % gap)
	table.append("KI-Duelle ohne Scutum (Seeds 1-6, je bis 25 s, summiert): " + JSON.stringify(o))
	_check(float(first.gap) >= -0.01, "Fighters never interpenetrate (min gap %.3f m)" % float(first.gap))
	table.append("KI-Duell Legionär gegen Axtkämpfer (Seed 8, bis 25 s): " + JSON.stringify(c) + (", kleinster Körperabstand %.3f m" % float(first.gap)))


func _test_simulate_strike() -> void:
	var reach := Core.nominal_reach("legionary", "thrust", float(Tracks.kit("axe_fighter").radius))
	var front := Core.simulate_strike("legionary", "thrust", "axe_fighter", reach - 0.02, 0.0, "guard_front")
	var side := Core.simulate_strike("legionary", "thrust", "axe_fighter", reach - 0.02, 90.0, "guard_front")
	var far := Core.simulate_strike("legionary", "thrust", "axe_fighter", reach + 1.0, 0.0, "", 1, {"health":100.0})
	_check(front.get("type", "") == "block", "Level-B helper: frontal thrust into a front guard is a block (%s)" % front.get("type", "-"))
	_check(side.get("type", "") == "hit" and int(side.clip_frame) >= int(Tracks.timing("legionary", "thrust").start), "Level-B helper: weapon-side thrust is a hit on a live frame (%s)" % side.get("type", "-"))
	_check(far.get("type", "") == "whiff", "Level-B helper: out of reach is a whiff (%s)" % far.get("type", "-"))
	_check(JSON.stringify(side) == JSON.stringify(Core.simulate_strike("legionary", "thrust", "axe_fighter", reach - 0.02, 90.0, "guard_front")), "Level-B helper is deterministic")
	table.append("simulate_strike (Ebene B): Stoß frontal in guard_front=%s (Frame %s), Waffenseite=%s (Frame %s, %s, %s Schaden), 1 m zu weit=%s" % [front.get("type"), str(front.get("clip_frame")), side.get("type"), str(side.get("clip_frame")), side.get("zone", "-"), str(side.get("damage", "-")), far.get("type")])


func _test_fighting_styles() -> void:
	var counts := {}
	for kit: String in ["legionary", "axe_fighter"]:
		var state := Core.new_state(5)
		Core.add_fighter(state, "f", kit, {"team":"a"})
		Core.add_fighter(state, "t", "legionary", {"team":"b", "z":-6.0})
		var tally := {}
		for i in 400:
			state.frame = i
			var m: Dictionary = AI.best_move(state, state.fighters.f, state.fighters.t)
			tally[m.move] = int(tally.get(m.move, 0)) + 1
		counts[kit] = tally
	var leg: Dictionary = counts.legionary
	var axe: Dictionary = counts.axe_fighter
	_check(int(leg.get("thrust", 0)) > 400 * 0.45, "The legionary style stabs most of the time (%s)" % JSON.stringify(leg))
	_check(int(axe.get("axe_overhead", 0)) > int(axe.get("axe_cut_outward", 0)), "The axe style favours the overhead chop (%s)" % JSON.stringify(axe))
	var spear := Core.nominal_reach("spearman", "spear_thrust", 0.2) - float(AI.STYLES.spearman.spacing)
	var axe_reach := Core.nominal_reach("axe_fighter", "axe_overhead", 0.2) - float(AI.STYLES.axe_fighter.spacing)
	_check(spear > axe_reach + 0.6, "The spearman engages from well outside the axe's distance (%.2f vs %.2f m)" % [spear, axe_reach])
	table.append("Kampfstile (400 Entscheidungen): Legionär %s; Axtkämpfer %s; Einsatzdistanz Speer %.2f m gegen Axt %.2f m" % [JSON.stringify(leg), JSON.stringify(axe), spear, axe_reach])


func _test_damage_formula() -> void:
	# D-042: level A has no formula or balance value of its own; every hit is
	# resolved by the shared combat_formula.gd with combat_balance.json.
	var b: Dictionary = Formula.balance()
	var hit := {"weapon_id":"gladius", "strike_kind":"cut", "weapon_quality":2, "weapon_wear":0.0, "skill":65.0, "stamina":90.0,
		"injuries":[], "zone":"torso", "defender_skill":40.0, "armor_pieces":{}, "impact":1.0, "contact_frame":27}
	var r := Damage.compute(hit)
	var t: Dictionary = r.terms
	var shared := Formula.resolve_hit({"weapon":{"family":"gladius", "quality":2, "wear":0.0, "strike":"cut"},
		"attacker":{"skill":65.0, "stamina":90.0, "injuries":[]}, "defender":{"skill":40.0, "armor":{}}, "zone":"torso",
		"shield_cover":0.0, "impact":1.0})
	_check(bool(shared.hit) and is_equal_approx(float(t.raw), float(shared.damage)) and r.damage == int(roundf(float(shared.damage))), "Level A books exactly the shared formula's damage (%d)" % r.damage)
	var product := 1.0
	for name: String in Formula.FACTORS:
		product *= float(t[name])
	_check(is_equal_approx(product, float(t.raw)) and int(t.contact_frame) == 27, "Damage is the product of the six reported factors, nothing else")
	_check(is_equal_approx(float(t.weapon_base), float(b.weapons.gladius.base)), "The weapon base is the balance file's value (%.0f)" % float(t.weapon_base))
	_check(JSON.stringify(Damage.compute(hit)) == JSON.stringify(r), "The formula is a pure, reproducible function")
	var script := FileAccess.get_file_as_string("res://scripts/domain/melee/melee_damage.gd") + FileAccess.get_file_as_string("res://scripts/domain/melee/melee_core.gd")
	_check(not script.contains("BALANCE") and not script.contains("ZONE_DAMAGE") and not script.contains("BASE_DAMAGE"), "No second balance table remains in the level-A core")
	var veteran: int = Damage.compute(hit.merged({"skill":80.0, "weapon_quality":1}, true)).damage
	var recruit: int = Damage.compute(hit.merged({"skill":25.0, "weapon_quality":4}, true)).damage
	_check(veteran > recruit, "A trained fighter with ordinary gear outdamages a recruit with the best gear (%d vs %d)" % [veteran, recruit])
	var best: int = Damage.compute(hit.merged({"weapon_quality":4}, true)).damage
	_check(best > r.damage and float(Damage.compute(hit.merged({"weapon_quality":99}, true)).terms.quality) <= float(b.clamps.quality[1]), "Better equipment helps noticeably and stays clamped (%d > %d)" % [best, r.damage])
	var head: int = Damage.compute(hit.merged({"zone":"head"}, true)).damage
	var mail: int = Damage.compute(hit.merged({"armor_pieces":Damage.kit_armor("mail")}, true)).damage
	var helmet: int = Damage.compute(hit.merged({"zone":"head", "armor_pieces":{"head":{"family":"helmet_montefortino", "quality":2, "wear":0.0}}}, true)).damage
	_check(head > r.damage and mail < r.damage and helmet < head, "Hit zone and protection act in the expected direction (torso %d, head %d, helmet %d, mail %d)" % [r.damage, head, helmet, mail])
	var tired: int = Damage.compute(hit.merged({"stamina":2.0}, true)).damage
	var worn: int = Damage.compute(hit.merged({"weapon_wear":1.0}, true)).damage
	var wounded: int = Damage.compute(hit.merged({"injuries":[{"kind":"arm_wound"}]}, true)).damage
	var jammed: int = Damage.compute(hit.merged({"impact":0.2}, true)).damage
	var parried: int = Damage.compute(hit.merged({"defender_skill":95.0}, true)).damage
	_check(tired < r.damage and worn < r.damage and wounded < r.damage and jammed < r.damage and parried < r.damage, "Exhaustion, weapon wear, a weapon-arm wound, an early jammed contact and a skilled defender each weaken the blow (%d %d %d %d %d)" % [tired, worn, wounded, jammed, parried])
	_check(Damage.compute(hit.merged({"weapon_id":"unknown"}, true)).damage == 0, "An unknown weapon deals no damage")
	# The core books exactly the formula's result at the contact frame.
	var spot := _peak_spot("legionary", "cut_inward", float(Tracks.kit("axe_fighter").radius), 0.02)
	var state := _duel("legionary", "axe_fighter", spot)
	state.fighters.d.has_shield = false
	Core.command(state, "a", "attack", {"move":"cut_inward"})
	var event := _first(_run(state, 60, ["hit"]), "hit")
	_check(not event.is_empty() and event.has("damage_terms") and int(event.damage_terms.contact_frame) == int(event.clip_frame), "Each hit reports its formula terms with the measured contact frame")
	_check(not event.is_empty() and 100.0 - float(state.fighters.d.health) == float(event.damage), "Health changes by exactly the formula's damage")
	var flesh := float(b.wear.weapon_per_hit.flesh)
	_check(is_equal_approx(float(state.fighters.a.weapon_wear), flesh), "Weapon wear is booked from the formula's wear output (%.3f)" % float(state.fighters.a.weapon_wear))
	# Trained beats equipped in the simulated strike itself, not only on paper.
	var reach := Core.nominal_reach("legionary", "thrust", float(Tracks.kit("axe_fighter").radius)) - 0.02
	var ordinary: Dictionary = Core.simulate_strike("legionary", "thrust", "axe_fighter", reach, 90.0, "guard_front", 3, {}, {"skill":80.0, "weapon_quality":1})
	var fine: Dictionary = Core.simulate_strike("legionary", "thrust", "axe_fighter", reach, 90.0, "guard_front", 3, {}, {"skill":25.0, "weapon_quality":4})
	_check(ordinary.get("type", "") == "hit" and fine.get("type", "") == "hit" and int(ordinary.damage) > int(fine.damage), "In the core, the veteran's ordinary blade wounds deeper than the recruit's master blade (%s vs %s)" % [ordinary.get("damage"), fine.get("damage")])
	table.append("Schadensformel D-042 (gemeinsames Modul; Gladius-Hieb, Rumpf, ungerüstet, Fertigkeit 65 gegen 40): %d; Veteran (80)/Q1 %d gegen Rekrut (25)/Q4 %d; Kopf %d, Helm %d, Kettenhemd %d; erschöpft %d, verschlissen %d, Armwunde %d, gestaucht %d, geübter Verteidiger %d" % [r.damage, veteran, recruit, head, helmet, mail, tired, worn, wounded, jammed, parried])


func _test_hitstop_scales_with_impact() -> void:
	# The striker's impact pause follows the energy of the contact and holds
	# the clip exactly that many frames before the weapon rebounds.
	var pauses := {}
	for entry: Array in [["youth_unarmed", "jab_left"], ["legionary", "thrust"], ["axe_fighter", "axe_overhead"]]:
		var spot := _peak_spot(entry[0], entry[1], float(Tracks.kit("raider").radius), 0.02)
		var state := _duel(entry[0], "raider", spot)
		state.fighters.d.has_shield = false
		Core.command(state, "a", "attack", {"move":entry[1]})
		var hit := _first(_run(state, 90, ["hit"]), "hit")
		_check(not hit.is_empty() and int(hit.get("hitstop_frames", 0)) == Core.hitstop_frames(float(hit.energy_j), false), "%s: the hit reports its impact pause" % entry[1])
		if hit.is_empty():
			continue
		var held := 0
		var t := float(state.fighters.a.t)
		var rebound := -1
		for i in 12:
			var events := Core.step(state, DT)
			if state.fighters.a.action == "attack" and is_equal_approx(float(state.fighters.a.t), t):
				held += 1
			for e: Dictionary in events:
				if e.type == "reaction" and e.fighter == "a" and e.kind == "recoil" and rebound < 0:
					rebound = i + 1
		_check(rebound == int(hit.hitstop_frames) and held == rebound - 1, "%s: the clip is held for the pause and rebounds on its last frame (%d frames, %.0f J)" % [entry[1], int(hit.hitstop_frames), float(hit.energy_j)])
		pauses[entry[1]] = [int(hit.hitstop_frames), float(hit.energy_j)]
	_check(pauses.size() == 3 and pauses.jab_left[0] < pauses.axe_overhead[0] and pauses.jab_left[0] >= int(Core.HITSTOP_RANGE[0]) and pauses.axe_overhead[0] <= int(Core.HITSTOP_RANGE[1]), "A child's jab checks shorter than a full axe blow (%s)" % JSON.stringify(pauses))
	_check(Core.hitstop_frames(200.0, true) == Core.hitstop_frames(200.0, false) + 1, "A shield holds the weapon one frame longer than a body")
	table.append("Trefferpause nach Aufprallenergie [Frames, J]: %s" % JSON.stringify(pauses))
