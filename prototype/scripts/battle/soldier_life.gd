extends RefCounted
## Soldiers' lives between battles (D-043): friendships, shared campaigns, loss of
## trust, promotion in rank, leaving the army, and what all of that means for the
## settlements they come from. Pure functions over SoldierRoster records: nothing here
## keeps state, so the caller (battle model, world state) stays the only authority and
## an event can be recomputed, never booked twice by this module.
## Thresholds are balancing design values, not historical claims.

const Roster := preload("res://scripts/battle/soldier_roster.gd")

const FRIEND_BOND := 60
const CAMPAIGN_BOND := 5
const NEW_BOND := 20
const MAX_CAMPAIGNS := 12
const OUTCOME_TRUST := {"victory": 6, "draw": 0, "defeat": -6}
const LEAVE_TRUST := 20
## What a higher rank asks of a soldier. Ranks are taken one step at a time.
const RANK_NEEDS := {
	"signifer": {"xp": 300, "trust": 55, "discipline": 55},
	"deputy": {"xp": 500, "trust": 60, "discipline": 55},
	"commander": {"xp": 900, "trust": 65, "discipline": 60},
}
const EVENT_TYPES := ["recruited", "wounded", "recovered", "died", "retired", "left", "promoted"]
## Proposed effect of an event on the soldier's home settlement. The world state decides
## what it books; the keys are counts of people, never goods.
const EFFECTS := {
	"recruited": {"workers": -1, "away": 1},
	"wounded": {"wounded": 1},
	"recovered": {"wounded": -1},
	"died": {"population": -1, "away": -1, "bereaved_households": 1},
	"retired": {"workers": 1, "away": -1, "impaired": 1},
	"left": {"workers": 1, "away": -1},
	"promoted": {},
}


## Comrades this soldier counts as friends (bond >= FRIEND_BOND), sorted.
static func friends(record: Dictionary) -> Array:
	var ids := []
	for other in record.relations:
		if int(record.relations[other]) >= FRIEND_BOND:
			ids.append(other)
	ids.sort()
	return ids


## Campaigns two soldiers went through together, in the order of the first record.
static func shared_campaigns(a: Dictionary, b: Dictionary) -> Array:
	var ids := []
	for id in a.campaigns:
		if id in b.campaigns:
			ids.append(id)
	return ids


## Closes a campaign for one company. campaign = {id, year, outcome}. Everyone who
## lived through it remembers it; survivors grow closer (strangers become
## acquaintances) and trust the command more or less with the outcome. The dead and
## those already gone are returned unchanged. Returns changed copies in the same order.
static func close_campaign(records: Array, campaign: Dictionary) -> Array:
	var result := []
	var together := []
	for record: Dictionary in records:
		var r: Dictionary = record.duplicate(true)
		result.append(r)
		if r.status in ["active", "wounded"] and not campaign.id in r.campaigns:
			together.append(r)
	for r: Dictionary in together:
		if r.campaigns.size() >= MAX_CAMPAIGNS:
			r.campaigns.remove_at(0)
		r.campaigns.append(str(campaign.id))
		Roster.shift_trust(r, int(OUTCOME_TRUST.get(campaign.outcome, 0)))
		Roster.note(r, "campaign", str(campaign.id), int(campaign.year), -1)
		for other: Dictionary in together:
			if other.uid != r.uid:
				r.relations[other.uid] = mini(100, int(r.relations.get(other.uid, NEW_BOND - CAMPAIGN_BOND)) + CAMPAIGN_BOND)
	return result


## Why a soldier wants to leave ("" = he stays). Only those fit for duty decide.
static func leave_reason(record: Dictionary) -> String:
	if record.status == "active" and int(record.trust) < LEAVE_TRUST:
		return "lost_trust"
	return ""


## The soldier leaves the army and goes home. Returns a changed copy; a soldier who
## has no reason, is wounded, dead or already gone is returned unchanged.
static func leave(record: Dictionary, year: int) -> Dictionary:
	var r: Dictionary = record.duplicate(true)
	var reason := leave_reason(r)
	if reason == "":
		return r
	r.status = "left"
	Roster.note(r, "left", reason, year, -1)
	return r


## Promotion to the next rank. Returns {ok, message, record}; record is a changed copy
## on success. Needs are checked here only; the appointment itself (who may promote)
## belongs to the catalog's authorities.
static func promote(record: Dictionary, to_rank: String, year: int) -> Dictionary:
	var at: int = Roster.RANKS.find(str(record.get("rank", "")))
	if record.status != "active":
		return {"ok": false, "message": "Nur diensttaugliche Soldaten werden befördert.", "record": record}
	if not RANK_NEEDS.has(to_rank) or Roster.RANKS.find(to_rank) != at + 1:
		return {"ok": false, "message": "Befördert wird nur in den nächsten Rang.", "record": record}
	var needs: Dictionary = RANK_NEEDS[to_rank]
	if int(record.xp) < needs.xp:
		return {"ok": false, "message": "Zu wenig Erfahrung (%d/%d)." % [int(record.xp), needs.xp], "record": record}
	if int(record.skills.discipline) < needs.discipline:
		return {"ok": false, "message": "Zu wenig Disziplin (%d/%d)." % [int(record.skills.discipline), needs.discipline], "record": record}
	if int(record.trust) < needs.trust:
		return {"ok": false, "message": "Zu wenig Vertrauen in die Führung (%d/%d)." % [int(record.trust), needs.trust], "record": record}
	var r: Dictionary = record.duplicate(true)
	r.rank = to_rank
	Roster.shift_trust(r, 5)
	Roster.note(r, "promoted", to_rank, year, -1)
	return {"ok": true, "message": "Befördert zum Rang %s." % to_rank, "record": r}


static func _event(type: String, r: Dictionary, at: Dictionary, detail: String) -> Dictionary:
	var effects: Dictionary = EFFECTS[type].duplicate()
	if type == "died":
		effects.dependants_without_provider = int(r.family.dependants)
	if (type == "died" and detail == "wounded") or type == "retired":
		effects.wounded = -1
	return {
		# Stable for (soldier, change, moment): the consumer books each id once.
		"id": "%s:%s:%s" % [r.uid, type, str(at.stamp)],
		"type": type, "uid": r.uid, "name": r.name, "year": int(at.year), "stamp": str(at.stamp),
		"group_id": r.origin.group_id, "place": r.origin.place,
		"household": r.family.household, "dependants": int(r.family.dependants), "standing": r.family.standing, "craft": r.family.craft,
		"troop_id": r.troop_id, "rank": r.rank, "detail": detail, "effects": effects,
	}


## Events for the settlements from the difference of two record lists (D-043).
## before: records at the earlier moment ([] or without a uid = not yet in the army);
## after: the same soldiers now; at = {year, stamp}, stamp naming the moment (battle
## step, world day). Each state change gives exactly one event; comparing the same two
## lists again gives the same ids, so a consumer that remembers ids never books twice.
## Event: {id, type, uid, name, year, stamp, group_id, place, household, dependants,
## standing, craft, troop_id, rank, detail, effects{}}; type is one of EVENT_TYPES.
static func settlement_events(before: Array, after: Array, at: Dictionary) -> Array:
	var earlier := {}
	for r: Dictionary in before:
		earlier[r.uid] = r
	var events := []
	for r: Dictionary in after:
		if not earlier.has(r.uid):
			events.append(_event("recruited", r, at, r.troop_id))
			if r.status == "active":
				continue
		var was: String = earlier[r.uid].status if earlier.has(r.uid) else "active"
		var old_rank: String = earlier[r.uid].rank if earlier.has(r.uid) else r.rank
		if r.status != was:
			match r.status:
				"wounded":
					events.append(_event("wounded", r, at, str(r.wound.get("severity", ""))))
				"dead":
					events.append(_event("died", r, at, "wounded" if was == "wounded" else "in_battle"))
				"retired":
					events.append(_event("retired", r, at, str(r.impairments.back()) if not r.impairments.is_empty() else ""))
				"left":
					events.append(_event("left", r, at, str(r.service.back().ref)))
				"active":
					if was == "wounded":
						events.append(_event("recovered", r, at, str(r.impairments.back()) if r.impairments.size() > earlier[r.uid].impairments.size() else ""))
		if Roster.RANKS.find(r.rank) > Roster.RANKS.find(old_rank):
			events.append(_event("promoted", r, at, r.rank))
	return events
