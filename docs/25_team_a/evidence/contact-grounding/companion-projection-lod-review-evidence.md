# Unabhängiges Review: Begleiterprojektion und LOD-Kontakthistorie

## Ergebnis

Die beiden begrenzten Produktionskorrekturen können integriert werden. Im geprüften Code besteht kein konkreter Blocker. Die Empfehlung betrifft den aktuellen Kandidaten mit Vorwärtsprojektion, eigenem Anfahrzustand und Wiederherstellung des LOD-Kontaktsnapshots. Der frühere 0,3-Mindestfaktor ist verworfen.

Das strenge Motion-Gate bleibt offen. Die vorhandenen Routen überschreiten weiterhin die Grenzwerte von 20 Grad Knochenrotation und 60 mm Knochenpositionsänderung. Silvanus und die beiden 30-Hz-Stressfälle haben weiterhin ausdrücklich dokumentierte Positionsverschlechterungen. Eine visuelle oder Android-Abnahme ist damit nicht erteilt.

Ausgangspunkt ist Commit `261639105dcaa72f8dd92e73f4db1d9ab7d90a23`; Engine der vorhandenen Messungen ist `4.7.2.stable.official.ed1daf0bf`. Dieses Review liest den tatsächlichen Code, die Regressionen und die bereits erzeugten Rohmessungen unabhängig nach. Es startet keine weitere Engine- oder vollständige Testsuite. `git diff --check` ist sauber.

## Navigation

Die Vorwärtsrichtung ist mit `Vector3.FORWARD` und `atan2(-direction.x, -direction.z)` konsistent. Der Controller dreht vor dem Physikschritt mit der bestehenden Grenze von 4,5 rad/s. Anschließend begrenzt `max(0, forward.dot(direction))` den Geschwindigkeitswunsch. Ein hinter der Figur liegendes Segment verursacht dadurch zunächst eine Drehung am Ort; der zurückgewandte Sprint wird verhindert.

Der neue `_requested_speed` erhöht den skalaren Geschwindigkeitswunsch um höchstens `8 * delta`. Ein kleinerer Richtungs- oder Abstandsdeckel wirkt sofort. Das ist eine Grenze für den skalaren Kommandoanstieg; eine allgemeine Grenze des gesamten Beschleunigungsvektors wird nicht behauptet. Kollisionen beeinflussen weiterhin `actual_speed` und damit die sichtbare Figur. Die durch Kollisionen verkürzte Bewegung wird nicht als Anfahrzustand zurückgespeist.

Pause, Reset und Körperwechsel setzen den Anfahrzustand zurück. Ankunft, außerhalb liegende Ziele und Suchstillstand ergeben eine Nullanforderung und setzen ihn dadurch ebenfalls auf null. Navigation und Save-Schema bleiben in ihren bestehenden Pfaden. Die tatsächlichen Missions-/Pause-/SaveLoad-Prüfungen bestehen.

Die geänderte Retarget-Regression prüft jetzt direkt, dass nach der Zieländerung kein weiterer Weg in die vorherige +Z-Umgehungsrichtung zurückgelegt wird. Die alte Forderung nach mehr als 2,3 m in der ersten Sekunde wurde durch echte Aufgabe der alten Richtung und nachgewiesenen Fortschritt nach Ausrichtung ersetzt. Endankunft und Maximalschritt bleiben geprüft. Die +Z-Aussage ist bewusst auf die konkrete Testgeometrie bezogen.

## LOD-Kontakthistorie

`VillagePerson._reload` speichert den Kontaktzustand vor dem Rigwechsel. Das bereits vorhandene `_plant_contacts(0.0)` berechnet die sofort sichtbare Ersatzpose. Wenn sich der Körper seit dem letzten echten Tick bewegt hat, konnte diese Nullzeitauswertung jedoch den gespeicherten letzten Standoffset überschreiben. Die erste Schwungphase übernahm dann einen zusätzlichen Rückversatz.

Der Zusatz stellt nach der sichtbaren Ersatzpose denselben zuvor gesicherten Snapshot wieder her. `restore_world_contacts` schreibt nur die Kontakthistorie, nicht die neue Skelettpose oder die Bindung. Kontakte und Schwünge werden tief kopiert. Die vorhandenen Identitäts- und Verfügbarkeitsprüfungen bleiben wirksam. Der nächste echte Animationsschritt setzt die Pose regulär und berechnet den Kontakt mit der richtigen Geschichte.

Die neue Regression verwendet zwei echte Figuren pro Fall. Beide werden unmittelbar vor der LOD-Auswertung bewegt; nur die geprüfte Figur wechselt von LOD 1 auf LOD 0. Der Kontrollakteur läuft ohne Reload weiter. Geprüft werden vorheriger Standkontakt, unveränderter gespeicherter Offset, tatsächliche Lage des neu geladenen Fußes am Anker, tatsächlicher Beginn der Schwungphase, unveränderter Freigabeoffset und die vollständige erste Schwungpose gegen die Kontrolle. Das ist eine aussagekräftige Gegenprobe des tatsächlichen Fehlers.

## Tatsächliche Missionsrouten bei 60 Hz

| Figur / Messwert | Ausgangsquelle | Nur Navigation | Navigation + LOD |
| --- | ---: | ---: | ---: |
| Marcus: Rotation | 31,651015 Grad | 21,883231 Grad | 21,883231 Grad |
| Marcus: Positionsschritt | 193,958268 mm | 161,454394 mm | 161,454394 mm |
| Marcus: Standfußversatz | 13,833697 mm | 0,005395 mm | 0,005395 mm |
| Silvanus: Rotation | 23,563750 Grad | 25,174231 Grad | 22,277519 Grad |
| Silvanus: Positionsschritt | 184,772387 mm | 187,171772 mm | 187,171772 mm |
| Silvanus: Standfußversatz | 8,412944 mm | 0,006877 mm | 0,006877 mm |

Der zusätzliche Silvanus-Rotationsausreißer beim Wechsel LOD 1 auf 0, Frame 482, ist im kombinierten Lauf beseitigt. Das neue Maximum liegt auf Arm_L in Frame 434, unveränderte LOD 1, Clip run, ohne Körperdrehung. Marcus' Maximum liegt auf Thigh_L in Frame 427, unveränderte LOD 0, Clip run, ohne Körperdrehung.

Silvanus' Positionsmaximum bleibt um 2,399385 mm höher als in der Ausgangsquelle. Der neue Maximalframe ist 360, Shin_R, unveränderte LOD 2, run, ohne Körperdrehung. Diese Restverschlechterung darf nicht durch den verbesserten Gesamtwert verdeckt werden.

Beide bestehenden Akteure erreichen den vorgesehenen Halt mit ungefähr 0,18 m Restabstand und Geschwindigkeit null. Während der Pause beträgt ihre Verschiebung null. Die Routen haben 1.351 beziehungsweise 884 Beobachtungen; die Ausgangsquelle hatte 1.307 beziehungsweise 820. Die zusätzliche Anfahr-/Wendezeit beträgt in diesen Abläufen etwa 0,73 beziehungsweise 1,07 Sekunden.

Die Weltkontaktmessung beobachtet den gestützten Fußknochen. Sie liefert keine vollständige Aussage über die verformte Sohlenoberfläche. Die getrennte Mesh-/Skin-Abnahme bleibt erforderlich.

## Regressionen aus den gesicherten Rohprotokollen

| Prüfung | Aktueller Kandidat | Gegenprobe Original |
| --- | ---: | ---: |
| Navigation | 32 / 32 | Keine neue Original-Gegenprobe dieses bestehenden Tests behauptet |
| Follow, echte Wege, Pause, Save/Load | 269 / 269 | Keine neue Original-Gegenprobe dieses bestehenden Tests behauptet |
| Neuer Dreh-/Kontakt-Test | 66 / 66 | 24 Fehler von 66 |
| Neue LOD-Kontrollprüfung | 216 / 216 in 36 Fällen | 108 Fehler von 216 |
| Bestehende CharacterMotion-Prüfung | 560 / 560 | Keine neue Original-Gegenprobe behauptet |

Der Dreh-/Kontakt-Test umfasst 30, 60 und 120 Hz sowie beide Drehrichtungen. Er verlangt tatsächlich den unveränderten Standfußgrenzwert von 15 mm. In allen sechs aktuellen Stressfällen liegt der größte beobachtete Versatz unter 0,001349 mm. Ausgerichtet erreicht Marcus ungefähr 4,1 m/s; die rückwärtige Geschwindigkeit und die Zahl rückwärtiger Laufclip-Frames betragen null.

Die LOD-Prüfung umfasst Held, Marcus und Frontier-Zivilist, beide Gangarten, beide Füße und alle drei Taktungen. Nach dem Fix sind die Änderungen des gespeicherten Offsets, des freigegebenen Offsets und die Positionsabweichung der ersten Schwungpose zur Kontrolle in allen 36 Fällen null. Die größte Quaternion-Winkelmetrik beträgt 0,055953 Grad bei einer Toleranz von 0,1 Grad. Auf der Originalquelle betrug der zusätzliche Offset beim 60-Hz-Laufen etwa 68,333 mm und beim 30-Hz-Laufen etwa 136,667 mm.

Die 30-Hz-Stressfälle behalten größere Positionsschritte als die Ausgangsquelle: 314,734 auf 326,883 mm beziehungsweise 331,275 auf 340,409 mm. Bei 60 Hz rechts erhöht sich die Bodenüberlappung von 4,794 auf 8,401 mm; sie bleibt dort unter 10 mm. Bei 30 Hz liegt die Bodenüberlappung bereits vor und nach der Korrektur bei ungefähr 10,5 mm. Die Regression erteilt keine allgemeine Freigabe aller Qualitätsmetriken über alle Taktungen.

Beide neuen Tests sind in `tools/check_prototype.py` registriert. Der aktualisierte Implementierungsbericht benennt den verworfenen 0,3-Kandidaten, die verbliebenen Verschlechterungen und das offene Gate ausdrücklich.

## Belege und Integrationsgrenze

`independent-review.json` enthält die aus den Rohdaten unabhängig extrahierten Werte, Worst-Frame-Kontexte und Codehashes. `source/` und `baseline/` sichern die geprüften Dateien. Die ursprünglichen und aktuellen Rohprotokolle sind beigelegt; `SHA256SUMS.json` bindet sie an dieses Review.

Dieses Verzeichnis gehört zum neuen Projektion-/LOD-Kandidaten. Die separat archivierten früheren 0,3-Berichte bleiben historische, verworfene Kandidaten. Keine Produktions-, Test- oder Assetdatei wurde durch dieses Review geändert.
