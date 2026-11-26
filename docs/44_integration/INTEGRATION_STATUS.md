# Integrationsstand `integ/reference-candidate-20261126` (PR #101)

Stand: 26.11.2026. Diese Datei führt die Integration des Referenzkandidaten:
welcher Arbeitsbranch zu welchem PR gehört, bis zu welchem Commit er
integriert ist, was geprüft wurde und was blockiert ist. Sie wird nach jedem
Merge-Stapel fortgeschrieben.

Regeln der Integration:

- „Merge“ heißt hier `git merge` in diesen Branch. Kein PR wird auf GitHub
  gemergt oder freigegeben, nichts geht nach `main`.
- Integriert werden geprüfte Stände. Hat ein Branch am Kopf einen
  `wip(...)`-Commit mit Code, wird der letzte nicht als WIP markierte Commit
  integriert; reine WIP-Dokumentation wird mitgenommen.
- Kein Test und kein Schwellwert wird abgeschwächt. Kein Reparatur-Commit aus
  #88–#95 wird fallen gelassen.
- Es gibt hier kein Fold7-Gerät. Alle Aussagen gelten für Headless-Läufe auf
  dem Entwicklungsrechner (Godot 4.7.2, `gl_compatibility`); Geräteleistung
  ist nicht belegt.

## 1. Branch → PR → integrierter Commit

Basis der PRs: `#87` = `fix/youth-sole-slab-calibration-20261125`,
`#95` = `fix/meshy-cloak-seam-20261126`, `#101` = dieser Branch.

| Bereich | Branch | PR | PR-Basis | Kopf (zuletzt gesehen) | Integriert bis | Stand |
|---|---|---|---|---|---|---|
| Basis | `fix/youth-sole-slab-calibration-20261125` | #87 | Unified | `89e735d` | `89e735d` | integriert (Ausgangsstand) |
| Reparatur | `fix/youth-hand-tunic-separation-20261126` | #88 | #87 | `6478fef` | – | **nicht enthalten**, siehe 4.1 |
| Reparatur | Stapel `fix/frontier-soldier-sole-lift` … `fix/meshy-cloak-seam-20261126` | #89–#95 | gestapelt | `df15a2e` | `df15a2e` | integriert (Ausgangsstand) |
| Gameplay | `feat/world-calendar-20261126` | #98 | #87 | `d1ca5ec` | `d1ca5ec` | integriert (Ausgangsstand) |
| Gameplay | `feat/germanic-tribes-ai-20261126` | #99 | #87 | `82367a8` | `6a703d1` | Nachlauf offen, kommt über #110 |
| Gameplay | `feat/troops-command-core-20261126` | #100 | #87 | `ee57ec6` | `73b2f85` | Nachlauf offen; `ee57ec6` ist in #110 enthalten, siehe 4.2 |
| Gameplay | `integ/world-state-20261126` | #110 | #87 | `9f14a11` | – | nicht gemergt: Abbruch der Integration vor dem Merge, siehe 4.2 |
| Gameplay | `feat/melee-combat-core-20261126` | #111 | #87 | `2bfbf99` | – | vom Autor fertig gemeldet (Einzelläufe grün, keine Suite, kein Gate, keine Renders); nicht gemergt, weil #110/Truppen davor fehlen |
| Gameplay | `feat/formation-movement-20261126` | #112 | #87 | `2c6c34d` | – | pausiert, siehe 4.3 |
| Gameplay | `feat/i01-three-cups-slice-20261126` | #104 | #87 | `04c3ae0` | `1fbde53` | integriert (Stapel 1); `1281f89` (I-03 als Besorgung, vom Autor geprüft) und WIP `04c3ae0` offen |
| Gameplay | `fix/village-raid-approach-20261126` | #103 | #87 | `8d94d0c` | `3c8da91` | integriert (Stapel 1), **zwei Gruppen rot**, siehe 3.2; WIP `3bc34cc` offen |
| Gameplay | `feat/raid-conspiracy-investigation-20261126` | #113 | #87 | `6c89d40` | – | reiner Datenentwurf, siehe 4.4 |
| Gameplay | `feat/motion-gate-blockers-20261126` | #102 | #95 | `d48107f` | `d48107f` | integriert (Stapel 1) |
| Grafik | `feat/village-lookdev-20261126` | #108 | #87 | `8c9231c` | `7a78e41` | integriert (Stapel 1), WIP-Kopf offen |
| Grafik | `feat/render-profiles-study-20261126` | #109 | #87 | `6b52a3c` | `18de593` | integriert (Stapel 1), WIP-Statusnotiz offen |
| Grafik | `feat/roman-hud-20261126` | #105 | #87 | `a34bc1c` | `93536c5` | integriert (Stapel 1), WIP-Kopf offen |
| Grafik | `feat/youth-civil-clothing-20261126` | #114 | #95 | `db02dc4` | – | WIP, Godot-Pfade ungetestet |
| Grafik | `fix/city-ground-walls-20261126` | #106 | #87 | `fa8e7a9` | `df0b7d8` | integriert (Stapel 1), WIP-Kopf offen |
| Grafik | `fix/village-backdrop-terrain-20261126` | #107 | #87 | `b56b1ca` | `cc68146` | integriert (Stapel 1), WIP-Kopf offen |
| Grafik | `feat/germanic-warrior-families-20261126` | #115 | #95 | `58185a1` | – | pausiert, siehe 4.5 |
| Audio | `feat/voices-lipsync-sfx-20261126` | eigener PR der Sitzung (noch keiner offen) | #87 | `e6d2f6b` | – | nicht geprüft, nicht gemergt (Probe-Merge konfliktfrei) |
| Leistung | `perf/runtime-optimization-20261126` | eigener PR der Sitzung | – | noch nicht gepusht | – | – |
| Welt | `feat/living-city-20261126` | eigener PR der Sitzung | #101 | noch nicht gepusht | – | – |
| Welt | `feat/colosseum-plaza-20261126` | eigener PR der Sitzung (noch keiner offen) | #101 | `3741574` | – | WIP-Commits, nicht geprüft, nicht gemergt |
| Grafik | `feat/vegetation-20261126` | #116 | #87 | `00582ea` | – | WIP: 15 Impostor-Prüfungen der eigenen Gruppe rot, nicht gerendert |
| Grafik | `feat/people-detail-realism-20261126` | #117 | #95 | `01af2fb` | – | WIP: keine Assets neu gebaut; `frontier_people` scheitert dort (viermal „Parameter material is null“ beim Freigeben eines Bewohnerkörpers). Nicht mergen |
| Grafik | `feat/house-interiors-detail-20261126` | #118 | #87 | `e257587` | – | WIP: letzter Lauf der eigenen Gruppe 23 Fehler, Kit einen Build zurück |
| Grafik | `feat/meshy-assets-shops-20261126` | #119 | #101 | `f1e2a3d` | – | WIP: kein Godot-Lauf der neuen Skripte und Tests |
| Grafik | `feat/architecture-families-20261126` | – | – | noch nicht gepusht | – | – |
| Doku | `docs/handover-gpt-fable-20261126`, `docs/game-direction-20261126` | #96, #97 | Unified | – | – | reine Dokumentation, nicht Teil dieses Kandidaten |

## 2. Merges in diesen Branch

### Ausgangsstand `f770025`

Reparaturstapel #87 und #89–#95 (`df15a2e`), Kalender #98 (`d1ca5ec`),
Stämme #99 (`6a703d1`), Truppen #100 (`73b2f85`).

### Stapel 1 (26.11.2026)

| Nr. | Merge-Commit | Quelle | Konflikte und Auflösung |
|---|---|---|---|
| 1 | `1dd54f4` | `feat/motion-gate-blockers-20261126` @ `d48107f` (#102) | keine |
| 2 | `a595e19` | `fix/village-raid-approach-20261126` @ `3c8da91` (#103) | `quality/motion_contract.json`, Liste `runtime_scripts`: beide Seiten behalten (`npc_social_memory.gd` des Kandidaten, `raid_route.gd` und `raider_strike.gd` des Überfalls) |
| 3 | `f4c36dc` | `feat/i01-three-cups-slice-20261126` @ `1fbde53` (#104) | `prototype/tests/mission_bridge_data_test.gd`: Kandidat prüft das aktuelle Speicherschema (`WorldModel.SCHEMA_VERSION`, Weltkalender), I-01 prüft die Migration Drehbuch v3 → v4 mit I-01 „legacy“. Beide Erwartungen stehen jetzt in einer Prüfung; der feste Wert `schema_version == 5` der I-01-Seite wurde durch die Konstante ersetzt, weil der Kandidat bereits Schema 6 schreibt |
| 4 | `5d790f5` | `feat/roman-hud-20261126` @ `93536c5` (#105) | keine |
| 5 | `6956c12` | `fix/city-ground-walls-20261126` @ `df0b7d8` (#106) | keine |
| 6 | `d64fbd7` | `fix/village-backdrop-terrain-20261126` @ `cc68146` (#107) | keine |
| 7 | `6845ab9` | `feat/village-lookdev-20261126` @ `7a78e41` (#108) | `village_scenery.gd`, Kopfkonstanten: beide behalten (`Hills`, `WATER_LEVEL`, `SPRING_ROUNDING_M` des Geländes; `Look`, `Grove` des Looks). Die geschlossene Hügel-Landform und die neuen Raine bleiben beide |
| 8 | `2de618b` | `feat/render-profiles-study-20261126` @ `18de593` (#109) | keine |

## 3. Prüfungen

### 3.1 Ausgangswerte

| Stand | Suite | Motion-Gate | Quelle |
|---|---|---|---|
| `df15a2e` (#95) | – | BLOCKED, 351 Blocker | CI |
| `f770025` (#101) | – | BLOCKED, 361 Blocker | CI |
| `f770025` (#101) | 95 von 95 Gruppen bestanden | BLOCKED, 359 Blocker, 61 gemessene Assets | lokaler Volllauf der Leitung, 26.11. 07:11–07:47 UTC |
| nur #87 | – | BLOCKED, 587 Blocker | CI |

Das Gate ist auf jedem Stand blockiert; die Zahl ist der Vergleichswert. Der
CI-Job `real-city-arm64-qa-apk` ist deshalb auf jedem Branch rot.

### 3.2 Stapel 1

**Dieser Stand ist nicht grün.** Die Integration wurde auf Anweisung der
Leitung (Kontingent des Auftraggebers) vor dem Abschluss beendet. Der letzte
vollständig geprüfte Stand bleibt `f770025` (95 von 95 Gruppen, Gate 359).

Geprüft wurde der Stand nach Merge 8 (`2de618b`) plus der Korrektur aus 3.3,
in Einzelstapeln auf der leichten Sperrspur (Godot 4.7.2 headless, nach
Reimport, 26.11. 08:10–08:27 UTC). Kein vollständiger Suite-Lauf, **kein
Motion-Gate-Lauf** auf diesem Stand.

| Ergebnis | Gruppen |
|---|---|
| bestanden (28 Gruppen) | `domain`, `raid_route_world_a`, `raid_route_world_b`, `raid_route_world_d`, `i01_slice`, `i01_flow`, `team_b_integration`, `locomotion_regression`, `village_backdrop`, `mission_bridge_data`, `roman_hud`, `render_profile`, `render_bench_views`, `integration`, `village_people`, `village_look`, `village_childhood`, `childhood_integration`, `regional_terrain`, `band1_alignment`, `chapter_abilities`, `opening_flow`, `ui`, `village_scenery`, `regional_workers`, `frontier_integration`, `runtime_display_lifecycle`, `fold7_graphics_policy` sowie die Python-Tests `tests.motion_quality_gate_test`, `tests.frontier_tunic_seam_test`, `tests.attack_lead_foot_test` (23 Tests) |
| **rot (3)** | `raid_route_world_c`, `raid_strike_timing`, `camera_collision` |
| Zeitüberschreitung, nicht aussagekräftig (1) | `landscape` (120 s; auf `f770025` 1 s) |
| nicht gelaufen | `action_world`, `world`, `main_scene`, `figure_gallery`, `youth_mocap`, alle übrigen Gruppen der Suite, `motion_measurement` |

Befunde zu den roten Gruppen (Diagnose aus Log und Quelltext, **nicht** durch
einen Wiederholungslauf bestätigt):

- `raid_route_world_c` – „The childhood chapter reaches its released night
  raid through real commands“. Der Testhelfer `_play_childhood_to_night` des
  Überfall-Branches spielt die Kindheit mit der alten Befehlsfolge; mit I-01
  beginnt sie jetzt mit dem Morgen (`i01_*`-Stufen). Die zwei D-040-Prüfungen
  derselben Gruppe fallen nur als Folge davon (0 Überfallereignisse). Nötig:
  der Helfer muss die `i01_*`-Stufen spielen wie `village_childhood_test.gd`
  (und nach `1281f89` die `i03_*`-Stufen über `tests/i03_support.gd`).
- `raid_strike_timing` – „A standing player sees repeated swings (0)“. Das
  Testfeld `FIELD = (40, -75)` liegt seit dem Gelände-Branch im Hang der
  festen Hügel-Landform (Fuß bei z ≈ -66,8). Nötig: das Feld auf freien,
  ebenen Boden legen (z. B. z ≈ -58, zwischen Palisade und Hügelfuß); die
  Prüfungen selbst bleiben unverändert.
- `camera_collision` – 48 Prüfungen ohne Fehler, aber „1 resources still in
  use at exit“. Ursache nicht untersucht; auf `f770025` trat die Zeile nicht
  auf, sie kommt also aus Stapel 1.

CI der einzelnen PRs (Stand 08:20 UTC): `headless-regressions` ist auf #104
und #105 rot (`locomotion_regression_test.gd:45`, siehe 3.3; der I-01-Kopf
`1281f89` behebt es selbst). `real-city-arm64-qa-apk` ist wie erwartet wegen
des Motion-Gates rot bzw. lief noch. Übrige Jobs von #102–#105 grün oder noch
in Arbeit; #106–#119 nicht mehr ausgewertet.

### 3.3 Korrektur auf dem Integrationsbranch

I-01 hält die Eröffnung an der offenen Morgenentscheidung an; „Überspringen“
trifft sie nicht. Vier Aufrufer aus anderen Branches setzten noch voraus, dass
Überspringen ins Spiel führt, und treffen jetzt die Entscheidung `i01_yard`
über den regulären Weg, so wie es der I-01-Branch in `action_world_test.gd`
tut:

- `prototype/tests/locomotion_regression_test.gd` (Gruppe besteht damit),
- `prototype/scripts/rendering/render_bench.gd` (`render_bench_views` besteht),
- `prototype/scripts/ui/android_graphics_probe.gd`, Modus „views“ (von keinem
  Test ausgeführt),
- `prototype/tests/village_look_review.gd` (Review-Werkzeug, nicht ausgeführt).

## 4. Blockiert oder zurückgestellt

### 4.1 #88 fehlt im Kandidaten

`6478fef` (Hände der Jugend-Figur pro UV-Insel von der Tunika trennen) ist ein
Seitenast auf #87 und nicht Teil des linearen Stapels #89–#95. Der Kandidat
`f770025` enthält ihn nicht, obwohl der Titel von #101 „#87–#95“ nennt. Der
Commit ändert nur `tools/characters/retarget_accad_youth.py` und
`tools/characters/youth_skin_polish.py`; ein Probe-Merge ist konfliktfrei. Er
wirkt erst, wenn die private Jugend-Figur neu gebaut wird. Übernahme mit dem
nächsten Stapel vorgesehen; der Neuaufbau der privaten Laufzeitdateien ist
Sache des Besitzers der Figur.

### 4.2 Weltzustand (#110), Truppen-Nachlauf (#100), Nahkampf (#111)

#110 (`9f14a11`) vereint #98/#99/#100 auf einer Uhr, enthält den Truppenkopf
`ee57ec6` und ersetzt die einfachen Merges dieser drei PRs; der Autor nennt
`world_state` mit 202 Prüfungen auf dem gemergten Truppenkopf. Ein Probe-Merge
auf den Stand nach Stapel 1 hat drei Konflikte, alle nur nebeneinander
stehende Zeilen (`opening_story.gd` und `village_life.gd`: Preloads beider
Seiten; `tools/check_prototype.py`: Gruppe `world_state`). Zu klären beim
Merge: der Überfall-Branch verlangt per Test (D-040), dass der Nachtüberfall
keinen Stamm speichert oder zeigt; #110 bucht den Überfall I-10 auf eine
Reitergruppe der Stammeswelt.

Reihenfolge für die Fortsetzung: `1281f89` (I-01/I-03) → Korrektur der zwei
Überfall-Tests → #88 → #110 → #111 (`2bfbf99`, nur ein Konflikt in
`quality/motion_contract.json`) → Audio. Keiner dieser Merges wurde begonnen.

### 4.3 Formation (#112)

Pausiert. Der Kopf-Commit ist ein ungetesteter Merge des Truppenstands, und
die Rang-/Platz-Zuordnung passt nicht zur expliziten Platzvergabe des
Truppen-Branches (D-043). Das ist eine Entwurfsentscheidung, keine
Merge-Frage; nicht integriert.

### 4.4 Verschwörung (#113)

Eine JSON-Datei, die kein Code liest und kein Test prüft. Konfliktfrei, aber
ohne Prüfung; nicht integriert, bis ein Datenvertrag oder ein Test existiert.

### 4.5 Germanische Kriegerfamilien (#115)

Pausiert (D-056). Nur Generator, keine Exporte, Durchdringungsgrenze nicht
eingehalten, kein Godot-Render. Nicht integriert.

### 4.6 WIP-Köpfe

- HUD `e6656f6` (Dorfverwaltungstafel), Stadt `fa8e7a9` (feste Stände,
  Kollisions-Audit, Routentest), Look `db068d6` (Schmiede- und Fackellicht):
  werden übernommen, sobald die Autoren sie als geprüft melden oder die
  Gruppen der Branches am Kopf bestehen.
