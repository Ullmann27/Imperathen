# Technikrecherche für die Grafikprofile und das Ultra-Profil (D-050)

Stand: 26.11.2026. Engine: Godot 4.7.2-stable. Jede Aussage nennt ihre Quelle; wo eine Quelle nur
Herstellerangabe ist, steht das dabei. Nichts hiervon ist eine Messung auf dem Fold7.

## 1. Was die drei Godot-Renderer können (4.7)

Quelle: Godot-Dokumentation „Overview of renderers“ (4.7) [G1] und die Klassenreferenz des
4.7.2-Binaries (`--doctool`, lokal ausgewertet) [G2]. Dieselben Einträge prüft
`prototype/tests/render_feature_probe.gd` am laufenden Renderer (Ergebnis in `RENDERER_COMPARISON.md`).

| Funktion | Compatibility (OpenGL ES 3) | Mobile (Vulkan) | Forward+ (Vulkan) |
| --- | --- | --- | --- |
| Lichtmodell | Forward, Schattenlichter mehrpässig | Forward, ein Pass | Clustered Forward |
| Punkt-/Spotlichter | 8 je Mesh (erhöhbar) | 8 je Mesh, 256 je Ansicht | 512 je Cluster |
| PCSS Punkt-/Spotlicht | nein | ja | ja |
| PCSS Sonne | nein | nein | ja |
| LightmapGI (gebacken) | Darstellung ja | ja | ja |
| ReflectionProbe | 2 je Mesh | 8 je Mesh | unbegrenzt |
| VoxelGI, SDFGI, SSIL | nein | nein | ja |
| SSAO | ja | nein | ja |
| SSR, volumetrischer Nebel | nein | nein | ja |
| Glow | ja (vereinfachte Variante) | ja (geringerer Dynamikumfang) | ja |
| Decals, Lichtprojektoren | nein | ja (8 Decals je Mesh) | ja |
| MSAA 3D | ja | ja | ja |
| FXAA, SMAA | nein | ja | ja |
| TAA, FSR 2.2 | nein | nein | ja |
| FSR 1.0 (räumlich) | nein | nein | ja |
| Skalierung des 3D-Puffers (bilinear) | ja | ja | ja |
| Tiefenunschärfe | nein | ja | ja |
| Subsurface Scattering | nein | nein | ja |
| Farbpuffer | RGBA8 | RGB10A2 | RGBA16F |
| Debanding, Variable Rate Shading | nein | ja | ja |
| CompositorEffects (eigene Nachbearbeitung im Renderer) | nein | ja | ja |

Folgen für das Projekt:

- Compatibility rechnet die Beleuchtung auf sRGB-kodierten RGBA8-Werten ([G2],
  `rendering/renderer/rendering_method`); weiche Verläufe (Himmel, Nebel, Nacht) können deshalb
  Stufen zeigen, die Mobile (RGB10A2 + Debanding) und Forward+ (RGBA16F) nicht haben.
- Mobile hat **kein SSAO** und keine zeitliche Kantenglättung; es bringt gegenüber Compatibility
  Decals, Lichtprojektoren, PCSS für Fackeln, SMAA/FXAA, Tiefenunschärfe, VRS und 10-Bit-Farbe.
- Alles, was nach „PC“ aussieht (SDFGI/VoxelGI, SSIL, SSR, volumetrischer Nebel, TAA/FSR 2,
  Sonnen-PCSS, SSS für Haut), gibt es **nur in Forward+**. Die Dokumentation nennt Forward+ auf
  Mobilgeräten „poorly optimized“ [G1].

## 2. Vulkan Mobile gegen OpenGL auf Adreno/Mali

- Google und The Forge haben den Vulkan-Renderer von Godot 4 für Android überarbeitet; die
  veröffentlichten Änderungen senkten die GPU-Bildzeit zusammen um 10–20 % [A1].
- Arm und W4 Games fanden im Mobile-Renderer (Godot 4.4-dev, Pixel 8 Pro, Mali) als Hauptproblem
  unnötige Load/Store-Operationen der Render-Passes: MSAA-Puffer und Resolve-Ziel wurden beide in den
  Hauptspeicher zurückgeschrieben. Nach der Korrektur (PR #98670) sanken die externen Schreibzugriffe
  um etwa das 300-Fache, die Testszene lief wieder mit Bildwiederholrate [A2].
- Qualcomm empfiehlt für Adreno ausdrücklich Vulkan vor OpenGL ES, ASTC-Texturen, MSAA (2× „nahezu
  kostenlos“ auf Tile-GPUs), wenige Render-Target-Wechsel, Instancing, Dreiecke nicht kleiner als etwa
  4 Pixel, sowie geringere Renderauflösung mit Upscaling (Reihenfolge: Adreno Neural Fusion ab
  Adreno 850, dann Snapdragon GSR, dann Blit) [Q1].
- Für Standalone-XR (Quest 3, Adreno 740) gilt Compatibility in der Godot-Praxis bisher als die
  schnellere Wahl; Vulkan Mobile holt auf, veröffentlichte Adreno-Vergleichszahlen für 4.7 haben wir
  nicht gefunden (Suche 26.11.2026, Sekundärquellen). Das ist genau der Grund, warum D-033 eine
  eigene Gerätemessung verlangt.

Bewertung: Es gibt **keine belastbare veröffentlichte Zahl**, die Mobile oder Forward+ auf einem
Adreno 830 gegen Compatibility einordnet. Die Herstellerempfehlung (Vulkan) und die Godot-Praxis
(Compatibility ist auf Mobil-GPUs oft schneller) widersprechen sich; nur die Messung auf dem Gerät
entscheidet.

## 3. Upscaling: FSR, Arm ASR, Snapdragon GSR

| Technik | Art | Lizenz | In Godot 4.7.2 | Bemerkung |
| --- | --- | --- | --- | --- |
| Bilineare 3D-Skalierung | räumlich | – | alle Renderer [G3] | heutiger Weg des Projekts (Pixelbudget, adaptive 3D-Auflösung) |
| AMD FSR 1.0 | räumlich + Schärfen | MIT | nur Forward+ [G3] | braucht gute Kantenglättung davor |
| AMD FSR 2.2 | zeitlich | MIT | nur Forward+ [G3] | ersetzt TAA; für Mobil-GPUs teuer |
| Arm ASR | zeitlich, aus FSR 2.2.2 abgeleitet | MIT | nicht enthalten | Plugins für Unreal, Unity angekündigt, generische Bibliothek [R1][R2]; Arm nennt bis zu 30 % mehr Bilder/s (Herstellerangabe) |
| Snapdragon GSR 1 | räumlich, ein Pass | BSD-3 | nicht enthalten | einzelner Fragment-Shader, auch unter OpenGL ES lauffähig [S1] |
| Snapdragon GSR 2 | zeitlich, 2 Pässe + Schärfen | siehe Repository | nicht enthalten | Qualcomm nennt etwa 1 ms auf Snapdragon 8 Gen 3 (Herstellerangabe) [S2][S3] |

Folgerung:

- Unter Compatibility ist nur ein **räumlicher** Upscaler möglich (kein Bewegungsvektor-Puffer).
  GSR 1 ist ein einzelner Fragment-Shader und ließe sich als Vollbild-Pass einbauen; das ist ein
  kleines, messbares Arbeitspaket.
- Ein zeitlicher Upscaler auf dem Fold7 setzt Vulkan voraus. In Godot heißt das heute: Forward+ mit
  FSR 2.2 (vorhanden, aber für Desktop ausgelegt) oder Mobile mit einem eigenen CompositorEffect
  (GSR 2/ASR). Mobile liefert in 4.7.2 keine TAA, also auch keinen fertigen Jitter-/Bewegungsvektor-Pfad;
  der Aufwand ist deutlich größer als bei GSR 1 und gehört erst nach der Gerätemessung entschieden.

## 4. Globale Beleuchtung: LightmapGI, Reflection Probes

- LightmapGI liefert laut Dokumentation die beste Laufzeitleistung für indirekte Beleuchtung und ist für
  Mobilgeräte geeignet; es wird in **allen drei Renderern** dargestellt [G2][G4].
- `directional = true` speichert die Lichtrichtung als Spherical Harmonics: Normalmaps reagieren auf das
  gebackene Licht, statische und dynamische Objekte bekommen grobe Reflexionen; Kosten: etwas mehr
  Shaderarbeit, längeres Backen, größere Dateien [G2].
- Bikubische Filterung der Lightmaps ist Projektstandard (`rendering/lightmapping/lightmap_gi/use_bicubic_filter`) [G2].
- Dynamische Figuren erhalten indirektes Licht über Light Probes (`generate_probes_subdiv`, `LightmapProbe`) [G2].
- Shadowmask-Modus: gebackene Sonnenschatten jenseits der Echtzeit-Schattenreichweite [G2] – passt zu den
  Profil-Schattenreichweiten 24–110 m.
- **Einschränkung, die das Projekt direkt trifft:** „Lightmap baking functionality is only available in
  the editor … not suited to procedurally generated or user-built levels“ [G2]. Valdora wird zur Laufzeit
  aus Skripten aufgebaut (`game_world.gd`, `settlement_dressing.gd`); ohne eine gespeicherte Szene mit
  UV2-Kanälen lässt sich nichts backen. Das Backen selbst braucht eine GPU mit RenderingDevice
  (Forward+/Mobile-fähig) [G2].
- ReflectionProbe: 2 je Mesh in Compatibility, 8 in Mobile, unbegrenzt in Forward+; `UPDATE_ONCE` ist
  billig [G2].

Folgerung für Ultra: Gebackene, gerichtete Lightmaps plus Reflection Probes sind der einzige GI-Weg,
der auf **jedem** Renderer und auf dem Telefon bezahlbar ist. Voraussetzung ist ein Export der
statischen Dorf- und Stadtgeometrie als gespeicherte Szene mit UV2 (eigenes Arbeitspaket,
Abschnitt „Offene Punkte“ in `GRAPHICS_PROFILES.md`). Der hier gerenderte Ultra-Prototyp nutzt
deshalb als Stellvertreter SDFGI und eine zur Laufzeit gebackene VoxelGI (nur Forward+).

## 5. Sichtweite und Dichte: LOD, HLOD, Impostors

- Automatische Mesh-LOD und Sichtbereichs-HLOD (`visibility_range_*`, Überblendmodus „Dependencies“)
  sind in allen Renderern vorhanden und kombinierbar [G5]. Das Projekt nutzt beides bereits über
  `mesh_lod_threshold` und Reichweiten je Profil.
- Für große offene Szenen empfiehlt die Dokumentation LOD und Sichtbereiche vor Occlusion Culling [G2].
- Oktaeder-Impostors gibt es nur als Drittanbieter-Erweiterung mit unklarer Lizenzlage [G6]; für Bäume
  und ferne Gebäude ist ein eigener Impostor-Bake aus Blender der sichere Weg.

## 6. Referenzpunkt Red Dead Redemption (Android/iOS, Dezember 2025)

- Rockstar verlangt für Android Prozessoren ab Snapdragon 888 [RD1]; Netflix nennt zusätzlich
  Android 14, Dimensity 8200, Exynos 2200, Tensor G2 und (in einigen Sprachfassungen) Vulkan 1.2 [RD2].
- Es gibt die Grafikmodi „Fidelity“ und „Performance“ [RD3]; Fidelity ist auf 30 Bilder/s begrenzt,
  60 Bilder/s wurden nur auf iPad Pro M4/M5 berichtet [RD4].

Einordnung: Der Maßstab für Ultra ist damit **30 Bilder/s bei voller Bildqualität auf einem
Oberklasse-Chip**, nicht 60. Der Fold7 (Snapdragon 8 Elite for Galaxy, Adreno 830) liegt vier
Chip-Generationen über dieser Mindestanforderung. Das Profil Ultra hat im Projekt bereits ein
30-Bilder/s-Limit und eine adaptive 3D-Auflösung (`fold7_quality_policy.gd`).

## Quellen

- [G1] Godot 4.7, Overview of renderers – https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html
- [G2] Godot 4.7.2 Klassenreferenz (`Godot_v4.7.2-stable --doctool`): Environment, Viewport, LightmapGI,
  ReflectionProbe, Decal, VoxelGI, ProjectSettings – online: https://docs.godotengine.org/en/4.7/classes/class_lightmapgi.html
- [G3] Godot 4.7, Resolution scaling – https://docs.godotengine.org/en/4.7/tutorials/3d/resolution_scaling.html
- [G4] Godot 4.7, LightmapGI – https://docs.godotengine.org/en/4.7/classes/class_lightmapgi.html
- [G5] Godot 4.7, Visibility ranges (HLOD) – https://docs.godotengine.org/en/4.7/tutorials/3d/visibility_ranges.html
- [G6] Godot Asset Library, Octahedral Impostor LOD – https://godotengine.org/asset-library/asset/5528
- [A1] Android Developers, Godot Engine Vulkan optimization for Android – https://developer.android.com/stories/games/godot-vulkan
- [A2] Arm, Optimizing 3D scenes in Godot on Arm GPUs – https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/optimizing-3d-scenes-in-godot-on-arm-gpus
- [Q1] Qualcomm, Adreno GPU on Mobile: Best Practices – https://docs.qualcomm.com/bundle/publicresource/80-78185-2/topics/mobile_best_practices.md
- [R1] Arm Accuracy Super Resolution – https://github.com/arm/accuracy-super-resolution
- [R2] Arm, Introducing Arm Accuracy Super Resolution – https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/introducing-arm-accuracy-super-resolution
- [S1] Snapdragon Game Super Resolution (GSR 1, BSD-3) – https://github.com/quic/snapdragon-gsr
- [S2] Qualcomm, Introducing Snapdragon Game Super Resolution 2 – https://www.qualcomm.com/developer/blog/2024/10/introducing-snapdragon-game-super-resolution-2
- [S3] Snapdragon GSR Repository – https://github.com/SnapdragonGameStudios/snapdragon-gsr
- [RD1] Rockstar Support, Red Dead Redemption Android Device Support – https://support.rockstargames.com/en-US/articles/5VamcWitbDNFnFUjSBMMLq/red-dead-redemption-android-device-support
- [RD2] Netflix Hilfe, Red Dead Redemption – https://help.netflix.com/en/node/479526572184164
- [RD3] Rockstar Support, Graphics mode for Red Dead Redemption on Android / iOS – https://support.rockstargames.com/articles/4NCHWpHnBC2LIgZX6ymvcx/graphics-mode-for-red-dead-redemption-on-android-ios
- [RD4] Notebookcheck, Red Dead Redemption mobile performance tested – https://www.notebookcheck.net/Red-Dead-Redemption-mobile-performance-tested-This-is-the-best-Apple-mobile-device-to-play-it-on.1178960.0.html

Hinweis zur Belastbarkeit: [RD1] und [RD3] konnten am 26.11.2026 nur über die Suchergebnisse gelesen
werden (die Seiten antworteten mit HTTP 503); die Aussagen zu 30/60 Bildern/s stammen aus [RD4].
