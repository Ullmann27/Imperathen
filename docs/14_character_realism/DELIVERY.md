# Hauptcharakter: anatomische 3D-Figur, Mimik und echte Renderings

**22. November 2026 · Arbeitsbranch `feature/hero-realism-20261122` · Bezug: [Issue #33](https://github.com/Ullmann27/Imperathen/issues/33).**

Die Italia-Hauptfigur verwendet jetzt ein anatomisch aufgebautes, animiertes 3D-Modell mit separaten Augen und eigenen Gesichtsmorphs. Die Figur liegt als bearbeitbare Blender-Datei und als vier tatsächlich importierte Godot-Modelle vor. Die ursprüngliche vereinfachte Figur bleibt für andere Herkünfte und als Ersatz bei fehlenden neuen Modellen erhalten.

Der neue Stand ist ein überprüfter Ausbau des Prototyps. Die vom Nutzer mit einer hochwertigen Spielszene konkretisierte PC-/Konsolenqualität ist noch nicht erreicht. Issue #33 bleibt deshalb offen. Die [unabhängige visuelle Prüfung](../art/HERO_INDEPENDENT_REVIEW_2026_11_22.md) beschreibt die verbleibenden Unterschiede ausdrücklich.

## Ausgangspunkt und Auftrag

Dieser Branch setzt `integration/realistic-android-23` bei Commit `0f23134460ed0565b36c44adefd22bc6a7da75b1` fort. Die vorbereitete Waffenarbeit aus [PR #30](https://github.com/Ullmann27/Imperathen/pull/30) wurde ebenfalls tatsächlich ausgeführt und verbessert. Es erfolgte kein Merge nach `main`.

Der Nutzer verlangt glaubwürdige Gesichter, Haare, ausmodellierte Kleidung, natürliche Materialien und eine hochwertige Lichtwirkung; Android bleibt die erste Zielplattform. Seine jüngste Bildreferenz dient als Qualitätsmaßstab. Mittelalterliche Kostüme aus dieser Referenz werden nicht als römische Ausrüstung übernommen. Das Nutzerbild wurde nicht in das öffentliche Repository kopiert.

## Modell und Laufzeit

Die geometrische Basis und ausgewählte Grafikdaten stammen aus den offiziellen CC0-Assets von MakeHuman. Eigene Arbeiten umfassen Altersanpassung, das kompakte Skelett, Gesichtsmorphs, Tunika und Sandalen, Materialkarten, vier Exporte und die Einbindung in den bestehenden Spieler. Die [Quellmanifeste](../../art/hero_quality/source/provenance.json) und der [System-Asset-Beleg](../../art/hero_quality/source/system_assets/provenance.json) enthalten konkrete Quellen, Revisionen und SHA-256. Die Prüfsummen aller 32 übernommenen Quelldateien stimmen mit den Manifesten überein. MakeHuman-Programmcode wurde nicht übernommen.

- **Kopf und Körper:** räumliche Nase, Lippen, Lider, Ohren und Kiefer, separate Augengeometrie, Haut-UVs und Haargeometrie. Der Grundkörper ist 1,50 m hoch. `Mature` verändert die Anatomie; die bestehende Skalierung 1,14 bildet die erwachsene Variante. Das sind zunächst zwei Altersformen, keine vollständige kontinuierliche Lebensalter-Simulation.
- **Rig und Bewegung:** 15 Knochen und elf tatsächliche Clips: `idle`, `march`, `run`, `gather`, `talk`, `train`, `work`, `block`, `attack`, `hit`, `death`. Die Übungswaffe bleibt beim erwachsenen Spieler in den vorhandenen Kampf-/Trainingsaktionen sichtbar schaltbar.
- **Mimik:** `Blink_L`, `Blink_R`, `JawOpen`, `Smile`, `BrowDown`, ergänzt durch `Mature` und `Companion`. Der Laufzeitcontroller bewegt die beiden Augen leicht versetzt und erzeugt Gesprächs-/Aktionsausdrücke pro Instanz. Die Gesprächsmimik ist noch keine sprachabhängige Lippensynchronität.
- **Integration:** Die neue Serie wird für den Spieler mit Herkunft `italia` gewählt, wenn alle vier importierten Dateien vorhanden sind. Beim Modellwechsel wird die neue Instanz vor dem Entfernen der alten aufgebaut. Ein fehlgeschlagener optionaler Austausch lässt die Figur nicht verschwinden.
- **Detailwechsel:** Animation und Phase bleiben erhalten. Eine Abstandshysterese verhindert fortlaufendes Hin- und Herschalten an einer Grenze. Ungenutzte Hero-LOD-Ressourcen werden nicht dauerhaft im eigenen Szenencache gehalten. Gesichtsmorphs werden auf den beiden fernsten Stufen nicht fortlaufend aktualisiert.

Die neue Figur ist kein vollständiger Charaktereditor. Andere Herkunftsfiguren, Gefährten, historische Persönlichkeiten und eine fertige Soldatenrüstung wurden in diesem Schritt nicht durch neue gleichwertige Modelle ersetzt.

## Tatsächliche Exportwerte

Die Zahlen stammen aus dem unabhängigen [GLB-Audit](../../art/hero_quality/validation.json), nicht aus Zielbudgets.

| Datei | Dreiecke | Dateigröße in Byte | Größte Bildkante |
| --- | ---: | ---: | ---: |
| `hero_quality_0.glb` | 32.820 | 13.644.588 | 2.048 px |
| `hero_quality_1.glb` | 16.417 | 6.030.876 | 1.024 px |
| `hero_quality_2.glb` | 7.222 | 3.026.828 | 512 px |
| `hero_quality_3.glb` | 2.820 | 966.952 | 256 px |

Jede Stufe enthält 14 Meshes mit 14 Materialflächen, fünf Materialien und neun eindeutige eingebettete Bilder. Die tatsächlichen Morphdeltas sind vorhanden und nicht nur benannt; alle elf Animationen enthalten veränderliche Kanäle. Joint-Indizes sind gültig, die Hautgewichte normalisiert. Der größte festgestellte Summenfehler liegt bei rund 0,000000119.

**Grafikprofil und Modell-LOD sind unterschiedliche Einstellungen.** Leicht, Ausgewogen, Hoch und Sehr hoch beeinflussen die bestehenden Darstellungsbudgets und verschieben die LOD-Abstände. In einer Nahaufnahme kann jedes Profil LOD 0 verwenden. Die vier Modelldateien sind deshalb keine feste Eins-zu-eins-Zuordnung zu diesen Profilnamen.

Die rechnerische RGBA8-Summe der unkomprimierten Basisbilder von LOD 0 beträgt etwa 57 MiB. Dieser Wert enthält keine Mipmaps und ist keine Messung des Android-Grafikspeichers. Die tatsächliche mobile Speicher- und Dauerlast muss auf dem Zielgerät geprüft werden.

## Tatsächliche Bilder und Bewegung

| Nachweis | Inhalt |
| --- | --- |
| [Blender: Kopf](../../art/hero_quality/review/hero_child_face.png) | Echter Cycles-Render der gespeicherten Modellgeometrie |
| [Blender: erwachsene Form](../../art/hero_quality/review/hero_adult_face.png) | Derselbe Charakter mit Altersmorph |
| [Blender: Lidschluss](../../art/hero_quality/review/hero_blink.png) | Tatsächliche Lidverformung |
| [Blender: Laufpose](../../art/hero_quality/review/hero_run.png) | Tunika, Körper und Skelett in einer deformierten Pose |
| [Godot: bisherige Geometrie](evidence/before/child-front.png) | Dieselbe Studioprüfung mit ausdrücklich gewählter bisheriger Modellserie |
| [Godot: neue Geometrie](evidence/after/child-front.png) | Neuer Produktionsspieler mit importiertem Hero-GLB |
| [Godot: erwachsener Lidschluss](evidence/after/adult-blink.png) | Gemeinsame Wirkung von Altersmorph und echtem Blinkcontroller |
| [Godot: Profilansicht](evidence/after/child-profile.png) | Formprüfung von Nase, Lippen, Kiefer, Ohr und Haaren |
| [Godot: kleinste Geometrie](evidence/after/asset-lod-3.png) | LOD 3 bewusst bei gleicher Nahkamera zur Prüfung der Reduktion |
| [Godot: tatsächlicher Marschzyklus als MP4](evidence/after/hero_march.mp4) | Drei Sekunden Bewegung des erwachsenen Modells im Studio |

Die Godot-Aufnahmen benutzen den tatsächlichen `VillagePerson`-Darsteller in einem kontrollierten Studio. Sie sind keine Dorf- oder Android-Screenshots. Die Vergleichsoption wählt nur die alte Modellroute; sie baut keine nachgemalte Vergleichsfigur. Die [Aufnahmedaten](evidence/after/runtime-review.json) protokollieren Engine, Renderer, Grafikadapter, Kamera, Modellroute, Gesichtsgewichte und Quellhashes.

Die Studioausgabe verwendet Godot 4.7.2, Compatibility/OpenGL und den Desktop-Software-Renderer Mesa llvmpipe bei 1.600 × 900 Pixeln. Für die Bewegungsaufnahme werden 72 echte Viewportbilder aus drei Marschzyklen zu einem Video mit 24 Wiedergabebildern pro Sekunde zusammengesetzt. Diese Wiedergaberate ist keine gemessene Spielbildrate.

Das H.264-Video wurde mit `ffprobe` als 72 Bilder, 1.600 × 900 Pixel und 3,000 Sekunden geprüft. Der [Videobeleg](evidence/after/motion_receipt.json) enthält den Videohash und die Hashes aller ursprünglichen Einzelbilder. Die reproduzierbaren PNG-Zwischenbilder wurden nach der Kodierung entfernt.

Das [generierte Zielbild](../../art/hero_quality/reference/README.md) bleibt separat als Konzeptreferenz gekennzeichnet. Es belegt weder einen fertigen 3D-Charakter noch die Grafikleistung der App.

## Ausgeführte Prüfungen

- **Vier GLB-Dateien:** unabhängige Byteprüfung bestanden, einschließlich tatsächlicher Geometrie, UVs, Morphdeltas, Skin-Gewichte, Animationskanäle, eingebetteter Bilder und fallender Dreieckzahlen.
- **Godot-Import:** alle vier Hero-Modelle und beide neuen Waffen erfolgreich importiert.
- **Hero-Laufzeitprüfung:** 55 Prüfungen bestanden. Dazu gehören Instanzunabhängigkeit der Mimik, Altersform, LOD-Wechsel, Animationsphase, Abstandshysterese und tatsächliche Freigabe ungenutzter Nahgeometrie.
- **Village-Personen:** 221 Prüfungen bestanden. Fünf alte regionale Kleidungsumschaltungen entfallen beim neuen eigenständig bekleideten Italia-Hero; deshalb ist die Zahl kleiner als beim zuvor geprüften Legacy-Stand mit 226 Prüfungen.
- **Gesamter Prototyp:** alle 16 Prüfgruppen bestanden, einschließlich Welt, UI, Kampfregeln, Gang, Jahreszeiten, Galerie, Landschaft, Architektur und Hauptszene. [Vollständiger Bericht mit Quellhashes](evidence/checks/validation_report.json).
- **APK-Inhaltskontrolle:** fünf gezielte Python-Tests bestanden. Die synthetischen ZIP-Fixtures prüfen fehlende oder defekte Hero-Payloads und gültige historische Projektstände. Das ist ausdrücklich noch kein Android-Gerätelauf.
- **Bestehende Foundation-Prüfungen:** Koordinationsprüfung, 18 Kernlogiktests, 14 Pipeline-Tests, Frontend-Syntax und die vorhandene statische Unreal-Prüfung bestanden. Daraus folgt kein Unreal-Build.

Der Android-Workflow ist für diesen Featurebranch aktiviert. Die APK-Prüfung verlangt bei dieser Quellversion alle vier Hero-Dateien und die Gesichtskomponente als echte auflösbare APK-Inhalte. Sie erfasst die Hashes der tatsächlich exportierten Daten getrennt von lokalen GLB-Quellhashes. Ein erfolgreicher Bau und dessen Emulatorprüfung werden mit ihrer eigenen Commitkennung dokumentiert; sie ersetzen keine physische Android-Grafikabnahme.

## Waffen und historische Figuren

Gladius und Scutum liegen als tatsächliche GLBs und gepackte Blender-Dateien vor. Die Waffen wurden nach dem Export erneut importiert und [mit Cycles gerendert](../../art/weapons/weapons_studio_preview.png). Die Byte- und Quellgeometrieprüfungen sind bestanden. Es handelt sich um einfache eigene Ausrüstungsstudien mit Griffmarkern; die neuen Dateien sind noch nicht in ein frei bedienbares Ausrüstungssystem eingebunden. Nur LOD 0 ist vorhanden. [Waffenlieferung](../../art/weapons/README.md).

Das [historische Quellenblatt](../art/CHARACTER_REFERENCE_SOURCES_2026_11_22.md) dokumentiert Caesar, Brutus und Marcus Aurelius sowie die Abgrenzung zwischen überliefertem Objekt und ergänzter Rekonstruktion. Der bestehende Prototyp zeigt für den jungen Lebenslauf 94 n. Chr. und für das freie Szenario zunächst 100 n. Chr.; dieser Kalender wurde nicht umgestellt. Neue historische Figuren wurden hier nicht als bereits fertig modelliert oder zeitlich freigegeben ausgegeben.

## Was zur Referenzqualität noch fehlt

Die wesentlichen sichtbaren Lücken sind die geschlossene Haarform, die gleichmäßige Haut, der einfache Mundinnenraum ohne ausgearbeitete Zähne/Zunge, eine verbleibende innere Lidfalte sowie wenig ausgearbeitete Stofffalten und die steife Saumverformung. Der Erwachsene besitzt noch dieselbe Hauttextur und Tunika. Die kleine Skelettstruktur ersetzt keine vollständige Hand-, Gesichts- oder Kleidungssimulation.

Die bisherige visuelle Prüfung umfasst ausgewählte Ansichten und Bewegungsphasen. Die nächste künstlerische Arbeit muss diese konkret sichtbaren Punkte verbessern. Die formelle Abnahme aus Issue #33 bleibt offen, bis der Charakter im Zielbuild mit Bewegung, Nahansicht, Ausrüstung und Kampf überzeugt und auf einem physischen Android-Gerät geprüft ist. Es wurden keine Meshy-Credits und keine anderen kostenpflichtigen Assetdienste verwendet.

## Wiederholen

```sh
blender -b -t 4 -P tools/characters/build_hero.py -- --export
python tools/characters/validate_hero.py --report art/hero_quality/validation.json
python tools/check_prototype.py --report docs/14_character_realism/evidence/checks
python tools/characters/capture_hero.py --software-x11 --baseline --output docs/14_character_realism/evidence/before
python tools/characters/capture_hero.py --software-x11 --motion --output docs/14_character_realism/evidence/after
ffmpeg -framerate 24 -i docs/14_character_realism/evidence/after/motion/frame-%04d.png -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart docs/14_character_realism/evidence/after/hero_march.mp4
python -m unittest discover -s tests -p android_hero_payload_test.py
```

Der Capture-Helfer nutzt bei Bedarf einen privaten authentifizierten Xorg-Server mit Software-Rendering und temporären Godot-Einstellungen. Er verändert keine vorhandenen Spielstände. Ohne passende grafische Umgebung meldet er einen Fehler; Headless-Ausgaben werden nicht als gerenderte Bilder ausgegeben.
