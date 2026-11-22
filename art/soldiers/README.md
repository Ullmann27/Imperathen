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

## Marschierende Talwache

Die [drei Sekunden lange Nahaufnahme](field_march.webm) zeigt einen Bewegungsbefehl in der Talverteidigung bei 768 × 432 Pixeln. Die 72 Einzelbilder stammen aus dem Godot-Viewport. Die Wiedergabe mit 24 Bildern pro Sekunde folgt dem Aufnahmeschritt der Simulation.

Marsch, Lauf und Flucht haben jeweils eine eigene Schrittlänge pro vollständigem Zyklus von 1,30 m, 1,75 m und 1,48 m. Die gebackene Standphase führt den Fuß entgegen der Fortbewegung. Die Schwungphase hebt den Fuß und beugt das Knie. Arme und Oberkörper bewegen sich gegenläufig. Die Handgelenke gleichen einen Teil des Schwungs beim Tragen von Schild und Speer aus. Position, Blickrichtung und Gangphase werden zwischen den Simulationsschritten dargestellt. Bei einer Neuöffnung beginnt jede Figur anhand ihrer gespeicherten Position, Richtung und Kennung. Die genaue frühere Beinphase entlang einer gekrümmten Strecke wird nicht im Spielstand gespeichert.

Die Godot-Bewegungsprobe prüft die importierten Knochen beider animierten Detailstufen. Auf ebenem Boden betrug die größte Längsabweichung des Standknöchels 1,19 cm und seine größte Höhenabweichung 0,56 cm. Der niedrigste Prüfpunkt an Sohle oder Ferse lag 0,54 cm über der Bodenebene. Beim Marsch blieb die Neigung der aus den Handknochen abgeleiteten Schild- und Speerachsen unter 16 Grad. Unebenes Gelände verschiebt den Figurenpivot auf die Terrainhöhe. Die Füße besitzen keine individuelle Hangkorrektur.

Bei der Aufnahme mit Mesa llvmpipe lagen die Mediane des ganzen sichtbaren Viewports bei 197,57 ms Render-CPU, 207,65 ms Render-GPU und 109 Draw Calls. Beide Zeitmessungen betreffen Software-Rendering der vollständigen Szene mit Bildauslese. Die Aufnahme misst keine Android-Bildrate.

```sh
godot --headless --path prototype --script res://tests/soldier_gait_test.gd
godot --path prototype --rendering-method gl_compatibility --script "$PWD/art/soldiers/gait_review.gd" -- /tmp/imperathen-gait-frames
ffmpeg -framerate 24 -i /tmp/imperathen-gait-frames/march_%03d.png -c:v libvpx-vp9 -b:v 0 -crf 33 -pix_fmt yuv420p /tmp/field_march.webm
```
