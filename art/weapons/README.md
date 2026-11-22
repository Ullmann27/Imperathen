# Gladius und Scutum: ausgeführter Blender-Arbeitsstand

22. November 2026. Ausgangspunkt ist der eigene Generator aus PR #30. Diese Fortsetzung wurde mit Blender 4.3.2 ausgeführt und die exportierten GLBs wurden für die Studiovorschau wieder importiert.

## Konkrete Änderungen

- Geschlossene, gebogene Schildschale mit 14 mm Konstruktionsstärke, eigener Rückseite und umlaufenden Randflächen.
- Die Randprofile und Nieten folgen der Schildkrümmung. Der hintere Griff besitzt zwei sichtbare Halterungen.
- Holz-, Leder-, Leinen- und Bronzematerialien verwenden die ursprünglichen PBR-Maps des Projekts aus `art/visual_benchmark/materials/`; deren Herkunft steht in `provenance.json` im selben Ordner. Die Stahlklinge nutzt konstante PBR-Werte.
- Die Befestigungsmarker sind echte, meshfreie Empty-Nodes: `SOCKET_RIGHT_HAND` und `SOCKET_LEFT_HAND`. Sie enthalten eine Rollenkennzeichnung, keine fertige Bindung an einen Charakterknochen.
- Alle sichtbaren Teile einer Waffe sind in einem Mesh mit Materialflächen zusammengefasst. Die Schildnieten erzeugen daher keine eigenen Mesh-Nodes.
- Die Blender-Quelldateien enthalten gepackte Bildressourcen; die GLBs enthalten ihre eigenen Bilddaten.

## Lieferumfang und Prüfung

| Datei | Dreiecke | Meshes | Materialflächen | Eingebettete Bilder |
| --- | ---: | ---: | ---: | ---: |
| `prototype/assets/weapons/gladius_lod0.glb` | 1.730 | 1 | 3 | 6 |
| `prototype/assets/weapons/scutum_lod0.glb` | 6.380 | 1 | 4 | 9 |

Materialflächen sind keine gemessenen Android-Drawcalls. Die Prüfung in `validation.json` liest tatsächliche GLB-, Accessor-, Index-, Normalen-, Material- und Bilddaten. Der zusätzliche Waffenvertrag verlangt genau einen passenden meshfreien Handmarker. Die zusätzliche Blender-Quellprüfung in `source_geometry_check.json` meldet für beide Modelle null nichtmannigfaltige Kanten, null Flächen ohne Fläche und null ungepackte Bildabhängigkeiten. Die dortigen Bodenpivot-Warnungen bleiben sichtbar: Beide Modelle benutzen absichtlich einen Griffpivot. Das ist keine fehlgeschlagene Bodenaufstellung.

`weapons_studio_preview.png` ist ein Offline-Cycles-Render der erneut importierten GLBs. Das Bild wurde visuell kontrolliert; Schild, Klinge, Griff und Materialunterschiede sind sichtbar. Es belegt keine bereits funktionierende Bewaffnung der Spielfigur und keine Android-Leistung. Die Modellierung bleibt eine einfache eigene Waffenstudie. Fein modellierter Verschleiß, historische Ausrüstungsabnahme und weitere tatsächliche LOD-Dateien fehlen noch; der Dateiname `lod0` behauptet keine vollständige LOD-Kette.

## Wiederholen

Aus dem Repository-Stamm:

```sh
blender --background -t 2 --python tools/build_roman_weapons.py -- \
  --output art/weapons --game-output prototype/assets/weapons --render-preview
python tools/validate_weapon_glb.py \
  prototype/assets/weapons/gladius_lod0.glb \
  prototype/assets/weapons/scutum_lod0.glb \
  --report art/weapons/validation.json
```

Der Workflow `.github/workflows/blender-weapons.yml` führt Generation und Byteprüfung aus. Ein Erfolg dieses Workflows ist keine visuelle Geräteabnahme. Die kanonischen Quellen in diesem Ordner sind `gladius_lod0.blend`, `scutum_lod0.blend` und die gemeinsam eingerichtete `weapons_review.blend`.
