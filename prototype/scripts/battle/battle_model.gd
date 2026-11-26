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
const Life := preload("res://scripts/battle/soldier_life.gd")
const Formula := preload("res://scripts/battle/combat_formula.gd")
## Formations that can be drawn along a front. SHAPES adds the all-round orbis.
const Muster := preload("res://scripts/battle/valley_muster.gd")

const FORMATIONS := Slots.NAMES
const SHAPES := {"line": "Linie", "column": "Marschkolonne", "shield_wall": "Schildwall",
	"testudo": "Schilddach / Testudo", "wedge": "Keil", "loose": "Lockere Ordnung",
	"phalanx": "Speerformation / Phalanx", "orbis": "Kreis / Orbis"}
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
	"phalanx": ["spear"], "wedge": ["infantry", "spear", "cavalry"], "orbis": ["infantry", "spear"]}
const COMMANDS := ["move", "hold", "form", "deploy", "attack", "attack_move", "defend",
	"flank", "retreat", "rally", "reserve", "focus_fire", "cease_fire",
	"follow", "advance", "fall_back", "charge", "face", "pila", "fire_at_will", "mount", "dismount"]
## Orders that only change a modifier and are never stored as the company's command.
const MODIFIERS := ["form", "cease_fire", "fire_at_will", "mount", "dismount"]
const ENEMY_TARGETED := ["attack", "flank", "focus_fire", "charge", "pila", "advance"]
## Orders that move the company; a company standing in the orbis must re-form first.
const MOVING_COMMANDS := ["move", "attack_move", "deploy", "attack", "flank", "retreat", "follow", "advance", "fall_back", "charge"]
## Orders (design values, P4).
const TURN_RATE := 3.6
const ADVANCE_STANDOFF := 6.0
const FALL_BACK_DISTANCE := 10.0
const FALL_BACK_SPEED := 1.0
const CHARGE_SPEED := 2.65
const CHARGE_COHESION := 15.0
const PILA_RANGE := 12.0
const PILA_FOUL_STEPS := 50
const PILA_BANDS := [0.60, 0.30]
const SCHEMA := 4
const DEFAULT_SEED := 58
## Per-soldier speed cap. No member, and therefore no company anchor, moves faster.
const MEMBER_SPEED := 2.65
const MOUNT_SPEED_FACTOR := 1.55
const MEMBER_STEP := MEMBER_SPEED * STEP
const ROUT_SPEED := MEMBER_SPEED
const RETREAT_SPEED := MEMBER_SPEED
## Casualty share of the first and second depth band facing the attacker; the rest
## falls deeper. Melee strikes hit the front; missiles reach further back (design values).
const MELEE_BANDS := [0.80, 0.15]
const MISSILE_BANDS := [0.40, 0.25]
const MEMORY_EVENTS := ["first_contact", "officer_fallen", "banner_lost", "routed", "rallied", "pila_volley", "charge_impact"]
const MAX_MEMORIES := 24
## Morale and rally (design values, P3). A routed company only becomes ready again when
## it has rallied: morale at least RALLY_MORALE, RALLY_STEPS since the rally order took
## effect, no fighting enemy within RALLY_CLEARANCE and a living commander or deputy.
const ROUT_MORALE := 24.0
const RALLY_MORALE := 40.0
const RALLY_CLEARANCE := 8.0
const RALLY_STEPS := 25
const RALLY_RATE := 4.0
const CONTAGION_RADIUS := 12.0
const CONTAGION_SHOCK := 8.0
const REAR_FACTOR := 1.5
const BANNER_SHOCK := 15.0
## Squad keys added by schema 3 and 4. A legacy save carries none of them (or all of them).
const SCHEMA3_KEYS := ["troop_id", "loadout", "drills", "uids", "people", "memories", "signifer_id", "rally_from",
	"commandable_by", "pila", "shields_fouled_until", "charge_bonus"]
const SCHEMA4_KEYS := ["wear", "tiers"]
## Companies that fight at range while their missiles last.
const RANGED_KINDS := ["archer", "skirmisher"]
const ARROWS := 18
## Data hook for later scenarios (outnumbered, defence, reinforcement, retreat,
## negotiation, capture). Only this test bench exists so far; build none of them here.
## Command rights follow appointments (D-023, D-025): order() acts for an appointment,
## and only companies that list it in commandable_by obey. Without an appointment (the
## twelve-year-old in the campaign) nothing can be commanded.
## The bench as published first (bow skirmishers on the hill). Saves written before the
## spear-throwers became the regular Germanic ranged troop (D-041) keep this composition.
const VALLEY_SCENARIO_V1 := {
	"id": "valley_58bc",
	"year": -58,
	"player_appointment": "legatus_valdora",
	"appointments": {
		"legatus_valdora": {"type": "legatus", "side": "ally"},
		"centurio_valley_guard": {"type": "centurio", "side": "ally"},
		"praefectus_valley_spears": {"type": "praefectus", "side": "ally"},
		"praefectus_valley_bows": {"type": "praefectus", "side": "ally"},
		"dux_hoehenbund": {"type": "dux", "side": "enemy"},
		"princeps_ridge_guard": {"type": "princeps", "side": "enemy"},
	},
	"companies": [
		{"id": "valley_guard", "title": "Talwache", "side": "ally", "kind": "infantry", "shape": "shield_wall", "at": Vector2(-7, 8), "count": 12,
			"troop_id": "roman_miles", "origin": "gallia_cisalpina", "commandable_by": ["legatus_valdora", "centurio_valley_guard"]},
		{"id": "valley_spears", "title": "Passwache", "side": "ally", "kind": "spear", "shape": "phalanx", "at": Vector2(5, 8), "count": 10,
			"troop_id": "cisalpine_militia_spear", "origin": "valdora_district", "commandable_by": ["legatus_valdora", "praefectus_valley_spears"]},
		{"id": "valley_bows", "title": "Talbogner", "side": "ally", "kind": "archer", "shape": "loose", "at": Vector2(1, 13), "count": 8,
			"troop_id": "aux_sagittarius_creticus", "origin": "creta", "commandable_by": ["legatus_valdora", "praefectus_valley_bows"]},
		{"id": "ridge_guard", "title": "Höhenbund", "side": "enemy", "kind": "infantry", "shape": "wedge", "at": Vector2(-8, -14), "count": 12,
			"troop_id": "germanic_retainer", "origin": "hoehenbund", "commandable_by": ["dux_hoehenbund", "princeps_ridge_guard"]},
		{"id": "ridge_spears", "title": "Felsbanner", "side": "enemy", "kind": "spear", "shape": "line", "at": Vector2(6, -13), "count": 10,
			"troop_id": "germanic_levy", "origin": "hoehenbund", "commandable_by": ["dux_hoehenbund"]},
		{"id": "ridge_bows", "title": "Hangbogner", "side": "enemy", "kind": "archer", "shape": "loose", "at": Vector2(0, -18), "count": 8,
			"troop_id": "germanic_bow_skirmisher", "origin": "hoehenbund", "commandable_by": ["dux_hoehenbund"]},
	],
}

## Current bench: the Germanic ranged company throws javelins (D-041). Its id stays
## ridge_bows so orders, saves and tests keep addressing the same company.
const VALLEY_SCENARIO := {
	"id": "valley_58bc_v2",
	"year": -58,
	"player_appointment": "legatus_valdora",
	"appointments": {
		"legatus_valdora": {"type": "legatus", "side": "ally"},
		"centurio_valley_guard": {"type": "centurio", "side": "ally"},
		"praefectus_valley_spears": {"type": "praefectus", "side": "ally"},
		"praefectus_valley_bows": {"type": "praefectus", "side": "ally"},
		"dux_hoehenbund": {"type": "dux", "side": "enemy"},
		"princeps_ridge_guard": {"type": "princeps", "side": "enemy"},
	},
	"companies": [
		{"id": "valley_guard", "title": "Talwache", "side": "ally", "kind": "infantry", "shape": "shield_wall", "at": Vector2(-7, 8), "count": 12,
			"troop_id": "roman_miles", "origin": "gallia_cisalpina", "commandable_by": ["legatus_valdora", "centurio_valley_guard"]},
		{"id": "valley_spears", "title": "Passwache", "side": "ally", "kind": "spear", "shape": "phalanx", "at": Vector2(5, 8), "count": 10,
			"troop_id": "cisalpine_militia_spear", "origin": "valdora_district", "commandable_by": ["legatus_valdora", "praefectus_valley_spears"]},
		{"id": "valley_bows", "title": "Talbogner", "side": "ally", "kind": "archer", "shape": "loose", "at": Vector2(1, 13), "count": 8,
			"troop_id": "aux_sagittarius_creticus", "origin": "creta", "commandable_by": ["legatus_valdora", "praefectus_valley_bows"]},
		{"id": "ridge_guard", "title": "Höhenbund", "side": "enemy", "kind": "infantry", "shape": "wedge", "at": Vector2(-8, -14), "count": 12,
			"troop_id": "germanic_retainer", "origin": "hoehenbund", "commandable_by": ["dux_hoehenbund", "princeps_ridge_guard"]},
		{"id": "ridge_spears", "title": "Felsbanner", "side": "enemy", "kind": "spear", "shape": "line", "at": Vector2(6, -13), "count": 10,
			"troop_id": "germanic_levy", "origin": "hoehenbund", "commandable_by": ["dux_hoehenbund"]},
		{"id": "ridge_bows", "title": "Hangspeerwerfer", "side": "enemy", "kind": "skirmisher", "shape": "loose", "at": Vector2(0, -18), "count": 8,
			"troop_id": "germanic_skirmisher", "origin": "hoehenbund", "commandable_by": ["dux_hoehenbund"]},
	],
}
const SCENARIOS := {"valley_58bc": VALLEY_SCENARIO_V1, "valley_58bc_v2": VALLEY_SCENARIO}

var squads: Dictionary = {}
var outcome := "ongoing"
var reason := ""
var steps := 0
var capture := 0
var battle_seed := DEFAULT_SEED
var year := -58
var scenario: Dictionary = VALLEY_SCENARIO
## Appointment the player currently holds; order() acts for it unless told otherwise.
## Not saved: it belongs to the campaign's career state, not to the battle.
var commander := ""
## Runtime measurement only (not saved): one entry per soldier taken out of the ranks.
var casualty_log: Array = []
var _remainder := 0.0
var _field := Field.new()
var _plans := {}


func _init(p_seed: int = DEFAULT_SEED, p_scenario: Dictionary = VALLEY_SCENARIO) -> void:
	battle_seed = p_seed
	_use_scenario(p_scenario)
	commander = str(scenario.get("player_appointment", ""))
	for company: Dictionary in scenario.companies:
		_add_squad(company.id, company.title, company.side, company.kind, company.shape, company.at, company.count)


## The campaign delegates only the local guard after actual adult service.
## The independent practice scenario supplies its own preappointed commander.
static func campaign_authority(world: Dictionary) -> String:
	var player: Dictionary = world.get("player", {})
	var progress: Dictionary = world.get("progress", {})
	if int(player.get("age", 0)) < 18 or player.get("role") != "soldier":
		return ""
	if not progress.get("training_complete", false) or not progress.get("skirmish_won", false) or progress.get("career_terminal", false):
		return ""
	return "praefectus_valley_spears" if int(world.get("squad", {}).get("alive", 0)) > 0 else ""


func muster(troop_id: String) -> Dictionary:
	if not scenario.has("contracts") or steps != 0 or _remainder != 0.0 or commander != "legatus_valdora":
		return _reply(false, "Aushebung nur vor Übungsbeginn mit erteiltem Kommando.")
	if not Muster.OFFERS.has(troop_id) or troop_id in scenario.contracts:
		return _reply(false, "Dieses Kontingent ist nicht verfügbar.")
	var plan := Muster.scenario(VALLEY_SCENARIO, scenario.contracts + [troop_id])
	if plan.is_empty():
		return _reply(false, "Die Mittel im Übungsdepot reichen nicht.")
	_use_scenario(plan)
	var company: Dictionary = _plans["muster_" + troop_id]
	_add_squad(company.id, company.title, company.side, company.kind, company.shape, company.at, company.count)
	return _reply(true, "%s: %d Erwachsene eingeteilt." % [company.title, company.count])


func _use_scenario(source: Dictionary) -> void:
	scenario = source
	year = int(scenario.year)
	_plans.clear()
	for company: Dictionary in scenario.companies:
		_plans[company.id] = company


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
	var weapon: String = {"infantry": "gladius", "spear": "spear", "archer": "bow", "skirmisher": "spear", "cavalry": "spear"}[kind]
	var loadout := {"main_hand": {"family_id": weapon, "q_min": 1, "q_max": 1}}
	if kind != "archer":
		loadout.shield = {"family_id": "shield_round", "q_min": 1, "q_max": 1}
	if kind == "skirmisher":
		loadout.missile = {"family_id": "javelin", "q_min": 1, "q_max": 1, "count": 3}
	return {"troop_id": "", "tier": 2, "culture": "", "battle_kind": kind, "loadout": loadout, "drills": {}}


## Issued kit of a company: each slot at the troop's minimum quality, unless the scenario
## names the quality of the actual items (kit_quality 0-4; the hook for shops, crafting
## and inventory: the world-state integration passes the quality of real item instances).
## The equipment tier sets every slot's quality; an explicit kit_quality (real items)
## takes precedence over the tier.
func _kit(troop: Dictionary, id: String = "", tiers: Dictionary = {}) -> Dictionary:
	var kit := {}
	var plan: Dictionary = _plans.get(id, {})
	var catalog := Catalog.load_default()
	var tier: Dictionary = catalog.tiers.equipment.get(tiers.get("equipment", ""), {}) if catalog.ok else {}
	for slot in troop.loadout:
		var item: Dictionary = troop.loadout[slot]
		var quality := int(item.q_min)
		if not tier.is_empty():
			quality = int(tier.quality)
		if plan.has("kit_quality"):
			quality = clampi(int(plan.kit_quality), 0, 4)
		kit[slot] = {"family_id": item.family_id, "quality": quality, "count": int(item.get("count", 1))}
	return kit


## Appointments that may command a company; each must exist in the scenario and be an
## appointment type of the catalog valid in the scenario year.
func _rights(id: String) -> Array:
	var rights := []
	var catalog := Catalog.load_default()
	var appointments: Dictionary = scenario.get("appointments", {})
	for appointment: String in _plans.get(id, {}).get("commandable_by", []):
		var post: Dictionary = appointments.get(appointment, {})
		var kind: Dictionary = catalog.appointments.get(post.get("type", ""), {}) if catalog.ok else {}
		if kind.is_empty() or not Catalog.valid_at(kind, year):
			push_error("Appointment %s of %s is not valid for %s." % [appointment, id, Catalog.year_label(year)])
			continue
		rights.append(appointment)
	return rights


## Sets the appointment the player holds ("" for none). Unknown appointments are refused.
func set_commander(appointment: String) -> bool:
	if appointment != "" and not scenario.get("appointments", {}).has(appointment):
		return false
	commander = appointment
	return true


## Training shifts every drill of the troop by the tier's offset (0-3).
func _drills(troop: Dictionary, tiers: Dictionary) -> Dictionary:
	var catalog := Catalog.load_default()
	var offset := int(catalog.tiers.training.get(tiers.get("training", ""), {}).get("drill_offset", 0)) if catalog.ok else 0
	var drills := {}
	for drill in troop.drills:
		drills[drill] = clampi(int(troop.drills[drill]) + offset, 0, 3)
	return drills


func _tiers_for(id: String, troop: Dictionary) -> Dictionary:
	var catalog := Catalog.load_default()
	if not catalog.ok or troop.troop_id == "":
		return {"experience": "", "equipment": "", "training": ""}
	var tiers := Catalog.company_tiers(catalog, troop.troop_id, _plans.get(id, {}))
	if tiers.is_empty():
		push_error("Company %s names an unknown tier; troop defaults apply." % id)
		tiers = Catalog.company_tiers(catalog, troop.troop_id, {})
	return tiers


func _add_squad(id: String, title: String, side: String, kind: String, shape: String, at: Vector2, count: int) -> void:
	var facing := 0.0 if side == "ally" else PI
	var troop := _troop_for(id, kind)
	var tiers := _tiers_for(id, troop)
	var s := {"id": id, "army_id": "talwache" if side == "ally" else "hoehenbund",
		"name": title, "side": side, "kind": kind, "formation": shape,
		"strength": count, "initial_strength": count, "morale": 90.0, "fatigue": 0.0,
		"x": at.x, "z": at.y, "facing": facing, "width": 0.0, "goal_x": at.x,
		"goal_z": at.y, "goal_facing": facing, "target": "", "fire": true,
		"command": "hold" if side == "ally" else "attack_move", "status": "ready",
		"damage": 0.0, "members": [], "ai_reason": "",
		"commander_id": "%s_%02d" % [id, count - 3], "deputy_id": id + "_00",
		"officer_id": "%s_%02d" % [id, count - 3],
		"equipment": {"infantry":"Schwert und Schild", "spear":"Speer und Schild", "archer":"Bogen", "skirmisher":"Wurfspeere und Schild", "cavalry":"Reitpferd, Speer und Schild"}[kind],
		"ammo": ARROWS if kind == "archer" else 0, "next_volley": 0,
		"experience": 52 if side == "ally" else 45, "discipline": 72 if side == "ally" else 62,
		"pending_formation": "", "formation_at": 0,
		"last_action": "", "action_step": -1, "hit_step": -1, "block_step": -1,
		"wounded": 0, "dead": 0, "cohesion": 100.0, "reaction_seconds": 0.4, "ready_at": 0,
		"troop_id": troop.troop_id, "loadout": _kit(troop, id, tiers), "drills": _drills(troop, tiers), "tiers": tiers,
		"uids": [], "people": {}, "memories": [],
		"signifer_id": _soldier_id(id, count - 2) if count >= 5 else "", "rally_from": 0,
		"commandable_by": _rights(id), "pila": 0, "shields_fouled_until": 0, "charge_bonus": false,
		"wear": {"weapon": 0.0, "shield": 0.0, "armor": 0.0}}
	if s.loadout.has("missile") and s.loadout.missile.family_id == "pilum":
		s.pila = s.loadout.missile.count
	if kind == "cavalry":
		s.mounted = true
	if kind == "skirmisher":
		s.ammo = s.loadout.missile.count
	var catalog := Catalog.load_default()
	var plan: Dictionary = _plans.get(id, {})
	var group: Dictionary = catalog.groups.get(plan.get("origin", ""), {}) if catalog.ok else {}
	var pool: Dictionary = catalog.name_pools.get(group.get("names", ""), {}) if catalog.ok else {}
	var entry_xp := Catalog.entry_xp(catalog, troop.troop_id) if catalog.ok else 0
	# A chosen experience tier sets skill and XP of new soldiers; the troop's own default
	# tier keeps the original generation, so earlier saves regenerate identically.
	var experience: Dictionary = {}
	if catalog.ok and _plans.get(id, {}).has("experience"):
		experience = catalog.tiers.experience.get(tiers.experience, {})
	for i in range(count):
		var uid := _soldier_id(id, i)
		var rank := "commander" if uid == s.commander_id else ("deputy" if uid == s.deputy_id else ("signifer" if uid == s.signifer_id else "miles"))
		var person := Roster.identity(battle_seed, id, i, count, troop, pool, group, entry_xp, s.discipline, year, experience, rank)
		s.people[person.uid] = person
	var order := _arrangement(shape, count, [s.commander_id, s.deputy_id, s.signifer_id], id)
	var slots := _company_slots(s, shape, 0.0, at, facing)
	for i in range(count):
		s.members.append([slots[i].x, slots[i].y])
		s.uids.append(order[i])
	squads[id] = s


## Initial places: the commander fights at the right of the front rank, the standard
## bearer stands in the middle of the second rank (behind the antesignani), the deputy
## closes the rear; everyone else keeps muster order. Losses decide who falls, not slots.
func _arrangement(shape: String, count: int, leaders: Array, id: String) -> Array:
	var order := []
	for i in range(count):
		order.append(_soldier_id(id, i))
	if count < 5:
		return order
	var ranks := Slots.ranks(shape, count, 0.0)
	var second := []
	for i in range(count):
		if ranks[i] == 1:
			second.append(i)
	var placed := {ranks.rfind(0): leaders[0], count - 1: leaders[1]}
	var standard: int = second[second.size() / 2] if not second.is_empty() else ranks.rfind(0) / 2
	if leaders[2] != "" and not placed.has(standard):
		placed[standard] = leaders[2]
	var rest := []
	for uid in order:
		if not uid in placed.values():
			rest.append(uid)
	var result := []
	for slot in range(count):
		result.append(placed[slot] if placed.has(slot) else rest.pop_front())
	return result


static func _soldier_id(company_id: String, index: int) -> String:
	return "%s_%02d" % [company_id, index]


func company_ids(formation_group_id: String, active_only: bool = true) -> Array[String]:
	var ids: Array[String] = []
	for s: Dictionary in squads.values():
		var group_id: String = s.army_id + ("_support" if s.kind in RANGED_KINDS else "_front")
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
	var ring: Array = Slots.world_slots(s.formation, s.strength, s.width, _pos(s), s.facing) if s.formation == "orbis" else []
	var file := 0
	for i in range(s.members.size()):
		var m: Array = s.members[i]
		var pose := "idle"
		if s.status == "routed" or (s.status == "rallying" and steps < s.ready_at):
			pose = "retreat"
		elif s.hit_step >= 0 and steps - s.hit_step < 2 and i % 3 == s.hit_step % 3:
			pose = "hit"
		elif s.block_step >= 0 and steps - s.block_step < 3 and i % 2 == 0:
			pose = "block"
		elif s.action_step >= 0 and steps - s.action_step < (5 if s.last_action == "shoot" else 3):
			# No dedicated throwing clip exists yet; the pila throw uses the attack pose.
			pose = "attack" if s.last_action == "throw" else s.last_action
		elif s.status == "moving":
			pose = "walk"
		var uid: String = s.uids[i]
		var facing: float = s.facing
		if not ring.is_empty():
			# In the orbis every soldier faces outwards from the centre.
			var out: Vector2 = ring[i] - _pos(s)
			facing = atan2(-out.x, -out.y)
		if i > 0 and ranks[i] != ranks[i - 1]:
			file = 0
		# slot: the soldier's place in the formation. index is the position in the layout
		# of Slots.layout() (and in uids/members), rank counts from the front (0), file
		# from the left of that rank as the company faces. "rank" repeats slot.rank.
		result.append({"id": uid, "x": m[0], "z": m[1], "facing": facing, "pose": pose, "rank": ranks[i],
			"slot": {"index": i, "rank": ranks[i], "file": file},
			"appearance_seed": s.people[uid].appearance_seed, "military_rank": s.people[uid].rank})
		file += 1
	return result


## Read-only identity record of one soldier, alive or fallen ({} if unknown).
func soldier_record(uid: String) -> Dictionary:
	for s: Dictionary in squads.values():
		if s.people.has(uid):
			return s.people[uid].duplicate(true)
	return {}


## What this battle means for the settlements (D-043): one event per soldier whose
## state changed since muster (wounded, died), or with p_muster the recruitment itself.
## Pure view of the records; see SoldierLife.settlement_events for the event format.
func settlement_events(p_muster: bool = false) -> Array:
	var before := []
	var after := []
	var pristine = get_script().new(battle_seed, scenario)
	for id in squads:
		for uid in squads[id].people:
			after.append(squads[id].people[uid])
			if not p_muster:
				before.append(pristine.squads[id].people[uid])
	return Life.settlement_events(before, after, {"year": year, "stamp": "%s-%d-%d" % [str(scenario.id), battle_seed, 0 if p_muster else steps]})


## Read-only records of everyone who ever served in a company, including the fallen.
func roster(id: String) -> Array:
	var result := []
	if squads.has(id):
		for uid in squads[id].people:
			result.append(squads[id].people[uid].duplicate(true))
	return result


## Mounted companies leave room for horse length both at rest and in a turn.
## Width is supplied in metres and remains the length drawn by the player.
func _company_slots(s: Dictionary, shape: String, width: float, center: Vector2, facing: float) -> Array[Vector2]:
	var spacing := 2.1 if s.kind == "cavalry" else 1.0
	var points := Slots.world_slots(shape, s.strength, width / spacing, center, facing)
	if spacing != 1.0:
		for i in points.size():
			points[i] = center + (points[i] - center) * spacing
	return points


func preview(id: String, start: Vector2, end: Vector2) -> Array:
	if not squads.has(id) or not start.is_finite() or not end.is_finite():
		return []
	var span := end - start
	if span.length() < 0.75 or not Field.clear_segment(start, end):
		return []
	var s: Dictionary = squads[id]
	var shape := _shape(s)
	if shape == "orbis":
		return []
	var points := _company_slots(s, shape, span.length(), (start + end) * 0.5, -span.angle())
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
	return SHAPES.has(shape) and (not EQUIPPED_FORMATIONS.has(shape) or kind in EQUIPPED_FORMATIONS[shape])


## Company-level gate: troop kind, then shield and drill from the issued kit.
func _form_problem(s: Dictionary, shape: String) -> String:
	if not can_form(s.kind, shape):
		return "Die Ausrüstung passt nicht zu dieser Formation."
	var shield: String = s.loadout.get("shield", {}).get("family_id", "")
	if shape in ["shield_wall", "testudo", "orbis"] and shield == "":
		return "Ohne Schilde ist diese Formation nicht möglich."
	if shape == "testudo" and (shield != "scutum" or int(s.drills.get("testudo", 0)) < 2):
		return "Das Schilddach verlangt Scuta und eingeübten Drill (Stufe 2)."
	if shape == "orbis" and int(s.drills.get("orbis", 0)) < 1:
		return "Der Kreis ist für diesen Verband nicht eingeübt."
	return ""


func _shape(s: Dictionary) -> String:
	return s.formation if s.pending_formation == "" else s.pending_formation


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


## Issues an order for the appointment `by` (default: the player's appointment).
## Every check runs before anything changes, so a rejected order leaves no trace.
func order(ids: Array, command: String, target: Variant = null, by: String = "") -> Dictionary:
	if outcome != "ongoing" or ids.is_empty() or not COMMANDS.has(command):
		return _reply(false, "Kein gültiger Befehl für diesen Gefechtsstand.")
	var issuer := by if by != "" else commander
	if issuer == "":
		return _reply(false, "Ohne Ernennung gibt es kein Befehlsrecht.")
	var destinations := {}
	var group_center := Vector2.ZERO
	for id in ids:
		if typeof(id) != TYPE_STRING or not squads.has(id) or destinations.has(id):
			return _reply(false, "Ungültige Verbandsauswahl.")
		var s: Dictionary = squads[id]
		if s.side != "ally" or s.strength < 1 or s.status == "withdrawn" or not issuer in s.commandable_by:
			return _reply(false, "Dieser Verband untersteht dem Befehl nicht.")
		if s.status in ["routed", "rallying"] and command != "rally":
			return _reply(false, "Der Verband flieht. Sammeln ist noch möglich.")
		if command in ["mount", "dismount"]:
			if s.kind != "cavalry" or int(s.drills.get("dismount", 0)) < 1 or bool(s.mounted) == (command == "mount"):
				return _reply(false, "Pferd, Reiter oder Ausbildung passen nicht zu dieser Bitte.")
			if s.command != "hold" or s.status != "ready" or steps < s.ready_at:
				return _reply(false, "Der Verband muss zuerst halten und zur Ruhe kommen.")
		if command == "form":
			if typeof(target) != TYPE_STRING:
				return _reply(false, "Die Ausrüstung passt nicht zu dieser Formation.")
			var problem := _form_problem(s, target)
			if problem != "":
				return _reply(false, problem)
		if command == "focus_fire" and s.kind in RANGED_KINDS and s.ammo == 0:
			return _reply(false, "Keine Salven mehr verfügbar.")
		if command in ["focus_fire", "cease_fire", "fire_at_will"] and not s.kind in RANGED_KINDS:
			return _reply(false, "Dieser Befehl benötigt einen Schützenverband.")
		if command in ["charge", "pila"] and s.kind == "archer":
			return _reply(false, "Schützenverbände führen diesen Befehl nicht aus.")
		if command == "pila" and s.pila < 1:
			return _reply(false, "Keine Pila mehr vorhanden.")
		if command in MOVING_COMMANDS and _shape(s) == "orbis":
			return _reply(false, "Aus dem Kreis kann der Verband nicht marschieren. Zuerst eine andere Formation befehlen.")
		destinations[id] = _pos(s)
		if command == "fall_back":
			var back := _pos(s) - _front(s) * FALL_BACK_DISTANCE
			if not Field.clear_segment(_pos(s), back):
				return _reply(false, "Hinter dem Verband fehlt Platz zum Zurückfallen.")
			destinations[id] = back
		group_center += _pos(s)
	group_center /= float(ids.size())
	if command == "advance" and target == null:
		var closest := INF
		for enemy: Dictionary in squads.values():
			if enemy.side == "enemy" and _active(enemy) and group_center.distance_to(_pos(enemy)) < closest:
				closest = group_center.distance_to(_pos(enemy))
				target = enemy.id
		if target == null:
			return _reply(false, "Kein gegnerischer Verband in Sicht.")
	if command in ENEMY_TARGETED:
		if typeof(target) != TYPE_STRING or not squads.has(target) or squads[target].side != "enemy" or not _active(squads[target]):
			return _reply(false, "Ein aktiver gegnerischer Verband wird benötigt.")
	if command == "follow":
		if typeof(target) != TYPE_STRING or not squads.has(target) or target in ids or squads[target].side != "ally" or not _active(squads[target]):
			return _reply(false, "Ein anderer aktiver eigener Verband wird als Führung benötigt.")
		var link: String = target
		for i in squads.size():
			var leader: Dictionary = squads[link]
			if leader.command != "follow" or leader.target == "":
				break
			link = leader.target
			if link in ids:
				return _reply(false, "Verbände können einander nicht im Kreis folgen.")
	if command == "face":
		if typeof(target) != TYPE_VECTOR2 or not target.is_finite():
			return _reply(false, "Eine Blickrichtung auf dem Gelände wird benötigt.")
		for id in ids:
			if _pos(squads[id]).distance_to(target) < 0.5:
				return _reply(false, "Die Blickrichtung liegt zu nah am Verband.")
	if command in ["move", "attack_move", "defend"]:
		if command == "defend" and target == null:
			target = group_center
		if typeof(target) != TYPE_VECTOR2 or not Field.clear_segment(target, target):
			return _reply(false, "Dieses Ziel liegt außerhalb des begehbaren Tals.")
		for id in ids:
			var dest: Vector2 = target + (_pos(squads[id]) - group_center)
			if not Field.clear_segment(dest, dest):
				return _reply(false, "Für die Gruppe fehlt Platz am Ziel.")
			if command == "defend" and _shape(squads[id]) == "orbis" and dest.distance_to(_pos(squads[id])) > 0.01:
				return _reply(false, "Aus dem Kreis kann der Verband nicht marschieren. Zuerst eine andere Formation befehlen.")
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
			if target == "orbis":
				# Forming the circle halts the company where it stands.
				s.command = "hold"
				s.target = ""
				s.charge_bonus = false
				_set_goal(s, _pos(s))
			continue
		if command == "rally" and s.status == "rallying":
			continue
		_delay(s)
		if command in ["mount", "dismount"]:
			s.mounted = command == "mount"
			continue
		if command == "cease_fire":
			s.fire = false
			continue
		if command == "fire_at_will":
			s.fire = true
			if s.command == "focus_fire":
				s.command = "hold"
				s.target = ""
				_set_goal(s, _pos(s))
			continue
		s.command = command
		s.target = ""
		s.charge_bonus = false
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
			"charge":
				s.target = target
				s.charge_bonus = true
			"pila", "advance", "follow":
				s.target = target
			"face":
				s.goal_facing = _bearing(s, target)
				_set_goal(s, _pos(s))
			"fall_back":
				s.goal_facing = s.facing
				_set_goal(s, destinations[id])
			"retreat": _set_goal(s, Vector2(s.x, 20))
			"move", "attack_move", "defend": _set_goal(s, destinations[id])
			"rally":
				# A routed company keeps running until the order arrives, then rallies
				# as a state; it only fights again once _rally_step lets it.
				if s.status == "routed":
					s.status = "rallying"
					s.rally_from = s.ready_at
				else:
					s.status = "ready"
				_set_goal(s, _pos(s))
			_: _set_goal(s, _pos(s))
	return _reply(true, "Befehl bestätigt.")


func _bearing(s: Dictionary, p: Vector2) -> float:
	var direction := _pos(s).direction_to(p)
	return atan2(-direction.x, -direction.y)


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
	return s.strength > 0 and s.status not in ["routed", "rallying", "withdrawn"]


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
	if s.status in ["withdrawn", "routed", "rallying"]:
		return
	var previous: String = s.command
	if s.morale < 35 or (s.command == "rally" and s.morale < 52):
		s.command = "rally"
		s.ai_reason = "Sammelt sich nach Verlusten"
		_set_goal(s, _pos(s))
	elif s.id == "ridge_spears" and steps < 45 and (enemy.is_empty() or _pos(s).distance_to(_pos(enemy)) > 10):
		s.command = "reserve"
		s.ai_reason = "Wartet als Reserve am Felsbanner"
	elif s.kind in RANGED_KINDS and steps < 20:
		s.command = "move"
		_set_goal(s, Vector2(6, -16))
		s.ai_reason = "Bezieht den erhöhten Hangplatz"
	elif not enemy.is_empty() and _pos(s).distance_to(_pos(enemy)) < 15:
		if s.kind in RANGED_KINDS and s.ammo > 0:
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
		if enemy.kind in RANGED_KINDS and enemy.ammo > 0 and s.kind == "infantry" and _form_problem(s, "shield_wall") == "":
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
		if s.status == "routed" or (s.status == "rallying" and steps < s.ready_at):
			var edge := Vector2(s.x, 21 if s.side == "ally" else -21)
			if _walk(s, edge, ROUT_SPEED):
				s.status = "withdrawn"
				s.rally_from = 0
		elif s.status == "rallying":
			_rally_step(s, enemy)
		else:
			_act(s, enemy, hits)
		_align_members(s)
	_apply_hits(hits)
	_evaluate()


## Apply all attacks after every squad has acted. A casualty cannot erase another
## squad's hit from the same simulation step. Panic then spreads from new routs.
func _apply_hits(hits: Dictionary) -> void:
	var routed: Array[String] = []
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
		if _take_losses(s, _choose_casualties(s, lost, hit.sources), hit.sources):
			routed.append(id)
	_spread_panic(routed)


## Removes the given soldiers and applies every morale consequence. Returns true when
## the company breaks because of it.
func _take_losses(s: Dictionary, fallen: Array, sources: Array) -> bool:
	var led_by: String = s.officer_id
	var banner: String = s.signifer_id
	for uid in fallen:
		_fall(s, uid)
	s.strength -= fallen.size()
	_count_losses(s)
	s.officer_id = _expected_officer(s)
	if s.officer_id != led_by:
		if led_by == s.commander_id:
			s.morale = maxf(0, s.morale - 4)
			_remember(s, "officer_fallen", led_by)
		if s.officer_id != "":
			Roster.note(s.people[s.officer_id], "took_command", led_by, year, steps)
	if banner != "" and not banner in s.uids:
		s.signifer_id = ""
		s.morale = maxf(0, s.morale - BANNER_SHOCK)
		_remember(s, "banner_lost", banner)
	s.morale = maxf(0, s.morale - casualty_morale(s, fallen.size(), sources))
	return _check_rout(s, "")


## Morale cost of casualties; the share of damage that came from behind weighs 1.5x.
func casualty_morale(s: Dictionary, lost: int, sources: Array) -> float:
	var total := 0.0
	var weighted := 0.0
	for source: Dictionary in sources:
		total += source.damage
		weighted += source.damage * (REAR_FACTOR if _from_rear(s, source.at) else 1.0)
	return 84.0 * lost / s.initial_strength * (weighted / total if total > 0.0 else 1.0)


func _from_rear(s: Dictionary, at: Vector2) -> bool:
	return s.formation != "orbis" and _front(s).dot(_pos(s).direction_to(at)) < -0.5


func _check_rout(s: Dictionary, cause: String) -> bool:
	if s.strength == 0:
		s.status = "destroyed"
		s.officer_id = ""
		s.rally_from = 0
		return false
	if s.morale <= ROUT_MORALE and s.status not in ["routed", "withdrawn", "destroyed"]:
		s.status = "routed"
		s.rally_from = 0
		_remember(s, "routed", cause)
		for uid in s.uids:
			Roster.shift_trust(s.people[uid], Roster.TRUST.routed)
		return true
	return false


## Every new rout shakes friendly companies within CONTAGION_RADIUS once; a company
## that breaks from it spreads the panic further in the same step.
func _spread_panic(routed: Array[String]) -> void:
	var queue := routed.duplicate()
	var i := 0
	while i < queue.size():
		var source: Dictionary = squads[queue[i]]
		i += 1
		for other: Dictionary in squads.values():
			if other.side != source.side or other.id == source.id or other.strength == 0 or other.status in ["routed", "withdrawn", "destroyed"]:
				continue
			if _pos(other).distance_to(_pos(source)) <= CONTAGION_RADIUS:
				other.morale = maxf(0, other.morale - CONTAGION_SHOCK)
				if _check_rout(other, source.id):
					queue.append(other.id)


## Comrades who know each other steady faster (0.8x at no bond, 1.2x at full bond).
func _bond_factor(s: Dictionary) -> float:
	return 0.8 + Roster.bond(s.people, s.uids) / 250.0


func _rally_step(s: Dictionary, enemy: Dictionary) -> void:
	_set_goal(s, _pos(s))
	s.fatigue = maxf(0, s.fatigue - 2 * STEP)
	if s.morale < 78.0:
		s.morale = minf(78.0, s.morale + RALLY_RATE * STEP * _bond_factor(s))
	var clear := enemy.is_empty() or _pos(s).distance_to(_pos(enemy)) > RALLY_CLEARANCE
	if s.morale >= RALLY_MORALE and steps - s.rally_from >= RALLY_STEPS and clear and s.officer_id != "":
		s.status = "ready"
		s.command = "hold"
		s.rally_from = 0
		_remember(s, "rallied", s.officer_id)


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
		var weights: Array = MELEE_BANDS if source.mode == "melee" else (PILA_BANDS if source.mode == "pila" else MISSILE_BANDS)
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
	if fate.status == "wounded":
		var helper := Roster.rescuer(battle_seed, person, s.uids, steps)
		if helper != "":
			Roster.rescue(person, s.people[helper], year, steps)
	for comrade in s.uids:
		if int(s.people[comrade].relations.get(uid, 0)) >= Roster.COMRADE_BOND:
			Roster.note(s.people[comrade], "lost_comrade", uid, year, steps)
			Roster.shift_trust(s.people[comrade], Roster.TRUST.lost_comrade)


func _act(s: Dictionary, nearest: Dictionary, hits: Dictionary) -> void:
	if steps < s.ready_at or s.pending_formation != "":
		s.status = "ready"
		return
	var dest := Vector2(s.goal_x, s.goal_z)
	var enemy := nearest
	var leader := {}
	if s.target != "":
		var designated: Dictionary = squads[s.target]
		if not _active(designated):
			s.target = ""
			s.command = "hold"
			s.charge_bonus = false
			_set_goal(s, _pos(s))
			dest = _pos(s)
		elif s.command == "follow":
			leader = designated
		else:
			enemy = designated
	var ranged: bool = s.kind in RANGED_KINDS and s.ammo > 0
	var reach: float = _range_of(s) if ranged else 3.5
	var dist := INF if enemy.is_empty() else _pos(s).distance_to(_pos(enemy))
	var contact := not enemy.is_empty() and dist <= reach and Field.clear_segment(_pos(s), _pos(enemy))
	var pursue: bool = s.command in ["attack", "flank", "focus_fire", "charge", "pila", "advance"] or (s.command == "attack_move" and dist < 7.0)
	if pursue and not enemy.is_empty():
		dest = _pos(enemy)
		if s.command == "flank" and dist > 7:
			dest = Field.project(dest + Vector2(5 if s.x > enemy.x else -5, 1))
	s.status = "ready"
	if s.command == "pila" and not enemy.is_empty() and dist <= PILA_RANGE and Field.clear_segment(_pos(s), _pos(enemy)):
		_throw_pila(s, enemy, hits)
		return
	if s.command == "advance" and not enemy.is_empty() and not contact:
		if dist <= ADVANCE_STANDOFF + 0.3:
			# Stop short and keep the enemy in front.
			s.facing = rotate_toward(s.facing, _bearing(s, _pos(enemy)), STEP * TURN_RATE)
			return
		dest = Field.project(_pos(enemy) + _pos(enemy).direction_to(_pos(s)) * ADVANCE_STANDOFF)
	var engaged: bool = contact and s.command not in ["move", "deploy", "retreat", "rally", "fall_back"] and (not ranged or s.fire)
	if engaged:
		s.status = "engaged"
		var bearing := _bearing(s, _pos(enemy))
		s.facing = rotate_toward(s.facing, bearing, STEP * TURN_RATE)
		var aligned := absf(angle_difference(s.facing, bearing)) <= 0.3
		var interval: int = _cadence(s) if ranged else STRIKE_STEPS
		var recovered: bool = s.action_step < 0 or steps - s.action_step >= interval
		if aligned and recovered and (not ranged or steps >= s.next_volley):
			s.action_step = steps
			s.last_action = ("shoot" if s.kind == "archer" else "throw") if ranged else "attack"
			if ranged:
				s.ammo -= 1
				s.next_volley = steps + interval
			if _shield_factor(s, enemy, ranged) < 1.0:
				enemy.block_step = steps
			var damage := _strike(s, enemy, "ranged" if ranged else "melee")
			if s.command == "charge" and s.charge_bonus and not ranged:
				# The charge factor counted once inside the formula; now it is an ordinary melee.
				s.charge_bonus = false
				s.command = "attack"
				_remember(s, "charge_impact", enemy.id)
			_add_hit(hits, s, enemy, damage, "missile" if ranged else "melee")
			_credit(s, ranged)
		s.fatigue = minf(100, s.fatigue + STEP)
	elif s.command in ["hold", "reserve", "rally"]:
		s.fatigue = maxf(0, s.fatigue - 2 * STEP)
		if s.command == "rally" and s.morale < 78.0:
			s.morale = minf(78.0, s.morale + RALLY_RATE * STEP * _bond_factor(s))
	elif s.command == "face":
		s.facing = rotate_toward(s.facing, s.goal_facing, STEP * TURN_RATE)
		if absf(angle_difference(s.facing, s.goal_facing)) < 0.0001:
			s.facing = s.goal_facing
			s.command = "hold"
	elif pursue and contact:
		pass
	elif s.command == "follow" and not leader.is_empty():
		var spot := _follow_spot(s, leader)
		if _pos(s).distance_to(spot) <= 0.5:
			s.facing = rotate_toward(s.facing, leader.facing, STEP * TURN_RATE)
		else:
			_walk(s, spot, 2.3 if s.formation == "column" else 1.85)
	else:
		var speed := 2.3 if s.formation == "column" else 1.85
		if s.command == "retreat":
			speed = RETREAT_SPEED
		elif s.command == "charge":
			speed = CHARGE_SPEED
		elif s.command == "fall_back":
			speed = FALL_BACK_SPEED
		if _walk(s, dest, speed, s.command == "fall_back"):
			if s.command == "deploy":
				s.facing = s.goal_facing
			if s.command == "retreat":
				s.status = "withdrawn"
			elif s.command in ["deploy", "move", "fall_back"]:
				s.command = "hold"
				_set_goal(s, _pos(s))


## One volley of pila (Caes. Gall. 1,25): consumes exactly one pilum per man, fouls the
## target's shields for PILA_FOUL_STEPS and returns the company to hold.
func _throw_pila(s: Dictionary, enemy: Dictionary, hits: Dictionary) -> void:
	var bearing := _bearing(s, _pos(enemy))
	s.facing = rotate_toward(s.facing, bearing, STEP * TURN_RATE)
	var recovered: bool = s.action_step < 0 or steps - s.action_step >= STRIKE_STEPS
	if absf(angle_difference(s.facing, bearing)) > 0.3 or not recovered:
		return
	s.pila -= 1
	s.action_step = steps
	s.last_action = "throw"
	if _shield_factor(s, enemy, true) < 1.0:
		enemy.block_step = steps
	_add_hit(hits, s, enemy, _strike(s, enemy, "pila"), "pila")
	enemy.shields_fouled_until = steps + PILA_FOUL_STEPS
	_credit(s, true)
	_remember(s, "pila_volley", enemy.id)
	s.command = "hold"
	s.target = ""
	_set_goal(s, _pos(s))


## Missile range and volley cadence from the balance file (bow, sling or thrown javelin).
func _range_of(s: Dictionary) -> float:
	return float(Formula.ranged_spec(_weapon(s, "ranged").family).get("range", 11.5))


func _cadence(s: Dictionary) -> int:
	return int(Formula.ranged_spec(_weapon(s, "ranged").family).get("cadence_steps", VOLLEY_STEPS))


func _depth(s: Dictionary) -> float:
	if s.formation == "orbis":
		return 2.0 * Slots.ring_radius(s.strength)
	var ranks := Slots.ranks(s.formation, s.strength, s.width)
	return (ranks.max() + 1 if not ranks.is_empty() else 1) * Slots.rank_depth(s.formation)


## The place behind the leading company, keeping a 2 m gap between the formations.
func _follow_spot(s: Dictionary, leader: Dictionary) -> Vector2:
	var gap := (_depth(s) + _depth(leader)) * 0.5 + 2.0
	return Field.project(_pos(leader) - _front(leader) * gap)


## Everything the combat formula needs for one strike interval of `s` against `enemy`.
## Competence and defence come from the soldiers' own skills, quality and wear from the
## issued kit; tactical state (morale, cohesion, formation, charge, height) is passed as
## is. All weighting happens in combat_formula.gd, nowhere in this file.
func strike_input(s: Dictionary, enemy: Dictionary, mode: String) -> Dictionary:
	var weapon := _weapon(s, mode)
	var to_attacker := _pos(enemy).direction_to(_pos(s))
	return {"mode": mode,
		"attackers": {"count": s.strength, "skill": _mean_skill(s, "melee" if mode == "melee" else "missile"),
			"stamina": 100.0 - float(s.fatigue), "weapon": weapon, "morale": s.morale, "cohesion": s.cohesion,
			"formation": s.formation, "kind": s.kind, "charge": mode == "melee" and s.command == "charge" and s.charge_bonus,
			"elevation": ground_height(s.x, s.z) - ground_height(enemy.x, enemy.z)},
		"defenders": {"skill": _mean_skill(enemy, "melee"), "armor": _armor(enemy), "shield": _shield(enemy),
			"formation": enemy.formation, "braced": enemy.command in ["defend", "hold"],
			"fouled": enemy.shields_fouled_until > steps, "facing_dot": _front(enemy).dot(to_attacker)}}


func _mean_skill(s: Dictionary, skill: String) -> float:
	var total := 0.0
	for uid in s.uids:
		total += float(s.people[uid].skills[skill])
	return total / maxi(1, s.uids.size())


## The weapon a company uses for this kind of strike. Bowmen in melee fall back to a
## sidearm, or fight unarmed.
func _weapon(s: Dictionary, mode: String) -> Dictionary:
	var slot := ""
	if mode == "pila":
		slot = "missile"
	elif mode == "ranged":
		slot = "missile" if s.loadout.get("missile", {}).get("family_id", "") in ["javelin"] and not s.loadout.get("main_hand", {}).get("family_id", "") in ["bow", "sling"] else "main_hand"
	else:
		for candidate in ["main_hand", "sidearm", "missile"]:
			var family: String = s.loadout.get(candidate, {}).get("family_id", "")
			if family != "" and not family in ["bow", "sling", "pilum"]:
				slot = candidate
				break
	if slot == "":
		return {"family": "fist", "quality": 2, "wear": 0.0}
	var item: Dictionary = s.loadout[slot]
	return {"family": item.family_id, "quality": item.quality, "wear": s.wear.weapon}


func _armor(s: Dictionary) -> Dictionary:
	var armor := {}
	for slot in ["head", "torso"]:
		if s.loadout.has(slot):
			armor[slot] = {"family": s.loadout[slot].family_id, "quality": s.loadout[slot].quality, "wear": s.wear.armor}
	return armor


func _shield(s: Dictionary) -> Dictionary:
	if not s.loadout.has("shield"):
		return {}
	return {"family": s.loadout.shield.family_id, "quality": s.loadout.shield.quality, "wear": s.wear.shield}


## Casualty-equivalent damage of one strike interval (combat formula, levels B/C). The
## wear it causes is booked on both kits.
func _strike(s: Dictionary, enemy: Dictionary, mode: String) -> float:
	var result := Formula.unit_strike(strike_input(s, enemy, mode))
	var blows: float = float(result.factors.get("blows", 0.0)) * float(result.factors.get("engaged", 0.0))
	s.wear.weapon = clampf(s.wear.weapon + result.wear.weapon * blows / maxi(1, s.strength), 0.0, 1.0)
	enemy.wear.shield = clampf(enemy.wear.shield + result.wear.shield * blows / maxi(1, enemy.strength), 0.0, 1.0)
	enemy.wear.armor = clampf(enemy.wear.armor + result.wear.armor * blows / maxi(1, enemy.strength), 0.0, 1.0)
	return result.casualties


## Expected casualties of one strike interval without booking wear (for comparisons).
func _attack_power(s: Dictionary, enemy: Dictionary, ranged: bool, mode: String = "") -> float:
	return Formula.unit_strike(strike_input(s, enemy, mode if mode != "" else ("ranged" if ranged else "melee"))).casualties


## Share of a blow that passes the enemy's shields from s's direction (1.0 = no cover).
func _shield_factor(s: Dictionary, enemy: Dictionary, ranged: bool) -> float:
	var b := Formula.balance()
	var defenders: Dictionary = strike_input(s, enemy, "ranged" if ranged else "melee").defenders
	return 1.0 - Formula.shield_cover(b, defenders, defenders.facing_dot, ranged) * Formula.shield_block(b, defenders)


func _walk(s: Dictionary, dest: Vector2, speed: float, keep_facing: bool = false) -> bool:
	var at := _pos(s)
	var mounted: bool = s.get("mounted", false)
	if mounted:
		# A tired horse loses its pace. The gait and the individual slot
		# correction below use the same ceiling so no rider falls behind.
		speed *= lerpf(MOUNT_SPEED_FACTOR, 1.0, float(s.fatigue) / 100.0)
	var next := _field.next_position(at, dest, speed * STEP)
	if next != at:
		var dir := at.direction_to(next)
		if not keep_facing:
			s.facing = atan2(-dir.x, -dir.y)
		s.x = next.x
		s.z = next.y
		s.fatigue = minf(100, s.fatigue + (0.48 if mounted else 0.22) * STEP)
		if s.status not in ["routed", "rallying"]:
			s.status = "moving"
	return next.distance_to(dest) < 0.02


## Members take the nearest free slot (greedy nearest-sort), so rear ranks step up into
## gaps instead of the whole line shuffling by index. Nobody moves more than MEMBER_STEP.
func _align_members(s: Dictionary) -> void:
	var slots := _company_slots(s, s.formation, s.width, _pos(s), s.facing)
	var goals: Array[Vector2] = []
	for slot in slots:
		goals.append(Field.project(slot))
	_assign_slots(s, goals)
	var deviation := 0.0
	for i in range(goals.size()):
		var at := Vector2(s.members[i][0], s.members[i][1])
		var step_limit := MEMBER_STEP * MOUNT_SPEED_FACTOR if s.get("mounted", false) else MEMBER_STEP
		var next := _field.next_position(at, goals[i], step_limit)
		s.members[i] = [next.x, next.y]
		deviation += next.distance_to(goals[i])
	s.cohesion = clampf(100.0 - 12.0 * deviation / maxi(1, slots.size()), 0, 100)
	if s.command == "charge":
		# Running at the enemy loosens the ranks.
		s.cohesion = maxf(0.0, s.cohesion - CHARGE_COHESION)


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
				if s.status in ["routed", "rallying", "withdrawn"]:
					total.routed += s.strength
		result[side] = total
	return result


func snapshot() -> Dictionary:
	return {"schema": SCHEMA, "seed": battle_seed, "scenario": str(scenario.id), "steps": steps, "capture": capture, "remainder": _remainder,
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
	s.rally_from = 0
	s.uids = []
	for i in range(int(s.strength)):
		s.uids.append(_soldier_id(original.id, i))
	s.signifer_id = original.signifer_id if original.signifer_id in s.uids else ""
	s.commandable_by = original.commandable_by.duplicate()
	s.pila = original.pila
	s.shields_fouled_until = 0
	s.charge_bonus = false
	# Older rules gated formations by kind only; the kit and drill now decide.
	if typeof(s.get("formation")) == TYPE_STRING and _form_problem(original, s.formation) != "":
		s.formation = "line"
	if typeof(s.get("pending_formation")) == TYPE_STRING and s.pending_formation != "" and _form_problem(original, s.pending_formation) != "":
		s.pending_formation = ""
		s.formation_at = 0
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


## Schema 3 had no wear and no tiers: kits start the migrated battle unworn and the
## company keeps its troop's default tiers.
func _migrate_v3(s: Dictionary, original: Dictionary) -> Variant:
	var present := 0
	for key in SCHEMA4_KEYS:
		present += int(s.has(key))
	if present == SCHEMA4_KEYS.size():
		return s
	if present > 0:
		return null
	s.wear = {"weapon": 0.0, "shield": 0.0, "armor": 0.0}
	s.tiers = original.tiers.duplicate()
	# Records up to schema 3 had no rank, trust, family or campaigns: they take the
	# values the same soldier is mustered with. Naming only some of them is invalid.
	if typeof(s.get("people")) != TYPE_DICTIONARY:
		return null
	var added := ["rank", "trust", "family", "campaigns"]
	for uid in s.people:
		var person: Variant = s.people[uid]
		if typeof(person) != TYPE_DICTIONARY or not original.people.has(uid):
			return null
		var named := 0
		for key in added:
			named += int(person.has(key))
		if named == added.size():
			continue
		if named > 0:
			return null
		for key in added:
			var value: Variant = original.people[uid][key]
			person[key] = value.duplicate(true) if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else value
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
	# Schema 3 adds the seed, schema 4 the scenario id; older saves ran the first bench.
	if save.size() != 7 + int(save.has("seed")) + int(save.has("scenario")) or (save.schema >= 3 and not save.has("seed")) or (save.schema >= 4 and not save.has("scenario")):
		return false
	var scenario_id := str(save.get("scenario", "valley_58bc"))
	var source := scenario
	if scenario_id != str(scenario.id):
		source = Muster.restore_plan(VALLEY_SCENARIO, scenario_id) if scenario.has("contracts") else SCENARIOS.get(scenario_id, {})
	if source.is_empty():
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
	var reference = get_script().new(save_seed, source)
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
		if save.schema <= 3:
			s = _migrate_v3(s, original)
			if s == null:
				return false
		if s.size() != original.size() or not s.has_all(original.keys()):
			return false
		# Nested records hold only whole numbers; compare them with the same types.
		for key in ["loadout", "drills", "people", "memories"]:
			if not Roster.integral(s[key]):
				return false
			s[key] = Roster.integers(s[key])
		for key in ["id", "army_id", "side", "name", "kind", "initial_strength", "equipment", "experience", "discipline", "commander_id", "deputy_id", "troop_id", "loadout", "drills", "commandable_by", "tiers"]:
			if s.get(key) != original[key]:
				return false
		if original.kind == "cavalry" and typeof(s.mounted) != TYPE_BOOL:
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
		if s.get("signifer_id") != (original.signifer_id if original.signifer_id in s.uids else ""):
			return false
		if not _number(s.get("rally_from"), 0, save.steps + 8, true) or (s.rally_from > 0) != (s.get("status") == "rallying"):
			return false
		if s.status == "rallying" and s.get("command") != "rally":
			return false
		if not _number(s.get("cohesion"), 0, 100) or not _number(s.get("reaction_seconds"), 0, 2) or not _number(s.get("ready_at"), 0, save.steps + 8, true):
			return false
		if not _number(s.get("ammo"), 0, original.ammo, true) or not _number(s.get("next_volley"), 0, save.steps + 9, true):
			return false
		if typeof(s.pending_formation) != TYPE_STRING or not _number(s.formation_at, 0, save.steps + 11, true):
			return false
		if (s.pending_formation == "") != (s.formation_at == 0):
			return false
		if s.pending_formation != "" and (_form_problem(original, s.pending_formation) != "" or (s.formation_at <= save.steps and s.status not in ["destroyed","withdrawn"])):
			return false
		if s.last_action not in ["","attack","shoot","throw"] or s.last_action == "shoot" and s.kind != "archer":
			return false
		if not _number(s.get("pila"), 0, original.pila, true) or not _number(s.get("shields_fouled_until"), 0, save.steps + PILA_FOUL_STEPS, true) or typeof(s.get("charge_bonus")) != TYPE_BOOL:
			return false
		if s.last_action == "throw" and (s.kind == "archer" or (s.kind == "skirmisher" and s.ammo >= original.ammo) or (s.kind != "skirmisher" and s.pila >= original.pila)):
			return false
		if s.charge_bonus and s.get("command") != "charge":
			return false
		var wear: Variant = s.get("wear")
		if typeof(wear) != TYPE_DICTIONARY or wear.size() != 3 or not wear.has_all(["weapon", "shield", "armor"]):
			return false
		for part in wear:
			if not _number(wear[part], 0.0, 1.0):
				return false
		for key in ["action_step", "hit_step", "block_step"]:
			if not _number(s[key], -1, save.steps, true) or s[key] == 0:
				return false
		if (s.action_step < 0) != (s.last_action == "") or (not s.kind in RANGED_KINDS and (s.next_volley != 0 or not s.fire)):
			return false
		if s.kind in RANGED_KINDS and ((s.ammo == original.ammo) != (s.next_volley == 0)):
			return false
		if s.kind in RANGED_KINDS and s.last_action in ["shoot", "throw"] and s.next_volley != s.action_step + _cadence(original):
			return false
		if not is_equal_approx(s.reaction_seconds / STEP, roundf(s.reaction_seconds / STEP)) or s.ready_at > save.steps + roundi(s.reaction_seconds / STEP):
			return false
		if s.reaction_seconds < 2 * STEP or s.reaction_seconds > 7 * STEP + 0.00001:
			return false
		if typeof(s.formation) != TYPE_STRING or _form_problem(original, s.formation) != "" or not COMMANDS.has(s.get("command")) or not s.get("status") in ["ready","engaged","moving","routed","rallying","withdrawn","destroyed"]:
			return false
		if typeof(s.get("fire")) != TYPE_BOOL or typeof(s.get("ai_reason")) != TYPE_STRING or typeof(s.get("target")) != TYPE_STRING:
			return false
		if s.command in MODIFIERS or (s.command == "focus_fire" and not s.kind in RANGED_KINDS) or (s.command in ["charge", "pila"] and s.kind == "archer"):
			return false
		if (s.command in ENEMY_TARGETED or s.command == "follow") and s.target == "":
			return false
		if s.target != "" and (not reference.squads.has(s.target) or s.target == id or (reference.squads[s.target].side == original.side) != (s.command == "follow")):
			return false
		if (s.command == "pila" and s.pila < 1) or (_shape(s) == "orbis" and s.command in MOVING_COMMANDS):
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
		for key in ["strength", "initial_strength", "action_step", "hit_step", "block_step", "formation_at", "ready_at", "next_volley", "ammo", "experience", "discipline", "wounded", "dead", "rally_from", "pila", "shields_fouled_until"]:
			restored[id][key] = int(s[key])
	if _result(restored, int(save.steps), int(save.capture)) != [save.outcome, save.reason]:
		return false
	squads = restored
	if source != scenario:
		_use_scenario(source)
	battle_seed = save_seed
	steps = int(save.steps)
	capture = int(save.capture)
	_remainder = float(save.remainder)
	outcome = save.outcome
	reason = save.reason
	casualty_log.clear()
	return true
