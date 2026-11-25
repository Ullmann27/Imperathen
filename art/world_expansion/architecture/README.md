# Römische Architektur – ergänzender Blender-Baukasten

Stand: 25. November 2026. Eigener Ergänzungsbereich des Weltteams auf Basis von
Team B / `7af39f35b1947595f95e365eb7762592feabf234`. Vorhandene Dorfmodelle und die
parallel entwickelte Stadt werden durch diese Dateien nicht überschrieben.

## Tatsächlich erzeugte Lieferung

Vier eigenständig bearbeitbare `.blend`-Quellen und zwölf eingebettete, texturierte
GLB-Dateien in `prototype/assets/world_expansion/architecture/`. Jede Variante
enthält genau ein Mesh mit mehreren Materialoberflächen und ist für gruppierte
Instanzierung vorgesehen. Die vier Typen sind künstlerische römisch inspirierte
Module, keine vermessene archäologische Rekonstruktion.

- **Taberna:** offene Ladenfront, Holzläden, Seiten- und Rückfenster, Verkaufsbank,
  Regale, Amphoren und abgesenkte Leinenmarkise. Der Durchgang liegt links neben
  der Verkaufsbank; es gibt keine schwarze Fläche als Ersatz für die Ladenöffnung.
- **Insula:** drei Geschosse, tatsächliche Fensteröffnungen, drei Ladenöffnungen
  im Erdgeschoss, Geschossbänder, Holzläden, Balkon und Ziegeldach. Obere Ebenen
  besitzen Böden. Eine 1,35 m breite und 2,115 m hohe Tür verbindet das oberste
  Geschoss mit dem Balkon; ihre Schwelle liegt auf Höhe des Balkonbodens bei
  5,875 m, 35 mm über dem inneren Geschossboden. Ein Treppen- und
  Navigationssystem ist nicht Teil dieses Moduls.
- **Basilika/Verwaltung:** hoher Saal mit Fenstern, offener Tür, Säulenportikus,
  profilierten Basen/Kapitellen, Giebelfront, vollständig gedecktem Vorhallendach,
  Bänken und kleiner hinterer Estrade. Die Vorhalle besitzt in allen drei LODs
  durchgehende Dachflächen; LOD0 ergänzt einzeln modellierte Ziegel.
  Es werden weder ein neuer Kaiser noch eine Storymission eingeführt.
- **Basaltstraße:** 8 × 8 m Modul mit sichtbar getrennten unregelmäßigen Steinplatten,
  leichter Krone, offenen Rinnen und seitlichen Steinwegen. Keine Asphalttextur.

## Reale Geometriegrößen

| Asset | Dreiecke LOD0 / LOD1 / LOD2 | Umriss LOD0 X/Z (m) | Höhe (m) |
| --- | --- | --- | --- |
| taberna | 35384 / 1968 / 652 | [7.7835, 9.888] | 5.045 |
| insula | 56664 / 5284 / 4588 | [10.8686, 10.713] | 10.625 |
| basilica | 115644 / 3308 / 2252 | [13.0839, 19.798] | 10.325 |
| basalt_road | 9856 / 852 / 276 | [8.0, 8.0] | 0.16 |

LOD0 erhält einzelne Tegula-/Deckziegel und feinere Steinkanten. LOD1 verwendet
vereinfachte Dachflächen mit realen Nähten; LOD2 erhält die Öffnungen und
wesentlichen Silhouetten mit reduzierter Materialzahl. Die hohen LOD0-Zahlen sind
für nahe Einzelgebäude bestimmt. 3.000–4.000 gleichzeitige LOD0-Instanzen sind weder
ein sinnvoller Laufzeitvertrag noch als lauffähig gemessen. Streaming, Entfernung,
Sichtbarkeit, Materialbündelung und echte Fold7-Messungen gehören in die Integration.

Blender verwendet Meter, Z nach oben und die Vorderseite bei −Y. Der GLB-Export
wandelt nach Y oben und Vorderseite +Z. Der Ursprung liegt am Boden; der innere
Gebäudeboden liegt auf 0,12 m. Das Manifest enthält exakte AABBs und Abmessungen
jeder Detailstufe. Die Umrisse enthalten Dachüberstände, Vordächer und Balkon und
sind teilweise asymmetrisch. Strukturboxen sind Daten zur Weiterbearbeitung, keine
bereits geprüften Engine-Kollisionen. Die Straßenbox ist absichtlich vereinfacht.

## Nachweise und Grenzen

`architecture_manifest.json` enthält tatsächliche Dateigrößen, SHA-256-Hashes,
Dreieckszahlen und Materialoberflächen. `glb_validation.json` dokumentiert die
Prüfung der zwölf realen Binärdateien: GLB2-Header/Länge, ein Mesh, Dreiecksindizes,
UVs und Normalen, endliche Positionsgrenzen, eingebettete Bilddateien sowie
Übereinstimmung von Hash und Dreieckszahl mit dem Exportmanifest. Alle zwölf
Dateien bestanden diese Strukturprüfung nach den beiden Modellkorrekturen.
`strict_validation.json` enthält zusätzlich den tatsächlichen Prüflauf von
`tools/world_art/validate.py --category architecture`: zwölf geprüfte GLBs,
keine Fehler, inklusive dekodierter Geometrie, Texturen und Manifestabgleich.
Diese Dateiprüfungen messen keine Android-Leistung.

### Tangentenspeicherung der Basilika

Die numerische Importkontrolle fand zusätzlich einen Fehler an den 48 feinen
Säulenrippen: Der gemeinsame Stein-Bevel von 12 mm überstieg die halbe Breite
dieser 18 mm breiten Details. Im ursprünglichen Export lagen sämtliche 550
geometrischen Nullflächen und 453 UV-Nullflächen innerhalb dieser Rippenregion;
573 ursprüngliche Limestone-Tangentenframes waren ungültig. Die Rippen liegen
jetzt in einer eigenen unbevelten Detailgruppe mit demselben Limestone-Material.
Alle 48 Rippen und die profilierten Säulen bleiben erhalten; die übrigen
Steinkomponenten behalten ihren bisherigen Bevel. Die korrigierte Oberfläche
enthält **keine geometrischen oder UV-Nullflächen und keine ungültigen ursprünglichen
Tangentenframes**. `basilica_original_tangent_check.json` dokumentiert den alten
Fehler, `basilica_fluting_repair.json` den gezielten Vorher-/Nachher-Vergleich.
LOD1 und LOD2 sind nach dem erneuten Export bytegleich geblieben.

Nur `basilica_lod0.glb` wird nach dem regulären Blender-Export durch
`compact_tangent_storage()` im Generator kompakt gepackt. Der Schritt entfernt
die sieben expliziten `TANGENT`-Attribute und ihre ausschließlich dafür verwendeten
Accessor-/BufferView-Daten. Er verkleinert die korrigierte Datei von 14.135.720 auf
10.565.572 Bytes, damit sie unverändert in ihrer Modellgeometrie über den
verfügbaren GitHub-Transport gespeichert werden kann. Der Packschritt verändert keine Geometrie
und benötigt weder Draco noch Meshopt.

`basilica_tangent_pack.json` enthält die Vorher-/Nachher-SHA-256-Werte sämtlicher
28 verbleibender Accessor-Payloads und aller zwölf eingebetteten Bilder. Die Werte
sind jeweils innerhalb dieses Packschritts identisch. Positionen, Normalen, UVs, Indizes, Materialdeklarationen
und Texturbytes bleiben dadurch erhalten. Der Packer bricht vor dem Schreiben bei
einer Abweichung ab. Er prüft außerdem vor dem Packen sämtliche ursprünglichen
Tangentenframes und bricht bei ungültiger Länge, Normalenbasis oder Händigkeit ab.
Blenderquelle und Reviewbild wurden nach der Rippenkorrektur neu erzeugt und
gehören zu genau dieser Geometrie und diesen Materialpixeln.

**Tangenten werden beim Godot-Import neu erzeugt.** Dafür muss die standardmäßig
aktive Importoption `meshes/ensure_tangents` eingeschaltet bleiben. Godot erzeugt
fehlende Tangenten mit MikkTSpace; eine Bitgleichheit der neu berechneten Tangenten
mit den Blender-Tangenten wird nicht behauptet. Der tatsächliche Engine-Import
und die Normalmapdarstellung sind Gegenstand der gesonderten Integrationsprüfung.
Der normale Laufzeitpfad enthält eine vollständige GLB-Datei; er benötigt keine
Teilarchive oder Dekompression.

Quellen für das Importverhalten:
[offizielle Importoption](https://docs.godotengine.org/en/stable/classes/class_resourceimporterscene.html#class-resourceimporterscene-property-meshes-ensure-tangents),
[Godot 4.7.2: Standardwert](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/import/3d/resource_importer_scene.cpp#L2646),
[Godot 4.7.2: glTF-Tangentenerzeugung](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/gltf/gltf_document.cpp#L1757).

### Sichtkontrolle der vier Modelle

Alle vier folgenden Blender-Bilder wurden tatsächlich erzeugt und geöffnet.
Die Insula und die Basilika wurden nach den gefundenen Baufehlern korrigiert,
einschließlich Blenderquelle und aller drei GLBs, und erneut gerendert. Die
Taberna und die Straße blieben bei dieser Korrektur in Quelle, GLBs und Bild
bytegleich. `render_source_snapshot.json` ordnet die endgültigen Quell- und
Bilddateien über SHA-256 zu.

| Bild | Auflösung / Cycles-Samples | Geprüfte sichtbare Merkmale und Grenzen |
| --- | --- | --- |
| `taberna_review.png` | 1280 × 960 / 24 | Ziegel, Markise, Fenster und offene Ladenfront sind sichtbar. Tiefe Innenregale bleiben stark verschattet. |
| `insula_review.png` | 1280 × 960 / 24 | Drei Geschosse, Öffnungen, Balkon und der korrigierte bodentiefe Zugang sind sichtbar; das Fassadenband versperrt die Tür nicht. |
| `basilica_review.png` | 1280 × 960 / 24 | Säulen, offener Zugang, Seitenfenster sowie die korrigierte vollständige Vorhallendachfläche sind sichtbar. |
| `basalt_road_review.png` | 1024 × 768 / 20 | Unregelmäßige Pflasterplatten, Rinnen und seitliche Gehwege sind sichtbar. |

Die vier Außenansichten liefen auf der CPU mit jeweils zwei Threads. Bei Insula,
Basilika und Straße wurde die Umgebungsbeleuchtung gegenüber dem ersten
Taberna-Bild aufgehellt. Die Ansichten erlauben eine Kontrolle grober Modellfehler
aus der gezeigten Perspektive. Sie sind keine Spielaufnahmen und bestätigen keine
Innenraumnavigation, Treppen, vollständige Rundumkontrolle oder spielbare Kollision.
LOD1 und LOD2 wurden als Binärgeometrie geprüft, aber nicht gesondert abgebildet.
Die umfassenden Abnahmestatus im Exportmanifest bleiben deshalb konservativ offen;
die hier dokumentierte Sichtkontrolle gilt für die vier LOD0-Außenansichten.

Quellen: eigener deterministischer Geometriecode in
`tools/world_art/architecture.py`; vorhandene originale Materialkarten aus
`tools/art/generate_materials.py` unter `art/visual_benchmark/materials`. Keine
neuen Fremdmodelle oder kostenpflichtigen Dienste. Sämtliche benötigten Texturen
sind in den GLBs und Blenderquellen eingebettet. Die GLBs enthalten jeweils eigene
Texturbytes; ein Engine-seitiger gemeinsamer Materialcache bleibt Integrationsarbeit.

## Wiederholung

```sh
blender -b -t 2 --python tools/world_art/architecture.py
blender -b -t 2 --python tools/world_art/architecture.py -- --asset taberna --render
python3 tools/world_art/validate.py --category architecture --output art/world_expansion/architecture/strict_validation.json
```

Der zweite Befehl baut die Taberna erneut und rendert die LOD0-Szene. Der
Dateiprüferstatus im Manifest bleibt für noch nicht durchgeführte Runtime-,
Kollisions-, Leistungs- und Gesamtbildabnahmen ausdrücklich offen. Render-Denoising
ist ausgeschaltet, weil der vorhandene Blender-Build kein OpenImageDenoise enthält.
