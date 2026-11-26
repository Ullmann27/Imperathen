extends RefCounted
## Authored presentation for the first day and the confirmed adult transition.
## Reading a sequence or a dialogue never changes the authoritative world state.

const Origins = preload("res://scripts/strategy/origins.gd")
const I01Film = preload("res://scripts/story/i01_film.gd")
const WorldCalendar = preload("res://scripts/domain/world_calendar.gd")
const STORY_VERSION := 1
const HELP_WOOD := 4
const HUT_WOOD := 8
const SHOT_IDS := ["aquileia_detail", "legions_rain", "caesar_orders", "labienus_orders", "legions_depart", "valley", "market", "well", "plot", "player", "mission_dialogue", "mission_reaction", "i01_table_detail", "i01_shelf_cups", "i01_bed", "i01_choice", "i01_table_wide", "i01_topic_choice", "i01_cups_insert", "i01_close_speaker", "i01_react_boy", "i01_two_shot", "i01_react_julia", "duo_wide", "duo_close", "duo_react", "duo_ots", "duo_hands", "prop_insert"]
const REGIONS := {
	"italia": {
		"location": "Römische Grenzsiedlung",
		"opening": "Trajan herrscht in Rom. Hier führt Decimus das Dorf. Der Überfall hat Dächer und Vorräte gekostet. Du gehörst zu denen, die bleiben.",
		"host": "Livia", "host_role": "Händlerin",
		"permission": "Das Holz westlich vom Brunnen ist freigegeben. Östlich des Weges darfst du bauen. Sprich danach mit Decimus und unseren Handwerkern.",
		"companion_role": "Am Brunnen",
		"request": "He, bleib kurz! Am Brunnen ist eine Strebe gebrochen. Vier Holzstücke würden reichen. Hilfst du mir, bevor du dein Dach baust?",
		"meeting": "Marcus wartet beim Brunnen.\n\n»Eine Strebe hält keinen vollen Eimer mehr. Vier Holzstücke, dann kann ich sie ersetzen. Ich weiß, du brauchst selbst ein Dach. Kannst du trotzdem etwas entbehren?«",
		"help_reply": "»Danke. Die Strebe bekommen wir hin. Dein Holz werde ich nicht vergessen.«",
		"decline_reply": "»Verstehe. Du brauchst selbst ein Dach. Ich frage die anderen.«"
	},
	"germania": {
		"location": "Höfe östlich des Rheins",
		"opening": "Zwischen den Höfen zieht Rauch über die Felder. Hier beginnt dein Weg mit Arbeit, Nachbarn und einem eigenen Dach.",
		"host": "Chronik", "host_role": "Dein erster Tag",
		"permission": "Das bereitgelegte Holz westlich vom Brunnen darfst du nutzen. Östlich des Weges ist Platz für deinen ersten eigenen Schlafplatz.",
		"companion_role": "Bei den Höfen",
		"request": "Bevor der Frost kommt, müssen wir das Holz unter Dach bringen. Vier Stück fehlen mir noch. Hast du etwas übrig?",
		"meeting": "Albrun wartet bei den Höfen.\n\n»Die anderen bereiten die Versammlung vor. Ich muss noch das Holz unter Dach bringen, bevor der Frost kommt. Vier Stück fehlen. Hilfst du mir?«",
		"help_reply": "»Danke. Dann wird es heute noch fertig. Ich merke mir, wer mit anpackt.«",
		"decline_reply": "»Gut. Kümmere dich um deinen Platz. Ich frage bei den anderen Höfen nach.«"
	},
	"han": {
		"location": "Dorf am Weg zum Bezirksspeicher",
		"opening": "Wagen ziehen zum Fluss. Ihr Korn ernährt Menschen, die du noch nie gesehen hast. Dein eigener Anfang liegt hier im Dorf.",
		"host": "Chronik", "host_role": "Dein erster Tag",
		"permission": "Das bereitgelegte Holz westlich vom Brunnen darfst du nutzen. Östlich des Weges ist Platz für deinen ersten eigenen Schlafplatz.",
		"companion_role": "Am Speicherweg",
		"request": "Mein Tragkorb ist gebrochen. Mit vier Holzstücken kann ich ihn wieder verstärken. Die Lieferung wartet nicht lange. Hilfst du mir?",
		"meeting": "Lin wartet am Dorfweg.\n\n»Mein Tragkorb ist gebrochen. So bekomme ich das Korn nicht zum Fluss. Vier Holzstücke würden den Rahmen halten. Ich weiß, du brauchst selbst Material. Kannst du etwas abgeben?«",
		"help_reply": "»Danke. Jetzt kann ich den Rahmen wieder festmachen. Auf deine Hilfe werde ich mich besinnen.«",
		"decline_reply": "»Dann suche ich weiter. Dein eigenes Dach baut sich auch nicht von allein.«"
	},
	"wa": {
		"location": "Dorf am Reisfeld",
		"opening": "Hinter dem Grabenring liegen die Reisfelder. Ihr Ertrag hält das Dorf zusammen. Dein Anfang ist ein eigener Platz darin.",
		"host": "Chronik", "host_role": "Dein erster Tag",
		"permission": "Das bereitgelegte Holz westlich vom Brunnen darfst du nutzen. Östlich des Weges ist Platz für deinen ersten eigenen Schlafplatz.",
		"companion_role": "Beim Dorfweg",
		"request": "Für den Speicher brauche ich noch vier gerade Hölzer. Wenn der Regen kommt, muss das Dach halten. Kannst du mir helfen?",
		"meeting": "Aki wartet am Dorfweg.\n\n»Vier gerade Stücke fehlen noch für den Speicher. Vor dem nächsten Regen müssen sie sitzen. Dein eigener Bau braucht auch Material. Können wir trotzdem etwas teilen?«",
		"help_reply": "»Danke. Dann komme ich vor dem Regen weiter. Das vergesse ich nicht.«",
		"decline_reply": "»Ich verstehe. Bring deinen eigenen Bau voran. Ich werde jemand anderen fragen.«"
	},
	"vistula": {
		"location": "Siedlung am Marktweg",
		"opening": "Am Marktweg werden Korn, Werkzeug und Nachrichten getauscht. Für dich beginnt der Tag mit einem eigenen Dach.",
		"host": "Chronik", "host_role": "Dein erster Tag",
		"permission": "Das bereitgelegte Holz westlich vom Brunnen darfst du nutzen. Östlich des Weges ist Platz für deinen ersten eigenen Schlafplatz.",
		"companion_role": "Am Marktweg",
		"request": "Mein Korb ist zerbrochen. Mit vier Holzstücken kann ich den Rahmen richten. Hast du etwas übrig, bevor du selbst baust?",
		"meeting": "Mira wartet am Marktweg.\n\n»Mein Korb ist zerbrochen. Vier Holzstücke, dann kann ich ihn richten. Du willst selbst bauen, ich weiß. Kannst du trotzdem etwas teilen?«",
		"help_reply": "»Danke. Jetzt kann ich den Rahmen richten. Ich werde mich an deine Hilfe erinnern.«",
		"decline_reply": "»Dann muss ich weiterfragen. Vielleicht sehen wir uns später am Markt.«"
	}
}


## The campaign year comes from the world calendar, never from a literal.
static func campaign_year_label() -> String:
	return WorldCalendar.format_year(int(WorldCalendar.CAMPAIGN_START.year))


static func historical_prologue() -> Dictionary:
	var chapter := "Prolog · I-00 · Drei Legionen im Regen"
	var location := "Aquileia und Umland · " + campaign_year_label()
	return {
		"id":"i00_aquileia","version":2,"origin_id":"italia",
		"source_mission_id":"I-00",
		"historical_source":"C. Julius Caesar · Bellum Gallicum I.10",
		"title":"Drei Legionen im Regen","location":location,"chapter":chapter,
		"chain_to":"childhood_home",
		"beats":[
			_beat("i00_detail","aquileia_detail","Chronik","Aquileia · " + campaign_year_label(),
				"Regen läuft über Leder, Holz und Metall. Bei Aquileia werden Caesars Legionen zum Marsch bereitgemacht; erst das Detail, dann öffnet sich der Blick auf Lager und Straße.",
				7.0,chapter,location),
			_beat("i00_legions","legions_rain","Chronik","Drei Legionen",
				"Drei Legionen stehen bei Aquileia bereit. Männer ordnen Gepäck und Waffen, Befehle gehen durch die Reihen. Der Aufbruch hängt ebenso an Versorgung und Wegen wie am Mut.",
				8.0,chapter,location),
			_beat("i00_caesar","caesar_orders","Caesar","Dramatisierter Produktionsdialog",
				"»Berichte, was du gesehen hast. Nicht, was du glaubst, dass ich hören will.«",
				7.5,chapter,location),
			_beat("i00_labienus","labienus_orders","Labienus","Dramatisierter Produktionsdialog",
				"»Wenn du Zweifel hast, melde sie. Wenn du Befehle hast, führe sie aus.«",
				7.5,chapter,location),
			_beat("i00_departure","legions_depart","Caesar","Dramatisierter Produktionsdialog",
				"»Eine Armee bewegt sich nicht durch Mut allein. Sie bewegt sich, weil Brot, Wege und Befehle zur gleichen Zeit ankommen.«",
				8.0,chapter,location)
		],
		"objective_title":"Valdora · Am selben Morgen",
		"objective_text":"Im Raum Aquileia liegt Valdora. Dort beginnt am selben Morgen die Geschichte eines zwölfjährigen Kindes, seiner Familie und der drei Becher."
	}


## VID-A of I-01 (screenplay v4). The former three text cards are kept below as
## childhood_cards() for reference; the playable opening is the in-engine film.
static func childhood(data: Dictionary = {}) -> Dictionary:
	return I01Film.vid_a(data)


static func childhood_cards() -> Dictionary:
	var chapter := "Kapitel I · I-01 · Die drei Becher"
	var location := "Valdora · Aquileia-Region · " + campaign_year_label()
	return {"id":"childhood_home","version":2,"origin_id":"italia",
		"title":"Ein Morgen zu Hause","location":location,"chapter":chapter,
		"beats":[
			_beat("home_morning","player","Chronik","Du bist zwölf","Du wachst im Haus deiner Familie auf. Draußen öffnen die Werkstätten. Auf dem Markt wird schon gehandelt. Diesen Ort musst du nicht erst erschaffen: Hier lebst du.",9.0,chapter,location),
			_beat("family_voice","player","Julia","Deine Mutter","Bist du schon wach? Dein Vater ist vor dem Haus. Komm erst zu mir; für Cassia habe ich eine kleine Besorgung. Zum Erkunden bleibt danach noch Zeit.",9.0,chapter,location),
			_beat("village_lives","market","Chronik","Ein Dorf voller Geschichten","Du wirst Menschen wiedersehen, Versprechen halten und manchmal etwas falsch machen. Nimm dir Zeit. Heute musst du weder Soldat werden noch ein Dorf regieren.",9.0,chapter,location)
		],
		"objective_title":"Ein Morgen zu Hause",
		"objective_text":"Geh durch die Haustür zu deiner Mutter Julia. Die Karte zeigt dir den Weg. Du gehst zunächst in ruhigem Schritttempo; mit „Laufen“ wechselst du das Tempo."}


static func sequence(origin_id: String = "italia") -> Dictionary:
	var selected := _origin_id(origin_id)
	var region: Dictionary = REGIONS[selected]
	var friend: String = Origins.PEOPLES[selected].companion
	var chapter := "Kapitel I · Ein Dach vor dem Abend"
	var beats: Array[Dictionary] = [
		_beat("road_dawn", "valley", "Chronik", "Dein erster Tag · 12 Jahre", region.opening, 7.5, chapter, region.location),
		_beat("livia_market" if selected == "italia" else "village_permission", "market", region.host, region.host_role, region.permission, 9.5, chapter, region.location),
		_beat("marcus_well" if selected == "italia" else "companion_request", "well", friend, region.companion_role, region.request, 10.0, chapter, region.location),
		_beat("first_roof", "plot", "Chronik", "Ein Platz für dich", "Erst brauchst du ein Dach. Dann folgen Arbeit, Begegnungen und Entscheidungen. Wer dir vertraut, steht vielleicht in Gefahr an deiner Seite.", 8.0, chapter, region.location),
		_beat("player_handoff", "player", "Chronik", "Deine Geschichte beginnt", "Finde das Holz westlich des Brunnens. Sprich mit %s. Deinen Bauplatz wählst du östlich des Weges." % friend, 7.5, chapter, region.location)
	]
	return {
		"id": "first_day", "version": STORY_VERSION, "origin_id": selected,
		"title": "Bevor die Straße ruft" if selected == "italia" else "Dein erster Tag",
		"location": region.location, "chapter": chapter, "beats": beats,
		"objective_title": "Ein Dach vor dem Abend",
		"objective_text": "Sammle %d Holz für deine Unterkunft. %s braucht zusätzlich %d Holz; du kannst helfen, ablehnen oder später wiederkommen. Baue östlich des Weges." % [HUT_WOOD, friend, HELP_WOOD]
	}


## Action names are the existing checked command path, never new world commands.
static func companion_dialog(state: Dictionary) -> Dictionary:
	var selected := _origin_id(str(state.get("origin_id", "italia")))
	var region: Dictionary = REGIONS[selected]
	var friend: String = Origins.PEOPLES[selected].companion
	var wood := int(state.get("resources", {}).get("wood", 0))
	var previous: String = str(state.get("companion", {}).get("choice", ""))
	if not previous.is_empty():
		return {"title": "%s · Eure Begegnung" % friend, "text": companion_reply(state), "choices": [_return_choice()]}
	return {
		"title": "%s · %s" % [friend, region.companion_role],
		"text": region.meeting,
		"choices": [
			{"label": "4 Holz teilen · Vertrauen +20", "action": "companion_help", "choice": "help", "enabled": wood >= HELP_WOOD, "reason": "Sammle zuerst 4 Holz. Du kannst jederzeit wiederkommen." if wood < HELP_WOOD else ""},
			{"label": "Mein Holz für das eigene Dach behalten · Vertrauen −5", "action": "companion_decline", "choice": "decline", "enabled": true, "reason": ""},
			_return_choice()
		]
	}


static func companion_reply(state: Dictionary) -> String:
	var selected := _origin_id(str(state.get("origin_id", "italia")))
	var region: Dictionary = REGIONS[selected]
	match str(state.get("companion", {}).get("choice", "")):
		"help": return region.help_reply
		"decline": return region.decline_reply
	return "Die Antwort steht noch aus. Du kannst zuerst Holz sammeln und später wiederkommen."


## Call only after the train transaction succeeds; no preview can age the player.
static func adulthood(state: Dictionary) -> Dictionary:
	var progress: Dictionary = state.get("progress", {})
	if int(state.get("player", {}).get("age", 0)) < 18 or int(progress.get("years_elapsed", 0)) < 6 or str(progress.get("stage", "")) != "training":
		return {}
	var selected := _origin_id(str(state.get("origin_id", "italia")))
	var region: Dictionary = REGIONS[selected]
	var friend: String = Origins.PEOPLES[selected].companion
	var helped := str(state.get("companion", {}).get("choice", "")) == "help"
	var memory := "Damals hast du dein Holz mit mir geteilt. Sechs Jahre sind vergangen. Ich habe es nicht vergessen." if helped else "Damals hast du zuerst an dein eigenes Dach gedacht. Sechs Jahre sind vergangen. Unsere Geschichte ist noch nicht zu Ende."
	var chapter := "Kapitel II · Die erste Verantwortung"
	var beats: Array[Dictionary] = [
		_beat("six_years", "plot", "Chronik", "Sechs Jahre später · 18 Jahre", "Aus deinem ersten Dach ist ein Stück Heimat geworden. Du und %s seid jetzt achtzehn. Eure frühere Entscheidung bleibt Teil dieses Ortes." % friend, 10.0, chapter, region.location),
		_beat("remembered_choice", "well", friend, "Was zwischen euch bleibt", memory, 9.0, chapter, region.location),
		_beat("adult_first_step", "player", "Chronik", "Die erwachsene Ausbildung beginnt", "Jetzt beginnt deine erste Waffenübung. Lerne Abstand und Ruhe zwischen den Schlägen. Welchen Weg du danach einschlägst, ist noch offen.", 10.0, chapter, region.location)
	]
	return {
		"id": "adulthood", "version": STORY_VERSION, "origin_id": selected,
		"title": "Sechs Jahre später", "location": region.location,
		"chapter": chapter, "beats": beats,
		"objective_title": "Die erste Waffenübung",
		"objective_text": "Du bist jetzt 18. Bleibe am Übungsziel und setze drei kontrollierte Treffer. Warte zwischen den Schlägen, bis sich deine Figur erholt hat."
	}


static func _beat(id: String, shot_id: String, speaker: String, role: String, text: String, minimum_duration: float, chapter: String, location: String) -> Dictionary:
	# Approximately 17 characters/second plus two seconds to settle on a new shot.
	# Manual advance and reduced motion are presentation options owned by the UI.
	return {"id": id, "shot_id": shot_id, "speaker": speaker, "role": role,
		"text": text, "duration": maxf(minimum_duration, 2.0 + text.length() / 17.0),
		"chapter": chapter, "location": location}


static func _return_choice() -> Dictionary:
	return {"label": "Ich komme später wieder", "action": "resume", "enabled": true, "reason": ""}


static func _origin_id(value: String) -> String:
	return value if REGIONS.has(value) and Origins.PEOPLES.has(value) else "italia"
