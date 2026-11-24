# Kapitel I: Fähigkeiten, Spielzeit-Schätzung und 90-h-Plan

Stand: 24.11.2026, Branch `chapter1/band1-alignment-20261124` (Basis Build 7 @ 7c3194db).
Regel: nur was Band 1 hergibt; Ergänzungen sind als solche gekennzeichnet.

## 1. Bestehendes Fortschrittssystem (vor dieser Änderung)

| System | Ort im Code | Persistenz | Wirkung außerhalb der Missionen |
|---|---|---|---|
| Attribute Mut/Kampf/Scharfsinn/Taktik | `village.attributes` (village_life.gd `ensure`) | Save v5 | Kampf erhöht Schaden im Dorfkampf (`village_strike`); I-07 Kontrollrunde gibt je +1; I-08 gibt Scharfsinn/Taktik +1 |
| Beziehungen (met/trust/helped/declined/learned/ally) | `village.childhood.relationships`, `village.social.npcs` | Save v5 | Vertrauen schaltet z. B. Sextus' Lehre frei (≥ 8) |
| Lehre/Beruf | `childhood.apprenticeship`, `village.social.profession` (smith) | Save v5 | Beruf erhöht Erträge passender Betriebe (+1) |
| Marcus Freund/Rivale | `companion.choice/trust` (I-03) | Save v5 | Begleiter-Beziehung |
| Unbewaffnete Techniken | `village.unarmed` (combat_actions.gd) | Save v5 | Übungstreffer schalten Techniken frei |

Band 1 selbst definiert **kein** Skill- oder Werte-System. Es verlangt, dass Lehre, Handel und Beobachtung als konkrete Handlung entstehen und im Weltzustand bleiben (z. B. I-05 Storykern, I-06 Storykern, I-08 Primärziel; „Zu speichern: … Beziehungsmemory …“ in jedem Missionsabschnitt).

## 2. Neu: Kapitel-I-Fähigkeiten (datengetrieben)

- Daten: `prototype/assets/story/chapter1_abilities.json` (stabile IDs, nur anhängen, nie umnummerieren)
- Logik: `prototype/scripts/story/chapter_abilities.gd`
- Save: `village.abilities = {"version":1,"earned":[…]}`. Das Schema bleibt v5. Ältere v5-Saves ohne den Eintrag erhalten ihn beim Laden aus den bereits gespeicherten Fakten (`Abilities.ensure` in `world_model.gd` vor der Validierung). Erworbene Fähigkeiten werden nie entfernt. Ein Save, dem eine durch Fakten belegte Fähigkeit fehlt oder der eine unbekannte ID trägt, wird abgewiesen.
- Der Eintrag liegt bewusst unter `village`, nicht unter `village.childhood`. Er hängt damit nicht am Kindheitsobjekt, das heute an Alter 12 gebunden validiert wird.

| ID | Name | Mission | Erwerb (gespeicherter Fakt) | Fundstelle | Wirkung (Ergänzung) | Wo wirksam |
|---|---|---|---|---|---|---|
| `ch1_look_before_force` | Sieh hin, bevor du Kraft brauchst | I-05 | Schritt `forge_anvil` abgeschlossen (Riss suchen, dann richten) | Band 1 · „I-05 · Sieh hin, bevor du Kraft brauchst“ · Tabelle 8, Storykern („… Beobachtung, Handwerk und spätere Kampfphilosophie …“) | Deckung 0,85 → 1,05 s, Abwehrfenster 0,75 → 0,95 s | Jeder Nahkampf mit `village_unarmed_guard` (I-10 und alle späteren Dorfüberfälle); Legacy-`village_block` 0,9 → 1,1 s |
| `ch1_price_is_promise` | Ein Preis ist eine Zusage | I-06 | Schritt `deliver_hinge` abgeschlossen (Griff geliefert) | Band 1 · „I-06 · Ein Preis ist eine Zusage“ · Tabelle 9, Storykern („… Lieferzusagen und Ruf“) | Notvorrat 6 → 5 Denare | `village_buy_food` (Wirtschaftsbefehl) |
| `ch1_read_tracks` | Spuren sichern statt raten | I-08 | Drehbuch-Flag `hoof_evidence` | Band 1 · „I-08 · Hufspuren im Regen“ · Tabelle 11, Primärziel („Hinweise sichern …“) | +1 Scharfsinn beim Auskundschaften | `village_scout` bei jeder Überfallwarnung |

Die Zahlenwerte sind Ergänzungen; Band 1 nennt keine Werte. Beim Erwerb meldet der Auftrag „Neue Fähigkeit: …“. Das Dorfleben-Panel (`village_life_panel.gd`, nicht `game_ui.gd`) listet die erlernten Fähigkeiten mit ihrer Wirkung.

Ehrliche Einschränkungen:
- Die Schaltfläche „Notvorrat kaufen“ liegt heute nur im Arbeits-Panel des Nicht-Kindheitsdorfs. Im Kindheitsweg ist der Rabatt deshalb erst nutzbar, wenn diese Ansicht nach Kapitel I geöffnet wird. Der Befehl selbst wirkt bereits.
- `village_scout` setzt eine Überfallwarnung voraus. Die gibt es im Kindheitsweg erst nach I-14 (`raids_allowed`). Der Test prüft hier den Wert, nicht einen vollständigen Scout-Ablauf.
- I-01–I-04 und I-07 erzeugen keine neue Fähigkeit. Dort wirken weiter die vorhandenen Beziehungs- und Attributwerte; Band 1 legt dort Beziehung statt Fähigkeit als Ziel fest (Primärziel I-01/I-03/I-04).

Tests: `prototype/tests/chapter_abilities_test.gd` (79 Prüfungen, echte WorldModel-Reise inkl. Save/Load, v5-Migration, Manipulationsabwehr, Wirkung im Nachtüberfall) und `tests/android_chapter_abilities_test.py` (3 Tests).

## 3. Ehrliche Spielzeit-Schätzung Kapitel I (heutiger Stand)

Das ist keine Messung mit Testspielern. Es ist eine Rechnung aus Code-Daten:
- Kindheitsablauf I-01 … I-09: 44 Stationen. Die Luftlinie zwischen den Zielpunkten beträgt zusammen 1.347 m (headless ermittelt). Bei Kinder-Laufen 3,8 m/s sind das ≈ 6 min, bei Gehen 1,45 m/s ≈ 15 min; reale Wege sind länger als die Luftlinie.
- Angeleitete Arbeit: 34 s (Blasebalg 8, Amboss 10, Abschrecken 4, Wachposten 12).
- Dialog/Lesen: 44 Stationen × ca. 20–40 s ≈ 15–30 min.
- Openings I-00 + Familienmorgen: wenige Minuten (16 Beats; Beat-Dauer = max(Minimum, 2 s + Textlänge/17)).
- I-10 … I-14 (Nacht, Schmiede, Vater, Morgen, Schwur): Kampf plus 4 Bridge-Schritte ≈ 5–15 min.

**Summe: etwa 35–70 Minuten für einen ersten Durchgang**, ohne freies Erkunden. Band 1 plant 32 Hauptmissionen und 24 Nebenquests. Spielbar sind heute nur I-00 … I-14 (15 Hauptmissionen, teils als verdichtete Bridge-Schritte); keine Nebenquest NQ-1-xx ist umgesetzt.

## 4. Plan zum 90-h-Ziel (Bände 1–4)

Umfang laut Drehbüchern (`campaign_arc.json`): 113 Hauptmissionen und 96 Nebenquests (Band 1: 32/24, Band 2: 25/24, Band 3: 25/24, Band 4: 31/24).

Grobe Zielrechnung (Planwerte, nicht gemessen):

| Baustein | Anzahl | Ziel-Dauer | Summe |
|---|---|---|---|
| Hauptmissionen | 113 | 25–35 min | 47–66 h |
| Nebenquests | 96 | 12–20 min | 19–32 h |
| Wiederholbare Aktivitäten (Arbeit, Handel, Überfälle, Training, Ausbildung) | — | — | 10–20 h |
| **Gesamt** | | | **≈ 76–118 h** |

Bei ø 3 h/Tag entspricht das 25–39 Tagen. Ein Monat Spielzeit ist damit nur erreichbar, wenn fast alle Drehbuch-Missionen und Nebenquests umgesetzt werden und tragen. Die heutigen I-01 … I-09 liegen mit wenigen Minuten pro Mission deutlich unter 25 min.

Schritte:
1. **Band 1 vollständig:** I-15 … I-31 und NQ-1-01 … NQ-1-24 (Lösungsfamilien und Ablehnungsfolgen stehen je Abschnitt im Drehbuch). Kapitel-I-Missionen ausbauen, statt eine Station pro Dialogzeile zu setzen.
2. **Wiederholbares:** vorhandene Systeme nutzen (Dorfwirtschaft, Überfälle, Nahkampf-Training, Handel, Beziehungen). Je Fähigkeit eine wiederkehrende Anwendung im freien Dorf (z. B. Spurensuche bei jeder Warnung, Reparaturaufträge mit Sorgfalt-Check).
3. **Update-fähige Datenstruktur:**
   - `campaign_arc.json` trägt je Mission `narrative_status`, `source_section`, `cast` und `location`.
   - Vorschlag: pro nachgelieferter Mission eine Datei `assets/story/missions/<ID>.json` mit Schritten, Bedingungen, Belohnungen und Fähigkeits-IDs, versioniert und nur anhängend.
   - `chapter1_abilities.json` ist das Muster für weitere Kataloge (`chapter2_abilities.json` …).
   - Saves bleiben v5-kompatibel über `ensure`-Ableitungen aus gespeicherten Fakten.
4. **Altersübergang:** `village.childhood` wird heute nur mit Alter 12 als gültig angesehen. Vor dem Sprung 58 → 52 v. Chr. braucht es einen eigenen Karriere-Bereich; `village.abilities` liegt dafür schon außerhalb von `childhood`.

Nichts davon ist in dieser Runde umgesetzt, außer den drei Fähigkeiten und der Datenstruktur dafür.
