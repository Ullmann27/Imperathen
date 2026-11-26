# Renderervergleich Compatibility · Mobile · Forward+ (D-033)

Stand: 26.11.2026, Branch `feat/render-profiles-study-20261126` (Basis 89e735d).
Der Projektrenderer bleibt **unverändert `gl_compatibility`** auf allen Plattformen.

> **Aussagegrenze.** Alle Bilder und Zeiten dieses Dokuments stammen von **Software-Renderern**
> auf einer geteilten Cloud-Maschine mit 4 Kernen und vielen parallelen Agenten:
> Compatibility über Xvfb + Mesa **llvmpipe** (OpenGL), Mobile und Forward+ über Xvfb + Mesa
> **lavapipe** (Vulkan). Sie belegen Bildunterschiede und Funktionsumfang. Zeiten sind nur relative
> Hinweise auf CPU-Rasterisierung, **keine Mobil-GPU- und keine Fold7-Daten**. Ein Rendererwechsel setzt
> zusätzlich die Gerätemessung aus Abschnitt 7 voraus (D-033, D-039).

<!-- RESULT -->

## 3. Harness und Reproduktion

| Teil | Datei | Zweck |
| --- | --- | --- |
| Feste Ansichten, Nacht, Zähler | `prototype/scripts/rendering/render_bench.gd` | gemeinsame Kameras für Desktop und Gerät |
| Ansichten je Renderer/Profil | `prototype/tests/render_comparison.gd` | echter Spielpfad (main.tscn → neues Leben → Valdora) bzw. Stadt |
| Funktionsprobe je Renderer | `prototype/tests/render_feature_probe.gd` | jede Funktion einzeln an/aus auf Ausgewogen, Bild + Kosten |
| Treiber und Auswertung | `tools/render/compare_renderers.py` | startet die drei Renderer, Pixeldifferenzen, Kontaktbögen, `summary.json/.md` |
| Texturpakete | `tools/render/build_texture_package.py` | getrennte Grafikpakete (VRAM-komprimiert / halbe Auflösung) |
| Gerätemodus | `prototype/scripts/ui/android_graphics_probe.gd` Modus `views`, `tools/render/fold7_render_bench.py` | dieselben Ansichten auf dem Fold7 |

Aufruf (unter dem gemeinsamen Schwerlast-Lock):

```bash
python3 tools/render/compare_renderers.py --godot "$G" --out <dir> \
    --renderers compatibility,mobile,forward_plus --steps probe,village,city --frames 5 --lock "$LOCK"
```

Je Renderer: `--rendering-method gl_compatibility --rendering-driver opengl3` bzw.
`--rendering-method mobile|forward_plus --rendering-driver vulkan` mit
`VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json`, `GALLIVM_PERF=no_aos_sampling`, `LP_PERF=no_rast_linear`
(dieselben Schalter wie `/opt/lavapipe/use-lavapipe.sh`, ohne dessen Browser-Argumente).
Auflösung 1280 × 720, isoliertes XDG-Verzeichnis, `Engine.time_scale = 0`, feste Präsentationszeit 4 s.

## 4. Szenen und Kameras (identisch in allen Renderern)

| Ansicht | Inhalt | Kamera |
| --- | --- | --- |
| `house_interior` | I-01-Startansicht im Familienhaus (Innenraum), Spielkamera | Startpose nach neuem Leben |
| `village_lane` | Dorfgasse, Third Person | Spieler (0,9 / 12,5), Gier 0, Neigung 0,24 – identisch mit `village_look_review.gd` „path“ |
| `village_overview` | Dorfübersicht | Auge (31 / 17,5 / 33) → Ziel (−4 / 1 / −9) – identisch mit „overview“ |
| `night_torch` | Dorfgasse nachts mit sechs Fackelständern (OmniLight3D) | wie `village_lane` |
| `city_forum`, `city_market` | Stadt (`city_exploration.gd`) | Spots wie `roman_city_visual_capture.gd` |

Die Nacht ist **Harness-Testbeleuchtung** (Mond 0,05, Umgebungslicht × 0,14, Himmel × 0,07, Fackel
2,4 / Reichweite 8,5 m), ausdrücklich kein Lookdev-Wert; sie dient nur dem Vergleich von
Punktlichtern, Punktlichtschatten, Glow und volumetrischem Nebel.
Variante `base` = exakt die Spieleinstellung des Profils; Variante `fx` = zusätzlich alle
fortgeschrittenen Funktionen, die der laufende Renderer kann (AO, SSIL, SDFGI, volumetrischer Nebel,
SSR, Glow) mit **Engine-Standardparametern** – Fähigkeitsschau, kein Lookvorschlag.
