# Weiterbearbeitungsplan IMPERATHEN für ChatGPT 6.2 Sol (sehr hoher Denkmodus)

Basis: Branch `handoff/sol-20261124` (enthält Build 7, PR #49 und PR #50). Stand und Grenzen: `docs/23_handoff_sol/UEBERGABE.md`.

## Harte Regeln (von Heinz, verbindlich)

1. **Nur echte Verbesserungen, keine Regressionen.** Was nicht nachweisbar besser ist, wird nicht übernommen. Was du nicht gut kannst, lässt du weg und sagst offen, welches Werkzeug oder Modell besser geeignet wäre.
2. **Vorher/Nachher mit gleicher Kamera** für jede sichtbare Änderung (gleiches Review-Skript, gleiche Auflösung, gleiche Kameraposition; z. B. `prototype/tests/live_graphics_review.gd`, `menu_review.gd`). Bilder aus Software-Rendering sind keine Leistungsmessung.
3. **Keine erfundenen Inhalte.** Handlung, Figuren, Orte und Dialoge kommen aus den Drehbüchern Band 1–4. Notwendige Ergänzungen werden in Doku und Commit als „Ergänzung“ markiert. Fehlen Daten: „Hierzu liegen mir keine gesicherten Daten vor.“
4. **Produktionsreifer Code** ohne TODO/FIXME-Platzhalter und ohne halbfertige Codepfade; jeder Commit testgrün.
5. **Deutsch** in Doku, Commit-Beschreibungen, Spieltexten und Rückmeldungen an Heinz.
6. **Spielstände bleiben kompatibel:** Schema v5 + Envelope; Schritt-, Item- und Fähigkeits-IDs nie umbenennen; neue Brückenstände nur mit Migration und Test.
7. **Git:** Arbeitszweige von `handoff/sol-20261124`, kleine Commits, kein Force-Push, nichts direkt nach `main`, keine Keystores/Secrets, keine Dateien > 50 MB, Drehbuch-docx nicht ins Repo.

## Pflicht-Prüfung je Arbeitspaket
```bash
python3 -m unittest discover -s tests -p 'android_*_test.py'
python3 tools/check_prototype.py --godot <godot-4.7.2> --keep-going --report artifacts/engine-checks
```
Neue Logik bekommt einen eigenen Engine-Test in `prototype/tests/` und einen Eintrag in `tools/check_prototype.py`.

---

## AP-1 Begleitsystem und offene Band-1-Abweichungen (Priorität 1)

- **Ziel:** Marcus kann in I-06, I-08, I-09 (und später I-15) anwesend sein, mitlaufen und Drehbuchzeilen sprechen. I-04: Silvanus begleitet zur Schmiede. Den in Band 1 nicht vorkommenden Namen „Severus“ (I-07) klären.
- **Dateien:** neu `prototype/scripts/story/companion_follow.gd` (o. ä.); `village_childhood.gd`; `missions/band1/I-04/I-06/I-08/I-09.json` (Feld z. B. `companions`); `world_model.gd` (Begleitstatus nur über bestehende `companion.*`-Daten oder versionierten Unterbereich); Figuren/NPC-Steuerung in `prototype/scripts/domain/npc_behavior.gd`, `scripts/world/village/`.
- **Akzeptanz:** Marcus folgt ohne Durchdringung von Boden/Wänden/Personen, bleibt bei Zwischensequenzen an definierten Punkten, spricht nur Zeilen aus Band 1 (Fundstelle in Doku). Freund/Rivale-Wahl aus I-03 beeinflusst Ton. Severus: entweder durch die im Drehbuch genannte Besetzung ersetzt oder als „namenloser Wachmann“ geführt – Entscheidung mit Fundstelle dokumentiert. Alte Saves laden ohne Fehler.
- **Tests:** neuer `companion_follow_test.gd` (Wegfindung, Abstand, Save/Load); `band1_alignment_test.gd` erweitert; Vorher/Nachher-Bilder Dorf und Schmiede.
- **Abhängigkeiten:** keine.

## AP-2 Brückenschritte in Missionsdateien (Priorität 1)

- **Ziel:** I-02, I-08, I-10 bis I-14 aus `_screenplay_step` in `missions/band1/I-xx.json` überführen.
- **Dateien:** `village_childhood.gd`, `mission_data.gd`, `missions/band1/index.json`, neue JSONs.
- **Akzeptanz:** Laufzeit-Schrittliste vorher/nachher byteidentisch verglichen (wie bei Commit 4bf14b3); Saves aus Build 7 und #50 laden.
- **Tests:** `village_childhood_test.gd`, `childhood_integration_test.gd`, `band1_expansion_test.gd` grün; neuer Vergleichstest der Schrittliste.
- **Abhängigkeiten:** keine; erleichtert AP-3.

## AP-3 Band 1 ausbauen: I-15 ff. (Priorität 2)

- **Ziel:** I-15 „Asche hat Namen“ nach `band1.md` Tabelle 18 und „Erlaubte Lösungsfamilien“ (Funde sichern: Pferdebeschlag, Stoffrest, Liefermarke, rotes Wachssiegel; Vergleich bei Cassia bzw. Decimus; Entscheidung melden/kopieren/geheim halten), danach I-16 bis I-31 der Reihe nach.
- **Dateien:** `missions/band1/I-15.json` ff., `village_childhood.gd` (Brückenstand **v4** mit Migration nach Muster v2 → v3), `campaign_arc.json` (`narrative_status`), ggf. `chapter1_abilities.json` (nur anhängen).
- **Akzeptanz:** jede Mission mit Fundstellen (Abschnitt, Tabelle, Zeile); Ziel-Dauer 25–35 min pro Hauptmission durch echte Spielhandlung, nicht durch Wegstrecke. Entscheidungen werden gespeichert und wirken später.
- **Systemvoraussetzungen:** I-16 bis I-18 brauchen Zeitsprung/Wiederaufbau über Monate und Alter 13 → eigener Karriere-/Altersbereich im Save (heute ist `village.childhood` an Alter 12 gebunden). I-19/I-20 brauchen den Ort Aquileia.
- **Tests:** je Mission ein Engine-Test (Durchlauf, Abzweigungen, Save/Load, Migration).
- **Abhängigkeiten:** AP-1 (Marcus in I-15), AP-2 empfohlen.

## AP-4 Nebenquest-System und NQ-1-01 bis NQ-1-24 (Priorität 2)

- **Ziel:** generisches, datengetriebenes Nebenquest-System (Auslöser, Lösungskorridor, Konsequenz, Ablehnungsfolge) und Umsetzung der Band-1-Nebenquests.
- **Reihenfolge:** zuerst die mit Valdora/Waldweg machbaren NQ-1-04, -07, -10, -13, -19, -22; dann nach Bau der Orte „Nachbardorf“ und „Marschlager“ die übrigen; NQ-1-01 und -16 erst mit Pferden/Maultieren.
- **Dateien:** neu `prototype/assets/story/sidequests/band1/NQ-1-xx.json`, `prototype/scripts/story/side_quests.gd`, Save-Unterbereich `village.side_quests = {"version":1,…}` mit `ensure`.
- **Akzeptanz:** Das Drehbuch liefert je Nebenquest nur eine Vorlage mit generischer Auftraggeber-Zeile. Konkrete Auftraggeber, Namen und zusätzliche Dialoge sind Ergänzungen und müssen markiert und Heinz zur Freigabe vorgelegt werden. Ziel-Dauer 12–20 min.
- **Tests:** `side_quests_test.gd` (Annahme, Ablehnung, Abschluss, Save/Load, Manipulationsabwehr).
- **Abhängigkeiten:** AP-2; Orte/Tiere aus AP-7.

## AP-5 Bände 2–4 (Priorität 3)

- **Ziel:** Missionen der Bände 2 (25/24), 3 (25/24), 4 (31/24) nach demselben Datenmuster.
- **Dateien:** `missions/band2..4/`, `sidequests/band2..4/`, `chapter2..4_abilities.json`, `campaign_arc.json`.
- **Akzeptanz:** wie AP-3/AP-4; Altersübergänge und Zeitsprünge (Kind → Soldat …) nur wie im Drehbuch, kein automatischer Kurzsprung.
- **Abhängigkeiten:** AP-3, AP-4, Karriere-Bereich im Save.

## AP-6 Open-World-Freischaltungen (Priorität 2, parallel zu AP-3)

- **Ziel:** Jede gelernte Fähigkeit hat eine wiederkehrende Anwendung in der freien Welt (z. B. Spurensuche bei jeder Überfallwarnung, Reparaturaufträge mit Sorgfaltsprüfung, Handel mit Ruf). Heutige Lücken: Rabatt `ch1_price_is_promise` erst nach Kapitel I in der Arbeitsansicht nutzbar; `village_scout` erst nach I-14.
- **Dateien:** `chapter_abilities.gd`, `village_life_panel.gd`, `village_economy.gd`, `combat_actions.gd`.
- **Akzeptanz:** Wirkung im Spiel sichtbar und getestet; Werte als Ergänzung dokumentiert.
- **Tests:** `chapter_abilities_test.gd` erweitert.
- **Abhängigkeiten:** keine.

## AP-7 Kampf, Bewegung, Rig (Priorität 3)

- **Ziel:** Finger-Rig, natürlichere Bewegung, Schwert- und Axtkampf mit eigenen Animationen.
- **Hinweis zur Eignung:** Neue Rigs, Fingerknochen und Animationen entstehen in **Blender** (Handarbeit oder Motion-Capture-Daten mit belegter Lizenz); ein Sprachmodell kann das nicht ersetzen. Für umfangreiche Godot-Animationslogik, Retargeting und Blender-Python-Skripte kann **Claude Opus** (bei Heinz vorhanden) als Alternative oder Zweitprüfung eingesetzt werden. Ob Sol oder Opus hier besser arbeitet: Hierzu liegen mir keine gesicherten Daten vor.
- **Dateien:** `art/`, `prototype/scripts/visuals/`, `prototype/scripts/domain/combat_actions.gd`, `docs/19_motion_combat/COMBAT_CONTRACT.md`.
- **Akzeptanz:** `natural_motion_test.gd`, `locomotion_regression_test.gd`, `cc0_runtime_gestures_test.gd`, `combat_actions_test.gd` grün; Vorher/Nachher-Videos mit gleicher Kamera; Lizenznachweis jeder Animation im Manifest.
- **Abhängigkeiten:** Blender-Assets.

## AP-8 Grafik Weg B (Priorität 3)

- **Ziel:** Prüfen, ob Forward+/Mobile-Vulkan auf echter GPU besser aussieht und flüssig läuft.
- **Dateien:** `prototype/project.godot` (Renderer-Einstellungen), CI-Option `IMPERATHEN_GRAPHICS_QA` in `android-prototype.yml`, `tools/android_graphics_benchmark.py`.
- **Akzeptanz:** Messung auf mindestens einem echten Android-Gerät (FPS, Frametime, Temperatur) und gleiche Kamera vorher/nachher. Übernahme nur bei klarer Verbesserung ohne FPS-Verlust unter das bisherige Niveau. Weg A (`docs/22_band1_alignment/GRAFIK_WEG_A.md`) brachte keine Verbesserung.
- **Abhängigkeiten:** Gerätezugang (AP-10).

## AP-9 Musik und Ton (Priorität 4)

- **Ziel:** Menümusik und Trailer-Ton heute synthetisch (`tools/ui/build_menu_music.py`), nur technisch geprüft. Ersatz durch einen orchestralen Score.
- **Hinweis:** Braucht einen Komponisten oder ein Musikmodell mit klaren Nutzungsrechten; ein Sprachmodell allein liefert das nicht. Lizenz im Manifest eintragen.
- **Akzeptanz:** Heinz hört und gibt frei; Pegel/Loop-Prüfung in `roman_menu_test.gd` bleibt grün.

## AP-10 Emulator- und Gerätetests (Priorität 1, sobald möglich)

- **Ziel:** APK des Integrationsstands auf Emulator und echtem Gerät starten: Menü, Vorspann, I-00 bis I-14, Save/Load.
- **Werkzeuge:** `tools/run_android_emulator.sh`, Workflow `android-runtime-recheck.yml`, `tools/android_runtime_smoke.py`, `tools/validate_android_apk.py`.
- **Akzeptanz:** Start ohne Absturz, Bildrate und Wärme protokolliert, Touch-Flächen bedienbar.
- **Abhängigkeiten:** keine (CI-Lauf genügt für Emulator; Gerät braucht Heinz).

## Spielzeit-Ziel

≥ 90 h für Bände 1–4 (3 h/Tag ≈ 1 Monat). Planrechnung: 113 Hauptmissionen × 25–35 min + 96 Nebenquests × 12–20 min + 10–20 h Wiederholbares ≈ 76–118 h. Das Ziel ist nur erreichbar, wenn fast alle Drehbuch-Missionen tragen. Spielzeit nie behaupten, sondern als Schätzung aus Code-Daten oder als Messung kennzeichnen.

## Rückmeldung an Heinz je Paket

Kurz auf Deutsch: was geändert wurde, Tests (Zahlen), Vorher/Nachher-Bilder, Grenzen, was nicht gemacht wurde und warum, Branch/PR-Link.
