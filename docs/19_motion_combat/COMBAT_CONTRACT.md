# Kampfbuchung und Szenarioprüfung

Stand: 23. November 2026. Diese Ergänzung beschreibt den Code unter
`prototype/scripts/domain/combat_actions.gd` und seine Anbindung an das
bestehende Weltmodell. Die Zahlen sind eigene Spielparameter, keine Messwerte
aus einem anderen Spiel und keine biomechanische Referenz.

## Ein gemeinsamer Zustand

Neue ausdrücklich aktivierte Partien verwenden weiterhin das Welt-Schema 5
mit dem optionalen Eintrag `village.unarmed`. Dessen elf Felder entsprechen dem
bereits im koordinierenden Kindheitszweig vorgesehenen Vertrag Version 1:

`version`, `stamina`, `practice_hits`, `resolved_hits`, `elapsed`, `technique`,
`target_id`, `facing`, `resolved`, `guard_remaining`, `dodge_remaining`.

Es gibt keinen zweiten Gesundheits-, Ausrüstungs- oder Erfahrungsspeicher.
Der integrierte Einstieg besitzt vier Parameter:

```gdscript
WorldModel.new_game(
    origin_id = "italia",
    extended_village = false,
    childhood_enabled = false,
    action_combat = false
)
```

| Aufruf | Familienkindheit | Kampfweg |
| --- | --- | --- |
| `new_game("italia", true, true)` | Neuer Familienstart mit den 35 Kindheitsschritten | `CombatActions` automatisch aktiv |
| `new_game("italia", true, false, true)` | Bisherige Dorfkarriere | `CombatActions` ausdrücklich aktiv |
| `new_game("italia", true)` | Bisherige Dorfkarriere | Bisherige unmittelbare Kampfregeln |
| `new_game()` | Bisheriger regionaler Einstieg | Bisherige unmittelbare Kampfregeln |

Der dritte Parameter bezeichnet die Familienkindheit. Der vierte Parameter
ermöglicht dieselbe moderne Kampfsteuerung zusätzlich in einer älteren
Dorfkarriere. Kindheit und moderner Dorfkampf werden nur bei aktiviertem
erweitertem Dorf und Herkunft `italia` angelegt. Andere Herkünfte erhalten
dadurch keine römische Familiengeschichte.

Neue Kindheitspartien speichern den bestehenden Kindheitszustand einschließlich
Aufträgen, getragenen Gegenständen und Leihstatus unter `village.childhood`.
Bestehende Aufrufe mit zwei Parametern und gespeicherte Partien ohne diese
optionalen Zustände behalten ihre bisherige Regelroute. Beim Laden werden weder
Kindheit noch Ausrüstung nachträglich erfunden. `view(data)` liefert eine tiefe
Präsentationskopie; ihre zusätzlichen Angaben gelangen nicht in den Spielstand.

## Eine Kampfautorität und eine Kompatibilitätsfassade

`combat_actions.gd` besitzt die Regeln, den Technikkatalog und den gespeicherten
Kampfzustand. `unarmed_combat.gd` ist eine reine delegierende Fassade: Konstanten,
Verfügbarkeit, Argumentprüfung, Befehle, Fortschreibung, Abbruch und Sichtdaten
werden an `CombatActions` weitergereicht. Die Fassade enthält keine eigene
Schadensbuchung und keinen zweiten Timer.

`WorldModel.advance` ruft die Kindheitsfortschreibung einmal je übergebenem
Zeitintervall auf. Innerhalb seiner vorhandenen Dorf-Zeitschritte folgen
Dorfleben und genau ein `CombatActions.advance` je Teilschritt. Ein zusätzlicher
Aufruf von `UnarmedCombat.advance` neben diesem Pfad wäre eine doppelte
Fortschreibung und gehört nicht zum Vertrag. Der Schadens-Callback wird nur
vom bestätigten Kontakt der gemeinsamen Autorität aufgerufen.

## Simulationsuhr und Übergänge

`Main._physics_process` besitzt die Weltfortschreibung. In ruhender Kindheit
sammelt es die verstrichene Physikzeit und übergibt sie etwa alle 0,1 Sekunden
an das Modell. Sobald eine Technik, Deckung, Ausweichen oder ein Gefecht aktiv
ist, verarbeitet es jeden Physikschritt; bei 60 Physikschritten pro Sekunde
entspricht das 60 Hz. Ältere Lebenswege bleiben auf ihrem direkten Physiktakt.
Der Renderprozess betreibt Oberfläche, Film und den Auslöser der automatischen
Speicherung.

Vor einem Befehl, einer Pause oder einer Speicherung verarbeitet
`_flush_simulation` die noch ausstehende Zeit. Weitere Unterbrechungen durch
Weltdeaktivierung oder Kameramoduswechsel verwenden denselben synchronen
Flush vor dem Domain-Abbruch. Die angesammelte Ruhezeit darf weder die
Vorbereitung eines erst danach gestarteten Angriffs verkürzen noch nach
Fortsetzen als zusätzliche Pausenzeit auftauchen. Neue Partien und
Ladevorgänge setzen den lokalen Akkumulator zurück.

Die Körperpose liest ausschließlich die normierte Zeit der gespeicherten
Technik. Animation und Geometrieadapter erzeugen keinen zusätzlichen Treffer.
Ein Abbruch muss auch eine noch laufende physische Ausweichbewegung beenden.
Der bei der Rekonstruktion gefundene Restbewegungsfall ist behoben; der
gezielte Adapterlauf ist im Prüfstatus unten gesondert dokumentiert.

## Techniken und Zeitfenster

| Kennung | Vorbereitung | Aktives Fenster | Gesamtdauer | Reichweite | Ausdauer | Benötigte Übungstreffer |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `jab_left` | 0,18 s | 0,14 s | 0,62 s | 1,45 m | 7 | 0 |
| `jab_right` | 0,21 s | 0,14 s | 0,68 s | 1,50 m | 8 | 0 |
| `hook_left` | 0,27 s | 0,16 s | 0,82 s | 1,15 m | 11 | 3 |
| `hook_right` | 0,27 s | 0,16 s | 0,82 s | 1,15 m | 11 | 3 |
| `uppercut_left` | 0,30 s | 0,17 s | 0,90 s | 1,05 m | 13 | 6 |
| `uppercut_right` | 0,30 s | 0,17 s | 0,90 s | 1,05 m | 13 | 6 |
| `headbutt` | 0,23 s | 0,14 s | 0,76 s | 0,85 m | 12 | 8 |
| `front_kick` | 0,34 s | 0,20 s | 1,05 s | 1,75 m | 15 | 4 |
| `side_kick` | 0,40 s | 0,22 s | 1,20 s | 1,85 m | 18 | 10 |
| `high_kick` | 0,44 s | 0,24 s | 1,30 s | 1,65 m | 21 | 14 |

Die verbleibende Zeit ist Erholung. Der gespeicherte Angriff liefert dieselbe
normierte Zeit für die Körperpose. Ein weiterer Angriff während einer laufenden
Bewegung oder Abwehr wird vollständig verworfen. Während dieses Zeitraums
regeneriert die verbrauchte Ausdauer nicht; tatsächliche Ruhe stellt zwölf
Punkte je Sekunde bis zur Grenze 100 wieder her.

## Befehls- und Trefferweg

`village_unarmed_attack` akzeptiert ausschließlich `technique`, `target_id`,
`facing_x` und `facing_z`. `village_unarmed_guard` und
`village_unarmed_dodge` akzeptieren keine zusätzlichen Parameter. Kein Befehl
nimmt einen vom Aufrufer bestimmten Schaden, Erfahrungspreis oder ein erfundenes
Ausrüstungsmerkmal an.

Ein angenommener Angriff bezahlt zuerst die Ausdauer und speichert die Bewegung.
Er verursacht zu diesem Zeitpunkt keinen Schaden. `advance` untersucht erst
das aktive Zeitfenster und benötigt zugleich:

- ein noch lebendes Ziel im tatsächlich aktiven Gefecht;
- einen gültigen Abstand und die gespeicherte Angriffsrichtung;
- einen ausdrücklich bestätigten Sicht-/Kontaktstrahl aus der realen Physikwelt;
- die Zustimmung des bestehenden autoritativen Schadenspfads.

Ohne Geometrie-Callback wird kein Kontakt verbucht. Ohne Schadens-Callback wird
kein Gegner verletzt. Ein Kontakt verbraucht seine Auflösung vor dem Callback;
auch eine zurückgewiesene Buchung wird nicht wiederholt. Ein anfänglich verfehltes
Ziel kann innerhalb des noch offenen Fensters erreichbar werden. In der
Erholungsphase ist das ausgeschlossen.

Der Schaden läuft über `WorldModel._apply_combat_hit`. Dieser verwendet für
Dorfüberfälle `VillageLife.apply_unarmed_hit` und für das ältere kleine Gefecht
dessen vorhandene Gesundheits- und Abschlussregeln. Derselbe letzte tatsächliche
Treffer beendet den jeweiligen Gegnerbestand. Die alten sofortigen
Angriffs-/Übungsbefehle sind in Partien mit aktivierter neuer Steuerung gesperrt.

Deckung und Ausweichen öffnen begrenzte Schutzfenster. Der Tastendruck allein
vergibt keinen Abwehrerfolg. Eingehender tatsächlicher Schaden unterbricht die
laufende Bewegung; Pause und Hintergrundwechsel verwenden dieselbe
Abbruchfunktion. Verbrauchte Ausdauer wird dabei nicht erstattet. Der Ablauf
eines Abwehrfensters entfernt auch seine alte Raid-Projektion, wenn die
Raid-Uhr während des militärischen Gefechts gerade nicht läuft.

## Übung, Ausbildung und Ausrüstung

Der Übungspfahl erhöht `practice_hits` nach demselben Zeit-, Richtungs- und
Geometrienachweis. Ein Luftschlag erhöht keinen Zähler. Ein Übungstreffer verletzt
keinen Gegner und erzeugt keine Teilnahme an einem Überfall.

Kindliche Übung verändert weder das Alter noch die verpflichtenden späteren
Ausbildungstreffer. Der neue Familienabschnitt behält seine eigenen Aufträge,
Gegenstände und Tageswechsel; die bisherige sechsjährige Ausbildungs-Abkürzung
ist dort gesperrt.

Die bestehende erwachsene Ausbildung bleibt für ältere Dorfkarrieren
erreichbar, einschließlich des ausdrücklich mit dem vierten Parameter
aktivierten modernen Kampfwegs. Erst in der tatsächlich erreichten Phase
`training` und ab 18 Jahren übergibt das Weltmodell einen bestätigten
Pfahlkontakt zusätzlich an die bestehende Ausbildungsbuchung. Damit wird
kindliche Übung nicht als abgeschlossene Erwachsenen-Ausbildung angerechnet.

Die Kindheitsgeschichte behält ihren vorhandenen Leihstatus für Helm und
Holzschild. Dieser Status und seine Darstellung sind unabhängig von
`set_equipment(false, false)` für den unbewaffneten Angriffskatalog. Ein
geliehener Gegenstand schaltet deshalb keinen Waffenangriff frei. Schwert-,
Schild- und sonstige Waffenangriffe gehören nicht zum freigegebenen Katalog
dieser unbewaffneten Steuerung.

## Historische Prüfungen des Ausgangsstands

Die folgende Tabelle dokumentiert die bereits ausgeführten Prüfungen des
veröffentlichten Ausgangsstands
`5d95676626d8eeee5589973603cb1da523ca4970`. Sie ist kein Ergebnis der
anschließenden Integration mit dem Kindheitsstand
`e5735509622c9a94564dc5fe21257c07074f9df5`.

Diese gezielten Läufe wurden damals mit Godot 4.7.2 tatsächlich ausgeführt.
Die vier bestehenden Main-Szenariotests erhielten eigene temporäre
XDG-Verzeichnisse und `IMPERATHEN_ISOLATED_TEST=1`. Die Modellprüfung verwendet
einen eigenen temporären Speicherordner und entfernt ihn wieder; die kurze
Adapterprüfung schreibt keinen Spielstand.

| Prüfung | Ergebnis | Wesentlicher Nachweis |
| --- | ---: | --- |
| `combat_actions_test.gd` | 171 / 171 | Zeitfenster, zehn Techniken, Reichweite, Richtung, fehlende/ablehnende Geometrie, Zielzustand, einzelner Kontakt, Ausdauer, Unterbrechung, v1-Validierung |
| `combat_model_integration_test.gd` | 215 / 215 | Echte Befehle, Wiederholungskennung, Speichern vor/nach Kontakt, Abwehr, Gesundheitsbilanz, vollständiger Raidabschluss, erwachsene Ausbildungsbrücke und Abweisung widersprüchlicher Kampfmodi |
| `action_adapter_test.gd` | 46 / 46 | Echte Weltszene: Kamerawechsel beendet Ausweichbewegung, Treffer-/Todespose bleibt vorrangig, Luftschläge buchen nichts, ein naher Dritter bleibt ein Hindernis, Alt-/Herkunftswechsel entfernt persönliche Kollisionskörper |
| `opening_flow_test.gd` | 37 / 37 | Film, Pause, Zielkarte, Speicherfehler, gespeicherter Altersübergang |
| `frontier_integration_test.gd` | 114 / 114 | Beide Frontier-Kostenpfade, neue tatsächliche Kampf-/Übungshandlungen, Wagenarbeit, Teilzeitspeicherung und Dialoge |
| `integration_test.gd` | 72 / 72 | Einstieg, Bau, Ausbildung, Gefecht, Folgeentscheidung, Backup-Wiederherstellung, Hintergrundpause und regionale Fortsetzung |
| `village_experience_test.gd` | 203 / 203 | Tatsächliche Oberfläche, Arbeit, Mentorbeziehungen, Überfall, Abwehrbewegung, Fortsetzen, Sieg, Erwachsenwerden und benannte Rekrutierung |

Die vier bestehenden Szenariotests verwendeten in diesem Ausgangsstand explizit sowohl
`Main._physics_process` als auch `Main._process`. Ihre automatischen Main-Takte
sind während des kontrollierten Szenarios ausgeschaltet, damit reine Warteframes
für eine Oberfläche nicht unbemerkt Weltzeit hinzufügen. Die vorhandenen
Erfolgs-, Kosten-, Persistenz- und Folgeprüfungen wurden nicht entfernt.

Die vorherigen unmittelbaren `training_hit`-/`strike_enemy`-Testsignale wurden
durch den tatsächlichen UI-Angriff, eine passende Entfernung und Blickrichtung
sowie abgelaufene Kontaktzeit ersetzt. Die höhere Zahl notwendiger Fausttreffer
folgt ihrem tatsächlichen Schaden. Die Tests erteilen keinen kostenlosen Sieg.

Die ausführliche Dorfprüfung deckte zwei veraltete Annahmen ihrer Testaufstellung
auf: Ein festes Teleportziel lag bei einem Angreifer auf der anderen Seite der
nördlichen Palisade; die neue Kontaktprüfung verweigerte den Treffer korrekt.
Der Test sucht nun einen unbesetzten, durch Kapselprüfung und Kontaktstrahl
bestätigten Anlaufpunkt. Außerdem liest `CharacterBody3D.move_and_slide` die
Engine-Physikzeit. Die räumliche Ausweichprüfung wartet deshalb auf echte
Physikframes, statt mehrere Bewegungsaufrufe innerhalb desselben Renderframes
als verstrichene Bewegungszeit zu behandeln.

Die kurze Adapterprüfung schützt zusätzlich konkrete Integrationskorrekturen:
Ein Wechsel zur Stadt- oder Kartenkamera verwirft sowohl den autoritativen
Ausweichzustand als auch seine noch ausstehende physische Bewegung. Eine gerade
eingetroffene Treffer- oder Todespose bleibt beim Synchronisieren und Pausieren
erhalten. Beim Kontaktstrahl ist je Endpunkt nur die nächstliegende beteiligte
Person ausgenommen; ein daneben stehender Dritter blockiert weiterhin den
tatsächlichen Physikstrahl. Das Laden des älteren Modus beziehungsweise der
Wechsel zur anderen Herkunft entfernt die zusätzlich erzeugten
Personenkollisionen und setzt die Spielerkollisionsmaske zurück. Ein gespeicherter
neuer Kampfzustand bei gleichzeitig deaktiviertem Dorf wird bereits vor
Befehlsausführung oder Speichern als widersprüchlich abgewiesen.

Die Szenarien verwenden ausdrücklich gesetzte Reise-Startpunkte. Sie belegen
keinen durchgespielten Fußweg durch die gesamte Welt. Diese Ergebnisse sind
Engine- und Regelprüfungen; sie messen keine Android-Bildrate, Temperatur oder
visuelle Endqualität. Körperansichten, reale Steuerbewegung und Android-Bauzustand
werden in den übrigen Nachweisen dieses Arbeitszweigs getrennt dokumentiert.

## Prüfstatus der rekonstruierten Integration

Dieser Nachtrag beschreibt die wiederhergestellte Vier-Parameter-API und den
einzigen delegierten Kampfpfad. Für die Schnittstellenprüfung wurden die
Domainquellen mit den rekonstruierten Quellen von Main, Welt und Adapter
verglichen. Diese Quellenprüfung ist kein bestandener Engine-Test der
zusammengeführten Fassung. Die historischen Prüfsummen und Fallzahlen oben
dürfen nicht als Ergebnis dieser Integration übernommen werden.

Für die integrierte Fassung sind zusätzliche Domainprüfungen vorgesehen:
Ein Kindheitsstart aktiviert den Kampf genau einmal; zwei Schritte zu je
0,1 Sekunden ergeben 0,2 Sekunden Technikzeit, einen bestätigten Kontakt und
keine Erwachsenen-Ausbildung. Ein Speichern und Laden zwischen Vorbereitung
und Kontakt erhält diese Reihenfolge. Die Fassade benötigt denselben
Geometrienachweis wie die gemeinsame Autorität.

**Behobener Befund: körperliche Ausweichrestzeit.** `sync` löscht jetzt
`world._dodge_remaining`, sobald der gespeicherte Ausweichzustand endet.
`reset` löscht dieselbe Restzeit unabhängig vom bisherigen Pose-Status.
Eine Domain-Unterbrechung oder ein frisches Welt-Setup kann dadurch keine
noch ausstehende Ausweichzeit aus der vorherigen Aktion übernehmen.

Der gezielte Lauf von `action_adapter_test.gd` mit Godot 4.7.2 bestand
**56 von 56 Prüfungen**, ohne Fehlschlag, mit Exitcode 0. Das ausgewertete
Protokoll `/dev/shm/imperathen-adapter-final.log` enthält:

```text
ACTION_ADAPTER_RESULT checks=56 failures=0
ACTION_ADAPTER_PASS
```

Die ergänzte Regression beginnt mit einem vom Modell angenommenen
Ausweichbefehl und bestätigt die dadurch gestartete körperliche Restzeit.
Anschließend unterbricht sie die Domain-Aktion, synchronisiert die Welt
und führt vier tatsächliche Physikframes mit regulären Weltaufrufen aus.
Ohne Bewegungseingabe bleibt die horizontale Positionsänderung unter
0,001 Metern. Ein zweiter angenommener Ausweichbefehl und ein frisches
Welt-Setup prüfen zusätzlich, dass weder autoritativer Ausweichzustand noch
körperliche Restzeit übernommen werden.

Derselbe Lauf prüft die Identität nativer ziviler Kollisionskörper:
Zwölf wiederholte Synchronisierungen erzeugen keine doppelten Körper,
ein naher Dritter bleibt im echten Kontaktstrahl ein Hindernis, und ein
durch den Besitzer deaktivierter ziviler Körper bleibt deaktiviert.

Dieser gezielte Adapterlauf ist kein Nachweis eines vollständig bestandenen
Merge-Gesamtlaufs. Die oben dokumentierten historischen Ergebnisse bleiben
dem Ausgangsstand zugeordnet; die vollständige integrierte Abnahme benötigt
ihren eigenen Gesamtbericht.
