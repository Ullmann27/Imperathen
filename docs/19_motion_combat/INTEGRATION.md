# Chat A – Übergabe an Dorf- und Kindheitsintegration

## Grundlage und Zuständigkeit

Eigener Branch: `feature/chat-a-movement-combat-20261123`.
Ausgangsstand ist der am 23.11.2026 tatsächlich abgerufene Commit
`2909040deeb33b99ad4180b884b38921f28233a9` von
`feature/childhood-village-20261123`. Dieser Stand enthält die beiden
Folgeaufträge und baut auf `f2900eb86b90b185627dcd490fef550fd0cbed11` auf.

Drei tatsächliche Arbeitsagenten bearbeiten Körper/Animation, Kampfautorität
und Touch/Kamera. Die Integration verbindet ihre Ergebnisse und prüft sie in
der bestehenden Hauptszene. Docker ist in dieser Ausführungsumgebung nicht
vorhanden; diese drei Agents sind keine behaupteten Dockercontainer.

Der aktive andere Arbeitsbaum wurde weder umgeschaltet noch verändert. Die
noch unveröffentlichte Datei `unarmed_combat.gd` des koordinierenden Chats
wurde ausschließlich gelesen, um dessen elf Felder umfassenden v1-Vertrag
und Technikkennungen zu bewahren. Unser Modul heißt `combat_actions.gd`.
Es gibt eine Kampfautorität pro Partie; beide Implementierungen dürfen nicht
gleichzeitig fortgeschrieben werden.

## Gemeinsame Integrationsdateien

| Datei | Eingriff und Zweck |
| --- | --- |
| `prototype/scripts/domain/world_model.gd` | Optionaler dritter Parameter `action_combat` bei `new_game`; Transaktionen, strikte Validierung, Unterbrechung, tatsächliche Trefferbuchung und getrennte Erwachsenen-Ausbildungsbrücke. |
| `prototype/scripts/main.gd` | Neue Partien aktivieren den optionalen Modus; Physikuhr, Geometriecallbacks, Touchaktionen und Unterbrechungen werden an die bestehenden Eingänge angeschlossen. |
| `prototype/scripts/world/game_world.gd` | Eigene Geh-/Laufgeschwindigkeit, reale Kollisionsgeschwindigkeit als Animationsantrieb, Kameraeingang und Delegation an den neuen Weltadapter. |
| `prototype/scripts/story/village_life.gd` | Kleiner interner Trefferabschluss; optionale Sicht- und Bewegungsprüfung für neue Kämpfe, damit Angreifer keine Mauern durchqueren. |
| `prototype/scripts/world/village/village_population.gd` | Begrenzter Kameraschutz für Namensschilder auch im älteren Bewohnerpfad: kleine Pixelskalierung, Mindesttiefe vor der Kamera und sofortiges Verbergen bei Pause. |

Die Änderungen sind begrenzte Anschlussstellen. Bewohnerkatalog, Berufe,
Geschichtentexte, Haushalte, Wege und das fortlaufende Kindheitskapitel bleiben
Zuständigkeit der anderen Arbeitslinie. Der Hauptdatenvertrag bleibt Schema 5;
der optionale Unterzustand heißt weiterhin `village.unarmed`, Version 1.

## Neue Modulverträge

- `CombatActions`: Regeln, Ausdauer, zehn Techniken, getrennte Phasen,
  strikte Eingaben, Kontaktprüfung und elf gespeicherte Felder. Siehe
  [COMBAT_CONTRACT.md](COMBAT_CONTRACT.md).
- `PlayerActionWorld`: wählt ein Ziel in der Blickrichtung und liefert echte
  Physikstrahlen sowie Kapsel-Sweeps. Er darf keinen Schaden und keine Erfahrung
  selbst vergeben. Bewohner erhalten sichtbarkeitsabhängige Körpergrenzen;
  alte Partien behalten keine unsichtbaren neuen Kollisionen.
- `VillagePerson`: `drive(real_speed, turn_rate)`,
  `sample_combat(technique, normalized_progress)`, `cancel_action()` und
  `set_equipment(sword, shield)`. Der tatsächliche autoritative Zeitstand treibt
  die Kampfdarstellung. Ein erreichtes Alter allein erzeugt keine Waffe.
- `GameUI`: `movement_pace`, `select_technique`, `camera_look`, `camera_zoom`,
  `touch_camera_managed` und die drei `village_unarmed_*`-Befehle ergänzen die
  bisherigen Ereignisse. Der Kamerafinger hat genau einen Besitzer.

## Regeln beim Übernehmen

Neue Module, Faustressourcen und UID-Dateien zusammen mit den Anschlussstellen
übernehmen. Bei geänderten gemeinsamen Dateien den Patch nicht blind anwenden.
Die beigefügten Integrationspatches und Quellhashes beschreiben die gelieferte
Grundlage; ein abweichender Kindheitsstand muss bewusst zusammengeführt werden.

Die Spielsimulation läuft in `Main._physics_process`. Manueller Testcode muss
deshalb Physik und Präsentation getrennt takten; `Main._process` allein
simuliert keinen Kampf mehr. Eingabepause, Hintergrundwechsel und Wechsel aus
der Figurenansicht unterbrechen auch die akzeptierte Kampfbewegung.

Bestehende Spielstände ohne `village.unarmed` bleiben lesbar und verwenden
ihren bisherigen Kampfablauf. Neue Echtzeitangriffe wachsen nicht als einzelne
Aufträge im dauerhaften Wirtschaftsprotokoll an; ihre validierten Folgen und
der aktuelle Unterzustand werden gespeichert. Über die API ausdrücklich
gelieferte Befehlskennungen behalten die vorhandene Wiederholungssicherung.

## Bekannte Grenzen

Die Kontaktregel verwendet Reichweite, Richtung und einen Weltstrahl. Sie ist
keine vollständige anatomische Hand-/Fuß-Hitboxsimulation. Die kurze Deckung
verwendet das vorhandene Abwehrfenster und ist noch nicht richtungsabhängig.
Ein an einer Wand blockierter Angreifer benötigt für ein intelligentes Umgehen
weiterführende Wegfindung. Der vorhandene Rig- und Tunikaaufbau begrenzt
Stoffverformung und feine Schulterbewegungen. Bewaffnete Aktionen brauchen
weiterhin einen ausdrücklich erworbenen Ausrüstungszustand; diese Lieferung
erfindet weder Waffenbesitz noch eine entsprechende abgeschlossene Mission.

Die kontinuierliche sichtbare Abnahme fand einen zusätzlichen konkreten Fehler:
Cassians altes Namensschild konnte vor der Kamera fast die ganze Tür verdecken.
Der ältere Bevölkerungspfad verwendet nun dieselbe Kameratiefeprüfung wie die
neueren Dorfbewohner. Sechs zusätzliche Regressionen prüfen diesen tatsächlichen
Bewohner; der vollständige Namensschildtest umfasst damit 16 Prüfungen. Die
Bewohnerdaten, Berufe und Tageswege wurden dafür nicht verändert.

Die Bildbelege stammen aus Godot mit lokaler Softwaregrafik. Android-Bau und
Android-Laufzeit sind getrennt im Lieferbericht ausgewiesen; ein physisches
Fold7 und thermische Dauerlast werden nicht durch diese Bilder belegt.
