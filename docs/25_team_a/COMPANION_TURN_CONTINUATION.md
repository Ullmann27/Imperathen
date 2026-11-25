# Begleiter: Ausrichtung, Anfahren und LOD-Kontakthistorie

Ausgangspunkt: `261639105dcaa72f8dd92e73f4db1d9ab7d90a23`. Engine: Godot `4.7.2.stable.official.ed1daf0bf`.

Der Stand enthält zwei begrenzte Produktionskorrekturen: Begleiter drehen und beschleunigen vor dem vollen Lauf, und ein LOD-Wechsel bewahrt die Kontakthistorie des letzten echten Zeitschritts. Die unveränderte 20-Grad-Grenze des Motion-Gates bleibt auf den vollständigen Routen überschritten. Dieser Bericht ersetzt die zwischenzeitlichen Angaben zum verworfenen 0,3-Tempofaktor.

## 1. Ursache im Bewegungscontroller

`CompanionFollow.move` setzte die volle Geschwindigkeit entlang des neuen Wegsegments, bevor der Körper passend ausgerichtet war. Marcus begann den Marktweg mit ungefähr 131 Grad Richtungsfehler und sofort 4,1 m/s. Die Körperdrehung blieb auf 4,5 rad/s begrenzt. Im Detailtrace entfernten sich die aufgesetzten Füße dadurch so weit vom Körper, dass die Weltkontaktkorrektur ungefähr 57 cm erreichte. Das Becken senkte sich bis zu seiner 16-cm-Grenze und hob sich danach rasch. Der rechte Oberschenkel sprang im reproduzierten Weltmesslauf in Frame 29 um 31,651 Grad.

Die Korrektur dreht den Körper vor dem Physikschritt mit derselben bestehenden Drehgrenze zum Wegsegment. Die Vorwärtsprojektion begrenzt das Tempo während der Drehung. Liegt das Ziel hinter der Figur, bleibt sie zunächst am Ort und verwendet die bereits vorhandenen Wendeschritte. Danach steigt die angeforderte Geschwindigkeit mit 8 m/s²; dieser Wert entspricht der vorhandenen Anfahrbeschleunigung des laufenden Spielers. Nach der Ausrichtung bleiben die vollständigen angeforderten 4,1 m/s erreichbar.

Der Anfahrzustand ist flüchtig und wird bei Pause, Reset oder Körperwechsel gelöscht. Er gehört zur angeforderten Navigation und wird getrennt von der durch Kollisionen tatsächlich zurückgelegten Strecke geführt. Eine Zwischenversion leitete den nächsten Geschwindigkeitswunsch immer wieder aus einem kurzen Kollisionsgleiten ab und blieb dadurch vor der Hausrampe hängen. Der getrennte Zustand beseitigt diese Rückkopplung; der bestehende Hauseingangstest besteht. Die Figurendarstellung erhält weiterhin die tatsächlich gemessene Bewegung.

## 2. Ursache beim LOD-Wechsel

Im Nav-Kandidaten lag ein zusätzlicher Silvanus-Ausreißer beim Wechsel von `frontier_civilian_man_1.glb` zu `frontier_civilian_man_0.glb`, Frame 482. Ein laufender Animations-Crossfade war dabei ausgeschlossen: `transition_remaining` war vor und nach dem Wechsel null. Die Gangphase wechselte von 0,292358 auf 0,323951, also genau vom letzten Standframe zum ersten Schwungframe.

`VillagePerson._reload` stellte die neue LOD mit `_plant_contacts(0.0)` dar, nachdem sich der Körper bereits bewegt hatte, während die Gangphase noch den vorherigen Tick bezeichnete. Dieser Auswertungsschritt überschrieb den gespeicherten Standoffset: aus ungefähr null wurde `(-0.048321, 0, 0.048319)` m. Die Änderung von 68,333022 mm entsprach dem tatsächlichen Körper-Schritt von 68,332516 mm. Der erste Schwung erhielt damit einen zusätzlichen Rückversatz.

Nach der Darstellung der neuen LOD stellt `_reload` jetzt den bereits vor dem Wechsel gesicherten Kontakt-/Schwung-Snapshot wieder her. Die berechnete sichtbare Knochenpose bleibt bestehen; der nächste echte Tick verwendet wieder die letzte gültige Kontakthistorie. Im selben tatsächlichen Silvanus-Frame beträgt die Offsetänderung anschließend exakt null. `CharacterMotion`, Assetdateien und Messgrenzen sind unverändert. `SoldierVisual` besitzt keinen entsprechenden World-Contact-Reload-Pfad und benötigt hier keine Änderung.

## 3. Dieselben tatsächlichen Routen vorher und nachher

Beide lokalen Läufe rufen die unveränderte Methode `MotionWorldMeasurement._companions` auf. Reguläre Missionsbefehle erzeugen die Zustände; die bestehenden Figuren bewegen sich durch die echte Physik, einschließlich Pause, Wiederaufnahme und Ankunft bei 60 Hz. Der Weltkontaktwert misst die Position des jeweils als gestützt gemeldeten Fußknochens. Er ist keine vollständige Prüfung der verformten Sohlenoberfläche.

| Figur und Messwert | Ausgangsquelle | Beide Korrekturen |
| --- | ---: | ---: |
| Marcus: größte Knochenrotation pro Frame | 31,651015° | 21,883231° |
| Marcus: größter Knochenpositionsschritt | 193,958268 mm | 161,454394 mm |
| Marcus: größter Standfußversatz | 13,833697 mm | 0,005395 mm |
| Silvanus: größte Knochenrotation pro Frame | 23,563750° | 22,277519° |
| Silvanus: größter Knochenpositionsschritt | 184,772387 mm | 187,171772 mm |
| Silvanus: größter Standfußversatz | 8,412944 mm | 0,006877 mm |

Der zuvor aufgetretene LOD-Rotationsausreißer von 25,174 Grad ist beseitigt. Das neue Silvanus-Maximum liegt auf `Arm_L`, Frame 434, `run`, unveränderte LOD 1, ohne Körperdrehung. Marcus erreicht sein neues Rotationsmaximum auf `Thigh_L`, Frame 427, `run`, unveränderte `villager_0.glb`, ebenfalls ohne Körperdrehung. Beide bleiben über der unveränderten 20-Grad-Grenze.

Eine kleine Verschlechterung bleibt ausdrücklich bestehen: Silvanus' größter Knochenpositionsschritt steigt von 184,772 auf 187,172 mm. Das neue Maximum liegt auf `Shin_R`, Frame 360, Animationsphase 0,469541739, `run`, unveränderte `frontier_civilian_man_2.glb`, ohne Körperdrehung. Ein voll bestandener Motion-Gate darf daraus nicht abgeleitet werden.

Beide Routen enden weiterhin ungefähr 0,18 m vor dem vorgesehenen Haltepunkt, mit Geschwindigkeit null und demselben Körper. Während der Pause beträgt die Verschiebung null. Silvanus benötigt in diesem Ablauf 1.351 statt 1.307 Beobachtungen, Marcus 884 statt 820; die zusätzlichen Wende- und Anfahrphasen kosten ungefähr 0,73 beziehungsweise 1,07 Sekunden. Zielankunft, Pause, Personenidentität und Kollisionsweg bleiben tatsächlich geprüft.

## 4. Unveränderte Retarget-Stressroute bei drei Taktungen

Jeweils derselbe Marcus beginnt mit einem Ziel hinter sich und erhält nach zwei Sekunden ein neues Ziel in Gegenrichtung. Die sechs Abläufe wurden auf der Originalquelle und dem endgültigen Nav-Kandidaten ausgeführt. Die neue LOD-Korrektur beeinflusst diese Fälle nicht, weil ihre Detailstufe festgehalten wird. Alle Rohwerte stehen in den Protokollen.

| Hz / Drehrichtung | Standfußversatz vorher → nachher | Knochenrotation vorher → nachher | Knochenpositionsschritt vorher → nachher |
| --- | ---: | ---: | ---: |
| 30 / -1 | 37,379187 → 0,001192 mm | 40,263 → 39,014° | 314,734 → 326,883 mm |
| 30 / +1 | 64,946659 → 0,001066 mm | 42,898 → 40,625° | 331,275 → 340,409 mm |
| 60 / -1 | 186,916530 → 0,001066 mm | 38,923 → 22,006° | 200,724 → 174,601 mm |
| 60 / +1 | 231,483877 → 0,001066 mm | 31,408 → 22,034° | 216,337 → 171,078 mm |
| 120 / -1 | 239,177465 → 0,001349 mm | 20,270 → 14,277° | 106,615 → 82,891 mm |
| 120 / +1 | 288,626611 → 0,001066 mm | 19,611 → 14,107° | 119,286 → 77,729 mm |

Die Positionsmaxima bei 30 Hz steigen links um 12,149 mm und rechts um 9,135 mm. Links liegt das neue Maximum auf `Foot_R`, Frame 17, Animationsphase 0,659389987; rechts ebenfalls auf `Foot_R`, Frame 82, Phase 0,671385620. Beide spielen `run` auf unveränderter `villager_0.glb`. Der Vergleichsbericht enthält die vollständigen Worst-Frame-Kontexte. Bei 60 Hz rechts steigt außerdem der gemessene Kollisionsüberlapp mit der Bodenfläche von ungefähr 4,794 auf 8,401 mm; dies bleibt unter der bestehenden 10-mm-Grenze. Bei 30 Hz liegt der Kollisionswert schon vorher in beiden Richtungen knapp über 10 mm und beträgt anschließend jeweils ungefähr 10,539 mm. Diese Befunde werden nicht durch die verbesserten Fuß- und Rotationswerte verdeckt.

## 5. Tatsächlich ausgeführte Regressionen

- `companion_navigation_test.gd`: 32 Prüfungen bestanden, einschließlich unverändertem Hauseingang, Bodenlücke, Wand-/Personenumgehung, gehendem Ziel und Endankunft.
- `companion_follow_test.gd`: 269 Prüfungen bestanden, einschließlich tatsächlicher Missionswege, Pause, Dialog, Speichern/Laden und Fortbestand derselben Bewohner.
- `companion_turn_motion_test.gd`: 66 Prüfungen bestanden. Beide Drehrichtungen bei 30/60/120 Hz behalten die echte 15-mm-Standfußgrenze, begrenzte Drehung, Anfahrbeschleunigung, vollständiges ausgerichtetes Lauftempo und Zielankunft. Die Gegenprobe auf der Original-Produktionsdatei scheitert bei 24 von 66 Prüfungen.
- `lod_contact_history_test.gd`: 216 Prüfungen in 36 Fällen bestanden: Held, Marcus und Frontier-Zivilist; Gehen/Laufen; beide Füße; 30/60/120 Hz. Jeweils wird der Körper unmittelbar vor dem ersten Schwung bewegt und dann die LOD gewechselt. Ein identischer Kontrollakteur wird ohne Wechsel weiter simuliert. Vor dem Fix scheiterten 108 Prüfungen. Nachher sind gespeicherter und freigegebener Standoffset unverändert; die erste Schwungpose hat zur Kontrolle null Positionsabweichung. Die Quaternion-Winkelmetrik bleibt innerhalb von 0,056 Grad bei einer Vergleichstoleranz von 0,1 Grad.
- Der bestehende `character_motion_test.gd` besteht weiterhin mit 560 Prüfungen, einschließlich erster Gangzyklen, Standkontakt, LOD und tatsächlichen Restsegmentachsen.

Der funktionale Zielwechseltest wurde fachlich präzisiert: Seine alte Bedingung „mehr als 2,3 m Fortschritt in der ersten Sekunde“ prüfte Geschwindigkeit, obwohl die Beschriftung die sofortige Aufgabe der alten Umgehungsrichtung verlangte. Jetzt wird direkt jeder weitere Schritt in die alte +Z-Richtung ausgeschlossen und tatsächlicher Fortschritt nach der begrenzten Ausrichtung verlangt. Bestehende Endankunft und Maximalschritt bleiben unverändert. Es wurde kein Motion-Grenzwert abgesenkt.

## 6. Verworfene Varianten und offene Folgeschritte

Der zwischenzeitliche 0,3-Mindestfaktor wurde verworfen: Er ließ rückwärts gerichtete Gehbewegung zu und verschlechterte unter anderem den linken 30-Hz-Stressfall von 37,379 auf 79,034 mm Standfußversatz sowie von 40,263 auf 47,237 Grad Rotation. Pauschaler Kontaktzustandserhalt zwischen `march` und `run` verschlimmerte diesen Fall weiter und ist ebenfalls nicht enthalten.

Reine Projektion ohne Anfahrbeschleunigung erzeugte beim Wiederanfahren nach der Pause einen neuen Marcus-Standfußversatz von 42,110 mm. Der Trace zeigte den direkten Sprung von null auf 4,1 m/s während des Ausblendens der Standpose. Die separate Anfahrrampe und der anschließend korrigierte LOD-Zeitschritt lösen diese konkret belegten Ursachen. Eine allgemeine visuelle Abnahme, Android-Abnahme oder ein vollständig grüner Motion-Gate liegt weiterhin nicht vor.

Die verbleibenden Rotations- und Positionsmaxima im regulären Lauf sowie das Aufsetzen eines beim Stop noch angehobenen Fußes bleiben eigene Folgearbeiten. Ein zuvor beobachteter angehobener Fuß darf nicht allein wegen eines kleinen Weltversatzes als korrekt geerdet gelten. Keine dieser offenen Fragen wurde durch nachträglich veränderte Messgrenzen ausgeblendet.

## Nachweise und Reproduktion

Der [Vergleich mit vollständigen Rohmessungen](evidence/companion-turn/companion-route-comparison.json) trägt ausdrücklich `complete: false` und `strict_gate_passed: false`. Er enthält die SHA-256-Werte beider Produktionsdateien, alle Routen- und Stressmaxima mit Kontext sowie die Kontrollprüfung. Die abschließende Wiederholung ergänzt ausschließlich `animation_phase` in den Diagnosen der maximalen Messwerte; die Messberechnung und ihre Grenzen bleiben unverändert. Die [LOD-Vergleichsmessung](evidence/companion-turn/lod-release-comparison.json) dokumentiert den tatsächlichen Release-Offset vor und nach der Korrektur.

Vom Repository-Stamm aus:

```sh
godot --headless --editor --path prototype --import --quit
godot --headless --path prototype --fixed-fps 60 --script res://tests/companion_navigation_test.gd
godot --headless --path prototype --fixed-fps 60 --script res://tests/companion_follow_test.gd
godot --headless --path prototype --fixed-fps 60 --script res://tests/companion_turn_motion_test.gd
godot --headless --path prototype --fixed-fps 60 --script res://tests/lod_contact_history_test.gd
godot --headless --path prototype --fixed-fps 60 --script res://tests/character_motion_test.gd
godot --headless --path prototype --fixed-fps 60 --script "$PWD/docs/25_team_a/evidence/companion-turn/measure_companions.gd" -- --output=/tmp/companion-routes.json
```

Für Gegenproben dieselben Prüfdaten in einem isolierten Checkout des Ausgangscommits verwenden. Der Navigationstest wird gegen die Originaldatei `companion_follow.gd` gestellt; der LOD-Kontrolltest gegen die Originaldatei `village_person.gd`. Die bestehenden Weltmessmethoden, Assets und Gate-Grenzen bleiben identisch.
