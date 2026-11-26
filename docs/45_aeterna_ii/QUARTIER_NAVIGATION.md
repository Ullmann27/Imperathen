# Fußwege zwischen Forum, Werkstätten und Stallhof

Die Stadtbevölkerung verwendet weiterhin den gemeinsamen AStar3D-Graphen. Der Bake lädt die gebaute Stadt und ihre tatsächlich installierten Kollisionskörper. Er verwendet das letzte im Baumodell angegebene Baujahr als konservative Hindernismenge. Dadurch bleiben spätere Monumente bei der Routenberechnung frei. Die Aufnahmeszene und der Spieltest verwenden den Kampagnenbeginn 58 v. Chr.

Alle 591 bestehenden Aktivitäts-IDs bleiben erhalten. Acht neue Ziele im Quartier bezeichnen den südlichen Zugang, die Schmiede, die Taberna, das Wohnhaus, die Kreuzung, beide Querstraßenarme und den Pferdehändler. Der Stallanker wird aus dem rotierten 3D-Händlermarker gelesen. Öffentliche Treffpunkte haben je einen Standplatz. Sie erzeugen weder neue Haushalte noch eigene Handelsbestände.

## Geometrie und Prüfung

Die geometrische Prüfung im Quartier tastet den Boden höchstens alle 50 cm ab. Sie berücksichtigt Fußbodenhöhe, begehbare Neigung, die 25-cm-Stufengrenze des vorhandenen Controllers und den Abstand zwischen interpoliertem Pfad und Boden. Eine 64 cm breite und 1,60 m hohe Kapsel wird entlang der Verbindung durch den statischen Raum bewegt. Außerhalb des Quartiers gilt das bestehende Verfahren mit Strahlen auf drei Höhen.

Beim ersten Lauf fiel die Spielerfigur am nördlichen Pflasterende auf dem Weg zum Stall drei Physiktakte frei. Die Sohle lag bis zu 31,4 mm über dem tieferen Boden. Die Blender-Quelle enthält dort jetzt einen 1,20 m langen, gepflasterten Anschluss mit durchgehender geneigter Kollisionsfläche. Der Walk-Test geht nacheinander durch sieben Ziele der tatsächlich installierten Stadt. Er startet einmal am südlichen Eingang und steuert anschließend ausschließlich die normale Bewegungsachse.

| Befund | Messung |
|---|---|
| Gebackene Stadt | 6.253 Knoten, 26.074 Kanten, 599 Aktivitätsanker |
| Spielbare Route | 127,45 m über sieben Teilstrecken, Händler erreicht, null Physiktakte ohne Bodenkontakt |
| Alte Quartierverbindungen | 107 von 280 geprüften Kanten schneiden feste Geometrie |
| Neue Quartierverbindungen | 0 von 499 geprüften Kanten schneiden feste Geometrie |

Der Kantenvergleich umfasst Verbindungen mit mindestens einem Endpunkt im Messfenster. Er verwendet auf beiden Graphen dieselben beidseitigen Strahlen gegen das bebaute Quartier. Der getrennte Lauf prüft die Spielerform und die normale Stufenlogik in Godot. Die 127,45 m sind die Summe der A*-Polylinien. Die Abnahme deckt diese Wege und den beschriebenen Stadtstand ab.

## Reproduktion

Vorausgesetzt sind die erzeugten Stadt-GLBs und das dazugehörige `prototype/assets/world/roman_city_manifest.json`. Das eingelesene Manifest hatte SHA-256 `f266a75cca14f65219c70bf4e10d4359850171ecb4a9d2a5951d28ed14eab118`, die zugehörige große Stadtkollision `04aca1579bed3346786b9ef1e57433be21fb06ac1e3c76e41f0090ed5560b45d`.

```sh
blender -b -t 2 --python-exit-code 1 --python tools/world/build_roman_north_junction.py
godot --headless --editor --path prototype --import
godot --headless --path prototype --script ../tools/world/bake_city_layout.gd
godot --headless --path prototype --script ../tools/world/verify_roman_north_junction.gd
godot --headless --fixed-fps 60 --path prototype --script res://tests/quarter_street_walk_test.gd
git show 3f61a2d:prototype/assets/city/street_graph.json > /tmp/stadtgraph-vorher.json
godot --rendering-method gl_compatibility --audio-driver Dummy --path prototype \
  --script ../tools/world/quarter_navigation_capture.gd -- \
  /tmp/stadtgraph-vorher.json /tmp/quartieraufnahme 3f61a2d "$(git rev-parse HEAD)"
```

Die grafische Aufnahme schreibt vier Godot-PNGs und ein JSON mit Graph-Prüfsummen, Kamera, Datum, Profil, Renderer und GPU. Die Luftansicht zeigt erst die Stadt, anschließend die alten und neuen Wege durch dieselbe eingefrorene Szene. Orange markiert eine physisch geschnittene Verbindung. Türkis bedeutet, dass die drei Strahlenpaare je Höhe frei waren. Die letzte Aufnahme zeigt die Gasse auf Augenhöhe.
