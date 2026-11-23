extends RefCounted
## Authored childhood chapters. Only explicit, nearby actions advance their order.
## This optional state is created for fresh games; loading a legacy save never adds it.

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
	"sick_guard":Vector2(10.0,18.5)
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
	"severus":{"name":"Severus", "role":"Dorfwache", "position":Vector2(-1.2,-45.9), "text":"Eine Runde mit der Wache ist kein Feldzug. Wir sehen nach Wegen und Toren, helfen den Leuten und melden, was wir tatsächlich beobachtet haben."}
}
const STEPS := [
	{"id":"mother_morning", "chapter":"Ein Morgen zu Hause", "npc":"julia", "label":"Mit Mutter den Morgen besprechen", "objective":"Sprich vor eurem Haus mit deiner Mutter Julia.", "text":"»Du bist wach. Dein Vater arbeitet heute an einer Tür. Hol bitte zuerst Wasser im Haus, dann bringt ihr gemeinsam die Besorgungen in Ordnung. Für Cassia lege ich einen Haushaltsdenar bereit.«", "result":"Mutter vertraut dir den zweckgebundenen Haushaltsdenar an. Er ist für die Besorgung, nicht dein Taschengeld."},
	{"id":"fill_water", "chapter":"Ein Morgen zu Hause", "point":"family_water", "label":"Den Wasserkrug füllen", "objective":"Gehe ins Familienhaus und fülle den Krug am Wassertisch.", "text":"", "result":"Du füllst den bereitgestellten Krug. Dein Vater wartet draußen auf dich."},
	{"id":"father_morning", "chapter":"Ein Morgen zu Hause", "npc":"silvanus", "label":"Vater den Krug bringen und zuhören", "objective":"Bring den Krug zu deinem Vater Silvanus vor dem Haus.", "text":"»Danke. Eine Tür braucht gerade Angeln; ein Versprechen braucht jemanden, der es hält. Geh zu Cassia auf den Markt und frage nach unserer Bestellung. Komm anschließend zu Mutter zurück.«", "result":"Vater nimmt den Krug. Die Familie verabredet die Besorgung auf dem Markt."},
	{"id":"market_meeting", "chapter":"Menschen auf dem Markt", "npc":"cassia", "label":"Nach der Familienbestellung fragen", "objective":"Lerne Cassia am Markt kennen und frage nach der Bestellung deiner Familie.", "text":"»Julia hat Brot und Grütze bestellt. Das Päckchen kostet den mitgegebenen Denar. Prüfe erst, ob Name und Bestellung stimmen; dann kaufen wir es gemeinsam.«", "result":"Du hast die richtige Bestellung und ihren Preis erfragt."},
	{"id":"market_purchase", "chapter":"Menschen auf dem Markt", "npc":"cassia", "label":"Den Haushaltsdenar gegen die Bestellung tauschen", "objective":"Kaufe bei Cassia das Familienpäckchen mit dem reservierten Haushaltsdenar.", "text":"»Hier ist das verschnürte Päckchen für eure Küche. Trag es selbst nach Hause; die Besorgung ist erst fertig, wenn es bei deiner Mutter angekommen ist.«", "result":"Der Haushaltsdenar ist bezahlt. Du trägst das Familienpäckchen tatsächlich im Auftragsinventar."},
	{"id":"deliver_food", "chapter":"Menschen auf dem Markt", "npc":"julia", "label":"Mutter die Bestellung übergeben", "objective":"Kehre mit dem Familienpäckchen zu Julia zurück.", "text":"»Du hast zugehört und die richtige Bestellung gebracht. Dein Vater hat noch eine Frage an Fabius. Danach kannst du Sextus an der Schmiede kennenlernen.«", "result":"Die Bestellung erreicht die Küche. Julia merkt sich, dass sie sich auf dich verlassen konnte."},
	{"id":"woodcutter_request", "chapter":"Ein Weg für die Nachbarn", "npc":"fabius", "label":"Fabius nach dem Kleinholz für die Schmiede fragen", "objective":"Suche Fabius auf und frage nach dem vorbereiteten Kleinholz.", "text":"»Für Sextus liegt ein kleines Bündel am Holzlager westlich des Dorfes bereit. Nur das markierte Kleinholz mitnehmen. Die schweren Stämme bleiben liegen.«", "result":"Fabius beschreibt dir den Lagerplatz. Jetzt weißt du, welches Bündel abgeholt werden darf."},
	{"id":"collect_kindling", "chapter":"Ein Weg für die Nachbarn", "point":"wood_bundle", "label":"Das bereitgelegte Kleinholzbündel aufnehmen", "objective":"Gehe zum westlichen Holzlager und hole das kleine Bündel für Sextus.", "text":"", "result":"Du nimmst das vorbereitete Bündel auf. Es muss noch zur Schmiede auf der anderen Dorfseite."},
	{"id":"deliver_kindling", "chapter":"Ein Weg für die Nachbarn", "npc":"sextus", "label":"Sextus das Kleinholz bringen", "objective":"Lerne Sextus an der Schmiede kennen und bring ihm Fabius’ Bündel.", "text":"»Du hast den Weg selbst gemacht und das richtige Holz gebracht. Beim Schmieden zählt dieselbe Sorgfalt. Wenn du einen Probemorgen versuchen möchtest, rede vorher mit deinem Vater.«", "result":"Sextus nimmt das Bündel an. Er bietet einen begleiteten Probemorgen an, keine fertige Berufsausbildung."},
	{"id":"apprentice_permission", "chapter":"Eine erste Lehre", "npc":"silvanus", "label":"Vater um Erlaubnis für den Probemorgen bitten", "objective":"Sprich zu Hause mit Silvanus über Sextus’ Angebot.", "text":"»Ein Probemorgen ist in Ordnung, wenn Sextus dabeibleibt und du auf seine Anweisungen hörst. Geh heute noch zu ihm und vereinbare, was du morgen tun darfst.«", "result":"Vater stimmt dem beaufsichtigten Probemorgen zu. Du bleibst zwölf und wohnst weiter bei deiner Familie."},
	{"id":"smith_trial", "chapter":"Eine erste Lehre", "npc":"sextus", "label":"Den begleiteten Probemorgen vereinbaren", "objective":"Bestätige bei Sextus die Erlaubnis deiner Eltern.", "text":"»Morgen zeige ich dir Blasebalg, Amboss und Kühlbottich. Heute ruhst du dich aus. Du fasst kein heißes Werkstück an, bevor ich es dir sage.«", "result":"Der Probemorgen ist verabredet. Geh nach Hause; der nächste Tag beginnt erst, wenn du dort bewusst ruhst."},
	{"id":"rest_first", "chapter":"Eine erste Lehre", "point":"family_rest", "label":"Zu Hause essen und bis zum nächsten Morgen ruhen", "objective":"Kehre in euer Familienhaus zurück und beende den ersten Tag bewusst.", "text":"", "result":"Nach Essen und Schlaf beginnt der zweite erzählte Dorftag. Dein Alter bleibt zwölf.", "rest":true},
	{"id":"forge_bellows", "chapter":"Arbeit unter Anleitung", "point":"bellows", "label":"Den Blasebalg unter Sextus’ Anleitung bedienen", "objective":"Gehe zum Blasebalg der Schmiede und beginne die angeleitete Arbeit.", "text":"", "result":"Die erste angeleitete Arbeitsfolge ist beendet. Sextus legt ein vorbereitetes Werkstück auf den Amboss.", "seconds":8.0},
	{"id":"forge_anvil", "chapter":"Arbeit unter Anleitung", "point":"anvil", "label":"Das vorbereitete Scharnier am Amboss richten", "objective":"Wechsle zum Amboss und richte das vorbereitete Scharnier mit Sextus.", "text":"", "result":"Du hast am richtigen Arbeitsplatz mitgearbeitet. Das Scharnier muss noch am Kühlbottich geprüft werden.", "seconds":10.0},
	{"id":"forge_quench", "chapter":"Arbeit unter Anleitung", "point":"quench", "label":"Das Werkstück mit Sextus kühlen und prüfen", "objective":"Gehe zum Kühlbottich und schließe die begleitete Arbeitsfolge ab.", "text":"", "result":"Sextus prüft das fertige Scharnier und gibt es dir für Cassias Markttruhe mit.", "seconds":4.0},
	{"id":"deliver_hinge", "chapter":"Eine ehrliche Lieferung", "npc":"cassia", "label":"Cassia das reparierte Scharnier übergeben", "objective":"Trage das geprüfte Scharnier von der Schmiede zu Cassias Marktstand.", "text":"»Das ist das Stück für meine Truhe. Du hast nicht nur davon erzählt, du hast es hergebracht. Zwei Denare sind dein vereinbarter Botenlohn. Hilfst du mir auch bei der Abrechnung einer kleinen Nachbarschaftsbestellung?«", "result":"Die Truhe erhält ihr Scharnier. Du verdienst einmalig zwei Denare für die tatsächliche Lieferung."},
	{"id":"market_trade", "chapter":"Eine ehrliche Lieferung", "npc":"cassia", "label":"Die kleine Bestellung abrechnen", "objective":"Entscheide bei Cassia, wie du die Nachbarschaftsbestellung abrechnest.", "text":"»Du kannst den vereinbarten Lohn von zwei Denaren nehmen. Oder du lässt einen Denar beim Nachbarn, dessen Krug zerbrochen ist. Ich merke mir beides: einen eingehaltenen Preis und eine freiwillige Hilfe.«", "result":"Die Abrechnung bleibt als konkrete Entscheidung gespeichert."},
	{"id":"smith_apprentice", "chapter":"Ein Platz an der Schmiede", "npc":"sextus", "label":"Die angefangene Schmiedelehre fortsetzen", "objective":"Berichte Sextus von der Lieferung und besprich die weitere Lehre.", "text":"»Du bist wiedergekommen, hast das Werkstück geliefert und Rechenschaft abgelegt. Du kannst bei mir weiterlernen. Ein paar Arbeitsfolgen machen dich noch nicht zum Meister; wir nehmen uns Zeit.«", "result":"Sextus nimmt dich als beginnenden Schmiedelehrling an. Deine praktische Arbeit und sein Vertrauen tragen diese Entscheidung."},
	{"id":"family_report", "chapter":"Ein Platz an der Schmiede", "npc":"julia", "label":"Zu Hause vom Probemorgen und dem Markt erzählen", "objective":"Kehre zu Julia zurück und erzähle von deiner Arbeit.", "text":"»Du hast heute Menschen geholfen und selbst etwas verdient. Beides hat Zeit gekostet. Leg die Arbeit für heute beiseite; morgen kannst du Severus nach einer begleiteten Dorfrunde fragen.«", "result":"Die Familie hört von deinen tatsächlichen Lieferungen und der begonnenen Lehre."},
	{"id":"rest_second", "chapter":"Ein Platz an der Schmiede", "point":"family_rest", "label":"Den zweiten Tag zu Hause beenden", "objective":"Beende den Arbeitstag im Familienhaus, wenn du bereit bist.", "text":"", "result":"Der dritte erzählte Tag beginnt. Du bist weiterhin ein zwölfjähriger Dorfbewohner.", "rest":true},
	{"id":"patrol_brief", "chapter":"Mit der Dorfwache unterwegs", "npc":"severus", "label":"Um eine begleitete Dorfrunde bitten", "objective":"Sprich mit Severus am inneren Nordweg über eine begleitete Runde.", "text":"»Du gehst heute mit mir, nicht allein auf Wache. Wir prüfen den inneren Weg, die Wagenstraße und das Tor. Wir beobachten und melden; wir suchen keinen Kampf.«", "result":"Severus übernimmt die Aufsicht. Die drei Wegabschnitte müssen wirklich erreicht und geprüft werden."},
	{"id":"patrol_inner", "chapter":"Mit der Dorfwache unterwegs", "point":"patrol_inner", "label":"Mit Severus den inneren Weg prüfen", "objective":"Prüfe mit Severus den inneren Nordweg.", "text":"", "result":"Der innere Weg ist geprüft. Gehe mit Severus weiter zur Wagenstraße."},
	{"id":"patrol_road", "chapter":"Mit der Dorfwache unterwegs", "point":"patrol_road", "label":"Die Wagenstraße gemeinsam überblicken", "objective":"Erreiche die Wagenstraße weiter nördlich und prüfe sie mit Severus.", "text":"", "result":"Du erkennst die Sichtlinie zwischen Wagenstraße und Tor. Der äußere Abschnitt fehlt noch."},
	{"id":"patrol_gate", "chapter":"Mit der Dorfwache unterwegs", "point":"patrol_gate", "label":"Am Tor mit Severus nach dem Rechten sehen", "objective":"Gehe bis zum Nordtor und schließe den begleiteten Rundgang ab.", "text":"", "result":"Ihr habt das Tor gemeinsam erreicht. Berichte Severus jetzt von deinen Beobachtungen."},
	{"id":"patrol_report", "chapter":"Mit der Dorfwache unterwegs", "npc":"severus", "label":"Die tatsächlich gelaufene Runde besprechen", "objective":"Besprich am Tor die drei geprüften Wegabschnitte mit Severus.", "text":"»Du hast die ganze Runde gemacht und nur berichtet, was du gesehen hast. Darauf kann eine Wache aufbauen. Für heute reicht es; geh zu deiner Familie zurück.«", "result":"Severus bestätigt deinen ersten begleiteten Rundgang. Es ist keine Ernennung zum Soldaten."},
	{"id":"rest_patrol", "chapter":"Wenn ein Nachbar ausfällt", "point":"family_rest", "label":"Nach dem Rundgang zu Hause schlafen", "objective":"Kehre ins Familienhaus zurück und beende den dritten Tag.", "text":"", "result":"Am vierten Morgen lässt Aurelia ausrichten, dass Severus krank ist. Seine Stelle im Wachroster bleibt tatsächlich unbesetzt.", "rest":true},
	{"id":"healer_request", "chapter":"Wenn ein Nachbar ausfällt", "npc":"aurelia", "label":"Aurelia nach Severus fragen", "objective":"Suche Aurelia auf und frage nach dem erkrankten Severus.", "text":"»Er braucht Ruhe und soll heute nicht am Tor stehen. Bring ihm dieses vorbereitete Päckchen. Danach kann er mit deinen Eltern klären, ob du Valeria für einen kurzen Tagesdienst unterstützen darfst.«", "result":"Aurelia übergibt dir das vorbereitete Versorgungspäckchen für Severus."},
	{"id":"deliver_medicine", "chapter":"Wenn ein Nachbar ausfällt", "npc":"severus", "label":"Severus Aurelias Päckchen bringen", "objective":"Bring Aurelias Päckchen zum erkrankten Severus bei ihrem Haus.", "text":"»Danke. Ich bleibe heute hier. Valeria führt die Wache; du könntest ihr nach der bekannten Runde eine kurze Nachricht überbringen. Frag erst deinen Vater. Die Leihsachen bleiben Eigentum der Wache.«", "result":"Das Versorgungspäckchen erreicht Severus. Er ist versorgt, bleibt aber für diesen Dienst aus dem Arbeitsroster genommen."},
	{"id":"watch_permission", "chapter":"Ein begrenzter Tagesdienst", "npc":"silvanus", "label":"Vater um Erlaubnis für die Aushilfe bitten", "objective":"Besprich den begrenzten Tagesdienst zu Hause mit Silvanus.", "text":"»Du kennst den Weg und Valeria bleibt verantwortlich. Eine kurze Aushilfe am inneren Tor ist erlaubt. Du gehst nicht auf einen Feldzug und kommst mit den Leihsachen zu Severus zurück.«", "result":"Vater erlaubt eine begrenzte Aushilfe unter Valerias Verantwortung. Dein Lebensalter und deine zivile Rolle ändern sich nicht."},
	{"id":"borrow_gear", "chapter":"Ein begrenzter Tagesdienst", "npc":"severus", "label":"Die Leihsachen für den Tagesdienst entgegennehmen", "objective":"Hole bei Severus den geliehenen Helm und hölzernen Schild ab.", "text":"»Helm und kleiner Holzschild gehören der Wache. Prüfe den Weg, bleib bei Valerias Abschnitt und melde Cassia, dass ihr Wagen passieren kann. Danach bringst du alles zurück.«", "result":"Du erhältst begrenzte Leihgegenstände für diesen Auftrag. Sie werden nicht zu dauerhaftem Eigentum."},
	{"id":"watch_post", "chapter":"Ein begrenzter Tagesdienst", "point":"patrol_gate", "label":"Valeria am bekannten Torabschnitt unterstützen", "objective":"Gehe zum Nordtor und übernimm den besprochenen kurzen Tagesdienst.", "text":"", "result":"Der bekannte Torabschnitt ist geprüft. Du erhältst die Durchlassnachricht für Cassias Wagen.", "seconds":12.0},
	{"id":"watch_message", "chapter":"Ein begrenzter Tagesdienst", "npc":"cassia", "label":"Cassia die tatsächliche Durchlassnachricht bringen", "objective":"Trage die Nachricht vom Tor zu Cassia auf den Markt.", "text":"»Gut, dann schicke ich den Wagen über den geprüften Weg. Geh jetzt zu Severus und gib die Leihsachen ab. Ein Dienst endet mit einer ordentlichen Übergabe.«", "result":"Cassia erhält die Nachricht vom tatsächlich geprüften Tor. Der Dienst muss noch an Severus übergeben werden."},
	{"id":"return_gear", "chapter":"Ein begrenzter Tagesdienst", "npc":"severus", "label":"Den Dienst übergeben und alle Leihsachen zurückgeben", "objective":"Kehre zu Severus zurück, berichte und gib Helm und Holzschild ab.", "text":"»Du hast die Nachricht gebracht und die Sachen vollständig zurückgegeben. Zwei Denare sind dein Botenlohn. Ich erhole mich und übernehme meine bisherige Stelle wieder, sobald sie frei ist. Geh nach Hause.«", "result":"Der Dienst ist übergeben, die Leihsachen sind zurück und zwei Denare sind bezahlt. Du bist weiter zwölf, kein angeworbener Soldat."},
	{"id":"family_evening", "chapter":"Ein Abend im vertrauten Dorf", "npc":"julia", "label":"Den Abend mit der Familie verbringen", "objective":"Erzähle Julia zu Hause von deinem Tag.", "text":"»Du kennst inzwischen den Markt, die Werkstätten und den Weg zum Tor. Morgen ist wieder Zeit für deine Lehre. Für heute essen wir zusammen und machen die Tür zu.«", "result":"Du verbringst den Abend bei deiner Familie. Die offenen Aufgaben dieses Tages sind wirklich erledigt."},
	{"id":"night_rest", "chapter":"Ein Abend im vertrauten Dorf", "point":"family_rest", "label":"Im Familienhaus schlafen gehen", "objective":"Gehe ins Familienhaus und lege dich schlafen, wenn du den Tag beenden möchtest.", "text":"", "result":"Du legst dich im vertrauten Familienhaus schlafen. Das Dorf wird still."}
]
const CARRIED_EFFECTS := {
	"mother_morning":{"add":["household_coin"]}, "fill_water":{"add":["water_jug"]},
	"father_morning":{"remove":["water_jug"]},
	"market_purchase":{"remove":["household_coin"],"add":["family_parcel"]},
	"deliver_food":{"remove":["family_parcel"]}, "collect_kindling":{"add":["kindling_bundle"]},
	"deliver_kindling":{"remove":["kindling_bundle"]},
	"forge_quench":{"add":["checked_hinge"]}, "deliver_hinge":{"remove":["checked_hinge"]},
	"healer_request":{"add":["medicine_parcel"]}, "deliver_medicine":{"remove":["medicine_parcel"]},
	"watch_post":{"add":["gate_message"]}, "watch_message":{"remove":["gate_message"]}
}
const ITEM_NAMES := {"household_coin":"Reservierter Haushaltsdenar", "water_jug":"Gefüllter Familienkrug", "family_parcel":"Cassias Familienbestellung", "kindling_bundle":"Fabius’ Kleinholzbündel", "checked_hinge":"Geprüftes Scharnier", "medicine_parcel":"Aurelias Versorgungspäckchen", "gate_message":"Durchlassnachricht vom Tor"}
const WORKPLACE_CAPACITY := {"farm":2,"woodcamp":2,"quarry":4,"trade":2,"watchpost":2}


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
	data.village.childhood = {"version":VERSION,"completed":[],"day":1,"carried":[],
		"relationships":relationships,"active_work":"","work_seconds":0.0,
		"gear":"none","apprenticeship":"none","night_event":"none",
		"guard_absence":{"active":false,"previous_assignment":"idle","previous_health":100}}
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
		if not old_relationships.has(legacy_id):
			return false
	var relationships := {}
	for legacy_id: String in LEGACY_RELATION_IDS:
		var canonical_id: String = LEGACY_RELATION_IDS[legacy_id]
		relationships[canonical_id] = (old_relationships[legacy_id] as Dictionary).duplicate(true)
	child.relationships = relationships
	child.version = VERSION

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
	error = validate(candidate)
	if not error.is_empty():
		return _fail("Kindheitsauftrag vollständig verworfen: " + error)
	data.village = candidate.village
	data.resources = candidate.resources
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
		if child.completed.size() != STEPS.size() or child.night_event != "pending":
			return _fail("Diese Nacht wurde noch nicht durch den tatsächlichen Dorfanfang erreicht.")
		child.night_event = "released"
		return _ok("In der Nacht brechen fremde Reiter in die vertraute Ruhe des Dorfes ein.")
	var step := _current(data)
	if step.is_empty():
		return _fail("Die Aufgaben dieses Kindheitskapitels sind bereits abgeschlossen.")
	var action: String = args.action_id
	var id: String = step.id
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
			return _fail("Severus ist für diesen Dorfabschnitt nicht verfügbar.")
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
	if id == "deliver_medicine":
		var guard := _person(data, "severus")
		guard.health = maxi(50, int(guard.health))
	if id == "return_gear":
		child.gear = "returned"
		_restore_guard(data)
	if id in ["patrol_inner", "patrol_road", "patrol_gate"]:
		var attribute: String = {"patrol_inner":"insight","patrol_road":"tactics","patrol_gate":"courage"}[id]
		data.village.attributes[attribute] = mini(10000, int(data.village.attributes[attribute]) + 1)
	if step.get("rest", false):
		child.day += 1
	if id == "night_rest":
		child.night_event = "pending"
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
	return not enabled(data) or data.village.childhood.night_event == "released"


static func view(data: Dictionary) -> Dictionary:
	if not enabled(data) or not validate(data).is_empty():
		return {}
	var child: Dictionary = data.village.childhood
	var step := _current(data)
	var items: Array[String] = []
	for item: String in child.carried:
		items.append(ITEM_NAMES[item])
	var result := {"enabled":true,"day":child.day,"age":int(data.player.age),
		"completed_steps":child.completed.size(),"total_steps":STEPS.size(),
		"stage":step.get("id", "village_night"),"chapter":step.get("chapter", "Die Nacht im Dorf"),
		"title":step.get("chapter", "Die Nacht im Dorf"),
		"objective":step.get("objective", "Du bist bei deiner Familie. Die nächste Nacht setzt eure gemeinsame Geschichte fort."),
		"carried":items,"relationships":child.relationships.duplicate(true),
		"apprenticeship":child.apprenticeship,"gear_loaned":child.gear == "loaned",
		"loaned_items":["Leihhelm","Hölzerner Leihschild"] if child.gear == "loaned" else [],
		"work_seconds":child.work_seconds,"work_required":step.get("seconds", 0.0),
		"can_rest":step.get("rest", false) or step.get("id", "") == "night_rest",
		"night_raid_pending":child.night_event == "pending","night_event":child.night_event,
		"guard_absent":child.guard_absence.active,"target_npc":step.get("npc", ""),
		"target_point":step.get("point", ""),"actions":_choices(data, step)}
	if not step.is_empty():
		var target := _target(data, step)
		result["target_position"] = [target.x, target.y]
		result["point"] = target
	return result


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
			choices = _choices(data, step)
		text += "\n\nVertrauen: %d · Erzählter Dorftag %d. Du bist weiterhin Teil deiner Familie und des Dorfes." % [int(relation.get("trust",0)),int(data.village.childhood.day)]
	return {"title":"%s · %s" % [spec.name,spec.role],"text":text,"choices":choices}


static func interactables(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not enabled(data) or not validate(data).is_empty():
		return result
	var step := _current(data)
	if not step.has("point"):
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
	if not _keys(child,["version","completed","day","carried","relationships","active_work","work_seconds","gear","apprenticeship","night_event","guard_absence"]) or not _integer(child.version,VERSION,VERSION):
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
	if not _integer(child.day,1,4) or child.day != expected_day or child.carried != expected_items:
		return "Tag oder Auftragsgegenstände sind nicht durch erledigte Handlungen belegt."
	if typeof(child.apprenticeship) != TYPE_STRING or child.apprenticeship != expected_apprenticeship or typeof(child.gear) != TYPE_STRING or child.gear != expected_gear:
		return "Lehre oder Leihgegenstände widersprechen der Auftragsfolge."
	if typeof(child.night_event) != TYPE_STRING or child.night_event not in (["pending","released"] if child.completed.size() == STEPS.size() else ["none"]):
		return "Die Nacht darf nicht vor dem vollständigen Dorfanfang beginnen."
	var raid: Dictionary = data.village.get("raid", {})
	if child.night_event != "released" and (raid.get("status", "") != "quiet" or raid.get("number", -1) != 0 or raid.get("completed", -1) != 0):
		return "Vor dem ausdrücklich freigegebenen Nachtereignis darf kein Überfall begonnen oder abgeschlossen sein."
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


static func _current(data: Dictionary) -> Dictionary:
	var index: int = data.village.childhood.completed.size()
	return STEPS[index] if index < STEPS.size() else {}


static func _matches(id: String, action: String) -> bool:
	return action in ["market_fair","market_neighbor"] if id == "market_trade" else action == id


static func _choices(data: Dictionary, step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if step.is_empty():
		return result
	var options: Array = [{"id":step.id,"label":step.label}]
	if step.id == "market_trade":
		options = [{"id":"market_fair","label":"Den vereinbarten Lohn nehmen · 2 Denare"},
			{"id":"market_neighbor","label":"Dem Nachbarn einen Denar lassen · 1 Denar Lohn"}]
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
	return _npc_position(data, step.npc) if step.has("npc") else POINTS[step.point]


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


static func _record(data: Dictionary, id: String, message: String) -> void:
	var history: Dictionary = data.village.history
	history.mode = "fictional_branch"
	history.player_changes.append("childhood_"+id)
	if history.player_changes.size() > 128:
		history.player_changes.pop_front()
	history.events.append({"seconds":data.village.social.seconds,"kind":"childhood_action","text":message,"provenance":"fictional_playable_event"})
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
