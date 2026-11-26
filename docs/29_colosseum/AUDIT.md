# Kolosseum – Bestandsaufnahme (26.11.2026)

Basis: `integ/reference-candidate-20261126`, Commit `f770025`.

## Befund

- Das bisherige Kolosseum ist kein eigenes Asset, sondern Teil des Stadt-GLB, das `tools/world/build_roman_test_city.py` (Funktion `amphitheatre()`, Zeilen 612–664) erzeugt: vier Fassadenquadranten aus Bogen-/Säulen-Primitiven, acht Cavea-Sektoren als glatte Stufenringe, eine Sandellipse. Position Blender (181, 42), Godot (181, 0, −42).
- Keine Umgänge, Treppen, Vomitorien, Sitzklassen, Podium, Loge, Tore, Hypogäum, Statuen, Eingangsnummern oder Velarium. Kollision nur für die Erdgeschossbögen.
- Kein Vorplatz: Das Bauwerk steht direkt auf dem Stadtboden zwischen Wohnblöcken.
- Epochengrenze: `era_registry.json` führt `building.amphitheatrum_flavium` ab 80 n. Chr.; die GLB-Knoten tragen `era_min_ce=80`. `city_exploration.gd` wertet das nicht aus („Test displays all epochs“) – das alte Kolosseum wäre in einer Stadt des Jahres 58 v. Chr. sichtbar.
- Der Stadt-Build ist mit Blender 4.3.2 reproduziert (`CITY_BUILD_COMPLETE`, 644 Objekte, 1 250 689 Dreiecke instanziert); Blender 4.0.2 war dafür nicht nötig.

## Vorher-Aufnahmen

Godot 4.7.2, `gl_compatibility`, Mesa llvmpipe unter Xvfb, 1280 × 720, Profil `high`, neutrales Tageslicht. Kameras: `prototype/assets/monuments/colosseum/capture_cameras.json`. Dateien und Messwerte: `evidence/before/`. Dies sind keine Geräteaufnahmen.

| Kamera | Draw Calls | Dreiecke im Bild |
|---|---|---|
| exterior_wide | 2139 | 967 168 |
| arcade_closeup | 1017 | 939 978 |
| entrance | 1289 | 1 028 728 |
| cavea_from_arena | 1413 | 918 321 |
| arena_floor | 1671 | 1 053 542 |
| piazza | 2570 | 1 151 431 |

Die Werte enthalten die gesamte Teststadt, nicht nur das Amphitheater.
