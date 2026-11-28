extends RefCounted
## Bounded memories of observed, mutually chosen NPC conversations. These are
## simulation relationships, independent of story trust, goods and quest rewards.

const VERSION := 1
const MAX_PAIRS := 96
const MAX_SHARED_SECONDS := 3600.0
const MAX_ENCOUNTERS := 64
const CONVERSATION_DISTANCE := 1.5
const CONVERSATION_HEIGHT := 1.2
const ENCOUNTER_SECONDS := 8.0
const ENCOUNTER_COOLDOWN := 30.0
const SESSION_GAP := 1.0
const FRIEND_SECONDS := 45.0
const FRIEND_ENCOUNTERS := 3


static func initial_state() -> Dictionary:
	return {"version":VERSION,"pairs":{}}


static func advance(social: Dictionary, people: Dictionary, available: Dictionary, now: float, delta: float, sight_check: Callable = Callable(), visibility_cache: Variant = null) -> void:
	if not is_finite(delta) or delta <= 0.0 or delta > 0.5 or not is_finite(now) or now < delta:
		return
	var ids: Array = people.keys()
	ids.sort()
	for id: String in ids:
		var person: Dictionary = people[id]
		var other_id := str(person.get("partner",""))
		# Visit each canonical pair once, regardless of dictionary insertion order.
		if id >= other_id or not people.has(other_id) or not available.get(id,false) or not available.get(other_id,false):
			continue
		var other: Dictionary = people[other_id]
		if person.activity != "socialize" or other.activity != "socialize" or other.partner != id or not close_conversation(person,other,sight_check,visibility_cache):
			continue
		var key := pair_key(id,other_id)
		if not social.pairs.has(key):
			if social.pairs.size() >= MAX_PAIRS:
				_evict_weakest(social.pairs)
			social.pairs[key] = {"shared_seconds":0.0,"encounters":0,"last_contact":now-delta,
				"session_seconds":0.0,"session_counted":false,"last_encounter":-1.0}
		var pair: Dictionary = social.pairs[key]
		# A second observation of the same tick grants nothing. With overlapping
		# intervals only the previously unobserved suffix may earn credit.
		# A gap never fabricates elapsed conversation time.
		var elapsed := now-float(pair.last_contact)
		if elapsed <= 0.00000001:
			continue
		var credit := minf(delta,elapsed)
		if elapsed > SESSION_GAP+0.00000001:
			pair.session_seconds = 0.0
			pair.session_counted = false
		pair.shared_seconds = minf(MAX_SHARED_SECONDS,float(pair.shared_seconds)+credit)
		pair.session_seconds = minf(MAX_SHARED_SECONDS,float(pair.session_seconds)+credit)
		pair.last_contact = now
		if not pair.session_counted and float(pair.session_seconds)+0.00000001 >= ENCOUNTER_SECONDS and (float(pair.last_encounter) < 0.0 or now-float(pair.last_encounter)+0.00000001 >= ENCOUNTER_COOLDOWN):
			pair.encounters = mini(MAX_ENCOUNTERS,int(pair.encounters)+1)
			pair.last_encounter = now
			pair.session_counted = true


static func close_conversation(person: Dictionary, other: Dictionary, sight_check: Callable = Callable(), visibility_cache: Variant = null) -> bool:
	if typeof(person.get("observed")) != TYPE_BOOL or typeof(other.get("observed")) != TYPE_BOOL or not person.observed or not other.observed:
		return false
	if not _observed_point(person.get("position")) or not _observed_point(other.get("position")):
		return false
	var here: Array = person.position
	var there: Array = other.position
	return absf(float(here[1])-float(there[1])) <= CONVERSATION_HEIGHT and Vector2(float(here[0]),float(here[2])).distance_to(Vector2(float(there[0]),float(there[2]))) <= CONVERSATION_DISTANCE and clear_sight(here,there,sight_check,visibility_cache)


static func clear_sight(first: Array, second: Array, sight_check: Callable = Callable(), visibility_cache: Variant = null) -> bool:
	# Invalid transient observations cannot become a sight result, even when
	# no physics adapter is present. Never cache or query non-finite endpoints.
	if not _observed_point(first) or not _observed_point(second):
		return false
	# Domain-only fixtures have no physics adapter. Runtime supplies a geometry
	# query; cache only this decision round, never persist a stale visibility flag.
	if not sight_check.is_valid():
		return true
	var from := Vector3(float(first[0]),float(first[1]),float(first[2]))
	var to := Vector3(float(second[0]),float(second[1]),float(second[2]))
	var cache: Dictionary = visibility_cache if typeof(visibility_cache) == TYPE_DICTIONARY else {}
	if cache.has(from) and cache[from].has(to):
		return bool(cache[from][to])
	var observation: Variant = sight_check.call(from,to)
	var visible: bool = typeof(observation) == TYPE_BOOL and observation
	if not cache.has(from):
		cache[from] = {}
	if not cache.has(to):
		cache[to] = {}
	cache[from][to] = visible
	cache[to][from] = visible
	return visible


static func pair_key(id: String, other_id: String) -> String:
	return id+":"+other_id if id < other_id else other_id+":"+id


static func relationship(social: Dictionary, id: String, other_id: String) -> Dictionary:
	var pair: Dictionary = social.get("pairs",{}).get(pair_key(id,other_id),{})
	if pair.is_empty():
		return {"status":"unknown","label":"Noch keine gemeinsame Gesprächserinnerung","shared_seconds":0.0,"encounters":0}
	var status := "familiar" if int(pair.encounters) >= 1 else "met"
	if int(pair.encounters) >= FRIEND_ENCOUNTERS and float(pair.shared_seconds) >= FRIEND_SECONDS:
		status = "friend"
	return {"status":status,"label":{"met":"Kurz begegnet","familiar":"Vertrauter Nachbar","friend":"Freundschaft gewachsen"}[status],
		"shared_seconds":float(pair.shared_seconds),"encounters":int(pair.encounters)}


static func preference(social: Dictionary, id: String, other_id: String) -> float:
	var relation := relationship(social,id,other_id)
	return 3.0 if relation.status == "friend" else 1.25 if relation.status == "familiar" else 0.0


static func validate(value: Variant, ids: Array, now: float) -> String:
	if not _keys(value,["version","pairs"]) or typeof(value.version) not in [TYPE_INT,TYPE_FLOAT] or value.version != VERSION or typeof(value.pairs) != TYPE_DICTIONARY or value.pairs.size() > MAX_PAIRS:
		return "Ungültiger sozialer Erinnerungsvertrag."
	for key: Variant in value.pairs:
		if typeof(key) != TYPE_STRING:
			return "Ungültige soziale Paar-ID."
		var partners := str(key).split(":")
		if partners.size() != 2 or partners[0] >= partners[1] or partners[0] not in ids or partners[1] not in ids:
			return "Unbekannte oder doppelte soziale Personen-ID."
		var pair: Variant = value.pairs[key]
		if not _keys(pair,["shared_seconds","encounters","last_contact","session_seconds","session_counted","last_encounter"]):
			return "Unvollständige soziale Erinnerung."
		if not _number(pair.shared_seconds,0.0,minf(MAX_SHARED_SECONDS,now+0.001)) or not _number(pair.session_seconds,0.0,float(pair.shared_seconds)) or not _number(pair.encounters,0.0,MAX_ENCOUNTERS) or float(pair.encounters) != floorf(float(pair.encounters)):
			return "Ungültige Gesprächsdauer oder Begegnungszahl."
		if float(pair.encounters)*ENCOUNTER_SECONDS > float(pair.shared_seconds)+0.00000001 or typeof(pair.session_counted) != TYPE_BOOL:
			return "Unbelegte soziale Begegnungszahl."
		if not _number(pair.last_contact,0.0,now+0.001) or not _number(pair.last_encounter,-1.0,float(pair.last_contact)):
			return "Ungültige soziale Erinnerungszeit."
		if float(pair.shared_seconds) > float(pair.last_contact)+0.001:
			return "Soziale Gesprächsdauer überschreitet die letzte beobachtete Kontaktzeit."
		if (int(pair.encounters) == 0 and float(pair.last_encounter) != -1.0) or (int(pair.encounters) > 0 and float(pair.last_encounter) < 0.0):
			return "Widersprüchliche soziale Begegnungszeit."
		if int(pair.encounters) > 0 and float(pair.last_encounter)+0.001 < ENCOUNTER_SECONDS+(int(pair.encounters)-1)*ENCOUNTER_COOLDOWN:
			return "Soziale Begegnungen unterschreiten ihre Zeit- und Wiederholungsgrenzen."
		if pair.session_counted and (int(pair.encounters) < 1 or float(pair.session_seconds)+0.00000001 < ENCOUNTER_SECONDS):
			return "Unbelegter Gesprächsabschluss."
	return ""


static func _evict_weakest(pairs: Dictionary) -> void:
	var ids: Array = pairs.keys()
	ids.sort()
	var weakest: String = ids[0]
	for key: String in ids:
		var candidate: Dictionary = pairs[key]
		var current: Dictionary = pairs[weakest]
		if int(candidate.encounters) < int(current.encounters) or (candidate.encounters == current.encounters and float(candidate.shared_seconds) < float(current.shared_seconds)) or (candidate.encounters == current.encounters and candidate.shared_seconds == current.shared_seconds and float(candidate.last_contact) < float(current.last_contact)):
			weakest = key
	pairs.erase(weakest)


static func _keys(value: Variant, keys: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _observed_point(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return false
	for component: Variant in value:
		if typeof(component) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(component)):
			return false
	return true


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum
