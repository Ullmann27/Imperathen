# Das Atriumhaus im Italia-Dorf

Die bereits platzierte Domus bei Godot-Koordinate (14, 0, −30) hat einen durchgehenden Zugang von der Straße zum Innenhof. Am Eingang stehen zwei beschlagene Holzflügel offen. Steinwangen, Schwelle, vergitterte Fenster, angeschlagene Läden und der gemauerte Sockel geben der Fassade Tiefe. Das flache Ziegeldach führt zur zentralen Öffnung, dem *compluvium*. Dort sind die gebrannten Flachziegel und hohlen Deckziegel, die Sparren und die auf vier Säulen ruhenden Balken sichtbar. Darunter umgeben ein Mosaik, eine Bank, zwei Gefäße und bemalte Wandfelder das Wasserbecken, das *impluvium*.

**[Vorher und nachher im direkten Vergleich](review/vergleich.jpg)**

| Kamera | Vorher | Nachher |
| --- | --- | --- |
| Straße | [Originalaufnahme](review/strasse_before.png) | [Originalaufnahme](review/strasse_after.png) |
| Innenhof | [Originalaufnahme](review/hof_before.png) | [Originalaufnahme](review/hof_after.png) |
| Dachöffnung | [Originalaufnahme](review/dach_before.png) | [Originalaufnahme](review/dach_after.png) |

Alle sechs Bilder stammen aus Godot 4.7.2, Compatibility auf Mesa llvmpipe. Die Prüfszene lädt das Gebäude über den tatsächlichen Dorfaufbau `show_origin("italia")`. Die Aufnahmen verwenden pro Bildpaar denselben Kamerastand, dieselben Lichteinstellungen und 1200 × 750 Pixel. Die Umgebung und der Boden der Prüfung dienen dem reproduzierbaren Vergleich. Die ältere Geometrie stammt aus Commit `eb0d6b2`.

## Import und Prüfung

| Tatsächlich importiertes Asset | Vorher | Nachher |
| --- | ---: | ---: |
| Render-Vertices einschließlich UV-/Normalengrenzen | 8.640 | 42.652 |
| Dreiecke der höchsten Stufe | 4.912 | 21.756 |
| Oberflächen / Materialien | 1 / 1 | 1 / 1 |
| Automatisch erzeugte Godot-LOD-Dreieckzahlen | 1.144, 332 | 8.520, 3.736, 1.668, 820, 240 |
| Ausdehnung (X, Höhe, Z) in Metern | 11,500 × 3,650 × 10,500 | 11,530 × 3,904 × 10,555 |
| GLB-Dateigröße in Bytes | 654.064 | 3.005.752 |

Ein zusätzlicher grafischer Test rendert nur das importierte Asset in einem 480 × 320 Pixel großen Viewport ohne Schatten. Bei 12 und 70 m reichte Godot 21.756 Dreiecke ein, bei 150 m 3.736 und bei 330 m 1.668. Diese Distanzen hängen von Auflösung, Sichtfeld und LOD-Einstellung ab. Die Budgetprüfung erlaubt bis zu 22.000 Dreiecke der höchsten Stufe und genau eine Oberfläche. Eine gerätespezifische Bildzeit für das einzelne Gebäude ist offen. [Vorher-Messung](review/before.json) · [Nachher-Messung](review/after.json)

Der Architekturtest prüft neben den importierten Materialien und absteigenden LOD-Größen auch den Durchgang. 25 Strecken von der Straße in die Eingangshalle bleiben sowohl im sichtbaren Dreiecksmesh als auch im Physikmodell frei, bei Querpositionen zwischen −0,78 und +0,78 m und Höhen zwischen 0,17 und 2,19 m. Kontrollstrahlen links und rechts treffen auf die Fassade.

## Quelle und Nachstellen

Geometrie und Texturen wurden für IMPERATHEN lokal erstellt. Das Modell ist eine römisch inspirierte Architekturstudie. Die editierbare Blender-Datei enthält die gepackten Texturen. Der 768²-Farbatlas enthält Holzmaserung, verwitterten Kalkputz, Ockerpigmente, Steinporen, Ton und Mosaik. Eine 768²-Normalmap und eine 192²-Rauheits-/Metallkarte ergänzen das Material. Der Generator nutzt die ursprünglichen Baumaße und die vorhandenen Geometriehilfen der Siedlungsmodelle. [Blender-Quelle](atrium_house.blend) · [Geometriegenerator](build_atrium.py) · [Materialgenerator](atrium_materials.py) · [Godot-Prüfung](verify_atrium.gd)

Vom Repository-Stamm mit Blender 4.3.2 (Python mit NumPy und Pillow) und Godot 4.7.2 ausführen. Der letzte Befehl benötigt einen grafischen Desktop.

```sh
blender -b -t 3 --python-exit-code 1 -P art/architecture/build_atrium.py
godot --headless --path prototype --import
godot --headless --path prototype --script "$PWD/art/architecture/verify_atrium.gd"
godot --path prototype --rendering-method gl_compatibility --script "$PWD/art/architecture/verify_atrium.gd" -- --after
```

Für die historischen Bilder eine separate Projektkopie anlegen. In dieser Kopie die Dateien `prototype/assets/architecture/atrium_house.glb` und `atrium_house.glb.import` aus `eb0d6b2` wiederherstellen, neu importieren und denselben grafischen Befehl mit `--before` ausführen. Der Prüfer erkennt das historische Mesh vor dem Schreiben der Vergleichsbilder.
