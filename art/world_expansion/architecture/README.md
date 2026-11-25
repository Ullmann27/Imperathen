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
  besitzen Böden; ein Treppen- und Navigationssystem ist nicht Teil dieses Moduls.
- **Basilika/Verwaltung:** hoher Saal mit Fenstern, offener Tür, Säulenportikus,
  profilierten Basen/Kapitellen, Giebelfront, Bänken und kleiner hinterer Estrade.
  Es werden weder ein neuer Kaiser noch eine Storymission eingeführt.
- **Basaltstraße:** 8 × 8 m Modul mit sichtbar getrennten unregelmäßigen Steinplatten,
  leichter Krone, offenen Rinnen und seitlichen Steinwegen. Keine Asphalttextur.

## Reale Geometriegrößen

| Asset | Dreiecke LOD0 / LOD1 / LOD2 | Umriss LOD0 X/Z (m) | Höhe (m) |
| --- | --- | --- | --- |
| taberna | 35384 / 1968 / 652 | [7.7835, 9.888] | 5.045 |
| insula | 56460 / 5080 / 4384 | [10.8686, 10.713] | 10.625 |
| basilica | 97024 / 3104 / 2216 | [13.0839, 19.798] | 10.325 |
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
Dateien bestanden diese Strukturprüfung. Das ist noch keine Godot-Import- oder
Android-Leistungsprüfung.

`taberna_review.png` ist ein tatsächlich erzeugtes und geöffnetes Blender-Bild
(1280 × 960, Cycles CPU, zwei Threads, 24 Samples). Dachziegel, Vordach,
Fensteröffnung und Ladenfront sind sichtbar; die tiefen Innenregale bleiben in
dieser Außenansicht stark verschattet. Das Bild ist eine Assetkontrolle und keine
Spielaufnahme oder vollständige Innenraumabnahme. Die anderen drei Blenderquellen
wurden exportiert; eine gesonderte visuelle Bildabnahme ist hier noch nicht behauptet.

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
```

Der zweite Befehl baut die Taberna erneut und rendert die LOD0-Szene. Der
Dateiprüferstatus im Manifest bleibt für noch nicht durchgeführte Runtime-,
Kollisions-, Leistungs- und Gesamtbildabnahmen ausdrücklich offen. Render-Denoising
ist ausgeschaltet, weil der vorhandene Blender-Build kein OpenImageDenoise enthält.
