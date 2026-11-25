# Römische Stadt: Detailpaket für Blender und Godot

Stand: 25. November 2026. Unterstützungsbranch für den parallel aufgebauten
Stadtversuch. Das Paket ergänzt die Stadt modular; es verändert keine bestehende
Kampagne, Aufgabe oder Freigabe des Bewegungssystems.

## Tatsächlich erzeugte Bestandteile

Die Blender-Datei `tools/city_detail/architecture_source.blend` enthält die
editierbare Geometrie, drei Detailstufen sowie eine beleuchtete Prüfanordnung.
`tools/city_detail/architecture_generate.py` erzeugt sie wiederholbar aus eigener
Geometrie und den bereits vorhandenen eigenen Projektmaterialien. Die
selbstständige GLB-Bibliothek liegt in
`prototype/assets/city_detail/architecture/city_architecture_library.glb`.

| Modul | Geometrie und Nutzung | Dreiecke LOD0 / LOD1 / LOD2 |
|---|---|---:|
| `basoli_4m` | 4 × 4 m Straßenstück; 36 große unregelmäßige Steinplatten mit abgerundeten Kanten und schmalen Fugen | 5.268 / 2.738 / 1.158 |
| `curb_4m` | 4 m Bordstein, Gehwegplatten und vertiefte offene Rinne | 1.836 / 954 / 402 |
| `taberna_4m` | 4 m breite offene Ladenhülle, Seiten-/Rückwände, niedrige Schwelle, Steingewände, zurückgelegte Holzläden, Regale, Dachbalken sowie einzelne Tegula-/Imbrexelemente | 25.856 / 13.444 / 5.688 |
| `dolia_counter` | 2,60 m breite Theke; drei modellierte Gefäße mit tatsächlich offenen Mündungen, Steinplatte, Sockel und Einlagen | 4.968 / 2.582 / 1.092 |
| `market_canopy` | 3 m breites Stoffdach, gebogene Stofffläche, Randbesatz und vier Holzpfosten | 1.627 / 845 / 357 |
| `amphora_pair` | Zwei unterschiedlich große Gefäße mit hohlen Hälsen und eigenen Griffen | 2.600 / 1.352 / 572 |
| `bread_display` | Holzbrett mit zwei geometrisch eingekerbten Brotlaiben | 2.980 / 1.548 / 654 |

Die Dateigröße der GLB beträgt **12.561.824 Bytes**. Die gemessenen Werte und der
SHA-256 stehen im maschinenlesbaren `architecture_manifest.json`; die unabhängige
GLB-Prüfung steht in `evidence/architecture/glb_validation.json`.

## Schärfe, Export und Android-Budget

Die Flächen verwenden die vorhandenen nahtlos wiederholbaren 512-Pixel-Karten des
Projekts mit einem nominellen Wiederholungsmaß von einem Meter. Farb-,
Rauheits-/Metall- und Tangentennormalkarten werden tatsächlich eingebettet: der
GLB-Parser bestätigt **21 Bilder**, UVs, Normalen und Tangenten. Sichtbare Kanten,
Dachziegel, Ladenschwellen, Gefäßöffnungen und Holzprofile sind echte Geometrie.
Es werden keine nur in Blender sichtbaren Materialnodes als Runtime-Detail
ausgegeben.

Der Godot-Helfer verwendet mipmapbasiertes anisotropes Filtern. Das erhält
schräg betrachtete Pflasterdetails besser, ohne den Mipmap-Schutz gegen Flimmern
abzuschalten. Die Texturfilterung ist von Materialanisotropie zu unterscheiden;
siehe [Godot BaseMaterial3D](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html).
Die Anbindung der Normalkarten folgt dem
[Blender-glTF-Exportvertrag](https://docs.blender.org/manual/en/4.2/addons/import_export/scene_gltf2.html).

Jedes Modul besitzt drei tatsächlich reduzierte Meshes. Wiederholte Module
teilen sich Mesh und Materialressourcen; `create_multimesh` bündelt gleiche
Varianten. Der empfohlene Abstandswähler verwendet beim hohen Profil LOD0 bis
20 m, LOD1 bis 55 m, danach LOD2. Diese Entfernungen sind **vorläufige
Spielgestaltung**, keine auf dem Fold7 gemessene Leistungsfreigabe. Auch die
höchste Stufe ist kein Nachweis fertiger PC-/Konsolengrafik.

## Integration

```gdscript
const Detail = preload("res://scripts/rendering/city_architecture_detail.gd")
var shop = Detail.create_module("taberna_4m", 0, true)
add_child(shop)
var paving = Detail.create_multimesh("basoli_4m", [
    Transform3D.IDENTITY,
    Transform3D(Basis.IDENTITY, Vector3(4, 0, 0)),
], 1)
add_child(paving)
```

Godot-Koordinaten: Meter, **+Y oben, +Z Vorderseite**, lokaler Boden y=0.
Die Rasteranordnung innerhalb der Bibliothek dient der Assetprüfung; der
Helfer entfernt deren Translation beim Erzeugen eines einzelnen Moduls.
`module_info(id)` liefert Maße, Detailstufen und einfache Kollisionsquader.
Collider sind nur bei ausdrücklichem `with_collision=true` aktiv. Die
Ladenöffnung bleibt frei; jede einzelne Pflasterplatte erzeugt keine eigene
Physikform. Sichtbare Fugen und Kanten bleiben trotz eines glatten gemeinsamen
Gehbodens erhalten. Ein Feld voller Modelle wird nicht automatisch als fertige
Navigation oder vollständige Stadtökonomie bezeichnet.

## Historische Grundlage und Grenze

Für die Straße sind große polygonale Lavasteinplatten das Vorbild. Der
[Archäologische Park der Via Appia](https://www.parcoarcheologicoappiaantica.it/luoghi/via-appia-antica/via-latina-parco-degli-acquedotti/)
beschreibt entsprechende Platten aus Leucitit sowie erhaltene Fahrspuren an der
Via Latina. Dieses konkrete Vorbild begründet die Formwahl; es bedeutet nicht,
dass sämtliche römischen Straßen gleich gepflastert waren. Die Spielmodule
verwenden eine gestalterische dunkle Steinoberfläche, keine petrographisch
vermessene Materialrekonstruktion.

Die Speise-/Getränketheke ist durch archäologisch belegte Theken mit
eingelassenen Vorratsgefäßen angeregt. Der
[Archäologische Park Pompeji](https://pompeiisites.org/en/press-releases/from-the-12th-august-the-thermopolium-of-regio-v-is-opening-to-the-public/)
beschreibt solche Speise- und Getränkeverkaufsstellen. Die konkrete erhaltene
Gestaltung gehört zur späteren Überlieferung Pompejis. **Unsere eigene
Ladenhülle und Dekoration sind eine historisch inspirierte Testgestaltung,
keine vermessene Rekonstruktion Aquileias im Jahr 58 v. Chr.** An den Quellen
wurde nur die sachliche Forminformation verwendet; keine fremden Fotos,
Texturen, Meshes oder Fresken wurden übernommen.

## Prüfung und Wiederholung

```sh
blender --background --threads 4 --python tools/city_detail/architecture_generate.py
python tools/city_detail/architecture_verify.py
python tools/city_detail/architecture_check.py
```

Der Python-Lauf prüft die tatsächlich exportierten Dreieckszahlen, streng
abnehmende LOD-Zahlen, eingebettete PBR-Karten, endliche Bounds, den Hash und
den Kollisionsvertrag. Der gesonderte Godot-Test lädt die echten Ressourcen
und prüft Ladeneingang, Wand, Boden sowie die tatsächliche Gefäßöffnung mit
Physikstrahlen. Der Wrapper verwendet den vorhandenen authentifizierten
Xorg-Softwarepfad, damit die Platzierung aus dem echten MultiMesh-Backend
zurückgelesen wird. Godots Headless-Dummy liefert an dieser Stelle nur die
Identität und kann diese Anforderung nicht prüfen. Der unveränderte Test wird
deshalb vollständig grafisch ausgeführt. Der jeweils wirklich ausgeführte Engine-/Bildnachweis wird
im gemeinsamen Lieferbericht geführt; ein vorhandenes Testskript ist allein
kein bestandener Lauf.

**Ausgeführt:** Die unveränderte Godot-Prüfung bestand am 25. November 2026
**94/94 Prüfungen** mit Godot 4.7.2 und dem echten OpenGL-/Mesa-Softwarepfad;
die Quellen blieben während des Laufs unverändert. Der Bericht nennt die vier
geprüften Quell-/Asset-Hashes. Der vorherige reine Headless-Lauf bestand die
93 dort ausführbaren Anforderungen; sein einziger Fehler war das nicht
unterstützte MultiMesh-Rücklesen. Die vollständige grafische Wiederholung
bestätigte anschließend auch diese vier Meter breite Instanzversetzung.
Siehe `evidence/architecture/godot_validation.json` und das vollständige Log.

Die drei Blenderansichten sind echte Renderings der erzeugten Geometrie.
Die Nahansicht und die Aufnahme aus 1,50 m Kamerahöhe dienen dem Form- und
Maßstabsvergleich. Der markierte Holzstab ist nur eine Maßhilfe. Die Renderings
sind keine Android-Screenshots, und aus ihnen folgt keine Bildrate,
Wärmeentwicklung oder Geräteabnahme.
