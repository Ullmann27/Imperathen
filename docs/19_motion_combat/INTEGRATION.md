# Chat A – Übergabe an Dorf- und Kindheitsintegration

## Grundlage und Zuständigkeit

Eigener Branch: `feature/chat-a-movement-combat-20261123`.
Die erste Fassung `5d95676626d8eeee5589973603cb1da523ca4970` basierte auf
`2909040deeb33b99ad4180b884b38921f28233a9`. Die anschließende Zusammenführung
übernimmt den vollständigen Familien- und Dorfstand
`e5735509622c9a94564dc5fe21257c07074f9df5` als zweiten Elternstand.
[Draft-PR 39](https://github.com/Ullmann27/Imperathen/pull/39) richtet sich an
`feature/childhood-village-20261123`. Die fünf Anschluss-Patches werden gegen
`e573550…` erzeugt. Ein Merge nach `main` gehört nicht zu dieser Lieferung.

Drei tatsächliche Arbeitsagenten bearbeiten Körper/Animation, Kampfautorität
und Touch/Kamera. Die Integration verbindet ihre Ergebnisse und prüft sie in
der bestehenden Hauptszene. Docker ist in dieser Ausführungsumgebung nicht
vorhanden; diese drei Agents sind keine behaupteten Dockercontainer.

Andere Arbeitsbäume wurden weder umgeschaltet noch verändert. Die Familie,
die 35 verbundenen Handlungen, Auftragsinventar, bewusst begonnene Dorftage,
Nachtfreigabe, Häuser, Bewohnerwege, Personenkollisionen, Nordkarte und geliehene
Wachausrüstung bleiben aus dem Dorfzweig erhalten.

`unarmed_combat.gd` ist jetzt eine delegierende Fassade für `CombatActions`.
Sie verarbeitet keinen zweiten Kampftick. Die Figur verwendet `CharacterMotion`
und `HandPose`; `NaturalMotion.install()` wird nicht zusätzlich im produktiven
Pfad aufgerufen. `PracticeGear` bleibt für den gespeicherten Leihstatus zuständig.

## Gemeinsame Integrationsdateien

| Datei | Eingriff und Zweck |
| --- | --- |
| `prototype/scripts/domain/world_model.gd` | Vierter optionaler Parameter `action_combat`; der dritte Parameter bleibt `childhood_enabled`. Transaktionen, strikte Validierung, Unterbrechung, tatsächliche Trefferbuchung und getrennte Erwachsenen-Ausbildungsbrücke. |
| `prototype/scripts/main.gd` | Neue Familienpartien aktivieren den gemeinsamen Modus; Physikuhr mit begrenztem Sammeln ruhender Kindheit und Flush vor Übergängen, Geometriecallbacks, Touchaktionen und Unterbrechungen werden an die bestehenden Eingänge angeschlossen. |
| `prototype/scripts/world/game_world.gd` | Eigene Geh-/Laufgeschwindigkeit, reale Kollisionsgeschwindigkeit als Animationsantrieb, Kameraeingang und Delegation an den neuen Weltadapter. |
| `prototype/scripts/story/village_life.gd` | Kleiner interner Trefferabschluss; optionale Sicht- und Bewegungsprüfung für neue Kämpfe, damit Angreifer keine Mauern durchqueren. |
| `prototype/scripts/world/village/village_population.gd` | Begrenzter Kameraschutz für Namensschilder auch im älteren Bewohnerpfad: kleine Pixelskalierung, Mindesttiefe vor der Kamera und sofortiges Verbergen bei Pause. |

Die Änderungen sind begrenzte Anschlussstellen. Bewohnerkatalog, Berufe,
Geschichtentexte, Haushalte, Wege und das fortlaufende Kindheitskapitel der
anderen Arbeitslinie bleiben erhalten. Der Hauptdatenvertrag bleibt Schema 5;
der optionale Unterzustand heißt weiterhin `village.unarmed`, Version 1.

## Neue Modulverträge

- `CombatActions`: Regeln, Ausdauer, zehn Techniken, getrennte Phasen,
  strikte Eingaben, Kontaktprüfung und elf gespeicherte Felder. Siehe
  [COMBAT_CONTRACT.md](COMBAT_CONTRACT.md).
- `PlayerActionWorld`: wählt ein Ziel in der Blickrichtung und liefert echte
  Physikstrahlen sowie Kapsel-Sweeps. Er darf keinen Schaden und keine Erfahrung
  selbst vergeben. Native zivile `CollisionObject3D`-Körper auf Schicht 8 werden
  wiederverwendet; ihre Lebens-/Sichtbarkeitszustände bleiben beim Dorfpfad.
  Nur Figuren ohne eigenen Körper erhalten zusätzliche Grenzen auf Schicht 4.
  Auch alte Partien behalten die Personenkollisionen des neuen Dorfzweigs.
- `VillagePerson`: `drive(real_speed, turn_rate)`,
  `sample_combat(technique, normalized_progress)`, `cancel_action()` und
  `set_equipment(sword, shield)`. Der tatsächliche autoritative Zeitstand treibt
  die Kampfdarstellung. Ein erreichtes Alter allein erzeugt keine Waffe.
  `set_loaned_gear()` erhält unabhängig davon den ausdrücklich geliehenen
  Helm und Holzschild; dies ist noch kein Schwert-/Schildkampfsystem.
- `GameUI`: `movement_pace`, `select_technique`, `camera_look`, `camera_zoom`,
  `touch_camera_managed` und die drei `village_unarmed_*`-Befehle ergänzen die
  bisherigen Ereignisse. Der Kamerafinger hat genau einen Besitzer.

## Einstieg und Kompatibilität

```gdscript
new_game(origin_id, extended_village, childhood_enabled = false, action_combat = false)
```

| Aufruf | Tatsächlicher Modus |
| --- | --- |
| `new_game("italia", true, true)` | Neue Familienkindheit einschließlich gemeinsamem Aktionskampf; regulärer neuer römischer Menüstart. |
| `new_game("italia", true)` | Bisherige Dorfkarriere ohne erfundene Kindheit oder neue Kampffelder. |
| `new_game("italia", true, false, true)` | Ausdrücklicher moderner Kampf auf der bisherigen Dorfkarriere. |

Ein drittes `true` ist keine bloße Kampffreigabe mehr. Die Legacy-Prüfungen
laden eigene alte Saves über Fortsetzen; der Familienweg beginnt über das Menü.
Das Technikmenü ist ein modales Overlay der laufenden Ansicht, kein zusätzlicher
konkurrierender `Main.screen`-Zustand.

## Regeln beim Übernehmen

Neue Module, Faustressourcen und UID-Dateien zusammen mit den Anschlussstellen
übernehmen. Bei geänderten gemeinsamen Dateien den Patch nicht blind anwenden.
Die beigefügten Integrationspatches und Quellhashes beschreiben die gelieferte
Grundlage; ein abweichender Kindheitsstand muss bewusst zusammengeführt werden.

Die Spielsimulation läuft in `Main._physics_process`. Ruhende Kindheit sammelt
bis ungefähr 0,1 Sekunden; laufende Kampf-/Abwehraktionen und Gefechte werden
am Physiktakt verarbeitet. Restzeit wird vor Befehlen, Speichern und Pausen
verbucht, damit neue Angriffe keine vorherige untätige Zeit erhalten.
Manueller Testcode muss
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

Ein später unterbrochener grafischer Routenversuch der ersten Chat-A-Fassung
fand einen zusätzlichen konkreten Fehler:
Cassians altes Namensschild konnte vor der Kamera fast die ganze Tür verdecken.
Der ältere Bevölkerungspfad verwendet nun dieselbe Kameratiefeprüfung wie die
neueren Dorfbewohner. Sechs zusätzliche Regressionen prüfen diesen tatsächlichen
Bewohner; der vollständige Namensschildtest umfasst damit 16 Prüfungen. Die
Bewohnerdaten, Berufe und Tageswege wurden dafür nicht verändert.

Die ersten Bildbelege unter `evidence/motion` und `evidence/touch` gehören zur
Chat-A-Fassung vor der Zusammenführung (`5d956…`). Ihre Quellhashes und
Messergebnisse sind keine neue grafische Abnahme der Familienfassung.
Die Bilder stammen aus Godot mit lokaler Softwaregrafik. Android-Bau und
Android-Laufzeit sind getrennt im Lieferbericht ausgewiesen; ein physisches
Fold7 und thermische Dauerlast werden nicht durch diese Bilder belegt.
