# I-01: Frühstücksbrot

Der vorhandene Eintrag `table_bread` bleibt genau einmal auf dem Tisch des
Familienhauses. Ursprung, Stellfläche, Collider und Spielstand bleiben im
Einrichtungskit. Nur das sichtbare Modell wurde ersetzt.

`build_breakfast_bread.py` erzeugt in Blender 4.0.2 die editierbare
`breakfast_bread.blend` und die Spielressource
`prototype/assets/operation_prima/table_bread.glb`. Im Blender-Dokument
sind Brett und eingeschnittener Laib zwei eigene, metrische Objekte;
Studiokamera und Beleuchtung liegen in einer getrennten Collection. Im Export
bleiben ein Mesh, drei Materialien und 1.148 Dreiecke (Manifestgrenze 1.184).
Farbe, Normalen und Rauheit stammen aus einem eigenen, reproduzierbar
erzeugten 1.024 × 512-Atlas, nicht aus dem allgemeinen Möbelatlas.
Keine externen Modelle, Texturen oder Sprachquellen.

Aus der Repository-Wurzel:

    blender -b -t 2 --python-exit-code 1 -P art/operation_prima/build_breakfast_bread.py -- --studio-dir artifacts/viva-bread-review
    godot --headless --path prototype --import --quit
    godot --headless --path prototype --script res://tests/operation_prima_art_test.gd

Die Blender-Ansichten prüfen die Requisite. Erst
`operation_prima_table_capture.gd` zeigt sie in der echten ersten
Tischeinstellung von I-01. Dies ist keine Android- oder Geräteabnahme.
