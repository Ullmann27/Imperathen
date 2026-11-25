# Figuren: Materialdetails für die Stadt-Prüfszene

## Umgesetzt und überprüft

Der vorhandene anatomische Hero und die benannten Haut-, Leinen- und Lederflächen der Frontier-Familie erhalten einen optionalen Materialpass für die Nähe. Er ergänzt feinere Webung, zurückhaltendes Hautrelief, geringe Rauheitsunterschiede und Lederkörnung. Die vorhandenen Farbtexturen bestimmen weiterhin Gesicht, Hautfarbe und Kleidung.

Die Original-Normalmaps werden aus dem tatsächlichen `hero_quality_0.glb` gelesen und per **Reoriented Normal Mapping** mit dem neuen Relief kombiniert. Die ursprüngliche Hautrauheit bleibt ebenfalls Bestandteil der neuen Karte. Der Generator verifiziert bei den 16 lokal vorhandenen Hero-/Frontier-Modellen der Detailstufen 0 und 1 identische ursprüngliche Haut-/Leinen-Normaldaten, bevor er den gemeinsamen Satz erzeugt. Die genauen Quellen- und Ausgabehashes stehen in `prototype/assets/city_detail/characters/provenance.json`.

Der Godot-Helfer arbeitet ausschließlich mit Instanzmaterialen und einem schwachen Cache. **Hoch/Sehr hoch und Modell-LOD 0/1** verwenden die Zusatzkarten und anisotrope Mipmapfilter. Andere Profile und Fernstufen stellen das ursprüngliche Material wieder her. Fehlende oder unvollständige UV-/Normal-/Tangentendaten verhindern die Anwendung. Augen, Haare, unbekannte Materiale und zusammengefasste Meshy-Atlanten erhalten keine pauschale Hautbehandlung.

Die Integration erfolgt über:

```gdscript
CityCharacterDetail.apply_to(actor.body, actor.profile, actor.detail)
```

Der Aufruf gehört hinter die vorhandene Figuren-Stilisierung und wird nach Modell-, LOD- oder Profilwechsel wiederholt.

## Tatsächliche Nachweise

- `godot_material_test.log`: **Godot 4.7.2, 79 Prüfungen, 0 Fehler**. Geprüft werden Materialisolierung, identische Farbtexturen, Cacheteilung, Profilwechsel, Wiederherstellung, fehlende Basisdaten, unbekannte Atlanten sowie die echten importierten Hero-Meshes, Skins und Knochen.
- `runtime_texture_validation.json`: Die vier echten `CompressedTexture2D`-Ressourcen enthalten vollständige Mipketten: jeweils 10 zusätzliche Ebenen bei den drei 1024er Karten und 8 beim 256er Leder. Quell-, Import-, Helfer- und Testhashes sind protokolliert. Der Import wurde erfolgreich beendet; Kompressionsmodus und Kartenbytes blieben unverändert.
- `character_detail_review.json`: **Blender 4.3.2**, vier ausgeführte Cycles-Aufnahmen mit identischem Modell, Licht, Kamera und Belichtung. GLB-Bytes, Geometrie, Gewichte, UVs, Morphdaten, Rig und erfasste Animationskurven blieben im Vergleich unverändert.
- `data_map_validation.json`: Alle ausgegebenen Kartenhashes stimmen; Normalvektoren sind endlich und innerhalb der dokumentierten 8-Bit-Quantisierung normalisiert. Die finale Hautrauheit liegt bei rund 0,557–0,714.
- `hero_city_detail.blend`: bearbeitbare Review-Datei mit Originalgeometrie und den neuen Materialen. Der vollständige Ordner `textures/` mit 13 unveränderten PNG-Ressourcen gehört dazu; die Datei verwendet ausschließlich relative `//textures/...`-Verweise. Die Szene zeigt ausdrücklich die Ruhepose.
- `face_before.png` / `face_after.png` und `cloth_before.png` / `cloth_after.png`: alle vier finalen Bilder wurden geöffnet und visuell verglichen. Zu kräftiges Hautrelief und zu grobe Webung aus einem ersten Durchlauf wurden vor dieser finalen Fassung zurückgenommen.

Beim ersten Godot-Test erzeugte `ArrayMesh.add_surface_from_arrays()` automatisch neue Tangenten für die vermeintlich tangentenlose Testfläche. Das Fixture war deshalb nicht tatsächlich ohne Basis. Der endgültige Test prüft die fehlenden Eingangsdaten unmittelbar am produktiven Guard und zusätzlich eine wirkliche Meshfläche ohne UVs; die Anforderung wurde beibehalten.

## Reichweite

Dies ist ein rigschonender **Material- und Texturdetailpass**. Die Kopfgeometrie, Haarform, Gesichtsmorphs und Körperanimationen stammen weiterhin aus dem vorhandenen Modell. Die Bilder belegen diesen Materialschritt, keine abgeschlossene AAA-Figur, keine neue Meshy-Gesichtsrekonstruktion und keine Android-Leistungsabnahme. Für gemischte Meshy-Atlanten bleibt eine gesonderte Material-/Zonenbearbeitung nötig.

## Wiederholen

```sh
python tools/city_detail/characters_maps.py
godot --headless --path prototype --import
godot --headless --path prototype --script res://tests/city_character_detail_test.gd
blender -b -t 4 -P tools/city_detail/characters_blender.py -- --render
blender -b -t 2 -P tools/city_detail/characters_package.py
```

Die vier `.png.import`-Dateien im Kartenordner gehören zum Lieferumfang: `mipmaps/generate=true` ist erforderlich. Eine anisotrope Materialeinstellung allein erzeugt keine fehlende Mipkette. Der Test liest dafür die tatsächlichen importierten Texturressourcen, nicht nur die Einstellungsdateien.

Die technische Bedeutung von Normalmaps und anisotroper Filterung folgt der [Godot-Dokumentation zu BaseMaterial3D](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html). Herkunft und Lizenz der unveränderten MakeHuman-Farb- und Anatomiedaten bleiben in `art/hero_quality/source/provenance.json` dokumentiert.

## Bearbeitbares Blender-Paket

`hero_city_detail.blend` und der direkt danebenliegende Ordner `textures/` bilden ein zusammengehöriges Projekt. Beim Kopieren oder Herunterladen beide erhalten. Die PNG-Dateien wurden mit ihren ursprünglichen kodierten Bytes ausgelagert: keine Größenreduktion, keine erneute Texturkompression und keine Änderung der Farbräume. Die finale Blender-Datei wurde in Blender 4.3.2 wieder geöffnet; Geometrie, Rig, Gewichte, UVs, Morphs, Animationskurven sowie Materialgraphen und Materialzuweisungen blieben identisch. `packaging_validation` im Reviewbericht protokolliert diesen Abgleich und die neue Dateiprüfsumme.
