# Geöffnete Wachstafel

Die Requisite für den Verkaufstresen besteht aus zwei gebohrten Holztafeln, texturierten Wachsfeldern, Flachsbindungen und einem hölzernen Griffel mit abgeflachtem Glättende. Buchstaben, Mengen, ältere Ritzspuren und Holzmaserung wurden für IMPERATHEN erzeugt. Die Einträge sind fiktionale Warenvermerke. Die spätere archäologische Parallele aus London belegt die Bauform aus Holz mit abgesenkter Wachsfläche und die Verwendung eines Griffels. Maße, Materialauswahl, Bindung und Gestaltung sind eigenständige Spielrekonstruktionen. [Roman Inscriptions of Britain, The tablets: their form and epigraphy](https://csad.romaninscriptionsofbritain.org/tablondbloomberg/form-epigraphy)

Die Godot-Achsen sind X = 0,295 m quer, Z = 0,190 m tief und Y = 0,017319 m hoch. Der Ursprung liegt mittig auf der Auflageebene. Eine einzige Mesh-Instanz besitzt 2.216 Dreiecke und sechs Materialflächen. Drei Farb- und drei Normaltexturen sind direkt in der GLB enthalten. Der Godot-Import bleibt mit eingebetteter Basis-Universal-Kompression eine einzelne Szene. [GLB](../../prototype/assets/roman_quarter/tablet/wax_tablet.glb) · [Bearbeitbare Blender-Datei](wax_tablet.blend)

## Reproduktion

```sh
blender -b -t 3 --python-exit-code 1 --python tools/world/build_roman_tablet.py -- --render
godot --headless --path prototype --import
godot --headless --path prototype --script "$PWD/tools/world/verify_roman_tablet.gd"
```

Godot 4.7.2 meldete `WAX_TABLET_PASS` in einem frisch importierten Prüfprojekt mit derselben Asset-Pfadstruktur. Die Bilddatei stammt aus Blender 4.3.2. [Blender-Studioansicht](wax_tablet_blender.jpg)
