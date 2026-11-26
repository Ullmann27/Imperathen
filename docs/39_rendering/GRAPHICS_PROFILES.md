# Grafikprofile Leicht · Ausgewogen · Hoch · Ultra (D-034, D-050)

Stand: 26.11.2026, Branch `feat/render-profiles-study-20261126` (Basis 89e735d).
Das höchste Profil heißt seit D-050 **Ultra** (Kennung `very_high` unverändert, gespeicherte Einstellungen
bleiben gültig); „Sehr hoch“ bezeichnet unten nur noch den Stand vor dieser Arbeit.
Status je Aussage: **implementiert** (Code vorhanden), **getestet** (automatischer Test grün),
**gerendert** (Bild auf dieser Maschine, Software-Renderer), **gerätebestätigt** (Fold7) – Letzteres
gibt es für keinen Wert in diesem Dokument.

Zuständigkeit: Dieses Arbeitspaket besitzt die Engine-Schalter der Profile und die Messharness.
Lookwerte (Belichtung, Tonemapper, Grading, Sonne/Himmel, Fackelfarben) gehören der Lookdev
(`feat/village-lookdev-20261126`) und wurden hier nicht verändert.

## 1. Wo die Profile definiert sind

| Ort | Rolle |
| --- | --- |
| `prototype/assets/quality_profiles.json` | Zentrale Daten: Pixelbudget, MSAA, Sonnenschatten-Atlas/-Reichweite, Mesh-LOD, Dekoanteil, Glow, Prüfgrenzen; neu: Blöcke `render` und `density` |
| `prototype/scripts/ui/runtime_display.gd` | Autoload; wendet Profil auf den Root-Viewport an (vorher: MSAA, LOD, Sonnenschatten-Atlas, Bildratenlimit, 3D-Skalierung); neu über `render_profile.gd` |
| `prototype/scripts/rendering/render_profile.gd` | **neu**: renderer-bewusste Engine-Schalter, Lichtbudget, AO, Dichte-Hooks, Texturpakete |
| `prototype/scripts/rendering/fold7_quality_policy.gd` | Empfehlung Adreno 830 → `high`; adaptive 3D-Auflösung nur Hoch/Sehr hoch |
| `prototype/scripts/ui/game_ui.gd` | Auswahl und Speicherung (`user://imperathen_ui.cfg`), Hinweistext „Fold7-Grafikziel: Hoch“ |
| `scripts/world/game_world.gd` (Dorf) | MSAA, Sonnenschatten-Reichweite und Kaskaden je Profil (in der Lookdev-Branch nach `village_look.gd` verlagert) |
| je Szene fest kodiert | `grove.gd`, `village_scenery.gd`, `settlement_dressing.gd`, `frontier_dressing.gd`, `village_person.gd`, `city_*`, `viva_roma_atmosphere.gd`, `world_stream_plan.gd`, `valley_*`, `imperial_fx.gd` |

## 2. Was jedes Profil vor dieser Arbeit änderte (89e735d)

| Bereich | Leicht | Ausgewogen | Hoch | Sehr hoch | Quelle |
| --- | --- | --- | --- | --- | --- |
| 3D-Pixelbudget mobil | 0,92 MP | 2,07 MP | 3,69 MP | 5,76 MP | `max_3d_pixels` |
| 3D-Pixelbudget Desktop | 0,92 MP | 2,07 MP | 8,29 MP | 8,29 MP (= Hoch) | `desktop_max_3d_pixels` |
| Bildratenlimit | 30 | 60 | 60 | 30 | `runtime_display.gd` |
| MSAA 3D | aus | 2× | 4× | 4× (= Hoch) | `runtime_display.gd`, `game_world.gd` |
| Sonnenschatten-Atlas | 1024 | 2048 | 4096 | 4096 (= Hoch) | `shadow_atlas_size` |
| Sonnenschatten-Reichweite | 24 m | 48 m | 85 m | 110 m | `game_world.gd`, `valley_landscape.gd`, `viva_roma_atmosphere.gd` |
| Schattenkaskaden (Dorf) | 1 | 2 | 4 | 4 (= Hoch) | `game_world.gd` |
| Schattenfilter Sonne | nicht gesetzt (Projektstandard soft_low für alle) | ← | ← | ← | – |
| Fackel-/Punktlichtschatten | nicht konfiguriert (Projektstandard 4096 Desktop / 2048 mobil) | ← | ← | ← | – |
| Punktlichtbudget | keine Regel | ← | ← | ← | – |
| Mesh-LOD-Schwelle | 3 | 1,5 | 0,65 | 0,4 | `mesh_lod_threshold` |
| Figuren-LOD-Distanzfaktor | 0,55 | 0,86 | 1,15 | 1,5 | `village_person.gd` |
| Vegetation/Deko Dorf (Anteil) | 22 % | 60 % | 100 % | 100 % (= Hoch) | `decoration_fraction` |
| Vegetation Reichweite Dorf | 24 m | 40 m | 58 m | 72 m | `village_scenery.gd` |
| Bäume nah/mittel bis | –/24 m | 17/52 m | 28/76 m | 38/110 m | `grove.gd` |
| Siedlungs-/Grenzdeko Reichweite | 24/24 m | 38/42 m | 56/65 m | 72/90 m | `settlement_dressing.gd`, `frontier_dressing.gd` |
| Bodenrelief, Wasserdetail, Regen | reduziert, aus, aus | voll | voll | voll | `village_scenery.gd` |
| Glow | aus | aus | an | an | nur Datenfeld; in 89e735d nirgends angewendet |
| Himmels-Radiance (Stadt) | 64 | 64 | 128 | 128 | `viva_roma_atmosphere.gd` |
| Umgebungsverdeckung (AO) | keine | keine | keine | keine | – |
| Anisotrope Filterung | Projektstandard 4× für alle | ← | ← | ← | – |
| Texturauflösung | keine Profilsteuerung; nur indirekt über Figuren-LOD (LOD0 2048², LOD1 1024², LOD2 512²) | ← | ← | ← | – |
| Texturkompression | 659 von 666 Texturimporten verlustfrei (`compress/mode=0`), siehe 5.3 | ← | ← | ← | `.import` |
| Stadt: Statisten / Menge | 0 / 4 | 2 / 8 | 4 / 12 | 6 / 12 (= Hoch) | `city_ambient_people.gd`, `city_exploration_crowd.gd` |
| Stadt: Fassadendetail | aus | 14 Häuser, 75 m | 28, 115 m | 36, 145 m | `city_surface_microdetail.gd` |
| Stadt: Detailmodule | aus | LOD1, 75 m | LOD0, 100 m | LOD0, 130 m | `city_exploration_detail_adapter.gd` |
| Stadt: Figurenfeinschliff | aus | aus | high | very_high | `city_character_detail.gd` |
| Region: Streamingringe, Detailpersonen | 0/1/3, 16 | 1/2/4, 32 | 1/3/5, 48 | 2/4/6, 72 | `world_stream_plan.gd` |
| Schlacht: Nah-/Mittelgrenze | 13/43 m | 18/48 m | 25/67 m | 35/90 m | `valley_scene.gd` |
| Menü-Effekte | Stufe 0 | 1 | 2 | 2 | `imperial_fx.gd` |

### Lücken gegenüber D-034 (vorher)

1. **Hoch und Sehr hoch unterschieden sich am Desktop kaum**: gleiches Pixelbudget, MSAA, Sonnen-Atlas,
   Kaskaden, Vegetationsanteil, Statisten-Obergrenze; Unterschiede nur Schattenreichweite, LOD-Schwellen,
   Reichweiten – und ein 30-FPS-Limit für Sehr hoch auch am PC.
2. **Texturauflösung** wird von keinem Profil gesteuert; Texturkompression fehlt fast vollständig.
3. **Beleuchtung/Schatten**: kein Schattenfilter-, kein Punktlichtschatten-, kein Lichtbudget-Schalter;
   keine AO in irgendeinem Profil; Glow nur als ungenutztes Datenfeld.
4. **Vegetationsdichte und Menschenmenge** enden bei Hoch (100 % bzw. 12 von 12 Einträgen); Sehr hoch hat
   keine zusätzlichen Instanzen, weil die Inhalte fehlen.
5. **Fold7-Zuordnung widerspricht D-034**: Code und `docs/31_fold7_high/FOLD7_GRAPHICS_TARGET.md`
   empfehlen für Adreno 830 **Hoch** (UI: „Fold7-Grafikziel: Hoch · 60 FPS“), D-034 definiert
   **Ausgewogen** als nachhaltig spielbares Fold7-Profil. Nicht eigenmächtig geändert (Abschnitt 7).

## 3. Profilmatrix nachher (implementiert, Engine-Schalter)

Fett = durch diese Arbeit neu oder geändert. Ausgewogen behält jeden vorherigen Wert
(geprüft in `tests/render_profile_test.gd`).

| Bereich | Leicht | Ausgewogen | Hoch | Sehr hoch | Wirkung im Compatibility-Renderer |
| --- | --- | --- | --- | --- | --- |
| Sonnenschatten-Atlas | 1024 | 2048 | 4096 | **8192** | ja |
| Sonnenschatten-Filter | **hart** | soft_low (wie bisher) | **soft_medium** | **soft_high** | siehe Funktionsprobe |
| Punktlicht-/Fackelschatten-Atlas | **0 (keine)** | **2048, 8 Plätze** | **4096, 24 Plätze** | **8192, 88 Plätze** | siehe Funktionsprobe |
| Punktlichtschatten-Filter | **hart** | **soft_low** | **soft_medium** | **soft_high** | siehe Funktionsprobe |
| Lichtbudget (Gruppe `profile_lights`): Licht blendet aus ab / über | **18 m / 6 m** | **30 m / 10 m** | **48 m / 14 m** | **70 m / 20 m** | ja (Engine-Distanz-Fade) |
| Schatten des Punktlichts bis | **–** | **16 m** | **28 m** | **45 m** | ja |
| Anisotrope Filterung | **2×** | 4× (wie bisher) | **8×** | **16×** | nur Materialien mit anisotropem Filter (Dorfboden) |
| Umgebungsverdeckung (SSAO) | aus | aus | **an, medium, halbe Auflösung** | **an, high, volle Auflösung** | ja (4.7.2: Forward+ und Compatibility, nicht Mobile) |
| Mesh-LOD-Schwelle, Pixelbudget, MSAA, Sonnenreichweite | unverändert | unverändert | unverändert | unverändert | ja |
| Dichte-Hook `density.vegetation` | 0,22 | 0,6 | 1,0 | **1,4** | Talvegetation liest den Hook; >1 erst mit zusätzlich erstellten Instanzen wirksam |
| Dichte-Hook `density.crowd` | 0,34 (4) | 0,67 (8) | 1,0 (12) | **1,5 (18 angefordert)** | Stadtmenge liest den Hook; Decke = 12 erstellte Einträge |
| Dichte-Hook `density.props_range` | 0,6 | 1,0 | 1,5 | 1,9 | Datenvertrag für Reichweiten; noch kein Verbraucher |
| Texturpaket | vorbereitet (`half`) | Originale | Originale | Originale | Paketmechanik, siehe 5.3 |

Anwendung: `RuntimeDisplay.apply_quality()` → `RenderProfile.apply_viewport()` (Root-Viewport und
globale RenderingServer-Schalter), ein `EnvironmentWatcher` setzt AO auf dem jeweils aktiven Environment
(auch nach Szenenwechsel; eine Szene kann mit Meta `render_profile_unmanaged` widersprechen oder mit
`ssao_look` eigene AO-Lookwerte liefern), `node_added` konfiguriert später erzeugte Lichter der Gruppe
`profile_lights`. Die Lookdev-Branch setzt im Dorf denselben Sonnenfilter-Wert je Profil (gleiche
Zuordnung hart/soft_low/soft_medium/soft_high), es gibt also keinen Widerspruch.

<!-- MEASURED -->

## 5. Ultra: Zielbild und Weg dorthin

Ziel (D-050): PC-nahe Darstellung auf leistungsfähigen Android-Geräten, Maßstab 30 Bilder/s bei voller
Bildqualität (Referenz und Quellen in `TECHNIQUE_RESEARCH.md`, Abschnitt 6).

| Baustein | Compatibility | Mobile | Forward+ | Stand |
| --- | --- | --- | --- | --- |
| Sonnenschatten 8192, soft_high, 4 Kaskaden, 110 m | ja | ja | ja | implementiert, getestet |
| Fackelschatten 8192 / 88 Plätze, soft_high | ja | ja (+ PCSS) | ja (+ PCSS) | implementiert, getestet |
| SSAO high, volle Auflösung | ja | **nein** | ja | implementiert, getestet |
| Glow | vereinfacht | ja | ja | Prototyp |
| SSIL, SDFGI/VoxelGI, volumetrischer Nebel, SSR | nein | nein | ja | Prototyp (nur Forward+) |
| TAA / FSR 2.2 | nein | nein | ja | Prototyp (nur Forward+) |
| SMAA | nein | ja | ja | Prototyp |
| Sonnen-PCSS (Sonnenscheibe 0,53°) | nein | nein | ja | Prototyp |
| Gebackene, gerichtete Lightmaps + Reflection Probes | ja | ja | ja | **offen**: braucht gespeicherte Szene mit UV2 |
| Decals (Schmutz, Radspuren, Blut) | nein | ja | ja | offen |
| Zeitlicher Upscaler (GSR 2 / Arm ASR) | nein | eigener CompositorEffect | FSR 2.2 vorhanden | offen, nach Gerätemessung |

Der Ultra-Prototyp ist die Variante `ultra` der Vergleichsharness (`tests/render_comparison.gd`,
Konstante `ULTRA`): auf dem Ultra-Profil wird je Renderer alles zugeschaltet, was dort Bildqualität
bringt. Er verändert keine Spieleinstellung und keine Lookwerte; die Bilder stehen in
`RENDERER_COMPARISON.md`.

Reihenfolge, die sich aus Recherche und Bildern ergibt:

1. **Gebackene gerichtete Lightmaps und Reflection Probes** für Dorf und Stadt. Einziger GI-Weg, der in
   allen drei Renderern und auf dem Telefon bezahlbar ist. Voraussetzung: statische Geometrie als
   gespeicherte Szene mit UV2 exportieren (Valdora entsteht heute zur Laufzeit aus Skripten, dort kann
   Godot nicht backen).
2. **Gerätemessung** Compatibility gegen Mobile gegen Forward+ auf dem Fold7 mit dem Modus `views`
   der Grafikprobe (`tools/render/fold7_render_bench.py`).
3. Erst danach: Ultra auf Vulkan (Mobile oder Forward+) umstellen und einen zeitlichen Upscaler wählen.

## 6. Rendererwahl je Profil auf Android

Godot legt den Renderer beim Start fest; ein laufender Prozess kann ihn nicht wechseln. Umgesetzt ist
deshalb eine Wahl **für den nächsten Start**, in einem einzigen APK:

- `project.godot` setzt `application/config/project_settings_override="user://render_override.cfg"`.
- Jedes Profil nennt in `quality_profiles.json` unter `render.renderer` seinen Wunschrenderer.
  `RenderProfile.request_renderer()` schreibt die Override-Datei (bzw. löscht sie, wenn der Wunsch dem
  Projektstandard entspricht) und meldet `restart_required`.
- Heute verlangen **alle vier Profile `gl_compatibility`** (D-033). Ein Wechsel ist dann nur noch eine
  Datenänderung.

Empfehlung (gilt erst nach der Gerätemessung, D-033):

| Profil | Renderer heute | Kandidat nach Messung | Begründung |
| --- | --- | --- | --- |
| Leicht | Compatibility | Compatibility | läuft auch ohne Vulkan; geringster Grundaufwand |
| Ausgewogen (Fold7) | Compatibility | Compatibility, sofern Mobile nicht messbar schneller ist | nachhaltiges Spielen, SSAO möglich; Mobile hätte kein SSAO |
| Hoch | Compatibility | Mobile | PCSS-Fackelschatten, SMAA, Decals, 10-Bit-Farbe ohne Banding; SSAO-Verlust durch gebackene AO/Lightmaps ausgleichen |
| Ultra | Compatibility | Forward+ mit 30 Bildern/s und Upscaling, Rückfall Mobile | nur Forward+ hat SSIL, SDFGI, volumetrischen Nebel, TAA/FSR 2, Sonnen-PCSS, SSS |

Bedingungen für den Wechsel eines Profils:

1. Messung auf dem Gerät mit denselben Ansichten: Bildzeit p50/p95, GPU-Zeit, Draw Calls, Speicher,
   mindestens 15 Minuten Dauerlauf ohne thermischen Einbruch.
2. Bildvergleich je Ansicht ohne Regression (Banding, Schattenfehler, fehlende Effekte).
3. Rückfall: Scheitert Vulkan beim Start, fällt Godot auf OpenGL zurück
   (`rendering/rendering_device/fallback_to_opengl3`, Standard an); das Spiel muss dann die
   Override-Datei löschen und das Profil auf Compatibility-Werte setzen.
4. Der Wechsel wird dem Spieler als „Neustart nötig“ angezeigt; ohne Neustart bleibt der laufende
   Renderer aktiv und das Profil nutzt nur dessen Funktionen (`RenderProfile.supports()`).

## 7. Messharness

| Messgröße | Quelle | Ort |
| --- | --- | --- |
| Bildzeit p50/p95/max | Zeit zwischen `frame_post_draw` | `render_bench.gd` `measure()` |
| CPU-/GPU-Renderzeit | `viewport_get_measured_render_time_cpu/gpu` | dito; fehlt die GPU-Zeit, steht `null`, nie 0 |
| Draw Calls, Primitive, Objekte (sichtbar und Schattenpass) | `Viewport.get_render_info` | dito |
| Textur-, Puffer-, Videospeicher | `RenderingServer.get_rendering_info` | dito |
| Prozessspeicher (RSS) | `/proc/self/status` | dito (Linux, Android) |
| Engine-Zustand je Bild (Renderer, Treiber, Profil, Kamera, Sonne, Lichter, Environment) | `engine_state()` | D-038-Metadaten in jedem Bericht |
| Geladene Modelle/Texturen mit SHA-256 | `loaded_assets()` | Bericht `*-report.json` |

Desktop: `tools/render/compare_renderers.py` (drei Renderer, Software). Gerät: Grafikprobe Modus `views`
über `tools/render/fold7_render_bench.py` (nicht ausgeführt, kein Gerät angeschlossen).
Schaukasten (D-052): `--showcase` rendert die gemeinsame Kameraliste
`prototype/assets/rendering/showcase_cameras.json`; `tools/render/showcase_compare.py` baut daraus
Vorher/Nachher-Bögen zweier Quellstände.

## 8. Offene Punkte und Entscheidungen des Auftraggebers

1. **Fold7-Zuordnung:** D-034 und D-052 nennen Ausgewogen als Fold7-Profil; Code und Oberfläche empfehlen
   für Adreno 830 weiterhin Hoch („Fold7-Grafikziel: Hoch · 60 FPS“, `fold7_quality_policy.gd`).
   Nicht eigenmächtig geändert, weil die bisherige Empfehlung auf früheren Gerätedaten beruht.
2. **Rendererwechsel** für Hoch und Ultra: erst nach Gerätemessung (D-033).
3. **Lightmap-Bake:** Export der statischen Dorf-/Stadtgeometrie als Szene mit UV2; Backen braucht eine
   GPU-Maschine mit Godot-Editor.
4. **Texturpakete:** Mechanik und Werkzeug sind vorhanden (`build_texture_package.py`,
   `RenderProfile.mount_texture_package`); die Pakete selbst wurden auf dieser Maschine nicht gebaut.
5. **Dichte über 100 %** (Vegetation 1,4, Menge 1,5 für Ultra) wirkt erst mit zusätzlich erstellten
   Inhalten.
