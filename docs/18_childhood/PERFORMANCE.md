# Dorf, natürliche Bewegung und begrenzte Renderarbeit

Stand: 23.11.2026. Ausgangspunkt der isolierten Messung ist Commit `f2900eb86b90b185627dcd490fef550fd0cbed11`, Godot `4.7.2.stable.official.ed1daf0bf`.

## Umgesetzt und tatsächlich geprüft

Die vorhandenen Dorfrequisiten behalten ihre Geometrie, Materialien und Kollisionen. Gleiche primitive Formen teilen jetzt unveränderliche Mesh-Ressourcen. Statische, gleichartige Einzelteile werden innerhalb kleiner zusammenhängender Objektgruppen als `MultiMesh` zusammengefasst. Dazu zählen beispielsweise die Bretter eines Wagens und die Pflanzen eines einzelnen Gartens. Die reparierbare Wagenachse bleibt ein eigenständiges, umschaltbares Objekt.

Die Animationskorrektur richtet die Arme unbewaffneter Figuren im Stand seitlich am Körper aus. Beim Gehen und Laufen schwingen sie gegenläufig. Vorhandene Bein-, Becken-, Rücken- und Kopfspuren einschließlich ihres Zeitverlaufs bleiben erhalten. Die korrigierten Armspuren entstehen einmal beim Laden eines Rigs und werden zwischen gleichzeitig lebenden Instanzen geteilt. Der Haltungsfix fügt keine frameweise inverse Kinematik hinzu. Bewaffnete Figuren behalten ihre vorhandenen Tragebewegungen für Schild, Bogen oder Speer.

Zehn unbewaffnete Übungstechniken haben eigene gebundene Animationsspuren: linke/rechte Gerade, Haken und Aufwärtshaken sowie Kopfstoß, Front-, Seiten- und hoher Tritt. Die sichtbare Trefferpose liegt jeweils bei 40 Prozent der vereinbarten Aktionsdauer. `VillagePerson.cue_unarmed(id)` startet ausschließlich die Darstellung; Annahme, Reichweite, Treffer, Ausdauer und Erholung gehören weiterhin dem Spielmodell. Die Posen sind ursprüngliche prozedurale Prototypanimationen, keine Motion-Capture-Aufnahmen und keine Behauptung fertiger Kampfchoreografie.

`VillagePerson.set_loaned_gear(bool)` zeigt einen kleinen ursprünglichen Helm und einen hölzernen Übungsschild auf den tatsächlichen Kopf- und Handknochen. Die Formen und Materialien werden geteilt. Ein LOD-Wechsel erhält den Leihstatus; wiederholte Zustandsmeldungen erzeugen keine doppelten Teile. Diese Darstellung erzeugt weder eine Waffe noch zusätzliche Treffer- oder Inventarrechte.

Die Bevölkerungsprojektionen verwenden außerdem `configure_resident(origin, years, appearance, variation, camera)`. Herkunft, Alter und Erscheinung werden vor dem ersten Laden gemeinsam gesetzt. Die erste Detailstufe folgt bereits der tatsächlichen Kameraentfernung und dem Qualitätsprofil. Damit entfallen der vorherige generische Zwischenkörper und das vorherige unbedingte Laden der höchsten Detailstufe. Ohne Kamera beginnt ein Bewohner auf Stufe 2; die normale spätere LOD-Prüfung bleibt aktiv.

## Vergleich derselben vorhandenen Requisiten

Die Messung instanziiert ausschließlich die schon vorhandene `frontier_dressing.gd` mit demselben Qualitätsprofil. Der in diesem Entwicklungsblock separat vergrößerte Ort ist **nicht** Teil dieses Gleichstandsvergleichs.

| Tatsächlich gezählte Eigenschaft | Vorher | Nachher |
|---|---:|---:|
| Einzelne `MeshInstance3D`-Knoten | 214 | 28 |
| Kompakte `MultiMeshInstance3D`-Knoten | 0 | 28 |
| Renderbare Geometrie-Knoten insgesamt | 214 | 56 |
| In Batches enthaltene ursprüngliche Instanzen | 0 | 186 |
| Unterschiedliche Mesh-Ressourcen | 214 | 37 |
| Unterschiedliche Materialien | 19 | 19 |
| Gezeichnete Modellgeometrie vor Sichtbarkeitsprüfung, Dreiecke | 24.064 | 24.064 |
| Kollisionsformen | 8 | 8 |

Das sind **73,8 Prozent weniger Geometrie-Knoten** und **82,7 Prozent weniger unterschiedliche Mesh-Ressourcen** in diesem abgegrenzten Bestand. Die logischen Modellinstanzen und deren Formen bleiben erhalten. Diese strukturellen Zahlen sind getrennt von den folgenden tatsächlichen Renderzählern ausgewiesen.

Der einmalige Aufbau des Fixtures betrug in den protokollierten Einzelaufrufen ungefähr 2,8 ms vorher und 3,5 ms nachher. Das zusätzliche Zusammenfassen kostet beim Aufbau Arbeit. Aus diesen Einzelwerten wird keine Verbesserung der Ladezeit abgeleitet. Die beabsichtigte Einsparung betrifft die anschließende Verwaltung und Übermittlung vieler separater Zeichenobjekte.

## Tatsächlich gerenderter Vergleich

Beide Fassungen wurden anschließend mit demselben Probe, denselben drei Kameras, 960 × 540 Pixeln, dem Profil „balanced“, MSAA 2× und dem Godot-Compatibility-Renderer gerendert. Verwendet wurde **Mesa llvmpipe, LLVM 19.1.7**, also eine Software-GPU auf dem Entwicklungsrechner. Pro Kamera wurden nach zwölf Aufwärmframes 60 Frames erfasst. Die folgenden Draw Calls stammen aus den tatsächlichen Viewport-Zählern; die Zeitspalten sind die Medianwerte dieser einzelnen Stichprobe.

| Kamera | Draw Calls vorher | Draw Calls nachher | Reduktion | Framezeit vorher | Framezeit nachher |
|---|---:|---:|---:|---:|---:|
| Wagen | 130 | 31 | 76,2 % | 43,429 ms | 42,608 ms |
| Garten | 169 | 49 | 71,0 % | 46,608 ms | 42,622 ms |
| Straße | 125 | 36 | 71,2 % | 46,064 ms | 36,557 ms |

Die Renderzähler belegen weniger Zeichenaufrufe für denselben Inhalt. Die Framezeiten sind Beobachtungen auf einem geteilten Entwicklungsrechner und keine stabile Hardware-Benchmarkreihe. Insbesondere werden daraus keine Handy-FPS oder Temperaturwerte abgeleitet. Die Rohberichte enthalten außerdem das 95. Perzentil und die vom Viewport gemeldeten CPU-/GPU-Zeiten.

Der räumliche Batch hat einen messbaren Zielkonflikt: In der Straßenansicht steigt der Primitivenzähler von 9.858 auf 10.542, weil eine sichtbare Gruppe auch einzelne außerhalb des Sichtfelds liegende Teile gemeinsam übermittelt. In der Wagen- und Gartenansicht bleibt dieser Zähler unverändert. Deshalb bleiben die Gruppen örtlich klein. Die aufgenommenen Requisitenbilder zeigen denselben Aufbau und dieselben Materialien; der Pixelvergleich ist sehr ähnlich, jedoch nicht bitidentisch. Für den Wagen sind 99,15 %, den Garten 98,81 % und die Straße 99,71 % der Pixel exakt gleich.

Die acht repräsentativen PNGs in der Evidenz zeigen Wagen und Standhaltung vor/nach der Änderung sowie zwei Gehphasen, den hohen Übungstritt und die Leihgegenstände. Sie wurden aus dem tatsächlichen Godot-Viewport aufgenommen und visuell geprüft. Das größere neue Dorf ist Gegenstand einer separaten Szenenprüfung und wird nicht als Bestandteil dieses Gleichstandsvergleichs ausgegeben.

## Messung der tatsächlich gebundenen Arme

Beim italienischen Jugendmodell lagen die Handgelenke im ursprünglichen Stand etwa 15–16 cm vor den Schultern. Im korrigierten Stand beträgt dieser Versatz etwa 2,6 cm; beide Handgelenke liegen rund 41,7 cm unter der jeweiligen Schulter. Die Werte stammen aus den tatsächlichen `Skeleton3D`-Knochenpositionen im Modellraum.

In der Gehpose liegt jetzt ein Handgelenk vor, das andere hinter der Schulterebene. Eine halbe Gangperiode später sind die Seiten vertauscht. Die Regression prüft diesen Zusammenhang für alle fünf Herkünfte an der nahen und entfernten Detailstufe. Sie prüft außerdem unveränderte Bein-, Rücken- und Kopfspuren, unterschiedliche Technikposen, Erholungsdauer, LOD-Kontinuität sowie die Unverändertheit der ursprünglichen importierten Animationen.

## Grenzen des örtlichen Nachweises

Die erste strukturelle Messung lief mit dem **Headless-/Dummy-Renderer**. Der spätere grafische Lauf nutzte einen tatsächlich erreichbaren privaten Xorg-Server: Displayserver und Godot müssen in dieser Umgebung vom selben Python-Elternprozess gestartet werden. Ein zuvor separat gestarteter Displayserver war nicht erreichbar; dieser Umgebungsfehler ist behoben. Die Dateien `before.json` und `after.json` bleiben als ursprüngliche Headless-Messungen erhalten; `before-graphical.json` und `after-graphical.json` enthalten die tatsächlich gerenderten Läufe.

Ein weiteres Detail ist für Tests wesentlich: Der Dummy-Renderer von Godot 4.7.2 gibt beim Abfragen einer hochgeladenen MultiMesh-Instanztransformation die Identität zurück. Der Headless-Test prüft deshalb die vorbereiteten CPU-Transformationen gegen die echten verschachtelten Node-Transformationen. Bei einem grafischen Renderer prüft derselbe Test zusätzlich die tatsächlich hochgeladenen Instanztransformationen. Das Verhalten ist im [Quelltext der genutzten Godot-Version](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/dummy/storage/mesh_storage.h) nachvollziehbar.

Es wurde keine Temperatur, Akkulaufzeit oder anhaltende Bildrate auf einem physischen Android-Handy gemessen. Weniger Ressourcen und Zeichenobjekte sind konkrete Einsparungen; ihre Wirkung auf Wärme und Laufzeit muss auf dem betreffenden Gerät geprüft werden. Eine bloße Verlagerung von CPU-Arbeit auf die GPU beweist keine geringere Erwärmung.

## Technischer Vertrag

- `Art.box`, `Art.cylinder` und `Art.sphere` behalten ihre bisherigen Rückgabetypen. Gleiche Dimensionen verwenden dieselbe Geometrie. Größenänderungen erfolgen am Node-Transform; vor direkter Änderung eines Meshes ist eine Kopie erforderlich. Jeder der drei Caches ist auf 128 Einträge begrenzt.
- `Art.material` liefert weiterhin ein eigenes veränderbares Material. Individuelle Farben können dadurch keine benachbarten Figuren oder Gegenstände unbeabsichtigt verändern.
- `Art.batch_static(group, exclusions)` wird einmal nach dem Aufbau einer ausdrücklich statischen, örtlich kleinen Gruppe aufgerufen. Kinder mit Kollisionen, Skripten, Skinning, individuellen Oberflächenüberschreibungen oder Ausschlüssen bleiben eigenständig. Verschachtelte Transformationen und Schatten-/Sichtbarkeitseinstellungen werden übernommen.
- Qualitätsumschaltungen müssen `GeometryInstance3D` erfassen, damit sowohl Einzelmeshes als auch MultiMeshes dieselben Distanzgrenzen erhalten. Die vorhandenen Detailgrenzen 24/42/65/90 m bleiben erhalten.
- Die Szene hat keinen zusätzlichen Prozess, der statische Requisiten pro Frame neu aufbaut oder ihre Transformationen neu hochlädt.
- Beim atomaren Bewohneraufbau müssen die endgültige Position und das Grafikprofil vor `configure_resident` gesetzt sein. Ein Kameraparameter ermöglicht bereits für das erste Modell die richtige Entfernungsklasse. Die bestehenden Einzelmethoden bleiben für bisherige Aufrufer verfügbar.

Ein MultiMesh wird als gemeinsame räumliche Einheit sichtbar oder unsichtbar. Deshalb wird nicht ein einziger Batch über das ganze Dorf gelegt. Die örtliche Gruppierung folgt der [offiziellen Godot-Empfehlung für getrennte Weltbereiche](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html). Die [MultiMesh-Referenz](https://docs.godotengine.org/en/stable/classes/class_multimesh.html) beschreibt außerdem gemeinsame Lichtgrenzen und ignorierte Blend Shapes; animierte Personen werden durch diesen Helfer nicht zusammengefasst.

## Berechnungen auslagern

Für diesen lokalen Android-Prototyp ist Vorberechnung beim Erstellen der Inhalte der nächste sinnvolle Ausbau: Detailstufen, Normal-/Rauheitskarten, statische Beleuchtungsanteile, fertig gebackene Bewegungsclips und kompakte Terrainzellen. Das Handy lädt dann fertige Daten. Die bereits vorhandenen importierten Charakter-LOD-Stufen bleiben nutzbar; der neue Clip-Cache vermeidet wiederholte Erzeugung derselben Korrektur für mehrere Figuren.

Ein Server kann später beispielsweise gemeinsam genutzte Hintergrundsimulation oder die Bereitstellung zusätzlicher Kartenpakete übernehmen. Das entfernt die lokale Darstellung des Dorfes, der Figuren und ihrer Schatten nicht automatisch. Vollständiges Videostreaming wäre eine eigene Produktarchitektur mit Serverbetrieb, laufender Verbindung und zusätzlicher Eingabeverzögerung. Dafür wurde in diesem Block kein Dienst eingerichtet. Die gegenwärtige Priorität bleibt ein lokal spielbares Dorf mit begrenzter Arbeit pro Bild und kleinen nachladbaren Bereichen.

Für eine spätere thermische Regelung empfiehlt Android, tatsächlichen thermischen Spielraum und Status zu beobachten und die Arbeitslast gezielt zu reduzieren, etwa Bildrate, Schatten oder Auflösung. Unterstützung und Messwerte unterscheiden sich zwischen Geräten. Eine solche native Thermal-Anbindung ist hier noch nicht implementiert; siehe [Android Thermal API](https://developer.android.com/games/optimize/adpf/thermal) und [ADPF-Empfehlungen zu gezielten Qualitätsanpassungen](https://developer.android.com/games/optimize/adpf/best-practices-adpf).

## Reproduktion und Evidenz

Die Rohdaten und Protokolle stehen in `evidence/performance/`:

- `before.json`, `after.json`, die beiden `*-graphical.json` und `comparison.json`: gleiche Requisiten, Knochenpositionen, tatsächliche Ressourcen-/Renderzähler, Zeitverteilungen, Quellhashes, Bildhashes und Messgrenzen.
- Acht repräsentative Viewport-PNGs mit zusammen rund 1,7 MB: Wagen, Standhaltung, gegenläufige Gehphasen, hoher Übungstritt und ausgeliehener Helm/Schild.
- `natural-motion-test.log`: 102 Prüfungen, 0 Fehler, einschließlich des einmaligen Bewohnerladens auf der richtigen Detailstufe.
- `static-art-test.log`: 17 Prüfungen, 0 Fehler.
- `legacy-person-test.log`: bestehende Charakterregression mit 221 Prüfungen, 0 Fehler.
- `../engine/validation_report.json`: abschließender zentraler Lauf mit allen 40 Testgruppen, 0 Fehlern und 0 Warnungen; 220 Quellhashes einschließlich Shadern. Die vier angepassten Altspielstand-Journeys bestehen mit 41/142/74/119 Prüfungen.

Aus dem Repositoryverzeichnis mit separaten, leeren `XDG_DATA_HOME`, `XDG_CONFIG_HOME` und `XDG_CACHE_HOME` starten:

```sh
IMPERATHEN_ISOLATED_TEST=1 godot --headless --path prototype --script res://tests/natural_motion_test.gd
IMPERATHEN_ISOLATED_TEST=1 godot --headless --path prototype --script res://tests/village_static_art_test.gd
IMPERATHEN_ISOLATED_TEST=1 godot --headless --path prototype --script res://tests/village_render_probe.gd -- /absolute/path/to/evidence
```

Für einen tatsächlichen grafischen Vergleich denselben Probe mit `--rendering-method gl_compatibility --resolution 960x540 --disable-vsync` und verfügbarem X11-/Wayland-Display ausführen; `--headless` entfällt. Er misst 60 Frames nach zwölf Aufwärmframes je festgelegter Kamera, speichert tatsächliche Renderzähler und Bilder der Requisiten, Gehposen, Techniken und Leihgegenstände. Vorher und nachher müssen derselbe Renderer, dieselbe Auflösung, derselbe Probe, dieselben Kameras und dasselbe Qualitätsprofil verwendet werden. Die Vorher-Fassung ist der oben genannte Ausgangscommit, mit identischer Probe-Datei ergänzt. In der hier verwendeten Umgebung kann `start_display` aus `tools/characters/capture_hero.py` im selben Python-Prozess wie der anschließend gestartete Godot-Unterprozess genutzt werden.

Vor einer Aussage über ein kühleres Handy folgen identische längere Gerätefahrten bei gleichem Profil, Bildratenziel und Ausgangszustand. Framezeitverteilung, Speicher, thermischer Status und tatsächliche Spielbarkeit werden gemeinsam beurteilt; die neuen Geometriezahlen ersetzen diesen Gerätevergleich nicht.
