extends RefCounted
## One person-id namespace for the shared world (D-045): village residents,
## tribal persons, soldiers, the player and the companion. Every module keeps
## its own local ids and records; this registry gives each person exactly one
## global id "<namespace>:<local id>" and resolves known aliases, so ids from
## different systems never collide and one human never appears twice.
##
## Namespaces:
##   pc   the player character and the companion ("pc:player", "pc:companion")
##   vil  Valdora residents, speaking NPCs and ambient residents (npc_behavior roster)
##   frt  people of the legacy frontier chapter
##   trb  tribal persons (TribalWorld persons: chiefs, heirs, rivals, retainers)
##   sol  soldiers of the valley battle (SoldierRoster uids)
## Aliases (same human, second local id): the companion's village id
## ("vil:marcus" -> "pc:companion") and the tribal target "player" ("pc:player").
## Ages are never stored here: they derive from the world clock (world_clock.gd).

const Clock = preload("res://scripts/domain/world_clock.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const NpcBehavior = preload("res://scripts/domain/npc_behavior.gd")
const VillageLife = preload("res://scripts/story/village_life.gd")
const Frontier = preload("res://scripts/story/frontier_chapter.gd")
const WorldState = preload("res://scripts/domain/world_state.gd")
const NAMESPACES := ["pc", "vil", "frt", "trb", "sol"]
const ID_PATTERN := "^[a-z0-9_]{1,64}$"


static func global_id(space: String, local_id: String) -> String:
	return "%s:%s" % [space, local_id]


static func split(global: String) -> Array:
	var index := global.find(":")
	if index <= 0:
		return []
	return [global.substr(0, index), global.substr(index + 1)]


## Every person of the world, keyed by global id. Pure; reads the owning modules.
static func collect(world: Dictionary) -> Dictionary:
	var people := {}
	var aliases := {}
	var companion_id := str(world.get("companion", {}).get("id", ""))
	people["pc:player"] = {"name": "Spielfigur", "source": "player", "local_id": "player", "alive": int(world.get("player", {}).get("health", 1)) > 0,
		"age": Clock.age(world, "player") if world.has("calendar") else int(world.get("player", {}).get("age", -1))}
	people["pc:companion"] = {"name": companion_id.capitalize(), "source": "companion", "local_id": companion_id, "alive": true,
		"age": Clock.age(world, "companion") if world.has("calendar") else int(world.get("companion", {}).get("age", -1))}
	var village: Dictionary = world.get("village", {})
	if bool(village.get("enabled", false)):
		var roster: Dictionary = NpcBehavior.roster()
		for id: String in roster:
			_add_village(people, aliases, id, str(roster[id].name), companion_id, "village_roster")
		for id: String in VillageLife.NPCS:
			_add_village(people, aliases, id, str(VillageLife.NPCS[id].name), companion_id, "village_npc")
		for person: Dictionary in village.get("economy", {}).get("people", []):
			var gid := _add_village(people, aliases, str(person.id), str(person.name), companion_id, "village_economy")
			if people.has(gid):
				people[gid].alive = bool(person.get("alive", true))
	elif not world.get("frontier", {}).is_empty():
		for id: String in Frontier.NPCS:
			people[global_id("frt", id)] = {"name": str(Frontier.NPCS[id].get("name", id)), "source": "frontier", "local_id": id, "alive": true, "age": -1}
	var tribes: Dictionary = world.get("tribes", {})
	for pid: String in tribes.get("persons", {}):
		var person: Dictionary = tribes.persons[pid]
		people[global_id("trb", pid)] = {"name": str(person.name), "source": "tribal_person", "local_id": pid,
			"alive": str(person.status) == "alive", "group": str(person.group), "age": -1}
	if tribes.get("targets", {}).has("player"):
		aliases["trb:player"] = "pc:player"
	for record: Dictionary in WorldState.soldiers(world) if world.has("world_state") else []:
		people[global_id("sol", str(record.uid))] = {"name": str(record.name), "source": "soldier", "local_id": str(record.uid),
			"alive": str(record.status) != "dead", "status": str(record.status), "troop_id": str(record.troop_id), "age": soldier_age(world, record)}
	return {"people": people, "aliases": aliases}


static func _add_village(people: Dictionary, aliases: Dictionary, id: String, name: String, companion_id: String, source: String) -> String:
	var gid := global_id("vil", id)
	if id == companion_id and not companion_id.is_empty():
		aliases[gid] = "pc:companion"
		return "pc:companion"
	if not people.has(gid):
		people[gid] = {"name": name, "source": source, "local_id": id, "alive": true, "age": -1}
	return gid


## Soldiers keep their muster age as identity; their age on the world date
## counts from the muster date on the world clock (world_state.military), so
## no season, journey or recovery can age them twice.
static func soldier_age(world: Dictionary, record: Dictionary) -> int:
	var muster := int(world.get("world_state", {}).get("military", {}).get("battle_start_jdn", -1))
	if not world.has("calendar") or muster < 0:
		return int(record.get("age", -1))
	var muster_year := Calendar.year_of(muster)
	var birth := Calendar.add_years(muster_year, -int(record.get("age", 0)))
	return Calendar.age_in_year(birth, Clock.year(world))


## The person behind an actor of the relation graph (tribes.relations): tribal
## persons and the tribal target "player". Groups, communities and powers are
## not persons and return "".
static func relation_actor(world: Dictionary, actor: String) -> String:
	var tribes: Dictionary = world.get("tribes", {})
	if tribes.get("persons", {}).has(actor):
		return global_id("trb", actor)
	if actor == "player" and tribes.get("targets", {}).has("player"):
		return "pc:player"
	return ""


static func resolve(world: Dictionary, global: String) -> String:
	var registry := collect(world)
	var id: String = registry.aliases.get(global, global)
	return id if registry.people.has(id) else ""


static func validate(world: Dictionary) -> String:
	var registry := collect(world)
	var regex := RegEx.create_from_string(ID_PATTERN)
	for gid: String in registry.people:
		var parts := split(gid)
		if parts.size() != 2 or parts[0] not in NAMESPACES or regex.search(parts[1]) == null:
			return "Ungültige Personenkennung: %s" % gid
	for alias: String in registry.aliases:
		if registry.people.has(alias) or not registry.people.has(registry.aliases[alias]):
			return "Eine Person ist doppelt angelegt: %s" % alias
	# One human, one record: a village resident recruited into the militia stays
	# the same resident (world_model militia), never a second soldier identity.
	for id: Variant in world.get("village", {}).get("militia", []):
		if not registry.people.has(global_id("vil", str(id))):
			return "Ein Milizangehöriger ist keine Person des Dorfes."
	# Every person of the relation graph is a person of this registry.
	var tribes: Dictionary = world.get("tribes", {})
	for key: String in tribes.get("relations", {}).get("edges", {}):
		for actor: String in key.split(">"):
			var kind := str(tribes.get("targets", {}).get(actor, {}).get("kind", "person" if tribes.get("persons", {}).has(actor) else ""))
			if kind == "person" and not registry.people.has(relation_actor(world, actor)):
				return "Der Beziehungsgraph nennt eine unbekannte Person: %s" % actor
	return ""
