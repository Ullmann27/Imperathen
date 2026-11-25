# Unabhängiges Review: starre Meshy-Fußgewichte erhalten

## Ergebnis und Umfang

Die schmale Korrektur in `smooth_reduced_weights` ist fachlich und im Code nachvollziehbar; es besteht kein konkreter statischer Blocker. Die zusätzliche Godot-Regression bildet den tatsächlichen Fehler ab und scheitert auf dem Gait-Kandidaten ohne Gewichtskorrektur. Sie besteht nach der gezielten Wiederherstellung der zuvor starren Fußzuordnung.

Die bereits geprüfte Gait-IK wird durch diesen Zusatz nicht erneut geändert. Ein unabhängiger AST-Vergleich zwischen dem gesicherten Gait-Kandidaten und dem aktuellen Generator ergibt ausschließlich Änderungen an `smooth_reduced_weights` und `export_tiers`. Letzteres erfasst zusätzlich die Zahl erhaltener Originalzuordnungen im Baubericht.

Dies ist ein unabhängiges Lesen und Auswerten von Produktionscode, Testcode und vorhandenen Rohprotokollen. Es wurde keine zusätzliche Engine- oder vollständige Testsuite gestartet. Produktions-, Test- und Assetdateien bleiben durch dieses Review unverändert.

## Tatsächliche Ursache

Der untersuchte Blender-Vertex 290 hat vor dem Glätten ausschließlich `Foot_R = 1.0`. Das vorhandene Glätten machte daraus ungefähr `Foot_R = 0.808618665` und `Shin_R = 0.191381350`. Die ursprüngliche Autorzuordnung an derselben Position war ebenfalls starr an Foot_R gebunden.

Der entsprechende exportierte Engine-Vertex 992 wurde während des Standkontakts um 17,269032 mm verschoben, obwohl sich der Fußknochen nur ungefähr 0,000213 mm bewegte. Die verformte Oberfläche war dadurch nicht am Standfuß befestigt. Blender- und glTF-Vertexnummern bezeichnen unterschiedliche Indexräume; sie dürfen nicht gleichgesetzt werden.

## Prüfung der Maske

Die Maske wird direkt aus den tatsächlichen Gewichten nach Decimation und vor dem Glätten gebildet. Nur Zeilen mit positiver Zuordnung zu Foot_L oder Foot_R und exakt einem Nichtnullgewicht werden erfasst. Ein auch nur geringfügig gemischt gebundener Vertex wird nicht als starr umklassifiziert. Die Auswahl verwendet weder Position, Höhenzone noch Profilparameter.

Beide bestehenden Glättungspässe laufen vollständig mit demselben Datenfluss weiter. Erst danach werden die vorher gespeicherten starren Zeilen wieder eingesetzt. Deshalb bleiben die nichtmaskierten Ergebnisse einschließlich ihrer beiden Nachbarschaftspässe unverändert. Eine Wiederherstellung zwischen den Pässen, die Nachbarzeilen zusätzlich verändert hätte, findet nicht statt.

Die bestehende Auswahl der vier größten Gewichte und ihre Normalisierung bleibt erhalten. Eine einzige positive Foot-Zuordnung wird damit wieder zu einer vollständigen Bindung an denselben Fuß. Fehlt ein Foot-Vertex-Group oder gibt es keine passenden Zeilen, entsteht keine neue Zuordnung. Die endgültige Ausgabe enthält weiter dieselben Geometriekoordinaten und Indizes.

## Gegenprobe auf tatsächlichen Oberflächen

Die neue Erweiterung von `motion_skin_measurement_test.gd` verwendet reale VillagePerson-Modelle, den Produktionsbewegungscode und CPU-verformte Sohlenpunkte. Sie simuliert einen vollständigen Gangzyklus mit höchstens 1/60 Sekunde pro Schritt. Geprüft werden Axe und Signifer bei LOD 0 und 3, jeweils march und run. Die Prüflogik verlangt Kontakte beider Füße, endliche Werte, maximal 15 mm Standversatz, maximal 10 mm Sohlenpenetration und keine Skin-Edge-Verletzungen.

Die Anker werden nur über zusammenhängende, tatsächlich unterstützte Kontakte fortgeführt. Mit dem Bone-Kontakt allein hätte der Fehler bestanden; die neue Prüfung erfasst ausdrücklich die Meshpunkte.

| Prüffall | Gait-Kandidat ohne Gewichtskorrektur | Mit Erhalt starrer Fußgewichte |
| --- | ---: | ---: |
| Gesamte Skin-Regression | 300 Checks, 1 Fehler | 300 Checks, 0 Fehler |
| Axe LOD 3, march: Versatz | 17,269032 mm | 0,000246 mm |
| Axe LOD 3, run: Versatz | 13,125321 mm | 0,000240 mm |
| Signifer LOD 3, march: Versatz | 6,023500 mm | 0,000246 mm |
| Signifer LOD 3, run: Versatz | 4,809031 mm | 0,000359 mm |

Die Axe-LOD3-Kontaktanzahlen bei march bleiben vollständig: links 604 auf 608, rechts 672 auf 672. Der Erfolg wird also nicht durch verschwundene Kontakte erzielt. Die Grenzwerte bleiben unverändert. Der einzige Fehler der Gegenprobe ist der konkrete Axe-LOD3-march-Versatz oberhalb von 15 mm.

## Acht abgeleitete Modelle und verbleibende Abnahme

Die acht vorhandenen finalen GLB-Dateien stimmen unabhängig per SHA-256 mit dem finalen Accessorbericht überein. Der Bericht zeigt für jedes Modell unveränderte Geometrieattribute und Indizes, unveränderte Animationskanäle gegenüber dem Gait-Kandidaten und neun unveränderte Nicht-Gang-Clips gegenüber dem ursprünglichen Commit. Die zusätzlichen Änderungen betreffen ausschließlich JOINTS_0 und WEIGHTS_0; jede geänderte Zuordnung endet starr auf dem bereits gewählten Fuß.

Die geänderten exportierten Binding-Zahlen sind Axe LOD 0–3: 126, 134, 96, 56; Signifer LOD 0–3: 179, 147, 95, 48. Diese Zahlen zählen exportierte Vertices einschließlich Nahtduplikaten. Sie sind nicht mit der Anzahl ursprünglicher Blender-Zeilen gleichzusetzen.

Unveränderte Animationskanäle beweisen bei veränderten Gewichten keine identische verformte Oberfläche in allen übrigen Clips. Die neue Regression überprüft konkret die acht Gangfälle auf den beiden äußersten LOD-Stufen. Der bereits von rig_audit ausgeführte beziehungsweise vorbereitete Vergleich sämtlicher Clips aller acht Modelle bleibt für die vollständige Oberflächenabnahme relevant. Ebenso ersetzt dieser Codebefund keine visuelle Abnahme und keine Android-Leistungsmessung.

## Gesicherte Belege

Die beiden Quellen, der zusätzliche Test, die isolierte Gewichtskorrektur, die Autor-/Engine-Proben, der vollständige Accessorbericht und die Originalprotokolle liegen in diesem Verzeichnis. `independent-review.json` enthält die überprüften Dateihashes und die unabhängige Eingrenzung der geänderten AST-Knoten. `SHA256SUMS.json` bindet alle Belege an diesen Reviewstand.
