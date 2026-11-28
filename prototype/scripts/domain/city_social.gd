extends RefCounted
## Private relation partition for the residents of the playable Roman city.
## The city supplies resident indices and witnessed events. No method accepts
## a caller-selected actor id, tribal graph, or arbitrary change of feelings.
const Relations := preload("res://scripts/domain/actor_relations.gd")
const SHARDS := 16
const MAX_KNOWN := 10

static func resident_id(index: int) -> String:
	return "c%04d" % index

static func new_shards() -> Array:
	var shards := []
	for number in SHARDS:
		shards.append({"district": "roma", "shard": number, "edges": {}})
	return shards

## Provides the generic arithmetic core with the edges of one typed city
## partition. The mutable core view never escapes this script.
static func _graph(state: Dictionary, number: int) -> Dictionary:
	if number < 0 or number >= SHARDS or not state.get("relations") is Array or state.relations.size() != SHARDS:
		return {}
	var shard: Variant = state.relations[number]
	if not shard is Dictionary or shard.size() != 3 or shard.get("district") != "roma" or shard.get("shard") != number or not shard.get("edges") is Dictionary:
		return {}
	return {"version": Relations.VERSION, "edges": shard.edges}

static func _for_people(state: Dictionary, observer: int, subject: int) -> Dictionary:
	if not state.get("residents") is Array or observer < 0 or subject < 0 or observer == subject or maxi(observer, subject) >= state.residents.size():
		return {}
	return _graph(state, observer % SHARDS)

static func meeting(state: Dictionary, observer: int, subject: int, event: String, week: int, kind: String, trust: int) -> bool:
	var graph := _for_people(state, observer, subject)
	if graph.is_empty() or event.is_empty() or week < 0:
		return false
	var known: Array = state.residents[observer].known
	if not known.has(subject) and known.size() >= MAX_KNOWN:
		return false
	var applied := Relations.apply(graph, resident_id(observer), resident_id(subject), event, week, kind, {"trust": float(trust)})
	if applied.is_empty():
		return false
	if not known.has(subject):
		known.append(subject)
	return true

static func witnessed_theft(state: Dictionary, vendor: int, thief: int, at_second: int) -> bool:
	var graph := _for_people(state, vendor, thief)
	if graph.is_empty() or at_second < 0:
		return false
	var event := "theft:%d:%d" % [at_second, thief]
	return not Relations.apply(graph, resident_id(vendor), resident_id(thief), event, at_second / 86400 / 7, "theft", {"trust": -25.0, "grievance": 30.0}).is_empty()

static func close_week(state: Dictionary, number: int) -> bool:
	var graph := _graph(state, number)
	if graph.is_empty():
		return false
	Relations.decay(graph, 1)
	return true

static func trust(state: Dictionary, observer: int, subject: int) -> float:
	var graph := _for_people(state, observer, subject)
	return 0.0 if graph.is_empty() else Relations.value(graph, resident_id(observer), resident_id(subject), "trust")

## Leisure reads each occupied slot in order without rebuilding a graph per person.
static func company_score(state: Dictionary, observer: int, slots: Array) -> int:
	var count: int = state.residents.size()
	var graph := _graph(state, observer % SHARDS) if observer >= 0 and observer < count else {}
	var observer_id := resident_id(observer)
	var score := 0
	for subject: int in slots:
		if subject < 0:
			continue
		score += 40
		if subject == observer or subject >= count or graph.is_empty():
			continue
		var trust_value := Relations.value(graph, observer_id, resident_id(subject), "trust")
		score += int(maxf(0.0, trust_value) * 6.0)
	return score


static func knows(state: Dictionary, observer: int, subject: int) -> bool:
	var graph := _for_people(state, observer, subject)
	return not graph.is_empty() and Relations.knows(graph, resident_id(observer), resident_id(subject))

static func validate_saved(state: Dictionary, people: Dictionary, week: int) -> String:
	for number in SHARDS:
		var graph: Variant = state.relations[number] if state.version == 1 else _graph(state, number)
		var problem := Relations.validate(graph, people, week)
		if not problem.is_empty():
			return problem
		for key: String in graph.edges:
			var observer := str(key.get_slice(">", 0))
			if int(observer.substr(1)) % SHARDS != number:
				return "Eine Beziehung gehört zu einem anderen Stadtbezirk."
	return ""

## The v1 study saved bare foundation graphs by shard. Only the load path
## calls this method, after validating all people, time stamps and shard IDs.
static func restore(state: Dictionary) -> void:
	if state.version == 1:
		var old: Array = state.relations
		var shards := new_shards()
		for number in SHARDS:
			shards[number]["edges"] = old[number].edges
		state.relations = shards
		state.version = 2
	for number in SHARDS:
		Relations.normalize(_graph(state, number))
