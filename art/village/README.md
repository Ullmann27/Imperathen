# Valdora – Handwerk und Landschaft

Die Blender-Szenen enthalten die originalen, in Metern modellierten Spielobjekte und gepackte PBR-Bilder. `build_props.py` verwendet Geometrie- und Pigmentfunktionen der hauseigenen Atriumquelle. Holzschindeln, das offene Werkstatttor, Hobelbank mit Spindel, Werkzeugleiste, Vorratssäcke, Marktstand mit Körben, Übungspuppe und Spaltholz sind modelliert. Die Werkstatt steht bei (−9,20 / −7,35), das Lager bei (−10,60 / 15,60), der Stand bei (−9 / 0) in Welt-X/Z. Die Werkstatt, das Lager und der Markt sind gemeinsame Wirtschaftsgebäude. Die regionalen Wohnhäuser und ihre Zugänge liegen weiterhin in der Regionaldorf-Szene.

Die GLBs in `prototype/assets/village` teilen ein Farbatlasbild, eine Tangentennormalkarte und eine Metall-/Rauheitskarte. Die drei PNGs müssen beim Kopieren neben den GLBs liegen. Alle sieben Meshes besitzen je eine Oberfläche. Godot 4.7.2 importiert Werkstatt, Lager, Stand, Übungspuppe und Stamm mit 4/4/2/2/1 zusätzlichen LOD-Stufen. Der Zaun besitzt zwei modellierte Stufen mit 416 und 104 Dreiecken pro Segment. Die einfache Stufe verwendet dieselben vier Pfahlspitzen und hält die Tore offen.

Der Bodenshader zeichnet Fahrspuren, die Kreuzung, den Platz, Ackerfurchen und das Flussufer auf einer zusammenhängenden Fläche. `paint_ground.py` generiert die periodischen Farb-/Reliefbilder und das Wolkenfeld mit festen Seeds. Die Gräser, Blüten und Binsen sind blickrichtungsunabhängige Geometrie. 1.667 Büschel verteilen sich über 99 räumliche Instanzgruppen. Leicht, Ausgewogen, Hoch und Sehr hoch geben davon maximal 413/1.042/1.667/1.667 innerhalb von 24/40/58/72 Metern frei. Schattenreichweite und Auflösung stammen weiterhin aus PR24. Licht, Bodenfeuchte, Schilfbewegung und Wolkendichte reagieren auf die Saison. Herbstregen läuft ab Ausgewogen. `world.set_presentation_time(4.0)` fixiert Wind, Wasser, Wolken und Regen für Spielaufnahmen. Negative Werte setzen die Uhr fort.

## Reproduktion und Prüfung

Vom Repo-Stamm mit Blender 4.3.2, Python mit NumPy/Pillow und Godot 4.7.2 ausführen.

```sh
python art/village/paint_ground.py
blender -b -P art/village/build_props.py
godot --headless --path prototype --import
godot --headless --path prototype --script ../art/village/verify.gd
godot --headless --path prototype --script res://scripts/world/world_smoke.gd
```

Die Dorfprüfung kontrolliert Materialien, geteilte Texturen, Meshbudgets, LOD, alle vier Profile, Regen, festgesetzte Zeit sowie die sichtbare und physische Durchgängigkeit beider Gebäude. Für den Blick über den Platz wird die bestehende Spielkamera bei (1,6 / 2,15 / 10,3) auf (−8,6 / 1,34 / −1,4) gerichtet, Sichtwinkel 60 Grad. Die Messung erfolgte im lokalen Compatibility-Renderer. Daraus lässt sich keine Bildrate für ein bestimmtes Android-Gerät ableiten.
