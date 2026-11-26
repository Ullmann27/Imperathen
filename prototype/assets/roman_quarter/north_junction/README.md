# Nördliche Kreuzung der Handwerksgasse

Blender-Entwurf für ein fiktives Viertel um 58 v. Chr. Töpferwerkstatt, Textilgeschäft, Speicher und Taberna bilden vier bebaute Ecken. Beide Dachrichtungen variieren mit der Parzelle. Offene Läden, Warenregale, Steinsockel, Kalkputz und modelliertes Pflaster stammen aus eigenen Projektwerkzeugen.

## Aufbau

- Der Modulursprung liegt bei Weltposition (28 m, 0,125 m, −17 m), ohne Drehung. Die breite Hauptgasse läuft von Welt-Z = −13 m weiter nach Norden. Die Querstraße führt nach Westen und Osten. Hinter jeder Ausfahrt setzt sich der Weg auf Stadtgrund fort.
- Das Grafik-GLB enthält die Pflasterfläche sowie vier einzelne Gebäude mit gemeinsamem eingebettetem PBR-Material. Es hat 50.010 Dreiecke und fünf Teilmeshes. Das Kollisions-GLB enthält 43 vereinfachte Hüllen, die an derselben Weltposition platziert werden.
- Zwei gemodelte Tafeln tragen die Inschriften `VICVS FABRVM` und `VICVS FIGVLORVM`. Die Wegnamen in `../street_names.json` sind fiktiv und sprachlich an römische Benennungsformen angelehnt. Ihre Rechtecke verwenden Weltkoordinaten. Die Querstraße steht in der Auswahl vor der Handwerksgasse, weil sie den Kreuzungsmittelpunkt belegt.
- Die Materialien und Bauformen sind eine historisch plausible Interpretation für das Spielquartier. Die Grundrisse und die Platzierung sind eigene Entwürfe. Der gepackte Blender-Quellstand liegt in `source/`.

## Reproduktion

```sh
blender -b -t 2 --python-exit-code 1 --python tools/world/build_roman_north_junction.py
godot --headless --path prototype --import
godot --headless --path prototype --script ../tools/world/verify_roman_north_junction.gd
```

Der Godot-Test prüft die offene Fahrbahn in vier Richtungen, die Durchgängigkeit der vier Erdgeschossräume, ihre Wände und den Texturimport. Mit einem grafischen Display und `-- --capture` schreibt er die lokale Straßen-, Übersichts- und Schildansicht.
