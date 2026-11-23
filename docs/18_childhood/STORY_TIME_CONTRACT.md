# Kindheit, Familie, Zeit und endgültige Folgen

Stand: 23. November 2026. Implementierung für Chat B auf dem isolierten Zweig
`feature/chat-b-village-world-20261123`, Ausgangspunkt
`2909040deeb33b99ad4180b884b38921f28233a9`.

Diese Datei beschreibt tatsächlich ausführbaren Quellcode und die unten
genannten Prüfungen. Die vom Nutzer genannten vier Stunden sind ein Maßstab für
den weiteren dramaturgischen Ausbau. Es gibt hier weder vier Stunden fertigen
Film noch einen Nachweis dieser Spielzeit.

## Vorhandener Handlungsbogen

`prototype/scripts/story/childhood_story.gd` enthält einen Katalog von 43 Szenen.
Entscheidungen wählen darin unterschiedliche Wege; eine Partie spielt nicht
automatisch alle Varianten ab. Vier ausdrücklich abgeschlossene Dorftage führen
zur Nachtentscheidung. Der fünfte erzählte Morgen behandelt die tatsächlich
entstandenen Verluste, Erinnerungen, den Racheschwur und den Aufbruch.

| Abschnitt | Tatsächliche Handlungen und Rückbezüge |
| --- | --- |
| Erster Tag | Zu Hause mit Julia sprechen; einen realen Essenskorb übernehmen oder ablehnen; Silvanus aufsuchen; Marcus beim verlorenen Riemen helfen oder ablehnen; Beobachtung, Unsicherheit oder unbelegte Anschuldigung; gemeinsamer Abend. |
| Zweiter Tag | Silvanus erzählt von seinem besten Freund Sextus; persönliche Einladung in die Werkstatt; echtes Material übernehmen; brauchbare oder misslungene Arbeit; ehrliche Erklärung oder Ausrede; erneutes Familiengespräch. |
| Dritter Tag | Erneuter Besuch bei Sextus; Übungsstock ausdrücklich ausleihen oder zunächst beobachten; Sicherheitsunterweisung; eine reale Lebensmittelkiste begleiten, verlieren oder abliefern; einmalige Bezahlung; persönlicher Familienabend. |
| Vierter Tag | Aurelia und die erkrankte Valeria; klare Grenzen der beaufsichtigten Hilfe; Vaters persönliche Zusage; dritter Besuch bei Sextus; Übungsstock zurückgeben, kaufen oder weiter darüber sprechen; Kontrollpunkte mit Varro oder alternative Nachrichtenhilfe; Rückkehr zur Familie. |
| Nacht | Bewusste Entscheidung zwischen tatsächlicher Hilfe und gemeinsamem Verstecken; gespeicherter Reiteranritt; vorhandener spielbarer Dorfangriff; reale Rettung über zwei Orte oder tatsächlich beobachtete Kampf-/Rettungshandlung; einmaliger endgültiger Ausgang. |
| Folgetag | Aurelia berichtet; Vaters Platz und Sextus' Werkstatt werden als Erinnerungsorte besucht; das Schicksal der Mutter bleibt sichtbar; Marcus erinnert sich an die frühe Beziehung; ausdrücklicher Racheschwur und Aufbruch ohne Alters- oder Rangwechsel. |

Eine misslungene Arbeit zahlt keinen Lohn. Eine übernommene, verlorene Lieferung
bleibt ein echter Ressourcenverlust. Ablehnungen führen zu anderen Gesprächen
und einer weiterhin erreichbaren Fortsetzung. Persönliche Wiederbesuche sind
möglich, vergeben aber keine wiederholten Belohnungen.

Die Unterweisung bei Sextus öffnet einen gespeicherten Erlaubnis- und
Ausrüstungszustand. Sie behauptet keine bereits durch den Spieler ausgeführten
Kampftechniken. Die zugehörigen Bewegungs- und Technikfunktionen bleiben die
Schnittstelle zu Chat A.

## Dieselben Menschen, keine zusätzlichen Elternmodelle

| Rolle | Bestehende Kennung | Verbindlicher Zustand |
| --- | --- | --- |
| Mutter | `julia` | Bestehende Bäuerin; bei einem neuen Lebensweg zugleich Mutter. |
| Vater | `silvanus` | Bestehender Lastenträger; bester Freund von Sextus. |
| Schmied | `sextus` | Bestehende Person; neue Kindheitswelt bezeichnet seinen Beruf als Schmied. |
| Freund | `companion.id`, in Italia `marcus` | Bestehende Gefährtenfigur; keine zweite Figur in der Wirtschaft. |
| Heilerin | `aurelia` | Dieselbe Bewohnerin vor und nach der Nacht. |

Die Einwohnerliste behält ihre vierzehn Kennungen. Der neue Anfang verwendet die
bereits stehenden Dorfgebäude. Es wird kein angeblich vom Spieler gebautes Haus
in die alte Baukostenbilanz eingetragen. Decimus bleibt Verwalter.

Die Startvorräte des bestehenden Dorfes ergänzen einmalig 12 Holz, 16 Getreide
und 8 Stein. `childhood.ledger` belegt diese Herkunft zusätzlich zur bisherigen
Grundausstattung. Arbeitsstätten beginnen baulich intakt. Vorhandene Personen
besetzen die laufenden Arbeitsplätze. Eltern und Schmied stehen während ihrer
Erzählrollen in keiner zweiten unsichtbaren Produktionsschicht.

Nach der verbindlichen neuen Nutzervorgabe sterben beim endgültigen Nachtübergang
**Silvanus und Sextus in beiden Verläufen**. Bei `hide` stirbt auch Julia. Bei
`defend` überlebt Julia nur nach tatsächlich bestätigtem Einsatz. Die Einträge
derselben Personen erhalten `alive=false`, `health=0`, `assignment="idle"` und
`previous_assignment="idle"`. Tote arbeiten und sprechen nicht weiter. Der
folgende Hauptauftrag führt zu Aurelia oder zu einem Erinnerungsort, nie zu
einem verstorbenen Pflichtsprecher.

## Zeitvertrag

Es gibt zwei ausdrücklich verschiedene Größen:

1. **Aktive Simulationszeit:** `world_seconds` und die bestehenden Dorfuhren
   entwickeln sich nur während ausgeführter Simulation. Die Wirtschaft arbeitet
   weiterhin mit ihren vorhandenen kurzen Arbeits- und Versorgungszyklen.
2. **Erzähltes Datum:** `village.childhood.day` und `phase` folgen den tatsächlich
   bestätigten Szenen. Ein Arbeitszyklus von 120 Sekunden ist in diesem Bogen
   kein automatisch abgeschlossener Kalendertag.

Jeder bestätigte Tagesabschluss speichert den erzählten Tag sowie den damaligen
Wert beider Simulationsuhren in `closed_days`. Der Tagesabschluss schreibt keine
fiktiven acht Stunden Produktion gut. Er löst auch keine Offlineberechnung aus.
Der vierte Tagesabschluss führt zunächst in die Nacht desselben Tages; erst der
einmalige Ausgang öffnet den fünften Morgen.

Der Spieler bleibt während dieses gesamten Bogens zwölf Jahre alt. Seine Rolle
bleibt `child`, `progress.years_elapsed` bleibt null und das Kalenderjahr bleibt
100 n. Chr. Lesen, Pause, eine geschlossene App, freie Bewegung oder mehrere
Minuten Wirtschaftstätigkeit verändern diese Felder nicht. Ein späteres
Älterwerden benötigt einen gesonderten, ausdrücklichen und speicherbaren
Erzählübergang; dieser Arbeitsblock erfindet ihn nicht.

## Nachtentscheidung und tatsächlicher Einsatz

`village.childhood.night_raid` enthält:

| Feld | Bedeutung |
| --- | --- |
| `phase` | `dormant`, `approach`, `attack`, `aftermath`. |
| `elapsed` | Tatsächlich simulierte Sekunden seit dem ausdrücklichen Nachtzweig. |
| `seed` | Gespeicherte deterministische Variante für die Darstellung. |
| `decision` | `pending`, `defend` oder `hide`; kein Timer wählt einen Zweig. |
| `support_confirmed` | Ein tatsächlich ausgeführter Beitrag ist bestätigt. |
| `support_kind` | Leer, `escort` oder `combat`. |
| `consequences_applied` | Endgültige Personenfolgen wurden einmalig übernommen. |
| `outcome` | Leer, `mother_survived` oder `parents_lost`. |

Nach dem vierten Tag bleibt die Sequenz `dormant`, solange die ausdrückliche
Entscheidung fehlt. Nach der Wahl läuft ein gespeicherter 32-Sekunden-Anritt.
Danach beginnt genau der erste Dorfangriff über `VillageLife.begin_childhood_raid`.
Die ursprünglichen Warnungen nach 120 Sekunden und späteren automatischen
Wiederholungen sind bei aktiver Kindheit gesperrt.

Das Öffnen eines Blockfensters zählt nicht als abgewehrter Treffer. Für den
Kampfbeleg werden tatsächliche Treffer, vom Regelmodell beobachtete Blocks oder
Ausweichmanöver beziehungsweise die tatsächliche Dorfrettung verwendet. Die
Wahl »Ich helfe« allein ist kein Beleg.

Die andere Möglichkeit besteht darin, Julia persönlich im Haus zu erreichen und
sie anschließend in das Nachbarhaus zu führen. Ihre Position ist kein Offset am
Spieler. `childhood.escort` speichert Wegfortschritt und tatsächliche X/Z-Position
auf einer festen Route durch beide Türen und die Gasse. Julia läuft höchstens
1,35 Meter pro simulierter Sekunde, folgt erst dem entlang der Route
vorangekommenen Spieler und hält an, wenn dieser sich mehr als 2,8 Meter vom Weg
entfernt. Die Ankunft lässt sich erst bestätigen, wenn sie selbst den
geschützten Innenbereich erreicht hat. Ein vorauseilender oder im Test versetzter
Spieler teleportiert sie nicht.

Die letzte Ankunftsschwelle liegt höchstens 0,45 Meter vor dem inneren Ziel;
damit befindet sich auch Julias vollständige Kapsel mit 0,29 Meter Radius
hinter der Tür. Wartet der Spieler bereits innen, darf sie den gewöhnlichen
Folgeabstand am letzten Schritt aufgeben. Die echte Kollisionsprüfung bleibt
dabei maßgeblich: Ein im Türweg stehender Spieler hält sie weiterhin auf.
Nach der räumlichen Ankunft wechselt das Bestätigungsziel vom Innenort zu
derselben Julia-Kennung. So spricht der Spieler die tatsächlich angekommene
Mutter an, ohne dass ihr eigener Körper den Sichtstrahl zum Ortsziel blockiert.

Zusätzlich übergibt die Welt pro aktivem Bild einen mit der echten Julia-Kapsel
geprüften freien Wegfortschritt an `WorldModel.advance(delta, escort_limit)`.
Das Modell kann diese Grenze unterschreiten, aber nicht überschreiten. Ein
versperrter Eingang oder ein anderer Körper hält Julia daher an, ohne ihre
gespeicherte Identität oder Position zu ersetzen. Der Standardparameter bleibt
für reine Modellprüfungen und bisherige Aufrufer `INF`; die reale Main-Integration
liefert die von `VillageLifeWorld.escort_progress_limit()` bestimmte Grenze und
projiziert anschließend dieselbe Position mit `sync_escort()`.

Wenn der technische Dorfangriff endet, bevor ein gewählter `defend`-Beitrag
geleistet wurde, bleibt die persönliche Rettungsaufgabe erreichbar. Der Timer
erfindet weder Hilfe noch den `hide`-Zweig. Der endgültige Ausgang folgt erst dem
wirklichen Beitrag. Diese begrenzte Lösung hält die Entscheidung ausdrücklich
und verhindert eine versteckte automatische Niederlage während der Erzählung.

Die Darstellung von dreißig Reitern besitzt einen eigenen Darstellungsvertrag.
Dieser Handlungsbaustein verändert den bestehenden Nahkampf nicht in dreißig
gleichzeitig simulierte berittene Kämpfer. Der vorhandene erste Dorfangriff
verwendet weiterhin seine drei spielbaren Angreifer. Ein visueller Zug mit
dreißig Pferden und Reitern ist kein Beleg für dreißig individuelle berittene
Kampf-KIs.

## Befehle, Dialoge und Ziele

Die reale neue Partie verwendet:

```gdscript
model.new_game("italia", true, true)
```

Die vorherige Signatur mit zwei Argumenten behält die bisherige Dorfvariante.
Damit bleiben ältere Prüfungen und ältere Lebenswege nachvollziehbar.

Das Modell bietet `get_childhood_view()`, `get_childhood_objective()` und
`get_childhood_dialog(npc_id="")`. Der Befehl lautet:

```gdscript
model.execute("childhood_choose", {
    "scene_id": "family_morning",
    "choice": "promise"
}, request_id)
```

Die aktuelle Szenenkennung muss exakt übereinstimmen. Jeder Befehl prüft
Voraussetzungen, echte Vorräte und räumliche Nähe. Ein alter Dialog kann daher
nicht die nächste Szene entscheiden oder einen zweiten Lohn erzeugen. Der
globale `command_id`-Vertrag schützt zusätzlich gegen Wiederholung desselben
Transportauftrags.

Ein Ziel liefert `id`, `label`, `npc_id`, `position=[x,z]`, `entrance=[x,z]`,
`kind` und `available`. Der Hauseingang dient der Wegführung; er ersetzt nicht
die Nähe zur wirklichen Person. `VillageLife.actor_position()` und die
Kindheitsziele verwenden dieselbe Quelle. Cassia und Antonias Marktplätze liegen
auf der freien Seite des realen Tisches; Aurelia steht außerhalb der Palisade,
Varro vor dem Haus. Physische Tür-, Boden-, Sicht- und Routenprüfungen gehören
zusätzlich zur Weltintegration.

Alte Befehle für den Sprung auf achtzehn, sofortige Rekrutierung, das alte
Gefährten-/Folgekapitel, Hüttenbau und das Umverteilen erwachsener Arbeitsgruppen
sind während der neuen Kindheit auch im Modell gesperrt. Das Ausblenden einer
Schaltfläche ist nicht die einzige Sperre.

## Zustand, Bilanzen und Speichermigration

Der Weltvertrag steigt von Schema 5 auf Schema 6. Der normale Dateilader ergänzt
bei einem gültigen alten Schema-5-Spielstand ohne Kindheitsabschnitt einen
deaktivierten modernen Abschnitt und den Handelsvertrag. Besitzt der Spielstand
bereits den früheren Bogen aus `village_childhood.gd`, bleibt genau dieser mit
seinen damaligen Personen, Aufträgen, Arbeitszuständen und Bilanzen erhalten.
`childhood_format.gd` unterscheidet beide Formen anhand ihrer vollständigen
Kennfelder. Beide nutzen intern Version 1; allein diese Versionszahl erlaubt
deshalb keine Zuordnung. Gemischte oder unvollständige Formen werden abgelehnt.

Der frühere Kindheitsbogen behält seinen 3.600-Sekunden-Versorgungszyklus, der
neue Bogen und der gewöhnliche Dorfweg ihren bisherigen 120-Sekunden-Zyklus.
Keiner dieser Zyklen ersetzt die ausdrücklichen erzählten Tagesabschlüsse.
Der Lader verändert weder vorhandenes Alter, Szene, Ressourcen, Arbeitszuweisung
noch die Bruchteile der Wirtschaftszeit. Bereits erwachsene Spielstände bleiben
erwachsen. Es wird kein neuer Prolog rückwirkend erzwungen. Bei veröffentlichten
modernen Schema-6-Saves ohne Faustkampffeld ergänzt der Lader einen leeren
optionalen Zustand. Er erfindet keine erlernten Techniken oder Treffer und
überschreibt keine vorhandenen Schläge oder ihre laufende Auflösung.

Die Migrationsprüfung verwendet eingefrorene Start-, Arbeits- und Kampfstände,
die direkt aus dem unveränderten Basiscommit `e5735509622c9a94564dc5fe21257c07074f9df5`
erzeugt wurden. Sie prüft den wirklichen Dateilader, unveränderte Teilzustände,
Fortsetzen im alten Bogen und erneutes Speichern/Laden unter Schema 6.

Die bestehende Ressourcenprüfung addiert jetzt vier getrennt belegte Salden:
Wirtschaft, bisherige Gespräche, Kindheit und Handel. Übernommene Waren werden
aus dem gemeinsamen Vorrat abgebucht und in der gespeicherten Fracht geführt.
Eine Ablieferung gibt diese Waren nicht noch einmal an den Spieler zurück.
Einmalige Arbeitslöhne verwenden im aktuellen Spielvertrag ganze Denare. Diese
Spielbalance ist keine Quellenbehauptung über einen historischen Kinderlohn.
Der Handel kann zusätzlich echte As-Wechselbeträge verwalten; ein Storylohn
überschreibt dieses Kleingeld nicht.

Jede Szenenentscheidung hinterlässt einen unverwechselbaren Beleg aus Szene,
Antwort und beobachteten Uhren. Der Validator rekonstruiert daraus den zulässigen
Szenenweg, Erzählzeit, Abschlussliste, Ressourcenbuchung, Fracht, Ausrüstung,
Beziehungen und Erinnerungen. Er lehnt doppelte Szenen, übersprungene
Voraussetzungen, erfundene Belohnungen, falsche Rettungsbelege und wiederbelebte
Angehörige ab. Die Speicherprüfsumme dient weiterhin der Erkennung beschädigter
Dateien; sie ist keine Sicherheitsgarantie gegen absichtliche Bearbeitung durch
den Besitzer eines Spielstands.

## Tatsächlich ausgeführte Prüfung

Am 23. November 2026 wurde unter Godot 4.7.2 ausgeführt:

```sh
/usr/local/bin/godot --headless --path prototype \
  --script res://tests/childhood_story_test.gd
```

Ergebnis nach der gespeicherten Eskortenbewegung, dem physischen
Fortschrittslimit und der abgesicherten Innenraumankunft: **345 Prüfungen,
null Fehler**. Der vorherige unveränderte
Domain-Prüflauf bestand zusätzlich **329 Prüfungen in zwölf Gruppen**. Der
[aufgezeichnete Terminalabschluss](evidence/childhood_story_terminal.log) enthält
die ausgeführten Befehle und die beobachteten Ergebniszeilen.
Der Lauf enthält beide endgültigen Familienausgänge, einen tatsächlichen
Kampftreffer, einen Block ohne Gegnerkontakt, die physisch getrennten
Rettungsschritte, einen Zwischenstand während Julias Gang, einen nach Ende des
Angriffs noch offenen Hilfsauftrag, vier echte Tagesabschlüsse, misslungene und
abgelehnte Aufgaben, einmalige Löhne, entfernte Ziele, veraltete Dialoge,
Schema-5-Migration eines jungen und eines bereits erwachsenen Lebenswegs sowie
absichtlich beschädigte Zustände.

Diese Prüfung führt das Regelmodell und den normalen Save/Load-Dateipfad aus.
Sie ersetzt keine gerenderte Sichtprüfung oder einen Android-Gerätetest.

Zusätzlich wurde `prototype/tests/childhood_night_integration_test.gd` mit
isolierten XDG-Benutzerverzeichnissen, `IMPERATHEN_ISOLATED_TEST=1` und einer
äußeren Zeitgrenze von 115 Sekunden tatsächlich ausgeführt. Ergebnis:
**231 Prüfungen, null Fehler, Prozessende 0**. Der vollständige
[Standardausgabe-Beleg](evidence/childhood_night_terminal.log) enthält den
Marker `CHILDHOOD_NIGHT_INTEGRATION_PASS`.

Dieser zweite Lauf instanziiert die echte `main.tscn`, das normale WorldModel,
GameWorld und die Spieloberfläche. Die Vorbereitung verwendet ausschließlich
gültige Szenenbefehle. Explizite Test-Reisepositionen verkürzen den Anmarsch;
sie setzen weder Geschichte noch Todeszustände oder Julias Fortschritt. Ab der
Nacht werden die wirklichen Weltinteraktionen und Dialogschaltflächen genutzt.
Julias Weg entwickelt sich ausschließlich über `Main._process`, echte
Kapsel-Kollisionsprüfung und den gespeicherten Modellfortschritt.

Der Lauf prüft beide Entscheidungen bis zum Racheschwur und Aufbruch, fünf
vollständige Main-Neustarts einschließlich Anritt und Gang zwischen den Häusern,
Lesepausen, Nachtlicht bereits vor der Entscheidung, Tageslicht nach den Folgen,
die Sichtbarkeit und Kollisionskörper der tatsächlich gestorbenen Personen,
die unveränderten vierzehn Einwohnerkennungen mit zwölf beziehungsweise elf
Überlebenden sowie das dauerhaft zwölfjährige Kind ohne Rekrutierung. Er
prüft außerdem die vollständige Kapsel hinter der Tür und den weiterhin
erreichbaren Dialog, wenn Julia genau auf dem Endpunkt ihres Weges steht.

Der Lauf hat zunächst zwei reale Übergangslücken nachgewiesen: Tageslicht vor
der ausdrücklichen Nachtentscheidung und eine zu frühe Rettungsbestätigung auf
der Eingangsstufe. Beide sind behoben; die dabei sichtbar gewordene
Selbstverdeckung des Ortsziels ist durch die eindeutige Zielperson beseitigt.
Diese Ergebnisse belegen keine gemessene Spielzeit, Bildrate oder
Temperaturverbesserung und keinen bereits ausgeführten Android-Gerätetest.
