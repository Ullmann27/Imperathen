# Werkstatt und Taberna für die spätrepublikanische Stadtstraße

Eigenentwurf in Blender 4.3.2 für das fiktive Stadtstück von 58 v. Chr. Tuffsteinsockel, Kalkputz, Holzläden, Schwellsteine, Tegulae und Imbrices orientieren sich an römischen Bauweisen. Die Kombination von Schmiede und Schankstube unter einem Dach ist eine Gestaltung für IMPERATHEN.

## In Godot platzieren

- Der Modulursprung liegt ebenerdig auf der vorderen Fassadenmitte. Tiefe entlang +X, Länge entlang Z. Das Mauerwerk misst 6,4 × 9,6 m. Der Innenfußboden liegt bei Y = 0.
- Beide Eingänge weisen zur Straße in Richtung −X. Die Türmitten liegen bei Z = −2,4 m für die Schmiede und Z = +2,4 m für die Taberna. Jede Öffnung ist 1,5 m breit und 2,25 m hoch.
- `roman_workshop.glb` enthält fünf sichtbare Teilmeshes mit einem gemeinsamen Material und eingebetteten Albedo-, Normalen- und Oberflächentexturen. `Blacksmith` und `Taverna` enthalten getrennte Möbelgruppen.
- `roman_workshop_collision.glb` enthält 18 physische Hüllen. Für Kollisionskörper am selben Ursprung verwenden. `collision_boxes()` im Generator enthält die Koordinaten von Wänden, Schwellenbereich, Esse, Werkbank, Regal, Theke und Sitzplätzen.
- Die gepackte Blender-Quelle in `source/` lässt sich unabhängig bearbeiten. Godot schließt sie über `.gdignore` vom Laufzeitimport aus.

## Reproduktion und Prüfung

Vom Repository-Stamm ausführen.

```sh
blender -b -t 2 --python-exit-code 1 --python tools/world/build_roman_workshop.py
godot --headless --path prototype --import
godot --headless --path prototype --script ../tools/world/verify_roman_workshop.gd
```

Godot 4.7.2 prüft die Öffnungen mit einer 48-cm-Spielfigurkapsel, die Boden- und Möbelkollision sowie den Import aller Texturkanäle. Mit einem grafischen Display und `-- --capture` erzeugt der Prüflauf drei lokale Ansichten. Der Export ergibt 22.181 sichtbare Dreiecke. Geometrie und Texturen stammen aus den Original-Generatoren im Projekt.
