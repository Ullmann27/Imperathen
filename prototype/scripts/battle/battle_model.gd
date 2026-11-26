extends RefCounted
## Offline, fixed-step rules for the stand-alone valley encounter (test bench, 58 BC:
## Roman companies against an independent, fictional Germanic group; decision D-023).
## Coordinates are ground (x,z). Facing is the Y rotation of a model looking -Z.
## This model is the single authority over every soldier's existence and state (D-026).
## Visual layers read soldiers(), soldier_record() and roster(); all return copies, so a
## change of detail level can never duplicate, revive or undo a soldier.

const Field := preload("res://scripts/battle/valley_field.gd")
const Slots := preload("res://scripts/battle/formation_slots.gd")
const Catalog := preload("res://scripts/battle/troop_catalog.gd")
const Roster := preload("res://scripts/battle/soldier_roster.gd")
const FORMATIONS := Slots.NAMES
const OBSTACLES := Field.ROCKS
const ARMIES := {
	"talwache": {"name":"Heer der Talwache", "side":"ally"},
	"hoehenbund": {"name":"Heer des Höhenbundes", "side":"enemy"}
}
const GROUP_NAMES := {"front":"Linienverband", "support":"Unterstützungsverband"}
const OBJECTIVE := Vector2(0.0, 15.0)
const STEP := 0.2
const DEFENCE_SECONDS := 120
const CAPTURE_SECONDS := 8
const VOLLEY_STEPS := 9
const STRIKE_STEPS := 6
const EQUIPPED_FORMATIONS := {"shield_wall": ["infantry", "spear"], "testudo": ["infantry"],
	"phalanx": ["spear"], "wedge": ["infantry", "spear"]}
const COMMANDS := ["move", "hold", "form", "deploy", "attack", "attack_move", "defend",
	"flank", "retreat", "rally", "reserve", "focus_fire", "cease_fire"]
const SCHEMA := 3
const DEFAULT_SEED := 58
## Per-soldier speed cap. No member, and therefore no company anchor, moves faster.
const MEMBER_SPEED := 2.65
const MEMBER_STEP := MEMBER_SPEED * STEP
const ROUT_SPEED := MEMBER_SPEED
const RETREAT_SPEED := MEMBER_SPEED
## Casualty share of the first and second depth band facing the attacker; the rest
## falls deeper. Melee strikes hit the front; missiles reach further back (design values).
const MELEE_BANDS := [0.80, 0.15]
const MISSILE_BANDS := [0.40, 0.25]
const MEMORY_EVENTS := ["first_contact", "officer_fallen"]
const MAX_MEMORIES := 24
## Squad keys added by schema 3. A legacy save carries none of them (or all of them).
const SCHEMA3_KEYS := ["troop_id", "loadout", "drills", "uids", "people", "memories"]
## Data hook for later scenarios (outnumbered, defence, reinforcement, retreat,
## negotiation, capture). Only this test bench exists so far; build none of them here.
const VALLEY_SCENARIO := {
	"id": "valley_58bc",
	"year": -58,
	"companies": [
		{"id": "valley_guard", "title": "Talwache", "side": "ally", "kind": "infantry", "shape": "shield_wall", "at": Vector2(-7, 8), "count": 12,
			"troop_id": "roman_miles", "origin": "gallia_cisalpina"},
		{"id": "valley_spears", "title": "Passwache", "side": "ally", "kind": "spear", "shape": "phalanx", "at": Vector2(5, 8), "count": 10,
			"troop_id": "cisalpine_militia_spear", "origin": "valdora_district"},
		{"id": "valley_bows", "title": "Talbogner", "side": "ally", "kind": "archer", "shape": "loose", "at": Vector2(1, 13), "count": 8,
			"troop_id": "aux_sagittarius_creticus", "origin": "creta"},
		{"id": "ridge_guard", "title": "Höhenbund", "side": "enemy", "kind": "infantry", "shape": "wedge", "at": Vector2(-8, -14), "count": 12,
			"troop_id": "germanic_retainer", "origin": "hoehenbund"},
		{"id": "ridge_spears", "title": "Felsbanner", "side": "enemy", "kind": "spear", "shape": "line", "at": Vector2(6, -13), "count": 10,
			"troop_id": "germanic_levy", "origin": "hoehenbund"},
		{"id": "ridge_bows", "title": "Hangbogner", "side": "enemy", "kind": "archer", "shape": "loose", "at": Vector2(0, -18), "count": 8,
			"troop_id": "germanic_bow_skirmisher", "origin": "hoehenbund"},
	],
}

var squads: Dictionary = {}
var outcome := "ongoing"
var reason := ""
var steps := 0
var capture := 0
var battle_seed := DEFAULT_SEED
var year := -58
var scenario: Dictionary = VALLEY_SCENARIO
## Runtime measurement only (not saved): one entry per soldier taken out of the ranks.
var casualty_log: Array = []
var _remainder := 0.0
var _field := Field.new()
var _plans := {}


func _init(p_seed: int = DEFAULT_SEED, p_scenario: Dictionary = VALLEY_SCENARIO) -> void:
	battle_seed = p_seed
	scenario = p_scenario
	year = int(scenario.year)
	for company: Dictionary in scenario.companies:
		_plans[company.id] = company
	for company: Dictionary in scenario.companies:
		_add_squad(company.id, company.title, company.side, company.kind, company.shape, company.at, company.count)


static func ground_height(x: float, z: float) -> float:
	return Field.height(x, z)


## A company resolves its troop type, issued kit and drill from the era-aware catalog.
## Unknown companies (tests may add some) fall back to a minimal kind-based kit.
func _troop_for(id: String, kind: String) -> Dictionary:
	var catalog := Catalog.load_default()
	var plan: Dictionary = _plans.get(id, {})
	var troop := Catalog.troop(catalog, plan.get("troop_id", "")) if catalog.ok else {}
	if not troop.is_empty() and troop.battle_kind == kind and Catalog.valid_at(troop, year):
		return troop
	if not plan.is_empty():
		push_error("Company %s has no valid %s troop for %s." % [id, kind, Catalog.year_label(year)])
	var weapon: String = {"infantry": "gladius", "spear": "spear", "archer": "bow"}[kind]
	var loadout := {"main_hand": {"family_id": weapon, "q_min": 1, "q_max": 1}}
	if kind != "archer":
		loadout.shield = {"family_id": "shield_round", "q_min": 1, "q_max": 1}
	return {"troop_id": "", "tier": 2, "culture": "", "battle_kind": kind, "loadout": loadout, "drills": {}}


func _kit(troop: Dictionary) -> Dictionary:
	var kit := {}
	for slot in troop.loadout:
		var item: Dictionary = troop.loadout[slot]
		kit[slot] = {"family_id": item.family_id, "quality": int(item.q_min), "count": int(item.get("count", 1))}
	return kit


func _add_squad(id: String, title: String, side: String, kind: String, shape: String, at: Vector2, count: int) -> void:
	var facing := 0.0 if side == "ally" else PI
	var troop := _troop_for(id, kind)
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
		"pending_formation": "", "formation_at": 0,
		"last_action": "", "action_step": -1, "hit_step": -1, "block_step": -1,
		"wounded": 0, "dead": 0, "cohesion": 100.0, "reaction_seconds": 0.4, "ready_at": 0,
		"troop_id": troop.troop_id, "loadout": _kit(troop), "drills": troop.drills.duplicate(true),
		"uids": [], "people": {}, "memories": []}
	var catalog := Catalog.load_default()
	var plan: Dictionary = _plans.get(id, {})
	var group: Dictionary = catalog.groups.get(plan.get("origin", ""), {}) if catalog.ok else {}
	var pool: Dictionary = catalog.name_pools.get(group.get("names", ""), {}) if catalog.ok else {}
	var entry_xp := Catalog.entry_xp(catalog, troop.troop_id) if catalog.ok else 0
	for i in range(count):
		var person := Roster.identity(battle_seed, id, i, count, troop, pool, group, entry_xp, s.discipline, year)
		s.people[person.uid] = person
	var order := _arrangement(shape, count, s.commander_id, s.deputy_id, id)
	var slots := Slots.world_slots(shape, count, 0.0, at, facing)
	for i in range(count):
		s.members.append([slots[i].x, slots[i].y])
		s.uids.append(order[i])
	squads[id] = s


## Initial places: the commander fights at the right of the front rank, the deputy
## closes the rear, everyone else keeps muster order. Losses decide who falls, not slots.
func _arrangement(shape: String, count: int, commander: String, deputy: String, id: String) -> Array:
	var order := []
	for i in range(count):
		order.append(_soldier_id(id, i))
	if count < 3:
		return order
	var ranks := Slots.ranks(shape, count, 0.0)
	var front_right := ranks.rfind(0)
	order.erase(commander)
	order.erase(deputy)
	order.insert(mini(front_right, order.size()), commander)
	order.append(deputy)
	return order


static func _soldier_id(company_id: String, index: int) -> String:
	return "%s_%02d" % [company_id, index]


func company_ids(formation_group_id: String, active_only: bool = true) -> Array[String]:
	var ids: Array[String] = []
	for s: Dictionary in squads.values():
		var group_id: String = s.army_id + ("_support" if s.kind == "archer" else "_front")
		if group_id == formation_group_id and (not active_only or _active(s)):
			ids.append(s.id)
	return ids


func hierarchy() -> Dictionary:
	var result := {}
	for army_id: String in ARMIES:
		var army := {"id":army_id, "name":ARMIES[army_id].name, "side":ARMIES[army_id].side,
			"initial_strength":0, "strength":0, "groups":[]}
		for role: String in GROUP_NAMES:
			var group_id := army_id + "_" + role
			var group := {"id":group_id, "name":GROUP_NAMES[role], "initial_strength":0, "strength":0, "companies":[]}
			for id in company_ids(group_id, false):
				var s: Dictionary = squads[id]
				var members: Array[String] = []
				members.assign(s.uids)
				group.companies.append({"id":id, "name":s.name, "status":s.status,
					"initial_strength":s.initial_strength, "strength":s.strength, "soldier_ids":members})
				group.initial_strength += s.initial_strength
				group.strength += s.strength
			army.groups.append(group)
			army.initial_strength += group.initial_strength
			army.strength += group.strength
		result[army_id] = army
	return result


func soldiers(id: String) -> Array:
	var result := []
	if not squads.has(id):
		return result
	var s: Dictionary = squads[id]
	var ranks := Slots.ranks(s.formation, s.strength, s.width)
	for i in range(s.members.size()):
		var m: Array = s.members[i]
		var pose := "idle"
		if s.status == "routed":
			pose = "retreat"
		elif s.hit_step >= 0 and steps - s.hit_step < 2 and i % 3 == s.hit_step % 3:
			pose = "hit"
		elif s.block_step >= 0 and steps - s.block_step < 3 and i % 2 == 0:
			pose = "block"
		elif s.action_step >= 0 and steps - s.action_step < (5 if s.last_action == "shoot" else 3):
			pose = s.last_action
		elif s.status == "moving":
			pose = "walk"
		var uid: String = s.uids[i]
		result.append({"id": uid, "x": m[0], "z": m[1], "facing": s.facing, "pose": pose, "rank": ranks[i],
			"appearance_seed": s.people[uid].appearance_seed})
	return result


## Read-only identity record of one soldier, alive or fallen ({} if unknown).
func soldier_record(uid: String) -> Dictionary:
	for s: Dictionary in squads.values():
		if s.people.has(uid):
			return s.people[uid].duplicate(true)
	return {}


## Read-only records of everyone who ever served in a company, including the fallen.
func roster(id: String) -> Array:
	var result := []
	if squads.has(id):
		for uid in squads[id].people:
			result.append(squads[id].people[uid].duplicate(true))
	return result


func preview(id: String, start: Vector2, end: Vector2) -> Array:
	if not squads.has(id) or not start.is_finite() or not end.is_finite():
		return []
	var span := end - start
	if span.length() < 0.75 or not Field.clear_segment(start, end):
		return []
	var s: Dictionary = squads[id]
	var shape: String = s.formation if s.pending_formation == "" else s.pending_formation
	var points := Slots.world_slots(shape, s.strength, span.length(), (start + end) * 0.5, -span.angle())
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


static func can_form(kind: String, shape: String) -> bool:
	return FORMATIONS.has(shape) and (not EQUIPPED_FORMATIONS.has(shape) or kind in EQUIPPED_FORMATIONS[shape])


func _queue_formation(s: Dictionary, shape: String) -> void:
	if s.pending_formation == shape or (s.formation == shape and s.pending_formation == ""):
		return
	_delay(s)
	var enemy := _nearest(s)
	var pressed := not enemy.is_empty() and _pos(s).distance_to(_pos(enemy)) <= 5.0
	pressed = pressed or (s.hit_step >= 0 and steps - s.hit_step <= 6)
	s.formation_at = s.ready_at + (5 if pressed else 1)
	s.pending_formation = shape
	s.width = 0.0


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
		if command == "form" and (typeof(target) != TYPE_STRING or not can_form(s.kind, target)):
			return _reply(false, "Die Ausrüstung passt nicht zu dieser Formation.")
		if command == "focus_fire" and s.kind == "archer" and s.ammo == 0:
			return _reply(false, "Keine Salven mehr verfügbar.")
		if command in ["focus_fire", "cease_fire"] and s.kind != "archer":
			return _reply(false, "Dieser Befehl benötigt einen Schützenverband.")
		destinations[id] = _pos(s)
		group_center += _pos(s)
	group_center /= float(ids.size())
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
		if command == "form":
			_queue_formation(s, target)
			continue
		_delay(s)
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
	if s.officer_id == "":
		delay += 3
	elif s.officer_id != s.commander_id:
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
			_queue_formation(s, "shield_wall")
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
		if s.pending_formation != "" and steps >= s.formation_at:
			s.formation = s.pending_formation
			s.pending_formation = ""
			s.formation_at = 0
		var enemy := _nearest(s)
		if s.side == "enemy" and (steps == 1 or steps % 5 == 0):
			_ai(s, enemy)
		if s.status == "routed":
			var edge := Vector2(s.x, 21 if s.side == "ally" else -21)
			if _walk(s, edge, ROUT_SPEED):
				s.status = "withdrawn"
		else:
			_act(s, enemy, hits)
		_align_members(s)
	# Apply all attacks after every squad has acted. A casualty cannot erase
	# another squad's hit from the same simulation step.
	for id in hits:
		var s: Dictionary = squads[id]
		var hit: Dictionary = hits[id]
		s.hit_step = steps
		_remember(s, "first_contact", hit.sources[0].from)
		s.damage += hit.damage
		var lost := mini(s.strength, floori(s.damage + 0.000001))
		if lost == 0:
			continue
		s.damage = maxf(0, s.damage - lost) if lost < s.strength else 0.0
		var led_by: String = s.officer_id
		for fallen in _choose_casualties(s, lost, hit.sources):
			_fall(s, fallen)
		s.strength -= lost
		_count_losses(s)
		s.officer_id = _expected_officer(s)
		if s.officer_id != led_by:
			if led_by == s.commander_id:
				s.morale = maxf(0, s.morale - 4)
				_remember(s, "officer_fallen", led_by)
			if s.officer_id != "":
				Roster.note(s.people[s.officer_id], "took_command", led_by, year, steps)
		s.morale = maxf(0, s.morale - 84.0 * lost / s.initial_strength)
		if s.strength == 0:
			s.status = "destroyed"
			s.officer_id = ""
		elif s.morale <= 24:
			s.status = "routed"
	_evaluate()


func _add_hit(hits: Dictionary, attacker: Dictionary, target: Dictionary, damage: float, mode: String) -> void:
	if not hits.has(target.id):
		hits[target.id] = {"damage": 0.0, "sources": []}
	hits[target.id].damage += damage
	hits[target.id].sources.append({"from": attacker.id, "at": _pos(attacker), "damage": damage, "mode": mode})


## Soldiers who strike together gain experience and trust their neighbours more.
func _credit(s: Dictionary, ranged: bool) -> void:
	var ranks := Slots.ranks(s.formation, s.strength, s.width)
	for i in range(s.uids.size()):
		if ranged or ranks[i] <= 1:
			s.people[s.uids[i]].xp += 2
		if i + 1 < s.uids.size() and ranks[i] == 0 and ranks[i + 1] == 0:
			for pair in [[s.uids[i], s.uids[i + 1]], [s.uids[i + 1], s.uids[i]]]:
				var relations: Dictionary = s.people[pair[0]].relations
				relations[pair[1]] = mini(100, int(relations.get(pair[1], 0)) + 1)


func _remember(s: Dictionary, event: String, ref: String) -> void:
	if event == "first_contact":
		for m: Dictionary in s.memories:
			if m.event == event:
				return
	if s.memories.size() >= MAX_MEMORIES:
		s.memories.remove_at(0)
	s.memories.append({"event": event, "step": steps, "ref": ref})


func _expected_officer(s: Dictionary) -> String:
	if s.strength == 0:
		return ""
	if s.commander_id in s.uids:
		return s.commander_id
	return s.deputy_id if s.deputy_id in s.uids else ""


func _count_losses(s: Dictionary) -> void:
	s.dead = 0
	s.wounded = 0
	for person: Dictionary in s.people.values():
		if person.status == "dead":
			s.dead += 1
		elif person.status == "wounded":
			s.wounded += 1


func _front(s: Dictionary) -> Vector2:
	return Vector2(-sin(s.facing), -cos(s.facing))


## Picks who is taken out of the ranks. Soldiers are grouped in depth bands seen from
## the attacker; melee mostly reaches the first band, missiles reach further back.
## Within a band the less skilled are a little more likely to fall.
func _choose_casualties(s: Dictionary, lost: int, sources: Array) -> Array[String]:
	var chosen: Array[String] = []
	var alive := range(s.strength)
	var ranks := Slots.ranks(s.formation, s.strength, s.width)
	var band_depth := Slots.rank_depth(s.formation) * 0.8
	var salt := Roster.text_salt(s.id)
	var total := 0.0
	for source: Dictionary in sources:
		total += source.damage
	for k in range(lost):
		var pick := Roster.roll(battle_seed, salt, steps, k * 4) * total
		var source: Dictionary = sources.back()
		for candidate: Dictionary in sources:
			pick -= candidate.damage
			if pick < 0.0:
				source = candidate
				break
		var dir := _pos(s).direction_to(source.at)
		if dir == Vector2.ZERO:
			dir = _front(s)
		var exposure := {}
		var highest := -INF
		for i in alive:
			exposure[i] = (Vector2(s.members[i][0], s.members[i][1]) - _pos(s)).dot(dir)
			highest = maxf(highest, exposure[i])
		var weights: Array = MELEE_BANDS if source.mode == "melee" else MISSILE_BANDS
		var r := Roster.roll(battle_seed, salt, steps, k * 4 + 1)
		var band := 0 if r < weights[0] else (1 if r < weights[0] + weights[1] else 2)
		var candidates := []
		while candidates.is_empty():
			for i in alive:
				var depth := mini(2, floori((highest - exposure[i]) / band_depth))
				if depth == band:
					candidates.append(i)
			band -= 1
		var weight := []
		var sum := 0.0
		for i in candidates:
			var w := 1.5 - float(s.people[s.uids[i]].skills.melee) / 100.0 if source.mode == "melee" else 1.0
			weight.append(w)
			sum += w
		var r2 := Roster.roll(battle_seed, salt, steps, k * 4 + 2) * sum
		var victim: int = candidates.back()
		for j in range(candidates.size()):
			r2 -= weight[j]
			if r2 < 0.0:
				victim = candidates[j]
				break
		alive.erase(victim)
		chosen.append(s.uids[victim])
		casualty_log.append({"step": steps, "squad": s.id, "uid": s.uids[victim], "rank": ranks[victim],
			"band": band + 1, "mode": source.mode, "by": source.from})
	return chosen


func _fall(s: Dictionary, uid: String) -> void:
	var i: int = s.uids.find(uid)
	s.uids.remove_at(i)
	s.members.remove_at(i)
	var person: Dictionary = s.people[uid]
	var fate := Roster.casualty(battle_seed, uid, steps)
	person.status = fate.status
	person.wound = fate.wound
	Roster.note(person, "killed" if fate.status == "dead" else "wounded", "", year, steps)
	for comrade in s.uids:
		if int(s.people[comrade].relations.get(uid, 0)) >= Roster.COMRADE_BOND:
			Roster.note(s.people[comrade], "lost_comrade", uid, year, steps)


func _act(s: Dictionary, nearest: Dictionary, hits: Dictionary) -> void:
	if steps < s.ready_at or s.pending_formation != "":
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
		var bearing := atan2(-direction.x, -direction.y)
		s.facing = rotate_toward(s.facing, bearing, STEP * 3.6)
		var aligned := absf(angle_difference(s.facing, bearing)) <= 0.3
		var interval := VOLLEY_STEPS if ranged else STRIKE_STEPS
		var recovered: bool = s.action_step < 0 or steps - s.action_step >= interval
		if aligned and recovered and (not ranged or steps >= s.next_volley):
			s.action_step = steps
			s.last_action = "shoot" if ranged else "attack"
			if ranged:
				s.ammo -= 1
				s.next_volley = steps + VOLLEY_STEPS
			if _shield_factor(s, enemy, ranged) < 1.0:
				enemy.block_step = steps
			var damage := _attack_power(s, enemy, ranged) * STEP * interval
			_add_hit(hits, s, enemy, damage, "missile" if ranged else "melee")
			_credit(s, ranged)
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
			speed = RETREAT_SPEED
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
	guard *= _shield_factor(s, enemy, ranged)
	if s.formation == "phalanx" and s.kind == "spear":
		power *= 1.12
	return power * guard * (0.043 if ranged else 0.075)


func _shield_factor(s: Dictionary, enemy: Dictionary, ranged: bool) -> float:
	if ranged and enemy.formation == "testudo":
		return 0.62
	var front := Vector2(-sin(enemy.facing), -cos(enemy.facing))
	if enemy.formation == "shield_wall" and front.dot(_pos(enemy).direction_to(_pos(s))) > 0.25:
		return 0.72 if ranged else 0.87
	return 1.0


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


## Members take the nearest free slot (greedy nearest-sort), so rear ranks step up into
## gaps instead of the whole line shuffling by index. Nobody moves more than MEMBER_STEP.
func _align_members(s: Dictionary) -> void:
	var slots := Slots.world_slots(s.formation, s.strength, s.width, _pos(s), s.facing)
	var goals: Array[Vector2] = []
	for slot in slots:
		goals.append(Field.project(slot))
	_assign_slots(s, goals)
	var deviation := 0.0
	for i in range(goals.size()):
		var at := Vector2(s.members[i][0], s.members[i][1])
		var next := _field.next_position(at, goals[i], MEMBER_STEP)
		s.members[i] = [next.x, next.y]
		deviation += next.distance_to(goals[i])
	s.cohesion = clampf(100.0 - 12.0 * deviation / maxi(1, slots.size()), 0, 100)


func _assign_slots(s: Dictionary, goals: Array[Vector2]) -> void:
	var n := goals.size()
	var pairs := []
	for i in range(n):
		var at := Vector2(s.members[i][0], s.members[i][1])
		for j in range(n):
			pairs.append([at.distance_squared_to(goals[j]), i, j])
	pairs.sort()
	var member_of := []
	member_of.resize(n)
	member_of.fill(-1)
	var used := []
	used.resize(n)
	used.fill(false)
	var placed := 0
	for pair: Array in pairs:
		if member_of[pair[2]] == -1 and not used[pair[1]]:
			member_of[pair[2]] = pair[1]
			used[pair[1]] = true
			placed += 1
			if placed == n:
				break
	var members := []
	var uids := []
	for j in range(n):
		members.append(s.members[member_of[j]])
		uids.append(s.uids[member_of[j]])
	s.members = members
	s.uids = uids


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


func _result(companies: Dictionary, elapsed: int, held: int) -> Array:
	var present := {"ally": 0, "enemy": 0}
	for s: Dictionary in companies.values():
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
	return {"schema": SCHEMA, "seed": battle_seed, "steps": steps, "capture": capture, "remainder": _remainder,
		"outcome": outcome, "reason": reason, "squads": squads.duplicate(true)}


func _number(v: Variant, low: float, high: float, integer: bool = false) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(v) and v >= low and v <= high and (not integer or v == floorf(v))


## Schema 1 lacked the pending-formation and action timing fields.
func _migrate_v1(s: Dictionary) -> Variant:
	s = s.duplicate(true)
	for key in ["pending_formation", "formation_at", "last_action", "action_step", "hit_step", "block_step"]:
		if s.has(key):
			return null
	s.merge({"pending_formation":"", "formation_at":0, "last_action":"", "action_step":-1, "hit_step":-1, "block_step":-1})
	if s.has("kind") and s.has("formation") and typeof(s.kind) == TYPE_STRING and typeof(s.formation) == TYPE_STRING and FORMATIONS.has(s.formation) and not can_form(s.kind, s.formation):
		s.formation = "line"
	return s


## Schema 2 identified soldier i by its slot index and removed losses from the rear,
## counting a third of them as dead. The migration keeps exactly that history: the
## survivors are the first `strength` soldiers, the fallen are marked in the order
## they were removed, every third of them dead, and their wounds as unrecorded.
func _migrate_v2(s: Dictionary, original: Dictionary) -> Variant:
	var present := 0
	for key in SCHEMA3_KEYS:
		present += int(s.has(key))
	if present == SCHEMA3_KEYS.size():
		return s
	if present > 0 or not _number(s.get("strength"), 0, original.initial_strength, true):
		return null
	s = s.duplicate(true)
	s.troop_id = original.troop_id
	s.loadout = original.loadout.duplicate(true)
	s.drills = original.drills.duplicate(true)
	s.memories = []
	s.uids = []
	for i in range(int(s.strength)):
		s.uids.append(_soldier_id(original.id, i))
	s.people = original.people.duplicate(true)
	var k := 0
	for index in range(original.initial_strength - 1, int(s.strength) - 1, -1):
		var person: Dictionary = s.people[_soldier_id(original.id, index)]
		var dead := (k + 1) % 3 == 0
		person.status = "dead" if dead else "wounded"
		person.wound = {"severity": "unrecorded", "recovery_days": 0, "impairment": "", "outcome": "dead" if dead else "pending", "step": 0}
		Roster.note(person, "legacy_casualty", "", year, 0)
		k += 1
	return s


func _valid_people(s: Dictionary, original: Dictionary, save_steps: int) -> bool:
	if typeof(s.get("uids")) != TYPE_ARRAY or s.uids.size() != s.strength or typeof(s.get("people")) != TYPE_DICTIONARY:
		return false
	if s.people.size() != original.people.size() or not s.people.has_all(original.people.keys()):
		return false
	var company: Array = original.people.keys()
	var seen := {}
	for uid: Variant in s.uids:
		if typeof(uid) != TYPE_STRING or seen.has(uid) or not s.people.has(uid):
			return false
		seen[uid] = true
	var counts := {"active": 0, "wounded": 0, "dead": 0}
	for uid in original.people:
		var person: Variant = s.people[uid]
		if not Roster.valid_record(person, original.people[uid], company, save_steps):
			return false
		if (person.status == "active") != seen.has(uid):
			return false
		counts[person.status] += 1
	if counts.active != s.strength or counts.dead != s.dead or counts.wounded != s.wounded:
		return false
	if typeof(s.get("memories")) != TYPE_ARRAY or s.memories.size() > MAX_MEMORIES:
		return false
	for m: Variant in s.memories:
		if typeof(m) != TYPE_DICTIONARY or m.size() != 3 or not m.get("event") in MEMORY_EVENTS or typeof(m.get("ref")) != TYPE_STRING or not _number(m.get("step"), 1, save_steps, true):
			return false
	return true


func restore(save: Dictionary) -> bool:
	if not _number(save.get("schema"), 1, SCHEMA, true) or typeof(save.get("squads")) != TYPE_DICTIONARY:
		return false
	# Schema 3 adds the seed. Older saves ran on the default seed.
	if save.size() != (8 if save.has("seed") else 7) or (save.schema == SCHEMA and not save.has("seed")):
		return false
	if save.has("seed") and not _number(save.seed, 0, 2147483647, true):
		return false
	if not _number(save.get("steps"), 0, DEFENCE_SECONDS / STEP, true) or not _number(save.get("capture"), 0, CAPTURE_SECONDS / STEP, true):
		return false
	if not _number(save.get("remainder"), 0, STEP) or not save.get("outcome") in ["ongoing", "victory", "defeat", "draw"] or typeof(save.get("reason")) != TYPE_STRING:
		return false
	if save.capture > save.steps or save.remainder >= STEP or (save.outcome != "ongoing" and save.remainder != 0):
		return false
	var save_seed := int(save.get("seed", DEFAULT_SEED))
	# Validate against a pristine company list of the same seed and scenario: identities
	# are regenerated, so a save can never invent, rename or revive a soldier.
	var reference = get_script().new(save_seed, scenario)
	if save.squads.size() != reference.squads.size():
		return false
	var restored := {}
	for id in reference.squads:
		var original: Dictionary = reference.squads[id]
		var s: Variant = save.squads.get(id)
		if typeof(s) != TYPE_DICTIONARY:
			return false
		s = s.duplicate(true)
		if save.schema == 1:
			s = _migrate_v1(s)
			if s == null:
				return false
		if save.schema <= 2:
			s = _migrate_v2(s, original)
			if s == null:
				return false
		if s.size() != original.size() or not s.has_all(original.keys()):
			return false
		# Nested records hold only whole numbers; compare them with the same types.
		for key in ["loadout", "drills", "people", "memories"]:
			if not Roster.integral(s[key]):
				return false
			s[key] = Roster.integers(s[key])
		for key in ["id", "army_id", "side", "name", "kind", "initial_strength", "equipment", "experience", "discipline", "commander_id", "deputy_id", "troop_id", "loadout", "drills"]:
			if s.get(key) != original[key]:
				return false
		if not _number(s.get("strength"), 0, original.initial_strength, true) or typeof(s.get("members")) != TYPE_ARRAY or s.members.size() != s.strength:
			return false
		if not _number(s.get("dead"), 0, original.initial_strength, true) or not _number(s.get("wounded"), 0, original.initial_strength, true) or s.wounded + s.dead != original.initial_strength - s.strength:
			return false
		if not _valid_people(s, original, int(save.steps)):
			return false
		var expected_officer := ""
		if s.strength > 0:
			expected_officer = s.commander_id if s.commander_id in s.uids else (s.deputy_id if s.deputy_id in s.uids else "")
		if s.get("officer_id") != expected_officer:
			return false
		if not _number(s.get("cohesion"), 0, 100) or not _number(s.get("reaction_seconds"), 0, 2) or not _number(s.get("ready_at"), 0, save.steps + 8, true):
			return false
		if not _number(s.get("ammo"), 0, 18 if original.kind == "archer" else 0, true) or not _number(s.get("next_volley"), 0, save.steps + 9, true):
			return false
		if typeof(s.pending_formation) != TYPE_STRING or not _number(s.formation_at, 0, save.steps + 11, true):
			return false
		if (s.pending_formation == "") != (s.formation_at == 0):
			return false
		if s.pending_formation != "" and (not can_form(s.kind, s.pending_formation) or (s.formation_at <= save.steps and s.status not in ["destroyed","withdrawn"])):
			return false
		if s.last_action not in ["","attack","shoot"] or s.last_action == "shoot" and s.kind != "archer":
			return false
		for key in ["action_step", "hit_step", "block_step"]:
			if not _number(s[key], -1, save.steps, true) or s[key] == 0:
				return false
		if (s.action_step < 0) != (s.last_action == "") or (s.kind != "archer" and (s.next_volley != 0 or not s.fire)):
			return false
		if s.kind == "archer" and ((s.ammo == 18) != (s.next_volley == 0)):
			return false
		if s.last_action == "shoot" and s.next_volley != s.action_step + VOLLEY_STEPS:
			return false
		if not is_equal_approx(s.reaction_seconds / STEP, roundf(s.reaction_seconds / STEP)) or s.ready_at > save.steps + roundi(s.reaction_seconds / STEP):
			return false
		if s.reaction_seconds < 2 * STEP or s.reaction_seconds > 7 * STEP + 0.00001:
			return false
		if typeof(s.formation) != TYPE_STRING or not can_form(s.kind, s.formation) or not COMMANDS.has(s.get("command")) or not s.get("status") in ["ready","engaged","moving","routed","withdrawn","destroyed"]:
			return false
		if typeof(s.get("fire")) != TYPE_BOOL or typeof(s.get("ai_reason")) != TYPE_STRING or typeof(s.get("target")) != TYPE_STRING:
			return false
		if s.command in ["form", "cease_fire"] or (s.command == "focus_fire" and s.kind != "archer"):
			return false
		if s.command in ["attack","flank","focus_fire"] and s.target == "":
			return false
		if s.target != "" and (not reference.squads.has(s.target) or reference.squads[s.target].side == original.side):
			return false
		if not _number(s.get("morale"), 0, 100) or not _number(s.get("fatigue"), 0, 100) or not _number(s.get("damage"), 0, 1) or not _number(s.get("width"), 0, 80):
			return false
		if not _number(s.get("facing"), -TAU, TAU) or not _number(s.get("goal_facing"), -TAU, TAU):
			return false
		if not _number(s.get("x"), -28, 28) or not _number(s.get("z"), -22, 22) or not _number(s.get("goal_x"), -28, 28) or not _number(s.get("goal_z"), -22, 22):
			return false
		var goal := Vector2(s.goal_x, s.goal_z)
		if not Field.clear_segment(goal, goal) or s.damage >= 1.0:
			return false
		if not Field.clear_segment(_pos(s), _pos(s)) or (s.strength == 0) != (s.status == "destroyed"):
			return false
		for m in s.members:
			if typeof(m) != TYPE_ARRAY or m.size() != 2 or not _number(m[0], -28, 28) or not _number(m[1], -22, 22):
				return false
			if not Field.clear_segment(Vector2(m[0], m[1]), Vector2(m[0], m[1])):
				return false
		restored[id] = s.duplicate(true)
		for key in ["strength", "initial_strength", "action_step", "hit_step", "block_step", "formation_at", "ready_at", "next_volley", "ammo", "experience", "discipline", "wounded", "dead"]:
			restored[id][key] = int(s[key])
	if _result(restored, int(save.steps), int(save.capture)) != [save.outcome, save.reason]:
		return false
	squads = restored
	battle_seed = save_seed
	steps = int(save.steps)
	capture = int(save.capture)
	_remainder = float(save.remainder)
	outcome = save.outcome
	reason = save.reason
	casualty_log.clear()
	return true
