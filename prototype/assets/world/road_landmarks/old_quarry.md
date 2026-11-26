# Alter Steinbruch

Kleiner fiktiver Arbeitsplatz für die Region von Valdora. Drei modellierte Felsbänke mit Kalksteinadern und bearbeiteten Flächen, seitlich gelagerte Zuschnitte, hölzerne Ladeschienen, Schutt und ein vorn offener Schuppen. Form, Geometrie und gebackene PBR-Karten sind Eigenproduktion mit Blender 4.3.2. Die Gestaltung zeigt einen plausiblen Arbeitsplatz und dient als Landschaftsziel.

## Positionierung

- Ursprung an der offenen Vorderkante, lokale Tiefe entlang +X, Breite entlang Z. Der mit der Route abgestimmte Standort liegt rund 4 m hinter (1500 m, −750 m) bei (1503,104 m, −752,524 m). Das Modul um +39,1° um Y drehen. Die Ursprungshöhe folgt der tatsächlichen Terrainoberfläche mit rund 4 cm Zugabe.
- Die Geometrie folgt der lokalen Tangente um 0,029 m/m in X und 0,057 m/m in Z. Die durchgehende Bodenfläche liefert das Weltterrain. Die Ankunftsspur bleibt rund um Z = 0 bis 11 m vor der Felsfront offen.
- **old_quarry.glb** enthält 16.754 Dreiecke in vier sichtbaren Teilmeshes. Albedo-, Normalen- und Oberflächenatlas sind eingebettet. **old_quarry_collision.glb** enthält 15 benannte Mesh-Hüllen für Fels, Steinblöcke, Pfosten, Rückwand und Werkbank. Mit gleicher Position und Drehung als statische Physik auf Layer 1 einhängen. Beim Collision-Import sind LOD und Schattenmeshes abgeschaltet.
- Die bearbeitbare Blender-Quelle in **old_quarry_source/** enthält die drei eigenen Texturkarten gepackt. Godot ignoriert den Quellordner. Prüfsummen und Herkunft erfasst **old_quarry_asset.json**.

## Reproduktion und Modellprüfung

```sh
blender -b -t 2 --python-exit-code 1 --python tools/world/build_roman_quarry.py
godot --headless --path prototype --import
godot --headless --path prototype --script ../tools/world/verify_roman_quarry.gd
```

Der Godot-Test prüft das importierte Modell mit einer 48-cm-Kapsel auf der abgestimmten Neigung. Drei Spuren zur Arbeitsfläche und der Schuppenzugang sind frei. Fels, Blöcke und Schuppenrückwand bilden Hindernisse. Mit grafischem Display und der Option **-- --capture** entsteht eine lokale Godot-Ansicht.
