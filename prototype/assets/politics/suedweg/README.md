# Bohlen am Südweg

Originale Blender-Modelle für das Beweisstück und die sichtbare Holzspende. Zwei intakte Bohlen liegen über dem schmalen Ablauf. Das Ende der mittleren Bohle liegt rund 11 cm tiefer, wo Schotter und Auflage ausgespült sind. Das Ersatzholz ist ein getrenntes Modell aus sechs gestapelten, verschnürten Bohlen.

- **suedweg_bohlen.glb** misst rund 1,40 m in X und 1,02 m in Z. Ursprung in der Mitte, Bodenhöhe Y = 0. Die Bretter verlaufen entlang X, das abgesackte Ende liegt in Richtung +X.
- **suedweg_ersatzbohlen.glb** besitzt am Modellmittelpunkt denselben Bodenbezug. Es ist als eigenständige Instanz für die Holzspende vorbereitet.
- Die sichtbaren Details haben keine Kollisionskörper. Sie werden seitlich vom bestehenden Laufweg platziert. Das Modell verändert den Weg physisch nicht.
- Holz und Stein verwenden den eingebetteten eigenen IMPERATHEN-PBR-Atlas. Die Blender-Quelldatei enthält dieselben Karten gepackt.

## Export und Test

```sh
blender -b -t 2 --python-exit-code 1 --python tools/world/build_suedweg_bohlen.py
godot --headless --path prototype --import
godot --headless --path prototype --script ../tools/world/verify_suedweg_bohlen.gd
```

Der Test prüft die separate Sichtbarkeit des Ersatzholzes, die Absenkung im importierten Modell und den Materialimport. Mit einem grafischen Display und **-- --capture** entsteht eine lokale Godot-Ansicht.
