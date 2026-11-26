# Vegetation Valdora (Aquileia-Region, 58 v. Chr.)

Bäume, Sträucher, Reben, Gräser, Blumen und Feldfrüchte für die erste Spielregion. Alle Geometrien und Texturen werden hier aus Code erzeugt; es gibt keine Fotos, Scans oder fremden Modelle. Artenauswahl und Quellen: [docs/vegetation/ARTENLISTE_VALDORA_58VC.md](../../docs/vegetation/ARTENLISTE_VALDORA_58VC.md).

## Reproduzierbarer Bau

Vom Repository-Stamm, Blender 4.3.2 und Godot 4.7.2. Texturen brauchen ein System-Python mit NumPy und Pillow (Blenders Python hat kein Pillow).

```sh
python3 art/vegetation/textures.py                    # Rinde, Blattatlanten, Kraut- und Feldkarten (~1,5 min)
blender -b -t 3 -P art/vegetation/build.py            # 17 Arten x 4 LOD + Impostoren, herb_cards.glb, metrics.json, manifest.json
python3 art/vegetation/import_settings.py             # Godot-Importparameter (VRAM, Mipmaps, Normalmaps, keine Auto-LODs)
godot --headless --path prototype --import
godot --headless --path prototype --script res://tests/vegetation_test.gd
blender -b -t 3 -P art/vegetation/render_review.py -- <out> lineup lods cards   # Cycles-Prüfplatten der re-importierten GLBs
```

Teilbau: `blender -b -P art/vegetation/build.py -- quercus_robur --no-impostors`.

## Aufbau

| Datei | Inhalt |
|---|---|
| `textures.py` | Rinde (gekachelt 512², Voronoi-Platten mit verzweigten Furchen, Flechten, Lentizellen, Pfahlholz) als Albedo + Normalmap; je Art ein Blattatlas 1024² (3 Zweig-Sprays mit einzeln gezeichneten Blättern, Adern, Faltung, Unterseiten; 1 dichter Kronen-Cluster) als RGBA + Normalmap; Kraut- und Feldatlas 2048² (je 4 x 4 Karten) |
| `species.py` | Wuchsparameter je Art (Höhe, Kronenform, Stamm, Wurzelanläufe, Drehwuchs, Maserknollen, Astwinkel, Phototropismus, Kopfbaum, Mehrstämmigkeit) |
| `build.py` | Generator: Stamm mit Wurzelanläufen, Gerüstäste, Zweige 2. und 3. Ordnung entlang der Kronenhülle, Blattkarten an den Endtrieben; LOD0–LOD3; Impostor-Bake (8 Ansichten, Albedo + Kamera-Normalen, Cycles); Kraut-/Feldkarten-Meshes; Export als GLB ohne eingebettete Bilder |
| `render_review.py` | Cycles-Prüfplatten der exportierten GLBs |
| `evidence.py` | D-038-Nachweis aus zwei `tests/vegetation_review.gd`-Läufen |
| `import_settings.py` | Importparameter für Godot |

Vertexfarben steuern den Wind im Godot-Shader: R Biegegewicht des Astes (0 am Stamm), G Astphase, B Blattflattern (0 am Ansatz, 1 an der Spitze), A Kronen-Verschattung. Blattkarten-Normalen sind zur Kronenoberfläche gebogen; Rückseiten behalten sie, damit die Krone als Volumen beleuchtet wird.

LOD-Schema: LOD0 alle Astordnungen, gewölbte Blattkarten; LOD1 ohne Zweige 3. Ordnung, 45 % der Karten 1,42-fach größer; LOD2 Gerüst + starke Äste, Blattkarten zu Kronenballen (1,5 m Raster) zusammengefasst; LOD3 Stamm + Hauptäste, Ballen 3 m; danach ein kamerazugewandtes Impostor-Quad, das die nächstgelegene der 8 gebackenen Ansichten im Eigenkoordinatensystem des Baums zeigt und mit deren Normalen beleuchtet wird.

## Laufzeit (prototype/scripts/vegetation)

| Datei | Aufgabe |
|---|---|
| `vegetation_wind.gdshaderinc` | Wind nach dem Crysis-Modell: Stammschwingen (Höhe², längenerhaltend), Ast-Wippen und -Neigen (R/G), Blattflattern (B), Böenfronten über die Landschaft; Pro-Instanz-Phase und -Steifigkeit aus `INSTANCE_CUSTOM`; `wind_detail` 0/1/2 |
| `vegetation_bark.gdshader`, `vegetation_leaf.gdshader`, `vegetation_impostor.gdshader`, `vegetation_card.gdshader` | Rinde (Normalmap, Moos an der Wetterseite, Nässe), Blätter (Alpha-Test mit mip-abhängiger Deckung, Durchscheinen, Jahreszeit, Winterausdünnung), Impostoren, Kraut-/Feldkarten (Jahreszeit-Kacheln, Ausblenden ohne Kante) |
| `vegetation_library.gd` | lädt GLBs, Materialien je Textur, Impostor-Quad |
| `vegetation_ecology.gd` | ökologische Platzierung (deterministisch) |
| `vegetation_ground.gd` | Höhe der sichtbaren Oberfläche (Dorfebene, Regionalgelände, Hügelmesh) |
| `vegetation_field.gd` | MultiMesh-Instanzierung: Bäume in 32-m-Zellen, je Art und Detailstufe ein MultiMesh; Kraut-/Feldchunks 16 m; Profile, Jahreszeit, Windzeit, Stammkollision serverseitig |
| `assets/vegetation/vegetation_profiles.json` | Distanzen, Dichten, Schatten und Windstufen je Grafikprofil |
