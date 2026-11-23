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
`WorldModel.new_game("italia", true, true)` aktiviert die neue Steuerung.
Bestehende Aufrufe mit zwei Parametern und gespeicherte Partien ohne den
optionalen Zustand behalten ihre bisherige Regelroute. `view(data)` liefert
eine tiefe Präsentationskopie; ihre zusätzlichen Angaben gelangen nicht in
den Spielstand.

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
Ausbildungstreffer. Erst in der tatsächlich erreichten erwachsenen Phase
`training` übergibt das Weltmodell einen bestätigten Pfahlkontakt zusätzlich an
die bestehende Ausbildungsbuchung. Damit bleibt der spätere Übergang zu
Rekrutierung und Gefecht erreichbar, ohne die Kindheit durch Übung zu überspringen.

Diese Lieferung führt kein erfundenes Ausrüstungsinventar ein. Schwert-, Schild-
und sonstige Waffenangriffe gehören nicht zum freigegebenen Katalog dieser
unbewaffneten Steuerung.

## Ausgeführte Prüfungen

Die folgenden gezielten Läufe wurden mit Godot 4.7.2 tatsächlich ausgeführt.
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

Die vier bestehenden Szenariotests verwenden jetzt explizit sowohl
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
