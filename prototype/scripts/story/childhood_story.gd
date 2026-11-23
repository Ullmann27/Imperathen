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
	"family_morning": {"day":1,"phase":"morning","npc":"julia","title":"Ein Morgen zu Hause","text":"Julia stellt den gefüllten Krug auf den Tisch und schlägt ein Tuch über den Essenskorb. »Dein Vater vergisst wieder die Zeit, wenn wir ihn lassen. Bringst du ihm das Essen zur Werkstatt?« Sie sieht dich an. »Wenn du etwas anderes vorhast, sag es mir. Dann finden wir eine andere Lösung.«","choices":[
		["promise","Den Korb übernehmen · 2 Getreide","father_lunch",{"goods":{"grain":-2},"cargo":{"meal":2},"bonds":{"julia":2},"memory":{"meal":"promised"}}],
		["decline","Heute ablehnen und Vater selbst Bescheid sagen","father_lunch",{"memory":{"meal":"declined"}}]]},
	"father_lunch": {"day":1,"phase":"afternoon","npc":"silvanus","title":"Vaters Arbeit","text":"Silvanus setzt seine Last ab und wischt sich die Stirn. »Wie war dein Morgen?« Als du die Werkstatt erwähnst, lächelt er. »Sextus ist mein bester Freund, seit wir kaum größer waren als du. Bei ihm darfst du fragen und Fehler machen. Nur verstecken solltest du sie nicht.«","choices":[
		["deliver","Den versprochenen Korb übergeben","friend_well",{"requires_cargo":{"meal":2},"cargo":{"meal":-2},"bonds":{"silvanus":3},"memory":{"meal":"delivered"}}],
		["lost","Ehrlich sagen, dass der übernommene Korb verloren ging","friend_well",{"requires_cargo":{"meal":2},"cargo":{"meal":-2},"bonds":{"silvanus":-1},"memory":{"meal":"lost"}}],
		["explain","Die Ablehnung erklären","friend_well",{"if_memory":{"meal":"declined"},"bonds":{"silvanus":1},"memory":{"meal":"explained"}}]]},
	"friend_well": {"day":1,"phase":"afternoon","npc":"marcus","title":"Ein Freund am Dorfweg","text":"Marcus wartet am Dorfweg und dreht ein loses Stück Schnur zwischen den Fingern. Aus Sextus' Werkzeugbündel fehlt ein Lederriemen. »Ich habe den Korb nur kurz am Brunnen abgestellt«, sagt er leise. »Hilfst du mir suchen, bevor alle glauben, ich hätte ihn genommen?«","choices":[
		["join","Mit Marcus nachsehen","well_search",{"bonds":{"marcus":2},"memory":{"friend":"joined"}}],
		["decline","Diesmal nicht mitgehen","day1_evening",{"bonds":{"marcus":-1},"memory":{"friend":"declined"}}]]},
	"well_search": {"day":1,"phase":"afternoon","npc":"","place":"well","title":"Spuren am Brunnen","text":"Zwischen den Steinen am Brunnenrand hängen helle Fasern. Unter einem verrutschten Brett schimmert etwas Dunkles. Neben dem abgestellten Korb zieht sich eine schmale Schleifspur durch den Staub. Vom Weg her ruft Marcus, ob du etwas gefunden hast.","choices":[
		["inspect","Unter das Brett schauen und den Riemen aufnehmen","friend_return",{"cargo":{"strap":1},"memory":{"strap":"found"}}],
		["guess","Ohne Untersuchung zurückgehen","friend_return",{"memory":{"strap":"unknown"}}]]},
	"friend_return": {"day":1,"phase":"afternoon","npc":"marcus","title":"Was am Brunnen geschah","text":"Marcus richtet sich auf, als du zurückkommst. »Und?« Er versucht, gelassen zu klingen, doch seine Hände kneten noch immer die Schnur. Jetzt wartet er darauf, was du ihm über den Riemen sagst.","choices":[
		["return","Den gefundenen Riemen zeigen","day1_evening",{"requires_cargo":{"strap":1},"cargo":{"strap":-1},"bonds":{"marcus":3,"sextus":1},"memory":{"friend_result":"cleared"}}],
		["honest","Sagen, dass du es nicht sicher weißt","day1_evening",{"bonds":{"marcus":1},"memory":{"friend_result":"honest"}}],
		["blame","Marcus ohne Beleg beschuldigen","day1_evening",{"bonds":{"marcus":-3},"memory":{"friend_result":"accused"}}]]},
	"day1_evening": {"day":1,"phase":"evening","npc":"julia","title":"Zurück am Familientisch","text":"Am Tisch ist noch ein Platz zwischen Julia und Silvanus frei. Dein Vater schiebt dir den Becher hin. »Du warst lange mit Marcus unterwegs. Ist alles in Ordnung?« Julia hört zu und fragt nach dem Essenskorb. Draußen werden die Stimmen in der Gasse leiser.","choices":[
		["tell","Offen vom Tag erzählen","day1_sleep",{"bonds":{"julia":2,"silvanus":1},"memory":{"evening1":"open"}}],
		["quiet","Heute wenig erzählen","day1_sleep",{"memory":{"evening1":"quiet"}}]]},
	"day1_sleep": {"day":1,"phase":"evening","npc":"","place":"home","title":"Wenn das Haus still wird","text":"Julia deckt den Krug ab. Silvanus prüft noch einmal die Tür, dann klingt auch sein Schritt nicht mehr durch das Haus. Dein Bett wartet. Wenn du noch ins Dorf möchtest, kannst du gehen; morgen wirst du Vater und Sextus genug zu erzählen haben.","choices":[["sleep","Zu Hause schlafen · nächster Morgen","father_invitation",{"close_day":true}]]},
	"father_invitation": {"day":2,"phase":"morning","npc":"silvanus","title":"Der Freund deines Vaters","text":"Silvanus erzählt von einem Wagenrad, das ihm einst fern vom Dorf brach. »Sextus hat alles stehen lassen und mich geholt. Auf seinen Lohn hat er gewartet, bis wir wieder Arbeit hatten.« Er hält kurz inne. »Wenn ich einem Menschen blind vertrauen würde, dann ihm. Heute wartet er auf dich.«","choices":[
		["ask","Nach ihrer gemeinsamen Geschichte fragen","smith_first",{"bonds":{"silvanus":2,"sextus":1},"memory":{"fathers_friend":"heard"}}],
		["go","Sextus selbst besuchen","smith_first",{"bonds":{"silvanus":1},"memory":{"fathers_friend":"visit"}}]]},
	"smith_first": {"day":2,"phase":"morning","npc":"sextus","title":"Sextus öffnet seine Werkstatt","text":"Sextus winkt dich an seine Werkbank. »Silvanus ist mein bester Freund. Für seinen Jungen finde ich Zeit.« Er zeigt auf einen lockeren Griff. »Ob Hammer oder Schwert: Wenn der Griff nachgibt, hilft dir alle Kraft nichts. Heute sehen wir uns an, wie Holz und Eisen zusammenhalten.«","choices":[
		["help","Bei den Werkzeuggriffen helfen","smith_material",{"bonds":{"sextus":2},"memory":{"smith_offer":"accepted"}}],
		["observe","Zunächst nur zuschauen und Fragen stellen","smith_account",{"bonds":{"sextus":1},"memory":{"smith_work":"observed"}}]]},
	"smith_material": {"day":2,"phase":"afternoon","npc":"silvanus","title":"Zwei Stücke gutes Holz","text":"Silvanus streicht über die bereitgelegten Holzstücke. »Zwei braucht Sextus für die Griffe. Such die vereinbarte Menge heraus und bring sie ihm.« Er mustert dich. »Und wenn etwas fehlt, sag es ihm. Dein Wort ist mehr wert als eine Ausrede.«","choices":[
		["take","2 Holz für Sextus aus dem Vorrat nehmen","smith_work",{"goods":{"wood":-2},"cargo":{"billets":2},"memory":{"smith_material":"taken"}}],
		["none","Ohne Material zurückgehen und es erklären","smith_account",{"memory":{"smith_work":"no_material"}}]]},
	"smith_work": {"day":2,"phase":"afternoon","npc":"sextus","title":"Die erste gemeinsame Arbeit","text":"Beim ersten Griff führt Sextus deine Hand. Beim zweiten tritt er einen Schritt zurück. Das Holz sitzt schief, und unter deinen Fingern spannt sich eine Faser. »Sieh hin, bevor du Kraft brauchst«, sagt er. Der Hammer liegt bereit; Sextus wartet, wie du weiterarbeitest.","choices":[
		["careful","Den Ansatz prüfen und den Griff sauber einpassen","smith_account",{"requires_cargo":{"billets":2},"cargo":{"billets":-2},"goods":{"denarii":1},"bonds":{"sextus":3},"memory":{"smith_work":"sound"}}],
		["rush","Den schiefen Griff mit Gewalt festschlagen","smith_account",{"requires_cargo":{"billets":2},"cargo":{"billets":-2},"bonds":{"sextus":-1},"memory":{"smith_work":"split"}}]]},
	"smith_account": {"day":2,"phase":"afternoon","npc":"sextus","title":"Ein Fehler beendet keine Freundschaft","text":"Sextus betrachtet die Griffe und lässt dich zuerst sprechen. »Erzähl mir, wie du es gemacht hast.« Er fährt mit dem Daumen über das Holz. »Für saubere Arbeit gibt es den vereinbarten Denar. Und wenn etwas schiefgeht, sehen wir gemeinsam nach. Dein Vater und ich haben auch klein angefangen.«","choices":[
		["truth","Offen sagen, was du getan hast","day2_evening",{"bonds":{"sextus":2},"memory":{"smith_honesty":"truth"}}],
		["excuse","Die Verantwortung auf das Material schieben","day2_evening",{"bonds":{"sextus":-1},"memory":{"smith_honesty":"excuse"}}]]},
	"day2_evening": {"day":2,"phase":"evening","npc":"silvanus","title":"Was Sextus dir mitgibt","text":"Silvanus rückt näher, als du von der Schmiede anfängst. »Hat er wieder gesagt: Sieh hin, bevor du Kraft brauchst?« Er lächelt. »Den Satz kenne ich gut.« Julia stellt den Krug zwischen euch. »Und du? Möchtest du morgen wieder zu ihm?«","choices":[
		["return","Erzählen und einen weiteren Besuch vorhaben","day2_sleep",{"bonds":{"silvanus":2,"julia":1},"memory":{"evening2":"return"}}],
		["uncertain","Die eigenen Zweifel offen ansprechen","day2_sleep",{"bonds":{"silvanus":1,"julia":1},"memory":{"evening2":"uncertain"}}]]},
	"day2_sleep": {"day":2,"phase":"evening","npc":"","place":"home","title":"Ruhe im vertrauten Haus","text":"Du streichst die Decke glatt. Durch die Tür hörst du Julia und Silvanus noch leise miteinander reden. In deinen Gedanken klingt Sextus' Stimme nach. Morgen steht seine Werkstatt wieder offen.","choices":[["sleep","Schlafen · dritter Morgen","smith_second",{"close_day":true}]]},
	"smith_second": {"day":3,"phase":"morning","npc":"sextus","title":"Der Stock von damals","text":"Sextus nimmt einen abgenutzten Übungsstock von der Bank. »Mit dem haben dein Vater und ich als Jungen geübt. Silvanus wollte immer schneller sein als ich.« Er lacht kurz. »Ich kann ihn dir leihen. Zuerst sprechen wir über deinen Stand und darüber, wie viel Platz du um dich brauchst.«","choices":[
		["borrow","Den Übungsstock von Sextus ausleihen","smith_practice",{"equipment":{"practice_staff":"loaned"},"bonds":{"sextus":2},"memory":{"training_permission":"granted"}}],
		["watch","Erst zuhören und zusehen","smith_practice",{"bonds":{"sextus":1},"memory":{"training_permission":"observe"}}]]},
	"smith_practice": {"day":3,"phase":"morning","npc":"sextus","title":"Sextus nimmt sich Zeit","text":"»Beim Schwert darf dich die Hand nicht aus dem Gleichgewicht ziehen«, erklärt Sextus. »Hinter einem Schild musst du noch sehen, was neben dir geschieht. Und ein Speer braucht mehr freien Raum, als man zuerst glaubt.« Er deutet auf deine Füße. »Wir fangen hier an: ruhig stehen, Abstand halten, aufeinander achten.«","choices":[
		["listen","Mit Sextus über Stand, Abstand und Deckung sprechen","market_offer",{"bonds":{"sextus":2},"memory":{"smith_practice":"introduced"}}],
		["stop","»Für heute möchte ich aufhören.«","market_offer",{"memory":{"smith_practice":"paused"}}]]},
	"market_offer": {"day":3,"phase":"afternoon","npc":"cassia","title":"Eine Lieferung für die Felder","text":"Cassia zieht das Tuch über einen Korb. »Drei Rationen für die Leute auf den Feldern. Silvanus geht ein Stück mit dir. Wenn das Essen dort angekommen ist, bekommst du einen Denar.« Sie legt die Hand auf den Henkel. »Traust du dir den Weg heute zu?«","choices":[
		["accept","3 Getreide übernehmen und die Lieferung begleiten","delivery_road",{"goods":{"grain":-3},"cargo":{"field_food":3},"bonds":{"cassia":1},"memory":{"delivery":"accepted"}}],
		["decline","Die Lieferung ablehnen","day3_evening",{"memory":{"delivery":"declined"}}]]},
	"delivery_road": {"day":3,"phase":"afternoon","npc":"","place":"east","title":"Mit Vater auf dem Feldweg","text":"Silvanus wartet an der Oststraße. Als du näherkommst, klappert der Verschluss am Korb. Dein Vater geht in die Hocke. »So hält das nicht bis zum Feld. Komm, wir können ihn zusammen festmachen.« Hinter euch hebt ein vorbeifahrender Wagen Staub vom Weg.","choices":[
		["secure","Den Verschluss mit Vater sichern","delivery_field",{"bonds":{"silvanus":2},"memory":{"delivery_care":"secured"}}],
		["abandon","Den offenen Korb zurücklassen und den Verlust melden","delivery_account",{"requires_cargo":{"field_food":3},"cargo":{"field_food":-3},"memory":{"delivery":"lost"}}]]},
	"delivery_field": {"day":3,"phase":"afternoon","npc":"julia","title":"Essen für die Feldarbeiter","text":"Julia winkt dir vom Feldrand zu. Die Leute haben ihre Arbeit unterbrochen; einer reibt sich mit dem Handrücken über die Stirn. »Da kommt unser Essen«, sagt deine Mutter. Sie öffnet mit dir den Korb und zählt die drei Rationen ab.","choices":[["deliver","Die drei Rationen abgeben","delivery_account",{"requires_cargo":{"field_food":3},"cargo":{"field_food":-3},"bonds":{"julia":2},"memory":{"delivery":"delivered"}}]]},
	"delivery_account": {"day":3,"phase":"afternoon","npc":"cassia","title":"Eine Zusage und ihre Folgen","text":"Cassia legt ihre Arbeit beiseite. »Nun? Sind die Rationen angekommen?« Ihr Blick wandert vom Korb zu dir. »Für eine abgelieferte Bestellung halte ich meinen Preis. Wenn etwas schiefgegangen ist, sag es mir geradeheraus.«","choices":[
		["paid","Die abgegebene Lieferung abrechnen · 1 Denar","day3_evening",{"if_memory":{"delivery":"delivered"},"goods":{"denarii":1},"bonds":{"cassia":2},"memory":{"delivery":"paid"}}],
		["loss","Cassia den Verlust eingestehen","day3_evening",{"if_memory":{"delivery":"lost"},"bonds":{"cassia":-1},"memory":{"delivery":"loss_reported"}}]]},
	"day3_evening": {"day":3,"phase":"evening","npc":"julia","title":"Drei Becher am Tisch","text":"Julia füllt die Becher, während Silvanus erzählt, wie Sextus als Junge mit einem Sack Kohle in den Bach fiel. »Und wer hat ihn herausgezogen?« Julia hebt eine Augenbraue. Dein Vater lacht. Für eine Weile gibt es nur den warmen Tisch, eure Stimmen und Geschichten, die du noch nicht kennst.","choices":[
		["stay","Bei den Eltern bleiben und zuhören","day3_sleep",{"bonds":{"julia":3,"silvanus":3,"sextus":1},"memory":{"family_evening":"shared"}}],
		["ask","Nach Vaters und Sextus' Jugend fragen","day3_sleep",{"bonds":{"silvanus":3,"sextus":2},"memory":{"family_evening":"their_youth"}}]]},
	"day3_sleep": {"day":3,"phase":"evening","npc":"","place":"home","title":"Unter dem vertrauten Dach","text":"Das Lachen am Tisch ist verstummt. Julia sammelt die Becher ein, und Silvanus wünscht dir eine gute Nacht. Du kannst dich schlafen legen oder noch einmal nach draußen gehen. Über den Dächern wird es dunkel.","choices":[["sleep","Schlafen · vierter Morgen","healer_request",{"close_day":true}]]},
	"healer_request": {"day":4,"phase":"morning","npc":"aurelia","title":"Valeria braucht Ruhe","text":"Aurelia stellt einen Krug neben Valerias Lager. »Sie bleibt heute hier. Severus kümmert sich um den Posten.« Sie senkt die Stimme. »Eine Ration würde ihr guttun. Du kannst auch einfach nach ihr sehen und die Nachricht weiterbringen.«","choices":[
		["food","Eine vorhandene Ration für die Kranken geben","father_promise",{"goods":{"grain":-1},"bonds":{"aurelia":2},"memory":{"sick_guard":"helped"}}],
		["visit","Nach Valeria sehen und die Nachricht weitergeben","father_promise",{"bonds":{"aurelia":1},"memory":{"sick_guard":"visited"}}]]},
	"father_promise": {"day":4,"phase":"morning","npc":"silvanus","title":"»Komm heute Abend wieder.«","text":"Silvanus hört dir zu, ohne dich zu unterbrechen. »Geh nur mit Varro und Severus. Wenn dir etwas unklar ist, komm zu mir oder Sextus.« Er legt dir die Hand auf die Schulter. »Und heute Abend erzählst du uns davon. Versprochen?«","choices":[["promise","Vater versprechen, am Abend zurückzukommen","smith_third",{"bonds":{"silvanus":2},"memory":{"father_promise":"made"}}]]},
	"smith_third": {"day":4,"phase":"morning","npc":"sextus","title":"Noch einmal bei Sextus","text":"Sextus begrüßt dich mit einem Nicken. »Dein Vater hat gefragt, wie es dir bei mir gefällt.« Ihr kommt noch einmal auf Schwert, Schild und Speer zu sprechen. »Jedes verlangt etwas anderes von dir. Aber mit jedem musst du auf die Menschen neben dir achten.« Er lächelt. »Das würde Silvanus auch sagen.«","choices":[
		["return","Den ausgeliehenen Stock zurückgeben","patrol_brief",{"if_equipment":{"practice_staff":"loaned"},"equipment":{"practice_staff":"returned"},"bonds":{"sextus":2},"memory":{"smith_last_visit":"returned"}}],
		["buy","Den Stock mit verdientem Geld kaufen · 1 Denar","patrol_brief",{"if_equipment":{"practice_staff":"loaned"},"goods":{"denarii":-1},"equipment":{"practice_staff":"owned"},"bonds":{"sextus":2},"memory":{"smith_last_visit":"bought"}}],
		["talk","Über das Gelernte sprechen","patrol_brief",{"bonds":{"sextus":2},"memory":{"smith_last_visit":"talked"}}]]},
	"patrol_brief": {"day":4,"phase":"afternoon","npc":"severus","title":"Mit Varro durchs Dorf","text":"Severus beschreibt den Weg: zur Südpforte, an die Oststraße und zurück zum Nordposten. »Varro geht mit dir. Haltet die Augen offen und berichtet mir, was ihr seht. Niemand läuft allein einer Spur hinterher.« Er deutet zum Posten. »Wenn du die Runde nicht mitgehen willst, bring mir dort die Nachricht.«","choices":[
		["join","Mit Varro die vereinbarte Runde gehen","patrol_south",{"bonds":{"severus":1,"varro":1},"memory":{"patrol":"joined"}}],
		["message","Statt der Runde nur die Nachricht am Posten abgeben","watchpost_help",{"memory":{"patrol":"message"}}]]},
	"patrol_south": {"day":4,"phase":"afternoon","npc":"","place":"south","title":"Was am Tor wirklich auffällt","text":"Varro bleibt an der Südpforte stehen. Im Staub biegt eine Wagenfährte vom Weg ab. Er geht in die Hocke und wartet, bis du neben ihm bist. »Was erkennst du? Nimm dir Zeit.« Danach führt eure Runde zur breiten Oststraße.","choices":[
		["observe","Die Spur mit Varro vergleichen","patrol_east",{"bonds":{"varro":2},"memory":{"patrol_south":"observed"}}],
		["unsure","Die Unsicherheit zugeben","patrol_east",{"bonds":{"varro":1},"memory":{"patrol_south":"uncertain"}}]]},
	"patrol_east": {"day":4,"phase":"afternoon","npc":"","place":"east","title":"Hufspuren im Staub","text":"An der Oststraße liegen frische Hufabdrücke über älteren Radspuren. Varro betrachtet sie mit dir. »Pferde waren hier. Das können wir sagen. Wer sie ritt und wohin sie wollten, wissen wir noch nicht.« Er richtet sich auf. »Genau so berichtest du es Severus.«","choices":[
		["report","Severus die beobachteten Hufspuren genau schildern","watchpost_help",{"bonds":{"varro":1},"memory":{"patrol_east":"accurate"}}],
		["invent","Behaupten, schon zu wissen, was die Spuren bedeuten","watchpost_help",{"bonds":{"varro":-1},"memory":{"patrol_east":"exaggerated"}}]]},
	"watchpost_help": {"day":4,"phase":"afternoon","npc":"severus","title":"Eine Nachricht und ein Becher Wasser","text":"Am Nordposten hört Severus deinen Bericht an. Du reichst das Wasser weiter, während er nachfragt. Schließlich nickt er. »Gut, dass du gekommen bist. Hier übernehmen wir. Geh zu deinen Eltern; sie warten bestimmt schon.«","choices":[["report","Die Nachricht abgeben und beim Wasser helfen","day4_evening",{"bonds":{"severus":2},"memory":{"watchpost":"helped"}}]]},
	"day4_evening": {"day":4,"phase":"evening","npc":"julia","title":"Morgen ist auch noch Zeit","text":"Silvanus ist schon am Tisch, als du heimkommst. Julia fragt nach der Runde. »Sextus wartet morgen wieder auf dich«, sagt dein Vater. »Vielleicht schaue ich mit vorbei.« Er greift nach seinem Becher, als wäre morgen ein Tag wie jeder andere.","choices":[
		["share","Mit beiden Eltern über den Tag sprechen","day4_sleep",{"bonds":{"julia":2,"silvanus":2},"memory":{"last_evening":"shared"}}],
		["embrace","Die Nähe der Familie suchen","day4_sleep",{"bonds":{"julia":3,"silvanus":2},"memory":{"last_evening":"close"}}]]},
	"day4_sleep": {"day":4,"phase":"evening","npc":"","place":"home","title":"Die Nacht am vertrauten Ort","text":"Julia wünscht dir eine gute Nacht. Du hörst, wie Silvanus den Riegel vor die Tür schiebt. Noch eine Weile dringen Schritte aus der Gasse herein, dann wird es still. Unter diesem Dach hast du dich immer sicher gefühlt.","choices":[["sleep","Mich zu Hause schlafen legen","night_decision",{"close_day":true,"memory":{"night_unlocked":"yes"}}]]},
	"night_decision": {"day":4,"phase":"night","npc":"julia","title":"Hufe in der Dunkelheit","text":"Hufschläge reißen dich aus dem Schlaf. Julia beugt sich über dich; Silvanus steht an der Tür. Draußen schreit jemand nach Hilfe. »Bleib bei uns«, flüstert deine Mutter. Dein Vater sieht zwischen dir und der Tür hin und her. Gehst du hinaus, um zu helfen, oder suchst du mit beiden Eltern im Haus Schutz?","choices":[
		["defend","Hinausgehen und bei Verteidigung oder Rettung helfen","night_mother",{"memory":{"night_choice":"defend"}}],
		["hide","Mich mit beiden Eltern im Haus verstecken","night_hidden",{"memory":{"night_choice":"hide"}}]]},
	"night_mother": {"day":4,"phase":"night","npc":"julia","title":"Ein Weg für Julia","text":"Julia steht im Familienhaus und lauscht auf die Gasse. »Nebenan, in der Backstube, finden wir Schutz. Du kennst den Weg.« Ihre Stimme zittert. »Komm zu mir. Dann geh vor und bleib so nahe, dass ich dich sehen kann.«","choices":[["escort","Julia persönlich zum Nachbarhaus begleiten","night_escort",{"memory":{"mother_escort":"started"}}]]},
	"night_escort": {"day":4,"phase":"night","npc":"","place":"refuge","title":"Die kurze Gasse zum Schutzort","text":"Julia folgt dir durch die kurze Gasse. Bei jedem Ruf vom Dorfweg sieht sie sich um. Die Tür des Nachbarhauses liegt vor euch. Führe sie hinein und lass ihr Platz, damit sie ganz durch den Eingang kommen kann.","choices":[["arrive","Julia im Nachbarhaus beruhigen: »Du bist in Sicherheit.«","night_wait",{"memory":{"mother_escort":"safe"}}]]},
	"night_wait": {"day":4,"phase":"night","npc":"","place":"refuge","title":"Die Nacht ist noch nicht vorbei","text":"Julia ist im Nachbarhaus. Von draußen dringen Schritte, Rufe und das Schlagen von Metall herein. Für einen Augenblick hältst du den Atem an. Noch immer ist nicht zu erkennen, ob die Wache den Weg halten kann.","choices":[]},
	"night_hidden": {"day":4,"phase":"night","npc":"","place":"home","title":"Mit den Eltern im Versteck","text":"Ihr kauert dicht beieinander im Familienhaus. Julia hält deinen Arm. Silvanus hebt einen Finger an die Lippen, als Schritte vor der Tür stehen bleiben. Du erkennst seine Hand selbst im Dunkeln. Draußen verstummt eine Stimme, die du eben noch gehört hast.","choices":[]},
	"grief_aurelia": {"day":5,"phase":"morning","npc":"aurelia","title":"Wer am Morgen fehlt","text":"Aurelia sieht dich lange an, bevor sie spricht. »Es tut mir leid. Dein Vater ist gefallen. Sextus auch.« Du wartest auf einen weiteren Satz, der es ungeschehen macht. Doch sie bleibt bei dir und lässt dir Zeit, bis du wieder etwas sagen kannst.","choices":[["listen","Aurelia zuhören","father_memory",{"memory":{"loss_heard":"yes"}}]]},
	"father_memory": {"day":5,"phase":"morning","npc":"","place":"home","title":"Vaters Platz","text":"Vaters Platz am Tisch ist leer. Du siehst seine Hände vor dir: wie sie Lasten trugen, den Becher hielten und dir über den Kopf strichen. Gestern hat er noch von morgen gesprochen. Du bleibst stehen, als könntest du jeden Moment seinen Schritt an der Tür hören.","choices":[["remember","Bei Vaters Platz verweilen","smith_memory",{"memory":{"father_remembered":"yes"}}]]},
	"smith_memory": {"day":5,"phase":"morning","npc":"","place":"smith","title":"Die stille Werkstatt","text":"Die Werkbank steht da, als würde Sextus gleich zurückkommen. Du erinnerst dich an seine Hand neben deiner und an den Satz, den auch Silvanus kannte: »Sieh hin, bevor du Kraft brauchst.« Zum ersten Mal antwortet dir in dieser Werkstatt niemand.","choices":[["remember","An Sextus und seinen Freund Silvanus denken","survivor_visit",{"memory":{"smith_remembered":"yes"}}]]},
	"survivor_visit": {"day":5,"phase":"morning","npc":"","place":"refuge","title":"Was von der Familie bleibt","text":"Du kehrst zum Nachbarhaus zurück. An der Tür hältst du inne. In der Nacht war dieser Weg kaum zu erkennen; jetzt liegt jeder Stein offen vor dir. Du suchst nach Julias Stimme.","choices":[["accept","Einen Moment am Schutzort bleiben","marcus_after",{"memory":{"family_fate_seen":"yes"}}]]},
	"marcus_after": {"day":5,"phase":"afternoon","npc":"marcus","title":"Was du ihm antwortest","text":"Marcus wartet am Dorfweg. Er steht erst ein paar Schritte entfernt, dann kommt er näher. »Was wirst du jetzt tun?« Du blickst zur Schmiede und denkst an Silvanus und Sextus. Die Worte, die du suchst, gelten ihnen.","choices":[["vow","»Ich werde euch rächen. Ich finde die Verantwortlichen.«","departure",{"memory":{"revenge_vow":"sworn"}}]]},
	"departure": {"day":5,"phase":"afternoon","npc":"","place":"east","title":"Mit dem Schwur auf den Weg","text":"An der Oststraße bleibst du noch einmal stehen. Hinter dir liegen das Haus deiner Eltern und Sextus' Werkstatt. Du kennst die Namen der Verantwortlichen noch nicht. Aber deinen Entschluss hast du gefasst: Du wirst sie finden und Silvanus und Sextus rächen.","choices":[["leave","Den Schwur mit auf den Weg nehmen","journey",{"memory":{"departure":"chosen"}}]]},
	"journey": {"day":5,"phase":"afternoon","npc":"","place":"east","title":"Der Schwur bleibt","text":"Der Wind trägt Staub über den Dorfweg. Manche Stimmen wirst du hier nie wieder hören; andere Menschen warten noch auf dich. Du nimmst die Erinnerung an Silvanus und Sextus mit. »Ich werde euch rächen.« Du weißt noch nicht, wie weit dich dieser Schwur führen wird.","choices":[]}
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
		value += "\n\n" + {"delivered":"Vater hat den Essenskorb bekommen. Für einen Moment konnte er die Arbeit liegen lassen.","lost":"Der Korb ging unterwegs verloren. Es fällt dir schwer, deinen Eltern davon zu erzählen.","declined":"Julia hat das Essen auf einem anderen Weg zu Vater geschickt.","explained":"Du hast Vater selbst gesagt, warum du den Korb nicht bringen wolltest."}.get(state.memories.get("meal",""),"")
	if state.scene_id in ["smith_account","smith_third","day2_evening"]:
		value += "\n\n" + {"sound":"Die beiden Griffe sitzen fest. Sextus hat dir den vereinbarten Denar für deine Arbeit gegeben.","split":"Der schief eingeschlagene Griff ist gerissen. Du erinnerst dich an die gespaltenen Fasern unter Sextus' Daumen.","observed":"Bei deinem ersten Besuch hast du Sextus zugesehen und Fragen gestellt.","no_material":"Du bist ohne Holz zurückgekommen. Sextus hat sich trotzdem Zeit für deine Fragen genommen."}.get(state.memories.get("smith_work",""),"")
	if state.scene_id in ["grief_aurelia","survivor_visit"]:
		value += "\n\n" + ("Julia ist im Nachbarhaus in Sicherheit. Ihr Blick sucht immer wieder die Tür, als müsste Silvanus gleich hereinkommen." if state.night_raid.outcome=="mother_survived" else "Auch Julia ist in dieser Nacht gestorben. Du erinnerst dich an ihren Arm neben dir im Versteck. Nun bleiben eure Plätze am Familientisch leer.")
	if state.scene_id=="marcus_after":
		value += "\n\n" + _friend_memory(state)
	return value.strip_edges()


static func _visit_text(data: Dictionary, id: String) -> String:
	var state: Dictionary = data.village.childhood
	if id=="sextus":
		return "Sextus sieht von der Werkbank auf. »Da bist du ja. Für Silvanus' Jungen bleibt immer ein Platz bei mir.«\n" + {"sound":"Er erinnert dich an die sauber eingepassten Griffe.","split":"Er zeigt dir noch einmal die gerissenen Fasern und gibt dir eine zweite Chance.","observed":"Er erinnert sich an deine Fragen beim ersten Besuch."}.get(state.memories.get("smith_work",""),"»Was möchtest du wissen?«, fragt er und schiebt dir einen Platz an der Werkbank frei.")
	if id=="silvanus":
		return "Silvanus sieht dich aufmerksam an. »Wenn etwas ist, komm zu mir. Hörst du?« Dann fragt er nach deinem Tag und nach Sextus. Er lässt dich ausreden."
	if id=="julia":
		return "Julia hält deine Hand einen Augenblick länger fest. »Bleib noch etwas bei mir.« Als ihr von Silvanus und Sextus sprecht, wird ihre Stimme leise." if state.night_raid.outcome=="mother_survived" else "Julia rückt den Krug zur Seite und macht dir Platz. »Setz dich. Was ist los?« Sie wartet, bis du die richtigen Worte findest."
	if id=="marcus":
		return _friend_memory(state)
	return "%s erkennt dich und wendet sich dir zu. Ihr kommt auf eure letzte Begegnung zu sprechen." % _name(id)


static func _friend_memory(state: Dictionary) -> String:
	return {"cleared":"»Am Brunnen hast du zu mir gehalten«, sagt Marcus. »Das habe ich nicht vergessen.«","honest":"Marcus erinnert sich an den Brunnen. »Du hast gesagt, dass du es nicht sicher weißt. Das war mir lieber als eine glatte Lüge.«","accused":"Marcus vermeidet erst deinen Blick. Der Streit am Brunnen steht noch zwischen euch."}.get(state.memories.get("friend_result",""),"Marcus zögert, dann tritt er näher. »Wenn du reden willst, ich bin hier.«")


static func _result_text(scene: String, choice: String, state: Dictionary) -> String:
	if scene.begins_with("day") and scene.ends_with("sleep"):
		return "Du legst dich zur Ruhe. " + str(SCENES[state.scene_id].title)
	if scene=="night_decision":
		return "" + ("»Ich lasse euch nicht allein«, sagst du. Draußen rufen die Nachbarn nach Hilfe." if choice=="defend" else "Du bleibst bei deinen Eltern. Gemeinsam sucht ihr Schutz im Haus.")
	if scene=="night_escort":
		return "Julia ist drinnen. Du hörst sie zum ersten Mal wieder ruhig ausatmen."
	return "" + str(SCENES[state.scene_id].title)


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
