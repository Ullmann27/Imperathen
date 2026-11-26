# Landschaft um Valdora – Stand 26.11.2026

Branch `fix/village-backdrop-terrain-20261126`. Ehrlicher Zwischenstand nach der Abschlussanweisung des Auftraggebers: **implementiert** heißt Code vorhanden, **getestet** heißt in dieser Sitzung mit dem genannten Befehl gelaufen, **gerendert** heißt echtes Godot-Bild vorhanden. Gerätemessungen (Fold7) gibt es nicht.

## Commits

| Commit | Inhalt | Stand |
|---|---|---|
| `7313af0` | Nördliche Hügelkette als geschlossene, feste Landform; Bachquelle am Hangfuß; erste Farbkorrektur | getestet und gerendert (Vorgänger, siehe [ASSETS_AND_WORLD.md](ASSETS_AND_WORLD.md)) |
| `cc68146` | `valdora_land.gd`: eine gemeinsame Maske für Wege, Bach und Ried | Skript geprüft (Stichproben), Grundlage der folgenden Arbeit |
| `b56b1ca` und Folgecommit | `wip`: gemeinsamer Bodenshader, eingetiefter Bach, Wege, Hohlweg, Fernrelief, Kamera-Sichtweite | siehe unten |

## Was implementiert ist

- **Eine Maske für Gelände und Vegetation** (`prototype/scripts/world/village/valdora_land.gd`, GLSL-Spiegel `valdora_land.gdshaderinc`): vier Wege ab den tatsächlichen Toröffnungen der äußeren Palisade (Nord über den Hügel, Süd, Ost ab dem Torhof, West ab der Brücke in den Wald), Bachmitte und -breite, Fortsetzung als schmaler werdende Rinne ins Ried bis z = 112, Profil des eingetieften Bachbetts. Die Vegetation (`feat/vegetation-20261126`) soll dieselbe Datei benutzen; die Übergabe steht in der Notiz für den Vegetations-Agenten und wurde über die Leitung weitergegeben. Ob sie dort bereits eingebaut ist, wurde hier nicht geprüft.
- **Ein Boden statt vier** (`prototype/scripts/world/land/land_surface.gdshaderinc`, `terrain.gdshader`): Dorfboden, gestreamtes Regionalgelände und Hügel setzen dieselbe Grasnarbe fort; außerhalb des Dorfes kommen fleckige Wiesenfarben, auf den Hügeln Gestrüpp, an steilen Flächen Schutt und Fels, auf den Wegen ausgetretene Erde dazu. Der frühere 14-m-Übergang auf eine einfarbige Geländefarbe entfällt.
- **Farbraum**: Farben kommen nur noch aus `source_color`-Texturen und -Uniforms; Vertexfarben sind Gewichte (Gestrüpp, Stein, Schattierung), keine Farben. Hintergrund (aus dem Shadertext der verwendeten Engine 4.7.2 gelesen): Der Compatibility-Renderer rechnet im Shader mit den gespeicherten sRGB-Werten und linearisiert `ALBEDO` erst danach, Forward+/Mobile linearisieren die Eingaben. Mit `source_color` übernimmt die Engine das in jedem Renderer selbst; rohe Vertexfarben müsste man je Renderer unterschiedlich behandeln. Der Dunst der Umgebung wird vom Shader selbst geschrieben (`FOG`), mit den Werten der `Environment`.
- **Regionalgelände** (`regional_terrain.gd`): Normalen aus dem Höhenfeld statt je Sektor geglättet (keine Lichtnaht an Sektorgrenzen). 13 Geländezellen unter dem eingetieften Bach bleiben offen; der Dorfboden füllt sie.
- **Bach** (`brook.gd`, `water.gdshader`): Der Bach liegt nicht mehr als Fläche auf dem Boden, sondern in einem Bett (Ufer fällt über 0,9 m zur Wasserlinie bei y = −0,16 m, Sohle bis −0,62 m). Kollision = gezeichnetes Bett; auf der Brücke trägt die Bohlenfläche (mit kurzen Rampen an beiden Enden statt einer 9-cm-Stufe). Wasser: in der Flachzone durchsichtig über Kies und Schlick, mit der Tiefe dunkler, Himmelsspiegelung bei flachem Blick, zwei wandernde Wellenlagen, schmale Uferlinie. Texturen eigene prozedurale Arbeit (`tools/world/landscape_textures.py`).
- **Hügelweg** (`backdrop_hills.gd`): Der Nordweg quert die Kette in einem Hohlweg (Sattel rund 5 m statt 11–19 m daneben, quer zur Spur eben).
- **Weite Sichtachsen** (`land/far_relief.gd`, `far_relief.gdshader`): Fernes Land in zwei Zeichenaufrufen: vier ineinanderliegende Raster des Regionalhöhenfelds (250 m bis 2 km Zellen) unter dem gestreamten Gelände, dahinter eine Gebirgskette jenseits des Nordrands der 32-km-Region (frei erfundene Kulissengeografie, bis rund 3 000 m, von Valdora aus höchstens 4,3° über dem Horizont). Hohe ferne Flächen behalten einen Rest Kontrast über dem Taldunst; Schneegrenze je Jahreszeit. Die Weltkamera reicht statt 300 m nun 70 km.

## Getestet (headless, Godot 4.7.2, Linux-Desktop)

Jeweils `Godot --headless --path prototype --fixed-fps 60 --script res://tests/<name>.gd` als Einzellauf:

- `village_backdrop_test.gd`: 60 Prüfungen, 0 Fehler (Stand `818be04`).
- `regional_terrain_test.gd`: 8 688 Prüfungen, 0 Fehler (Stand `b56b1ca` plus Testkorrekturen).
- `village_landscape_test.gd` (neu, Gruppe `village_landscape`): 64 Prüfungen, 0 Fehler auf dem Stand vor der einzeiligen Korrektur der ersten Wasserreihe; danach nicht erneut gelaufen. Gemessen u. a.: 600 Wegpunkte mit Kollision an der sichtbaren Fläche und ohne Hindernis, Hohlweg längs höchstens 17,8°, quer 4 cm Gefälle; Bachbett als erste Trittfläche, Füße beim Durchwaten bis 0,47 m unter dem Wasserspiegel, auf der Brücke 0,081 m; Fernrelief 5 112 / 7 772 / 15 112 / 25 152 Dreiecke (Leicht bis Ultra, 2,2–3,2 % der sichtbaren Primitive des Profils), feineres Raster überall mindestens 1,9 m über dem gröberen.

## Nicht getestet, nicht gerendert

- **Kein einziges Bild dieses Standes.** Die neuen Shader (`land_surface.gdshaderinc`, `terrain.gdshader`, `far_relief.gdshader`, `ground.gdshader`, `water.gdshader`) wurden noch von keinem Renderer übersetzt; ein Übersetzungsfehler oder ein falsches Aussehen ist möglich. Vorher/Nachher-Bilder, Zeichenaufrufe und Primitive je Profil bei 70 km Sichtweite sowie der Abgleich GLSL-Maske gegen Skript fehlen.
- Volle Testsuite und Motion-Gate liefen auf diesem Stand nicht; ebenso die übrigen Dorfgruppen (`village_collision`, `village_scenery`, `village_experience`, `world`, `seasons`).
- Tiefenpuffer bei 70 km Sichtweite (Flimmern an fernen Graten) ungeprüft; Figuren ohne Physik (Bewohner auf festen Routen) würden beim Queren des Bachs weiterhin auf Bodenhöhe laufen.

## Nächste Schritte

1. Render mit dem Skript im Arbeitsverzeichnis des Agenten (`scratchpad/land/v2/zz_land_render2.gd`, 14 Kameras, schreibt Zeichenaufrufe und Primitive je Ansicht); Vorher-Baum auf `7313af0` liegt unter `scratchpad/land/before_tree`.
2. Shaderfehler beheben, Farben am Dorfrand und Dunst am Sektorrand ansehen, dann Dorfgruppen, volle Suite und Motion-Gate.
3. Mit der Vegetation abgleichen, dass sie `valdora_land.gd` benutzt (ihr Ostweg lief in die geschlossene Palisade).
4. `ASSETS_AND_WORLD.md` (Abschnitt Farbraum und 14-m-Übergang) an diesen Stand anpassen, sobald er gerendert ist.
