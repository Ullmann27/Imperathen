# Weltkalender und Zeitarchitektur

Status: **Module, Daten und Tests implementiert; noch nicht in Weltzustand, Story oder Oberfläche eingebunden.** Grundlage sind die Vorgaben D-015 (Start 58 v. Chr., Valdora, zwölf Jahre) und D-028 (Bänder I–IV, Zeitsprünge, kein Jahr null) aus [GAME_DIRECTION_2026-11-26](../00_governance/GAME_DIRECTION_2026-11-26.md) und [GAME_DIRECTION_2026-11-26_B](../00_governance/GAME_DIRECTION_2026-11-26_B.md) sowie das Zeitmodell des Masterhandbuchs 3.0 (PDF S. 64: historischen Tag, Weltzeit, Spielzeit, Alter und Jahreszeit getrennt führen; kein stiller Sprung). Das Dynastiesystem (D-029) ist nicht gebaut; Datenmodell und Tests reichen bis 9 n. Chr. und darüber hinaus.

## Konventionen

| Größe | Darstellung | Beispiel |
|---|---|---|
| Historisches Jahr | Ganzzahl mit Vorzeichen, **0 ungültig** | −58 = 58 v. Chr., −1 = 1 v. Chr., 1 = 1 n. Chr. |
| Astronomisches Jahr | nur intern für Arithmetik | 1 v. Chr. = 0, 58 v. Chr. = −57 |
| Tag | Julianische Tageszahl (JDN), proleptisch julianisch | 15. März 44 v. Chr. = 1705426 |
| Uhrzeit | Sekunde des Tages 0–86399 | 21600 = 6 Uhr |
| Jahreszeit | meteorologisch, Januar/Februar gehören zum Winter des Vorjahres | Zug 0 = Frühling 58 v. Chr. |

Auf 1 v. Chr. folgt direkt 1 n. Chr.: `add_years(-1, 1) == 1`, `years_between(-58, 9) == 66`. Das ist dieselbe Konvention wie `village.history.start_year = -58`, `LifePathPolicy` und `era_min_ce` des Stadt-Builders. `campaign_arc.json` zählt dagegen `start_year_bce: 58` positiv; beim Lesen gilt `-start_year_bce`.

Daten vor dem 1. Januar 45 v. Chr. sind nominale römische Daten auf proleptisch julianischem Raster. Die Abweichung des vorjulianischen Kalenders und der augusteische Schaltjahresfehler werden nicht simuliert. Die römische Anzeige zählt inklusiv zu Kalenden, Nonen und Iden (`a.d. V Kal. Apr.` = 28. März, Caesar BG 1.6.4), nennt Quintilis ab 44 v. Chr. Iulius und Sextilis ab 8 v. Chr. Augustus. Das a.u.c.-Jahr ist optional (varronisch, 1 n. Chr. = 754; Zeitgenossen datierten nach Konsuln, die Fasti Capitolini zählen ein Jahr weniger).

## Module

| Datei | Inhalt |
|---|---|
| `prototype/scripts/domain/world_calendar.gd` | Jahreskonvertierung, JDN, Dauer (Tage, Monate, Kalenderjahre), Alter aus Geburtsdatum oder -jahr, Jahreszeiten und Saisonzüge, deutsche/englische/römische Anzeige mit a.u.c., Uhr- und Speicherblock (`new_world_time`, `validate_world_time`, `normalize_world_time`). Vorläufiger Kampagnenbeginn `CAMPAIGN_START` = 1. Mai 58 v. Chr., Geburtsjahr `PROTAGONIST_BIRTH` = 70 v. Chr. |
| `prototype/scripts/domain/era_registry.gd` + `prototype/assets/world/era_registry.json` | 53 Einträge mit Datumsbereich, Status (`documented`, `authored_default`, `provisional`) und Quellenprüfung (`handbook`, `repo`, `literature_unverified`, `none`): Kalenderregeln, Anker (Helvetier, Aquileia, Alesia, Iden, Actium, 27 v. Chr., Varusschlacht, 14 n. Chr.), politische Zustände in exklusiven Slots, Regionen des Atlas, Gebäude (mit Builder-Aliassen), Ausrüstungsfamilien (Handbuch IT-011 bis IT-020), Truppeneinträge, Kleidung. |
| `prototype/scripts/domain/campaign_timeline.gd` + `prototype/assets/story/mission_timeline.json` | Alle 113 Missionsblätter wörtlich aus dem Handbuch, Validierung gegen die Bänder, ein Geburtsjahr, Seitenbezüge, Befunde. |
| `prototype/scripts/domain/time_jump_contract.gd`, `time_jump_participant.gd`, `calendar_ageing_participant.gd` | Vertrag und Orchestrierung für Zeitsprünge; Referenzteilnehmer nur für kalendarisches Altern. |
| `tools/story/extract_mission_timeline.py` | Reproduzierbare Extraktion aus dem PDF (`pdftotext -layout`); `--check` vergleicht mit der eingecheckten Datei. |

Abfragen der Ära-Registry: `available(id, jdn, overrides)`, `window`, `active(kind, jdn)`, `state_at(slot, jdn)`, `changes_between(a, b)` (halboffen, sortiert), `filter_available(ids, jdn)`, `era_min_visible(era_min_ce, jdn)`, `asset_available(mode, jdn, earliest, latest)` (gleiches Verhalten wie `LifePathPolicy.asset_available`, per Test belegt). Unbekannte Inhalte sind nie verfügbar. Ein Zeitfenster ändert sich zur Laufzeit nur durch eine Überschreibung mit `divergence_id` (markierte Divergenz, z. B. IV-28 „Caesar lebt“).

## Missionszeitleiste

Quelle: Missionsblätter der Fassung 2.0 auf PDF-Seiten 125–237 (PDF-Seite = Blattseite + 58), gegengeprüft mit Abschnitt G (PDF S. 49–56). Alle 113 Seitenverweise des Registers stimmen mit den Blättern überein; alle Titel und IDs stimmen mit `campaign_arc.json` überein. Stichproben von Hand am PDF: I-01, I-18, I-31 (umbrochener Titel), II-13, III-02, III-22, IV-18, IV-28, IV-29, IV-30.

| Band | Missionen | Jahre laut Blatt | Alter | Vorgabe |
|---|---|---|---|---|
| I | 32 (I-00–I-31) | 58–52 v. Chr. | 12–18 | 58–52 |
| II | 25 (II-00–II-24) | 51–47 v. Chr. | 19–23 | 51–47 |
| III | 25 (III-00–III-24) | 47–44 v. Chr. | 23–26 | 47–44 |
| IV | 31 (IV-00–IV-30) | 44–27 v. Chr., danach Sandbox | 26–43, 26+, variabel | 44–27 + Sandbox |

Datumsarten: 96 Einzeljahre, 7 Doppeljahre (57/56 …), 2 Tagesdaten (III-22, III-23: 15. März 44 v. Chr.), 1 Spanne (IV-18: 34–32), 4 „27 v. Chr. und danach“ (IV-24–IV-27), 1 „ab 44 v. Chr.“ (IV-28), 1 „alternativ“ (IV-29), 1 „Epilog“ (IV-30). Kanonarten: 46 HISTORICAL CORE, 35 FICTIONAL THREAD, 24 HISTORICAL FRAME, 4 FICTIONAL ENDING, 2 COUNTERFACTUAL, 1 FICTIONAL FRAME (I-23), 1 SYSTEMIC EPILOG.

**Ergebnis:** Kein Blatt widerspricht den Bändern; alle Altersangaben passen zu genau einem Geburtsjahr, **70 v. Chr.** (Alter = Jahr − Geburtsjahr, wie Start 58 v. Chr. mit 12). Ein Protagonist dieses Jahrgangs wäre bei der Varusschlacht 78, nicht 79.

Befunde der Validierung (nichts korrigiert; die Liste steht als `acknowledged_findings` in der Datei, jede Änderung bricht den Test):

| Art | Befund | PDF-Seiten |
|---|---|---|
| Schreibweise | II-13 „49/48 v. Chr.“ nennt das Alter des späteren Jahres (22); die sechs übrigen Doppeljahre (I-18, I-19, I-26, III-13, IV-03, IV-12) das des früheren. Beides passt zu 70 v. Chr. | 170 |
| Hinweis | Geburtstag zwischen 1. Januar und 15. März, wenn „ca. 26“ an den Iden wörtlich gilt (III-22, III-23). | 204, 205 |
| Hinweis | Grenzjahre: 47 v. Chr. gehört zu II und III (II-24, III-00, III-01), 44 v. Chr. zu III und IV (III-13–III-24, IV-00–IV-03). Band folgt aus der ID, nicht aus dem Jahr. | 181–183, 195–210 |
| Hinweis | Zeitsprünge ohne Mission: IV-15→IV-16 drei Jahre, IV-17→IV-18 zwei, IV-21→IV-22 drei. | 222–225, 228–229 |
| Hinweis | IV-24–IV-27 offen nach 27 v. Chr., Alter 43 nur zum Eintritt; IV-28 nur im Divergenzmodus; IV-29 und IV-30 ohne Jahr. | 231–237 |

Manuelle Prüfhinweise (`review_notes`): **R1** I-26 „Dienstvertrag oder Zivilweg“ mit ca. 17 (53/52 v. Chr., PDF S. 151, Register S. 50) gegen die Lebensphasen des Handbuchs (PDF S. 64, Heeresdienst erst als Erwachsener; `world_model.gd` verlangt 18). **R2** III-02 „Afrika ruft“ steht auf 46 v. Chr.; Caesars Aufbruch nach Africa fällt nach der Standardchronologie auf Ende Dezember 47 v. Chr. (PDF S. 184; fachlich prüfen). **R3** Die Blätter nennen keinen Starttag. **R4** `campaign_arc.json` führt für Band II–IV weder Ort noch Kanonart.

## Zeitsprungvertrag

Ein Sprung braucht einen sichtbaren Grund und wird in Jahreszeit- oder Jahresschritten integriert (sechs Jahre ab 1. Mai = 25 Saisonschritte). Ein offenes geschütztes Ereignis im Fenster (I-10, D-020) blockiert ihn. Teilnehmer laufen in fester Reihenfolge (characters, relations, politics, tribes, settlements, economy, property, troops, equipment) auf tiefen Kopien; Zufall nur aus `context.seed` (SHA-256 aus Welt, Domäne, Schritt). Pflichtdomänen: characters, relations, settlements, property, politics, equipment. Fehlt eine Simulation, muss sie mit Grund in `allow_missing` stehen und erscheint als `not_simulated` in der Zusammenfassung. Jede Änderung nennt Subjekt, Text und Ursache; jede Entfernung Grund und Ereignis-ID, sonst wird der ganze Sprung verworfen. Das Ergebnis enthält neue Uhr, Domänenzustände, Ledger, Zusammenfassung, Ära-Übergänge und einen Digest. Alter entsteht immer aus dem Geburtsdatum; Verstorbene altern nicht weiter (vorbereitet für Nachfolger und Erben).

## Integrationsplan für den Lead

Diese Datei ändert keine bestehende Logik. Basis der Zeilenangaben: `ffbe3ad`.

1. **Speicherschema v6** (`world_model.gd`): `SCHEMA_VERSION` (Z. 19) auf 6; in `new_game` (Z. 57–107) `"calendar": WorldCalendar.new_world_time(WorldCalendar.campaign_start_jdn(), 21600, -58, {"player": {"year": -70}, <companion_id>: {"year": -70}})` für neue Kindheitsspiele; `"calendar"` in die exakte Schlüsselliste von `_validate_state` (Z. 737) aufnehmen und dort `validate_world_time` plus `EraRegistry.validate_overrides(state.calendar.divergences)` prüfen; in `_restore_integer_fields` (Z. 1044) `state.calendar = WorldCalendar.normalize_world_time(state.calendar)`.
2. **Migration v5 → v6** in `_read_save` nach Z. 1011, ohne Inhalte zu verändern: Kindheitssaves (`village.childhood` vorhanden) erhalten `jdn = campaign_start_jdn() + childhood.day - 1`, `origin_year = -58`. Ältere reguläre Saves mit `history.start_year == 100` behalten ihre Zeitlinie (Entscheidung offen, siehe unten): `origin_year = 100`, `jdn = season_start(add_years(100, progress.years_elapsed), strategy.turn % 4)` (Frühling 100 n. Chr. für Kinder, Frühling 106 n. Chr. nach dem Sechsjahressprung). Das Alter bleibt der gespeicherte Wert; Geburtsjahr `birth_year_for_age(player.age, year_of(jdn))`. `world_seconds` bleibt technische Uhr (wird von `npc_behavior.gd:419` geprüft) und ist nicht das historische Datum.
3. **Altersprüfung** (`world_model.gd` Z. 802–807) ersetzen: `player.age == WorldCalendar.world_time_age(calendar, "player")`, Gefährte entsprechend; `years_elapsed` wird `years_between(origin_year, year_of(clock.jdn))`.
4. **Legacy-Sprung „train“** (Z. 528–549): statt `world_seconds += 6 * YEAR_SECONDS` und `age = 18` einen Plan `TimeJumpContract.plan(calendar.clock, add_calendar_years(jdn, 6), {"reason": "Sechs Jahre später", "pending_protected": offene_geschützte})` mit `CalendarAgeingParticipant` und `allow_missing` für die noch fehlenden Domänen ausführen; Alter, Lebensphase und Uhr aus dem Ergebnis übernehmen, die Zusammenfassung im Chronikeintrag zeigen. Solange `screenplay.i10` nicht abgeschlossen ist: `pending_protected = [{"id": "I-10", "jdn": jdn + 1}]`.
5. **Regionalkampagne** (`world_model.gd` Z. 1290–1294, `season_campaign.gd` Z. 206): `advance` setzt die Uhr auf `season_turn_start(turn, origin_year)`; `summary.year` wird `WorldCalendar.add_years(origin_year, floori(turn / 4.0))` statt `100 + …`. Die Reihenfolge `SEASONS` (Z. 6) entspricht `SEASON_NAMES_DE`; der Südhalbkugelversatz (Z. 178) bleibt. Damit entfällt die in `prototype/README.md:51` beschriebene Abweichung.
6. **Anzeigen**: `village_life_panel.gd:142` `"%s n. Chr."` → `WorldCalendar.format_year(year)` (heute würde ein Kindheitssave „-58 n. Chr.“ zeigen, der Zweig ist nur durch den frühen Rücksprung verdeckt); `atlas_screen.gd:113–114` `94 if young else season.year` und `"%d n. Chr."` → Jahr aus der Uhr und `format_year` (die Weltkugel zeigt jungen Spielern heute 94 n. Chr., die Dorfchronik 100 n. Chr.); `opening_story.gd:71, 79, 102` die Literale „58 v. Chr.“ aus `format_year(WorldCalendar.CAMPAIGN_START.year)`.
7. **Geschichtsrahmen** (`village_life.gd`): Z. 623 `start_year + years_elapsed` ergibt bei −58 + 58 das ungültige Jahr 0 → `year_of(clock.jdn)`; `_ruler` (Z. 741–745) rechnet immer `100 + years_elapsed` und meldet „Trajan“ auch in 58-v.-Chr.-Saves → `EraRegistry.state_at("rome.power_bloc" | "rome.dictatorship" | "rome.princeps", jdn)`; `HISTORICAL_ANCHORS` (Z. 36–40, Trajan, Dakerkriege) werden für die Kampagne durch `EraRegistry.active("historical_anchor", jdn)` ersetzt und für Legacy-Saves als eigene Einträge geführt; Default `start_year: 100` (Z. 62) und Prüfung Z. 727–728 folgen `calendar.origin_year`.
8. **Texte mit 100 n. Chr. oder Trajan**: `village_life.gd:21` (Decimus: „Trajan herrscht in Rom“), `opening_story.gd:13`, `atlas_data.gd` Z. 5 (Trajan, 100 n. Chr.), Z. 6 Lugdunum (ab 43 v. Chr.), Z. 7 Londinium/Provinz Britannia (ab 43 n. Chr.), Z. 8 Baetica (augusteisch), Z. 10 „römische Eisenzeit“, Z. 12 Achaia (ab 27 v. Chr.), Z. 13 Africa Proconsularis/Karthago, Z. 14 römisches Ägypten (ab 30 v. Chr.), Z. 22 Kuschan, Z. 25 Östliche Han (58 v. Chr.: Westliche Han), Z. 35 Moche; Notizen nach `EraRegistry.state_at(<region>.rule, jdn)` wählen. Dokumente: `prototype/README.md:45–51`, `docs/17_village_life/STORY.md:7, 9`, `PLAYER_VISION.md:19, 23`, `DELIVERY.md:222, 224`, `docs/12_integration/ATLAS_SOURCES.md:3, 7, 9`, `docs/15_living_frontier/STORY.md:33`, `docs/art/CHARACTER_REFERENCE_SOURCES_2026_11_22.md:21, 77`; `AGENTS.md` wird auf dem Branch `docs/game-direction-20261126` korrigiert.
9. **Hooks anderer Systeme**: `LifePathPolicy.elapsed_years`, `age_at_year`, `asset_available` (`life_path_policy.gd:96–111`) an `WorldCalendar`/`EraRegistry` delegieren (Parität getestet; `life_path_policy_test.gd` ist bisher nicht in `check_prototype.py` registriert). Stadt-Builder (`tools/world/build_roman_test_city.py`): `era_min_ce` ist ein historisches Jahr mit Vorzeichen; die Laufzeit blendet Objekte mit `EraRegistry.era_min_visible(era_min_ce, jdn)` aus. In 58 v. Chr. sichtbar: Häuser (−100), Boden (−1000); verborgen: Basilica (−46), Aquädukt (52), Amphitheater (80), Thermen (216), Mauern und Tore (271) – Aquileia braucht eine eigene frühere Befestigung. Stammes-KI (`feat/germanic-tribes-ai-20261126`): Tick mit Uhr, Übergänge über `changes_between(vorher, jetzt)`, Ausrüstung über `active("equipment_family", jdn)`, im Sprung als Teilnehmer `tribes`. Truppenkatalog (`feat/troops-command-core-20261126`): `filter_available(katalog, jdn)`; Talgefecht-Prüfstand als `troops.valley_skirmish_test_bench` (58 v. Chr.).
10. **Export**: `export_presets.cfg` Z. 13, 72, 88 – `assets/story/mission_timeline.json,assets/world/era_registry.json` zur `include_filter` ergänzen, sonst fehlen beide Dateien in der APK (die Module melden dann leere Daten bzw. `ok = false`).

## Offene Entscheidungen des Auftraggebers

1. Starttag der Kampagne (vorläufig 1. Mai 58 v. Chr.) und Geburtstag des Protagonisten (Jahr 70 v. Chr. abgeleitet; Tag frei, bei wörtlichem „ca. 26“ an den Iden bis 15. März).
2. Alte reguläre Saves mit Trajan-Zeitlinie (100 n. Chr.) behalten oder auf 58 v. Chr. umstellen (Vorschlag: behalten, eigene Legacy-Anker).
3. I-26 mit 17 Jahren: Termin 52 v. Chr. (dann 18) oder ziviler Pfad bei 17 (R1); III-02 auf 47 v. Chr. prüfen lassen (R2); Schreibweise der Doppeljahre (II-13).
4. Vorjulianischen Kalender später simulieren oder bei nominalen Daten bleiben; a.u.c. oder Konsulnamen als römische Jahresanzeige.
5. Fachliche Prüfung der Registry-Einträge mit Status `provisional` und `literature_unverified` (u. a. Schienenpanzer erst ab 9 n. Chr., Montefortino-Enddatum).

## Prüfung

Gruppen in `tools/check_prototype.py`: `world_calendar` (111 Prüfungen), `era_registry` (63), `mission_timeline` (32, gibt alle Befunde mit Seiten aus), `time_jump_contract` (42). Lauf: `python3 tools/check_prototype.py --godot <godot> --only world_calendar era_registry mission_timeline time_jump_contract --report <scratch>`. Eine absichtliche Verletzung der Jahr-null-Regel lässt alle vier Gruppen scheitern. `python3 tools/story/extract_mission_timeline.py --pdf <Handbuch> --check` bestätigt, dass die Zeitleiste der PDF-Extraktion entspricht.
