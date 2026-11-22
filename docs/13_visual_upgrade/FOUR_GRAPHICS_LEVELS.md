# IMPERATHEN — vier Android-Grafikstufen und realistisches Grenzdorf

**22. November 2026 · Arbeitspaket zu [Issue #23](https://github.com/Ullmann27/Imperathen/issues/23)**

## Status dieses Branches

Dies ist die **erste technische Verdrahtung** von vier Grafikprofilen, **nicht** die versprochene fotorealistische Dorfrevision. Kein Android-Gerät wurde mit diesem Commit gemessen. Die in der ChatGPT-Unterhaltung gezeigten KI-Konzeptbilder sind Visualisierungen, keine Belege für ein Godot-Rendering. Die 3D-Dorfpersonen bestehen weiterhin teilweise aus Boxen/Kugeln/Zylindern in `prototype/scripts/world/village_art.gd`.

- Die Schlüssel bleiben `low` (neuer Anzeigename **Leicht**), `balanced`, `high`, neu `very_high`. Bestehende Qualitäts-Einstellungen in `user://imperathen_ui.cfg` bleiben gültig.
- Die gleiche Spielwelt und dieselben Interaktionsregeln werden gezeigt; Qualitätsprofile verändern nur Renderbudget, Schatten, LOD und Dichte. `game_world.gd`, `valley_scene.gd` und `grove.gd` akzeptieren den vierten Key.
- UI, `RuntimeDisplay`, Android-Welt, Talgefecht, Vegetation, Showroom und die vorhandenen Rendering-Smoke-Tests sind auf den neuen Key vorbereitet.
- Der neue Wert `very_high` erhält vorsorglich eine 30-FPS-Obergrenze, bis eine 20-Minuten-Messung zeigt, ob höhere Limits sinnvoll sind.
- Der aktuelle Projektstart verwendet GL-Compatibility. Die Vulkan-Mobile-Validierung und ein sicherer Fallback fehlen **noch**. Shaderfunktionen der Godot-Renderer nicht gleichsetzen.

## Konfigurationsvertrag

| ID | Anzeigename | Max. interne Android-3D-Pixel | MSAA | Schattenatlas | Reichweite | Mesh-LOD-Schwelle | Dekoration | Obergrenze FPS |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `low` | Leicht | 921.600 | 0 | 1024 | 24 m | 3,00 | 22 % | 30 |
| `balanced` | Ausgewogen | 2.073.600 | 2 | 2048 | 48 m | 1,50 | 60 % | 60 |
| `high` | Hoch | 3.686.400 | 4 | 4096 | 85 m | 0,65 | 100 % | 60 |
| `very_high` | Sehr hoch | 5.760.000, **höchstens native Auflösung** | 4 | 4096 | 110 m | 0,40 | 100 % | 30 |

Die Werte sind Startwerte, keine FPS-Garantie. Bestehendes Verhalten bei `high` unterscheidet sich von `very_high` insbesondere in 3D-Budget, Schattenentfernung und LOD-Distanz. Der Vergleich muss in derselben Kamera mit denselben Szenen gemessen werden. Höherer Schattenatlas (8192) oder 8x MSAA dürfen **nicht** ohne Prüfung aktiviert werden. Der Android-Benchmark muss thermische Stabilität und Arbeitsspeicher prüfen.

## Noch erforderliche Grafikproduktion

1. Protagonist als altersgerechter **12-Jähriger** für den Start, Gefährte, Ausbilder/Marcus, Wache, Arbeiter: echte GLB-3D-Figuren mit Gesichtern, Händen, Haaren, Kleidung, Rig, Animationen und mehreren LODs. Die bestehenden Porträts sind kein Nachweis für diese 3D-Integration.
2. `Art.person()` in laufender Dorfwelt schrittweise durch einen Modelladapter ersetzen; Ausrichtung, Fußboden, Kollision, Spiel-ID, Position, Touch-Interaktion, Kind-/Erwachsenen-Lebensphase und Save/Load erhalten. Die bereits vorhandenen 3D-Soldaten können nicht unbesehen die Hauptfigur ersetzen.
3. Dorfgestaltung: PBR-Terrain, Fußwege, Kies, Erde, Grasvarianten, Palisaden, authentische Fenster/Türen, Ziegel/Dach, Markt, Brunnen und Holzlager. Bereits gebautes Atrium und visuelle Benchmark-Assets nutzen; Modelle müssen **im echten Spiel** erscheinen, nicht nur im Showroom.
4. Leistungsoptimierung: Texture LOD/Kompression (ASTC/ETC2 nach Geräteunterstützung), instanzierte Dekoration, LOD/HLOD für Gebäude und Armeen, Beleuchtungs- und Schattenbudget, aggressive Fernsichtoptimierung ohne Änderung an Spielwerten.
5. Gerätetests nach [Issue #23](https://github.com/Ullmann27/Imperathen/issues/23): günstiges Android-Gerät, S24, S25, Fold7, 2026 Gaming-Flaggschiff. p50/p95/p99, Render-CPU/GPU, RSS/PSS, Temperatur/thermischer Status nach 20 min, 4 vergleichbare Engine-Screenshots, 2 Gefechtsscreenshots, keine falschen Bildratenbehauptungen.

## Pfade und Verantwortung

- Grafikprofil: `prototype/assets/quality_profiles.json` und `art/visual_benchmark/quality_profiles.json` (gleiche Schlüssel und Werte).
- Speicherbare UI: `prototype/scripts/ui/game_ui.gd`; Renderbudget und Diagnose: `prototype/scripts/ui/runtime_display.gd`.
- Dorf: `prototype/scripts/world/game_world.gd`, `prototype/scripts/world/village_art.gd`, Vegetation `prototype/scripts/visuals/grove.gd`.
- Tal: `prototype/scripts/tactics/valley_scene.gd`, `prototype/scripts/tactics/valley_landscape.gd`, `prototype/scripts/main.gd`.
- Prüfungen: `prototype/scripts/ui/ui_smoke.gd`, `prototype/scripts/world/world_smoke.gd`, `prototype/tests/visual_benchmark.gd`, `art/visual_benchmark/scripts/showroom.gd`.
- Die Agents behalten getrennte Eigentumsbereiche und koordinieren über Issue #23. Nicht ungeprüft andere laufende PRs überschreiben oder nach `main` mergen.

## Technischer Hinweis

Offizielle Godot-Rendererübersicht: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html. **Mobile** bietet nicht automatisch desktopexklusive SDFGI, SSR oder volumetrischen Nebel. Für statische Gebäudeteile kommen vorberechnete Beleuchtung und ReflectionProbes in Frage. Freier Städtebau braucht eine andere Strategie, weil LightmapGI nicht zur Laufzeit in einem exportierten Spiel gebacken werden kann.
