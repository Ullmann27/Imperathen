# Valdora Look-Development – Licht, Atmosphäre, Grading, Materialien (26.11.2026)

Branch `feat/village-lookdev-20261126` (Basis ffbe3ad). Bezug: Masterhandbuch 3.0, AAA Visual Quality Directive
(GAME_DIRECTION_2026-11-26_C.md, Punkt 3) und D-050 (filmisch, warmes glaubwürdiges Sonnenlicht, reiche aber natürliche
Farbgebung, Kontaktschatten, Tiefendunst, nichts flach oder ausgewaschen). Referenzbilder (Valhalla, Ryse) dienen nur als
Qualitätsmaßstab; Inhalte, Figuren, UI und Look werden nicht kopiert.

Status-Begriffe: **umgesetzt** = im Code, **getestet** = automatischer Test grün, **gerendert** = in Godot-Renderbildern
geprüft, **gerätebestätigt** = auf dem Fold7 gemessen. Gerätebestätigung: **keine** (kein Gerät; DEVICE_BLOCKED).

## 1. Rahmen

- Ausgeliefert bleibt `gl_compatibility` (project.godot); kein Rendererwechsel. Renderer-Vergleich und Engine-Profil-Schalter
  (Ultra, Vulkan, LightmapGI) liegen beim Render-Profil-Agenten; dieser Branch liefert die Look-Werte.
- Alle Look-Werte und der Kamerasatz liegen in **einer Datendatei**:
  `prototype/assets/village/look/look_values.json` (Tonemapper, Dunst, Glow, vier Jahreszeiten, Sonnenbahn, Nacht/Mond,
  Wetter, Feuerarten, Innenraumlicht, Kameras). Profil-Schalter bleiben in `prototype/assets/quality_profiles.json`
  (`look`: Schattenkaskaden/-filter, Himmels-Radiance, Luftperspektive, Innenraumlicht, Lichtschächte).
- Code: `scripts/rendering/village_look.gd` (Licht, Himmel, Dunst, Grading, Innenraum, Tageszeit, Wetter, Feuer),
  `scripts/rendering/village_surfaces.gd` + `scripts/world/village/lime_plaster.gdshader` (Materialien),
  Texturgenerator `tools/world/village_look_textures.py` (prozedural, ohne Fremdquellen).
- Nachweis: `prototype/tests/village_look_review.gd` (echter Spielpfad main.tscn → neues Leben → Valdora; vier feste
  Einstellungen start/path/conversation/overview; je Profil Draw Calls, Primitive, Objekte, Schattenprimitive,
  Textur-/Buffer-/Videospeicher, Frame-Zeiten) und `prototype/tests/village_look_test.gd` (Gruppe `village_look`).

## 2. Was der Compatibility-Renderer in 4.7.2 tatsächlich kann (gemessen)

Pixel-Differenz-Probe (320×180, Mesa llvmpipe): ACES/AgX/Filmic, Belichtung, Adjustments, Glow, Himmels-/BG-Umgebungslicht,
exponentieller, Tiefen-, Höhen- und Luftperspektiven-Nebel sowie die Soft-Shadow-Filterqualität verändern das Bild.
Ohne Wirkung: `shadow_blur`, `light_angular_distance` (kein PCSS), `fog_sun_scatter`. Volumetrischer Nebel, SDFGI und SSIL
sind laut Godot-Dokumentation nur Forward+ ([Environment][godot-env]). SSAO ist laut Dokumentation in Compatibility
vorhanden; die Probe zeigte nur sehr kleine Änderungen, Ergebnis siehe Abschnitt 6. `INSTANCE_CUSTOM` einer MultiMesh
lieferte in Compatibility schwarze Gräser (Variation wird daher aus der Instanzposition gehasht).
LightmapGI wird in Compatibility seit 4.3 gerendert, aber nur mit Vulkan gebacken ([PR 85120][pr85120],
[LightmapGI-Doku][godot-lightmap]).

## 3. Umgesetzt

**Sonne und Himmel.** Warme, tiefe Nachmittagssonne je Jahreszeit (Energie ≈ 2 statt 0,46; Frühling/Sommer klar,
Herbst bedeckt und dunstig, Winter tief und kalt). Umgebungslicht kommt aus der Himmels-Radiance (oben blau, unten
Landfarbe über den Cubemap-Pass des Himmels-Shaders) statt aus einer flachen Farbe. Himmel mit Sonnenscheibe, warmem
Horizontdunst auf der Sonnenseite und warm angestrahlten Wolkenrändern; der Radiance-Pass nutzt feste Wolkendichte, damit
Umgebungslicht nicht mit der Wolkendrift flackert.

**Tiefendunst.** Exponentieller Nebel mit Luftperspektive (Nebelfarbe aus dem Himmel hinter jedem Pixel, passt daher zum
Horizont) plus leichter Bodennebel; Dichte je Jahreszeit.

**Tonemapping, Belichtung, Grading.** ACES (white 6). Keine pauschale Kontrast-/Sättigungsanhebung (Directive C:
„nicht lediglich Helligkeit, Kontrast oder Sättigung“). Belichtung je Jahreszeit 0,86–0,95; gemessene Clipping-Anteile
siehe Abschnitt 6. Augenadaption beim Betreten eines Hauses (Belichtung ×1,3, sanft überblendet).

**Innenräume.** Ist die Kamera in einem Haus, sinkt der Himmelsanteil des Umgebungslichts auf 28 % (warm-dunkles
Restlicht), und zwei schattenlose Lichter folgen dem Haus: warmes Bodenlicht hinter der Schwelle und kühles Himmelslicht
unter dem Rückfenster (Fensterlage aus der Wandgeometrie von `frontier_house.glb` vermessen). Sonnenflecken durch Tür
und Fenster kommen aus der vorhandenen Schattenkarte. Hoch/Sehr hoch: additive, weich auslaufende Lichtschächte entlang
des Sonnenlichts durch Tür und Vorderfenster als Ersatz für volumetrisches Licht.

**Tageszeit, Wetter, Feuer.** `set_time_of_day(stunden)`: Sonnenbogen für ≈45,6° N je Jahreszeit, rotes schwaches Licht
in Horizontnähe, Dämmerungshimmel, nachts kühler Mond, dunkler Himmel, angepasste Belichtung, warme Fensterglut aller
Häuser und flackerndes Herdlicht im Haus. `set_weather(clear|overcast|rain|mist)`. `add_fire_light(…, candle|torch|hearth)`
mit gemeinsamer Flackeranimation. Noch treibt keine Spieluhr die Tageszeit (Standard bleibt der Nachmittag).

**Materialien.** Kalkputz mit Kellenstruktur, Haarrissen, Regenläufen, Abplatzungen bis zum Bruchstein, Normal-,
Rauheits- und Kavitätskarte, Makrovariation und aufsteigender Feuchte/Spritzschmutz am Sockel (innen schwächer).
Flache Requisitenfarben erhalten objektgebundene Triplanar-Abnutzung. Wege: verdichtete Erde mit Splitt, Kieseln,
Trittspuren und feuchten Senken; Wiesen: Grasnarbe ohne helle Sprenkel. Texturspeicher: 5,8 MiB (VRAM-komprimiert mit
Mipmaps, ETC2 und S3TC gleich groß), ersetzt 0,7 MiB.

**Vegetation (Übergabe an den Vegetations-Branch).** Dichtere gemischte Ränder, Windböen, Blumen, Wandgras,
Baumkronen im Wind; Budget je Profil im Commit 9b802cd.

## 4. Techniken und Quellen (Recherche D-050)

- **Filmisches Tonemapping.** ACES: hoher Kontrast, filmähnliche Kurve, Entsättigung heller Werte; AgX: hält den Farbton
  heller Farben am besten ([Godot Environment][godot-env]). AgX stammt aus Troy Sobotkas Display-Transform und ersetzt in
  Blender 4 Filmic ([darktable AgX][darktable-agx], [AgX-Herleitung][agx-blog]). GTA V nutzt laut Frame-Analyse einen
  filmischen Uncharted-2-Operator und addiert Bloom vor dem Tonemapping ([Courrèges, GTA V Graphics Study][gtav]).
- **Grading-LUT.** Godot wendet `adjustment_color_correction` (Texture3D-LUT oder 1D-Verlauf) **nach** dem Tonemapping an;
  Reihenfolge DoF → Auto-Exposure → Glow → Tonemap → Adjustments ([Godot Environment][godot-env]). Filament backt
  Tonemapping und Grading in eine LUT ([Godot-Proposal AgX, Diskussion][godot-agx]). Eine dezente Split-Tone-LUT
  (warme Lichter, leicht kühle Schatten) wird hier gemessen, nicht pauschal Sättigung.
- **Belichtung.** GTA V misst die mittlere Leuchtdichte auf ¼ Auflösung, adaptiert langsam und von dunkel nach hell
  schneller ([Courrèges][gtav]); physikalisch basierte Kamera/Belichtung bei Frostbite
  ([Lagarde & de Rousiers 2014][frostbite]). Godot rät, Helligkeit über `tonemap_exposure` vor dem Tonemapping zu steuern.
- **Himmel und Dunst.** Hillaires Sky/Aerial-Perspective-LUTs skalieren über LUT-Auflösung und Samples bis auf Mobile und
  erlauben Wetter-Wechsel ohne teure Neuberechnung ([Hillaire 2020][hillaire]); RDR2 integriert Himmel, Wolken und
  Nebel in eine Atmosphärenlösung ([Bauer, SIGGRAPH 2019 Advances][rdr2]). In Compatibility steht davon die
  Luftperspektive des Godot-Nebels zur Verfügung; daran orientieren sich die Werte.
- **Gebackenes Licht.** LightmapGI mit Richtungsinformation und Shadowmask für statische Szenen; günstig auf schwacher
  Hardware ([Godot LightmapGI][godot-lightmap]); Rendering in Compatibility seit 4.3, Bake nur mit Vulkan ([PR 85120][pr85120]).
  Für das statische Valdora (Häuser, Innenräume) der größte verbleibende Hebel für glaubwürdiges indirektes Licht.
- **Kontaktschatten.** Screen-Space-Schatten für Sonnenlicht in Days Gone ([Bend Studio][bend]); Unreal bietet Contact
  Shadows pro Licht ([Unreal Contact Shadows][ue-contact]). GTA V: vier Kaskaden in einer 1024×4096-Karte, tiefenbewusst
  weichgezeichnet ([Courrèges][gtav]). In Compatibility gibt es keine Screen-Space-Schatten; hier: enge Bias-Werte,
  Soft-Filter je Profil, Kavität/Feuchte im Material und (falls messbar wirksam) SSAO.

## 5. Kamerasatz (gemeinsam mit dem Render-Profil-Agenten)

`look_values.json` → `cameras`: start (Spielkamera nach neuem Leben, Familienhaus, Kamera (-10,86 | 2,12 | 12,95)),
path (Spieler (0,9 | 0 | 12,5), Yaw 0, Pitch 0,24), conversation (Julia; Spieler 1,35 m entfernt auf freiem Boden,
Kamera 1,15 m hinter / 0,52 m neben / 1,62 m hoch, FOV 44), overview (Auge (31 | 17,5 | 33) → Ziel (-4 | 1 | -9)).
Auflösungen 1280×720 und 1384×1536 (Fold7-Innenseitenverhältnis), Profile balanced und very_high.

## 6. Messungen

Wird mit den Vorher/Nachher-Aufnahmen ergänzt (Commit, Profil, Renderer, Speicher, llvmpipe-Zeiten nur relativ).

[godot-env]: https://docs.godotengine.org/en/4.6/classes/class_environment.html
[godot-lightmap]: https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/using_lightmap_gi.html
[pr85120]: https://github.com/godotengine/godot/pull/85120
[godot-agx]: https://github.com/godotengine/godot-proposals/discussions/7545
[darktable-agx]: https://docs.darktable.org/usermanual/development/en/module-reference/processing-modules/agx/
[agx-blog]: https://thecodecofficial.github.io/Blog/AgES
[gtav]: https://www.adriancourreges.com/blog/2015/11/02/gta-v-graphics-study/
[frostbite]: https://blog.selfshadow.com/publications/s2014-shading-course/
[hillaire]: https://diglib.eg.org/handle/10.1111/cgf14050
[rdr2]: https://advances.realtimerendering.com/s2019/index.htm
[bend]: https://www.bendstudio.com/blog/inside-bend-screen-space-shadows/
[ue-contact]: https://dev.epicgames.com/documentation/en-us/unreal-engine/contact-shadows-in-unreal-engine
