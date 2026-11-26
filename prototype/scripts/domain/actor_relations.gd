extends RefCounted
## Actor-generic directed relations and memories.
##
## Groups (a tribe, a village, Rome) and individual persons (a chieftain,
## Marcus, a trader) share one contract: an edge "observer>subject" holds what
## the observer feels about the subject. A->B is never B->A. Values change only
## through `apply()` with a concrete event id, or through slow `decay()` toward
## a baseline. An edge exists only when the observer knows the subject: unknown
## actors have no edge and therefore no opinion.
##
## The caller owns event semantics (what a raid or a gift means); this core
## owns bounds, memory, decay and validation so that every simulation that
## builds on it (tribes now, NPC personalities next) obeys the same rules.

const VERSION := 1
const MAX_MEMORIES := 8
const MAX_EDGES := 2048
## name: [minimum, maximum, decay fraction per tick toward baseline, baseline]
## The tick is the caller's simulation step (tribal world: one calendar week).
const DIMENSIONS := {
	"trust": [-100.0, 100.0, 0.004, 0.0],
	"fear": [0.0, 100.0, 0.02, 0.0],
	"grievance": [0.0, 100.0, 0.008, 0.0],
	"obligation": [0.0, 100.0, 0.01, 0.0],
	"respect": [-100.0, 100.0, 0.004, 0.0],
	"loyalty": [-100.0, 100.0, 0.003, 0.0],
	"envy": [0.0, 100.0, 0.01, 0.0]
}
const SNAP := 0.0001


static func new_graph() -> Dictionary:
	return {"version": VERSION, "edges": {}}


static func key(observer: String, subject: String) -> String:
	return observer + ">" + subject


static func knows(graph: Dictionary, observer: String, subject: String) -> bool:
	return graph.edges.has(key(observer, subject))


static func value(graph: Dictionary, observer: String, subject: String, dimension: String) -> float:
	var edge: Dictionary = graph.edges.get(key(observer, subject), {})
	return float(edge.get(dimension, DIMENSIONS[dimension][3]))


static func edge(graph: Dictionary, observer: String, subject: String) -> Dictionary:
	return (graph.edges.get(key(observer, subject), {}) as Dictionary).duplicate(true)


static func _blank(tick: int) -> Dictionary:
	var result := {"since": tick, "last": tick, "memories": []}
	for dimension: String in DIMENSIONS:
		result[dimension] = float(DIMENSIONS[dimension][3])
	return result


## Creates the edge without changing any feeling. The memory records how the
## observer learned of the subject (met, told by someone, saw evidence).
static func introduce(graph: Dictionary, observer: String, subject: String, event_id: String, tick: int, kind: String) -> bool:
	if observer == subject or observer.is_empty() or subject.is_empty():
		return false
	var k := key(observer, subject)
	if graph.edges.has(k):
		return false
	if graph.edges.size() >= MAX_EDGES:
		return false
	var fresh := _blank(tick)
	fresh.memories.append({"event": event_id, "tick": tick, "kind": kind, "delta": {}})
	graph.edges[k] = fresh
	return true


## The only way feelings change apart from decay. `deltas` maps dimension
## names to signed amounts. The edge is created when it does not exist yet:
## experiencing an event is a way of getting to know someone.
static func apply(graph: Dictionary, observer: String, subject: String, event_id: String, tick: int, kind: String, deltas: Dictionary) -> Dictionary:
	if observer == subject or observer.is_empty() or subject.is_empty() or event_id.is_empty():
		return {}
	var k := key(observer, subject)
	if not graph.edges.has(k):
		if graph.edges.size() >= MAX_EDGES:
			return {}
		graph.edges[k] = _blank(tick)
	var target: Dictionary = graph.edges[k]
	var applied := {}
	var names: Array = deltas.keys()
	names.sort()
	for dimension: String in names:
		if not DIMENSIONS.has(dimension):
			continue
		var bounds: Array = DIMENSIONS[dimension]
		var before := float(target[dimension])
		var after := _q(clampf(before + float(deltas[dimension]), float(bounds[0]), float(bounds[1])))
		if after != before:
			target[dimension] = after
			applied[dimension] = _q(after - before)
	target.last = tick
	target.memories.append({"event": event_id, "tick": tick, "kind": kind, "delta": applied})
	while target.memories.size() > MAX_MEMORIES:
		target.memories.pop_front()
	return applied


## Slow fading toward the baseline. Memories stay; feelings soften.
static func decay(graph: Dictionary, ticks: int = 1) -> void:
	if ticks <= 0:
		return
	var kept := {}
	for dimension: String in DIMENSIONS:
		kept[dimension] = pow(1.0 - float(DIMENSIONS[dimension][2]), ticks)
	# Every edge fades independently, so the visiting order cannot matter.
	for target: Dictionary in graph.edges.values():
		for dimension: String in DIMENSIONS:
			var baseline := float(DIMENSIONS[dimension][3])
			var current := float(target[dimension])
			if current == baseline:
				continue
			var next := _q(baseline + (current - baseline) * float(kept[dimension]))
			if absf(next - baseline) < 0.01:
				next = baseline
			target[dimension] = next


## A readable label for UI and AI shorthand. Thresholds are part of the contract.
static func stance(graph: Dictionary, observer: String, subject: String) -> String:
	if not knows(graph, observer, subject):
		return "unknown"
	var trust := value(graph, observer, subject, "trust")
	var grievance := value(graph, observer, subject, "grievance")
	var fear := value(graph, observer, subject, "fear")
	if grievance >= 45.0 or trust <= -45.0:
		return "hostile"
	if trust >= 45.0 and grievance < 20.0:
		return "close"
	if trust >= 15.0 and grievance < 30.0:
		return "friendly"
	if grievance >= 20.0 or trust <= -15.0 or fear >= 40.0:
		return "wary"
	return "neutral"


static func observers_of(graph: Dictionary, subject: String) -> Array:
	var result := []
	for k: String in graph.edges:
		var parts := k.split(">")
		if parts.size() == 2 and parts[1] == subject:
			result.append(parts[0])
	result.sort()
	return result


static func known_by(graph: Dictionary, observer: String) -> Array:
	var result := []
	for k: String in graph.edges:
		var parts := k.split(">")
		if parts.size() == 2 and parts[0] == observer:
			result.append(parts[1])
	result.sort()
	return result


static func remove_actor(graph: Dictionary, actor: String) -> void:
	for k: String in graph.edges.keys():
		var parts := k.split(">")
		if parts[0] == actor or parts[1] == actor:
			graph.edges.erase(k)


static func normalize(graph: Dictionary) -> void:
	graph.version = int(graph.version)
	for k: String in graph.edges:
		var target: Dictionary = graph.edges[k]
		target.since = int(target.since)
		target.last = int(target.last)
		for dimension: String in DIMENSIONS:
			target[dimension] = float(target[dimension])
		for memory: Dictionary in target.memories:
			memory.tick = int(memory.tick)
			for dimension: String in memory.delta:
				memory.delta[dimension] = float(memory.delta[dimension])


static func validate(graph: Variant, actor_ids: Dictionary, now_tick: int) -> String:
	if typeof(graph) != TYPE_DICTIONARY or graph.size() != 2 or not graph.has_all(["version", "edges"]):
		return "Ungültiger Beziehungsgraph."
	if not _is_int(graph.version) or int(graph.version) != VERSION or typeof(graph.edges) != TYPE_DICTIONARY or graph.edges.size() > MAX_EDGES:
		return "Unbekannte Beziehungsversion oder zu viele Beziehungen."
	var fields := DIMENSIONS.size() + 3
	for k: Variant in graph.edges:
		if typeof(k) != TYPE_STRING:
			return "Ungültiger Beziehungsschlüssel."
		var parts := str(k).split(">")
		if parts.size() != 2 or parts[0] == parts[1] or not actor_ids.has(parts[0]) or not actor_ids.has(parts[1]):
			return "Beziehung mit unbekannter Person oder Gruppe: %s" % k
		var target: Variant = graph.edges[k]
		if typeof(target) != TYPE_DICTIONARY or target.size() != fields or not target.has_all(["since", "last", "memories"]):
			return "Unvollständige Beziehung %s." % k
		if not _is_int(target.since) or not _is_int(target.last) or int(target.since) > int(target.last) or int(target.last) > now_tick:
			return "Beziehungszeit liegt in der Zukunft oder ist widersprüchlich: %s." % k
		for dimension: String in DIMENSIONS:
			var bounds: Array = DIMENSIONS[dimension]
			if not target.has(dimension) or not _is_number(target[dimension]) or float(target[dimension]) < float(bounds[0]) or float(target[dimension]) > float(bounds[1]):
				return "Beziehungswert außerhalb der Grenzen: %s.%s" % [k, dimension]
		if typeof(target.memories) != TYPE_ARRAY or target.memories.is_empty() or target.memories.size() > MAX_MEMORIES:
			return "Beziehung ohne belegende Erinnerung: %s." % k
		var previous := -1
		for memory: Variant in target.memories:
			if typeof(memory) != TYPE_DICTIONARY or memory.size() != 4 or not memory.has_all(["event", "tick", "kind", "delta"]):
				return "Ungültige Erinnerung in %s." % k
			if typeof(memory.event) != TYPE_STRING or str(memory.event).is_empty() or typeof(memory.kind) != TYPE_STRING or not _is_int(memory.tick) or int(memory.tick) < previous or int(memory.tick) > now_tick or typeof(memory.delta) != TYPE_DICTIONARY:
				return "Erinnerung ohne Ereignis oder Zeit in %s." % k
			previous = int(memory.tick)
			for dimension: Variant in memory.delta:
				if not DIMENSIONS.has(dimension) or not _is_number(memory.delta[dimension]):
					return "Unbekannte Erinnerungswirkung in %s." % k
	return ""


## Rounded to four decimals that survive Godot's JSON save/load exactly.
static func _q(x: float) -> float:
	return roundf(x * 10000.0) / 10000.0


static func _is_number(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v))


static func _is_int(v: Variant) -> bool:
	return _is_number(v) and float(v) == floorf(float(v))
