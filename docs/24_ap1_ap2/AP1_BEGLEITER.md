# AP-1 · Marcus und Silvanus als physische Begleiter

Stand: 24.11.2026. Basis `handoff/sol-20261124`, Commit
`94bb7cdd76a3fe2577610eac8da6948e29b0faab`. Umsetzung auf
`feature/ap1-ap2-companions-20261124`; Godot 4.7.2 und `gl_compatibility`.

## Auftrag und vorab festgelegter Umsetzungsplan

Die vorhandenen Figuren werden in den belegten Band-1-Missionen verwendet:
Silvanus geht in I-04 zur Schmiede; Marcus begleitet I-06, I-08 und I-09.
Der unbelegte Eigenname des kranken Wachmanns wird geklärt. Die Wegbewegung,
Dialogauswahl und Präsentation kommen hinzu, ohne neue gespeicherte
Fortschrittsfelder oder umbenannte Actor-IDs einzuführen.

| Bereich | Betroffene Dateien | Nachweis |
|---|---|---|
| Missionsregie und Quellen | `missions/band1/I-04/I-06/I-07/I-08/I-09.json`, `companion_story.gd`, `village_childhood.gd` | Band-1-Abgleich, Originalstellen, Freund/Rivale |
| Physische Bewegung | `companion_follow.gd`, `companion_world.gd`, `game_world.gd`, `village_life_world.gd` | Wand, Personen, Boden, Hauseingang, Zielwechsel und echte Dorfwege |
| Ansprechen und Beobachtung | `world_model.gd`, `village_life.gd`, `main.gd`, `village_life_panel.gd` | Reale Körperposition, Dialogpause, Name, Save/Load |
| Regressionen | `companion_navigation_test.gd`, `companion_follow_test.gd`, `band1_alignment_test.gd`, `village_collision_test.gd`, `check_prototype.py` | Vollständige Python- und Engine-Prüfung vor Commit |
| Sichtbare Abnahme | `companion_review.gd`, `capture_companion_comparison.py`, Workflow `companion-review.yml` | Identisches externes Prüfszenenskript auf Basis und Änderung; echte Renderbilder |

Die vollständigen Originalfundstellen und SHA-256-Werte stehen in
[`QUELLENPRUEFUNG.md`](QUELLENPRUEFUNG.md). Drehbücher und Volltextextraktionen
werden nicht ins Repository übernommen.

## Verhalten und Aufgabenverteilung

Die Missionsdateien enthalten zusätzliche `companions`-Metadaten. Sie verändern
weder die bestehenden Schrittindizes noch die in AP-2 ausgelagerten Brücken.

| Mission | Figur | Bestehende aktive Teilschritte | Belegter Text |
|---|---|---|---|
| I-04 | Silvanus | `collect_kindling`, `deliver_kindling`, `apprentice_permission`, `smith_trial` | Tabelle 7, Dialogregie 01 |
| I-06 | Marcus | `deliver_hinge`, `market_trade`, `smith_apprentice` | Tabelle 9, Dialogregie 05; bei Rivalenwahl 08 |
| I-08 | Marcus | `i08_tracks`, `i08_report` | Tabelle 11, Dialogregie 01 |
| I-09 | Marcus | `family_evening`, `night_rest` | Tabelle 12, Dialogregie 04 |

`companion_story.gd` liest die Metadaten und die vorhandenen Spielstandsfakten.
Marcus' Ton folgt `companion.choice`: `help` ist vertraut, `decline`
zurückhaltend. Eine spätere Änderung des Vertrauenswertes ersetzt diese konkrete
I-03-Erinnerung nicht. Für I-08 und I-09 existiert jeweils nur eine ausgewählte,
zeitlich passende Originalzeile. Deshalb unterscheiden sich dort Titel und
Regiemetadaten, ohne einen weiteren gesprochenen Satz zu erfinden. Es gibt keine
neue Sprachaufnahme.

`companion_world.gd` bindet die Regie an die bestehenden Körper. Marcus' bisherige
Figur erhält einen `CharacterBody3D`; bei Silvanus wird derselbe Bewohnerkörper
beweglich. Es entsteht kein zweiter Marcus oder Silvanus. Bei der Schmiede,
am Markt, bei den Spuren und am Abend gibt es Haltepunkte. Außerhalb der aktiven
Begleitung kehrt die verfügbare Figur gehend zu ihrem bisherigen Standort zurück.
Tod, Arbeitszuweisung oder Milizdienst machen Silvanus für diese Begleitregie
nicht verfügbar. Andere bestehende Karrierevarianten behalten ihre Platzierung.

`companion_follow.gd` bewegt den Körper ausschließlich über `move_and_slide()`.
Eine begrenzte Raster-Wegsuche prüft die vorhandenen Kollisionskörper und Boden,
einschließlich Bewohnern. Es gibt keinen Aufholteleport. Nicht erreichbare Ziele
führen zu Warten und begrenzter erneuter Suche. Pfade sind Laufzeitdaten.
Die vorhandene Laufanimation erhält die tatsächlich zurückgelegte Geschwindigkeit.

Beim Gespräch oder Menü hält die Begleitung an. Die bestehenden
Dialog-/Zwischensequenzen-Pausen werden verwendet; dieses Arbeitspaket ergänzt
keine neuen geschnittenen Zwischensequenzen. Die Missionsregie bringt die Figuren
an definierte Haltepunkte, solange die Welt aktiv ist.

**Ergänzungen:** Konkrete Folgeabstände, Geschwindigkeiten, Suchbudgets,
Haltekoordinaten, Zuordnung zu bestehenden Teilschritten und Auswahl der
Originalzeilen pro Beziehung sind technische beziehungsweise inszenatorische
Ergänzungen. Sie stehen auch als `direction_note` in den Missionsmetadaten.
Der Auftragstext für die Lehrlings-Erlaubnis nennt jetzt Silvanus bei der
Schmiede, da er den Spieler tatsächlich dorthin begleitet.

## Wachmann und Save-Vertrag

Der Name „Severus“ kommt in keinem der vier geprüften Originale vor. I-07 nennt
Decimus und Silvanus in der Besetzung, identifiziert Decimus aber nicht als den
kranken Mann. Deshalb lautet der Anzeigename im Kindheitsabschnitt **Wachmann**.
Die Zuordnung des vorhandenen Actors zu dieser namenlosen Rolle ist ausdrücklich
eine **Ergänzung**, keine behauptete Originalidentität.

Die technische ID `severus` bleibt in Beziehungen, Missionszielen und gespeicherten
Daten bestehen. Das betrifft auch die Abwesenheits-/Rückkehrmechanik. Andere
Karrierevarianten behalten ihren bisherigen Namen. Bereits gespeicherte ältere
Ereignisprotokolle werden nicht nachträglich umgeschrieben.

Der Save bleibt **Schema v5 mit Envelope**, `screenplay.version` bleibt **3**.
Die bestehende NPC-Beobachtung speichert die wirklichen Figurenpositionen. Bei
Marcus bleibt die alte Konvention des Figurenmittelpunkts erhalten; sein neuer
Fußursprung wird nur beim Wiederherstellen um 0,9 m korrigiert. Beim normalen
`sync_state()` erfolgt keine Rückplatzierung auf einen festen Heimatpunkt.

Vor einem Weltbefehl werden die aktuellen Beobachtungen im geklonten
Befehlskandidaten berücksichtigt. Ein fehlgeschlagener Befehl übernimmt diesen
Kandidaten nicht. Dialoge prüfen die tatsächliche Nähe; der Hinweis und die
Interaktion für einen bereits bekannten Marcus verwenden dieselbe Bedingung.

Es werden keine zusätzlichen Begleitstände im Save eingeführt. Deshalb ist
für AP-1 keine neue Migration nötig. Die vorhandenen Legacy-Migrationen und die
drei im Handoff aufgezeichneten v5-Envelopes werden weiterhin geprüft.

## Prüfumfang und visuelle Nachweise

`companion_navigation_test.gd` prüft echte Physik an Wand, Bewohnerkapsel,
unzugänglichem Ziel, Bodenlücke sowie Hauseingang mit den vorhandenen Tür-/Rampenmaßen.
Zusätzlich werden bewegtes Ziel, Halteabstand, Pause und Zielwechsel geprüft.

`companion_follow_test.gd` erreicht alle vier Szenen über echte Missionsbefehle.
Nur die Reise des Spielers ist ein ausdrücklich gesetztes Prüffixture. Die
Begleiter laufen danach selbst durch die tatsächliche Dorfgeometrie. Geprüft
werden Ankunft, unveränderte Figurenanzahl, Boden, Pause, Synchronisation,
Beobachtung, Dialognähe und Speichern/Laden. Der Save-Vergleich normalisiert nur
JSON-Zahlentypen und vergleicht weiterhin sämtliche Fortschritts-/Beziehungsfelder.

Der Bildworkflow benutzt dasselbe externe Skript für Handoff und Änderung.
Er prüft Kameratransformation, Auflösung 1280×720, Qualitätsprofil „Ausgewogen“,
Spielerposition, Missionsfortschritt, Beziehung, Präsentationszeit, Figurenpose,
Quellhashes und Bildhashes. Die Bilder zeigen vorbereitete Zustände; sie sind kein
Nachweis für einen vollständig durchgespielten Weg oder für Android-Bildraten.
Das Vergleichs-HTML stellt alle neun Bildpaare nebeneinander bereit.

Die tatsächlich erreichten Testzahlen, Commitstände und Bildbewertungen werden
im Abschlussbericht `DELIVERY.md` mit den zugehörigen Originalprotokollen dokumentiert.

Vor dem Implementierungscommit bestanden **153/153 Python-Tests** und
**64/64 Engine-Prüfgruppen** unter `4.7.2.stable.official.ed1daf0bf`, ohne Warnungen.
Darin: Begleitnavigation **30**, reale Weltintegration **269**, Band-1-Abgleich
**206** und Brückendaten **214** erfolgreiche Einzelprüfungen. Vollständiger
Engine-Bericht und alle Gruppenlogs: [`evidence/ap1/`](evidence/ap1/).
Python-Protokoll: [`evidence/ap1_python.log`](evidence/ap1_python.log).

## Fachliche Grenzen

- Kein neuer Grafikasset, Rig, Shader, Renderingverfahren oder Rückschritt auf
  einen einfacheren Renderer ist Teil dieser Änderung.
- Eine Aufnahme mit Software-OpenGL bestätigt die Darstellung und die
  Vergleichsbedingungen, nicht die Leistung eines Android-Geräts.
- Eine Messung auf Heinz' Handy, thermische Dauerlast und Eingabeprüfung auf dem
  Gerät stehen aus. Hierzu liegen mir keine gesicherten Daten vor.
- Bei unerreichbaren Positionen wartet der Begleiter; ein neues Weltmodell mit
  Transport, Levelwechseln oder großen Menschenmengen benötigt weitere Planung.
- AP-1/AP-2 erweitern den vorhandenen Prototyp. Sie belegen weder eine vollständig
  inszenierte Band-1-Kampagne noch 90 Stunden Spielzeit oder die Umsetzung von Band 2–4.
