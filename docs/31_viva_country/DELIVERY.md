# VIVA ROMA III – Feldweg und Wiesenqualität
Basis: Stand-0-Commit 31b4cf88789b690e582dc472b9b21d1940cacf9b. Eigenständige Referenzstrecke, nicht Kampagnenintegration. Keine Veränderung der bestehenden Streaming-, Welt-, Save- oder Handelslogik. Neu: zwei projektspezifische Codex-Agentenprofile (nicht gestartete Sessions), Original-GLB-Modelle und eine eigenständige First-Person-3D-Szene mit WASD / vorhandenem Touchstick und Touchblick.

## Generierter, hochgeladener Stand
36 m Länge, 20 m Querschnitt, drei zusammenhängende 12-m-Sektoren. 115.200 Terrain-Dreiecke; tatsächlich triangulierte Höhen, nahtgleiche Randpositionen und Normalen, variierende Querneigung und ca. 2,47–4,17 m Nennbreite. 40 modellierte Hufabdrücke mit errechneten Mesh-Tiefen ca. 21,9–35,5 mm. 7.276 Grassbüschel in vier Varianten, einzelne gebogene Halme mit dreieckigem Querschnitt; 2.852 Kiesel in vier Formen mit unterschiedlichen Radien. Nominale Büschelskalen 3,88–55,97 cm; die einzelnen modellierten Halme variieren innerhalb des Büschels zusätzlich. 361 Büschel in stärker ausgeprägter Wegfläche, 933 in gemischter Randzone. Verbindlicher Zahlenstand in manifest.json.

## Runtime
Terrain und CollisionShape3D stammen aus denselben importierten Meshes. Acht reale Scatter-Prototypen, 24 räumlich begrenzte MultiMesh-Gruppen, nach Entfernung und vier Grafikprofilen reduzierte sichtbare Instanzen. Die Manifestzahlen sind Gesamtbestand, nicht gleichzeitig sichtbar. Keine zusätzliche Kies-/Grasphysik. Bodenshader mit metrischer Körnung und ableitungsbasierter Normalenvariation; keine Displacement-Abweichung zwischen Render und Physik. Wind bewegt Halme lokal bei festem Fußpunkt, Sonnenrichtung konsistent mit drei bewusst gesetzten Tageslichtstimmungen (keine astronomische Simulation). Schatten nur nahe in höheren Stufen; tatsächliche Fold7-Leistung offen.

## Reproduktion
- `node tools/viva_country/generate.mjs /tmp/country-generated`
- `python tools/viva_country/prepare_fixture.py /tmp/country-fixture`
- `godot --headless --path /tmp/country-fixture --import --quit`
- `godot --headless --path /tmp/country-fixture --script res://tests/viva_country_test.gd`
- `godot --path /tmp/country-fixture` zum Begehen.
- Grafischer Prüfaufruf: `godot --path /tmp/country-fixture --resolution 1280x720 --script res://tests/viva_country_test.gd -- --capture=/tmp/country-evidence`.

Numerische Generatorprüfungen auf dem exakten Generator tatsächlich ausgeführt: endliche Geometrie, normierte Normalen, nichtdegenerierte Dreiecke, Randkontinuität, Mindest-Hufrelief, nichtleere Grasflächen im Weg und Größenstreuung. Vier GLB- und drei Scatter-JSON-Dateien im Git-Baum bestätigt. Godot-Import, Raycasts, Touch-/Lichtdarstellung und fünf echte Aufnahmen (drei Sonnenstände, Rand, Hufdetail) sind als CI-Prüfung hinterlegt; bis zum Ergebnis keine Engine-, Bildqualitäts- oder Androidfreigabe. Kein Blender-Render behauptet. Keine APK, keine neue Figur, kein Main-Merge. Der kleine Prüfabschnitt ist bewusst keine vollständig ausgearbeitete Landschaft mit Fernhorizont.
