# Valdoras Ratstube

Kleines fiktives Amtshaus im Stil der späten Republik. Tuffsteinsockel und Kalkputz umschließen die Ratsstube mit zwei offenen Lichtfenstern, einer Sitzbank und dem Arbeitstisch für Wachstafeln und Schriftgut. Das Holzblatt der Tür ist an einem eigenen Drehpunkt modelliert und nach innen geöffnet. Die verfügbare Geometrie deckt das Erdgeschoss ab.

## Platzierung

- Ursprung mittig an der Fassadenvorderkante. Die Front blickt nach −X, der Raum erstreckt sich 6,1 m nach +X und 7,2 m entlang Z. Der Boden liegt bei lokal Y = 0.
- Die lichte Türöffnung misst 1,52 × 2,25 m. Der Drehpunkt des geöffneten Holzblatts liegt bei (0,19 m, 0,032 m, −0,818 m).
- Tageslichtöffnungen in beiden Seitenwänden liegen entlang lokal X zwischen 2,0 m und 3,65 m. Die Lichtöffnungen reichen von Y = 1,47 m bis 2,57 m. Der Arbeitstisch steht bei (4,34 m, Y = 0, Z = 1,94 m).
- Beide GLBs am selben Ursprung einhängen. Das sichtbare Modell umfasst fünf Meshes mit 12.909 Dreiecken. Das separate Physik-GLB liefert 17 vereinfachte Hüllen und die Lichtöffnungen bleiben frei. Für eine spätere bewegliche Tür muss die statische Hülle der geöffneten Tür gemeinsam mit dem Holzblatt gewechselt werden.

Die Blender-Datei in **source/** enthält gepackte Albedo-, Normalen- und Oberflächenkarten. Dieselben Karten sind im GLB eingebettet. Die wiederverwendete Materialpipeline und alle Geometrien stammen aus IMPERATHEN. Das Asset-Register erfasst die SHA-256-Prüfsummen.

## Reproduktion

```sh
blender -b -t 2 --python-exit-code 1 --python tools/world/build_valdora_council.py
godot --headless --path prototype --import
godot --headless --path prototype --script ../tools/world/verify_valdora_council.gd
```

Der Test importiert beide GLBs in Godot 4.7.2, nutzt eine 48-cm-Spielfigurkapsel an der Tür und prüft die offenen Seitenfenster, die Kollisionen der Einrichtung und die Texturkarten. Die Option **-- --capture** speichert mit grafischem Display die Fassade und den Innenraum.
