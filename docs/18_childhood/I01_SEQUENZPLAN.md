# I-01 „Die drei Becher“ – Sequenzplan, Timingkarte und Grenzen

Stand: 26.11.2026, Branch `feat/i01-three-cups-slice-20261126`. Grundlage: Masterhandbuch 3.0 S. 13 (Vertiefungsentwurf), S. 126 (Originalblatt), S. 22–31 (Film), S. 44 (erste Stunde), S. 46 (Testmatrix). Dialogzeilen sind eigene Produktionsentwürfe in `prototype/assets/story/missions/band1/I-01.json` (`slice.lines`), kein Wortlaut des Originaldrehbuchs.

## Spielablauf (Vertikalschnitt)

1. **VID-A** (In-Engine, Klasse B): Tisch mit Brot und Julia, Regal mit den drei Bechern und Silvanus’ Scherz über den schiefen Becher, Schulteraufnahme des Jungen an seinem Bett, **Wahl** (Mit Julia reden / Beim Tischdecken helfen / Erst in den Hof gehen), Julias Reaktion, Übergabe an die normale Kamera am Bett.
2. **Spiel**: Becher vom echten Regal nehmen (alle drei zugleich), einzeln an Julias, Silvanus’ und den eigenen Platz stellen, Wasser am Brunnen im Hof schöpfen, Becher füllen, Frühstück. Bei „reden“ oder „Hof“ deckt Julia selbst; der Brunnen bleibt freiwillig („Bitte später erfüllen“). Das Frühstück findet auch ohne Hilfe statt; dann hat Silvanus das Wasser geholt. Draußen sind Begegnungen mit Marcus (am Brunnen), Cassia oder Aelia möglich; sie werden als Ereignis gespeichert, nicht als Freund-/Rivalenwert.
3. **VID-B** (In-Engine): Tisch in der Totalen, Silvanus erzählt, warum Sextus ihm half (keine Vorausdeutung), Julia reagiert auf die gespeicherten Tatsachen (volle Hilfe, nur Tisch, nur Wasser, offene Bitte, Abwesenheit), **Wahl** des Themas (Werkstatt / Feldarbeit / Begegnung – nur nach tatsächlicher Begegnung), Antwort.
4. **Familienschritte** (bestehende Save-Indizes 0–2): Silvanus geht nach dem Gespräch selbst zu seiner Türarbeit vor dem Haus; Julia räumt den Tisch ab und gibt dort die Besorgung (Haushaltsdenar), dann Krug vom Tisch nehmen und zu Silvanus bringen. Julia wechselt erst nach der Übergabe vor das Haus, während der Junge draußen ist.
5. **VID-C** (Übergang zu I-02): Silvanus’ Vaterzeile, Variante „Erinnerung an die Zusage“ (nach Hilfe) oder freundlicher Abschied, Hinweis auf Marcus/Cassia nur nach echter Begegnung.

## Sequenzplan

| ID | Klasse | Dauer (gemessen, Autorendauer der Beats) | Cast | Ort | Entry state | Exit state | Abbruchregel |
| --- | --- | --- | --- | --- | --- | --- | --- |
| I-01.VID-A (`childhood_home` v3) | B, In-Engine | 29,7 s bis zur Wahl, 9,1 s Reaktion + Übergabe | Julia, Silvanus, Junge | Familienhaus (baker_home), Tisch, Regal, Bett | `i01=pending`, `i01_path=""` | `i01_path` gesetzt, Ereignis `I-01.choice.*` | Skip springt zur offenen Wahl, trifft sie nie; nach der Wahl springt Skip zur Übergabe. Back/Suspend speichern Beat-Index; Continue setzt dort fort. |
| I-01.VID-B (`i01_vid_b`) | B, In-Engine | 32,9 s bis zur Themenwahl, 12,2 s Antwort + Übergabe | Silvanus, Julia, Junge | Frühstückstisch | `i01_meal=done`, `i01_topic=""` | `i01_topic` gesetzt, `i01=complete` | wie VID-A; Abbruch ändert das Ergebnis nicht (Test „Film abgebrochen“). |
| I-01.VID-C (`mission_transition_father_morning`) | B, In-Engine | 31,9 s | Silvanus (Junge) | vor dem Familienhaus | Krug an Silvanus übergeben | I-02 aktiv | keine Wahl; Skip führt zum Ziel von I-02. |

Shotlist (Kamera aus `scripts/cinematic/opening_director.gd`, Brennweite als FOV): `i01_table_detail` (FOV 40→34, über Brot/Becherplatz zu Julia), `i01_shelf_cups` (44→36, Regal mit drei Bechern), `i01_bed` (46→42, Schulteraufnahme am Bett Richtung Julia), `i01_choice` (Halten der Schulteraufnahme während der Wahl), `mission_dialogue` (43→38, Gegenschuss mit Blickpaar, Wandabweisung), `i01_table_wide` (58→54, Tisch in der Totalen), `i01_topic_choice` (Schulter des Jungen Richtung Silvanus). Letzter Shot `player` endet exakt auf der Spielkamera.

Varianten: VID-A-Reaktion je Weg (3), VID-B-Reaktion je Faktenlage (5), Themenantwort (Werkstatt, Feld, je Begegnung 3), VID-C (2 Elternzeilen, 0–1 Begegnungszeile).

Sprachtracks: **BLOCKIERT.** Keine Aufnahmen vorhanden, keine lokale lizenzierte Sprachsynthese, kostenpflichtige Dienste ausgeschlossen. Jeder Beat trägt `line_id`, `speaker_id` und `voice: "blocked_no_recording"`; die Untertitel zeigen Sprecher und Rolle. Lippensync/Viseme, Fingeranimation (Erwachsenenrig ohne Finger) und ein Aufsteh-/Trage-/Sitzclip fehlen ebenfalls.

## Timingkarte (eine skriptierte Route, kein menschlicher Spieltest)

Gemessen mit `prototype/tests/i01_playthrough_test.gd` (feste 60 Hz, Main-Uhr, normale `move_axis`-Eingabe, normale Interaktion/Dialoge). Route: Hilfe, Thema Werkstatt.

| Phase | Sekunden |
| --- | --- |
| VID-A bis Wahl / Reaktion + Übergabe | 29,7 / 9,1 |
| Bett → Regal, Becher nehmen, Regal → Tisch, 3× abstellen | 3,0 + 0,4 |
| Tisch → Brunnen (Tür, um das Vorratshaus herum) | 15,9 |
| Brunnen → Tisch, füllen, Frühstück | 15,7 + 0,2 |
| VID-B bis Wahl / Antwort + Übergabe | 32,9 / 12,2 |
| Warten bis Silvanus hinausgeht, Julia, Krug | 3,7 + 0,2 |
| Tisch → Silvanus vor dem Haus, Übergabe | 5,6 + 0,1 |
| VID-C | 31,9 |
| **Summe** | **Film 115,8 s · Laufen 44,0 s (49,4 m) · Aktionen ≈ 1 s** |

Ergebnis: rund 2:40 min ohne Lese-, Entscheidungs- und Erkundungszeit. Das Handbuch nennt 34 min Referenz für I-01; der Vertikalschnitt erreicht diese Spielzeit **nicht**. Der offene zweite Beat (Minute 18–30: Nachbar, Marktrand, freiwilliger Dienst) ist nicht umgesetzt.

## Testzuordnung

| Fall | Nachweis |
| --- | --- |
| T01 neue Partie ohne Waffe/Geldcheat | `i01_slice_test`: keine Leihausrüstung, kein Gegenstand, 0 Denare beim regulären Start; HUD ohne Kampfknöpfe (`i01_flow_test`). Rüstung im Originaljungen-Mesh: siehe Grenzen. |
| T19 Filmstart/Ende | `i01_flow_test`: VID-A erreicht die Wahl, letzter Shot = Spielkamera. |
| T20 Skip bei offener Wahl | `i01_flow_test`, `opening_flow_test`: Skip landet auf der Wahl, Zustand unverändert. |
| T21 Back/Suspend/Resume | `i01_flow_test`: Back pausiert, Suspend schreibt Checkpoint, Continue am selben Beat, keine doppelten Ereignisse. |
| Film abgebrochen | `i01_flow_test`: VID-B übersprungen vs. vollständig angesehen ergibt identischen Zustand. |
| NPC beim Brunnen abwesend | `i01_slice_test` (Marcus `absent`), `i01_flow_test` (Marcus unsichtbar): kein Kontakt, keine Ersatzzeile. |
| Hilfe abgelehnt | `i01_slice_test`: Julia deckt, Frühstück findet statt, kein Vertrauensgewinn, offene Bitte als `declined`. |
| Save am Tisch | `i01_slice_test` (Modell) und `i01_flow_test` (Requisiten nach Continue). |
| Save-Migration v3 → v4 | `i01_slice_test`, `mission_bridge_data_test`. |

## Grenzen und offene Entscheidungen

- Der Originaljunge trägt im Mesh eine segmentierte Rüstung (Schulterplatten, Brustschienen, Armschienen). Das widerspricht „ohne Waffe/Rüstung“ für I-01; Asset-/Eigentümerentscheidung, im Code nicht verändert.
- Tageszeit: keine Uhr und kein Abendlicht; VID-C spielt im festen Sonnenstand.
- Tragen ist ein Graustufen-Behelf: Becher und Krug folgen den Handknochen ohne Trage-Pose.
- Interaktion bevorzugt die Person, die das aktuelle Ziel nennt, sobald sie in Reichweite ist (vorher öffnete am Tisch Silvanus’ Gespräch statt Julias, weil er näher stand). Andere Personen werden weiterhin nach Nähe gewählt.
- Bilder aus Mesa/llvmpipe (gl_compatibility) sind Engine-Frames, kein Nachweis für Fold7-Bildrate oder -Darstellung.
