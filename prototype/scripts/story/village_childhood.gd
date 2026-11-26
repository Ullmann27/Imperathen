extends RefCounted
## Authored childhood chapters. Only explicit, nearby actions advance their order.
## This optional state is created for fresh games; loading a legacy save never adds it.

const Bible = preload("res://scripts/story/campaign_bible.gd")
const Abilities = preload("res://scripts/story/chapter_abilities.gd")
const MissionData = preload("res://scripts/story/mission_data.gd")
const CompanionStory = preload("res://scripts/story/companion_story.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const I03 = preload("res://scripts/story/i03_shortcut.gd")
const I04 = preload("res://scripts/story/i04_workshop.gd")
const VERSION := 2
const LEGACY_RELATION_IDS := {"antonia":"julia", "sextus":"silvanus", "quintus":"sextus"}
const NPC_RANGE := 3.2
const POINT_RANGE := 1.6
const MAX_RESOURCE := 1000000
const COMMAND_FIELDS := {"village_childhood_action":["action_id"], "village_childhood_begin_raid":[]}
const WORKPLACE_POSITIONS := {"farm":Vector2(24.0,-30.0),"woodcamp":Vector2(-43.0,14.0),"quarry":Vector2(48.0,-12.0),"trade":Vector2(25.0,24.0),"watchpost":Vector2(0.0,-48.0),"defense":Vector2(0.0,-16.0)}
const POINTS := {
	"mother":Vector2(-15.3,14.8), "father":Vector2(-16.2,16.7),
	"family_entrance":Vector2(-13.0,14.7), "family_rest":Vector2(-12.05,10.55),
	"family_water":Vector2(-12.0,11.7), "smith":Vector2(32.8,-25.0),
	"bellows":Vector2(32.7,-28.4), "anvil":Vector2(32.8,-26.2), "quench":Vector2(32.7,-23.8),
	"wood_bundle":Vector2(-43.0,17.0), "patrol_inner":Vector2(0.0,-16.0),
	"patrol_road":Vector2(0.0,-35.0), "patrol_gate":Vector2(0.0,-46.0),
	"sick_guard":Vector2(10.0,18.5), "marcus":Vector2(-3.0,4.0),
	"hoof_tracks":Vector2(0.0,-35.0), "oath_ridge":Vector2(-16.0,-19.0),
	"home_shelf":Vector2(-15.32,12.05), "home_table":Vector2(-14.1,10.39), "well":Vector2(-7.0,6.0)
}
const EXTRA_NPCS := {
	"julia":{"name":"Julia", "role":"Deine Mutter", "point":"mother", "profession":""},
	"silvanus":{"name":"Silvanus", "role":"Dein Vater", "point":"father", "profession":""},
	"sextus":{"name":"Sextus", "role":"Dorfschmied · Freund deines Vaters", "point":"smith", "profession":"smith"}
}
const NEIGHBORS := {
	"decimus":{"name":"Decimus", "role":"Dorfverwalter", "position":Vector2(2.0,9.0), "text":"Deine Eltern wohnen schon lange hier. Schau dir das Dorf an und halte die Zusagen, die du den Nachbarn gibst. Die Amtsgeschäfte erledigen wir Erwachsenen."},
	"aelia":{"name":"Aelia", "role":"Steinmetzin", "position":Vector2(20.0,17.0), "text":"Die Mauer steht, weil ihre Steine zusammenarbeiten. Bevor man etwas umbaut, muss man verstehen, was es trägt."},
	"varro":{"name":"Varro", "role":"Späher und Jäger", "position":Vector2(-10.0,-13.0), "text":"Auf einem bekannten Weg entdeckt man jeden Tag etwas anderes. Frag nach, bevor du allein den Waldweg nimmst."},
	"fabius":{"name":"Fabius", "role":"Holzfäller", "position":Vector2(-12.0,3.0), "text":"Am Lager kannst du das bereitgelegte Kleinholz holen. An die gefällten Stämme und die Axt gehst du nur mit einem Erwachsenen."},
	"aurelia":{"name":"Aurelia", "role":"Heilerin", "position":Vector2(8.0,18.0), "text":"Im Dorf kümmern wir uns umeinander. Eine Nachricht rechtzeitig zu bringen hilft oft mehr als ein großer Auftritt."},
	"cassia":{"name":"Cassia", "role":"Händlerin", "position":Vector2(5.0,0.0), "text":"Auf meinem Tisch liegen Waren, die andere brauchen. Höre erst zu, prüfe die Menge und nenne dann den Preis."},
	"severus":{"name":"Wachmann", "role":"Dorfwache", "position":Vector2(-1.2,-45.9), "text":"Eine Runde mit der Wache ist kein Feldzug. Wir sehen nach Wegen und Toren, helfen den Leuten und melden, was wir tatsächlich beobachtet haben."}
}
# Authored steps live in res://assets/story/missions/band1/ (one file per mission).
static var STEPS: Array = MissionData.steps("band1")
## Separater Datenkatalog; die Save-relevante STEPS-Reihenfolge bleibt erhalten.
static var BRIDGE_STEPS: Dictionary = MissionData.bridge_steps("band1")
## Screenplay bridge state version. v3 adds I-07 water (story core „Wasser,
## Nachricht und kurze Kontrollrunde“); v4 adds the playable I-01 morning
## (cups, well, meal, table talk, event ledger); v5 adds the playable I-03
## errand with Marcus (route, stance, resolution, farewell, event ledger).
## v6 adds the I-04 workshop visit (work, talk at the anvil, event ledger).
## Older saves migrate on load.
const SCREENPLAY_VERSION := 6
static var CARRIED_EFFECTS: Dictionary = MissionData.carried_effects("band1")
const ITEM_NAMES := {"household_coin":"Reservierter Haushaltsdenar", "neighbor_basket":"Julias Nachbarschaftskorb", "memory_token":"Erinnerungsstück aus Valdora", "water_jug":"Gefüllter Familienkrug", "family_parcel":"Cassias Familienbestellung", "kindling_bundle":"Kleinholzbündel für Sextus", "stall_water":"Wasserkrug für Cassias Stand", "sextus_note":"Sextus’ Wachstäfelchen für Fabius", "checked_hinge":"Geprüfter Truhengriff", "medicine_parcel":"Aurelias Versorgungspäckchen", "gate_message":"Durchlassnachricht vom Tor"}
const WORKPLACE_CAPACITY := {"farm":2,"woodcamp":2,"quarry":4,"trade":2,"watchpost":2}
static var SOURCE_MISSION_BY_STEP: Dictionary = MissionData.source_missions("band1")


static func start(data: Dictionary) -> bool:
	if data.get("origin_id", "") != "italia" or not data.get("village", {}).get("enabled", false) or data.village.has("childhood") or int(data.player.age) != 12:
		return false
	var relationships := {}
	for id: String in EXTRA_NPCS:
		var parent := id in ["julia", "silvanus"]
		relationships[id] = {"met":parent,"trust":4 if parent else 0,"helped":false,"declined":false,"learned":false,"ally":false}
		var person := _person(data, id)
		if not person.is_empty():
			person.profession = EXTRA_NPCS[id].role
			person.assignment = "idle"
			person.previous_assignment = "idle"
	# The production screenplay begins in 58 BCE. Legacy village careers keep
	# their older Trajan-era history; only an explicitly enabled childhood
	# campaign moves this shared village history anchor.
	data.village.history.start_year = -58
	data.village.history.mode = "historical_baseline"
	data.village.childhood = {"version":VERSION,"completed":[],"day":1,"carried":[],
		"relationships":relationships,"active_work":"","work_seconds":0.0,
		"gear":"none","apprenticeship":"none","night_event":"none",
		"screenplay":{"version":SCREENPLAY_VERSION,"i02":"pending","i02_outcome":"","i03":"locked","i03_outcome":"","i07_water":"locked","i08":"locked","hoof_evidence":false,"i10":"locked","raid_path":"","visible_raiders":30,"i11":"locked","i12":"locked","i13":"locked","i14":"locked","julia_outcome":"undecided","oath":false},
		"guard_absence":{"active":false,"previous_assignment":"idle","previous_health":100}}
	data.village.childhood.screenplay.merge(I01.fresh_state())
	data.village.childhood.screenplay.merge(I03.fresh_state())
	data.village.childhood.screenplay.merge(I04.fresh_state())
	return true


static func enabled(data: Dictionary) -> bool:
	return typeof(data.get("village")) == TYPE_DICTIONARY and data.village.has("childhood")


static func migrate_legacy_ids(data: Dictionary) -> bool:
	# The first playable childhood build used Antonia/Sextus/Quintus for
	# mother/father/smith. The production screenplay fixes those roles as
	# Julia/Silvanus/Sextus. Preserve completed steps, trust and inventory while
	# moving only the actor identity keys.
	if not enabled(data):
		return false
	var child: Variant = data.village.childhood
	if typeof(child) != TYPE_DICTIONARY or int(child.get("version", 0)) != 1:
		return false
	var old_relationships: Variant = child.get("relationships", {})
	if typeof(old_relationships) != TYPE_DICTIONARY:
		return false
	for legacy_id: String in LEGACY_RELATION_IDS:
		if not old_relationships.has(legacy_id) or typeof(old_relationships[legacy_id]) != TYPE_DICTIONARY:
			return false
	var relationships := {}
	for legacy_id: String in LEGACY_RELATION_IDS:
		var canonical_id: String = LEGACY_RELATION_IDS[legacy_id]
		var legacy_relation: Dictionary = old_relationships[legacy_id]
		relationships[canonical_id] = legacy_relation.duplicate(true)
	child.relationships = relationships
	child.version = VERSION
	# Version-one childhood saves were produced before the four-volume campaign
	# was made authoritative and therefore carried the generic Trajan-era marker.
	# The existence of childhood itself proves this is the Valdora campaign path.
	data.village.history.start_year = -58
	data.village.history.mode = "historical_baseline"
	var old_completed: Array = child.get("completed", [])
	var passed_family_morning := old_completed.size() >= 3
	var passed_watch_service := old_completed.has("return_gear") or old_completed.has("family_evening") or old_completed.has("night_rest")
	var legacy_night: String = str(child.get("night_event", "none"))
	var legacy_released := legacy_night == "released"
	var legacy_raid: Dictionary = data.village.get("raid", {})
	var legacy_raid_finished := legacy_released and str(legacy_raid.get("status", "")) == "aftermath"
	child.screenplay = {
		"version":2,
		"i02":"complete" if passed_family_morning else "pending",
		"i02_outcome":"legacy" if passed_family_morning else "",
		"i03":"complete" if passed_family_morning or bool(data.get("companion", {}).get("met", false)) else "locked",
		"i03_outcome":"legacy" if passed_family_morning or bool(data.get("companion", {}).get("met", false)) else "",
		"i08":"complete" if passed_watch_service else "locked",
		"hoof_evidence":passed_watch_service,
		"i10":"complete" if legacy_released else ("pending" if legacy_night == "pending" else "locked"),
		"raid_path":"legacy" if legacy_released else "",
		"visible_raiders":30,
		"i11":"pending" if legacy_raid_finished else "locked",
		"i12":"locked","i13":"locked","i14":"locked",
		"julia_outcome":"legacy" if legacy_released else "undecided",
		"oath":false
	}
	# Old saves that had already passed the family morning never carried the
	# newly authored basket; do not invent it retroactively.
	if passed_family_morning:
		child.carried.erase("neighbor_basket")

	# Restore generic villagers that no longer carry a family/story role.
	var antonia := _person(data, "antonia")
	if not antonia.is_empty():
		antonia.profession = "Töpferin"
	var quintus := _person(data, "quintus")
	if not quintus.is_empty():
		quintus.profession = "Steinbrecher"

	# Canonical actors inherit the authored presentation roles and stay at the
	# family/smith locations during the childhood chapter.
	for id: String in EXTRA_NPCS:
		var person := _person(data, id)
		if not person.is_empty():
			person.profession = EXTRA_NPCS[id].role
			person.assignment = "idle"
			person.previous_assignment = "idle"
	return true


## Adds the v3 screenplay fields to v2 childhood saves without completing
## anything retroactively: a save already past the watch post keeps I-07 water
## as "legacy"; a save standing exactly before it gets the new water task.
## The chain continues with v3 -> v4 (I-01 morning, see I01.migrate).
static func migrate_screenplay(data: Dictionary) -> bool:
	if not enabled(data):
		return false
	var child: Variant = data.village.childhood
	if typeof(child) != TYPE_DICTIONARY or typeof(child.get("screenplay")) != TYPE_DICTIONARY or typeof(child.get("completed")) != TYPE_ARRAY:
		return false
	var screenplay: Dictionary = child.screenplay
	var migrated := false
	if int(screenplay.get("version", 0)) == 2:
		var water_index := _step_index("watch_post")
		var done: int = child.completed.size()
		screenplay.i07_water = "locked" if done < water_index else ("pending" if done == water_index else "legacy")
		screenplay.version = 3
		migrated = true
	if I01.migrate(child):
		migrated = true
	if I03.migrate(child, data.get("companion", {})):
		migrated = true
	if I04.migrate(child, _i04_index()):
		migrated = true
	return migrated


static func _step_index(step_id: String) -> int:
	for index in STEPS.size():
		if STEPS[index].id == step_id:
			return index
	return -1


static func has_npc(data: Dictionary, id: String) -> bool:
	return enabled(data) and EXTRA_NPCS.has(id)


static func relationship(data: Dictionary, id: String) -> Dictionary:
	return _relation(data, id).duplicate(true)


static func npc_catalog(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not enabled(data):
		return result
	for id: String in EXTRA_NPCS:
		var spec: Dictionary = EXTRA_NPCS[id]
		var point: Vector2 = POINTS[spec.point]
		result.append({"id":id,"name":spec.name,"role":spec.role,"profession":spec.profession,
			"cost":{},"x":point.x,"z":point.y,"greeting":_idle_text(id),"reply":_idle_text(id)})
	return result


static func actor_override(data: Dictionary, id: String) -> Variant:
	if not enabled(data):
		return null
	var observed: Variant = CompanionStory.observed_position(data, id)
	if observed != null:
		return observed
	var child: Dictionary = data.village.childhood
	if id == "severus":
		if child.guard_absence.active:
			return POINTS.sick_guard
		var current := _current(data)
		if current.get("id", "") in ["patrol_brief","patrol_inner"]:
			return POINTS.patrol_inner + Vector2(1.8, 0)
		if current.get("id", "") == "patrol_road":
			return POINTS.patrol_road + Vector2(1.8, 0)
		if current.get("id", "") in ["patrol_gate","patrol_report"]:
			return POINTS.patrol_gate + Vector2(1.8, 0)
	if id in ["julia", "silvanus"] and bool(I01.presentation(data).get(id + "_at_table", false)) and str(_person(data, id).get("assignment", "idle")) == "idle":
		return I01.POINTS[id + "_table"]
	if EXTRA_NPCS.has(id) and str(_person(data, id).get("assignment", "idle")) == "idle":
		return POINTS[EXTRA_NPCS[id].point]
	if child.completed.size() < STEPS.size() and NEIGHBORS.has(id):
		var duty: String = str(_person(data, id).get("assignment", "idle"))
		if WORKPLACE_POSITIONS.has(duty):
			var rank := 0
			for person: Dictionary in data.village.economy.people:
				if person.id == id:
					break
				if person.assignment == duty:
					rank += 1
			return WORKPLACE_POSITIONS[duty] + Vector2((rank % 2) * 2.4 - 1.2, 2.1 + floori(float(rank) / 2.0) * 2.0)
		return NEIGHBORS[id].position
	return null


static func execute(data: Dictionary, command: String, args: Dictionary = {}) -> Dictionary:
	if not enabled(data) or not COMMAND_FIELDS.has(command) or not _keys(args, COMMAND_FIELDS[command]):
		return _fail("Dieser Kindheitsauftrag ist nicht verfügbar oder enthält unerlaubte Angaben.")
	var error := validate(data)
	if not error.is_empty():
		return _fail("Ungültiger Kindheitsstand: " + error)
	if command == "village_childhood_action" and (typeof(args.action_id) != TYPE_STRING or args.action_id.length() > 64):
		return _fail("Ungültige Auftragskennung.")
	var candidate: Dictionary = data.duplicate(true)
	var result := _apply(candidate, command, args)
	if not result.ok:
		return result
	# Abilities are proven by the facts this action just stored; they persist
	# at village.abilities and stay effective after the mission ends.
	for gained: String in Abilities.sync(candidate):
		result.message = str(result.message) + " Neue Fähigkeit: " + str(Abilities.entry(gained).name) + "."
	error = validate(candidate)
	if not error.is_empty():
		return _fail("Kindheitsauftrag vollständig verworfen: " + error)
	data.village = candidate.village
	data.resources = candidate.resources
	data.companion = candidate.companion
	return result


static func talk(data: Dictionary, id: String, choice: String) -> Dictionary:
	if not has_npc(data, id) or choice != "meet":
		return _fail("Diese Antwort gehört nicht zum aktuellen Gespräch.")
	if not _available(data, id) or _distance(data, _npc_position(data, id)) > NPC_RANGE:
		return _fail("Gehe zu dieser Person im Dorf, bevor ihr miteinander sprecht.")
	var relation := _relation(data, id)
	if relation.met:
		return _fail("Ihr kennt einander bereits. Vertrauen entsteht durch eure gemeinsamen Handlungen.")
	relation.met = true
	relation.trust = mini(100, int(relation.trust) + 3)
	return _ok(_idle_text(id))


static func _apply(data: Dictionary, command: String, args: Dictionary) -> Dictionary:
	var child: Dictionary = data.village.childhood
	if command == "village_childhood_begin_raid":
		if child.completed.size() != STEPS.size() or child.night_event != "pending" or child.screenplay.i10 != "pending":
			return _fail("Diese Nacht wurde noch nicht durch den tatsächlichen Dorfanfang erreicht.")
		# Compatibility entry for existing automation: historically this command
		# meant "release the first raid". It now maps to the canonical defend path.
		child.screenplay.i10 = "complete"
		child.screenplay.raid_path = "defend"
		child.night_event = "released"
		return _ok("In der Nacht brechen fremde Reiter in Valdora ein. Du gehst hinaus, um Menschen zu helfen.")
	var step := _current(data)
	if step.is_empty():
		return _fail("Die Aufgaben dieses Kindheitskapitels sind bereits abgeschlossen.")
	var action: String = args.action_id
	if I01.handles(action):
		var morning := I01.apply(data, action, _villager_positions(data))
		if not morning.ok:
			return _fail(str(morning.message))
		_record(data, action, str(morning.message), str(morning.events[0]))
		return _ok(str(morning.message))
	if I03.handles(action):
		var errand := I03.apply(data, action, i03_ctx(data))
		if not errand.ok:
			return _fail(str(errand.message))
		for item: String in errand.carry_add:
			child.carried.append(item)
		for item: String in errand.carry_remove:
			child.carried.erase(item)
		if bool(errand.parted):
			# The two part: the stored memories are summarised once for the
			# systems that still read the older companion fields.
			var kind := I03.summary(child.screenplay)
			data.companion.met = true
			data.companion.choice = kind
			data.companion.trust = 20 if kind == "help" else -5
			child.screenplay.i03_outcome = "friend" if kind == "help" else "rival"
		_record(data, action, str(errand.message), str(errand.events[0]))
		return _ok(str(errand.message))
	if I04.handles(action):
		var visit := I04.apply(data, action, i04_ctx(data))
		if not visit.ok:
			return _fail(str(visit.message))
		for item: String in visit.carry_add:
			child.carried.append(item)
		for item: String in visit.carry_remove:
			child.carried.erase(item)
		_record(data, action, str(visit.message), str(visit.event_id))
		return _ok(str(visit.message))
	var id: String = step.id
	if step.get("screenplay", false):
		var reason := _action_reason(data, step)
		if not reason.is_empty():
			return _fail(reason)
		return _apply_screenplay(data, step, action)
	var starting := action == "begin_" + id and step.has("seconds")
	if not starting and not _matches(id, action):
		return _fail("Diese Handlung passt noch nicht zu deinem aktuellen Auftrag.")
	var reason := _action_reason(data, step)
	if not reason.is_empty():
		return _fail(reason)
	if step.has("seconds"):
		if starting:
			if child.active_work != "":
				return _fail("Diese Arbeit läuft bereits. Bleibe am Arbeitsplatz und schließe sie danach bewusst ab.")
			child.active_work = id
			child.work_seconds = 0.0
			return _ok("Die angeleitete Arbeit beginnt. Nur deine tatsächliche Anwesenheit an dieser Station zählt.")
		if child.active_work != id or float(child.work_seconds) + 0.000001 < float(step.seconds):
			return _fail("Diese Arbeitsfolge ist noch nicht fertig. Beginne sie vor Ort und bleibe an der Station.")
	if id == "smith_apprentice" and int(_relation(data, "sextus").trust) < 8:
		return _fail("Sextus braucht Vertrauen aus eurer tatsächlich erledigten Arbeit.")
	if id == "rest_patrol":
		var guard := _person(data, "severus")
		if guard.is_empty() or not guard.alive or data.village.get("militia", []).has("severus") or guard.assignment == "defense":
			return _fail("Der Wachmann ist für diesen Dorfabschnitt nicht verfügbar.")
		child.guard_absence = {"active":true,"previous_assignment":guard.assignment,"previous_health":guard.health}
		guard.assignment = "idle"
		guard.previous_assignment = "idle"
		guard.health = mini(30, int(guard.health))
	var effect: Dictionary = CARRIED_EFFECTS.get(id, {})
	for item: String in effect.get("remove", []):
		if not child.carried.has(item):
			return _fail("Der tatsächlich benötigte Auftragsgegenstand fehlt.")
	for item: String in effect.get("remove", []):
		child.carried.erase(item)
	for item: String in effect.get("add", []):
		child.carried.append(item)
	var reward := 0
	if id in ["deliver_hinge", "return_gear"]:
		reward = 2
	elif action == "market_fair":
		reward = 2
	elif action == "market_neighbor":
		reward = 1
	if reward > 0:
		if int(data.resources.denarii) > MAX_RESOURCE - reward:
			return _fail("Für den vereinbarten Lohn ist kein Platz im Geldbestand.")
		data.resources.denarii += reward
		data.village.social.ledger.denarii += reward
	if step.has("npc"):
		_gain_trust(data, step.npc, 2)
	if id in ["forge_bellows", "forge_anvil", "forge_quench"]:
		_gain_trust(data, "sextus", 1)
	if action == "market_neighbor":
		_gain_trust(data, "julia", 2)
	if id == "deliver_kindling":
		_relation(data, "sextus").helped = true
	if id == "smith_trial":
		child.apprenticeship = "trial"
	if id == "smith_apprentice":
		child.apprenticeship = "apprentice"
		data.village.social.profession = "smith"
		_relation(data, "sextus").learned = true
	if id == "borrow_gear":
		child.gear = "loaned"
		child.screenplay.i07_water = "pending"
	if id == "deliver_medicine":
		var guard := _person(data, "severus")
		guard.health = maxi(50, int(guard.health))
	if id == "return_gear":
		child.gear = "returned"
		_restore_guard(data)
		if child.screenplay.i08 == "locked":
			child.screenplay.i08 = "pending"
	if id in ["patrol_inner", "patrol_road", "patrol_gate"]:
		var attribute: String = {"patrol_inner":"insight","patrol_road":"tactics","patrol_gate":"courage"}[id]
		data.village.attributes[attribute] = mini(10000, int(data.village.attributes[attribute]) + 1)
	if step.get("rest", false):
		child.day += 1
	if id == "night_rest":
		child.night_event = "pending"
		child.screenplay.i10 = "pending"
	child.active_work = ""
	child.work_seconds = 0.0
	child.completed.append(action)
	var message: String = step.result
	if action == "market_fair":
		message = "Der vereinbarte Preis gilt. Du erhältst einmalig zwei Denare; Cassia merkt sich deine verlässliche Abrechnung."
	elif action == "market_neighbor":
		message = "Du nimmst einen Denar und lässt einen dem Nachbarn. Julia hört von deiner freiwilligen Hilfe."
	_record(data, action, message)
	return _ok(message)


static func _apply_screenplay(data: Dictionary, step: Dictionary, action: String) -> Dictionary:
	var child: Dictionary = data.village.childhood
	var screenplay: Dictionary = child.screenplay
	var id: String = step.id
	var message := ""
	match id:
		"i02_basket":
			if action == "basket_check":
				screenplay.i02 = "complete"
				screenplay.i02_outcome = "checked"
				screenplay.i03 = "pending"
				child.carried.erase("neighbor_basket")
				message = "Du prüfst den Korb mit Aurelia. Die Lieferung stimmt; Sorgfalt wird als konkrete Erinnerung gespeichert."
			elif action == "basket_rush":
				screenplay.i02 = "correction"
				screenplay.i02_outcome = "wrong"
				message = "Du hast den falschen Korb erwischt. Die Mission scheitert nicht: Julia muss dir helfen, den Fehler zu korrigieren."
			else:
				return _fail("Entscheide, ob du den Korb prüfst oder ungeprüft abgibst.")
		"i02_correct":
			if action != "basket_correct":
				return _fail("Korrigiere den falschen Korb gemeinsam mit Julia.")
			screenplay.i02 = "complete"
			screenplay.i03 = "pending"
			child.carried.erase("neighbor_basket")
			message = "Julia hilft dir, den Fehler zu korrigieren. Der falsche Korb bleibt als Ereignis erhalten, statt durch einen Reload zu verschwinden."
		"i07_water_fetch":
			if action != "i07_water_fetch":
				return _fail("Schöpfe zuerst das Wasser für den Torposten.")
			screenplay.i07_water = "carry"
			message = "Der Krug ist gefüllt. Trag ihn zum bekannten Torabschnitt."
		"i07_water_bring":
			if action != "i07_water_bring":
				return _fail("Bring das Wasser zum Torposten.")
			screenplay.i07_water = "complete"
			message = "Das Wasser steht am Torposten. Jetzt kannst du am bekannten Torabschnitt aushelfen."
		"i08_tracks":
			if action != "i08_inspect":
				return _fail("Untersuche zuerst die Hufspuren selbst.")
			screenplay.i08 = "report"
			screenplay.hoof_evidence = true
			_gain(data, "insight", 1)
			message = "Du sicherst mehrere frische Hufspuren als Beobachtung. Herkunft und Täter bleiben ausdrücklich offen."
		"i08_report":
			if action != "i08_report" or not screenplay.hoof_evidence:
				return _fail("Du kannst nur berichten, was du zuvor tatsächlich untersucht hast.")
			screenplay.i08 = "complete"
			_gain(data, "tactics", 1)
			message = "Decimus protokolliert die Spuren ohne vorschnelle Schuldzuweisung. Die Warnung bleibt im Event-Ledger."
		"i10_choice":
			if action not in ["i10_defend","i10_hide"]:
				return _fail("Entscheide ausdrücklich zwischen Hilfe draußen und Verstecken bei deinen Eltern.")
			screenplay.i10 = "complete"
			screenplay.raid_path = "defend" if action == "i10_defend" else "hide"
			child.night_event = "released"
			message = "Du gehst hinaus, um Menschen zu helfen. Die Nacht läuft nun in der realen Dorfwelt." if action == "i10_defend" else "Du bleibst bei deinen Eltern. Die Welt läuft weiter; dieses Versteck schützt nicht automatisch alle."
		"i11_forge":
			if action != "i11_forge":
				return _fail("Erreiche die Schmiede und den offenen Fluchtweg.")
			var smith := _person(data, "sextus")
			if smith.is_empty() or not smith.alive:
				return _fail("Sextus’ Zustand passt nicht mehr zu diesem Storyschritt.")
			smith.alive = false
			smith.health = 0
			smith.assignment = "idle"
			smith.previous_assignment = "idle"
			screenplay.i11 = "complete"
			screenplay.i12 = "pending"
			message = "Sextus hält den Fluchtweg offen und stirbt. Sein Arbeitsplatz bleibt danach tatsächlich unbesetzt."
		"i12_father":
			if action != "i12_father":
				return _fail("Folge Silvanus auf seinem letzten Weg.")
			var father := _person(data, "silvanus")
			if father.is_empty() or not father.alive:
				return _fail("Silvanus’ Zustand passt nicht mehr zu diesem Storyschritt.")
			father.alive = false
			father.health = 0
			father.assignment = "idle"
			father.previous_assignment = "idle"
			var mother := _person(data, "julia")
			var julia_survives := true
			if screenplay.raid_path == "hide":
				julia_survives = false
			elif screenplay.raid_path == "defend":
				var raid: Dictionary = data.village.raid
				julia_survives = bool(raid.get("rescued", false)) and str(raid.get("rescue_person_id", "")) == "julia"
			elif screenplay.raid_path == "legacy":
				julia_survives = not mother.is_empty() and bool(mother.get("alive", true))
			if not julia_survives and not mother.is_empty():
				mother.alive = false
				mother.health = 0
				mother.assignment = "idle"
				mother.previous_assignment = "idle"
			screenplay.julia_outcome = "survived" if julia_survives else "dead"
			screenplay.i12 = "complete"
			screenplay.i13 = "pending"
			message = "Silvanus stirbt. Julia überlebt, weil du sie tatsächlich aus der Gefahrenzone gebracht hast." if julia_survives else "Silvanus stirbt. Julia überlebt diesen Weg nicht; die Entscheidung bleibt dauerhaft im Weltzustand."
		"i13_morning":
			if action != "i13_morning":
				return _fail("Erfasse mit Aurelia die tatsächlichen Folgen des Angriffs.")
			screenplay.i13 = "complete"
			screenplay.i14 = "pending"
			message = "Am Morgen bleiben Tote, Verletzte, verlorene Arbeitsplätze und beschädigte Vorräte Teil derselben Welt."
		"i14_oath":
			if action != "i14_oath":
				return _fail("Der Schwur wird nur am Waldrand als bewusste Handlung abgeschlossen.")
			if not child.carried.has("memory_token"):
				child.carried.append("memory_token")
			screenplay.i14 = "complete"
			screenplay.oath = true
			child.night_event = "resolved"
			message = "»Ich werde euch rächen. Ich finde die Verantwortlichen.« Der Schwur öffnet die Ermittlung; er macht dich nicht automatisch zum Soldaten."
		_:
			return _fail("Unbekannter Drehbuchschritt.")
	_record(data, action, message)
	return _ok(message)


static func advance(data: Dictionary, delta: float) -> bool:
	if not enabled(data) or not is_finite(delta) or delta <= 0.0 or delta > 3600.0 or not validate(data).is_empty():
		return false
	var child: Dictionary = data.village.childhood
	var step := _current(data)
	if child.active_work == "" or not step.has("seconds") or not _action_reason(data, step).is_empty():
		return false
	var before := float(child.work_seconds)
	child.work_seconds = minf(float(step.seconds), before + delta)
	return float(child.work_seconds) > before


static func raids_allowed(data: Dictionary) -> bool:
	return not enabled(data) or data.village.childhood.night_event in ["released","resolved"]


static func on_raid_finished(data: Dictionary) -> void:
	if not enabled(data):
		return
	var screenplay: Dictionary = data.village.childhood.screenplay
	if screenplay.i10 == "complete" and screenplay.i11 == "locked":
		screenplay.i11 = "pending"


static func view(data: Dictionary) -> Dictionary:
	if not enabled(data) or not validate(data).is_empty():
		return {}
	var child: Dictionary = data.village.childhood
	var step := _current(data)
	var items: Array[String] = []
	for item: String in child.carried:
		items.append(ITEM_NAMES[item])
	var mission_id: String = step.get("mission", SOURCE_MISSION_BY_STEP.get(step.get("id", ""), ""))
	var chapter: String = step.get("chapter", "Die Nacht im Dorf")
	var result := {"enabled":true,"day":child.day,"age":int(data.player.age),
		"completed_steps":child.completed.size(),"total_steps":STEPS.size(),
		"stage":step.get("id", "village_night"),"source_mission_id":mission_id,
		"chapter":chapter,"title":mission_heading(mission_id, chapter),
		"objective":step.get("objective", "Du bist bei deiner Familie. Die nächste Nacht setzt eure gemeinsame Geschichte fort."),
		"carried":items,"relationships":child.relationships.duplicate(true),
		"apprenticeship":child.apprenticeship,"gear_loaned":child.gear == "loaned",
		"loaned_items":["Leihhelm","Hölzerner Leihschild"] if child.gear == "loaned" else [],
		"work_seconds":child.work_seconds,"work_required":step.get("seconds", 0.0),
		"can_rest":step.get("rest", false) or step.get("id", "") == "night_rest",
		"night_raid_pending":child.night_event == "pending","night_event":child.night_event,
		"guard_absent":child.guard_absence.active,"target_npc":step.get("npc", ""),
		"target_point":step.get("point", ""),"actions":_choices(data, step),
		"hud_title":hud_title(step, mission_id, chapter),"in_first_mission":I01.in_mission(data),
		"morning":I01.presentation(data)}
	var cup_state: Dictionary = I01.cups(data)
	if cup_state.values().has("hand"):
		items.append("Drei Becher vom Regal")
	if str(child.screenplay.get("i01_water", "")) == "jug":
		items.append("Familienkrug mit Brunnenwasser")
	if bool(child.screenplay.get("i04_hand", false)):
		items.append("Ein Arm voll Kleinholz")
	if not step.is_empty():
		var target := _target(data, step)
		result["target_position"] = [target.x, target.y]
		result["point"] = target
	return result


## Player-facing objective heading (HB 3.0 S. 44): occasion and place instead
## of a technical mission ID. The ID-bearing title stays for chronicle/tests.
static func hud_title(step: Dictionary, mission_id: String, chapter: String) -> String:
	var occasion := str(Bible.mission(mission_id).get("title", "")) if not mission_id.is_empty() else ""
	if occasion.is_empty():
		occasion = chapter
	var place := I01.hud_place(step)
	if place.is_empty():
		place = I03.hud_place(step)
	if place.is_empty():
		place = I04.hud_place(step)
	if place.is_empty() and step.has("npc"):
		place = "bei " + str(EXTRA_NPCS.get(step.npc, NEIGHBORS.get(step.npc, {})).get("name", ""))
	return occasion if place.is_empty() or place == "bei " else "%s · %s" % [occasion, place]


## HUD heading for a childhood step: the screenplay mission ID and its authored
## Band 1 title. Steps without a screenplay mission keep their scene chapter.
static func mission_heading(mission_id: String, chapter: String) -> String:
	if mission_id.is_empty():
		return chapter
	var title := str(Bible.mission(mission_id).get("title", ""))
	return chapter if title.is_empty() else "%s · %s" % [mission_id, title]


static func dialogue(data: Dictionary, npc_id: String) -> Dictionary:
	if not enabled(data) or not (EXTRA_NPCS.has(npc_id) or NEIGHBORS.has(npc_id)) or not validate(data).is_empty():
		return {}
	var spec: Dictionary = EXTRA_NPCS.get(npc_id, NEIGHBORS.get(npc_id, {}))
	var relation := _relation(data, npc_id)
	var choices: Array[Dictionary] = []
	var text := _idle_text(npc_id)
	if not _available(data, npc_id):
		text = "Diese Person kann gerade kein Gespräch im Dorf führen. Ihre bisherige Geschichte bleibt erhalten."
	elif not relation.get("met", false):
		choices.append({"label":"Einander kennenlernen","command":"village_talk","payload":{"npc_id":npc_id,"choice":"meet"},"enabled":true,"reason":""})
	else:
		var step := _current(data)
		if step.get("npc", "") == npc_id:
			text = step.text
			var remembered := I01.hook_lines(data, str(step.get("id", "")))
			remembered.append_array(I03.hook_lines(data, str(step.get("id", ""))))
			remembered.append_array(I04.hook_lines(data, str(step.get("id", ""))))
			if not remembered.is_empty():
				text = "\n\n".join(remembered) + "\n\n" + text
			choices = _choices(data, step)
		elif I01.contact_open(data, npc_id):
			text = I01.contact_line(npc_id)
			var why := I01.reason(data, "i01_contact_" + npc_id, _villager_positions(data))
			choices.append({"label":"Kurz zuhören und antworten","command":"village_childhood_action","payload":{"action_id":"i01_contact_" + npc_id},"enabled":why.is_empty(),"reason":why})
		elif typeof(step.get("visits")) == TYPE_DICTIONARY and step.visits.has(npc_id):
			# Optional visits authored in the mission data (e.g. I-09 evening).
			text = str(step.visits[npc_id])
		var companion_line := companion_dialogue(data, npc_id)
		if step.get("npc", "") != npc_id and not companion_line.is_empty():
			text = companion_line.text
		text += "\n\nVertrauen: %d · Erzählter Dorftag %d. Du bist weiterhin Teil deiner Familie und des Dorfes." % [int(relation.get("trust",0)),int(data.village.childhood.day)]
	return {"title":"%s · %s" % [spec.name,spec.role],"text":text,"choices":choices}


static func interactables(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not enabled(data) or not validate(data).is_empty():
		return result
	if I01.active(data):
		return I01.interactables(data, func(action: String) -> String: return _i01_reason(data, action))
	var step := _current(data)
	# Marcus (lane, farewell) is a person: he is addressed, not a world point.
	if not step.has("point") or step.get("id", "") in ["i03_marcus", "i03_farewell"]:
		return result
	var point: Vector2 = POINTS[step.point]
	for choice: Dictionary in _choices(data, step):
		result.append({"id":"childhood_"+str(step.id),"kind":"childhood","label":choice.label,
			"action_id":choice.payload.action_id,"point":point,
			"command":choice.command,"payload":choice.payload,"enabled":choice.enabled,"reason":choice.reason,
			"x":point.x,"z":point.y,"position":[point.x,point.y],"radius":POINT_RANGE})
	return result


static func validate(data: Dictionary) -> String:
	if not enabled(data):
		return ""
	if data.get("origin_id", "") != "italia" or not data.village.get("enabled", false) or not _integer(data.get("player", {}).get("age"), 12, 12) or data.get("progress", {}).get("years_elapsed", -1) != 0:
		return "Dieses Kindheitskapitel beginnt im römischen Dorf mit zwölf Jahren und ohne übersprungene Lebensjahre."
	var child: Variant = data.village.childhood
	if not _keys(child,["version","completed","day","carried","relationships","active_work","work_seconds","gear","apprenticeship","night_event","screenplay","guard_absence"]) or not _integer(child.version,VERSION,VERSION):
		return "Unbekannte oder unvollständige Kindheitsversion."
	if typeof(child.completed) != TYPE_ARRAY or child.completed.size() > STEPS.size() or typeof(child.carried) != TYPE_ARRAY:
		return "Ungültige Aufgabenfolge oder Traglast."
	var expected_items: Array[String] = []
	var expected_day := 1
	var expected_apprenticeship := "none"
	var expected_gear := "none"
	var absent := false
	for index in child.completed.size():
		var action: Variant = child.completed[index]
		var step: Dictionary = STEPS[index]
		if typeof(action) != TYPE_STRING or not _matches(step.id, action):
			return "Eine Aufgabe wurde übersprungen, vertauscht oder doppelt ausgeführt."
		var effect: Dictionary = CARRIED_EFFECTS.get(step.id, {})
		for item: String in effect.get("remove", []):
			if not expected_items.has(item):
				return "Widersprüchliche Übergabefolge."
			expected_items.erase(item)
		for item: String in effect.get("add", []):
			expected_items.append(item)
		if step.get("rest", false):
			expected_day += 1
		if step.id == "smith_trial":
			expected_apprenticeship = "trial"
		if step.id == "smith_apprentice":
			expected_apprenticeship = "apprentice"
		if step.id == "borrow_gear":
			expected_gear = "loaned"
		if step.id == "rest_patrol":
			absent = true
		if step.id == "return_gear":
			expected_gear = "returned"
			absent = false
	var screenplay: Variant = child.screenplay
	var screenplay_keys := ["version","i02","i02_outcome","i03","i03_outcome","i07_water","i08","hoof_evidence",
		"i10","raid_path","visible_raiders","i11","i12","i13","i14","julia_outcome","oath"]
	screenplay_keys.append_array(I01.KEYS)
	screenplay_keys.append_array(I03.KEYS)
	screenplay_keys.append_array(I04.KEYS)
	if not _keys(screenplay, screenplay_keys) or not _integer(screenplay.version,SCREENPLAY_VERSION,SCREENPLAY_VERSION):
		return "Ungültiger Drehbuch-Brückenstand."
	var morning_error := I01.validate(screenplay, child.completed.size())
	if not morning_error.is_empty():
		return morning_error
	var water_index := _step_index("watch_post")
	var water_allowed: Array = ["locked"]
	if child.completed.size() == water_index:
		water_allowed = ["pending","carry","complete"]
	elif child.completed.size() > water_index:
		water_allowed = ["complete","legacy"]
	if typeof(screenplay.i07_water) != TYPE_STRING or screenplay.i07_water not in water_allowed:
		return "Der Wasserauftrag in I-07 widerspricht der Auftragsfolge."
	if screenplay.i02 not in ["pending","correction","complete"] or screenplay.i03 not in ["locked","pending","complete"] or screenplay.i08 not in ["locked","pending","report","complete"]:
		return "Ungültiger Status einer frühen Drehbuchmission."
	for key: String in ["i10","i11","i12","i13","i14"]:
		if typeof(screenplay[key]) != TYPE_STRING or screenplay[key] not in ["locked","pending","complete"]:
			return "Ungültiger Status einer Nachtraid-Drehbuchmission."
	if typeof(screenplay.i02_outcome) != TYPE_STRING or screenplay.i02_outcome not in ["","checked","wrong","legacy"]:
		return "Ungültige Folge des Korbauftrags."
	if typeof(screenplay.i03_outcome) != TYPE_STRING or screenplay.i03_outcome not in ["","friend","rival","legacy"]:
		return "Ungültige Marcus-Erinnerung."
	if typeof(screenplay.raid_path) != TYPE_STRING or screenplay.raid_path not in ["","defend","hide","legacy"]:
		return "Ungültiger Weg durch die Nacht der Reiter."
	if typeof(screenplay.julia_outcome) != TYPE_STRING or screenplay.julia_outcome not in ["undecided","survived","dead","legacy"]:
		return "Ungültiger gespeicherter Ausgang für Julia."
	if typeof(screenplay.hoof_evidence) != TYPE_BOOL or typeof(screenplay.oath) != TYPE_BOOL or not _integer(screenplay.visible_raiders,30,30):
		return "Drehbuchbeleg, Schwur oder sichtbare Reiterzahl ist ungültig."

	if screenplay.i03_task == "service_bring":
		expected_items.append("stall_water")
	if screenplay.i04_note == "carried":
		expected_items.append("sextus_note")
	if screenplay.i02 == "complete":
		expected_items.erase("neighbor_basket")
	if screenplay.i14 == "complete":
		expected_items.append("memory_token")
	if screenplay.i03s == "legacy":
		# Saves decided before the playable errand keep their stored decision.
		if screenplay.i03 == "complete" and screenplay.i03_outcome != "legacy":
			if not data.companion.met or screenplay.i03_outcome == "friend" and data.companion.choice != "help" or screenplay.i03_outcome == "rival" and data.companion.choice != "decline":
				return "Marcus-Beziehung und I-03 widersprechen sich."
		elif screenplay.i03 != "complete" and data.companion.met:
			return "Marcus darf vor I-03 nicht stillschweigend als Gefährte entschieden sein."
	else:
		var summary_outcome: String = "" if screenplay.i03s != "complete" else ("friend" if I03.summary(screenplay) == "help" else "rival")
		if screenplay.i03_outcome != summary_outcome:
			return "Die I-03-Zusammenfassung widerspricht den gespeicherten Erinnerungen."
		if screenplay.i03s == "pending" and screenplay.i03 == "complete" and child.completed.size() > _i03_farewell_index():
			return "Die Bestellung kann nicht übergeben sein, bevor Marcus und du auseinandergegangen seid."
	var errand_error := I03.validate(screenplay, data.companion, child.carried)
	if not errand_error.is_empty():
		return errand_error
	var visit_error := I04.validate(screenplay, child.completed.size(), _i04_index(), child.carried)
	if not visit_error.is_empty():
		return visit_error
	if screenplay.i08 in ["report","complete"] and not screenplay.hoof_evidence:
		return "Die gemeldeten Hufspuren wurden nicht tatsächlich untersucht."
	if screenplay.i08 == "complete" and not child.completed.has("return_gear"):
		return "I-08 darf nicht vor dem begrenzten Wachtdienst abgeschlossen sein."

	var base_complete: bool = child.completed.size() == STEPS.size()
	var bridges_complete: bool = screenplay.i02 == "complete" and screenplay.i03 == "complete" and screenplay.i08 == "complete"
	if screenplay.i10 != "locked" and (not base_complete or not bridges_complete):
		return "I-10 darf erst nach dem vollständigen gewöhnlichen Dorfabend beginnen."
	if not base_complete and screenplay.i10 != "locked":
		return "Die Nacht der Reiter wurde vor dem letzten gewöhnlichen Abend geöffnet."
	if base_complete and bridges_complete and screenplay.i10 == "locked":
		return "Nach dem letzten gewöhnlichen Abend muss I-10 als nächste Mission bereitstehen."
	if screenplay.i10 == "pending" and screenplay.raid_path != "":
		return "Vor der Nachtentscheidung darf kein Raid-Weg feststehen."
	if screenplay.i10 == "complete" and screenplay.raid_path == "":
		return "Die abgeschlossene Nachtentscheidung benötigt einen gespeicherten Weg."
	if screenplay.i10 != "complete" and screenplay.i11 != "locked":
		return "I-11 darf nicht vor der Nachtentscheidung beginnen."

	var raid: Dictionary = data.village.get("raid", {})
	if screenplay.i11 in ["pending","complete"] and (raid.get("status","") != "aftermath" or int(raid.get("completed",0)) < 1):
		return "I-11 benötigt einen tatsächlich abgeschlossenen Angriff."
	if raid.get("status","") == "aftermath" and screenplay.i10 == "complete" and screenplay.i11 == "locked":
		return "Nach dem Angriff muss I-11 freigeschaltet sein."
	if screenplay.i11 == "pending" and screenplay.i12 != "locked":
		return "I-12 darf erst nach Sextus’ Schmiedeszene beginnen."
	if screenplay.i11 == "complete":
		var smith := _person(data,"sextus")
		if smith.is_empty() or smith.alive or int(smith.health) != 0 or smith.assignment != "idle":
			return "I-11 und Sextus’ tatsächlicher Einwohnerzustand widersprechen sich."
		if screenplay.i12 == "locked":
			return "Nach I-11 muss I-12 bereitstehen."
	if screenplay.i12 == "pending" and screenplay.i13 != "locked":
		return "I-13 darf erst nach dem letzten Weg des Vaters beginnen."
	if screenplay.i12 == "complete":
		var father := _person(data,"silvanus")
		var mother := _person(data,"julia")
		if father.is_empty() or father.alive or int(father.health) != 0 or father.assignment != "idle":
			return "I-12 und Silvanus’ tatsächlicher Einwohnerzustand widersprechen sich."
		if screenplay.julia_outcome not in ["survived","dead"]:
			return "I-12 benötigt einen eindeutigen Ausgang für Julia."
		if mother.is_empty() or screenplay.julia_outcome == "survived" and (not mother.alive or int(mother.health) <= 0) or screenplay.julia_outcome == "dead" and (mother.alive or int(mother.health) != 0):
			return "Julias gespeicherter Ausgang widerspricht ihrem Einwohnerzustand."
		if screenplay.i13 == "locked":
			return "Nach I-12 muss I-13 bereitstehen."
	elif screenplay.julia_outcome not in ["undecided","legacy"]:
		return "Julias Endzustand wurde vor I-12 festgeschrieben."
	if screenplay.i13 == "complete" and screenplay.i14 == "locked":
		return "Nach I-13 muss I-14 bereitstehen."
	if screenplay.i14 == "complete":
		if not screenplay.oath or not expected_items.has("memory_token"):
			return "I-14 benötigt Schwur und Erinnerungsstück."
	elif screenplay.oath:
		return "Der Schwur darf nicht vor I-14 gesetzt sein."

	var expected_night := "none"
	if base_complete and bridges_complete:
		expected_night = "pending" if screenplay.i10 == "pending" else ("resolved" if screenplay.i14 == "complete" else "released")
	if typeof(child.night_event) != TYPE_STRING or child.night_event != expected_night:
		return "Nachtstatus und Drehbuchfortschritt widersprechen sich."
	if child.night_event in ["none","pending"] and (raid.get("status","") != "quiet" or int(raid.get("number",-1)) != 0 or int(raid.get("completed",-1)) != 0):
		return "Vor der freigegebenen Nacht darf kein Überfall begonnen oder abgeschlossen sein."
	if child.night_event == "resolved" and (raid.get("status","") != "aftermath" or int(raid.get("completed",0)) < 1):
		return "Der Schwur darf keinen unabgeschlossenen Nachtangriff überspringen."

	if not _integer(child.day,1,4) or child.day != expected_day or child.carried != expected_items:
		return "Tag oder Auftragsgegenstände sind nicht durch erledigte Handlungen belegt."
	if typeof(child.apprenticeship) != TYPE_STRING or child.apprenticeship != expected_apprenticeship or typeof(child.gear) != TYPE_STRING or child.gear != expected_gear:
		return "Lehre oder Leihgegenstände widersprechen der Auftragsfolge."
	if not _keys(child.relationships,EXTRA_NPCS.keys()):
		return "Die Familien- oder Lehrbeziehungen fehlen."
	for id: String in EXTRA_NPCS:
		var relation: Variant = child.relationships[id]
		if not _keys(relation,["met","trust","helped","declined","learned","ally"]) or not _integer(relation.trust,-100,100):
			return "Ungültige Kindheitsbeziehung."
		for key: String in ["met","helped","declined","learned","ally"]:
			if typeof(relation[key]) != TYPE_BOOL:
				return "Beziehungsmerkmale benötigen Wahrheitswerte."
		if (relation.helped or relation.learned or relation.ally or relation.declined) and not relation.met or relation.helped and relation.declined:
			return "Widersprüchliche Kindheitsbeziehung."
		if id in ["julia","silvanus"] and not relation.met:
			return "Die eigene Familie darf nicht nachträglich unbekannt sein."
		if _person(data,id).is_empty():
			return "Eine Familien- oder Lehrperson fehlt im gemeinsamen Einwohnerroster."
	if child.relationships.sextus.helped != child.completed.has("deliver_kindling") or child.relationships.sextus.learned != (expected_apprenticeship == "apprentice"):
		return "Sextus’ Hilfe und Lehre müssen durch die gemeinsame Auftragsfolge belegt sein."
	var current := _current(data)
	var limit := float(current.get("seconds", 0.0))
	if typeof(child.active_work) != TYPE_STRING or not _number(child.work_seconds,0.0,limit):
		return "Ungültige Arbeitszeit."
	if child.active_work != "" and (limit <= 0.0 or child.active_work != current.get("id", "")) or child.active_work == "" and float(child.work_seconds) != 0.0:
		return "Arbeitszeit gehört nicht zur aktuellen begonnenen Tätigkeit."
	var absence: Variant = child.guard_absence
	if not _keys(absence,["active","previous_assignment","previous_health"]) or typeof(absence.active) != TYPE_BOOL or absence.active != absent or not _integer(absence.previous_health,0,100) or typeof(absence.previous_assignment) != TYPE_STRING or absence.previous_assignment not in ["idle","farm","woodcamp","quarry","trade","watchpost"]:
		return "Ungültige gespeicherte Wachablösung."
	if absent:
		var guard := _person(data,"severus")
		if guard.is_empty() or guard.assignment != "idle" or not guard.alive:
			return "Der erkrankte Wächter darf nicht zugleich einen Arbeitsplatz besetzen."
	return ""


static func _screenplay_step(data: Dictionary) -> Dictionary:
	var child: Dictionary = data.village.childhood
	var screenplay: Dictionary = child.screenplay
	# I-01: the playable first morning precedes the established family steps.
	if I01.active(data):
		return I01.current_step(data)
	# I-02 and I-03 sit after the established family morning. They are separate
	# from completed[] so older 35-step saves keep their exact sequence indices.
	if child.completed.size() >= 3:
		if screenplay.i02 == "pending":
			return BRIDGE_STEPS["i02_basket"].duplicate(true)
		if screenplay.i02 == "correction":
			return BRIDGE_STEPS["i02_correct"].duplicate(true)
		var errand := I03.current_step(data, i03_ctx(data))
		if not errand.is_empty():
			return errand
		# I-04: the workshop visit sits between the delivered kindling and the
		# father's permission, again outside completed[].
		var visit := I04.current_step(data, i04_ctx(data))
		if not visit.is_empty():
			return visit
	# I-07 story core names water, a message and a short control round. Water is
	# carried to the known gate section before the supervised watch post.
	if child.completed.size() == _step_index("watch_post"):
		if screenplay.i07_water == "pending":
			return {"id":"i07_water_fetch","mission":"I-07","screenplay":true,"point":"family_water",
				"chapter":"Der kranke Wachmann","label":"Wasser für den Torposten schöpfen",
				"objective":"Der Torposten braucht Wasser. Schöpfe am Haus einen Krug, bevor du zum bekannten Torabschnitt gehst.",
				"text":"","result":"Der Krug ist gefüllt."}
		if screenplay.i07_water == "carry":
			return {"id":"i07_water_bring","mission":"I-07","screenplay":true,"point":"patrol_gate",
				"chapter":"Der kranke Wachmann","label":"Den Wasserkrug zum Torposten bringen",
				"objective":"Bring das Wasser zum bekannten Torabschnitt. Du hilfst beaufsichtigt; du stehst keine Wache allein.",
				"text":"","result":"Das Wasser steht am Torposten."}
	# I-08 must happen after the bounded watch service and before the last normal
	# family evening. No people or faction are identified from hoofprints alone.
	if child.completed.has("return_gear"):
		if screenplay.i08 == "pending":
			return BRIDGE_STEPS["i08_tracks"].duplicate(true)
		if screenplay.i08 == "report":
			return BRIDGE_STEPS["i08_report"].duplicate(true)
	if child.completed.size() == STEPS.size():
		if screenplay.i10 == "pending":
			return BRIDGE_STEPS["i10_choice"].duplicate(true)
		if screenplay.i10 == "complete" and screenplay.i11 == "pending":
			return BRIDGE_STEPS["i11_forge"].duplicate(true)
		if screenplay.i11 == "complete" and screenplay.i12 == "pending":
			return BRIDGE_STEPS["i12_father"].duplicate(true)
		if screenplay.i12 == "complete" and screenplay.i13 == "pending":
			return BRIDGE_STEPS["i13_morning"].duplicate(true)
		if screenplay.i13 == "complete" and screenplay.i14 == "pending":
			return BRIDGE_STEPS["i14_oath"].duplicate(true)
	return {}


static func current_step(data: Dictionary) -> Dictionary:
	return _current(data).duplicate(true) if enabled(data) else {}


static func companion_specs(data: Dictionary) -> Dictionary:
	var step := current_step(data)
	var mission := str(step.get("mission", SOURCE_MISSION_BY_STEP.get(step.get("id", ""), "")))
	return CompanionStory.for_step(data, mission, str(step.get("id", "")))


static func companion_dialogue(data: Dictionary, id: String) -> Dictionary:
	var step := current_step(data)
	var mission := str(step.get("mission", SOURCE_MISSION_BY_STEP.get(step.get("id", ""), "")))
	return CompanionStory.dialogue(data, id, mission, str(step.get("id", "")))


static func display_name(data: Dictionary, id: String, fallback: String) -> String:
	return CompanionStory.display_name(data, id, fallback)


static func _current(data: Dictionary) -> Dictionary:
	var screenplay_step := _screenplay_step(data)
	if not screenplay_step.is_empty():
		return screenplay_step
	var index: int = data.village.childhood.completed.size()
	return STEPS[index] if index < STEPS.size() else {}


static func _matches(id: String, action: String) -> bool:
	return action in ["market_fair","market_neighbor"] if id == "market_trade" else action == id


static func _choices(data: Dictionary, step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if step.is_empty():
		return result
	if step.get("i01", false):
		for option: Dictionary in I01.options(data, step):
			var why := _i01_reason(data, str(option.id))
			result.append({"label":option.label,"command":"village_childhood_action","payload":{"action_id":option.id},"enabled":why.is_empty(),"reason":why})
		return result
	if step.get("i04", false):
		for option: Dictionary in I04.options(data, step):
			var why := I04.reason(data, str(option.id), i04_ctx(data))
			result.append({"label":option.label,"command":"village_childhood_action","payload":{"action_id":option.id},"enabled":why.is_empty(),"reason":why})
		return result
	if step.get("i03", false):
		for option: Dictionary in I03.options(data, step):
			var why := I03.reason(data, str(option.id), i03_ctx(data))
			result.append({"label":option.label,"command":"village_childhood_action","payload":{"action_id":option.id},"enabled":why.is_empty(),"reason":why})
		return result
	var options: Array = [{"id":step.id,"label":step.label}]
	if step.id == "market_trade":
		options = [{"id":"market_fair","label":"Den vereinbarten Lohn nehmen · 2 Denare"},
			{"id":"market_neighbor","label":"Dem Nachbarn einen Denar lassen · 1 Denar Lohn"}]
	elif step.id == "i02_basket":
		options = [{"id":"basket_check","label":"Korb gemeinsam prüfen"},
			{"id":"basket_rush","label":"Ohne Prüfung abgeben"}]
	elif step.id == "i02_correct":
		options = [{"id":"basket_correct","label":"Fehler korrigieren und richtigen Korb schicken"}]
	elif step.id == "i07_water_fetch":
		options = [{"id":"i07_water_fetch","label":"Wasserkrug füllen"}]
	elif step.id == "i07_water_bring":
		options = [{"id":"i07_water_bring","label":"Wasser am Torposten abstellen"}]
	elif step.id == "i08_tracks":
		options = [{"id":"i08_inspect","label":"Hufspuren untersuchen und nur Beobachtungen sichern"}]
	elif step.id == "i08_report":
		options = [{"id":"i08_report","label":"Decimus nur belegte Spuren melden"}]
	elif step.id == "i10_choice":
		options = [{"id":"i10_defend","label":"Hinausgehen · verteidigen und Menschen retten"},
			{"id":"i10_hide","label":"Bei den Eltern bleiben und sich verstecken"}]
	elif step.id == "i11_forge":
		options = [{"id":"i11_forge","label":"Sextus’ Fluchtweg erreichen"}]
	elif step.id == "i12_father":
		options = [{"id":"i12_father","label":"Beim Vater bleiben und nach Julia sehen"}]
	elif step.id == "i13_morning":
		options = [{"id":"i13_morning","label":"Verluste mit Aurelia erfassen"}]
	elif step.id == "i14_oath":
		options = [{"id":"i14_oath","label":"Erinnerungsstück nehmen und den Schwur sprechen"}]
	elif step.has("seconds"):
		if data.village.childhood.active_work == "":
			options[0].id = "begin_" + str(step.id)
			options[0].label = str(step.label) + " · beginnen"
		else:
			options[0].label = str(step.label) + " · abschließen (%d/%d)" % [int(data.village.childhood.work_seconds),int(step.seconds)]
	var reason := _action_reason(data, step)
	if reason.is_empty() and step.has("seconds") and data.village.childhood.active_work != "" and float(data.village.childhood.work_seconds) + 0.000001 < float(step.seconds):
		reason = "Bleibe an dieser Station, bis die begonnene Arbeitsfolge fertig ist."
	for option: Dictionary in options:
		result.append({"label":option.label,"command":"village_childhood_action","payload":{"action_id":option.id},"enabled":reason.is_empty(),"reason":reason})
	return result


static func _action_reason(data: Dictionary, step: Dictionary) -> String:
	if data.get("village",{}).get("raid",{}).get("active",false) or data.get("encounter",{}).get("active",false):
		return "Während unmittelbarer Gefahr ruhen diese Alltagsaufgaben."
	if step.has("npc"):
		if not _available(data, step.npc):
			return "Diese Person ist derzeit nicht im Dorf verfügbar."
		if not _relation(data, step.npc).get("met", false):
			return "Lerne diese Person zuerst im Gespräch kennen."
	if _distance(data, _target(data, step)) > (NPC_RANGE if step.has("npc") else POINT_RANGE):
		return "Gehe selbst zum angegebenen Menschen oder Arbeitsplatz."
	if step.has("seconds") and step.id.begins_with("forge_") and not _available(data,"sextus"):
		return "Die heiße Arbeit findet nur unter Sextus’ Aufsicht statt."
	return ""


static func _target(data: Dictionary, step: Dictionary) -> Vector2:
	if str(step.get("point", "")) == "market_stall":
		return I03.marcus_stall(i03_ctx(data))
	if step.has("npc"):
		return _npc_position(data, step.npc)
	return POINTS[step.point]


static func _villager_positions(data: Dictionary) -> Dictionary:
	var result := {}
	for id: String in ["cassia", "aelia"]:
		result[id] = _npc_position(data, id)
	return result


## completed[] size at which Julia's order is bought and still carried: the
## moment Marcus and the boy part at the stall.
static func _i03_farewell_index() -> int:
	return _step_index("deliver_food")


static func _i04_index() -> int:
	return _step_index("apprentice_permission")


## Context of the I-04 workshop visit: the completed[] size at which it is
## open, where Sextus and Fabius really are, and the two work places.
static func i04_ctx(data: Dictionary) -> Dictionary:
	return {"index":_i04_index(), "trial_index":_step_index("smith_trial"),
		"sextus":_npc_position(data, "sextus"), "sextus_here":_available(data, "sextus"),
		"fabius":_npc_position(data, "fabius"), "fabius_here":_available(data, "fabius"),
		"bundle":POINTS.quench, "hearth":POINTS.bellows}


static func i04_reason(data: Dictionary, action: String) -> String:
	return I04.reason(data, action, i04_ctx(data))


## Context of the I-03 errand: where Cassia really stands and trades (her
## stall is in front of her) and whether she is there at all.
static func i03_ctx(data: Dictionary) -> Dictionary:
	return {"farewell_index":_i03_farewell_index(), "cassia":_npc_position(data, "cassia"), "cassia_here":_available(data, "cassia")}


static func i03_reason(data: Dictionary, action: String) -> String:
	return I03.reason(data, action, i03_ctx(data))


static func i01_reason(data: Dictionary, action: String) -> String:
	return _i01_reason(data, action)


static func _i01_reason(data: Dictionary, action: String) -> String:
	return I01.reason(data, action, _villager_positions(data))


static func _npc_position(data: Dictionary, id: String) -> Vector2:
	var point: Variant = actor_override(data,id)
	if typeof(point) == TYPE_VECTOR2:
		return point
	if EXTRA_NPCS.has(id):
		return POINTS[EXTRA_NPCS[id].point]
	return NEIGHBORS[id].position


static func _relation(data: Dictionary, id: String) -> Dictionary:
	if EXTRA_NPCS.has(id):
		return data.get("village",{}).get("childhood",{}).get("relationships",{}).get(id,{})
	return data.get("village",{}).get("social",{}).get("npcs",{}).get(id,{})


static func _person(data: Dictionary, id: String) -> Dictionary:
	for person: Dictionary in data.get("village",{}).get("economy",{}).get("people",[]):
		if person.get("id","") == id:
			return person
	return {}


static func _available(data: Dictionary, id: String) -> bool:
	if id == "decimus":
		return true
	var person := _person(data,id)
	return not person.is_empty() and person.get("alive",false) and not data.village.get("militia",[]).has(id)


static func _distance(data: Dictionary, point: Vector2) -> float:
	var position: Array = data.player.position
	return Vector2(float(position[0]),float(position[2])).distance_to(point)


static func _gain(data: Dictionary, attribute: String, amount: int) -> void:
	if not data.get("village", {}).get("attributes", {}).has(attribute):
		return
	data.village.attributes[attribute] = mini(10000, int(data.village.attributes[attribute]) + amount)


static func _gain_trust(data: Dictionary, id: String, amount: int) -> void:
	var relation := _relation(data,id)
	if not relation.is_empty() and relation.met:
		relation.trust = mini(100,int(relation.trust)+amount)


static func _restore_guard(data: Dictionary) -> void:
	var absence: Dictionary = data.village.childhood.guard_absence
	var guard := _person(data,"severus")
	guard.health = maxi(50,int(absence.previous_health))
	var duty: String = absence.previous_assignment
	var occupied := 0
	for person: Dictionary in data.village.economy.people:
		if person.id != "severus" and person.assignment == duty:
			occupied += 1
	guard.assignment = duty if duty == "idle" or occupied < int(WORKPLACE_CAPACITY[duty]) else "idle"
	guard.previous_assignment = "idle"
	absence.active = false


static func _idle_text(id: String) -> String:
	if NEIGHBORS.has(id):
		return NEIGHBORS[id].text
	return {"julia":"»Hier ist dein Zuhause. Erzähle mir, was du heute vorhast, und komm mit deinen Fragen wieder.«",
		"silvanus":"»Du musst noch kein Soldat und kein Verwalter sein. Lerne die Menschen kennen und führe deine Zusagen selbst zu Ende.«",
		"sextus":"»Eine Schmiede ist ein Arbeitsplatz, keine Abkürzung zum Heldentum. Erst zuhören, dann gemeinsam üben und die Arbeit ordentlich übergeben.«"}.get(id, "")


static func _record(data: Dictionary, id: String, message: String, event_id := "") -> void:
	var history: Dictionary = data.village.history
	history.mode = "fictional_branch"
	history.player_changes.append("childhood_"+id)
	if history.player_changes.size() > 128:
		history.player_changes.pop_front()
	history.events.append({"seconds":data.village.social.seconds,"kind":"childhood_action" if event_id.is_empty() else event_id,"text":message,"provenance":"fictional_playable_event"})
	if history.events.size() > 64:
		history.events.pop_front()


static func _keys(value: Variant, keys: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value,minimum,maximum) and float(value) == floorf(float(value))


static func _ok(message: String) -> Dictionary:
	return {"ok":true,"message":message}


static func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
