# Übergabe IMPERATHEN – Integration Menü + Kapitel I (Stand 24.11.2026)

Dieses Dokument beschreibt den Stand des Branches `handoff/sol-20261124` für die Weiterarbeit (z. B. mit ChatGPT 6.2 Sol). Es fasst nur zusammen, was im Repository und in den Prüfläufen belegt ist. Unsichere Punkte sind mit „Hierzu liegen mir keine gesicherten Daten vor.“ markiert.

## 1. Branches, Pull Requests, Commits

| Rolle | Branch | Commit | PR |
|---|---|---|---|
| Basis „Build 7“ | `integration/motion-combat-cc0-20261124` | `7c3194db13acef2702e5e92336b94e9be41c7b58` | – |
| Menü, Trailer-Vorspann, Menümusik | `ui/roman-menu-intro-20261124` | `d9a251d4aa0fa5520c8e81370989ba500bb0c4e1` | [#49](https://github.com/Ullmann27/Imperathen/pull/49) |
| Kapitel I an Band 1 angeglichen | `chapter1/band1-alignment-20261124` | `38344fffb703f64978d4f6904f542e1912de668d` | [#50](https://github.com/Ullmann27/Imperathen/pull/50) |
| **Integration (dieser Branch)** | `handoff/sol-20261124` | siehe Git-Historie: Merge #49, Merge #50, Übergabe-Doku | PR gegen `integration/motion-combat-cc0-20261124` |

`main` (`e9e1bb16`) enthält nur die README und ist **nicht** die Arbeitsbasis. Weiterarbeit startet von `handoff/sol-20261124`.

### Merge-Protokoll
1. `git merge --no-ff origin/ui/roman-menu-intro-20261124` auf Build 7: konfliktfrei.
2. `git merge --no-ff origin/chapter1/band1-alignment-20261124`: konfliktfrei. Git hat `tools/check_prototype.py` automatisch zusammengeführt; beide Zweige hatten dort Prüfungen ergänzt. Geprüft: Die Liste enthält jetzt `band1_alignment`, `chapter_abilities`, `band1_expansion` (aus #50) und `roman_menu` (aus #49). Es waren keine manuellen Konfliktlösungen nötig.

## 2. Build- und Testbefehle

Engine: Godot **4.7.2** (Renderer `gl_compatibility`, CI pinnt 4.7.2). Projektordner: `prototype/`.

```bash
# Python-Prüfungen (Payload, Kampagnenbibel, Kapitel-Fähigkeiten, APK-Inhalt)
python3 -m unittest discover -s tests -p 'android_*_test.py'

# Engine-Prüfungen headless (alle GDScript-Tests, inkl. roman_menu, band1_*, chapter_abilities)
python3 tools/check_prototype.py --godot /pfad/zu/godot-4.7.2 --keep-going --report artifacts/engine-checks

# Einzeltest, z. B.
godot --headless --path prototype --script res://tests/band1_expansion_test.gd

# Android-APK (wie CI, braucht SDK, JDK 17, Export-Templates 4.7.2 und einen Debug-Keystore, der NICHT im Repo liegt)
python3 tools/build_android_prototype.py --godot "$GODOT_BIN" --sdk-root "$ANDROID_HOME" --java-home "$JAVA_HOME" \
  --template-dir "$TEMPLATE_DIR" --keystore "$KEYSTORE" --keystore-user imperathen-debug --abi arm64-v8a --output artifacts/IMPERATHEN-arm64.apk
python3 tools/validate_android_apk.py --apk artifacts/IMPERATHEN-arm64.apk --sdk-root "$ANDROID_HOME" --report artifacts/arm64-apk-validation.json
```

CI: `.github/workflows/android-prototype.yml` führt Unittests, `check_prototype`, APK-Bau (arm64 + x86_64-Emulator) und Desktop-Export aus. Weitere Workflows: `story-validation.yml`, `cc0-motion-import.yml`, `npc-regressions.yml`, `visual-quality.yml` u. a.

### Prüfergebnis dieses Branches (24.11.2026, lokal, Godot 4.7.2 headless)
- Python: 153/153 OK (`python3 -m unittest discover -s tests -p 'android_*_test.py'`).
- Engine: 61/61 PASS (`tools/check_prototype.py --keep-going`, inkl. `roman_menu`, `band1_alignment`, `chapter_abilities`, `band1_expansion`).
- APK: für diesen Merge **nicht** gebaut (kein Speicherplatz auf der Arbeitsmaschine). Zuletzt gebaut und validiert (28/28): Kapitel-I-Stand `fe8bed4` bzw. `d4549fb`.
- Bilder und Videos aus Xvfb/llvmpipe sind Software-Rendering und **keine** Leistungsmessung.

## 3. Repo-Struktur (Auszug)

| Pfad | Inhalt |
|---|---|
| `prototype/project.godot`, `main.tscn` | Godot-Projekt, Einstieg |
| `prototype/scripts/main.gd` | Spielablauf, Menü/Vorspann-Steuerung |
| `prototype/scripts/domain/world_model.gd` | Weltzustand, Befehle, Save/Load, Validierung (Schema v5) |
| `prototype/scripts/domain/` | `combat_actions.gd`, `unarmed_combat.gd`, `npc_behavior.gd`, `village_economy.gd` |
| `prototype/scripts/story/` | `village_childhood.gd` (Kindheitskette I-01 ff.), `mission_data.gd` (Loader), `chapter_abilities.gd`, `campaign_bible.gd`, `opening_story.gd`, `village_life.gd`, `frontier_chapter.gd` |
| `prototype/scripts/ui/` | `game_ui.gd` (`show_menu`), `roman_style.gd`, `imperial_intro.gd` (Vorspann), `imperial_fx.gd`, Touch-Steuerung, `village_life_panel.gd` |
| `prototype/scripts/visuals/`, `world/`, `battle/`, `tactics/`, `strategy/`, `cinematic/` | Figuren, Dorf/Gelände, Kampf, Kamera |
| `prototype/shaders/` | u. a. `intro_backdrop`, `legion_silhouette`, `roman_banner`, `torch_flame`, `menu_grade` |
| `prototype/assets/story/` | `campaign_arc.json`, `chapter1_abilities.json`, `missions/band1/` |
| `prototype/assets/ui/` | Menümusik, Cinzel-Font, Embleme, Trailer-Grafiken |
| `prototype/assets/asset_manifest.json` | Herkunft/Lizenz der Laufzeit-Assets |
| `prototype/tests/*.gd` | Engine-Tests (von `tools/check_prototype.py` aufgerufen) |
| `tests/android_*_test.py` | Python-Tests |
| `tools/` | Build, APK-Validierung, Generatoren (`tools/ui/build_menu_music.py`, `build_intro_trailer.py`, `build_imperial_emblems.py`, `render_legion_silhouettes.py`), `tools/story`, `tools/characters` |
| `art/` | Quellmodelle (Blender), Referenzen |
| `docs/` | 00–21 frühere Runden; `22_title_menu/DELIVERY.md` (Menü), `22_band1_alignment/` (Kapitel I), `23_handoff_sol/` (diese Übergabe) |
| `AGENTS.md` | verbindlicher Arbeitsauftrag und Regeln für Agenten |

## 4. Spielstand: Schema v5 mit Envelope

- `world_model.gd`: `SCHEMA_VERSION := 5`, `SAVE_FORMAT := "imperathen-offline-save"`.
- Datei-Envelope (genau diese vier Schlüssel): `{"format": "imperathen-offline-save", "format_version": 1, "payload": "<JSON-Text>", "sha256": "<sha256 von payload>"}`. Beim Laden werden Schlüssel, Format, Version, Länge und Prüfsumme streng geprüft; Abweichung = Ablehnung.
- Erweiterungen erfolgen **ohne** Schema-Sprung über `ensure`-Ableitungen aus bereits gespeicherten Fakten (Muster: `Abilities.ensure` vor der Validierung) und über versionierte Unterbereiche:
  - `village.abilities = {"version":1, "earned":[…]}`
  - Drehbuch-Brückenstand `screenplay` mit eigener Version, aktuell **v3** (`screenplay.i07_water`, Migration v2 → v3 in `village_childhood.gd`, Test `band1_expansion_test.gd`). Neue Brückenschritte brauchen v4 mit Migration nach diesem Muster.
- `village.childhood` gilt heute nur bei Alter 12 als gültig. Ein Altersübergang braucht einen eigenen Karriere-Bereich.

## 5. Missionen als Daten

- `prototype/assets/story/campaign_arc.json` (schema_version 1): alle 113 Hauptmissionen und 96 Nebenquests der Bände 1–4 mit ID, Titel, Storykern, Besetzung, Ort, `narrative_status`, `source_section`. Titel und IDs stimmen mit den Drehbüchern überein (geprüft in `docs/22_band1_alignment/ABGLEICH_I01_I09.md`).
- `prototype/assets/story/missions/band1/index.json` + **eine Datei je Mission**: `I-01, I-03, I-04, I-05, I-06, I-07, I-09.json` (schema_version 1, stabile Schritt-IDs, Feld `visits` für optionale Gespräche). Loader: `prototype/scripts/story/mission_data.gd`.
- Regeln: Schritt-IDs und Item-IDs nie umbenennen oder umnummerieren (Saves); nur anhängen.
- Noch im Code (`_screenplay_step` in `village_childhood.gd`): Brückenschritte zu I-02, I-08 und I-10 bis I-14.

## 6. Fähigkeitssystem

- Katalog `prototype/assets/story/chapter1_abilities.json`, Logik `prototype/scripts/story/chapter_abilities.gd`, Anzeige im Dorfleben-Panel.
- Drei Fähigkeiten: `ch1_look_before_force` (I-05, Deckung/Abwehrfenster länger), `ch1_price_is_promise` (I-06, Notvorrat 6 → 5 Denare), `ch1_read_tracks` (I-08, +1 Scharfsinn beim Auskundschaften). Zahlenwerte sind Ergänzungen; Band 1 nennt keine Werte.
- Erwerb aus gespeicherten Fakten, nie entfernt; unbekannte IDs oder fehlende belegte Fähigkeiten → Save abgelehnt.
- Muster für weitere Kataloge: `chapter2_abilities.json` usw. Details: `docs/22_band1_alignment/FAEHIGKEITEN_UND_SPIELZEIT.md`.

## 7. Asset-Lizenzen

- Laufzeit-Assets mit Herkunft und Lizenz: `prototype/assets/asset_manifest.json`; Übersicht und Regeln: `docs/07_legal/RIGHTS_AND_PROVENANCE.md`, `docs/20_meshy_assets/ASSET_LEDGER.md`, `docs/19_motion_combat/` (CC0-Bewegungsbibliothek), `art/hero_quality/source/LICENSE*.md`.
- Menü/Vorspann: Cinzel (SIL OFL 1.1, Lizenztext liegt bei), Menümusik und Trailer-Ton (eigene numpy-Synthese), Embleme und Shader (eigener Code), Legion-Silhouetten (Blender-Renderings der projekteigenen Rigs). Tabelle: `docs/22_title_menu/DELIVERY.md`.
- Neue Assets nur mit belegter Lizenz und Manifest-Eintrag.
- Die Drehbücher (`IMPERATHEN_Drehbuch_Band_1…4`) liegen **nicht** im Repository und dürfen nicht eingecheckt werden.

## 8. Bekannte Grenzen und offene Punkte

**Band 1 / Kapitel I**
- Spielbar: I-00 bis I-14 (teils als verdichtete Brückenschritte). Erster Durchgang laut Schätzung aus Code-Daten etwa 35–70 min (+1–2 min durch die I-07-Wasseraufgabe). Keine Messung mit Testspielern.
- Marcus fehlt in I-06, I-08, I-09 und I-15 (kein Begleit-/Dialogsystem im Kindheitsdorf).
- I-07: Der Name „Severus“ für den kranken Wachmann kommt in Band 1 nicht vor; Aurelia und die Nachricht an Cassia sind Ergänzungen.
- I-04: Silvanus begleitet nicht körperlich.
- Brückenschritte I-02, I-08, I-10 bis I-14 noch im Code statt in Missionsdateien.
- I-15 „Asche hat Namen“: nur konzipiert, kein Code. Plan aus `band1.md` (Tabelle 18, „Erlaubte Lösungsfamilien“): Brandstelle der Schmiede → Funde sichern (Pferdebeschlag, Stoffrest, Liefermarke, rotes Wachssiegel) → Vergleich bei Cassia (falls tot: Decimus) → Entscheidung bei Decimus: Beweis melden / Kopie anlegen / Spur geheim halten. Braucht Brückenstand v4.
- I-16 ff.: nicht begonnen. I-16 bis I-18 brauchen Wiederaufbau über Monate (Zeitsprung, Alter 13); I-19/I-20 brauchen Aquileia.
- Nebenquests NQ-1-01 bis NQ-1-24: nicht umgesetzt, kein Nebenquest-System. Das Drehbuch liefert je Nebenquest nur eine Vorlage (Ort, Auslöser, Lösungskorridor, Konsequenz, generische Auftraggeber-Zeile, drei Spielerantworten).
  - Pferde/Maultiere fehlen (NQ-1-01, NQ-1-16).
  - Orte „Nachbardorf“ und „Marschlager“ fehlen (NQ-1-02, -03, -05, -06, -08, -09, -11, -12, -14, -15, -17, -18, -20, -21, -23, -24).
  - Mit Valdora/Waldweg grundsätzlich machbar: NQ-1-04, -07, -10, -13, -19, -22 (Auftraggeber im Drehbuch unbenannt; Zuordnung wäre Ergänzung).

**Umfangsziel**
- Ziel: Bände 1–4 mit ≥ 90 h. Planrechnung (nicht gemessen): 113 Haupt- + 96 Nebenmissionen + Wiederholbares ≈ 76–118 h. Heute weit darunter.

**Technik, Grafik, Animation, Ton**
- Emulator- und Gerätetest stehen aus (eigenes AVD blieb „offline“). FPS auf echtem Android-Gerät: Hierzu liegen mir keine gesicherten Daten vor.
- Grafik Weg A (Feinabstimmung im `gl_compatibility`-Renderer) brachte keine eindeutige Verbesserung, nichts übernommen (`docs/22_band1_alignment/GRAFIK_WEG_A.md`). Weg B (Forward+/Mobile-Vulkan) ist nur auf echter GPU zu beurteilen.
- Finger-Rig, Schwert- und Axtkampf brauchen neue Rigs und Animationen (Blender).
- Menümusik und Trailer-Ton sind synthetisch und nur technisch geprüft (Pegel, Spektrum, Loop), nicht durch Anhören.
- Die Legion im Vorspann besteht aus 2D-Silhouetten; die Blutspur ist ein gezeichneter Effekt, keine Fluidsimulation.
- `IRON_BANNERS_Projektmappe.zip` (Projektbibel, Master-GDD, Datenmodelle) wurde nie geliefert und nicht gelesen.

## 9. Quellen außerhalb des Repos

Drehbücher Band 1–4 als `.docx` liegen bei Heinz (Band 1: „Das Feuer von Valdora“, Produktionsfassung 1.0 vom 23.11.2026). Wer weiterarbeitet, muss sie selbst bereitstellen; Fundstellen in den Doku-Dateien verweisen auf Abschnittsüberschriften, Tabellennummern und Dialogzeilennummern.
