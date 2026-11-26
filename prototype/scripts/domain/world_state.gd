extends RefCounted
## Integration ledger of the shared world state (D-045). It joins the village
## (village_life/economy), the tribal world (#99) and the military simulation
## (#100) on the one world clock (world_clock.gd) without duplicating them:
##
## - `time`: the world-time ledger (see world_clock.gd).
## - `raids`: one record per village raid that a tribal war band carried out.
##   The village ledger stays authoritative for the village goods; the tribal
##   ledger books the reported loot exactly once (TribalWorld.apply_raid_result).
## - `military`: the aftercare of the valley battle on world time. Recovery is
##   derived, never stored: a soldier's campaign state is
##   SoldierRoster.recover(battle record, days since the battle ended), so the
##   dead stay dead and no copy can contradict the battle snapshot. Only
##   promotions are stored, each with its world date.
## - relations: the actor relation graph (ActorRelations, saved as
##   `tribes.relations`) is the one relation graph of the world state. The
##   tribal simulation writes it through events only; everything outside it
##   (missions, quests, trade, the player's deeds) writes through
##   `relation_event` / `mission_dispute` below, and nowhere else (D-048).

const Clock = preload("res://scripts/domain/world_clock.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Tribes = preload("res://scripts/domain/tribal_world.gd")
const Roster = preload("res://scripts/battle/soldier_roster.gd")
const Relations = preload("res://scripts/domain/actor_relations.gd")
const Life = preload("res://scripts/battle/soldier_life.gd")
const Politics = preload("res://scripts/domain/valdora_politics.gd")
const CityCheckpoint = preload("res://scripts/domain/city_checkpoint.gd")
const VERSION := 2
const LEGACY_KEYS := ["version", "time", "raids", "military"]
const KEYS := LEGACY_KEYS + ["politics"]
const RAID_STATUS := ["committed", "booked", "no_band"]
## Balance value (central): a promoted soldier serves a season in grade first.
const MIN_DAYS_IN_GRADE := 90
const MAX_RAIDS := 64
const MAX_PROMOTIONS := 512


static func new_state() -> Dictionary:
	return {"version": VERSION, "time": {}, "raids": {}, "politics": Politics.new_state(),
		"military": {"battle_start_jdn": -1, "battle_end_jdn": -1, "promotions": []}}


static func migrate(world: Dictionary) -> void:
	var state: Variant = world.get("world_state")
	if _keys(state, LEGACY_KEYS) and _int(state.version, 1, 1):
		state.politics = Politics.new_state()
		state.version = VERSION


# --- raids: village <-> tribal ledger -------------------------------------------------

## Called after every accepted village transition. Links a played childhood
## night raid to the tribal band that carries it and books its result once.
static func bridge_raids(world: Dictionary) -> bool:
	var village: Dictionary = world.get("village", {})
	if not bool(village.get("enabled", false)) or not village.has("raid") or not world.has("tribes"):
		return false
	var raid: Dictionary = village.raid
	var number := int(raid.number)
	if number <= 0:
		return false
	var key := str(number)
	var records: Dictionary = world.world_state.raids
	var changed := false
	if not records.has(key):
		if not _tribal_raid(world):
			return false
		var tribes := Tribes.writable(world)
		var committed := Tribes.commit_story_raid(tribes, "I-10")
		records[key] = {"story": "I-10", "expedition": str(committed.get("expedition", "")), "status": "committed" if committed.ok else "no_band",
			"jdn": Clock.jdn(world), "outcome": "", "stolen": 0, "booked": {}}
		changed = true
	var record: Dictionary = records[key]
	if record.status == "committed" and int(raid.completed) >= number and str(raid.status) == "aftermath":
		var fallen := 0
		for enemy: Dictionary in raid.enemies:
			if int(enemy.health) <= 0:
				fallen += 1
		var outcome := str(raid.outcome)
		if outcome not in ["defended", "raided", "wounded", "hidden"]:
			outcome = "raided"
		if str(village.childhood.get("screenplay", {}).get("raid_path", "")) == "hide":
			outcome = "hidden"
		var loot := {"grain": int(raid.stolen)} if int(raid.stolen) > 0 else {}
		var tribes := Tribes.writable(world)
		var result := Tribes.apply_raid_result(tribes, str(record.expedition), {"outcome": outcome, "attacker_losses": fallen,
			"loot": loot, "defender_casualties": 0, "damage": 0})
		if result.ok:
			record.status = "booked"
			record.outcome = outcome
			record.stolen = int(raid.stolen)
			record.booked = (result.loot_booked as Dictionary).duplicate()
			changed = true
	return changed


static func _tribal_raid(world: Dictionary) -> bool:
	## Only the protected I-10 night (D-020) is carried by a tribal band; other
	## village raids belong to the legacy chapter without a tribal roster.
	var village: Dictionary = world.village
	if not village.has("childhood") or str(world.tribes.get("scenario", Tribes.NO_SCENARIO)) == Tribes.NO_SCENARIO:
		return false
	return str(village.childhood.get("screenplay", {}).get("i10", "")) in ["pending", "complete"] and str(world.tribes.story.get("I-10", {}).get("status", "")) == "pending"


static func expected_booking(stolen: int) -> Dictionary:
	var result := {}
	if stolen <= 0:
		return result
	for good: String in Tribes.EXTERNAL_GOODS.grain:
		var quantity := floori(stolen * float(Tribes.EXTERNAL_GOODS.grain[good]))
		if quantity > 0:
			result[good] = quantity
	return result


# --- military aftercare on world time --------------------------------------------------

## Called before the first checkpoint stores the battle: the muster date.
static func battle_started(world: Dictionary) -> void:
	if int(world.world_state.military.battle_start_jdn) < 0:
		world.world_state.military.battle_start_jdn = Clock.jdn(world)


static func battle_ended(world: Dictionary) -> void:
	## The first checkpoint with a final outcome dates the end of the battle.
	var valley: Dictionary = world.get("valley", {})
	if valley.is_empty() or str(valley.get("outcome", "ongoing")) == "ongoing":
		return
	if int(world.world_state.military.battle_end_jdn) < 0:
		world.world_state.military.battle_end_jdn = Clock.jdn(world)


static func days_since_battle(world: Dictionary, at_jdn: int = -1) -> int:
	var end := int(world.world_state.military.battle_end_jdn)
	if end < 0:
		return 0
	return maxi(0, Calendar.days_between(end, Clock.jdn(world) if at_jdn < 0 else at_jdn))


## The battle records of the saved valley snapshot (identity authority #100).
static func battle_records(world: Dictionary) -> Dictionary:
	var result := {}
	var valley: Dictionary = world.get("valley", {})
	for squad: Dictionary in valley.get("snapshot", {}).get("squads", {}).values():
		for uid: String in squad.get("people", {}):
			result[uid] = squad.people[uid]
	return result


## A soldier's campaign record on a world date: recovered on the clock, then
## the stored promotions applied in order. Pure; never stored.
static func soldier(world: Dictionary, uid: String, at_jdn: int = -1) -> Dictionary:
	var record: Dictionary = battle_records(world).get(uid, {})
	if record.is_empty():
		return {}
	return _soldier_at(world, record, Clock.jdn(world) if at_jdn < 0 else at_jdn)


static func _soldier_at(world: Dictionary, battle_record: Dictionary, day: int) -> Dictionary:
	var record := battle_record.duplicate(true)
	if int(world.world_state.military.battle_end_jdn) >= 0:
		record = Roster.recover(record, days_since_battle(world, day), Calendar.year_of(day))
	for promotion: Dictionary in world.world_state.military.promotions:
		if promotion.uid == battle_record.uid and int(promotion.jdn) <= day:
			record.troop_id = str(promotion.to)
			Roster.note(record, "promoted", str(promotion.to), int(promotion.year), -1)
	return record


static func soldiers(world: Dictionary) -> Array:
	var result := []
	var records := battle_records(world)
	if records.is_empty():
		return result
	var ids := records.keys()
	var day := Clock.jdn(world)
	ids.sort()
	for uid: String in ids:
		result.append(_soldier_at(world, records[uid], day))
	return result


# --- soldiers and their settlements (D-043) ---------------------------------------------

## Every event of the soldiers' lives up to a world date, from #100's pure
## event function: muster, wounds and deaths of the battle (dated on the
## muster and the end of the battle) and what world time did afterwards
## (recovered, retired). Derived from the battle record and the clock, never
## stored: the ids are stable, and the same world always gives the same list.
static func settlement_events(world: Dictionary, at_jdn: int = -1) -> Array:
	var military: Dictionary = world.world_state.military
	var start := int(military.battle_start_jdn)
	if start < 0:
		return []
	var day := Clock.jdn(world) if at_jdn < 0 else at_jdn
	var participants := battle_records(world)
	var ids := participants.keys()
	ids.sort()
	var records: Array = []
	for uid: String in ids:
		records.append(participants[uid])
	var blank := []
	for record: Dictionary in records:
		var fresh: Dictionary = record.duplicate(true)
		fresh.status = "active"
		blank.append(fresh)
	# Muster: everyone joins; then the battle changes some of them.
	var events := Life.settlement_events([], blank, {"year": Calendar.year_of(start), "stamp": "muster-%d" % start})
	var end := int(military.battle_end_jdn)
	if end < 0 or day < end:
		return events
	events.append_array(Life.settlement_events(blank, records, {"year": Calendar.year_of(end), "stamp": "battle-%d" % end}))
	var today := []
	for record: Dictionary in records:
		today.append(_soldier_at(world, record, day))
	for event: Dictionary in Life.settlement_events(records, today, {"year": Calendar.year_of(day), "stamp": "aftercare-%d" % end}):
		if event.type != "promoted":
			events.append(event)
	return events


## What those events mean for each home settlement: counts of people per
## place ("group_id/place"), summed from the events' proposed effects.
static func settlement_effects(world: Dictionary, at_jdn: int = -1) -> Dictionary:
	var places := {}
	for event: Dictionary in settlement_events(world, at_jdn):
		var key := "%s/%s" % [str(event.group_id), str(event.place)]
		if not places.has(key):
			places[key] = {"group_id": str(event.group_id), "place": str(event.place), "events": 0, "totals": {}}
		var entry: Dictionary = places[key]
		entry.events = int(entry.events) + 1
		for effect: String in event.effects:
			entry.totals[effect] = int(entry.totals.get(effect, 0)) + int(event.effects[effect])
	return places


## One line per settlement for the chronicle and the panels.
static func settlement_report(world: Dictionary, at_jdn: int = -1) -> Array:
	var lines := []
	var places := settlement_effects(world, at_jdn)
	var keys := places.keys()
	keys.sort()
	for key: String in keys:
		var totals: Dictionary = places[key].totals
		var parts := ["%d im Dienst" % int(totals.get("away", 0))]
		if int(totals.get("wounded", 0)) > 0:
			parts.append("%d verwundet" % int(totals.wounded))
		if int(totals.get("population", 0)) < 0:
			parts.append("%d gefallen" % -int(totals.population))
		if int(totals.get("impaired", 0)) > 0:
			parts.append("%d versehrt heimgekehrt" % int(totals.impaired))
		if int(totals.get("dependants_without_provider", 0)) > 0:
			parts.append("%d Angehörige ohne Versorger" % int(totals.dependants_without_provider))
		lines.append("%s: %s" % [str(places[key].place), ", ".join(parts)])
	return lines


## Gate on world time: active (recovered, not dead or retired) after the
## battle and at least MIN_DAYS_IN_GRADE since the last promotion.
static func promotion_reason(world: Dictionary, uid: String) -> String:
	var end := int(world.world_state.military.battle_end_jdn)
	if end < 0:
		return "Beförderungen folgen erst nach dem abgeschlossenen Gefecht."
	var record := soldier(world, uid)
	if record.is_empty():
		return "Diesen Soldaten gibt es in dieser Welt nicht."
	if str(record.status) != "active":
		return {"wounded": "Erst die Genesung, dann die Beförderung (noch %d Tage)." % int(record.get("wound", {}).get("recovery_days", 0)), "dead": "Gefallene werden nicht befördert.", "retired": "Ausgeschiedene werden nicht befördert."}.get(str(record.status), "Nicht verfügbar.")
	var last := -1
	for promotion: Dictionary in world.world_state.military.promotions:
		if promotion.uid == uid:
			last = maxi(last, int(promotion.jdn))
	if last >= 0:
		var waited := Calendar.days_between(last, Clock.jdn(world))
		if waited < MIN_DAYS_IN_GRADE:
			return "Noch %d Tage Dienst in der jetzigen Stufe." % (MIN_DAYS_IN_GRADE - waited)
	return ""


static func record_promotion(world: Dictionary, uid: String, from_id: String, to_id: String) -> void:
	world.world_state.military.promotions.append({"uid": uid, "from": from_id, "to": to_id, "jdn": Clock.jdn(world), "year": Clock.year(world)})


# --- relations: the one write path outside the tribal simulation (D-048) -----------------

## A deed of a person towards a tribal group changes what that group feels.
## `actor` is a global person id (PersonRegistry); today only the player has
## deeds the tribes can witness. Returns the tribal event that carries it.
static func relation_event(world: Dictionary, actor: String, group_id: String, kind: String, note: String) -> Dictionary:
	if actor != "pc:player":
		return {"ok": false, "message": "Nur Taten der Spielfigur erreichen bisher die Stämme."}
	if typeof(world.get("tribes")) != TYPE_DICTIONARY or str(world.tribes.get("scenario", Tribes.NO_SCENARIO)) == Tribes.NO_SCENARIO:
		return {"ok": false, "message": "Diese Welt führt keine Stammeslage."}
	if not world.tribes.groups.has(group_id) or not Tribes.PLAYER_EFFECTS.has(kind):
		return {"ok": false, "message": "Unbekannte Gruppe oder Handlung."}
	return Tribes.record_player_action(Tribes.writable(world), group_id, kind, note.left(160))


## A mission or quest records the dispute it created (D-048: no conflict
## without a recorded cause). `source` names the mission, e.g. "mission:I-14".
static func mission_dispute(world: Dictionary, a: String, b: String, source: String, note: String, weeks: int) -> Dictionary:
	if typeof(world.get("tribes")) != TYPE_DICTIONARY or str(world.tribes.get("scenario", Tribes.NO_SCENARIO)) == Tribes.NO_SCENARIO:
		return {"ok": false, "message": "Diese Welt führt keine Stammeslage."}
	if not source.begins_with("mission:") and not source.begins_with("quest:"):
		return {"ok": false, "message": "Ein Streit braucht eine Mission oder Quest als Quelle."}
	var ids := Tribes.actor_ids(world.tribes)
	if not ids.has(a) or not ids.has(b) or a == b:
		return {"ok": false, "message": "Unbekannte Streitparteien."}
	var record := Tribes.open_dispute(Tribes.writable(world), a, b, "quest_dispute", source, note.left(160), weeks)
	return {"ok": not record.is_empty(), "message": "Streit vermerkt." if not record.is_empty() else "Der Streit wurde nicht vermerkt.", "dispute": str(record.get("id", ""))}


# --- validation -------------------------------------------------------------------------

static func validate(world: Dictionary) -> String:
	var state: Variant = world.get("world_state")
	var has_city: bool = state is Dictionary and state.has("city")
	if has_city and not CityCheckpoint.valid_header(state.city):
		return "Der Stadtstand ist beschädigt."
	if not _keys(state, KEYS + ["city"] if has_city else KEYS) or not _int(state.version, VERSION, VERSION) or typeof(state.raids) != TYPE_DICTIONARY or state.raids.size() > MAX_RAIDS:
		return "Der gemeinsame Weltzustand fehlt oder ist ungültig."
	var clock_error := Clock.validate(world)
	if not clock_error.is_empty():
		return clock_error
	var political_error := Politics.validate(world)
	if not political_error.is_empty():
		return political_error
	var raid: Dictionary = world.get("village", {}).get("raid", {"number": 0})
	for key: Variant in state.raids:
		var record: Variant = state.raids[key]
		if typeof(key) != TYPE_STRING or not str(key).is_valid_int() or int(key) < 1 or int(key) > int(raid.get("number", 0)):
			return "Ein Überfallbeleg gehört zu keinem Überfall des Dorfes."
		if not _keys(record, ["story", "expedition", "status", "jdn", "outcome", "stolen", "booked"]) or record.status not in RAID_STATUS or not _int(record.jdn, 0, Clock.jdn(world)) or not _int(record.stolen, 0, 1000000) or typeof(record.booked) != TYPE_DICTIONARY:
			return "Ungültiger Überfallbeleg."
		if record.status == "booked":
			if JSON.stringify(_ints(record.booked)) != JSON.stringify(expected_booking(int(record.stolen))):
				return "Die Beute wurde im Stammesledger nicht genau einmal gebucht."
			for e: Dictionary in world.tribes.get("expeditions", []):
				if str(e.id) == str(record.expedition) and str(e.status) == "arrived":
					return "Ein abgerechneter Überfall wartet noch im Stammesledger."
		elif not record.booked.is_empty() or int(record.stolen) != 0:
			return "Ein offener Überfall trägt bereits eine Buchung."
	var military: Variant = state.military
	if not _keys(military, ["battle_start_jdn", "battle_end_jdn", "promotions"]) or not _int(military.battle_start_jdn, -1, Clock.jdn(world)) or not _int(military.battle_end_jdn, -1, Clock.jdn(world)) or typeof(military.promotions) != TYPE_ARRAY or military.promotions.size() > MAX_PROMOTIONS:
		return "Ungültige Nachsorge des Gefechts."
	var valley: Dictionary = world.get("valley", {})
	var ended := not valley.is_empty() and str(valley.get("outcome", "ongoing")) != "ongoing"
	if ended != (int(military.battle_end_jdn) >= 0) or valley.is_empty() != (int(military.battle_start_jdn) < 0):
		return "Gefecht und Weltzeit widersprechen sich."
	if ended and int(military.battle_end_jdn) < int(military.battle_start_jdn):
		return "Das Gefecht endet vor seinem Beginn."
	# The tribal world counts no days of its own: its weeks follow the clock.
	if typeof(world.get("tribes")) == TYPE_DICTIONARY and int(world.tribes.get("extra_days", 0)) != 0:
		return "Die Stammeswelt führt eine eigene Tageszählung neben der Weltzeit."
	var records := battle_records(world)
	var grade := {}
	var last_jdn := {}
	for promotion: Variant in military.promotions:
		if not _keys(promotion, ["uid", "from", "to", "jdn", "year"]) or typeof(promotion.uid) != TYPE_STRING or not records.has(promotion.uid) or not _int(promotion.jdn, int(military.battle_end_jdn), Clock.jdn(world)):
			return "Eine Beförderung gehört zu keinem Soldaten dieses Gefechts."
		if int(promotion.year) != Calendar.year_of(int(promotion.jdn)):
			return "Beförderungsjahr und Weltzeit widersprechen sich."
		var uid: String = promotion.uid
		var recovered := Roster.recover((records[uid] as Dictionary).duplicate(true), Calendar.days_between(int(military.battle_end_jdn), int(promotion.jdn)), int(promotion.year))
		if str(recovered.status) != "active":
			return "Ein verwundeter, gefallener oder ausgeschiedener Soldat wurde befördert."
		if str(promotion.from) != str(grade.get(uid, records[uid].troop_id)):
			return "Die Beförderung beginnt nicht bei der tatsächlichen Stufe."
		if last_jdn.has(uid) and Calendar.days_between(int(last_jdn[uid]), int(promotion.jdn)) < MIN_DAYS_IN_GRADE:
			return "Beförderung ohne Dienstzeit in der vorigen Stufe."
		grade[uid] = str(promotion.to)
		last_jdn[uid] = int(promotion.jdn)
	return ""


static func normalize(world: Dictionary) -> void:
	var state: Dictionary = world.world_state
	state.version = int(state.version)
	Clock.normalize(world)
	Politics.normalize(world)
	for record: Dictionary in state.raids.values():
		record.jdn = int(record.jdn)
		record.stolen = int(record.stolen)
		record.booked = _ints(record.booked)
	state.military.battle_start_jdn = int(state.military.battle_start_jdn)
	state.military.battle_end_jdn = int(state.military.battle_end_jdn)
	for promotion: Dictionary in state.military.promotions:
		promotion.jdn = int(promotion.jdn)
		promotion.year = int(promotion.year)


static func _ints(value: Dictionary) -> Dictionary:
	var result := {}
	var keys := value.keys()
	keys.sort()
	for key: Variant in keys:
		result[key] = int(value[key])
	return result


static func _keys(value: Variant, keys: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _int(value: Variant, low: int, high: int) -> bool:
	return Calendar.is_integral(value) and int(value) >= low and int(value) <= high
