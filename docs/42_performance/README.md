# IMPERATHEN – Laufzeitprofil und Optimierung (26.11.2026)

Branch `perf/runtime-optimization-20261126`, Basis `fix/youth-sole-slab-calibration-20261125` (89e735d).
Engine Godot 4.7.2-stable, Renderer `gl_compatibility`.

> **Aussagegrenze.** Alle Zahlen stammen aus einem Linux-Cloud-Container (4 vCPU):
> CPU-Messung headless (Skripte, Physik, Animation laufen vollständig, ohne Rasterung),
> Render-Zähler unter xvfb + Mesa llvmpipe. Sie sind **Desktop-/Softwarerenderer-Werte und nur
> relativ zwischen zwei Quellständen vergleichbar**. Es gibt hier kein Android-Gerät; nichts davon
> ist auf dem Galaxy Z Fold7 bestätigt.

## Ergebnis

**Status: WIP – Messung abgebrochen (Kontingent).** Gemessen (Dorf, je 7 Läufe, bester Lauf, Desktop headless):

| Szene/Profil | Frame Ø vorher | nachher | Δ | p95 vorher | nachher | Δ |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| village/low (Leicht) | 6,99 | 5,38 | −23 % | 12,47 | 10,55 | −15 % |
| village/balanced (Ausgewogen) | 7,34 | 7,08 | −4 % | 13,22 | 12,48 | −6 % |
| village/high (Hoch) | 7,28 | 6,90 | −5 % | 13,03 | 12,14 | −7 % |
| village/very_high (Sehr hoch) | 7,35 | 7,41 | +1 % | 13,39 | 13,14 | −2 % |

Nur Leicht liegt klar über dem Rauschband (≈±10 %); die exakten Änderungen in Ausgewogen/Hoch/Sehr hoch
sind gemessen, aber **nicht signifikant nachgewiesen**. Stadt/Distrikt/Tal: nur Basis mit 5 Läufen
(`evidence/profile-before-other.json`) und ein früherer 3-Lauf-Vergleich (`evidence/profile-*-run1.json`,
Abweichungen ±25 % ohne Codeänderung = Rauschen). **Fehlt:** Nachher-Lauf Stadt/Distrikt/Tal mit 5
Wiederholungen, Render-Zähler-Pass (xvfb), Vergleichsaufnahmen Leicht, volle Suite und Motion-Gate auf
dem Endstand. Basis-Suite 89e735d: alle 83 Gruppen grün; Motion-Gate Basis: 581 Blocker.

## Werkzeuge (implementiert, getestet)

| Datei | Zweck |
| --- | --- |
| `prototype/tests/runtime_profile_harness.gd` | Startet eine Szene über den echten Spielfluss (`main.tscn`), fester Seed 20261126, `--fixed-fps 60`, deterministische Gehbewegung je Frameindex. Misst je Frame Wandzeit, `Performance`-Monitore, Draw Calls, Primitive, Objekte, Nodes, Physik; Szenenzählung (Materialien, MeshInstances, MultiMesh, Sichtweitenbereiche, Lichter, Skelette, Physikkörper, Speicher); Mikrobenchmarks des Domänenschritts. Modus `attributed` misst `_process`/`_physics_process` je Skriptdatei. Optional `--capture=` für Vergleichsbilder. |
| `tools/perf/runtime_profile.py` | Matrix Szene × Profil, Wiederholungen (Median und bester Lauf), attributierter Lauf, optional Render-Zähler (`--render`/`--render-only`). Schreibt `profile-<label>.json` und `.md`. |
| `tools/perf/compare_profiles.py` | Vorher/Nachher-Tabelle aus zwei Ergebnisdateien. |

Szenen: `village` (Valdora First Play: neues römisches Leben, Eröffnungen übersprungen, Spielsteuerung
aktiv, 44 Bewohner), `city` (freie Stadterkundung aus dem Hauptmenü), `district` (begehbarer
Marktdistrikt `city_support_district.tscn`), `valley` (Talgefecht-Demo, Schlacht läuft).
Profile: `low` (Leicht), `balanced` (Ausgewogen), `high` (Hoch), `very_high` (Sehr hoch / „Ultra“).

Reproduktion:

```bash
G=/home/user/tools/godot/Godot_v4.7.2-stable_linux.x86_64
export GODOT_SILENCE_ROOT_WARNING=1 IMPERATHEN_ISOLATED_TEST=1
python3 tools/perf/runtime_profile.py --godot $G --label after --out /tmp/perf --repeat 5
python3 tools/perf/runtime_profile.py --godot $G --label render --out /tmp/perf --render-only
python3 tools/perf/compare_profiles.py /tmp/perf_before/profile-before.json /tmp/perf/profile-after.json
```

Methodische Hinweise:

- `Performance.TIME_PROCESS`/`TIME_PHYSICS_PROCESS` sind in Godot das **Maximum der letzten Sekunde**,
  nicht der Wert des aktuellen Frames; maßgeblich ist deshalb die eigene Frame-Wandzeit.
- Der Harness hebt nur die Bildratenbegrenzung des Profils (30/60) auf, damit Kosten statt Wartezeit
  gemessen werden. Alle anderen Profilwerte bleiben aktiv.
- Der Container ist verrauscht (gleicher Quellstand: bis ±25 % in kleinen Szenen). Verglichen wird
  daher der **beste von 5–7 Läufen**; Unterschiede unter ≈10 % gelten als nicht nachgewiesen.
- Der attributierte Modus ruft die Callbacks selbst auf; er dient der Kostenverteilung, nicht der
  Gesamtzeit.

## Gemessene Hotspots (Basis 89e735d, village/balanced, Desktop headless)

| Hotspot | Messung | Einordnung |
| --- | --- | --- |
| `village_person.gd` `_process` (44 Figuren) | ≈3,3–4,0 ms/Frame; davon Fuß-IK `plant_world_feet` ≈2,2 ms, prozedurale Pose ≈1,0 ms; 29–31 Figuren in LOD 3 | Dauerlast, größter Einzelposten |
| UI-/Welt-Refresh (`main._refresh`, alle ≈0,12 s) | ≈7 ms Spitze: `village_life_world.sync_state` ≈3,1 ms (davon `_sync_actor` ≈2,5 ms, rekursive Kollisionssuche ≈0,45 ms), `_ui_state` ≈1,8 ms, `game_ui.update_state` ≈1,7 ms | erzeugt die p95-Spitzen |
| `world_model.advance()` | ≈3,5–4,8 ms je Aufruf (10 Hz, im Kampf 60 Hz); zwei vollständige `_validate_state` à ≈1,1 ms, Kopie 0,22 ms, Simulation ≈0,9 ms (Wirtschaft 0,40, Beobachtung 0,17, Leben 0,15) | im Kampf ≈3,5 ms je Physiktakt |
| `game_world.navigation_view()` | `Childhood.view()` jeden Frame, ≈0,22 ms/Frame | Kartenanzeige |
| LOD-Wechsel `village_person._reload` | ≈15 ms je Wechsel, ≈3 Wechsel/s beim Gehen durchs Dorf | Ruckler, offen (siehe unten) |
| Stadt / Distrikt / Tal | 0,6–1,5 ms/Frame CPU; `city_exploration` 0,3 ms, `valley_scene` 0,5–1,0 ms | unkritisch auf CPU-Seite |

## Umgesetzte Änderungen

1. **Vorab-Validierung memoisiert** (`world_model.gd`, exakt): `advance()` und `execute()` prüfen den
   Ausgangszustand erneut mit `_validate_state()`. Diese Funktion ist rein; ist der Inhalt seit der
   letzten bestandenen Validierung unverändert (`Dictionary.hash()`, 0,017 ms statt 1,18 ms), wird
   die Wiederholung übersprungen. Jede Änderung (Position, Beobachtung, externe Schreibzugriffe) ändert
   den Hash und löst die volle Prüfung aus. Die Prüfung des neuen Kandidaten bleibt unverändert.
   Mikromessung: 3,40 → 2,82 ms je Schritt bei stehender Figur (z. B. im Faustkampf mit 60 Hz).
   Restrisiko: Eine 32-Bit-Hashkollision (≈2·10⁻¹⁰ je geändertem Zustand) überspränge nur die
   Wiederholungsprüfung; die Kandidatenprüfung läuft weiterhin.
2. **Kollisionskörperliste gecacht** (`village_life_world.gd`, exakt): statt bei jedem Refresh
   `find_children("*","CollisionObject3D")` über ≈480 Nachfahren wird die Liste nur nach
   `node_added`/`node_removed` im eigenen Teilbaum neu aufgebaut. Gleiche Körper, gleiche Schichten.
3. **Kapitelansicht der Karte gecacht** (`game_world.gd`, exakt): `Childhood.view()` ist eine reine
   Funktion des Zustands und wird nur bei geändertem Inhalt neu berechnet.
4. **Profilgebunden – nur „Leicht“** (`village_person.gd`, `quality_profiles.json`
   `far_actor_foot_contacts: false`): Bewohner in LOD 3 (im Profil Leicht ab ≈16,5 m Kameraabstand)
   lösen keine weltfesten Fußkontakte mehr; ihre Füße folgen der authored/prozeduralen Pose.
   Spielerfigur, Gefährte und LOD 0–2 sind nie betroffen; Ausgewogen, Hoch und Sehr hoch bleiben
   bildgleich. Dies **ändert das Bild** (mögliches leichtes Fußgleiten in der Ferne) und ist hier
   ausdrücklich dokumentiert; Vergleichsaufnahmen siehe unten.
5. **Texturimport korrigiert** (siehe Abschnitt Texturen): Globus, Talboden und Dorfgesichter.

Geprüft und **verworfen**, weil ohne messbaren Gewinn: Beschränkung der Knochenabfrage in
`plant_world_feet` auf die gelesenen Beinknochen (0,2 ms der 2,2 ms liegen dort; kein Effekt) und eine
geänderte Räumung des LOD-Szenencaches (halbierte `load()`-Aufrufe, gleiche Zeit, da Cachetreffer).
String-/Dictionary-Lookups in der IK machen nur ≈10 % aus; ein Umbau des Bewegungscodes lohnt nicht.

Vergleichsaufnahmen für Änderung 4 (Leicht): **noch nicht erstellt** (`--capture=` im Harness vorhanden).

## Texturen und Android-Import

Projektweit ist `textures/vram_compression/import_etc2_astc=true` gesetzt. Prüfung aller 609
Textur-Importdateien unter `prototype/assets`:

- 602 stehen auf `compress/mode=0` (verlustfrei = unkomprimiert im Videospeicher, 32 bpp),
  7 (Dorfboden) auf VRAM-Komprimierung. Die Godot-Dokumentation beschreibt verlustfrei als
  artefaktfrei, aber mit deutlich höherem Videospeicher als VRAM-Komprimierung (meist Faktor 4–6)
  ([Godot: Importing images](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)).
  Auf Mobilgeräten ist Speicherbandbreite besonders energieintensiv
  ([Arm: ASTC](https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/astc-does-it---part-ii-how-to-use-it),
  [Android: Texturen optimieren](https://developer.android.com/games/optimize/textures)).
- Gemessene Qualität (PSNR gegen das verlustfreie Original, Godot `Image.compress`, 23 Stichproben):
  **ASTC 4×4** (Android, `high_quality=true`) 49,6–88 dB, eine feine Rinden-Normalmap 31,8 dB;
  BPTC (Desktop) 44–56 dB; **ETC2** (Android-Standard bei `high_quality=false`) nur 21–50 dB.
  Wenn umgestellt wird, dann nur mit `high_quality=true`.
- **Behoben** (eindeutige Fehler, 14 Dateien): `assets/atlas/earth.jpg` – der Globus-Shader verlangt
  `filter_linear_mipmap_anisotropic`, die Textur hatte keine Mipmaps; `assets/terrain/earth_basecolor.png`
  (gekachelter Talboden, keine Mipmaps → Flimmern und unnötige Bandbreite);
  `assets/village_characters/faces/*.webp` (3D-Gesichter ohne Mipmaps). Jetzt Mipmaps + VRAM
  hohe Qualität (ASTC 4×4 / BPTC). Gemessen: ASTC 57,5 dB (Boden), 52,5–53,5 dB (Gesichter),
  49,9 dB (Globus). Mipmaps verbessern zugleich die Bildruhe in der Distanz.
- **Nicht umgestellt, offen:** die übrigen 3D-Texturen (versionierte: 36 in `assets/characters`,
  15 Waffen, 4 Stadtfiguren; dazu ≈250 beim GLB-Import extrahierte, nicht versionierte Texturen in
  `assets/characters`, `world_expansion`). Gründe: (a) Ein frischer Import erzeugt dann ASTC **und**
  BPTC und würde nach Messung (≈2,7 s je 2K-Textur und Format, Einzelthread laut
  `import/use_multiple_threads=false`) den Import deutlich über das 120-s-Zeitlimit der Prüfgruppe
  `import` in `tools/check_prototype.py` heben; (b) extrahierte GLB-Texturen werden über die
  Szenen-Importoptionen gesteuert, nicht über eigene versionierte `.import`-Dateien; (c) die
  Motion-Gate-Quellprüfung erfasst die Importeinstellungen extrahierter Texturen. Empfehlung an die
  Asset-/CI-Verantwortlichen: Umstellung mit `high_quality=true` gemeinsam mit einem gecachten
  `.godot/imported`-Verzeichnis in CI oder einer begründeten Neubewertung des Import-Zeitlimits.
- 2D-Porträts und UI-Grafiken bleiben verlustfrei ohne Mipmaps (korrekt für UI).

## Verbleibende Hotspots für andere Zuständigkeiten

| Ort | Messung | Vorschlag |
| --- | --- | --- |
| `prototype/scripts/ui/game_ui.gd` `update_state()` (HUD-Team) | ≈1,7 ms je Refresh, alle 0,12 s | nur geänderte Teilbereiche aktualisieren; Text-/Layout-Neuaufbau vermeiden |
| `main.gd` `_ui_state()` | ≈1,8 ms je Refresh: tiefe Kopie des Zustands + vier Ansichten (`VillageLife`, `VillageEconomy`, `Childhood`, `CombatActions`) | Ansichten nur bei geänderter Revision; Wirtschaftsansicht wird in `village_life_world.sync_state` zusätzlich ein zweites Mal berechnet |
| `village_life_world._sync_actor` | ≈2,5 ms je Refresh für ≈15 Bewohner (`Behavior.view`, `refresh_lod`, Beschriftung) | Bewohner ohne Zustandsänderung überspringen |
| `village_person._reload` (LOD-Wechsel) | ≈15 ms je Wechsel, ≈3/s beim Gehen; davon `_play()` ≈2 ms (erste prozedurale Pose auf neuem Skelett) und Nachladen nicht mehr gecachter Stufen | Stufen der aktiven Familien per `ResourceLoader.load_threaded_request` vorladen oder Instanzen poolen; ändert Speicher bzw. Wechselzeitpunkt, daher Entscheidung der Figuren-/Speicherverantwortlichen |
| Fuß-IK ferner Figuren in Ausgewogen/Hoch/Sehr hoch | ≈1,5 ms/Frame (balanced) | gleiche Option wie in Leicht; nur nach Bildfreigabe |
| `world_model` Validatoren | `NpcBehavior.validate` 0,43 ms, `VillageEconomy.validate` 0,16 ms, `VillageLife.validate` 0,13 ms je Aufruf | Konstantarrays statt Literal je Iteration, `roster().keys()` einmal |
| `prototype/scripts/battle/*`, `tribal_world.gd` | nicht verändert (andere Agenten); `valley_scene.gd` 0,5–1,0 ms/Frame | kein dringender CPU-Hotspot gemessen |

## Nicht durchgeführt

- Keine Messung auf Android/Fold7, keine Temperatur-, GPU-Zeit- oder Akkuwerte.
- Keine GPU-Optimierung von Draw Calls/MultiMesh am Dorfbild (Dorf-Look gehört anderen Agenten);
  Render-Zähler sind dokumentiert, nicht verändert.
