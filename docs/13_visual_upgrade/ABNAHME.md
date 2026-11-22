# IMPERATHEN · Abnahme des Grenzdorfs

Spielrevision `49f4cbb518ac0a7cb330a1b069ff057d32607fee` baut auf dem Vier-Profil-Stand `465ba372` aus #24 und der Godot-Integration aus #22 auf. Die Referenztafeln des Auftraggebers dienten als Gestaltungsvorlage für Dorfblick, Figurenmaßstab, Materialien und Abstufung. Die Aufnahmen unten stammen aus der spielbaren Szene.

## Änderungen am Spiel

| Bereich | Integrierte Arbeit | Commit |
| --- | --- | --- |
| Dorfpersonen | Der zwölfjährige Spieler, die Gefährten aller fünf Herkünfte, Ausbilder, Rekruten und Gegner verwenden animierte 3D-Modelle. Die zivile Familie enthält altersabhängige Formen, unterschiedliche Gesichter und vier Geometriestufen. | `24bc541`, `4e87fbe` |
| Dorfplatz | Begehbare Werkstatt und Lager, Marktstand, Holzvorräte, Übungsziel und zwei Palisadenmeshes. Der gemeinsame PBR-Atlas enthält Farbe, Normale und Materialeigenschaften. Jahreszeiten verändern Licht, Wolken, Bodenfeuchte und Vegetation. | `a42b749` |
| Spielkamera und HUD | Die Schulterkamera blickt vom Spawn über den Platz. Die Chronik lässt sich aus der Personenansicht öffnen. Beide technischen Kameras, die zum Bauen und auf der Karte gebraucht werden, bleiben verfügbar. | `0361892`, `f597f1d` |
| Armeen | Die der Kamera nächsten sichtbaren Soldaten erhalten eigene Skelette innerhalb des Profilbudgets. Weitere Soldaten bewegen sich instanziert mit der Gangphase ihrer simulierten Bewegung. | `f597f1d` |
| Android | Profile sind im Dorf und im Tal umschaltbar. Es gibt getrennte Compatibility- und Vulkan-Mobile-Exporte. Die Messung unterscheidet aktive Zeit, Simulationsfortschritt, Prozessspeicher, virtuelle Sensoren und die tatsächlich benutzte Render-API. | `812eeac`, `64ec1b2`, `d2d56b8` |

Die Blender-Dateien und Erzeugungsskripte liegen in [art/village](../../art/village/README.md) und [art/village_characters](../../art/village_characters/README.md). Die Gesichtstexturen nutzen die bereits zum Projekt gehörenden Konzeptporträts. Die spielbaren Meshes wurden mit Blender erzeugt. Für diese Revision wurde kein Meshy-Auftrag abgerechnet. Die vier militärischen Grundmodelle stammen aus der bisherigen Produktionslinie. Ihre kantigen Nahgesichter und die Figurenanimationen erreichen das vorgelegte Referenzniveau noch nicht.

## Bildvergleich aus Godot

[Dorf in vier Profilen](evidence/village-comparison.jpg) · [Talszene in vier Profilen](evidence/valley-comparison.jpg) · [Nahaufnahmen von Kind, Ausbilder und Talwache](evidence/closeups.jpg)

Die Dorfbilder verwenden denselben geladenen Italia-Spielstand, die reguläre Schulterkamera und dieselbe Position. Sonne, Uhrzeit, Posen sowie die Bewegung von Wetter und Vegetation sind für den Vergleich fixiert. Die Kampfbilder verwenden denselben Simulationsschritt. Die Nahaufnahmen bewegen die Kamera an die bereits im Spiel befindlichen Charaktere. Die Laufzeitdaten halten die Prüfsummen beider Zustände und die Kameratransformationen fest. [Messdaten und Kamerapositionen](evidence/viewport.json)

Die Bilddateien in diesem Abschnitt sind Godot-Aufnahmen auf Linux. Der Android-Lauf legt seine eigenen Bildschirmaufnahmen im Actions-Artefakt ab. Die 180-Soldaten-Messung vergrößert ausschließlich die sechs Kohorten in der Testszene. Die spielbare Talschlacht beginnt regulär mit 60 Soldaten.

## Reproduktion

Von der Repositorywurzel mit Godot 4.7.2 und einem grafischen Display ausführen. Der temporäre Datenpfad hält die Testpartie von vorhandenen Spielständen getrennt.

```sh
python3 tools/check_prototype.py --report /tmp/imperathen-engine
npm run check
test_data=$(mktemp -d)
XDG_DATA_HOME="$test_data/data" XDG_CONFIG_HOME="$test_data/config" XDG_CACHE_HOME="$test_data/cache" \
  IMPERATHEN_ISOLATED_TEST=1 godot --path prototype --audio-driver Dummy \
  --resolution 1280x720 --script res://tests/live_graphics_review.gd -- /tmp/imperathen-bilder 24
```

Der Engine-Lauf umfasst 15 Prüfsuiten. Er enthält 226 Figurenprüfungen, 325 Prüfungen der Soldatendarstellung und den begehbaren Dorfaufbau. [Prüfprotokoll](evidence/engine-checks.json) · [Figuren](evidence/village_people.log) · [Gebäude](evidence/village_scenery.log)

[Android-Messverfahren](ANDROID_GRAFIKTEST.md) · [Build- und Gerätelog](https://github.com/Ullmann27/Imperathen/actions/runs/45047214144) · [Integrations-PR](https://github.com/Ullmann27/Imperathen/pull/25)

## Messung der Laufzeitszenen auf Linux

Godot renderte mit Mesa llvmpipe auf der CPU bei 1280 × 720. Jede Zeile enthält 24 gerenderte Frames. Beim höchsten Dorfprofil starteten zeitweise zusätzlich die Desktop-Testprogramme auf demselben Host. Die kurzen Intervalle eignen sich zur Kontrolle des Arbeitsaufwands. Belastbare Vergleiche der oberen Framezeit-Perzentile erfordern längere Läufe auf dedizierter Hardware.

| Profil | Dorf: Aufrufe / sichtbare Primitive, Median | Dorf: Bildzeit P50 / P95 / P99, ms | 180er-Szenario: animiert / instanziert am Intervallende |
| --- | ---: | ---: | ---: |
| Leicht | 202 / 138,535 | 202 / 238 / 243 | 24 / 156 |
| Ausgewogen | 247 / 227,260 | 2694 / 3000 / 3019 | 40 / 140 |
| Hoch | 353 / 295,455 | 3230 / 3632 / 3786 | 64 / 111 |
| Sehr hoch | 354 / 305,470 | 3949 / 11594 / 12445 | 90 / 67 |

Das größere Gefecht lief über die Profilwechsel hinweg weiter. Die Zählwerte folgen den tatsächlich verbliebenen Soldaten. Die vier Stufen erlauben höchstens 24, 40, 64 und 90 unabhängige Soldatenrigs. Beim festen Dorfblick liegen Hoch und Sehr hoch optisch noch eng beieinander. Beide verwenden im Nahbereich die volle Grasdichte. Aufwendigere Nahmodelle und deutlicherer Detailgewinn auf sehr hoher Stufe bleiben Entwicklungsziele.

## Gesicherte Auslieferung

[Standard-APK für Android ARM64](https://github.com/Ullmann27/Imperathen/releases/download/graphics-2026-11-22-49f4cbb5/IMPERATHEN-49f4cbb5-arm64.apk) · [Windows-Debugbuild](https://github.com/Ullmann27/Imperathen/releases/download/graphics-2026-11-22-49f4cbb5/IMPERATHEN-49f4cbb5-Windows-x86_64.zip) · [Linux und Vulkan-Mobile](https://github.com/Ullmann27/Imperathen/releases/tag/graphics-2026-11-22-49f4cbb5) · [SHA-256 für alle Downloads](evidence/release-sha256.txt)

Die öffentliche Standard-APK umfasst 82.424.623 Bytes. Ein erneuter Download ergab SHA-256 `d226709ad0c639e2aad87c9e99d61d75d4262e8c48c4c37ea08e622eddfbae72`. Das Linux-Paket und die Windows-EXE unter Wine starteten über ihren grafischen Einstieg bis `IMPERATHEN_READY`. [Linux-Start](evidence/linux-build-start.log) · [Windows-Start unter Wine](evidence/windows-build-start.log)
