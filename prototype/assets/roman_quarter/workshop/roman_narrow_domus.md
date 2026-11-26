# Stadtwohnhaus mit Laden für die spätrepublikanische Straßenzeile

Eigenentwurf in Blender mit 9 m Straßenfront, 5 m Haustiefe, zwei Geschossen und einem Giebel zur Straße. Kalkputz, Tuffsteinsockel, Travertinfenster, geöffnete Holzläden und das kurze Ziegeldach vor dem Laden nutzen eigene, gebackene PBR-Oberflächen. Das Erdgeschoss enthält eine Ladentheke mit Lager und einen getrennten Wohnflur mit Bank und Truhe.

## Platzierung und Quellen

- Lokaler Ursprung auf der vorderen Fassadenmitte. Grundstück hinter der Front entlang +X, Fußboden Y = 0. Bei einer Rotation um 180° und einem Ursprungsort von (23,5 m, 0,285 m, 2,9 m) liegen die Türmitten im Straßenraster bei Z = 4,9 m und Z = 0,8 m.
- Die Ladenöffnung bei lokal Z = −2,0 m ist 1,88 m breit. Der Hauszugang bei Z = +2,1 m ist 1,34 m breit. Die offene Höhe beträgt rund 2,25 m. Beide Räume liegen auf Straßenhöhe. Das Obergeschoss ergänzt die Stadtansicht.
- Das Haupt-GLB enthält fünf Teilmeshes mit 22.944 Dreiecken und gebackenen Albedo-, Normalen- und Oberflächenkarten. Das Kollisions-GLB enthält 12 vereinfachte Hüllen für begehbaren Boden, Wände und größere Möbel.
- Die Blender-Quelle unter `source/roman_narrow_domus.blend` enthält die gepackten Karten. Der Python-Generator verwendet die bestehende eigene Materialpipeline der Werkstatt mit einer anderen, wärmeren Farbpalette.

## Reproduktion

```sh
blender -b -t 2 --python-exit-code 1 --python tools/world/build_roman_narrow_domus.py
godot --headless --path prototype --import
godot --headless --path prototype --script ../tools/world/verify_roman_narrow_domus.gd
```

Der Godot-Test montiert das Haus mit der vorgesehenen Straßenrotation, prüft die beiden Wege mit einer 48-cm-Kapsel und prüft die Rückwand, die Straßenwand sowie die PBR-Texturen. Die Option `-- --capture` schreibt mit einem grafischen Display eine lokale Echtszene.
