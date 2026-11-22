extends RefCounted
## Offline, fixed-step rules for the stand-alone valley encounter.
## Coordinates are ground (x,z). Facing is the Y rotation of a model looking -Z.

const Field := preload("res://scripts/battle/valley_field.gd")
const Slots := preload("res://scripts/battle/formation_slots.gd")
const FORMATIONS := Slots.NAMES
const OBSTACLES := Field.ROCKS
const OBJECTIVE := Vector2(0.0, 15.0)
const STEP := 0.2
const DEFENCE_SECONDS := 120
const CAPTURE_SECONDS := 8
const COMMANDS := ["move", "hold", "form", "deploy", "attack", "attack_move", "defend",
	"flank", "retreat", "rally", "reserve", "focus_fire", "cease_fire"]

var squads: Dictionary = {}
var outcome := "ongoing"
var reason := ""
var steps := 0
var capture := 0
var _remainder := 0.0
var _field := Field.new()


func _init() -> void:
	_add_squad("valley_guard", "Talwache", "ally", "infantry", "shield_wall", Vector2(-7, 8), 12)
	_add_squad("valley_spears", "Passwache", "ally", "spear", "phalanx", Vector2(5, 8), 10)
	_add_squad("valley_bows", "Talbogner", "ally", "archer", "loose", Vector2(1, 13), 8)
	_add_squad("ridge_guard", "Höhenbund", "enemy", "infantry", "wedge", Vector2(-8, -14), 12)
	_add_squad("ridge_spears", "Felsbanner", "enemy", "spear", "line", Vector2(6, -13), 10)
	_add_squad("ridge_bows", "Hangbogner", "enemy", "archer", "loose", Vector2(0, -18), 8)


static func ground_height(x: float, z: float) -> float:
	return Field.height(x, z)


func _add_squad(id: String, title: String, side: String, kind: String, shape: String, at: Vector2, count: int) -> void:
	var facing := 0.0 if side == "ally" else PI
	var s := {"id": id, "army_id": "talwache" if side == "ally" else "hoehenbund",
		"name": title, "side": side, "kind": kind, "formation": shape,
		"strength": count, "initial_strength": count, "morale": 90.0, "fatigue": 0.0,
		"x": at.x, "z": at.y, "facing": facing, "width": 0.0, "goal_x": at.x,
		"goal_z": at.y, "goal_facing": facing, "target": "", "fire": true,
		"command": "hold" if side == "ally" else "attack_move", "status": "ready",
		"damage": 0.0, "members": [], "ai_reason": "",
		"commander_id": "%s_%02d" % [id, count - 3], "deputy_id": id + "_00",
		"officer_id": "%s_%02d" % [id, count - 3],
		"equipment": {"infantry":"Schwert und Schild", "spear":"Speer und Schild", "archer":"Bogen"}[kind],
		"ammo": 18 if kind == "archer" else 0, "next_volley": 0,
		"experience": 52 if side == "ally" else 45, "discipline": 72 if side == "ally" else 62,
		"wounded": 0, "dead": 0, "cohesion": 100.0, "reaction_seconds": 0.4, "ready_at": 0}
	for slot in Slots.world_slots(shape, count, 0.0, at, facing):
		s.members.append([slot.x, slot.y])
	squads[id] = s


func soldiers(id: String) -> Array:
	var result := []
	if not squads.has(id):
		return result
	var s: Dictionary = squads[id]
	for i in range(s.members.size()):
		var m: Array = s.members[i]
		var pose := "idle"
		match s.status:
			"moving": pose = "walk"
			"engaged": pose = "attack"
			"routed": pose = "retreat"
		result.append({"id": "%s_%02d" % [id, i], "x": m[0], "z": m[1], "facing": s.facing, "pose": pose})
	return result


func preview(id: String, start: Vector2, end: Vector2) -> Array:
	if not squads.has(id) or not start.is_finite() or not end.is_finite():
		return []
	var span := end - start
	if span.length() < 0.75 or not Field.clear_segment(start, end):
		return []
	var s: Dictionary = squads[id]
	var points := Slots.world_slots(s.formation, s.strength, span.length(), (start + end) * 0.5, -span.angle())
	for point in points:
		if not Field.clear_segment(point, point):
			return []
	return points


func _segment(ids: Array, i: int, a: Vector2, b: Vector2) -> Array:
	return [a.lerp(b, float(i) / ids.size()), a.lerp(b, float(i + 1) / ids.size())]


func preview_group(ids: Array, start: Vector2, end: Vector2) -> Array:
	var points := []
	for i in range(ids.size()):
		var line := _segment(ids, i, start, end)
		var part := preview(ids[i], line[0], line[1])
		if part.is_empty():
			return []
		points.append_array(part)
	return points


func _reply(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}


func order(ids: Array, command: String, target: Variant = null) -> Dictionary:
	if outcome != "ongoing" or ids.is_empty() or not COMMANDS.has(command):
		return _reply(false, "Kein gültiger Befehl für diesen Gefechtsstand.")
	var destinations := {}
	var group_center := Vector2.ZERO
	for id in ids:
		if typeof(id) != TYPE_STRING or not squads.has(id) or destinations.has(id):
			return _reply(false, "Ungültige Verbandsauswahl.")
		var s: Dictionary = squads[id]
		if s.side != "ally" or s.strength < 1 or s.status == "withdrawn":
			return _reply(false, "Dieser Verband untersteht dem Befehl nicht.")
		if s.status == "routed" and command != "rally":
			return _reply(false, "Der Verband flieht. Sammeln ist noch möglich.")
		if command == "focus_fire" and s.kind == "archer" and s.ammo == 0:
			return _reply(false, "Keine Salven mehr verfügbar.")
		if command in ["focus_fire", "cease_fire"] and s.kind != "archer":
			return _reply(false, "Dieser Befehl benötigt einen Schützenverband.")
		destinations[id] = _pos(s)
		group_center += _pos(s)
	group_center /= float(ids.size())
	if command == "form" and (typeof(target) != TYPE_STRING or not FORMATIONS.has(target)):
		return _reply(false, "Unbekannte Formation.")
	if command in ["attack", "flank", "focus_fire"]:
		if typeof(target) != TYPE_STRING or not squads.has(target) or squads[target].side != "enemy" or not _active(squads[target]):
			return _reply(false, "Ein aktiver gegnerischer Verband wird benötigt.")
	if command in ["move", "attack_move", "defend"]:
		if command == "defend" and target == null:
			target = group_center
		if typeof(target) != TYPE_VECTOR2 or not Field.clear_segment(target, target):
			return _reply(false, "Dieses Ziel liegt außerhalb des begehbaren Tals.")
		for id in ids:
			var dest: Vector2 = target + (_pos(squads[id]) - group_center)
			if not Field.clear_segment(dest, dest):
				return _reply(false, "Für die Gruppe fehlt Platz am Ziel.")
			destinations[id] = dest
	if command == "deploy":
		if typeof(target) != TYPE_DICTIONARY or typeof(target.get("start")) != TYPE_VECTOR2 or typeof(target.get("end")) != TYPE_VECTOR2:
			return _reply(false, "Zwei gültige Endpunkte sind erforderlich.")
		if preview_group(ids, target.start, target.end).is_empty():
			return _reply(false, "Die Linie ist zu kurz oder versperrt.")
	for i in range(ids.size()):
		var id: String = ids[i]
		var s: Dictionary = squads[id]
		_delay(s)
		if command == "form":
			s.formation = target
			s.width = 0.0
			continue
		if command == "cease_fire":
			s.fire = false
			continue
		s.command = command
		s.target = ""
		match command:
			"deploy":
				var line := _segment(ids, i, target.start, target.end)
				_set_goal(s, (line[0] + line[1]) * 0.5)
				var span: Vector2 = line[1] - line[0]
				s.width = span.length()
				s.goal_facing = -span.angle()
			"attack", "flank", "focus_fire":
				s.target = target
				s.fire = true
			"retreat": _set_goal(s, Vector2(s.x, 20))
			"move", "attack_move", "defend": _set_goal(s, destinations[id])
			"rally":
				s.status = "ready"
				_set_goal(s, _pos(s))
			_: _set_goal(s, _pos(s))
	return _reply(true, "Befehl bestätigt.")


func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or outcome != "ongoing":
		return
	_remainder += delta
	while _remainder + 0.0000001 >= STEP and outcome == "ongoing":
		_remainder = maxf(0.0, _remainder - STEP)
		_step()
	if outcome != "ongoing":
		_remainder = 0.0


func _pos(s: Dictionary) -> Vector2:
	return Vector2(s.x, s.z)


func _set_goal(s: Dictionary, p: Vector2) -> void:
	s.goal_x = p.x
	s.goal_z = p.y


func _active(s: Dictionary) -> bool:
	return s.strength > 0 and s.status not in ["routed", "withdrawn"]


func _nearest(s: Dictionary) -> Dictionary:
	var best := {}
	var distance := INF
	for enemy: Dictionary in squads.values():
		if enemy.side == s.side or not _active(enemy):
			continue
		var d := _pos(s).distance_squared_to(_pos(enemy))
		if d < distance:
			best = enemy
			distance = d
	return best


func _delay(s: Dictionary) -> void:
	var delay := 2 if s.discipline >= 65 else 3
	if s.officer_id != s.commander_id:
		delay += 2
	if s.morale < 40:
		delay += 1
	s.ready_at = steps + delay
	s.reaction_seconds = delay * STEP


func _archer_target(s: Dictionary, fallback: Dictionary) -> Dictionary:
	for other: Dictionary in squads.values():
		if other.side == s.side or not _active(other) or other.kind != "archer":
			continue
		if _pos(s).distance_to(_pos(other)) <= 13 and Field.clear_segment(_pos(s), _pos(other)):
			return other
	return fallback


func _ai(s: Dictionary, enemy: Dictionary) -> void:
	if s.status == "withdrawn" or s.status == "routed":
		return
	var previous: String = s.command
	if s.morale < 35 or (s.command == "rally" and s.morale < 52):
		s.command = "rally"
		s.ai_reason = "Sammelt sich nach Verlusten"
		_set_goal(s, _pos(s))
	elif s.id == "ridge_spears" and steps < 45 and (enemy.is_empty() or _pos(s).distance_to(_pos(enemy)) > 10):
		s.command = "reserve"
		s.ai_reason = "Wartet als Reserve am Felsbanner"
	elif s.kind == "archer" and steps < 20:
		s.command = "move"
		_set_goal(s, Vector2(6, -16))
		s.ai_reason = "Bezieht den erhöhten Hangplatz"
	elif not enemy.is_empty() and _pos(s).distance_to(_pos(enemy)) < 15:
		if s.kind == "archer" and s.ammo > 0:
			enemy = _archer_target(s, enemy)
			s.command = "focus_fire"
			s.ai_reason = "Priorisiert sichtbare Schützen" if enemy.kind == "archer" else "Bündelt Feuer am Talweg"
		elif s.kind == "spear" and _pos(s).distance_to(_pos(enemy)) > 7:
			s.command = "flank"
			s.ai_reason = "Reserve nimmt den Seitenweg"
		else:
			s.command = "attack"
			s.ai_reason = "Gegner am Talweg"
		s.target = enemy.id
		if enemy.kind == "archer" and enemy.ammo > 0 and s.kind == "infantry":
			s.formation = "shield_wall"
			s.ai_reason = "Schließt die Schilde unter Beschuss"
	else:
		s.command = "attack_move"
		s.target = ""
		_set_goal(s, OBJECTIVE)
		s.ai_reason = "Will das Talzeichen besetzen"
	if s.command != previous:
		_delay(s)


func _step() -> void:
	steps += 1
	var hits := {}
	for s: Dictionary in squads.values():
		if s.strength == 0 or s.status == "withdrawn":
			continue
		var enemy := _nearest(s)
		if s.side == "enemy" and (steps == 1 or steps % 5 == 0):
			_ai(s, enemy)
		if s.status == "routed":
			var edge := Vector2(s.x, 21 if s.side == "ally" else -21)
			if _walk(s, edge, 3.3):
				s.status = "withdrawn"
		else:
			_act(s, enemy, hits)
		_align_members(s)
	# Apply all attacks after every squad has acted. A casualty cannot erase
	# another squad's hit from the same simulation step.
	for id in hits:
		var s: Dictionary = squads[id]
		s.damage += hits[id]
		var lost := mini(s.strength, floori(s.damage + 0.000001))
		if lost == 0:
			continue
		s.damage = maxf(0, s.damage - lost)
		s.strength -= lost
		s.members.resize(s.strength)
		var total_lost: int = s.initial_strength - s.strength
		s.dead = floori(total_lost / 3.0)
		s.wounded = total_lost - s.dead
		if s.strength <= s.initial_strength - 3 and s.officer_id == s.commander_id:
			s.officer_id = s.deputy_id
			s.morale = maxf(0, s.morale - 4)
		s.morale = maxf(0, s.morale - 84.0 * lost / s.initial_strength)
		if s.strength == 0:
			s.status = "destroyed"
			s.officer_id = ""
		elif s.morale <= 24:
			s.status = "routed"
	_evaluate()


func _act(s: Dictionary, nearest: Dictionary, hits: Dictionary) -> void:
	if steps < s.ready_at:
		s.status = "ready"
		return
	var dest := Vector2(s.goal_x, s.goal_z)
	var enemy := nearest
	if s.target != "":
		var designated: Dictionary = squads[s.target]
		if _active(designated):
			enemy = designated
		else:
			s.target = ""
			s.command = "hold"
			_set_goal(s, _pos(s))
			dest = _pos(s)
	var ranged: bool = s.kind == "archer" and s.ammo > 0
	var reach := 11.5 if ranged else 3.5
	var dist := INF if enemy.is_empty() else _pos(s).distance_to(_pos(enemy))
	var contact := not enemy.is_empty() and dist <= reach and Field.clear_segment(_pos(s), _pos(enemy))
	var pursue: bool = s.command in ["attack", "flank", "focus_fire"] or (s.command == "attack_move" and dist < 7.0)
	if pursue and not enemy.is_empty():
		dest = _pos(enemy)
		if s.command == "flank" and dist > 7:
			dest = Field.project(dest + Vector2(5 if s.x > enemy.x else -5, 1))
	var engaged: bool = contact and s.command not in ["move", "deploy", "retreat", "rally"] and (not ranged or s.fire)
	s.status = "ready"
	if engaged:
		s.status = "engaged"
		var direction := _pos(s).direction_to(_pos(enemy))
		s.facing = atan2(-direction.x, -direction.y)
		if not ranged or steps >= s.next_volley:
			var period := STEP
			if ranged:
				s.ammo -= 1
				s.next_volley = steps + 9
				period = STEP * 9
			var damage := _attack_power(s, enemy, ranged) * period
			hits[enemy.id] = float(hits.get(enemy.id, 0.0)) + damage
		s.fatigue = minf(100, s.fatigue + STEP)
	elif s.command in ["hold", "reserve", "rally"]:
		s.fatigue = maxf(0, s.fatigue - 2 * STEP)
		if s.command == "rally":
			s.morale = minf(78.0, s.morale + 4.0 * STEP) if s.morale < 78.0 else s.morale
	elif pursue and contact:
		pass
	else:
		var speed := 2.3 if s.formation == "column" else 1.85
		if s.command == "retreat":
			speed = 3.0
		if _walk(s, dest, speed):
			if s.command == "deploy":
				s.facing = s.goal_facing
			if s.command == "retreat":
				s.status = "withdrawn"
			elif s.command in ["deploy", "move"]:
				s.command = "hold"
				_set_goal(s, _pos(s))


func _attack_power(s: Dictionary, enemy: Dictionary, ranged: bool) -> float:
	var power: float = s.strength * (0.75 + s.morale * 0.0025) * (1.0 - s.fatigue * 0.002)
	power *= (0.88 + s.cohesion * 0.0012) * (0.92 + s.experience * 0.0016)
	var elevation := ground_height(s.x, s.z) - ground_height(enemy.x, enemy.z)
	power *= clampf(1.0 + 0.1 * elevation, 0.85, 1.15)
	var guard := 0.76 if enemy.command in ["defend", "hold"] else 1.0
	var front := Vector2(-sin(enemy.facing), -cos(enemy.facing))
	var from_target := _pos(enemy).direction_to(_pos(s))
	if ranged and enemy.formation == "testudo":
		guard *= 0.62
	elif enemy.formation == "shield_wall" and front.dot(from_target) > 0.25:
		guard *= 0.72 if ranged else 0.87
	if s.formation == "phalanx" and s.kind == "spear":
		power *= 1.12
	return power * guard * (0.043 if ranged else 0.075)


func _walk(s: Dictionary, dest: Vector2, speed: float) -> bool:
	var at := _pos(s)
	var next := _field.next_position(at, dest, speed * STEP)
	if next != at:
		var dir := at.direction_to(next)
		s.facing = atan2(-dir.x, -dir.y)
		s.x = next.x
		s.z = next.y
		s.fatigue = minf(100, s.fatigue + 0.22 * STEP)
		if s.status != "routed":
			s.status = "moving"
	return next.distance_to(dest) < 0.02


func _align_members(s: Dictionary) -> void:
	var slots := Slots.world_slots(s.formation, s.strength, s.width, _pos(s), s.facing)
	var deviation := 0.0
	for i in range(slots.size()):
		var at := Vector2(s.members[i][0], s.members[i][1])
		var goal := Field.project(slots[i])
		var next := _field.next_position(at, goal, 4.8 * STEP)
		s.members[i] = [next.x, next.y]
		deviation += next.distance_to(goal)
	s.cohesion = clampf(100.0 - 12.0 * deviation / maxi(1, slots.size()), 0, 100)


func _evaluate() -> void:
	var at_marker := {"ally": 0, "enemy": 0}
	for s: Dictionary in squads.values():
		if _active(s):
			if _pos(s).distance_to(OBJECTIVE) <= 4.0:
				at_marker[s.side] += 1
	capture = capture + 1 if at_marker.enemy > 0 and at_marker.ally == 0 else 0
	var result := _result(squads, steps, capture)
	outcome = result[0]
	reason = result[1]


func _result(roster: Dictionary, elapsed: int, held: int) -> Array:
	var present := {"ally": 0, "enemy": 0}
	for s: Dictionary in roster.values():
		if _active(s):
			present[s.side] += 1
	if present.ally == 0 and present.enemy == 0:
		return ["draw", "Beide Heere verlassen das Tal."]
	if present.ally == 0 or held * STEP >= CAPTURE_SECONDS:
		return ["defeat", "Das Talzeichen ist gefallen." if present.ally > 0 else "Die Talwache weicht."]
	if present.enemy == 0 or elapsed * STEP >= DEFENCE_SECONDS:
		return ["victory", "Das Talzeichen wurde gehalten." if present.enemy > 0 else "Der Höhenbund zieht ab."]
	return ["ongoing", ""]


func summary() -> Dictionary:
	var result := {"outcome": outcome, "reason": reason, "seconds": steps * STEP,
		"capture_seconds": capture * STEP, "defence_seconds": DEFENCE_SECONDS}
	for side in ["ally", "enemy"]:
		var total := {"initial": 0, "strength": 0, "losses": 0, "routed": 0, "wounded": 0, "dead": 0}
		for s: Dictionary in squads.values():
			if s.side == side:
				total.initial += s.initial_strength
				total.strength += s.strength
				total.losses += s.initial_strength - s.strength
				total.wounded += s.wounded
				total.dead += s.dead
				if s.status in ["routed", "withdrawn"]:
					total.routed += s.strength
		result[side] = total
	return result


func snapshot() -> Dictionary:
	return {"schema": 1, "steps": steps, "capture": capture, "remainder": _remainder,
		"outcome": outcome, "reason": reason, "squads": squads.duplicate(true)}


func _number(v: Variant, low: float, high: float, integer: bool = false) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(v) and v >= low and v <= high and (not integer or v == floorf(v))


func restore(save: Dictionary) -> bool:
	if save.get("schema") != 1 or typeof(save.get("squads")) != TYPE_DICTIONARY or save.squads.size() != squads.size():
		return false
	if not _number(save.get("steps"), 0, DEFENCE_SECONDS / STEP, true) or not _number(save.get("capture"), 0, CAPTURE_SECONDS / STEP, true):
		return false
	if not _number(save.get("remainder"), 0, STEP) or not save.get("outcome") in ["ongoing", "victory", "defeat", "draw"] or typeof(save.get("reason")) != TYPE_STRING:
		return false
	var restored := {}
	for id in squads:
		var original: Dictionary = squads[id]
		var s: Variant = save.squads.get(id)
		if typeof(s) != TYPE_DICTIONARY or s.size() != original.size():
			return false
		for key in ["id", "army_id", "side", "name", "kind", "initial_strength", "equipment", "experience", "discipline", "commander_id", "deputy_id"]:
			if s.get(key) != original[key]:
				return false
		if not _number(s.get("strength"), 0, original.initial_strength, true) or typeof(s.get("members")) != TYPE_ARRAY or s.members.size() != s.strength:
			return false
		if not _number(s.get("dead"), 0, original.initial_strength, true) or not _number(s.get("wounded"), 0, original.initial_strength, true) or s.wounded + s.dead != original.initial_strength - s.strength:
			return false
		var expected_officer: String = s.commander_id if s.strength > s.initial_strength - 3 else s.deputy_id
		if s.get("officer_id") != (expected_officer if s.strength > 0 else ""):
			return false
		if not _number(s.get("cohesion"), 0, 100) or not _number(s.get("reaction_seconds"), 0, 2) or not _number(s.get("ready_at"), 0, save.steps + 8, true):
			return false
		if not _number(s.get("ammo"), 0, 18 if original.kind == "archer" else 0, true) or not _number(s.get("next_volley"), 0, save.steps + 9, true):
			return false
		if not FORMATIONS.has(s.get("formation")) or not COMMANDS.has(s.get("command")) or not s.get("status") in ["ready","engaged","moving","routed","withdrawn","destroyed"]:
			return false
		if typeof(s.get("fire")) != TYPE_BOOL or typeof(s.get("ai_reason")) != TYPE_STRING or typeof(s.get("target")) != TYPE_STRING:
			return false
		if s.target != "" and (not squads.has(s.target) or squads[s.target].side == original.side):
			return false
		if not _number(s.get("morale"), 0, 100) or not _number(s.get("fatigue"), 0, 100) or not _number(s.get("damage"), 0, 1) or not _number(s.get("width"), 0, 80):
			return false
		if not _number(s.get("facing"), -TAU, TAU) or not _number(s.get("goal_facing"), -TAU, TAU):
			return false
		if not _number(s.get("x"), -28, 28) or not _number(s.get("z"), -22, 22) or not _number(s.get("goal_x"), -28, 28) or not _number(s.get("goal_z"), -22, 22):
			return false
		if not Field.clear_segment(_pos(s), _pos(s)) or (s.strength == 0) != (s.status == "destroyed"):
			return false
		for m in s.members:
			if typeof(m) != TYPE_ARRAY or m.size() != 2 or not _number(m[0], -28, 28) or not _number(m[1], -22, 22):
				return false
			if not Field.clear_segment(Vector2(m[0], m[1]), Vector2(m[0], m[1])):
				return false
		restored[id] = s.duplicate(true)
		for key in ["strength", "initial_strength", "ready_at", "next_volley", "ammo", "experience", "discipline", "wounded", "dead"]:
			restored[id][key] = int(s[key])
	if _result(restored, int(save.steps), int(save.capture)) != [save.outcome, save.reason]:
		return false
	squads = restored
	steps = int(save.steps)
	capture = int(save.capture)
	_remainder = float(save.remainder)
	outcome = save.outcome
	reason = save.reason
	return true
