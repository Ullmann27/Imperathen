extends RefCounted
## Bounded, offline decisions for the existing residents. Intent is saved; physical
## movement stays in the world and is observed back here, never invented by a clock.
## These needs do not grant goods, quest progress, money, health or combat damage.

const Layout = preload("res://scripts/world/village/village_layout.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const SocialMemory = preload("res://scripts/domain/npc_social_memory.gd")
const VERSION := 1
const STEP := 0.5
const PLAYER_CENTER_HEIGHT := 0.9
const ACTIVITIES := ["work", "patrol", "explore", "socialize", "rest", "weather_pause", "greet", "yield", "space", "flee", "alert", "assist", "absent"]
const REASONS := ["daily_work", "watch", "curiosity", "company", "shared_interest", "familiar_neighbor", "tired", "injured", "rain", "familiar_face", "friendly", "distrust", "personal_space", "danger", "alarm", "help_injured", "unavailable"]
const INTEREST_LABELS := {
	"craft":"Handwerk und gute Werkzeuge", "trade":"Handel und verlässliche Kunden",
	"community":"Nachbarn und Neuigkeiten", "family":"Familie und Haushalt",
	"nature":"Felder, Tiere und Jahreszeiten", "security":"Sichere Wege und Wachdienst",
	"learning":"Neues lernen und die Umgebung erkunden", "care":"Menschen versorgen"
}
const ACTIVITY_LABELS := {
	"work":"Arbeitet", "patrol":"Hält auf dem Weg Wache",
	"explore":"Sieht sich in der Nachbarschaft um", "socialize":"Sucht Gesellschaft",
	"rest":"Legt eine Pause ein", "weather_pause":"Unterbricht die Arbeit im Regen",
	"greet":"Wendet sich dir zu", "yield":"Macht auf dem Weg Platz",
	"space":"Bittet um mehr Abstand", "flee":"Weicht der Gefahr aus",
	"alert":"Beobachtet die Gefahr", "assist":"Hält Hilfe für Verletzte bereit",
	"absent":"Ist nicht im zivilen Dorfleben verfügbar"
}
const EXPLANATIONS := {
	"daily_work":"Die eigene Aufgabe hat gerade Vorrang.", "watch":"Die Sicherheit des Weges hat gerade Vorrang.",
	"curiosity":"Neuigkeiten aus der Nachbarschaft wecken Interesse.", "company":"Nach der Arbeit fehlt Gesellschaft.",
	"shared_interest":"Ein Nachbar mit ähnlichen Interessen ist in der Nähe.", "tired":"Die bisherige Arbeit macht eine Pause nötig.",
	"familiar_neighbor":"Gemeinsame Gespräche machen diesen Nachbarn vertraut.",
	"injured":"Die Verletzung lässt gerade keine Arbeit zu.", "rain":"Die nasse Witterung unterbricht die Tätigkeit draußen.",
	"familiar_face":"Eure bisherigen Begegnungen bleiben in Erinnerung.", "friendly":"Deine Nähe bietet Gelegenheit für einen kurzen Gruß.",
	"distrust":"Eure bisherigen Begegnungen verlangen Vorsicht.", "personal_space":"Du stehst sehr nahe im persönlichen Bereich.",
	"danger":"Ein lebender Angreifer ist in der Nähe.", "alarm":"Der Alarm verlangt Aufmerksamkeit.",
	"help_injured":"Beim Überfall werden Verletzte versorgt.", "unavailable":"Tod oder Truppendienst nimmt diese Person aus dem zivilen Alltag."
}
const GUARDS := ["aulus", "lucius", "sergius", "severus", "valeria"]
const CARERS := ["aurelia", "priscilla"]
const SPECIAL_INTERESTS := {"julia":"family", "silvanus":"craft", "sextus":"craft", "marcus":"learning", "decimus":"community", "aelia":"craft", "varro":"nature", "aurelia":"care", "priscilla":"care", "cassia":"trade", "livia":"trade", "severus":"security", "valeria":"security"}
static var _roster_cache: Dictionary = {}
static var _profile_cache: Dictionary = {}


static func enabled(data: Dictionary) -> bool:
	return typeof(data.get("village")) == TYPE_DICTIONARY and typeof(data.village.get("behavior")) == TYPE_DICTIONARY


static func roster() -> Dictionary:
	if not _roster_cache.is_empty():
		return _roster_cache
	var result := {}
	for item: Dictionary in Layout.RESIDENTS:
		result[item.id] = {"name":item.name, "occupation":item.occupation, "ambient":true, "mobile":not item.route.is_empty()}
	for item: Dictionary in Economy.PEOPLE:
		result[item.id] = {"name":item.name, "occupation":item.profession, "ambient":false, "mobile":false}
	result.decimus = {"name":"Decimus", "occupation":"Dorfverwalter", "ambient":false, "mobile":false}
	result.marcus = {"name":"Marcus", "occupation":"Dein Jugendfreund", "ambient":false, "mobile":false}
	result.make_read_only()
	_roster_cache = result
	return _roster_cache


static func profile(id: String) -> Dictionary:
	if _profile_cache.has(id):
		return _profile_cache[id]
	var hash := _seed(id)
	var interest := str(SPECIAL_INTERESTS.get(id, ""))
	var catalog := roster()
	if not catalog.has(id):
		return {}
	var job: String = catalog[id].occupation.to_lower()
	if interest.is_empty():
		if id in GUARDS:
			interest = "security"
		elif "händler" in job or "händlerin" in job or "verkäufer" in job or "wagen" in job:
			interest = "trade"
		elif "feld" in job or "hirte" in job or "bäuer" in job or "holzf" in job:
			interest = "nature"
		elif "bote" in job or "schreiber" in job:
			interest = "community"
		else:
			interest = "craft"
	var result := {"interest":interest, "diligence":0.35+float(hash%51)/100.0,
		"sociability":0.25+float((hash/53)%66)/100.0,
		"caution":0.25+float((hash/97)%66)/100.0,
		"curiosity":0.25+float((hash/193)%66)/100.0,
		"guard":id in GUARDS, "carer":id in CARERS,
		"ambient":catalog[id].ambient, "mobile":catalog[id].mobile}
	result.make_read_only()
	_profile_cache[id] = result
	return result


static func start(data: Dictionary) -> void:
	if not data.get("village", {}).get("enabled", false) or enabled(data):
		return
	var now := float(data.get("world_seconds", 0.0))
	var people := {}
	var catalog := roster()
	for id: String in catalog:
		var hash := _seed(id)
		var point := _initial_position(data, id)
		var guard_duty: bool = id in GUARDS and str(_economic_person(data,id).get("assignment","idle")) in ["idle","watchpost"]
		people[id] = {"fatigue":8.0+float(hash%25), "social_need":22.0+float((hash/7)%48), "stress":0.0,
			"activity":"patrol" if guard_duty else "work", "reason":"watch" if guard_duty else "daily_work",
			"since":now, "next_decision":now, "last_greet":-1000.0, "last_trust":_trust(data,id), "partner":"",
			"position":[point.x, point.y, point.z], "route_distance":0.0, "route_direction":1, "observed":false, "memories":[]}
	data.village.behavior = {"version":VERSION, "seconds":now, "accumulator":0.0, "people":people,"social":SocialMemory.initial_state()}
	_decide_all(data, 0.0)


## Retain people, observations' last positions and dated memories. Decisions
## resume on the new simulation clock without replaying years of local ticks.
static func resume_after_interlude(data: Dictionary) -> void:
	if not enabled(data):
		return
	var behavior: Dictionary = data.village.behavior
	behavior.seconds = float(data.world_seconds) - float(behavior.accumulator)
	for person: Dictionary in behavior.people.values():
		person.since = behavior.seconds
		person.next_decision = behavior.seconds
		person.observed = false


static func ensure_social(data: Dictionary) -> void:
	# Call only after validating a legacy save. A present invalid record is never
	# overwritten, and migration invents no past relationships or conversation time.
	if enabled(data) and not data.village.behavior.has("social"):
		data.village.behavior.social = SocialMemory.initial_state()


static func observe(data: Dictionary, observations: Variant, complete_snapshot := false) -> void:
	if not enabled(data) or typeof(observations) != TYPE_DICTIONARY:
		return
	for id: String in data.village.behavior.people:
		var person: Dictionary = data.village.behavior.people[id]
		# A full world snapshot reports currently visible bodies, not a permanent
		# record of everybody ever seen. Keep the last valid position for saves,
		# but do not use a hidden or invalid body for social/proximity decisions.
		if complete_snapshot:
			person.observed = false
		if not observations.has(id) or typeof(observations[id]) != TYPE_DICTIONARY:
			continue
		var observation: Dictionary = observations[id]
		if not _position(observation.get("position")) or not _number(observation.get("route_distance",0.0), 0.0, 1000.0):
			continue
		person.position = observation.position.duplicate()
		person.route_distance = float(observation.get("route_distance",0.0))
		var direction: Variant = observation.get("route_direction",1)
		if _number(direction,-1.0,1.0) and float(direction) in [-1.0,1.0]:
			person.route_direction = int(direction)
		person.observed = true


static func advance(data: Dictionary, delta: float, sight_check: Callable = Callable()) -> void:
	if not enabled(data) or not is_finite(delta) or delta <= 0.0:
		return
	ensure_social(data)
	var behavior: Dictionary = data.village.behavior
	behavior.accumulator = float(behavior.accumulator)+delta
	while float(behavior.accumulator)+0.00000001 >= STEP:
		behavior.accumulator = maxf(0.0, float(behavior.accumulator)-STEP)
		behavior.seconds = float(behavior.seconds)+STEP
		_decide_all(data, STEP, sight_check)


static func _decide_all(data: Dictionary, delta: float, sight_check: Callable = Callable()) -> void:
	var behavior: Dictionary = data.village.behavior
	var now := float(behavior.seconds)
	var player: Array = data.get("player",{}).get("position",[0.0,0.0,0.0])
	# Saved player position is the capsule center, resident positions are feet.
	# The world sight adapter receives feet and applies its own eye-height offset.
	var player_ground: Array = player.duplicate()
	player_ground[1] = float(player_ground[1])-PLAYER_CENTER_HEIGHT
	var player_at := Vector2(float(player[0]),float(player[2]))
	var raid: Dictionary = data.village.get("raid",{})
	var rain := int(data.get("strategy",{}).get("turn",0))%4 == 2
	var catalog := roster()
	# Decide from one snapshot. Iteration order does not change who appears to
	# be a conversational partner in the same tick.
	var previous := _perception_people(behavior.people)
	var available := _availability(data)
	var visibility_cache := {}
	SocialMemory.advance(behavior.social,previous,available,now,delta,sight_check,visibility_cache)
	for id: String in behavior.people:
		var person: Dictionary = behavior.people[id]
		var perceived: Dictionary = previous[id]
		var traits := profile(id)
		var actual := _economic_person(data,id)
		# Guard experience is a trait, not a permanent workplace assignment.
		# A reassigned guard must perform the actual civilian job as ordinary work.
		var guard_duty: bool = traits.guard and str(actual.get("assignment","idle")) in ["idle","watchpost"]
		var trust := _trust(data,id)
		if trust != int(person.last_trust):
			_remember(person, "trust_gained" if trust > int(person.last_trust) else "trust_lost", now)
			person.last_trust = trust
		if not actual.is_empty() and (not actual.alive or data.village.get("militia",[]).has(id)):
			_choose(person,"absent","unavailable",now)
			continue
		var old_activity: String = person.activity
		if old_activity in ["work","patrol","explore"]:
			person.fatigue = minf(100.0,float(person.fatigue)+delta*(0.10 if old_activity == "work" else 0.075))
		else:
			person.fatigue = maxf(0.0,float(person.fatigue)-delta*(0.75 if old_activity == "rest" else 0.08))
		person.social_need = clampf(float(person.social_need)+delta*(-0.9 if old_activity in ["socialize","greet"] and _has_company(id,perceived,previous,player_at,available,sight_check,visibility_cache,float(player_ground[1])) else 0.075),0.0,100.0)
		person.stress = maxf(0.0,float(person.stress)-delta*0.45)
		var at := Vector2(float(perceived.position[0]),float(perceived.position[2]))
		var player_visible: bool = perceived.observed and at.distance_to(player_at) <= 3.5 and absf(float(perceived.position[1])-float(player_ground[1])) <= SocialMemory.CONVERSATION_HEIGHT and SocialMemory.clear_sight(perceived.position,player_ground,sight_check,visibility_cache)
		var danger_distance := 100000.0
		if person.observed and raid.get("active",false):
			danger_distance = _nearest_visible_danger(perceived,raid,sight_check,visibility_cache)
		var urgent_activity := ""
		var urgent_reason := ""
		if danger_distance < 24.0:
			person.stress = minf(100.0,float(person.stress)+delta*5.0)
			# Quest and service anchors cannot silently relocate. They turn toward
			# danger and suspend work; only mobile bodies claim to be fleeing.
			urgent_activity = "assist" if traits.carer and danger_distance > 9.0 and raid.get("rescue_available",false) else "alert" if traits.guard or not traits.mobile else "flee"
			urgent_reason = "help_injured" if urgent_activity == "assist" else "danger"
		elif raid.get("alarm",false) and raid.get("status","") in ["warning","active"]:
			urgent_activity = "alert"
			urgent_reason = "alarm"
		elif not actual.is_empty() and int(actual.get("health",100)) <= 30:
			urgent_activity = "rest"
			urgent_reason = "injured"
		elif player_visible and at.distance_to(player_at) < 1.1:
			urgent_activity = "yield" if catalog[id].mobile else "space"
			urgent_reason = "personal_space"
		if not urgent_activity.is_empty():
			if urgent_reason == "danger" and person.reason != "danger":
				_remember(person,"danger_seen",now)
			_choose(person,urgent_activity,urgent_reason,now)
			person.next_decision = now+STEP
			continue
		# Immediate danger and personal-space reactions end when their cause ends.
		var was_urgent: bool = old_activity in ["yield","space","flee","alert","assist","absent"] or person.reason == "injured"
		if not was_urgent and now+0.000001 < float(person.next_decision):
			continue
		person.next_decision = now+3.0+float(_seed(id)%9)*0.25
		person.partner = ""
		if player_visible and at.distance_to(player_at) < 3.0 and now-float(person.last_greet) > 25.0 and trust >= 0 and (trust > 0 or float(traits.sociability) >= 0.55):
			_choose(person,"greet","familiar_face" if trust > 0 else "friendly",now)
			person.partner = "player"
			person.last_greet = now
			person.next_decision = now+2.5
			continue
		if rain and not guard_duty and (catalog[id].ambient or str(actual.get("assignment","idle")) in ["farm","woodcamp","quarry"]):
			_choose(person,"weather_pause","rain",now)
			continue
		var partner := _nearby_partner(id,perceived,traits,previous,behavior.social,available,sight_check,visibility_cache)
		var scores := {
			"work":48.0+float(traits.diligence)*25.0-float(person.fatigue)*0.35,
			"socialize":float(person.social_need)*0.82+float(traits.sociability)*16.0+(8.0 if not partner.is_empty() else 0.0),
			"rest":float(person.fatigue)*1.05+8.0,
			"explore":24.0+float(traits.curiosity)*25.0-float(person.fatigue)*0.2}
		if guard_duty:
			scores.work += 18.0
		if not catalog[id].ambient and str(actual.get("assignment","idle")) != "idle":
			scores.work += 12.0
		if not traits.mobile:
			scores.explore = -1.0
		var selected := "work"
		for activity: String in scores:
			if float(scores[activity]) > float(scores[selected]):
				selected = activity
		# A small hysteresis prevents work/rest oscillation near equal utilities.
		if scores.has(old_activity) and float(scores[selected]) < float(scores[old_activity])+7.0 and now-float(person.since) < 20.0:
			selected = old_activity
		var reason: String = {"work":"daily_work","socialize":"company","rest":"tired","explore":"curiosity"}[selected]
		if selected == "work" and guard_duty:
			selected = "patrol"
			reason = "watch"
		if selected == "socialize":
			person.partner = partner
			if not partner.is_empty() and SocialMemory.preference(behavior.social,id,partner) > 0.0:
				reason = "familiar_neighbor"
			elif not partner.is_empty() and profile(partner).interest == traits.interest:
				reason = "shared_interest"
		_choose(person,selected,reason,now)


static func _nearby_partner(id: String, person: Dictionary, traits: Dictionary, people: Dictionary, social: Dictionary = {}, available: Dictionary = {}, sight_check: Callable = Callable(), visibility_cache: Variant = null) -> String:
	if not person.observed:
		return ""
	var at := Vector2(float(person.position[0]),float(person.position[2]))
	var best := ""
	var best_score := -1000.0
	for other_id: String in people:
		if other_id == id or not available.get(other_id,true):
			continue
		var other: Dictionary = people[other_id]
		if not other.observed or other.activity in ["absent","flee","alert","assist"]:
			continue
		var distance := at.distance_to(Vector2(float(other.position[0]),float(other.position[2])))
		if distance > 3.5 or absf(float(person.position[1])-float(other.position[1])) > SocialMemory.CONVERSATION_HEIGHT:
			continue
		if not SocialMemory.clear_sight(person.position,other.position,sight_check,visibility_cache):
			continue
		var score := 4.0-distance+(2.0 if profile(other_id).interest == traits.interest else 0.0)+SocialMemory.preference(social,id,other_id)
		if score > best_score or is_equal_approx(score,best_score) and other_id < best:
			best = other_id
			best_score = score
	return best


static func _has_company(id: String, person: Dictionary, people: Dictionary, player: Vector2, available: Dictionary = {}, sight_check: Callable = Callable(), visibility_cache: Variant = null, player_height := 0.0) -> bool:
	var at := Vector2(float(person.position[0]),float(person.position[2]))
	if person.partner == "player":
		return person.observed and at.distance_to(player) <= 3.5 and absf(float(person.position[1])-player_height) <= SocialMemory.CONVERSATION_HEIGHT and SocialMemory.clear_sight(person.position,[player.x,player_height,player.y],sight_check,visibility_cache)
	if not people.has(person.partner) or not available.get(id,true) or not available.get(person.partner,true):
		return false
	var partner: Dictionary = people[person.partner]
	# Mere proximity, or a neighbor busy talking to somebody else, does not
	# satisfy this resident's social need. Both must choose the encounter and
	# have arrived within the same bounded conversational distance.
	return partner.activity == "socialize" and partner.partner == id and SocialMemory.close_conversation(person,partner,sight_check,visibility_cache)


static func _nearest_visible_danger(person: Dictionary, raid: Dictionary, sight_check: Callable, visibility_cache: Dictionary) -> float:
	var at := Vector2(float(person.position[0]),float(person.position[2]))
	var candidates: Array[Dictionary] = []
	for enemy: Dictionary in raid.get("enemies",[]):
		if int(enemy.get("health",0)) <= 0:
			continue
		var distance := at.distance_to(Vector2(float(enemy.x),float(enemy.z)))
		if distance < 24.0:
			candidates.append({"distance":distance,"position":[float(enemy.x),float(enemy.get("y",0.0)),float(enemy.z)],"id":str(enemy.get("id",""))})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left.distance) < float(right.distance) or (left.distance == right.distance and left.id < right.id))
	for candidate: Dictionary in candidates:
		if SocialMemory.clear_sight(person.position,candidate.position,sight_check,visibility_cache):
			return float(candidate.distance)
	return 100000.0


static func _choose(person: Dictionary, activity: String, reason: String, now: float) -> void:
	if person.activity != activity or person.reason != reason:
		person.since = now
	person.activity = activity
	person.reason = reason
	if activity not in ["socialize","greet"]:
		person.partner = ""


static func _remember(person: Dictionary, kind: String, now: float) -> void:
	if not person.memories.is_empty() and person.memories.back().kind == kind and now-float(person.memories.back().at) < 20.0:
		return
	person.memories.append({"kind":kind,"at":now})
	while person.memories.size() > 4:
		person.memories.pop_front()


static func view(data: Dictionary, id: String) -> Dictionary:
	if not enabled(data) or not data.village.behavior.people.has(id):
		return {}
	var person: Dictionary = data.village.behavior.people[id]
	var traits := profile(id)
	var mood := "calm"
	if float(person.stress) >= 30.0 or person.activity in ["alert","flee","space"]:
		mood = "tense"
	elif float(person.fatigue) >= 65.0:
		mood = "tired"
	elif _trust(data,id) < 0:
		mood = "wary"
	elif person.activity in ["greet","socialize"] and not person.partner.is_empty():
		mood = "content"
	var mood_label: String = {"calm":"ruhig","tense":"angespannt","tired":"müde","wary":"zurückhaltend","content":"zufrieden"}[mood]
	return {"activity":person.activity,"activity_label":ACTIVITY_LABELS[person.activity],"reason":EXPLANATIONS[person.reason],
		"interest":traits.interest,"interest_label":INTEREST_LABELS[traits.interest],"temperament":"gesellig" if traits.sociability >= 0.6 else "bedachtsam",
		"mood":mood,"mood_label":mood_label,"greeting":_greeting(data,id,person),"decision_since":person.since,
		"fatigue":person.fatigue,"social_need":person.social_need,"stress":person.stress,"partner":person.partner,
		"position":person.position.duplicate(),"route_distance":person.route_distance,"observed":person.observed,
		"relationship":SocialMemory.relationship(data.village.behavior.get("social",{}),id,str(person.partner))}


static func social_neighbors(data: Dictionary, id: String) -> Array:
	# Panel-only query; do not scan pair history in every rendered actor's view.
	var result: Array = []
	var catalog := roster()
	if not enabled(data) or not catalog.has(id):
		return result
	var social: Dictionary = data.village.behavior.get("social",{})
	for key: String in social.get("pairs",{}):
		var pair := key.split(":")
		if id not in pair:
			continue
		var other_id: String = pair[1] if pair[0] == id else pair[0]
		var relationship := SocialMemory.relationship(social,id,other_id)
		if relationship.status not in ["familiar","friend"]:
			continue
		result.append({"id":other_id,"name":Childhood.display_name(data,other_id,str(catalog[other_id].name)),
			"status":relationship.status,"label":relationship.label,"encounters":relationship.encounters,
			"shared_seconds":relationship.shared_seconds})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority := 0 if left.status == "friend" else 1
		var right_priority := 0 if right.status == "friend" else 1
		return left_priority < right_priority or (left_priority == right_priority and left.id < right.id))
	return result


static func _greeting(data: Dictionary, id: String, person: Dictionary) -> String:
	match str(person.activity):
		"flee": return "»Zurück! Dort sind Bewaffnete. Ich bringe mich aus ihrer Nähe.«"
		"alert": return "»Bleib aufmerksam. Ich behalte den Weg im Auge.«"
		"assist": return "»Ich halte Verbände bereit. Bring die Verletzten aus der Gefahrenzone.«"
		"weather_pause": return "»Bei diesem Regen lasse ich die Arbeit draußen kurz liegen.«"
		"yield", "space": return "»Einen Schritt zurück, bitte. Lass mir etwas Platz.«"
		"rest": return "»Ich brauche einen Augenblick Ruhe. Danach geht es weiter.«" if person.reason != "injured" else "»Mit dieser Verletzung muss ich mich erst erholen.«"
		"greet": return "»Gut, dich zu sehen. Ich erinnere mich an unsere Begegnung.«" if person.reason == "familiar_face" else "»Guten Tag. Wie geht es dir heute?«"
		"socialize": return "»Für ein Gespräch nehme ich mir gern einen Moment.«" if not person.partner.is_empty() else "»Ich sehe mich nach den Nachbarn um. Vielleicht gibt es Neuigkeiten.«"
		"explore": return "»Ich sehe nach, was sich an unserem Weg verändert hat.«"
		"patrol": return "»Ich halte den Weg frei und schaue nach Reisenden und Nachbarn.«"
		"absent": return ""
	if _trust(data,id) < 0:
		return "»Ich habe deine letzte Entscheidung nicht vergessen. Was möchtest du besprechen?«"
	return "»Ich bin gerade bei meiner Arbeit. Für ein paar Worte reicht die Zeit.«"


static func validate(data: Dictionary) -> String:
	if not data.get("village",{}).has("behavior"):
		return ""
	var value: Variant = data.village.behavior
	if (not _keys(value,["version","seconds","accumulator","people"]) and not _keys(value,["version","seconds","accumulator","people","social"])) or value.version != VERSION or not _number(value.seconds,0.0,1000000000000.0) or not _number(value.accumulator,0.0,STEP):
		return "Ungültiger Bewohnerentscheidungsvertrag."
	if not _keys(value.people,roster().keys()):
		return "Bewohnerentscheidungen passen nicht zur vorhandenen Bevölkerung."
	if absf(float(value.seconds)+float(value.accumulator)-float(data.get("world_seconds",0.0))) > 0.001:
		return "Bewohner und Spielwelt verwenden verschiedene Zeitstände."
	if value.has("social"):
		var social_error := SocialMemory.validate(value.social,roster().keys(),float(value.seconds))
		if not social_error.is_empty():
			return social_error
	for id: String in value.people:
		var person: Variant = value.people[id]
		if not _keys(person,["fatigue","social_need","stress","activity","reason","since","next_decision","last_greet","last_trust","partner","position","route_distance","route_direction","observed","memories"]):
			return "Unvollständige Bewohnerentscheidung: "+id
		for need: String in ["fatigue","social_need","stress"]:
			if not _number(person[need],0.0,100.0):
				return "Ungültiges Bedürfnis: "+id
		if typeof(person.activity) != TYPE_STRING or person.activity not in ACTIVITIES or typeof(person.reason) != TYPE_STRING or person.reason not in REASONS:
			return "Unbekannte Bewohnerabsicht: "+id
		if not _number(person.since,0.0,float(value.seconds)+0.001) or not _number(person.next_decision,0.0,float(value.seconds)+10.0) or not _number(person.last_greet,-1000.0,float(value.seconds)+0.001):
			return "Ungültige Bewohnerzeit: "+id
		if not _number(person.last_trust,-100.0,100.0) or float(person.last_trust) != floorf(float(person.last_trust)):
			return "Ungültige Beziehungserinnerung: "+id
		if typeof(person.partner) != TYPE_STRING or person.partner not in ["","player"] and not value.people.has(person.partner):
			return "Unbekannter Gesprächspartner: "+id
		if not _position(person.position) or not _number(person.route_distance,0.0,1000.0) or not _number(person.route_direction,-1.0,1.0) or float(person.route_direction) not in [-1.0,1.0] or typeof(person.observed) != TYPE_BOOL:
			return "Ungültige beobachtete Bewohnerposition: "+id
		if typeof(person.memories) != TYPE_ARRAY or person.memories.size() > 4:
			return "Ungültige Bewohnererinnerungen: "+id
		for memory: Variant in person.memories:
			if not _keys(memory,["kind","at"]) or memory.kind not in ["danger_seen","trust_gained","trust_lost"] or not _number(memory.at,0.0,float(value.seconds)+0.001):
				return "Ungültige Bewohnererinnerung: "+id
	return ""


static func _initial_position(data: Dictionary, id: String) -> Vector3:
	var resident := Layout.resident(id)
	if not resident.is_empty():
		return resident.at
	if id == "marcus":
		return Vector3(-3.0,0.0,4.0)
	var at := Life.actor_position(data,id)
	return Vector3(at.x,0.0,at.y)


static func _economic_person(data: Dictionary, id: String) -> Dictionary:
	for person: Dictionary in data.get("village",{}).get("economy",{}).get("people",[]):
		if person.id == id:
			return person
	return {}


static func _availability(data: Dictionary) -> Dictionary:
	var result := {}
	for id: String in roster():
		result[id] = not data.village.get("militia",[]).has(id)
	for person: Dictionary in data.get("village",{}).get("economy",{}).get("people",[]):
		if result.has(person.id):
			result[person.id] = result[person.id] and bool(person.alive) and int(person.get("health",100)) > 30
	return result


static func _perception_people(people: Dictionary) -> Dictionary:
	var result: Dictionary = people.duplicate(true)
	# The established companion save/restore contract stores Marcus at center
	# height. Only this transient perception snapshot uses his feet, like every
	# other resident; never change the stored position or restoration contract.
	if result.has("marcus"):
		result.marcus.position[1] = float(result.marcus.position[1])-PLAYER_CENTER_HEIGHT
	return result


static func _trust(data: Dictionary, id: String) -> int:
	if id == "marcus":
		return int(data.get("companion",{}).get("trust",0))
	return int(Life.relationship(data,id).get("trust",0))


static func _seed(id: String) -> int:
	var result := 17
	for character in id.to_utf8_buffer():
		result = (result*31+int(character))%2147483647
	return result


static func _keys(value: Variant, keys: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _position(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY and value.size() == 3 and _number(value[0],-100000.0,100000.0) and _number(value[1],-1000.0,1000.0) and _number(value[2],-100000.0,100000.0)
