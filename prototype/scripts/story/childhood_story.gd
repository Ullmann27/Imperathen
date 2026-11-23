extends RefCounted
## An authored childhood in the existing village. Decisions, not idle time, open scenes.
## WorldModel owns the outer transaction, resource authority and save envelope.

const Format = preload("res://scripts/domain/childhood_format.gd")
const VERSION := 1
const RANGE := 3.2
const APPROACH_SECONDS := 32.0
const MAX_RECEIPTS := 96
const GOODS := ["wood", "grain", "denarii", "stone"]
const PEOPLE := ["julia", "silvanus", "sextus", "marcus", "cassia", "varro", "severus", "aurelia"]
const INITIAL_GOODS := {"wood":12, "grain":16, "denarii":0, "stone":8}
const INITIAL_BONDS := {"julia":20, "silvanus":20, "sextus":10, "marcus":5, "cassia":0, "varro":0, "severus":0, "aurelia":0}
const HOME := Vector2(-5.0, 25.4)
const HOME_ENTRANCE := Vector2(-5.0, 27.65)
const REFUGE := Vector2(-14.0, 25.4)
const REFUGE_ENTRANCE := Vector2(-14.0, 27.65)
const SMITH := Vector2(37.2, -27.3)
const SMITH_ENTRANCE := Vector2(34.35, -26.0)
const WELL := Vector2(-7.0, 8.0)
const SOUTH_GATE := Vector2(0.0, 30.0)
const EAST_ROAD := Vector2(30.0, -16.0)
const NORTH_POST := Vector2(0.0, -46.0)
const ESCORT_SPEED := 1.35
const ESCORT_ROUTE := [Vector2(-4.0,24.9),Vector2(-5.0,25.4),Vector2(-5.0,27.0),Vector2(-5.0,28.2),Vector2(-14.0,28.2),Vector2(-14.0,27.0),Vector2(-14.0,25.4)]
const COMMAND_FIELDS := {"childhood_choose":["scene_id", "choice"]}
const NIGHT_SCENES := ["night_mother", "night_escort", "night_wait", "night_hidden"]
const WORKPLACES := {"farm":Vector2(24.0,-30.0), "woodcamp":Vector2(-43.0,14.0), "quarry":Vector2(48.0,-12.0), "trade":Vector2(25.0,24.0), "watchpost":Vector2(0.0,-48.0), "defense":Vector2(0.0,-16.0)}
const DEFAULT_POSITIONS := {"cassia":Vector2(5.0,0.0), "varro":Vector2(-14.0,-6.6), "severus":Vector2(0.0,-7.0), "aurelia":Vector2(8.0,16.5)}

# Choice: id, label, following scene, authored effects. A receipt stores only the
# accepted scene/choice and observed clocks; the effects are rebuilt on validation.
const SCENES := {
	"family_morning": {"day":1,"phase":"morning","npc":"julia","title":"Ein Morgen zu Hause","text":"Julia stellt den gefüllten Krug auf den Tisch. Vater Silvanus trägt heute Holz und Werkzeug zur Werkstatt. »Bringst du ihm den Essenskorb? Sag es ehrlich, wenn du etwas anderes vorhast. Dann organisiere ich es selbst.«","choices":[
		["promise","Den Korb übernehmen · 2 Getreide","father_lunch",{"goods":{"grain":-2},"cargo":{"meal":2},"bonds":{"julia":2},"memory":{"meal":"promised"}}],
		["decline","Heute ablehnen und Vater selbst Bescheid sagen","father_lunch",{"memory":{"meal":"declined"}}]]},
	"father_lunch": {"day":1,"phase":"afternoon","npc":"silvanus","title":"Vaters Arbeit","text":"Silvanus setzt seine Last ab. Er kennt jeden Wagen auf diesem Platz und fragt nach deinem Morgen. »Sextus und ich sind seit unserer Jugend Freunde. Ich möchte, dass du ihn wirklich kennenlernst. In seiner Werkstatt darfst du fragen und Fehler machen – wenn du dazu stehst.«","choices":[
		["deliver","Den versprochenen Korb übergeben","friend_well",{"requires_cargo":{"meal":2},"cargo":{"meal":-2},"bonds":{"silvanus":3},"memory":{"meal":"delivered"}}],
		["lost","Ehrlich sagen, dass der übernommene Korb verloren ging","friend_well",{"requires_cargo":{"meal":2},"cargo":{"meal":-2},"bonds":{"silvanus":-1},"memory":{"meal":"lost"}}],
		["explain","Die Ablehnung erklären","friend_well",{"if_memory":{"meal":"declined"},"bonds":{"silvanus":1},"memory":{"meal":"explained"}}]]},
	"friend_well": {"day":1,"phase":"afternoon","npc":"marcus","title":"Ein Freund am Dorfweg","text":"Marcus möchte den Brunnenrand absuchen. Ein Lederriemen aus Sextus' Werkzeugbündel fehlt. Er hat Angst, dass man ihn sofort beschuldigt. »Schauen wir erst nach, bevor alle reden?«","choices":[
		["join","Mit Marcus nachsehen","well_search",{"bonds":{"marcus":2},"memory":{"friend":"joined"}}],
		["decline","Diesmal nicht mitgehen","day1_evening",{"bonds":{"marcus":-1},"memory":{"friend":"declined"}}]]},
	"well_search": {"day":1,"phase":"afternoon","npc":"","place":"well","title":"Spuren am Brunnen","text":"Am Rand hängen Fasern an einem Stein. Unter dem Brett liegt ein Riemen; frische Schleifspuren führen vom abgestellten Korb dorthin. Du kannst wirklich nachsehen oder mit einer vorschnellen Vermutung zurückgehen.","choices":[
		["inspect","Unter das Brett schauen und den Riemen aufnehmen","friend_return",{"cargo":{"strap":1},"memory":{"strap":"found"}}],
		["guess","Ohne Untersuchung zurückgehen","friend_return",{"memory":{"strap":"unknown"}}]]},
	"friend_return": {"day":1,"phase":"afternoon","npc":"marcus","title":"Was du tatsächlich gesehen hast","text":"Marcus wartet auf deine Antwort. Eine Anschuldigung lässt sich schnell aussprechen. Er wird sich merken, ob du Beobachtungen von Vermutungen unterscheidest.","choices":[
		["return","Den gefundenen Riemen zeigen","day1_evening",{"requires_cargo":{"strap":1},"cargo":{"strap":-1},"bonds":{"marcus":3,"sextus":1},"memory":{"friend_result":"cleared"}}],
		["honest","Sagen, dass du es nicht sicher weißt","day1_evening",{"bonds":{"marcus":1},"memory":{"friend_result":"honest"}}],
		["blame","Marcus ohne Beleg beschuldigen","day1_evening",{"bonds":{"marcus":-3},"memory":{"friend_result":"accused"}}]]},
	"day1_evening": {"day":1,"phase":"evening","npc":"julia","title":"Zurück am Familientisch","text":"Julia hört zu, Silvanus sitzt neben ihr. Hier zählen die Menschen hinter deinen Aufgaben. Dein Vater fragt, wie es Marcus geht. Deine Mutter erinnert sich an den Essenskorb und lässt dich erklären, was geschehen ist.","choices":[
		["tell","Offen vom Tag erzählen","day1_sleep",{"bonds":{"julia":2,"silvanus":1},"memory":{"evening1":"open"}}],
		["quiet","Heute wenig erzählen","day1_sleep",{"memory":{"evening1":"quiet"}}]]},
	"day1_sleep": {"day":1,"phase":"evening","npc":"","place":"home","title":"Ein Tag ist vergangen","text":"Du bist zu Hause. Du kannst weiter durchs Dorf gehen oder dich bewusst schlafen legen. Gespräche, Pausen und eine geschlossene App beenden keinen Tag für dich.","choices":[["sleep","Zu Hause schlafen · nächster Morgen","father_invitation",{"close_day":true}]]},
	"father_invitation": {"day":2,"phase":"morning","npc":"silvanus","title":"Der Freund deines Vaters","text":"Silvanus erzählt, wie Sextus ihm einst nach einem gebrochenen Wagenrad half. »Er hat auf seinen Lohn gewartet, bis wir wieder Arbeit hatten. Wenn ich heute einen Menschen blind vertrauen würde, dann ihm. Er hat dich für heute eingeladen.«","choices":[
		["ask","Nach ihrer gemeinsamen Geschichte fragen","smith_first",{"bonds":{"silvanus":2,"sextus":1},"memory":{"fathers_friend":"heard"}}],
		["go","Sextus selbst besuchen","smith_first",{"bonds":{"silvanus":1},"memory":{"fathers_friend":"visit"}}]]},
	"smith_first": {"day":2,"phase":"morning","npc":"sextus","title":"Sextus öffnet seine Werkstatt","text":"»Dein Vater ist mein bester Freund«, sagt Sextus. »Du musst hier nichts beweisen. Erst sehen wir uns Griffe und Werkzeuge an. Später zeige ich dir, wie du mit einem Übungsstock sicher stehst.« Er bietet dir eine kleine Arbeit an einem Werkzeugbündel an.","choices":[
		["help","Bei den Werkzeuggriffen helfen","smith_material",{"bonds":{"sextus":2},"memory":{"smith_offer":"accepted"}}],
		["observe","Zunächst nur zuschauen und Fragen stellen","smith_account",{"bonds":{"sextus":1},"memory":{"smith_work":"observed"}}]]},
	"smith_material": {"day":2,"phase":"afternoon","npc":"silvanus","title":"Material hat einen Wert","text":"Silvanus zeigt dir die gemeinsame Vorratsliste. Für zwei Werkzeuggriffe braucht Sextus zwei Holzstücke. Nimm nur die vereinbarte Menge; wenn der Vorrat anderweitig verbraucht wurde, sag es ihm und schau diesmal zu.","choices":[
		["take","2 Holz für Sextus aus dem echten Vorrat nehmen","smith_work",{"goods":{"wood":-2},"cargo":{"billets":2},"memory":{"smith_material":"taken"}}],
		["none","Ohne Material zurückgehen und es erklären","smith_account",{"memory":{"smith_work":"no_material"}}]]},
	"smith_work": {"day":2,"phase":"afternoon","npc":"sextus","title":"Die erste gemeinsame Arbeit","text":"Sextus führt deine Hand beim Anpassen des ersten Griffes. Beim zweiten lässt er dich selbst entscheiden: die Verbindung noch einmal prüfen oder den schiefen Ansatz mit Gewalt festschlagen. Material und Ergebnis bleiben nach diesem Versuch erhalten.","choices":[
		["careful","Den Ansatz prüfen und den Griff sauber einpassen","smith_account",{"requires_cargo":{"billets":2},"cargo":{"billets":-2},"goods":{"denarii":1},"bonds":{"sextus":3},"memory":{"smith_work":"sound"}}],
		["rush","Den schiefen Griff mit Gewalt festschlagen","smith_account",{"requires_cargo":{"billets":2},"cargo":{"billets":-2},"bonds":{"sextus":-1},"memory":{"smith_work":"split"}}]]},
	"smith_account": {"day":2,"phase":"afternoon","npc":"sextus","title":"Ein Fehler beendet keine Freundschaft","text":"Sextus sieht sich die Arbeit mit dir an. Gute Griffe bezahlt er einmal mit dem vereinbarten Denar. Bei einem Fehler erklärt er die gerissenen Fasern. »Komm wieder. Dein Vater und ich haben auch nicht fehlerfrei angefangen.«","choices":[
		["truth","Offen sagen, was du getan hast","day2_evening",{"bonds":{"sextus":2},"memory":{"smith_honesty":"truth"}}],
		["excuse","Die Verantwortung auf das Material schieben","day2_evening",{"bonds":{"sextus":-1},"memory":{"smith_honesty":"excuse"}}]]},
	"day2_evening": {"day":2,"phase":"evening","npc":"silvanus","title":"Was Sextus dir mitgibt","text":"Am Familientisch fragt Silvanus nach der Werkstatt. Er kennt Sextus gut genug, um zu wissen, dass er dir auch nach einem Fehler die Tür offenhält. Julia möchte wissen, ob du morgen wiederkommen willst.","choices":[
		["return","Erzählen und einen weiteren Besuch vorhaben","day2_sleep",{"bonds":{"silvanus":2,"julia":1},"memory":{"evening2":"return"}}],
		["uncertain","Die eigenen Zweifel offen ansprechen","day2_sleep",{"bonds":{"silvanus":1,"julia":1},"memory":{"evening2":"uncertain"}}]]},
	"day2_sleep": {"day":2,"phase":"evening","npc":"","place":"home","title":"Ruhe im vertrauten Haus","text":"Die Werkzeuge bleiben in Sextus' Werkstatt. Deine Entscheidungen und der tatsächlich erhaltene Lohn sind gespeichert. Der nächste Tag beginnt erst, wenn du dich zu Hause schlafen legst.","choices":[["sleep","Schlafen · dritter Morgen","smith_second",{"close_day":true}]]},
	"smith_second": {"day":3,"phase":"morning","npc":"sextus","title":"Ein Übungsstock, keine Uniform","text":"Sextus begrüßt dich wieder und legt einen eigenen Übungsstock auf die Bank. »Dein Vater und ich haben damit als Jungen geübt. Ich leihe ihn dir. Du bleibst mein junger Gast, kein Soldat. Wir beginnen langsam, mit Abstand und einem sicheren Stand.«","choices":[
		["borrow","Den Übungsstock ausdrücklich ausleihen","smith_practice",{"equipment":{"practice_staff":"loaned"},"bonds":{"sextus":2},"memory":{"training_permission":"granted"}}],
		["watch","Zuerst seine Erklärung beobachten","smith_practice",{"bonds":{"sextus":1},"memory":{"training_permission":"observe"}}]]},
	"smith_practice": {"day":3,"phase":"morning","npc":"sextus","title":"Sextus nimmt sich Zeit","text":"Sextus zeigt Stand, Deckung und den freien Raum um euch. Du wiederholst die besprochenen Sicherheitsregeln und kannst anschließend mit dem ausgeliehenen Stock üben. Diese Einweisung erteilt die Erlaubnis; sie behauptet keine bereits ausgeführten Kampftechniken.","choices":[
		["listen","Abstand und sicheren Stand mit ihm besprechen","market_offer",{"bonds":{"sextus":2},"memory":{"smith_practice":"introduced"}}],
		["stop","Für heute mit der Erklärung aufhören","market_offer",{"memory":{"smith_practice":"paused"}}]]},
	"market_offer": {"day":3,"phase":"afternoon","npc":"cassia","title":"Eine Lieferung für die Felder","text":"Cassia braucht Hilfe bei drei Rationen für die Feldarbeiter. Silvanus kann dich ein Stück begleiten. Die Rationen werden bei Annahme aus dem wirklichen Dorfvorrat genommen. Nur eine abgegebene Lieferung wird bezahlt.","choices":[
		["accept","3 Getreide übernehmen und die Lieferung begleiten","delivery_road",{"goods":{"grain":-3},"cargo":{"field_food":3},"bonds":{"cassia":1},"memory":{"delivery":"accepted"}}],
		["decline","Die Lieferung ablehnen","day3_evening",{"memory":{"delivery":"declined"}}]]},
	"delivery_road": {"day":3,"phase":"afternoon","npc":"","place":"east","title":"Mit Vater auf dem Feldweg","text":"Silvanus wartet am breiten Weg. Ein loser Verschluss klappert am Korb. Er lässt dich entscheiden, ob ihr ihn gemeinsam sichert. Der Verlust ist kein zufälliger Würfelwurf: Wer den offenen Korb stehen lässt, liefert seinen Inhalt nicht ab.","choices":[
		["secure","Den Verschluss mit Vater sichern","delivery_field",{"bonds":{"silvanus":2},"memory":{"delivery_care":"secured"}}],
		["abandon","Den offenen Korb zurücklassen und den Verlust melden","delivery_account",{"requires_cargo":{"field_food":3},"cargo":{"field_food":-3},"memory":{"delivery":"lost"}}]]},
	"delivery_field": {"day":3,"phase":"afternoon","npc":"julia","title":"Menschen warten auf die Lieferung","text":"Julia arbeitet am Feldrand und kennt die Leute, für die du das Essen trägst. Sie zählt die drei Rationen mit dir. Was du abgibst, bleibt nicht zusätzlich in deinem Besitz.","choices":[["deliver","Die drei Rationen abgeben","delivery_account",{"requires_cargo":{"field_food":3},"cargo":{"field_food":-3},"bonds":{"julia":2},"memory":{"delivery":"delivered"}}]]},
	"delivery_account": {"day":3,"phase":"afternoon","npc":"cassia","title":"Eine Zusage und ihre Folgen","text":"Cassia verlangt eine klare Auskunft. Eine bestätigte Lieferung zahlt sie einmal aus. Ein verlorener Korb bleibt ein Verlust; sie lässt dich erklären, was schiefging, und hält andere Arbeit für später offen.","choices":[
		["paid","Die abgegebene Lieferung abrechnen · 1 Denar","day3_evening",{"if_memory":{"delivery":"delivered"},"goods":{"denarii":1},"bonds":{"cassia":2},"memory":{"delivery":"paid"}}],
		["loss","Den tatsächlichen Verlust eingestehen","day3_evening",{"if_memory":{"delivery":"lost"},"bonds":{"cassia":-1},"memory":{"delivery":"loss_reported"}}]]},
	"day3_evening": {"day":3,"phase":"evening","npc":"julia","title":"Ein Abend, der später fehlen wird","text":"Julia füllt die Becher. Silvanus erzählt eine peinliche Geschichte über sich und Sextus; zum ersten Mal hörst du beide Namen nicht als Auftraggeber, sondern als Menschen, die einander seit Jahren beistehen. Ihr sprecht über deinen Übungsstock und die Lieferung.","choices":[
		["stay","Bei den Eltern bleiben und zuhören","day3_sleep",{"bonds":{"julia":3,"silvanus":3,"sextus":1},"memory":{"family_evening":"shared"}}],
		["ask","Nach Vaters und Sextus' Jugend fragen","day3_sleep",{"bonds":{"silvanus":3,"sextus":2},"memory":{"family_evening":"their_youth"}}]]},
	"day3_sleep": {"day":3,"phase":"evening","npc":"","place":"home","title":"Ein bewusster Tagesabschluss","text":"Du kennst inzwischen die Familie, Marcus, Sextus und den Weg zu den Feldern. Du kannst weiter erkunden. Schlafen beginnt den vierten erzählten Tag; dein Lebensalter bleibt zwölf.","choices":[["sleep","Schlafen · vierter Morgen","healer_request",{"close_day":true}]]},
	"healer_request": {"day":4,"phase":"morning","npc":"aurelia","title":"Ein kranker Mensch am Wachposten","text":"Aurelia versorgt Valeria. Die Wache braucht Ruhe; Severus übernimmt die Verantwortung. Du sollst keine erwachsene Wache ersetzen. Du kannst Essen bringen und später unter Aufsicht eine Kontrollrunde kennenlernen.","choices":[
		["food","Eine vorhandene Ration für die Kranken geben","father_promise",{"goods":{"grain":-1},"bonds":{"aurelia":2},"memory":{"sick_guard":"helped"}}],
		["visit","Nach Valeria sehen und die Nachricht weitergeben","father_promise",{"bonds":{"aurelia":1},"memory":{"sick_guard":"visited"}}]]},
	"father_promise": {"day":4,"phase":"morning","npc":"silvanus","title":"Vater bleibt erreichbar","text":"Silvanus hört sich an, was Aurelia gesagt hat. »Geh nur mit Varro und Severus. Wenn etwas unklar ist, komm zu mir oder Sextus. Niemand verlangt von dir, allein die Wache zu spielen.« Er möchte abends hören, was du beobachtet hast.","choices":[["promise","Die Grenzen verstehen und den Abend verabreden","smith_third",{"bonds":{"silvanus":2},"memory":{"father_promise":"made"}}]]},
	"smith_third": {"day":4,"phase":"morning","npc":"sextus","title":"Ein weiterer Besuch bei Sextus","text":"Sextus prüft den Übungsstock mit dir. Er erinnert sich an deine erste Arbeit und fragt nach Silvanus. »Dein Vater vertraut dir. Und ich auch. Ein Werkzeug zurückbringen oder einen Fehler eingestehen sagt mir mehr als Prahlen.«","choices":[
		["return","Den ausgeliehenen Stock zurückgeben","patrol_brief",{"if_equipment":{"practice_staff":"loaned"},"equipment":{"practice_staff":"returned"},"bonds":{"sextus":2},"memory":{"smith_last_visit":"returned"}}],
		["buy","Den Stock mit verdientem Geld kaufen · 1 Denar","patrol_brief",{"if_equipment":{"practice_staff":"loaned"},"goods":{"denarii":-1},"equipment":{"practice_staff":"owned"},"bonds":{"sextus":2},"memory":{"smith_last_visit":"bought"}}],
		["talk","Über das Gelernte sprechen","patrol_brief",{"bonds":{"sextus":2},"memory":{"smith_last_visit":"talked"}}]]},
	"patrol_brief": {"day":4,"phase":"afternoon","npc":"severus","title":"Eine beaufsichtigte Kontrollrunde","text":"Severus erklärt den kurzen Weg: Südpforte, Oststraße und zurück zum Nordposten. Varro begleitet die Runde. Du beobachtest Wege und lieferst eine Nachricht ab. Uniform, Rekrutierung und ein Alterswechsel sind damit nicht verbunden.","choices":[
		["join","Mit Varro die vereinbarte Runde gehen","patrol_south",{"bonds":{"severus":1,"varro":1},"memory":{"patrol":"joined"}}],
		["message","Statt der Runde nur die Nachricht am Posten abgeben","watchpost_help",{"memory":{"patrol":"message"}}]]},
	"patrol_south": {"day":4,"phase":"afternoon","npc":"","place":"south","title":"Was am Tor wirklich auffällt","text":"Varro hält an der Südpforte. Eine Wagenfährte biegt vom Weg ab. Er lässt dich vergleichen, statt aus jedem Geräusch einen Angriff zu machen. Der nächste Kontrollpunkt liegt an der breiten Oststraße.","choices":[
		["observe","Die Spur mit Varro vergleichen","patrol_east",{"bonds":{"varro":2},"memory":{"patrol_south":"observed"}}],
		["unsure","Die Unsicherheit zugeben","patrol_east",{"bonds":{"varro":1},"memory":{"patrol_south":"uncertain"}}]]},
	"patrol_east": {"day":4,"phase":"afternoon","npc":"","place":"east","title":"Ein Bericht statt einer Vermutung","text":"An der Oststraße sind ältere Radspuren und frische Hufabdrücke zu unterscheiden. Varro sagt, was sicher ist: Hier waren Pferde. Wer sie ritt und warum, lässt sich daraus allein nicht beweisen.","choices":[
		["report","Die beobachteten Hufspuren genau merken","watchpost_help",{"bonds":{"varro":1},"memory":{"patrol_east":"accurate"}}],
		["invent","Aus der Spur eine unbelegte Gewissheit machen","watchpost_help",{"bonds":{"varro":-1},"memory":{"patrol_east":"exaggerated"}}]]},
	"watchpost_help": {"day":4,"phase":"afternoon","npc":"severus","title":"Für einen Moment am Posten helfen","text":"Severus bleibt der verantwortliche Erwachsene. Du gibst deine Nachricht ab und reichst Wasser. Er hört, was du selbst gesehen hast. Die Wache übernimmt danach; du kehrst zu deiner Familie zurück.","choices":[["report","Die Nachricht abgeben und beim Wasser helfen","day4_evening",{"bonds":{"severus":2},"memory":{"watchpost":"helped"}}]]},
	"day4_evening": {"day":4,"phase":"evening","npc":"julia","title":"Zuhause, bevor alles zerbricht","text":"Silvanus ist zurück. Julia fragt nach der Runde, und dein Vater erzählt, dass Sextus morgen wieder auf dich wartet. Ihr kennt diese Abende inzwischen. Keiner behandelt dich als Herrscher oder als Soldaten. Du bist ihr zwölfjähriger Sohn.","choices":[
		["share","Mit beiden Eltern über den Tag sprechen","day4_sleep",{"bonds":{"julia":2,"silvanus":2},"memory":{"last_evening":"shared"}}],
		["embrace","Die Nähe der Familie suchen","day4_sleep",{"bonds":{"julia":3,"silvanus":2},"memory":{"last_evening":"close"}}]]},
	"day4_sleep": {"day":4,"phase":"evening","npc":"","place":"home","title":"Die Nacht am vertrauten Ort","text":"Du legst dich im Haus deiner Familie schlafen. Erst diese bewusste Entscheidung schließt den Dorfabschnitt ab. Es verstreichen keine Jahre.","choices":[["sleep","Den vierten Tag zu Hause beenden","night_decision",{"close_day":true,"memory":{"night_unlocked":"yes"}}]]},
	"night_decision": {"day":4,"phase":"night","npc":"julia","title":"Hufe in der Dunkelheit","text":"Rufe kommen vom Weg. Julia weckt dich, Silvanus greift nach der Tür. Du musst ausdrücklich entscheiden: hinausgehen und die Verteidigung oder Rettung unterstützen – oder dich mit beiden Eltern im Haus verstecken. Warten entscheidet das nicht für dich. Eine bloße Zusage zu helfen gilt noch nicht als tatsächliche Hilfe.","choices":[
		["defend","Hinausgehen und tatsächlich helfen","night_mother",{"memory":{"night_choice":"defend"}}],
		["hide","Mich mit beiden Eltern im Haus verstecken","night_hidden",{"memory":{"night_choice":"hide"}}]]},
	"night_mother": {"day":4,"phase":"night","npc":"julia","title":"Deine Mutter braucht einen freien Weg","text":"Julia steht im Familienhaus. Du kannst sie über die kurze Gasse zum Nachbarhaus führen. Erreiche sie zuerst und bringe sie dann wirklich zum vereinbarten Schutzort. Auch ein tatsächlicher Treffer, abgewehrter Angriff oder eine echte Rettung bei der Dorfverteidigung belegt deinen Einsatz.","choices":[["escort","Julia persönlich zum Nachbarhaus begleiten","night_escort",{"memory":{"mother_escort":"started"}}]]},
	"night_escort": {"day":4,"phase":"night","npc":"","place":"refuge","title":"Die kurze Gasse zum Schutzort","text":"Julia folgt dir. Erreiche den Innenraum des Nachbarhauses und bestätige dort ihre Ankunft. Erst dieser zweite Ortsschritt zählt als abgeschlossene Rettung; das Versprechen im Elternhaus genügt nicht.","choices":[["arrive","Julia im erreichten Nachbarhaus in Sicherheit bringen","night_wait",{"memory":{"mother_escort":"safe"}}]]},
	"night_wait": {"day":4,"phase":"night","npc":"","place":"refuge","title":"Die Nacht ist noch nicht vorbei","text":"Du hast einen wirklichen Beitrag geleistet. Die Wache kämpft weiter um den Weg. Die Folgen dieser Nacht werden einmalig festgehalten, wenn der laufende Angriff endet.","choices":[]},
	"night_hidden": {"day":4,"phase":"night","npc":"","place":"home","title":"Mit den Eltern im Versteck","text":"Ihr bleibt zusammen im Familienhaus. Die Entscheidung ist gespeichert. Draußen läuft der Angriff weiter. Warten oder ein Neustart verwandeln das Verstecken nicht nachträglich in eine geleistete Verteidigung.","choices":[]},
	"grief_aurelia": {"day":5,"phase":"morning","npc":"aurelia","title":"Wer am Morgen fehlt","text":"Aurelia nennt die Namen der Toten. Silvanus ist gefallen. Auch Sextus, sein bester Freund, kehrt nicht zurück. Das sind dieselben Menschen, mit denen du gearbeitet und gesprochen hast. Ihre Arbeitsplätze und Aufgaben sind nicht mehr besetzt.","choices":[["listen","Aurelia zuhören und zu den vertrauten Orten gehen","father_memory",{"memory":{"loss_heard":"yes"}}]]},
	"father_memory": {"day":5,"phase":"morning","npc":"","place":"home","title":"Vaters Platz","text":"Der Platz am Familientisch ist leer. Du erinnerst dich an Silvanus' Lasten, an seine Hilfe auf dem Feldweg und an die Geschichten über Sextus. Der nächste Auftrag verlangt nicht, mit einem Toten zu sprechen.","choices":[["remember","Bei Vaters Platz verweilen","smith_memory",{"memory":{"father_remembered":"yes"}}]]},
	"smith_memory": {"day":5,"phase":"morning","npc":"","place":"smith","title":"Die stille Werkstatt","text":"Sextus' Werkbank steht noch. Hier durfte ein Fehler eine zweite Chance bekommen. Du erinnerst dich an seine Einladung, die Arbeit an den Griffen und den Übungsstock. Was ausgeliehen, zurückgegeben oder gekauft wurde, bleibt Teil deiner Geschichte.","choices":[["remember","An Sextus und seinen Freund Silvanus denken","survivor_visit",{"memory":{"smith_remembered":"yes"}}]]},
	"survivor_visit": {"day":5,"phase":"morning","npc":"","place":"refuge","title":"Was von der Familie bleibt","text":"Du gehst zum Schutzort. Dort wird sichtbar, welche Folge deine Entscheidung und deine tatsächlichen Handlungen in der Nacht hatten.","choices":[["accept","Die eigene Geschichte annehmen","marcus_after",{"memory":{"family_fate_seen":"yes"}}]]},
	"marcus_after": {"day":5,"phase":"afternoon","npc":"marcus","title":"Marcus bleibt eine wirkliche Person","text":"Marcus spricht über das, was am Brunnen zwischen euch geschehen ist. Er erinnert sich an Hilfe, Ehrlichkeit oder eine ungerechte Anschuldigung. Nun fragt er, was du nach dem Tod deines Vaters und Sextus tun willst.","choices":[["vow","Schwören, die Verantwortlichen zu finden","departure",{"memory":{"revenge_vow":"sworn"}}]]},
	"departure": {"day":5,"phase":"afternoon","npc":"","place":"east","title":"Der eigentliche Aufbruch","text":"Du verlässt den vertrauten Dorfweg mit einem konkreten Grund: den Tod von Silvanus und Sextus aufzuklären und die Verantwortlichen zu suchen. Du bist weiterhin zwölf. Aus dem Schwur entstehen weder ein Soldatenrang noch ein Herrschaftsanspruch.","choices":[["leave","Den Schwur mit auf den Weg nehmen","journey",{"memory":{"departure":"chosen"}}]]},
	"journey": {"day":5,"phase":"afternoon","npc":"","place":"east","title":"Der Schwur bleibt","text":"Deine Familie, die Werkstatt und die Entscheidungen der Nacht bleiben gespeichert. Du kannst zu den Überlebenden zurückkehren und dich weiter ausrüsten. Der Weg zu den Verantwortlichen beginnt mit dem, was du tatsächlich erlebt hast.","choices":[]}
}


static func enabled(data: Dictionary) -> bool:
	return Format.kind(data) == Format.AUTHORED and data.village.childhood.enabled == true


static func _base(active: bool) -> Dictionary:
	return {"version":VERSION, "enabled":active, "scene_id":"family_morning", "day":1, "phase":"morning", "journal":[], "closed_days":[], "ledger":INITIAL_GOODS.duplicate(true) if active else {"wood":0,"grain":0,"denarii":0,"stone":0}, "bonds":INITIAL_BONDS.duplicate(true), "cargo":{"meal":0,"strap":0,"billets":0,"field_food":0}, "equipment":{"practice_staff":"none"}, "memories":{}, "escort":{"progress":0.0,"position":[-4.0,24.9]}, "night_raid":{"phase":"dormant","elapsed":0.0,"seed":1731,"decision":"pending","support_confirmed":false,"support_kind":"","consequences_applied":false,"outcome":""}}


static func ensure(data: Dictionary, active := false) -> void:
	if typeof(data.get("village")) != TYPE_DICTIONARY or data.village.has("childhood"):
		return
	data.village.childhood = _base(active)
	if not active:
		return
	for key: String in GOODS:
		data.resources[key] = int(data.resources[key]) + int(INITIAL_GOODS[key])
	for id: String in data.village.economy.workplaces:
		data.village.economy.workplaces[id].condition = 100
	# Existing workers, existing IDs: the family and the smith are not duplicated.
	var assignments := {"vibius":"farm","drusa":"farm","fabius":"woodcamp","quintus":"woodcamp","cassia":"trade","antonia":"trade","severus":"watchpost","valeria":"watchpost"}
	for person: Dictionary in data.village.economy.people:
		person.assignment = assignments.get(person.id, "idle")
		person.previous_assignment = "idle"
		if person.id == "sextus":
			person.profession = "Schmied"
	data.village.economy.last_report = "Das Dorf besteht bereits. Decimus verwaltet es; du lebst bei Julia und Silvanus."
	data.player.position = [HOME.x, 1.0, HOME.y]
	data.story.title = SCENES.family_morning.title
	data.story.text = SCENES.family_morning.text
	data.chronicle[0].text = "Du bist zwölf und lebst mit Julia und Silvanus in einem bestehenden Dorf. Sextus ist der beste Freund deines Vaters."


static func actor_position(data: Dictionary, id: String) -> Vector2:
	if not enabled(data):
		return Vector2.INF
	var state: Dictionary = data.village.childhood
	var phase := str(state.phase)
	var scene := str(state.scene_id)
	if id == "julia":
		if state.night_raid.outcome == "mother_survived":
			return Vector2(-13.0,24.9)
		if scene == "night_escort" or state.memories.get("mother_escort") == "safe":
			return Vector2(state.escort.position[0],state.escort.position[1])
		return Vector2(22.8,-30.0) if scene == "delivery_field" else Vector2(-4.0,24.9)
	if id == "silvanus":
		if scene == "delivery_road":
			return EAST_ROAD + Vector2(-1.5,1.2)
		return Vector2(-9.0,-5.2) if phase == "afternoon" else Vector2(-6.8,24.8)
	if id == "sextus":
		return SMITH
	if id == str(data.get("companion",{}).get("id","marcus")):
		return Vector2(-3.0,4.0)
	if id == "varro" and scene in ["patrol_south","patrol_east"]:
		return (SOUTH_GATE if scene == "patrol_south" else EAST_ROAD) + Vector2(-1.6,1.2)
	if id == "severus" and scene == "watchpost_help":
		return NORTH_POST + Vector2(-1.2,0.0)
	if DEFAULT_POSITIONS.has(id):
		return _assigned_position(data,id,DEFAULT_POSITIONS[id])
	return Vector2.INF


static func activity(data: Dictionary, id: String) -> String:
	if not enabled(data):
		return "idle"
	var state: Dictionary = data.village.childhood
	if state.scene_id == "night_escort" and id == "julia":
		return "walk"
	if state.phase in ["evening","night"]:
		return "rest"
	if id == str(SCENES[state.scene_id].get("npc","")):
		return "talk"
	return "work" if id in ["silvanus","sextus"] else "idle"


static func _assigned_position(data: Dictionary, id: String, fallback: Vector2) -> Vector2:
	var people: Array = data.get("village",{}).get("economy",{}).get("people",[])
	for index in people.size():
		var person: Dictionary = people[index]
		if person.id != id:
			continue
		var assignment := str(person.assignment)
		if not WORKPLACES.has(assignment):
			return fallback
		var rank := 0
		for previous in index:
			if people[previous].assignment == assignment:
				rank += 1
		if assignment=="trade":
			return WORKPLACES[assignment]+Vector2((rank%2)*1.4-0.7,1.3+floori(rank/2.0)*2.4)
		return WORKPLACES[assignment] + Vector2((rank % 2)*2.4-1.2, floori(rank/2.0)*2.4)
	return fallback


static func objective(data: Dictionary) -> Dictionary:
	if not enabled(data):
		return {}
	var state: Dictionary = data.village.childhood
	var spec: Dictionary = SCENES[state.scene_id]
	var npc := str(spec.npc)
	# Before arrival the doorway is the route goal. Inside, address the same
	# Julia body so it cannot occlude its own rescue-confirmation interaction.
	if state.scene_id=="night_escort" and _escort_arrived(state):
		npc = "julia"
	var point := actor_position(data,npc) if npc != "" else _place(str(spec.get("place","home")))
	var entrance := point
	if npc == "sextus" or spec.get("place","") == "smith":
		entrance = SMITH_ENTRANCE
	elif npc in ["julia","silvanus"] and point.distance_to(HOME) < 4.0 or spec.get("place","") == "home":
		entrance = HOME_ENTRANCE
	elif point.distance_to(REFUGE) < 4.0:
		entrance = REFUGE_ENTRANCE
	return {"id":state.scene_id,"label":spec.title,"npc_id":npc,"position":[point.x,point.y],"entrance":[entrance.x,entrance.y],"kind":"person" if npc != "" else "place","available":_alive(data,npc) if npc != "" else true}


static func _place(id: String) -> Vector2:
	return {"home":HOME,"refuge":REFUGE,"smith":Vector2(36.6,-26.0),"well":WELL,"south":SOUTH_GATE,"east":EAST_ROAD,"north":NORTH_POST}.get(id,HOME)


static func view(data: Dictionary) -> Dictionary:
	if not enabled(data):
		return {"enabled":false}
	var state: Dictionary = data.village.childhood
	var spec: Dictionary = SCENES[state.scene_id]
	return {"enabled":true,"scene_id":state.scene_id,"title":spec.title,"text":_text(data,spec),"day":state.day,"phase":state.phase,"year":int(data.village.history.start_year)+int(data.progress.years_elapsed),"age":data.player.age,"objective":objective(data),"choices":_choices(data),"memories":state.memories.duplicate(true),"bonds":state.bonds.duplicate(true),"equipment":state.equipment.duplicate(true),"journal":state.journal.duplicate(true),"closed_days":state.closed_days.duplicate(true),"active_seconds":float(data.world_seconds),"economy_seconds":_economic_seconds(data),"night_raid":state.night_raid.duplicate(true),"complete":state.scene_id=="journey"}


static func dialogue(data: Dictionary, npc_id := "") -> Dictionary:
	if not enabled(data):
		return {}
	var state: Dictionary = data.village.childhood
	var spec: Dictionary = SCENES[state.scene_id]
	if npc_id == str(objective(data).npc_id):
		return {"npc_id":npc_id,"scene_id":state.scene_id,"title":spec.title,"text":_text(data,spec),"choices":_choices(data)}
	if npc_id in PEOPLE and _alive(data,npc_id):
		return {"npc_id":npc_id,"scene_id":state.scene_id,"title":_name(npc_id),"text":_visit_text(data,npc_id),"choices":[]}
	return {}


static func _choices(data: Dictionary) -> Array:
	var state: Dictionary = data.village.childhood
	var result: Array = []
	for item: Array in SCENES[state.scene_id].choices:
		var reason := _choice_error(state,item[3])
		if not reason.is_empty():
			continue
		reason = _afford_error(data,item[3])
		if reason.is_empty() and state.scene_id=="night_escort" and not _escort_arrived(state):
			reason = "Julia muss selbst durch die Tür in den Innenraum gelangen. Schließe das Gespräch und begleite sie weiter."
		result.append({"id":item[0],"label":item[1],"command":"childhood_choose","args":{"scene_id":state.scene_id,"choice":item[0]},"enabled":reason.is_empty(),"reason":reason})
	return result


static func execute(data: Dictionary, command: String, args: Dictionary) -> Dictionary:
	if command != "childhood_choose" or not _keys(args,["scene_id","choice"]) or not enabled(data):
		return _fail("Diese Kindheitsentscheidung ist nicht verfügbar.")
	if typeof(args.scene_id) != TYPE_STRING or typeof(args.choice) != TYPE_STRING or args.scene_id.length()>64 or args.choice.length()>64:
		return _fail("Die Szenen- oder Antwortkennung ist ungültig.")
	var invalid := validate(data)
	if not invalid.is_empty():
		return _fail("Der Kindheitsstand ist ungültig: " + invalid)
	var state: Dictionary = data.village.childhood
	if state.scene_id != args.scene_id:
		return _fail("Diese Szene wurde bereits entschieden. Der aktuelle Auftrag bleibt erhalten.")
	var target := objective(data)
	if not target.available:
		return _fail("Diese Person ist hier nicht verfügbar.")
	var p: Array = data.player.position
	if Vector2(float(p[0]),float(p[2])).distance_to(Vector2(target.position[0],target.position[1]))>RANGE or absf(float(p[1])-1.0)>3.0:
		return _fail("Erreiche die Person oder den angegebenen Ort, bevor du die Handlung ausführst.")
	var choice: Array = []
	for item: Array in SCENES[state.scene_id].choices:
		if item[0] == args.choice:
			choice = item
			break
	if choice.is_empty():
		return _fail("Diese Antwort gehört nicht zur aktuellen Szene.")
	invalid = _choice_error(state,choice[3])
	if invalid.is_empty():
		invalid = _afford_error(data,choice[3])
	if not invalid.is_empty():
		return _fail(invalid)
	if state.scene_id=="night_escort" and not _escort_arrived(state):
		return _fail("Julia hat den geschützten Innenraum noch nicht tatsächlich erreicht.")
	var candidate: Dictionary = data.duplicate(true)
	var child: Dictionary = candidate.village.childhood
	var receipt := {"scene_id":child.scene_id,"choice":args.choice,"world_seconds":float(data.world_seconds),"economy_seconds":_economic_seconds(data)}
	_apply_receipt(child,choice,receipt)
	for key: String in choice[3].get("goods",{}):
		candidate.resources[key] = int(candidate.resources[key]) + int(choice[3].goods[key])
	if args.scene_id == "night_decision":
		child.night_raid.decision = args.choice
		child.night_raid.phase = "approach"
	if args.scene_id == "night_escort" and args.choice == "arrive":
		child.night_raid.support_confirmed = true
		child.night_raid.support_kind = "escort"
	if args.scene_id == "day3_sleep":
		var sick := _person(candidate,"valeria")
		sick.health = mini(int(sick.health),30)
		sick.assignment = "idle"
		sick.previous_assignment = "idle"
	_schedule(candidate)
	observe_defense(candidate)
	invalid = validate(candidate)
	if not invalid.is_empty():
		return _fail("Die Entscheidung wurde verworfen: " + invalid)
	data.village = candidate.village
	data.resources = candidate.resources
	data.story.title = SCENES[child.scene_id].title
	data.story.text = _text(candidate,SCENES[child.scene_id])
	return {"ok":true,"message":_result_text(args.scene_id,args.choice,child)}


static func _choice_error(state: Dictionary, effect: Dictionary) -> String:
	for key: String in effect.get("requires_cargo",{}):
		if int(state.cargo.get(key,0)) < int(effect.requires_cargo[key]):
			return "Die zugesagte Lieferung befindet sich nicht bei dir."
	for key: String in effect.get("if_memory",{}):
		if state.memories.get(key) != effect.if_memory[key]:
			return "Diese Antwort passt nicht zum erlebten Ausgang."
	for key: String in effect.get("if_equipment",{}):
		if state.equipment.get(key) != effect.if_equipment[key]:
			return "Diese Ausrüstung ist nicht in deinem Besitz."
	return ""


static func _afford_error(data: Dictionary, effect: Dictionary) -> String:
	for key: String in effect.get("goods",{}):
		var next := int(data.resources[key])+int(effect.goods[key])
		if next<0:
			return "Dafür fehlt der tatsächliche Vorrat. Die angebotene Alternative bleibt erreichbar."
		if next>1000000:
			return "Der Vorrat ist voll; zuerst Platz schaffen."
	return ""


static func _apply_receipt(state: Dictionary, choice: Array, receipt: Dictionary) -> void:
	var effect: Dictionary = choice[3]
	for key: String in effect.get("goods",{}):
		state.ledger[key] = int(state.ledger[key])+int(effect.goods[key])
	for key: String in effect.get("cargo",{}):
		state.cargo[key] = int(state.cargo[key])+int(effect.cargo[key])
	for key: String in effect.get("bonds",{}):
		state.bonds[key] = clampi(int(state.bonds[key])+int(effect.bonds[key]),-100,100)
	for key: String in effect.get("memory",{}):
		state.memories[key] = effect.memory[key]
	for key: String in effect.get("equipment",{}):
		state.equipment[key] = effect.equipment[key]
	if effect.get("close_day",false):
		state.closed_days.append({"day":state.day,"world_seconds":receipt.world_seconds,"economy_seconds":receipt.economy_seconds})
	state.journal.append(receipt.duplicate(true))
	state.scene_id = choice[2]
	state.day = SCENES[state.scene_id].day
	state.phase = SCENES[state.scene_id].phase


static func advance(data: Dictionary, delta: float, escort_limit: float = INF) -> bool:
	if not enabled(data) or not is_finite(delta) or delta<=0.0 or is_nan(escort_limit) or escort_limit<0.0:
		return false
	_advance_escort(data,delta,escort_limit)
	var raid: Dictionary = data.village.childhood.night_raid
	if raid.phase not in ["approach","attack"]:
		return false
	raid.elapsed = float(raid.elapsed)+delta
	if raid.phase=="approach" and float(raid.elapsed)+0.000001>=APPROACH_SECONDS:
		raid.phase = "attack"
		return true
	return false


static func _advance_escort(data: Dictionary, delta: float, escort_limit: float) -> void:
	var state: Dictionary = data.village.childhood
	if state.scene_id!="night_escort":
		return
	var p: Array = data.player.position
	var player_point := Vector2(float(p[0]),float(p[2]))
	var projected := _escort_project(player_point)
	if float(projected.distance)>2.8:
		return
	var wanted := maxf(0.0,float(projected.progress)-0.75)
	# Once the child waits inside the refuge, let Julia finish crossing the
	# doorway instead of keeping her outside at the usual following distance.
	# The real-world sweep still stops her if the child blocks that last step.
	if player_point.distance_to(REFUGE)<=1.5 and player_point.y<=REFUGE.y+0.05:
		wanted = _escort_length()
	wanted = minf(escort_limit,wanted)
	var progress := float(state.escort.progress)
	if wanted<=progress:
		return
	progress = minf(wanted,progress+ESCORT_SPEED*delta)
	var point := _escort_point(progress)
	state.escort.progress = progress
	state.escort.position = [point.x,point.y]


static func _escort_length() -> float:
	var length := 0.0
	for i in range(1,ESCORT_ROUTE.size()):
		length += ESCORT_ROUTE[i-1].distance_to(ESCORT_ROUTE[i])
	return length


static func _escort_point(progress: float) -> Vector2:
	var remaining := maxf(0.0,progress)
	for i in range(1,ESCORT_ROUTE.size()):
		var length: float = ESCORT_ROUTE[i-1].distance_to(ESCORT_ROUTE[i])
		if remaining<=length:
			return ESCORT_ROUTE[i-1].lerp(ESCORT_ROUTE[i],remaining/length)
		remaining -= length
	return ESCORT_ROUTE.back()


static func _escort_project(point: Vector2) -> Dictionary:
	var best := {"progress":0.0,"distance":INF}
	var walked := 0.0
	for i in range(1,ESCORT_ROUTE.size()):
		var a: Vector2 = ESCORT_ROUTE[i-1]
		var b: Vector2 = ESCORT_ROUTE[i]
		var section := b-a
		var fraction := clampf((point-a).dot(section)/section.length_squared(),0.0,1.0)
		var distance := point.distance_to(a+section*fraction)
		if distance<float(best.distance):
			best = {"progress":walked+section.length()*fraction,"distance":distance}
		walked += section.length()
	return best


static func _escort_arrived(state: Dictionary) -> bool:
	# z=26.17 is the inner doorway boundary; with a .29 m capsule the saved
	# centre must be at most z=25.88. REFUGE.z + .45 is safely inside it.
	return float(state.escort.progress)>=_escort_length()-0.45 and Vector2(state.escort.position[0],state.escort.position[1]).distance_to(REFUGE)<=0.45


static func observe_defense(data: Dictionary) -> void:
	if not enabled(data):
		return
	var state: Dictionary = data.village.childhood
	var raid: Dictionary = state.night_raid
	if raid.decision=="defend" and not raid.support_confirmed:
		var live: Dictionary = data.village.raid
		if int(live.player_hits)+int(live.blocks)+int(live.dodges)>0 or live.rescued:
			raid.support_confirmed = true
			raid.support_kind = "combat"
	if raid.phase!="attack" or int(data.village.raid.completed)<1 or raid.consequences_applied:
		return
	if raid.decision=="defend" and not raid.support_confirmed:
		# A chosen intention is not evidence. Keep the physical rescue reachable.
		return
	_apply_consequences(data)


static func _apply_consequences(data: Dictionary) -> void:
	var state: Dictionary = data.village.childhood
	var raid: Dictionary = state.night_raid
	if raid.consequences_applied:
		return
	var outcome := "mother_survived" if raid.decision=="defend" and raid.support_confirmed else "parents_lost"
	for id: String in ["silvanus","sextus"] + (["julia"] if outcome=="parents_lost" else []):
		var person := _person(data,id)
		person.alive = false
		person.health = 0
		person.assignment = "idle"
		person.previous_assignment = "idle"
	if outcome=="mother_survived":
		var mother := _person(data,"julia")
		mother.assignment = "idle"
		mother.previous_assignment = "idle"
		mother.health = maxi(1,int(mother.health))
	state.journal.append({"scene_id":"night_resolution","choice":outcome,"world_seconds":float(data.world_seconds),"economy_seconds":_economic_seconds(data)})
	state.memories["family_fate"] = outcome
	state.scene_id = "grief_aurelia"
	state.day = 5
	state.phase = "morning"
	raid.phase = "aftermath"
	raid.consequences_applied = true
	raid.outcome = outcome
	data.story.title = SCENES.grief_aurelia.title
	data.story.text = _text(data,SCENES.grief_aurelia)


static func _schedule(data: Dictionary) -> void:
	var state: Dictionary = data.village.childhood
	# These named people are present in their story role and are not phantom workers.
	for id: String in ["julia","silvanus","sextus"]:
		var person := _person(data,id)
		if not person.is_empty() and person.alive:
			person.assignment = "idle"
			person.previous_assignment = "idle"
	var trainer := _person(data,"severus")
	if not trainer.is_empty() and trainer.alive and state.scene_id in ["patrol_brief","watchpost_help"]:
		trainer.assignment = "idle"
		trainer.previous_assignment = "idle"


static func validate(data: Dictionary) -> String:
	if Format.kind(data) == Format.LEGACY:
		# The older authored life is validated by its own module, without rewrite.
		return ""
	if typeof(data.get("village")) != TYPE_DICTIONARY or typeof(data.village.get("childhood")) != TYPE_DICTIONARY:
		return "Der gespeicherte Kindheitsvertrag fehlt."
	var state: Dictionary = data.village.childhood
	if not _keys(state,["version","enabled","scene_id","day","phase","journal","closed_days","ledger","bonds","cargo","equipment","memories","escort","night_raid"]) or not _integer(state.version,VERSION,VERSION) or typeof(state.enabled)!=TYPE_BOOL:
		return "Unbekannte Kindheitsfelder."
	if typeof(state.journal)!=TYPE_ARRAY or state.journal.size()>MAX_RECEIPTS:
		return "Die Szenenbelege sind ungültig."
	var rebuilt := _base(bool(state.enabled))
	var previous_time := -1.0
	var previous_economy := -1.0
	var resolved := false
	for receipt: Variant in state.journal:
		if not _keys(receipt,["scene_id","choice","world_seconds","economy_seconds"]) or typeof(receipt.scene_id)!=TYPE_STRING or typeof(receipt.choice)!=TYPE_STRING or not _number(receipt.world_seconds,0.0,float(data.get("world_seconds",0.0))) or not _number(receipt.economy_seconds,0.0,_economic_seconds(data)+0.0001):
			return "Ein Szenenbeleg besitzt ungültige Identität oder Zeit."
		if float(receipt.world_seconds)<previous_time or float(receipt.economy_seconds)+0.0001<previous_economy:
			return "Die erlebten Szenen sind zeitlich vertauscht."
		previous_time = float(receipt.world_seconds)
		previous_economy = float(receipt.economy_seconds)
		if receipt.scene_id=="night_resolution":
			if resolved or rebuilt.scene_id not in NIGHT_SCENES or receipt.choice not in ["mother_survived","parents_lost"]:
				return "Der endgültige Überfallausgang wurde mehrfach oder zu früh verbucht."
			if rebuilt.memories.get("night_choice","") != ("defend" if receipt.choice=="mother_survived" else "hide"):
				return "Der Verlust widerspricht der ausdrücklichen Nachtentscheidung."
			rebuilt.memories["family_fate"] = receipt.choice
			rebuilt.scene_id = "grief_aurelia"
			rebuilt.day = 5
			rebuilt.phase = "morning"
			rebuilt.journal.append(receipt)
			resolved = true
			continue
		if receipt.scene_id!=rebuilt.scene_id or not SCENES.has(receipt.scene_id):
			return "Eine Voraussetzung oder eine bereits entschiedene Szene wurde übersprungen."
		var choice: Array = []
		for item: Array in SCENES[receipt.scene_id].choices:
			if item[0]==receipt.choice:
				choice = item
				break
		if choice.is_empty() or not _choice_error(rebuilt,choice[3]).is_empty():
			return "Ein gespeicherter Ausgang passt nicht zur vorherigen Geschichte."
		_apply_receipt(rebuilt,choice,receipt)
	for key: String in ["scene_id","day","phase","closed_days","ledger","bonds","cargo","equipment","memories"]:
		if not _equivalent(state.get(key),rebuilt[key]):
			return "Die belegte Geschichte widerspricht dem gespeicherten Feld: " + key
	if not state.enabled and not state.journal.is_empty():
		return "Ein alter Lebensweg enthält einen nachträglich erzwungenen Kindheitsbogen."
	var escort: Variant = state.escort
	if not _keys(escort,["progress","position"]) or not _number(escort.progress,0.0,_escort_length()) or typeof(escort.position)!=TYPE_ARRAY or escort.position.size()!=2 or not _number(escort.position[0],-100.0,100.0) or not _number(escort.position[1],-100.0,100.0):
		return "Der gespeicherte Begleitweg ist ungültig."
	if not Vector2(escort.position[0],escort.position[1]).is_equal_approx(_escort_point(float(escort.progress))):
		return "Julias Standort liegt nicht auf dem geprüften Begleitweg."
	var escort_start := -1.0
	for receipt: Dictionary in state.journal:
		if receipt.scene_id=="night_mother" and receipt.choice=="escort":
			escort_start = float(receipt.world_seconds)
	if (escort_start<0.0 and float(escort.progress)!=0.0) or (escort_start>=0.0 and float(escort.progress)>ESCORT_SPEED*(float(data.world_seconds)-escort_start)+0.0001):
		return "Der Begleitweg wurde ohne wirklich vergangene Bewegungszeit übersprungen."
	if state.memories.get("mother_escort","")=="safe" and not _escort_arrived(state):
		return "Die Rettung wurde vor Julias tatsächlicher Ankunft verbucht."
	var raid: Variant = state.night_raid
	if not _keys(raid,["phase","elapsed","seed","decision","support_confirmed","support_kind","consequences_applied","outcome"]):
		return "Die Nachtsequenz ist unvollständig."
	if typeof(raid.phase)!=TYPE_STRING or raid.phase not in ["dormant","approach","attack","aftermath"] or not _number(raid.elapsed,0.0,1000000000.0) or not _integer(raid.seed,1,2147483647):
		return "Die Nachtsequenz besitzt ungültige Zeit- oder Variantenwerte."
	if raid.decision!=state.memories.get("night_choice","pending") or typeof(raid.support_confirmed)!=TYPE_BOOL or typeof(raid.consequences_applied)!=TYPE_BOOL or raid.support_kind not in ["","combat","escort"] or raid.outcome not in ["","mother_survived","parents_lost"]:
		return "Die Nachtentscheidung oder ihre Belege fehlen."
	if (raid.decision=="pending") != (raid.phase=="dormant") or (raid.phase=="dormant" and float(raid.elapsed)!=0.0) or (raid.phase=="approach" and float(raid.elapsed)>APPROACH_SECONDS+0.000001) or (raid.phase in ["attack","aftermath"] and float(raid.elapsed)+0.000001<APPROACH_SECONDS):
		return "Die Sequenzzeit überspringt die ausdrückliche Nachtentscheidung."
	if raid.support_confirmed != (raid.support_kind!="") or (raid.support_confirmed and raid.decision!="defend"):
		return "Eine bloße Absicht wurde als tatsächliche Verteidigung gewertet."
	if raid.support_kind=="escort" and state.memories.get("mother_escort","")!="safe":
		return "Die Mutter hat den Schutzort noch nicht erreicht."
	if raid.support_kind=="combat":
		var live: Dictionary = data.village.raid
		if int(live.player_hits)+int(live.blocks)+int(live.dodges)<=0 and not live.rescued:
			return "Der behauptete Verteidigungsbeitrag wurde nicht beobachtet."
	if raid.consequences_applied!=resolved or (raid.outcome!="")!=resolved or (raid.phase=="aftermath")!=resolved:
		return "Die endgültigen Folgen und der einmalige Szenenbeleg widersprechen sich."
	if resolved:
		if raid.outcome!=state.memories.family_fate or int(data.village.raid.completed)<1:
			return "Die Folgen wurden ohne den tatsächlichen Überfall verbucht."
		for id: String in ["silvanus","sextus"] + (["julia"] if raid.outcome=="parents_lost" else []):
			var person := _person(data,id)
			if person.is_empty() or person.alive or int(person.health)!=0 or person.assignment!="idle":
				return "Ein endgültig gefallener Angehöriger besitzt einen widersprüchlichen Arbeits- oder Lebenszustand."
		if raid.outcome=="mother_survived" and (not raid.support_confirmed or not _alive(data,"julia")):
			return "Julias Überleben braucht den tatsächlich geleisteten Beitrag."
	if state.enabled:
		if typeof(data.get("player"))!=TYPE_DICTIONARY or typeof(data.get("progress"))!=TYPE_DICTIONARY:
			return "Der aktive Kindheitsbogen benötigt eine gültige Spieler- und Altersstruktur."
		if not data.village.enabled or data.get("origin_id","")!="italia" or int(data.player.get("age",0))!=12 or data.player.get("role","")!="child" or int(data.progress.get("years_elapsed",-1))!=0:
			return "Die neue Kindheit wurde automatisch gealtert oder in eine Soldatenkarriere umgewandelt."
		for id: String in PEOPLE:
			if id!="marcus" and _person(data,id).is_empty():
				return "Eine Pflichtperson fehlt in der gemeinsamen Einwohnerliste."
		if not resolved:
			for id: String in ["julia","silvanus","sextus"]:
				if not _alive(data,id):
					return "Ein Familienmitglied fehlt vor seinem gespeicherten Erzählübergang."
	return ""


static func restore_integer_fields(data: Dictionary) -> void:
	if Format.kind(data) != Format.AUTHORED:
		return
	var state: Dictionary = data.village.childhood
	state.version = int(state.version)
	state.day = int(state.day)
	state.night_raid.seed = int(state.night_raid.seed)
	for section: String in ["ledger","bonds","cargo"]:
		for key: String in state[section]:
			state[section][key] = int(state[section][key])
	for day: Dictionary in state.closed_days:
		day.day = int(day.day)


static func _person(data: Dictionary, id: String) -> Dictionary:
	for person: Dictionary in data.get("village",{}).get("economy",{}).get("people",[]):
		if person.id==id:
			return person
	return {}


static func _alive(data: Dictionary, id: String) -> bool:
	if id==str(data.get("companion",{}).get("id","marcus")):
		return true
	var person := _person(data,id)
	return not person.is_empty() and person.get("alive",false)==true and int(person.get("health",0))>0


static func _economic_seconds(data: Dictionary) -> float:
	var economy: Dictionary = data.get("village",{}).get("economy",{})
	return int(economy.get("day",0))*120.0+float(economy.get("day_seconds",0.0))


static func _text(data: Dictionary, spec: Dictionary) -> String:
	var state: Dictionary = data.village.childhood
	var value := str(spec.text)
	if state.scene_id in ["day1_evening","father_lunch"]:
		value += "\n\n" + {"delivered":"Vater hat deinen Essenskorb tatsächlich erhalten.","lost":"Der übernommene Korb ging verloren. Deine Eltern erinnern sich daran.","declined":"Du hast den Botengang abgelehnt; Julia hat sich darum gekümmert.","explained":"Du hast Vater die Ablehnung selbst erklärt."}.get(state.memories.get("meal",""),"")
	if state.scene_id in ["smith_account","smith_third","day2_evening"]:
		value += "\n\n" + {"sound":"Die beiden Griffe sind brauchbar. Der vereinbarte Denar wurde einmal ausgezahlt.","split":"Der hastig eingesetzte Griff ist gerissen. Es gab dafür keinen Lohn.","observed":"Du hast zunächst zugeschaut. Dafür wurde kein Arbeitslohn erfunden.","no_material":"Ohne Material habt ihr die Arbeit besprochen, statt einen fertigen Griff zu behaupten."}.get(state.memories.get("smith_work",""),"")
	if state.scene_id in ["grief_aurelia","survivor_visit"]:
		value += "\n\n" + ("Julia lebt. Deine tatsächliche Hilfe in dieser Nacht hat ihren Ausgang verändert. Silvanus und Sextus sind dennoch tot." if state.night_raid.outcome=="mother_survived" else "Auch Julia ist tot. Du hattest dich mit beiden Eltern versteckt. Die drei Verluste bleiben endgültig Teil dieses Lebenswegs.")
	if state.scene_id=="marcus_after":
		value += "\n\n" + _friend_memory(state)
	return value.strip_edges()


static func _visit_text(data: Dictionary, id: String) -> String:
	var state: Dictionary = data.village.childhood
	if id=="sextus":
		return "Sextus nimmt sich Zeit für dich. »Silvanus ist mein bester Freund. Seine Familie gehört für mich dazu.«\n" + {"sound":"Er erinnert dich an die sauber eingepassten Griffe.","split":"Er zeigt dir noch einmal die gerissenen Fasern und gibt dir eine zweite Chance.","observed":"Er erinnert sich an deine Fragen beim ersten Besuch."}.get(state.memories.get("smith_work",""),"Die Werkstatt bleibt für einen Besuch offen.")
	if id=="silvanus":
		return "Silvanus fragt nach deinem Tag und nach Sextus. Er erinnert sich an den Essenskorb und eure gemeinsamen Wege. Ihr müsst nicht erst eine neue Belohnung erfinden, um miteinander zu sprechen."
	if id=="julia":
		return "Julia lebt und erinnert sich an deine Hilfe in der Nacht. Ihr sprecht über Silvanus und Sextus." if state.night_raid.outcome=="mother_survived" else "Julia hört dir zu. Du bist ihr Sohn, kein Verwalter des Dorfes. Der Familientisch und eure Abende bleiben ein fester Teil deines Lebens."
	if id=="marcus":
		return _friend_memory(state)
	return "%s erinnert sich an eure bisherigen Begegnungen. Euer Gespräch vergibt keine wiederholte Bezahlung." % _name(id)


static func _friend_memory(state: Dictionary) -> String:
	return {"cleared":"Marcus erinnert sich, dass du den Riemen gefunden und ihn entlastet hast.","honest":"Marcus weiß noch, dass du Unsicherheit zugegeben hast, statt etwas zu erfinden.","accused":"Marcus hat deine unbelegte Anschuldigung nicht vergessen."}.get(state.memories.get("friend_result",""),"Marcus erinnert sich daran, ob du ihn am Brunnen begleiten wolltest.")


static func _result_text(scene: String, choice: String, state: Dictionary) -> String:
	if scene.begins_with("day") and scene.ends_with("sleep"):
		return "Der Tagesabschluss ist gespeichert. Du bleibst zwölf Jahre alt. " + str(SCENES[state.scene_id].title)
	if scene=="night_decision":
		return "Deine Nachtentscheidung ist gespeichert: " + ("Du willst wirklich helfen; erst eine ausgeführte Rettung oder Verteidigung zählt." if choice=="defend" else "Du versteckst dich mit deinen Eltern im Haus.")
	if scene=="night_escort":
		return "Du hast Julia am tatsächlichen Schutzort abgeliefert. Diese Rettung ist als wirklicher Beitrag gespeichert."
	return "Die Entscheidung und ihre einmaligen Folgen sind gespeichert. " + str(SCENES[state.scene_id].title)


static func _name(id: String) -> String:
	return {"julia":"Julia","silvanus":"Silvanus","sextus":"Sextus","marcus":"Marcus","cassia":"Cassia","varro":"Varro","severus":"Severus","aurelia":"Aurelia"}.get(id,id)


static func _keys(value: Variant, names: Array) -> bool:
	return typeof(value)==TYPE_DICTIONARY and value.size()==names.size() and value.has_all(names)


static func _number(value: Variant, low: float, high: float) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=low and float(value)<=high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value,float(low),float(high)) and float(value)==floorf(float(value))


static func _equivalent(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]:
		return is_finite(float(left)) and float(left)==float(right)
	if typeof(left)!=typeof(right):
		return false
	if typeof(left)==TYPE_DICTIONARY:
		if left.size()!=right.size():
			return false
		for key: Variant in left:
			if not right.has(key) or not _equivalent(left[key],right[key]):
				return false
		return true
	if typeof(left)==TYPE_ARRAY:
		if left.size()!=right.size():
			return false
		for i in left.size():
			if not _equivalent(left[i],right[i]):
				return false
		return true
	return left==right


static func _fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}
