extends RefCounted
## Seasonal board-game campaign. Its regional mandate is independent of the protagonist's rank.

const Atlas := preload("res://scripts/strategy/atlas_data.gd")
const HOMES := ["italia","germania","han","wa","vistula"]
const SEASONS := ["Frühling", "Sommer", "Herbst", "Winter"]
const MANDATES := ["Ortsmandat", "Provinzmandat", "Reichsmandat"]
const SEASON_ACTIONS := 2
# These are fictional local stories for this playthrough. Each includes an immediate
# mechanical result and a distinct later scene recalling the player's choice.
const ORIGIN_EVENTS := {
	"italia":{"title":"Die Mühle am Ufer", "intro":"Nach Regen wartet das Dorf auf Mehl. Mühlenpächterin Livia bittet um eine Entscheidung.",
		"choices":[["muehltag","Gemeinsam mahlen","grain",4,"Livia öffnet den Mühlhof. Familien bringen erstmals ihre eigenen kleinen Säcke zum Mahltag.",-2],
		["faehrwagen","Die Fährleute unterstützen","supply",3,"Am Fährplatz steht nun ein überdachter Wagen. Bei Regen kommen die Mehlsäcke trocken über den Fluss.",2]]},
	"germania":{"title":"Der umgestürzte Baum", "intro":"Ein umgestürzter Stamm unterbricht den Weg zwischen den Höfen. Zwei Nachbarn haben Pläne für das Holz.",
		"choices":[["bohlenweg","Bohlen für den Hofweg sägen","supply",3,"Die Boten bringen nasse Stiefel mit, aber die Wagen erreichen den Hof über deinen Bohlenweg."],
		["speicherwand","Die Speicherwand ausbessern","stores",4,"Die neue Speicherwand hält. Die Familien legen ihr erstes gemeinsam verwahrtes Saatgut hinein."]]},
	"han":{"title":"Die Listen der Kornwache", "intro":"Im fiktiven Dorf bei Luoyang zählt Schreiberin Lin zwei unbeschriftete Lieferungen. Helfer warten am Speicher.",
		"choices":[["lagerbuch","Ein gemeinsames Lagerbuch beginnen","stores",4,"Lin liest die ersten Einträge vor. Die Speicherwache findet jede eingelagerte Lieferung wieder.",-2],
		["korbtraeger","Tragekörbe an die Höfe geben","grain",5,"Die Hofboten bringen ihre Körbe zurück. Beim nächsten Erntetag teilen mehrere Familien die Tragewege.",3]]},
	"wa":{"title":"Wasser für die jungen Felder", "intro":"Im Dorf am Hang hat Regen eine Rinne geöffnet. Die Nachbarn beraten, wohin das Wasser fließen soll.",
		"choices":[["feldrinne","Eine Feldrinne ausheben","grain",4,"Das erste Wasser erreicht das untere Feld. Die Helfer markieren die Rinne mit kleinen Pfählen."],
		["uferlager","Ein Uferlager anlegen","supply",3,"Vom Hang führt ein Trittpfad zum Uferlager. Der erste Transport kann dort seine Ladung trocken umpacken."]]},
	"vistula":{"title":"Am alten Brennplatz", "intro":"Im Dorf im Weichselraum bietet eine Töpferin einen gemeinsamen Brand an. Der trockene Ton reicht für einen Auftrag.",
		"choices":[["vorratstopf","Große Vorratsgefäße brennen","stores",4,"Die Töpferin stellt die letzten gedeckelten Gefäße auf. Die Familien erkennen ihren Vorrat an eingeritzten Zeichen."],
		["reisegefaess","Kleine Reisegefäße formen","supply",4,"Mit den ersten Reisegefäßen kehrt ein Bote zurück. Das kleine Gefäß hat den langen Weg unbeschadet überstanden."]]}
}
const RESOURCE_NAMES := {"grain":"Korn", "stores":"Wintervorrat", "supply":"Reisevorrat"}


static func _empty_story() -> Dictionary:
	return {"choice":"", "turn":-1, "log":[]}


static func _story(data: Dictionary) -> Dictionary:
	return data.get("origin_story", _empty_story())


static func _option(data: Dictionary, id: String) -> Array:
	for option: Array in ORIGIN_EVENTS[data.home].choices:
		if option[0] == id:
			return option
	return []


static func _decision_line(option: Array) -> String:
	var change := "+%d %s" % [option[3], RESOURCE_NAMES[option[2]]]
	if option.size() > 5:
		change += ", %+d Unruhe" % int(option[5])
	return "%s (%s)." % [option[1],change]


static func story_options(data: Dictionary) -> Array:
	var options := []
	if data.turn >= 2 and _story(data).choice == "":
		for option: Array in ORIGIN_EVENTS[data.home].choices:
			options.append({"id":option[0], "label":_decision_line(option)})
	return options


static func _valid_story(data: Dictionary) -> bool:
	if not data.has("origin_story"):
		return true # First world-map build stored the campaign before origin episodes existed.
	var story: Variant = data.origin_story
	if typeof(story) != TYPE_DICTIONARY or story.size() != 3 or not story.has_all(["choice","turn","log"]):
		return false
	if typeof(story.log) != TYPE_ARRAY or not _int(story.turn,-1,data.turn) or typeof(story.choice) != TYPE_STRING:
		return false
	if story.choice == "":
		return story.turn == -1 and story.log.is_empty()
	var option := _option(data,story.choice)
	if option.is_empty() or story.turn < 2:
		return false
	var next_year := (floori(story.turn/4.0) + 1) * 4
	var due: bool = data.turn >= next_year
	if story.log.size() != (2 if due else 1):
		return false
	for i in story.log.size():
		var line: Variant = story.log[i]
		if typeof(line) != TYPE_DICTIONARY or line.size() != 2 or not line.has_all(["turn","text"]):
			return false
		if line.turn != (story.turn if i == 0 else next_year) or line.text != (_decision_line(option) if i == 0 else option[4]):
			return false
	return true


static func new_game(home_id: String = "italia") -> Dictionary:
	if home_id not in HOMES or not Atlas.REGIONS.has(home_id):
		return {}
	return {"schema":2, "turn":0, "home":home_id, "owned":[home_id], "grain":6, "stores":0,
		"supply":0, "actions":SEASON_ACTIONS, "unrest":0, "mandate":0,
		"mission":{"id":1,"target":home_id,"status":"active","misses":0},
		"origin_story":_empty_story(), "wins":0, "failures":0, "history":[], "last_event":"%s erhält den Auftrag, Nahrung für den Winter einzulagern." % Atlas.REGIONS[home_id].name}


static func _int(v: Variant, low: int, high: int) -> bool:
	return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(v) and v == floorf(v) and v >= low and v <= high


static func _linked(a: String, b: String) -> bool:
	return a in Atlas.REGIONS[b].links or b in Atlas.REGIONS[a].links


static func _connected(owned: Array, home_id: String) -> bool:
	if not owned.has(home_id):
		return false
	var reached := [home_id]
	var i := 0
	while i < reached.size():
		for id in owned:
			if id not in reached and _linked(reached[i], id):
				reached.append(id)
		i += 1
	return reached.size() == owned.size()


static func validate(data: Dictionary) -> bool:
	var required := ["schema","turn","home","owned","grain","stores","supply","actions","unrest",
		"mandate","mission","wins","failures","history","last_event"]
	if not _int(data.get("schema"),1,2):
		return false
	if data.schema == 2:
		required.append("origin_story")
	if data.size() != required.size() or not data.has_all(required):
		return false
	if not _int(data.turn,0,1000000) or not _int(data.actions,0,SEASON_ACTIONS):
		return false
	if not _int(data.mandate,0,2) or not _int(data.unrest,0,100) or typeof(data.last_event) != TYPE_STRING:
		return false
	if not _int(data.wins,0,data.turn) or not _int(data.failures,0,data.turn):
		return false
	for key in ["grain","supply","stores"]:
		if not _int(data[key],0,100000000):
			return false
	if typeof(data.owned) != TYPE_ARRAY or data.owned.size() > Atlas.REGIONS.size() or data.owned.is_empty():
		return false
	var seen := {}
	for id in data.owned:
		if typeof(id) != TYPE_STRING or not Atlas.REGIONS.has(id) or seen.has(id):
			return false
		seen[id] = true
	if data.home not in HOMES or not _connected(data.owned, data.home) or not _valid_story(data):
		return false
	var spent := int(data.turn) * SEASON_ACTIONS + SEASON_ACTIONS - int(data.actions)
	if data.owned.size() - 1 + int(data.mandate) > spent:
		return false
	var m: Variant = data.mission
	if typeof(m) != TYPE_DICTIONARY or m.size() != 4 or not m.has_all(["id","target","status","misses"]):
		return false
	if not _int(m.id,1,data.turn + 1) or not _int(m.misses,0,2) or typeof(m.target) != TYPE_STRING or not Atlas.REGIONS.has(m.target):
		return false
	if m.status not in ["active","won","failed"] or ((m.misses == 2) != (m.status == "failed")):
		return false
	if m.status == "active" and not seen.has(m.target):
		return false
	if typeof(data.history) != TYPE_ARRAY or data.history.size() != data.wins + data.failures or data.history.size() > data.turn:
		return false
	var wins := 0
	var last_turn := 0
	for i in data.history.size():
		var entry: Variant = data.history[i]
		if typeof(entry) != TYPE_DICTIONARY or entry.size() != 4 or not entry.has_all(["id","target","status","turn"]):
			return false
		if entry.id != i + 1 or not _int(entry.turn,last_turn + 1,data.turn) or typeof(entry.target) != TYPE_STRING or not Atlas.REGIONS.has(entry.target):
			return false
		if entry.status not in ["won","failed"]:
			return false
		wins += int(entry.status == "won")
		last_turn = int(entry.turn)
	if data.wins != wins or m.id != data.history.size() + int(m.status == "active"):
		return false
	if m.status != "active":
		if data.history.is_empty() or data.history.back().status != m.status or data.history.back().target != m.target:
			return false
	return true


static func _season(turn: int, id: String) -> int:
	return (turn + (2 if Atlas.REGIONS[id].lat < 0 else 0)) % 4


static func _need(data: Dictionary) -> int:
	return 4 + floori((data.owned.size()-1) / 2.0) + int(data.mandate)*2


static func summary(data: Dictionary) -> Dictionary:
	var turn := int(data.turn)
	var mission_region: String = data.mission.target
	var local_season := _season(turn, mission_region)
	var harvest: int = [3,5,8,1][_season(turn, data.home)] + floori((data.owned.size()-1) / 3.0)
	var needed := _need(data)
	var due_local: bool = data.mission.status == "active" and local_season == 3
	var warning := ""
	if int(data.stores) < needed and (due_local or _season(turn, data.home) == 3):
		warning = "Es fehlen %d Vorräte bis zum Saisonwechsel." % (needed - int(data.stores))
		if due_local and data.mission.misses == 1:
			warning += " Ein zweiter Mangel beendet den Auftrag."
	elif int(data.stores) < needed and (_season(turn, data.home) == 2 or (data.mission.status == "active" and local_season == 2)):
		warning = "Vor dem Winter noch %d Vorräte einlagern." % (needed - int(data.stores))
	var title := ""
	var story_text := ""
	if turn >= 2:
		var state := _story(data)
		title = ORIGIN_EVENTS[data.home].title
		story_text = ORIGIN_EVENTS[data.home].intro if state.log.is_empty() else state.log.back().text
	return {"story_title":title,"story_text":story_text, "year":100 + floori(turn / 4.0), "season":SEASONS[turn % 4], "winter_need":needed,
		"harvest_yield":harvest, "warning":warning, "mission_season":SEASONS[local_season],
		"mandate_name":MANDATES[int(data.mandate)]}


static func region_info(data: Dictionary, id: String) -> Dictionary:
	if not Atlas.REGIONS.has(id):
		return {}
	var cost := 0
	for origin in data.owned:
		if not _linked(origin,id):
			continue
		var a: Dictionary = Atlas.REGIONS[origin]
		var b: Dictionary = Atlas.REGIONS[id]
		var longitude := absf(wrapf(float(a.lon)-float(b.lon),-180,180))
		var crossing := longitude > 46 or absf(a.lat-b.lat) > 42
		var route := (5 if crossing else 3) + int(data.mandate)
		if cost == 0 or route < cost:
			cost = route
	return {"owned":id in data.owned,"reachable":cost > 0 and id not in data.owned,
		"cost":cost, "season":SEASONS[_season(int(data.turn),id)]}


static func _finish(data: Dictionary, status: String) -> void:
	data.mission.status = status
	data.history.append({"id":data.mission.id, "target":data.mission.target,
		"status":status, "turn":data.turn})
	if status == "won":
		data.wins += 1
	else:
		data.failures += 1


static func _lose_border(data: Dictionary) -> String:
	for i in range(data.owned.size()-1, -1, -1):
		var id: String = data.owned[i]
		if id == data.home or (data.mission.status == "active" and data.mission.target == id):
			continue
		var remaining: Array = data.owned.duplicate()
		remaining.remove_at(i)
		if _connected(remaining,data.home):
			data.owned = remaining
			return Atlas.REGIONS[id].name
	return ""


static func _advance(data: Dictionary) -> String:
	var calendar := summary(data)
	var home_winter := _season(int(data.turn),data.home) == 3
	var mission_winter: bool = data.mission.status == "active" and calendar.mission_season == "Winter"
	data.turn += 1
	data.actions = SEASON_ACTIONS
	var notes := PackedStringArray()
	if home_winter or mission_winter:
		var needed := int(calendar.winter_need)
		var supplied := mini(data.stores, needed)
		data.stores -= supplied
		if supplied == needed:
			data.unrest = maxi(0, data.unrest - 12)
			notes.append("Winterlieferung vollständig.")
			if mission_winter:
				_finish(data, "won")
				notes.append("Regionalauftrag erfüllt.")
		else:
			data.unrest = mini(100, int(data.unrest) + 5 + data.owned.size() + int(data.mandate)*7)
			if mission_winter:
				data.mission.misses += 1
				if data.mission.misses == 2:
					_finish(data, "failed")
					notes.append("Regionalauftrag nach zwei Wintern ohne ausreichenden Vorrat gescheitert.")
				else:
					notes.append("Ein Winter fehlte. Der Auftrag läuft bis zum nächsten örtlichen Winter weiter.")
			if data.mandate == 0 and data.owned.size() <= 2:
				data.grain += 3
				notes.append("Nachbarhöfe bringen drei Korn zur Erholung.")
			elif data.unrest >= 45:
				var lost := _lose_border(data)
				if lost != "":
					notes.append("%s löst sich wegen Versorgungsmangels vom Mandat." % lost)
				data.supply = maxi(0, int(data.supply)-3)
				notes.append("Die Transporte verlieren bis zu drei Reisevorräte.")
	var story := _story(data)
	if story.choice != "" and story.log.size() == 1 and int(data.turn) % 4 == 0:
		var followup: String = _option(data,story.choice)[4]
		story.log.append({"turn":data.turn, "text":followup})
		notes.append(followup)
	if notes.is_empty():
		notes.append("Neue Saison. Zwei Vorbereitungen sind verfügbar.")
	return " ".join(notes)


static func act(data: Dictionary, command: String, target_id: String = "") -> Dictionary:
	if not validate(data):
		return {"ok":false,"message":"Der Kampagnenstand ist ungültig."}
	var next := data.duplicate(true)
	if next.schema == 1:
		next.origin_story = _empty_story()
		next.schema = 2
	var message := ""
	if command == "story":
		var option := _option(next, target_id)
		if next.turn < 2 or next.origin_story.choice != "" or option.is_empty():
			return {"ok":false,"message":"Diese Entscheidung ist zurzeit nicht verfügbar."}
		message = _decision_line(option)
		next[option[2]] += int(option[3])
		if option.size() > 5:
			next.unrest = clampi(int(next.unrest) + int(option[5]),0,100)
		next.origin_story = {"choice":target_id, "turn":next.turn,
			"log":[{"turn":next.turn, "text":message}]}
	elif command == "advance":
		message = _advance(next)
	elif next.actions < 1:
		return {"ok":false,"message":"Alle Vorbereitungen dieser Saison sind verbraucht."}
	else:
		match command:
			"harvest":
				var amount := int(summary(next).harvest_yield)
				next.grain += amount
				message = "%d Korn eingebracht." % amount
			"store", "supply":
				var capacity := 6 + floori(next.owned.size()/4.0) if command == "store" else 5
				var amount := mini(capacity,next.grain)
				if amount == 0:
					return {"ok":false,"message":"Für diese Vorbereitung fehlt freies Korn."}
				next.grain -= amount
				if command == "store":
					next.stores += amount
				else:
					next.supply += amount
				message = "%d Korn als %s verbucht." % [amount,"Wintervorrat" if command == "store" else "Reisevorrat"]
			"campaign":
				var info := region_info(next,target_id)
				if info.is_empty() or not info.reachable:
					return {"ok":false,"message":"Ein fremdes Gebiet an einer Land- oder Seeverbindung wählen."}
				if next.supply < info.cost:
					return {"ok":false,"message":"Für dieses Gebiet sind %d Reisevorräte nötig." % info.cost}
				next.supply -= info.cost
				next.owned.append(target_id)
				message = "%s gehört zum Mandat." % Atlas.REGIONS[target_id].name
				if next.owned.size() == Atlas.REGIONS.size():
					message += " Alle Gebiete des Planspiels sind verbunden."
			"mission":
				if next.mission.status == "active" or target_id not in next.owned:
					return {"ok":false,"message":"Ein neuer Winterauftrag braucht ein eigenes Gebiet und einen abgeschlossenen Vorgänger."}
				next.mission = {"id":next.history.size()+1,"target":target_id,"status":"active","misses":0}
				message = "Neuer Winterauftrag in %s." % Atlas.REGIONS[target_id].name
			"mandate":
				var tier := int(next.mandate)
				if tier >= 2 or next.owned.size() < (3 if tier == 0 else 7):
					return {"ok":false,"message":"Das nächste Mandat benötigt drei beziehungsweise sieben Gebiete."}
				next.mandate = tier+1
				message = "%s übernommen. Vorratsbedarf und Folgen bei Mangel steigen." % MANDATES[tier+1]
			_:
				return {"ok":false,"message":"Unbekannter Kampagnenauftrag."}
		next.actions -= 1
	next.last_event = message
	if not validate(next):
		return {"ok":false,"message":"Dieser Zug würde einen ungültigen Kampagnenstand erzeugen."}
	data.clear()
	data.merge(next)
	return {"ok":true,"message":message}
