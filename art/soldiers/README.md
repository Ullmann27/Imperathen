# Feldkompanie

Vier erwachsene, römisch inspirierte Spielrollen aus originaler Geometrie für IMPERATHEN. Die Blender-Quellen enthalten die editierbaren Konturen, Ausrüstung, Atlasmaterialien und Actions. Der Python-Generator baut alle drei Detailstufen. Die Studie übernimmt keine Modelle, Texturen oder Bewegungsaufnahmen Dritter. Eine allgemeine Weiterverwendungslizenz wird hiermit nicht erteilt.

| Rolle | Kennzeichen | Dreiecke nah / mittel / fern | Knochen nah / mittel |
| --- | --- | --- | --- |
| Schweres Fußvolk | Gebogener Langschild mit Metallbuckel, Segmentpanzer, Schwert | 4814 / 2962 / 170 | 15 |
| Speerträger | Ovaler Schild, grüne Tunika, langer Speer | 4682 / 2920 / 168 | 15 |
| Bogenschütze | Kappe, Köcher, Bogen, bewegliche Sehne und Pfeil | 3600 / 2130 / 136 | 17 |
| Offizier | Querkamm, Mantelspange, Bronzeharnisch | 5154 / 3096 / 198 | 15 |

Die Dateien verwenden Meter, Bodenpivot und glTF +Z als Blickrichtung. Die Nahquellen besitzen benannte Vertexgruppen für Gesicht, Schuhe, Rüstung, Helm, Schild und Waffen, soweit zur Rolle passend. Die Meshes belegen je eine Oberfläche. UV-Zellen des selbst erzeugten 128×128-Atlas unterscheiden gewebtes Leinen, Holz, Haut, Leder und Metall. Eine zweite eingebettete Textur steuert Rauheit und Metallanteil. Drei Materialtönungen werden im Godot-Adapter geteilt.

Im Rig folgen Schild und Bogen der Gruppe Hand_L, Schwert und Speer der Gruppe Hand_R. Beim Bogen verformt Nock die Sehne und Arrow trägt den aufliegenden Pfeil. Der Spielzustand kann unabhängig von dieser Darstellung den Treffer auflösen. Waffen lassen sich im Blender-Generator austauschen. Zum Abspielen in Blender die gewünschte Action im Action-Editor auswählen.

Nah und mittel besitzen die elf Clips idle, march, run, attack, shoot, block, wall, testudo, hit, retreat und death. Der Adapter erhält Bewegung und Status vom Taktikmodell. Die fernste Stufe stellt Form und Position statisch dar. Der MultiMesh-Renderer speichert höchstens vier Gruppen und schreibt die sichtbaren Instanzen pro Rolle. Die bemalten Details, polygonalen Gesichter und vereinfachten Stoffkanten sind auf die Spielkamera zugeschnitten. Hand- und Bodenkontakte sind vorgefertigt, ohne Laufzeit-IK oder Kollisionskorrektur.

## Nachstellen

Vom Repository-Stamm mit Blender 4.3.2 und Godot 4.7.2 ausführen.

```sh
blender -b -t 2 -P art/soldiers/build.py
godot --headless --path prototype --import
godot --headless --path prototype --script res://tests/soldier_visual_test.gd
godot --path prototype --rendering-method gl_compatibility --script res://tests/soldier_visual_test.gd -- --render-stats
godot --path prototype --resolution 1280x720 --rendering-method gl_compatibility --script "$PWD/art/soldiers/review.gd"
```

[Godot-Nahaufnahme der exportierten Figuren](runtime_review.png) · [Exportgrößen und Meshstatistik](metrics.json). Der grafische Test vergleicht einen leeren Viewport und 64 Ferndarstellungen bei gleichem Kamerastand. Godot Compatibility mit Mesa llvmpipe meldete 0 bzw. 4 Draw Calls im sichtbaren Pass. Diese Messung betrifft die isolierte Figurenansicht.
