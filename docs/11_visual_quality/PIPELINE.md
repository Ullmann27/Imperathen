# Grafikteam: Ausführbare Prüf- und Übergabepipeline

Die Zusammenarbeit ist in [Issue #18](https://github.com/Ullmann27/Imperathen/issues/18)
mit den bestehenden Teams #16 und #17 abgestimmt. Diese Pipeline ergänzt deren
Aufgabenaufteilung. Sie überschreibt weder deren Agent-Runner noch deren
Spiel-, Vorschau- oder Speicherdateien.

**Android hat Vorrang.** PC ist eine spätere Vorbereitung. Die Grafikprüfung
vergleicht drei Stufen – Hoch, Ausgewogen und Niedrig – mit gemeinsamem
Spielinhalt. Die tatsächlich konfigurierten Pixel-, Schatten-, MSAA-, LOD- und
Dekorationswerte sind im [Importvertrag](INTEGRATION.md) beschrieben; maßgeblich
ist [`quality_profiles.json`](../../art/visual_benchmark/quality_profiles.json).

## Besitz und Reihenfolge

| Schritt | Arbeitsbereich | Erwarteter Nachweis |
| --- | --- | --- |
| Architektur | Eigene Erzeugung unter `tools/art/`, Architekturassets im Grafikpaket | Reproduzierbare Herkunft, tatsächliche GLB-Dateien |
| Figuren | Eigene Erzeugung unter `tools/art/`, Figurenassets im Grafikpaket | Maße, sichtbare Rollen, dokumentierter Rig-Status |
| Statische Prüfung | `tools/art/validate_visual_assets.py` | JSON-Ergebnis und Exitcode |
| Szenenaufbau und Bildprüfung | `art/visual_benchmark/` und `art/visual_benchmark/evidence/` | Echte Aufnahmen, Renderer und gemessener Prüfumfang |
| Übergabe | `docs/11_visual_quality/` | Importvertrag, Commit/PR und Grenzen |

## GLB-Dateiprüfung

Der eigene GitHub-Workflow `.github/workflows/visual-quality.yml` führt bei
Änderungen am Grafikpaket den statischen Dateivertrag aus. Dieser CI-Job benötigt
keine zusätzlichen Pakete und keine GPU. Sein Name beschreibt bewusst nur die
GLB-Prüfung; ein grüner Lauf ist kein Android- oder Rendernachweis.

Der vollständige Einstieg lautet `python tools/art/run_visual_pipeline.py`.
Er führt den GLB-Vertrag, frischen Godot-Import, Profilinvarianten und die konkrete
Regression für die Figurenpaletten aus. Die zusätzliche Materialprüfung ist
wegen eines im echten Bildtest gefundenen Importfehlers erforderlich.
Für einen einzelnen Aufruf:

```bash
godot --headless --path art/visual_benchmark --script res://scripts/verify_character_materials.gd
```

`pipeline_receipt.json` enthält die tatsächlichen Schritte sowie SHA-256-Werte
der GLBs, Szenenskripte, Einstellungen und Pipelinequellen. Der Bildtest bleibt
eine getrennte, durch tatsächliche PNG-Aufnahmen belegte Prüfung.

Vom Repository-Hauptverzeichnis aus:

```bash
python tools/art/validate_visual_assets.py --output art/visual_benchmark/evidence/asset_validation.json
```

Alternativer Repository-Pfad:

```bash
python tools/art/validate_visual_assets.py --root /path/to/Imperathen --output /path/to/asset_validation.json
```

Ohne `--output` wird der vollständige JSON-Bericht nach stdout geschrieben.
Der Prüfer liest alle `art/visual_benchmark/assets/**/*.glb`. Er benötigt nur die
Python-Standardbibliothek. Exitcode 0 bedeutet: Alle gefundenen Dateien haben
diesen statischen Exportvertrag bestanden. Exitcode 1 bedeutet: Mindestens eine
Datei ist fehlerhaft oder es wurde noch keine GLB-Datei gefunden. Ein leerer
Assetordner kann keinen erfolgreichen Nachweis erzeugen.

### Tatsächlicher Prüfumfang

- GLB-Magic, Version, exakte Dateilänge, Chunkgrenzen und Ausrichtung.
- Zugängliche eingebettete Buffer, BufferViews und Accessors; Komponententypen,
  Strides, Sparse-Zugriffe, tatsächliche numerische Daten und deklarierte Bounds.
- Indizes innerhalb der vorhandenen Vertices, Dreiecksgeometrie und mindestens
  ein nicht degeneriertes Dreieck je Primitive.
- Vorhandene, annähernd normierte Normalen; referenzierte UV-Kanäle bei Texturen.
- Eingebettete PNG/JPEG-Dateien, Bildmaße und SHA-256; PNG-Chunk-CRC.
- Material-/Textur-/Bildreferenzen und PBR-Faktorbereiche. Konstante Materialien
  sind erlaubt; fehlende Texturverwendung erscheint als Hinweis.
- Szenenhierarchie ohne Zyklen oder mehrfache Eltern; tatsächliche
  Transformationen und plausible räumliche Ausdehnung der Standardszene in Metern.
- Dateihash, Bildhashes und klarer Fehlertext je betroffener Exportdatei.
- Mesh-, Material-, Primitive- und Dreieckszahlen sowie instanzierte Geometrie
  der Standardszene. Primitiveinstanzen vor Batching dienen der Planung, nicht
  als behauptete Drawcall-Messung.
- Abschätzung der eindeutigen Textur-Basisbilder in RGBA8 ohne Mipmaps. Diese
  Zahl ist keine gemessene GPU-Belegung eines Android-Geräts.

Der Prüfer ist ein bewusst begrenztes projektspezifisches Export-Gate auf Basis
der [glTF-2.0-Spezifikation von Khronos](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html).
Er ist kein vollständiger glTF-Schemavalidator. Er decodiert die Bildpixel nicht,
prüft keine Bewegungsqualität und misst keine Bildrate. Der JSON-Bericht nennt
diese Grenzen ausdrücklich. Geometriekompression und unbekannte erforderliche
Erweiterungen werden abgewiesen, statt ungeprüft als bestanden zu gelten.

## Visueller Durchgang

Nach bestandenem Dateivertrag werden tatsächliche Modelle in der Prüfszene
geladen. Zwei Distanzen sind erforderlich: eine Nahaufnahme zur Prüfung von
Oberflächen und Figuren sowie eine Spiel-/Dorfansicht zur Prüfung von Maßstab und
Lesbarkeit. Eine zusätzliche Aufnahme der Bauzustände erleichtert die Übergabe
an Team #17.

Zu jedem Nachweis gehören der verwendete Renderer, Auflösung, relevante
Einstellungen und bekannte Darstellungsgrenzen. FPS, VRAM und Leistungsbudgets
werden nur ergänzt, wenn sie tatsächlich unter dokumentierten Bedingungen
gemessen wurden. Schönes Standbild und spielbare Bildrate sind getrennte Befunde.

Die drei Grafikstufen sind bei gleichbleibender Szene zu vergleichen. Im
ausgewogenen Profil sowohl ein 16:9-Layout mit ungefähr 1920×1080 internen
Bildpunkten als auch das Fold-Seitenverhältnis prüfen. Auf Fold das Seitenverhältnis
erhalten und dasselbe Budget von ungefähr 2,07 Millionen internen 3D-Pixeln
anwenden. Eine starre 1080-Pixel-Vorgabe für die kurze Seite wäre kein gleiches
Pixelbudget. Für die Berechnung sind tatsächliche Ausgabepixel heranzuziehen,
nicht eine virtuelle Canvas-Größe wie 1280×720.
Bedienflächen, Interaktionsmarker und Text dürfen beim Wechsel weder verschwinden
noch ihre Bedeutung ändern. Ein Desktop-Lauf belegt noch keine Android-Leistung.

### Nachweise getrennt führen

Der Headless-Lauf mit `--verify` kann die geladenen Instanzen, wiederholte
Profilwechsel und Berechnungsinvarianten prüfen. Sein Bericht kennzeichnet
`render_proof: false`. Daraus folgt kein sichtbares GPU-Bild und kein
Android-Leistungsnachweis. Da die Prüfszene keine Kampagnenlogik implementiert,
beweist sie auch keine unveränderte Kampagnensimulation über die Profile.

Der Aufnahmeweg `--capture=...` wartet auf einen abgeschlossenen Renderframe
und schreibt ein PNG. Ein Headless-Display wird ausdrücklich abgewiesen.
Eine Aufnahme ist erst dann ein tatsächlicher Godot-Bildnachweis, wenn die Datei
vorliegt, visuell geöffnet wurde und der verwendete Renderer dokumentiert ist.
Blender-Bilder desselben Assets bleiben als Blender-Bilder gekennzeichnet.

Für Touch und kleine Fenster beide Drehungen sowie Größenwechsel prüfen.
Schaltflächen müssen erreichbar bleiben, Bildunterschriften dürfen nicht
abgeschnitten werden und eine Zweifingergeste muss auf Android tatsächlich
zoomen. Godot benötigt dafür die Einstellung
`input_devices/pointing/android/enable_pan_and_scale_gestures`; siehe die
[offizielle Gestendokumentation](https://docs.godotengine.org/en/stable/classes/class_inputeventmagnifygesture.html).
Reale Ausgabe- und virtuelle UI-Größen sind entsprechend der
[Window-Dokumentation](https://docs.godotengine.org/en/stable/classes/class_window.html)
getrennt zu behandeln.

## Übergabestatus

Diese Datei definiert das Verfahren. Sie behauptet für noch nicht erzeugte
Dateien keinen bestandenen Lauf. Die tatsächlichen Ergebnisse stehen im
zeitgestempelten JSON-Bericht und in den nach Ausführung erstellten Bildnachweisen.
Ein Fehler wird zuerst an der verantwortlichen Exportquelle behoben; danach
werden die betroffenen GLB-Dateien erneut exportiert und geprüft. Fremde Pfade
werden dabei nicht verändert.

Für den funktionalen Anschluss gilt der [Importvertrag](INTEGRATION.md). Erst nach
einem realen Test in der Spielschleife darf eine Datei als dort integriert gelten.
Rigging, Animation, Unreal-Import und Leistungsmessung bleiben bis zu ihrem
jeweiligen Nachweis offen.
