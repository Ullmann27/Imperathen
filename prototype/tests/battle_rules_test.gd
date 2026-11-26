extends SceneTree

const Battle := preload("res://scripts/battle/battle_model.gd")
const Field := preload("res://scripts/battle/valley_field.gd")
const GUARD := "valley_guard"
const SPEARS := "valley_spears"
const BOWS := "valley_bows"
const ENEMY := "ridge_guard"

var checks := 0
var failures := 0


func _initialize() -> void:
	_test_orders()
	_test_hierarchy()
	_test_slots_and_routes()
	_test_battle_and_reentry()
	_test_defeat()
	_test_battle_factors()
	_test_objective()
	_test_contact_windows()
	_test_pending_and_validation()
	print("BATTLE_RULES_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func _test_orders() -> void:
	var m := Battle.new()
	var before := m.snapshot()
	check(m.squads.size() == 6 and m.summary().ally.initial == 30 and m.summary().enemy.initial == 30, "Army rosters")
	for pair in [[[], "hold", null], [[GUARD, ENEMY], "hold", null], [[GUARD, GUARD], "hold", null],
			[[GUARD], "form", "?"], [[GUARD],"form","phalanx"], [[BOWS],"form","testudo"],
			[[SPEARS],"form","testudo"], [[BOWS],"form","shield_wall"], [[GUARD,BOWS],"form","wedge"], [[GUARD], "attack", BOWS], [[GUARD], "flank", ""],
			[[BOWS, GUARD], "focus_fire", ENEMY], [[GUARD], "move", Vector2(INF,0)],
			[[GUARD], "move", Vector2(100,0)], [[GUARD], "move", Vector2(-12,-2)],
			[[GUARD], "deploy", {"start": Vector2.ZERO, "end": Vector2.ZERO}]]:
		check(not m.order(pair[0], pair[1], pair[2]).ok and m.snapshot() == before, "Rejected group order is atomic: " + pair[1])
	check(m.order([GUARD, SPEARS], "move", Vector2(0,10)).ok, "Move a group")
	var dx: float = m.squads[SPEARS].goal_x - m.squads[GUARD].goal_x
	check(dx == 12.0, "Group move retains lateral separation")
	for pair in [["reserve",null], ["defend",null], ["move",Vector2(0,8)], ["attack_move",Vector2(0,8)],
			["attack",ENEMY], ["flank",ENEMY], ["retreat",null], ["rally",null], ["hold",null]]:
		check(m.order([GUARD],pair[0],pair[1]).ok and m.squads[GUARD].command == pair[0], "Accept " + pair[0])
	check(m.order([BOWS], "cease_fire").ok and not m.squads[BOWS].fire, "Cease fire")
	check(m.order([BOWS], "focus_fire", ENEMY).ok and m.squads[BOWS].target == ENEMY and m.squads[BOWS].fire, "Focus fire and resume")
	check(before.squads[GUARD].command == "hold", "Snapshots are isolated from live commands")


func _test_slots_and_routes() -> void:
	var m := Battle.new()
	var layouts := {}
	for shape in Battle.FORMATIONS:
		var unit := SPEARS if shape == "phalanx" else GUARD
		check(m.order([unit], "form", shape).ok, "Equipped formation accepted: " + shape)
		var points := m.preview(unit, Vector2(-11,13), Vector2(-4,13))
		check(points.size() == m.squads[unit].strength, "Every member has a deploy slot: " + shape)
		layouts[str(points)] = true
	check(layouts.size() == 7, "Seven distinct formations even on the same drawn front")
	m.order([GUARD], "form", "line")
	var start := Vector2(-10,12)
	var end := Vector2(-4,12)
	var slots := m.preview(GUARD,start,end)
	check(m.order([GUARD], "deploy", {"start":start, "end":end}).ok, "Legal deployment")
	m.tick(4)
	var exact := true
	for i in range(slots.size()):
		var soldier: Dictionary = m.soldiers(GUARD)[i]
		exact = exact and slots[i].distance_to(Vector2(soldier.x, soldier.z)) < 0.01
	check(exact, "Confirmed positions match visual preview after motion")
	var field := Field.new()
	var p := Vector2(-18,-2)
	var destination := Vector2(-5,-2)
	var clear := true
	for i in 160:
		var next := field.next_position(p, destination, 0.22)
		clear = clear and Field.clear_segment(p, next) and p.distance_to(next) <= 0.221
		p = next
	check(clear and p == destination, "Route goes around a rock without jumps or penetration")


func _test_battle_and_reentry() -> void:
	var split := Battle.new()
	var once := Battle.new()
	split.tick(0.19)
	check(split.steps == 0, "Fractional step accumulates")
	split.tick(0.01)
	once.tick(0.2)
	check(split.squads == once.squads and split.steps == once.steps, "Frame partition gives identical state")
	once.tick(11.74)
	var before := once.snapshot()
	var reentry := Battle.new()
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(before, "", true, true))
	check(reentry.restore(decoded) and reentry.summary() == once.summary(), "JSON save round trip restores army totals")
	var invalid := before.duplicate(true)
	invalid.squads[BOWS].members = []
	check(not once.restore(invalid) and once.snapshot() == before, "Malformed roster is rejected atomically")
	once.tick(200)
	reentry.tick(200)
	check(once.outcome != "ongoing" and once.outcome == reentry.outcome and once.summary() == reentry.summary(), "Re-entry reproduces outcome and loss accounts")
	var totals := once.summary()
	for army in ["ally", "enemy"]:
		check(totals[army].initial == totals[army].strength + totals[army].losses and totals[army].losses > 0, "Persistent casualty accounting: " + army)
	var terminal := once.snapshot()
	once.tick(40)
	check(once.snapshot() == terminal and not once.order([GUARD],"rally").ok, "Terminal state is frozen")
	check(Battle.new().restore(terminal), "Terminal result can be reopened")
	print("Valley default: ", totals)


func _test_defeat() -> void:
	var m := Battle.new()
	check(m.order([GUARD,SPEARS,BOWS], "retreat").ok, "Everyone may withdraw")
	m.tick(30)
	var t := m.summary()
	check(m.outcome == "defeat" and t.ally.routed == t.ally.strength and t.ally.initial == t.ally.strength + t.ally.losses, "Withdrawn soldiers survive the loss")

func _test_battle_factors() -> void:
	var m := Battle.new()
	var guard: Dictionary = m.squads[GUARD]
	var foe: Dictionary = m.squads[ENEMY]
	var bows: Dictionary = m.squads[BOWS]
	m.order([GUARD],"move",Vector2(-6,8))
	var old_x: float = guard.x
	m.tick(Battle.STEP)
	check(guard.x == old_x and guard.reaction_seconds > 0, "Command has a response delay")
	m.tick(0.5)
	check(guard.x != old_x, "Command takes effect when ready")
	check(m.squads.ridge_spears.command == "reserve" and m.squads.ridge_bows.command == "move", "Enemy reserves and elevated archer start")
	check(m.summary().ally.losses == 0 and m.summary().enemy.losses == 0, "Distant formations deal no damage")
	var save := m.snapshot()
	save.outcome = "victory"
	check(not m.restore(save), "Outcome must match the battle state")
	var front: float = foe.facing
	foe.formation = "shield_wall"
	var from_target := Vector2(foe.x,foe.z).direction_to(Vector2(bows.x,bows.z))
	foe.facing = atan2(-from_target.x, -from_target.y)
	var protected := m._attack_power(bows, foe, true)
	foe.facing += PI
	check(protected < m._attack_power(bows, foe, true), "Oriented front guards against a volley")
	foe.facing = front
	bows.fatigue = 100
	var exhausted := m._attack_power(bows, foe, true)
	bows.fatigue = 0
	check(exhausted < m._attack_power(bows, foe, true), "Fatigue affects exchange")
	var ids := []
	for soldier in m.soldiers(GUARD):
		ids.append(soldier.id)
	m.tick(300)
	check(m.squads[BOWS].ammo < 18 and m.squads[BOWS].ammo >= 0, "Ammunition expended in finite volleys")
	for s: Dictionary in m.squads.values():
		check(s.wounded + s.dead == s.initial_strength - s.strength, "Wounded plus dead balance " + s.id)
		if s.strength > 0 and not s.uids.has(s.commander_id):
			check(s.officer_id == (s.deputy_id if s.uids.has(s.deputy_id) else ""), "Surviving deputy takes command")
	for soldier in m.soldiers(GUARD):
		check(ids.has(soldier.id), "Survivors retain identity")


func _test_objective() -> void:
	var m := Battle.new()
	# Place each side on its own edge using the same snapshot representation
	# as the campaign adapter. A quiet target isolates the capture clock.
	var save := m.snapshot()
	for s: Dictionary in save.squads.values():
		var at := Vector2(0,15) if s.id == ENEMY else Vector2(-17 + save.squads.keys().find(s.id)*5,-17)
		s.x = at.x
		s.z = at.y
		s.goal_x = at.x
		s.goal_z = at.y
		s.members.clear()
		for slot in Battle.Slots.world_slots(s.formation, s.strength, s.width, at, s.facing):
			s.members.append([slot.x,slot.y])
		if s.side == "enemy":
			s.command = "hold"
	check(m.restore(save), "Objective fixture loads")
	m.tick(7.8)
	check(m.outcome == "ongoing" and m.capture > 0, "Marker capture takes time")
	m.tick(0.2)
	check(m.outcome == "defeat" and m.reason == "Das Talzeichen ist gefallen.", "Uncontested marker lost after eight seconds")


func _positions(m, changes: Dictionary) -> void:
	var save: Dictionary = m.snapshot()
	for id in changes:
		var squad: Dictionary = save.squads[id]
		var at: Vector2 = changes[id]
		squad.x = at.x
		squad.z = at.y
		squad.goal_x = at.x
		squad.goal_z = at.y
		squad.members.clear()
		for p in Battle.Slots.world_slots(squad.formation, squad.strength, squad.width, at, squad.facing):
			squad.members.append([p.x, p.y])
	check(m.restore(save), "Contact fixture respects valid field positions")


func _has_pose(m, id: String, pose: String) -> bool:
	for soldier in m.soldiers(id):
		if soldier.pose == pose:
			return true
	return false


func _test_contact_windows() -> void:
	var m := Battle.new()
	_positions(m, {GUARD:Vector2(-7,8), ENEMY:Vector2(-7,5), BOWS:Vector2(-7,14)})
	var enemy: Dictionary = m.squads[ENEMY]
	enemy.formation = "shield_wall"
	var guard: Dictionary = m.squads[GUARD]
	guard.facing = PI
	m.tick(Battle.STEP)
	check(not _has_pose(m, GUARD, "attack") and guard.action_step == -1, "Backward-facing melee unit turns before connecting")
	check(_has_pose(m, BOWS, "shoot") and m.squads[BOWS].ammo == 17, "Shoot pose starts at an actual volley")
	check(_has_pose(m, ENEMY, "block") and _has_pose(m, ENEMY, "hit"), "Facing wall responds to incoming volley")
	for step in 4:
		m.tick(Battle.STEP)
	check(_has_pose(m, GUARD, "attack") and guard.action_step > 0, "In-range, aligned unit lands its strike")
	var first_attack: int = guard.action_step
	m.tick(0.6)
	check(guard.action_step == first_attack and not _has_pose(m, GUARD, "attack"), "Sword has a recovery window")
	check(not _has_pose(m, BOWS, "shoot") and m.squads[BOWS].ammo == 17, "No shooting through the reload")
	m.order([BOWS], "cease_fire")
	m.tick(2.0)
	check(m.squads[BOWS].ammo == 17 and not _has_pose(m, BOWS, "shoot"), "Cease fire prevents volleys and their poses")
	var far := Battle.new()
	far.tick(2)
	check(not _has_pose(far, GUARD, "attack") and not _has_pose(far, BOWS, "shoot"), "No attack poses out of range")


func _test_pending_and_validation() -> void:
	var m := Battle.new()
	m.order([GUARD],"form","testudo")
	var calm: int = m.squads[GUARD].formation_at
	_positions(m, {ENEMY:Vector2(-7,5)})
	check(m.order([GUARD],"form","line").ok, "Can issue compatible formation under pressure")
	var s: Dictionary = m.squads[GUARD]
	check(s.formation_at > calm and s.formation == "shield_wall", "Contact delays the new formation")
	var pending := m.snapshot()
	var fresh := Battle.new()
	check(fresh.restore(JSON.parse_string(JSON.stringify(pending))), "Pending reformation survives JSON")
	var deadline: int = s.formation_at
	m.tick((deadline - 1) * Battle.STEP)
	check(s.formation == "shield_wall", "No shape or defence bonus before transition")
	m.tick(Battle.STEP)
	fresh.tick(deadline * Battle.STEP)
	check(s.formation == "line" and s.pending_formation == "" and fresh.squads[GUARD].formation == "line", "Delayed formation becomes active at deadline")
	for change in [["ready_at", 90], ["reaction_seconds", 0.517], ["action_step", 0], ["block_step", 999],
			["goal_x", -12], ["pending_formation", "phalanx"], ["next_volley",1], ["last_action","shoot"]]:
		var bad := pending.duplicate(true)
		bad.squads[GUARD][change[0]] = change[1]
		if change[0] == "goal_x":
			bad.squads[GUARD].goal_z = -2
		check(not fresh.restore(bad), "Reject invalid snapshot field " + change[0])
	var legacy := Battle.new().snapshot()
	legacy.schema = 1
	for squad in legacy.squads.values():
		for key in ["pending_formation","formation_at","last_action","action_step","hit_step","block_step"]:
			squad.erase(key)
	legacy.squads[BOWS].formation = "testudo"
	check(fresh.restore(JSON.parse_string(JSON.stringify(legacy))) and fresh.squads[BOWS].formation == "line", "Retain older snapshots with equipment-compatible shape")

func _test_hierarchy() -> void:
	var m := Battle.new()
	var all_ids := {}
	var h := m.hierarchy()
	for army: Dictionary in h.values():
		_check_hierarchy_army(m,army,all_ids)
	check(all_ids.size() == 60, "Both army trees cover the original 60 distinct soldiers exactly once")
	check(m.company_ids("talwache_front") == [GUARD,SPEARS] and m.company_ids("talwache_support") == [BOWS], "Player front and support command groups")
	check(m.company_ids("hoehenbund_front") == [ENEMY,"ridge_spears"] and m.company_ids("?").is_empty(), "Enemy groups retain stable IDs")
	check(m.order(m.company_ids("talwache_front"),"defend").ok and m.squads[BOWS].command == "hold", "Group order acts on the two front companies")
	h.talwache.groups[0].companies[0].soldier_ids.clear()
	check(m.soldiers(GUARD).size() == 12, "Changing a hierarchy view never changes the roster")
	m.tick(200)
	var persisted := Battle.new()
	check(persisted.restore(JSON.parse_string(JSON.stringify(m.snapshot()))) and persisted.hierarchy() == m.hierarchy(), "Hierarchy and losses survive a normal JSON save")
	all_ids.clear()
	for army: Dictionary in persisted.hierarchy().values():
		_check_hierarchy_army(persisted,army,all_ids)
	check(persisted.company_ids("hoehenbund_front",false) == [ENEMY,"ridge_spears"], "Historical companies remain in their group after losses")
	for id in persisted.company_ids("hoehenbund_front"):
		check(persisted.squads[id].status not in ["routed","withdrawn","destroyed"], "Default group selection includes only active companies")


func _check_hierarchy_army(m, army: Dictionary, all_ids: Dictionary) -> void:
	var total := 0
	for group: Dictionary in army.groups:
		var count := 0
		for company: Dictionary in group.companies:
			var visible := []
			for soldier in m.soldiers(company.id):
				visible.append(soldier.id)
			check(company.soldier_ids == visible and company.strength == visible.size(), "View and simulation share the same live member IDs")
			for id in company.soldier_ids:
				if all_ids.has(id):
					check(false,"Duplicate member ID")
				all_ids[id] = true
			count += company.strength
		check(count == group.strength,"Group balance")
		total += count
	check(total == army.strength and total == m.summary()[army.side].strength and army.initial_strength == 30,"Army balance")
