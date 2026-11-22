# IMPERATHEN – Android-Grafikstudie

Dieses dritte Team unterstützt die bereits arbeitenden Teams [#16](https://github.com/Ullmann27/Imperathen/issues/16) und [#17](https://github.com/Ullmann27/Imperathen/issues/17). Eigene Koordination: [#18](https://github.com/Ullmann27/Imperathen/issues/18).

**Aktuelle Nutzerentscheidung vom 22. November 2026: Android ist die Hauptplattform.** Ein späterer PC-Ausbau wird über portable GLBs, bearbeitbare Blender-Quellen und getrennte Grafikprofile vorbereitet. Die Grafik soll auf hohen Einstellungen sichtbar anspruchsvoll sein; niedrige Einstellungen bewahren Figuren, wichtige Gebäude, Bedienung und Spielregeln.

## Direkt starten

Godot 4.7.2 wurde für diese Lieferung tatsächlich verwendet. `project.godot` in diesem Ordner öffnen und das Projekt starten. Auf einer geeigneten Grafikoberfläche funktioniert auch:

```sh
godot --path art/visual_benchmark
```

Der Schauraum zeigt zwei Instanzen des Hauses, einen Brunnen, eine Baustufe und zwei Figuren. Es ist eine Grafikprüfszene; die Kampagne entsteht beim Team #17. Die hier erzeugten Assets ersetzen dort noch keine animierten Spielfiguren.

- **Ziehen** dreht die Kamera; **Mausrad, Pinch oder +/−** verändern den Abstand.
- **Dorf / Haus / Figuren / Übersicht** wechseln zwischen festen Prüfansichten.
- **Licht wechseln** zeigt Morgenlicht beziehungsweise neutrales Tageslicht.
- **Niedrig / Ausgewogen / Hoch** wirken sofort und werden lokal gespeichert.
- **P** schreibt auf dem Entwicklungsrechner eine echte Viewport-Aufnahme samt Renderer-/Gerätebeleg nach `evidence/`. **Leertaste** schaltet den Kameralauf um.

## Drei Grafikstufen

| Einstellung | Niedrig | Ausgewogen | Hoch |
| --- | ---: | ---: | ---: |
| 3D-Pixelbudget bei 16:9 | bis 1280×720 | bis 1920×1080 | bis 2560×1440 |
| Kantenglättung | aus | 2× MSAA | 4× MSAA |
| Schattenatlas | 1024 | 2048 | 4096 |
| Schattendistanz | 24 m | 48 m | 85 m |
| Kosmetische Grasmenge | 22 % | 60 % | 100 % |

Das Display-Seitenverhältnis bleibt erhalten, auch auf Fold-Geräten. Ausgewogen nutzt etwa 2,07 Millionen 3D-Pixel; bei quadratischem Display entspricht das ungefähr 1440×1440. Kleinere Displays werden nicht unnötig über ihre tatsächliche Auflösung hinaus gerendert. Die 2D-Oberfläche bleibt in Ausgabeauflösung. Die Engine-Untergrenze von 25 % Skalierung begrenzt das Pixelbudget bei extremen Ausgabegrößen; diese Lieferung prüft keine 8K-Ausgabe.

Alle Stufen bewahren dieselben Hauptobjekte. Die Unterschiede betreffen Grasdekoration, entfernte Meshdetails, Schatten und Kantenglättung. Texturdateien werden in diesem ersten Stand nicht je Profil ausgewechselt. Der Mobile-Renderer ist vorgesehen; Compatibility dient als unterstützter Fallback. Desktop-Forward+-Effekte sind keine Android-Pflicht.

## Geliefertes Assetpaket

- `assets/architecture/frontier_house.glb`: detailliertes Grenzhaus mit echter Tür-/Fensteröffnung und Inneneinrichtung.
- `assets/architecture/village_well.glb`: gemauerter Brunnen, Holztragwerk, Winde, Seil und Eimer.
- `assets/architecture/house_foundation.glb`: Fundament, Teilwände, Gerüst, Leiter und Materialvorrat.
- `assets/characters/civilian_youth.glb` und `frontier_guard.glb`: zwei statische Rollenstudien.
- `assets/characters/*_lod1.glb`: reduzierte Varianten mit identischer Ausdehnung.

Die Dateien sind vollständig lokal erzeugt. Die `.blend`-Quellen enthalten die Materialkarten; die GLBs enthalten ihre eigenen Texturen. Der Import nutzt generierte LODs und eingebettete Basis-Universal-Texturen. Es wurden keine fremden Modelle oder Materialpakete heruntergeladen.

**Qualitätsstand:** Die Gebäude sind detaillierte erste wiederverwendbare Assets. Die Figuren sind erkennbare Rollenmodelle; Gesichter, Haare, Haut und Stoffsilhouetten erreichen das angestrebte Realismusniveau noch nicht. Rigging und Bewegungen fehlen. Ein erfolgreicher Dateicheck ersetzt diese künstlerische Abnahme nicht.

## Grafikpipeline

Nach Schließen des Editors:

```sh
python tools/art/run_visual_pipeline.py
```

Nur die vorhandenen Assets prüfen:

```sh
python tools/art/run_visual_pipeline.py --assets-only
```

Originale Modelle und Materialkarten lokal reproduzieren:

```sh
python tools/art/run_visual_pipeline.py --rebuild --render-previews
```

Die Pipeline prüft GLB-Bytes, Materialien, Maße, Indexdaten und eingebettete Texturen, führt einen echten Godot-Import aus und testet wiederholte Profilwechsel. Ein Headless-Test ist ausdrücklich kein GPU- oder Android-Leistungstest. `evidence/asset_validation.json`, `engine_invariants.json` und `pipeline_receipt.json` nennen den tatsächlichen Umfang. Blender-Vorschauen werden von Godot-Aufnahmen getrennt bezeichnet.

## Anschluss an das Spielteam

Der [Importvertrag](../../docs/11_visual_quality/INTEGRATION.md) beschreibt Metermaßstab, Bodenpivot, Y-up und Front +Z. Produktionsimporte übernehmen gezielt die GLBs und ihre passenden Importparameter. `.blend`-Quellen, Artberichte und Reviewbilder gehören nicht in die Android-APK.

Noch offen sind Animation/Rig, Engine-Kollision, Navigationsprüfung, echte Touch-/Fold-Geräteläufe und mindestens ein längerer Android-Test mit Framezeiten, Speicher und Temperatur. Hoch ist ein anspruchsvoller visueller Zielpfad, keine ungemessene Behauptung über den schnellsten Mobilchip.
