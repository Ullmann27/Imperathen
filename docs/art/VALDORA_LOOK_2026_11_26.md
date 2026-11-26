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

## 6. Vorher/Nachher-Aufnahmen und Messungen (D-038)

Bilder und Zähler liegen in `docs/art/valdora_look_2026_11_26/`:

- `before_after_1280x720_balanced.jpg`, `before_after_1280x720_very_high.jpg`: start, path und overview, links vorher,
  rechts nachher, **identische Kamera** (Kameramatrix in beiden JSON-Dateien gleich).
- `after_conversation_1280x720.jpg`: Gesprächseinstellung nur nachher. Eine Vorher-Aufnahme mit derselben Kamera
  **fehlt** (die Vorher-Läufe haben den Spieler anders platziert); sie ist offen.
- `before_ffbe3ad_1280x720_look.json`, `after_9e24ec7_1280x720_look.json`: Zähler je Einstellung und Profil.
  `png_sha256.txt`: Prüfsummen der Einzelbilder (die PNGs selbst liegen nur im Arbeitsverzeichnis des Laufs).

| Angabe | Wert |
|---|---|
| Quellstand vorher / nachher | ffbe3ad / 9e24ec7 (spätere Commits dieses Branches sind **nicht** in diesen Bildern) |
| Befehl | `xvfb-run … godot --path prototype --resolution 1280x720 --script res://tests/village_look_review.gd ++ <out> <label> 3` |
| Spielpfad | main.tscn → neues Leben → Valdora, Frühling, Nachmittags-Voreinstellung, klares Wetter |
| Profile | balanced (Ausgewogen) und very_high (Ultra) |
| Renderer / Treiber | gl_compatibility, OpenGL 4.5 Core, Mesa 25.2.8 llvmpipe (LLVM 20.1.2, Software) |
| Auflösung | 1280×720, Render-Skalierung 1,0 |
| Licht | Sonne −29°/−38°, Energie 2,0, `#ffdcb0`; Himmels-Umgebungslicht 0,52; ACES, Belichtung 0,88 |
| Look-Texturen (sha256, 16 Stellen) | lime_plaster albedo 171d1c3531a1ecfa, mask c59414455ebcc216, normal fec3771b2f9b075f; meadow_sod afeffb3604d92ef4 / f147e355b89ac14b; trodden_earth 527198c6938ba0c7 / 01f16dbf69dea6b1; wear_detail 1c525a5f4ae733a9 / d7345eefc7adfef1 |
| Hausmodell | frontier_house.glb 2fb464187ecec393 |
| Fehler im Lauf | nachher keine Review-Fehler; in beiden Läufen fehlt `gear_roman_signum_1.glb` (veralteter Import-Cache des Arbeitsverzeichnisses), ein Ausrüstungsteil ist daher nicht im Bild |

Zähler vorher → nachher (Median aus 3 Bildern; Zeiten sind llvmpipe-Software-Zeiten unter wechselnder Maschinenlast,
**keine** Geräteleistung und untereinander nur grob vergleichbar):

| Einstellung | Profil | Draw Calls | Primitive (Tsd.) | Schattenprimitive (Tsd.) | Videospeicher MiB | Sekunden je Bild |
|---|---|---|---|---|---|---|
| start | balanced | 635 → 674 | 428 → 446 | 511 → 513 | 246 → 256 | 9,5 → 21,0 |
| start | very_high | 955 → 1363 | 530 → 620 | 987 → 1338 | 313 → 327 | 13,7 → 31,9 |
| path | balanced | 1033 → 1055 | 617 → 639 | 461 → 445 | 232 → 240 | 7,4 → 38,8 |
| path | very_high | 2504 → 2783 | 785 → 945 | 1649 → 1935 | 302 → 316 | 15,6 → 27,9 |
| overview | balanced | 1275 → 1280 | 721 → 731 | 336 → 322 | 159 → 168 | 10,7 → 31,9 |
| overview | very_high | 2550 → 2849 | 885 → 1051 | 1190 → 1385 | 218 → 232 | 11,3 → 32,5 |

Die Nachher-Läufe liefen bei deutlich höherer Maschinenlast (Last 10–14 statt etwa 4); der Zeitzuwachs ist deshalb
nicht dem Look zuzuordnen. Belastbar sind Draw Calls, Primitive und Speicher: balanced +1 bis +6 % Draw Calls und
+9 MiB Videospeicher; Ultra +11 bis +43 % Draw Calls (dichtere Vegetation, Lichtschächte) und +14 MiB.

Helligkeitsverteilung der Nachher-Bilder (Anteil Pixel mit einem Kanal ≥ 0,985):

| Einstellung | balanced | very_high |
|---|---|---|
| start | 0,10 % | 0,04 % |
| path | 5,12 % | 0,01 % |
| overview | 3,49 % | 0,00 % |
| conversation | 13,32 % | 0,01 % |

**Sichtbare Verbesserungen:** gerichtetes warmes Sonnenlicht mit lesbaren Gebäude- und Baumschatten statt flacher
Ausleuchtung; Himmelslicht in den Schatten; Tiefendunst zu den Hügeln; Kalkputz mit Struktur statt gekachelter
Flecken; dunklerer, gerichteter Innenraum mit Sonnenfleck an der Tür; dichtere Wegränder.

**Verbleibende Fehler (ehrlich):**

1. **Ausgewogen überstrahlt sonnenbeschienenen Putz, Haut und helle Requisiten** (bis 13 % ausgefressene Pixel,
   gelb-orange Farbverschiebung), Ultra nicht. Wahrscheinliche Ursache, noch nicht durch einen Gegenlauf belegt: Ohne
   Glow wendet der Compatibility-Renderer das Tonemapping je Lichtdurchgang im 8-Bit-Ziel an (die Schattensonne wird
   additiv gezeichnet), mit Glow dagegen einmal am Ende aus dem HDR-Puffer. Nächster Schritt: auf balanced den
   HDR-Nachbearbeitungspfad erzwingen (Glow mit Intensität 0) oder die Belichtung dort senken, und die Kosten messen.
   Ein Abstimmlauf dazu (`glow0`, AgX, Belichtung 0,7) war beim Abschluss noch in der Warteschlange.
2. Innenraum (start) auf balanced sehr dunkel (Mittelwert 0,22); die Putzabplatzungen wiederholten sich als Muster.
   Für das Muster gibt es eine Shader-Korrektur in einem späteren Commit (nicht gerendert).
3. Heller Fleck des Fensterlichts an der Rückwand (Kegel streift die Wand); Winkel liegt jetzt als
   `interior.window_angle` in den Look-Werten, der Wert ist noch nicht nachgestellt.
4. Amphoren und einige Requisiten bleiben einfarbig-flach; helle Baumkrone im Vordergrund der Übersicht.
5. Tageszeit, Wetter, Nacht und Feuerlicht sind nur headless getestet, **nicht gerendert**.
6. Keine Aufnahmen in 1384×1536, keine für low/high, keine Gerätemessung.

## 7. Status beim Abschluss (26.11.2026, Wrap-up)

| Teil | umgesetzt | getestet | gerendert |
|---|---|---|---|
| Sonne, Himmelslicht, Dunst, ACES, Profile | ja | `village_look_test` grün | ja (Abschnitt 6), balanced überstrahlt |
| Kalkputz, Abnutzung, Wege/Wiese | ja | ja | ja |
| Innenraumlicht, Lichtschächte | ja | ja | ja (start), Feinabstimmung offen |
| Tageszeit, Mond, Fensterglut, Wetter | ja | headless | **nein** |
| Feuerlicht: Schmiedeherd, Türfackeln, Budget je Profil (1/3/5/7) | ja (wip) | headless, 43 Prüfungen | **nein** |
| Putz: Abplatzungen nur in verwitterten Zonen, nie im Wohnraum | ja (wip) | Shader nicht geladen geprüft | **nein** |
| SSAO, Split-Tone-LUT | Schalter vorhanden, aus | – | Wirkung nicht belegt |
| Spieluhr treibt Tageszeit | nein (Schnittstelle `set_time_of_day`) | – | – |
| Gerätebestätigung Fold7 | nein | – | – |

Befehle: `python3 tools/check_prototype.py --godot <godot> --only village_look` bzw.
`godot --headless --path prototype --script res://tests/village_look_test.gd` (43 Prüfungen, 0 Fehler, Stand db068d6);
Aufnahmen in kurzen Läufen: `… --script res://tests/village_look_review.gd ++ <out> <label> 2 balanced start,path`.

Nächste Schritte: (1) Überstrahlung auf balanced beheben und nachrendern; (2) Gesprächs-Vorheraufnahme mit gleicher
Kamera; (3) Nacht-, Dämmerungs-, Wetter- und Fackelaufnahmen, danach Fackelposition und Lichtstärken abstimmen;
(4) AgX gegen ACES im HDR-Pfad vergleichen; (5) 1384×1536 und Profile low/high; (6) LightmapGI für die statischen Häuser.

Für den Render-Profil-Agenten bleiben stabil: `cameras.path`, `cameras.overview`, `cameras.conversation`, `night`, `fire`
in `look_values.json` sowie `set_time_of_day` und `add_fire_light`.

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
