# Status Nahkampf Ebene A (Branch `feat/melee-combat-core-20261126`)

Stand 26.11.2026, Abschluss auf Anweisung des Auftraggebers. Einzelheiten und Messwerte: `LEVEL_A_MELEE.md`.

## Umgesetzt und getestet (headless, Einzelläufe auf der Arbeitsmaschine)

| Thema | Stand | Nachweis |
|---|---|---|
| Kein Schaden vor dem Kontaktframe (Nahkampf und Geschosse) | umgesetzt, getestet | `melee_core` 1159, `melee_weapons` 200, `melee_visual_contact` 242 |
| Individuelle Trefferreaktionen, Schildrichtung, Ausdauer, Wunden, Moral, Reichweite, Fußkontakt, Übergänge | umgesetzt, getestet | `melee_core`, `melee_visual_contact`, `melee_tracks` (19 Bewegungen, 18 Deckungen) |
| Trefferpause nach Aufprallenergie, Kamerastoß | umgesetzt, getestet | `melee_core`, `melee_camera` 75 |
| Schaden nur über das gemeinsame Modul (D-042) | umgesetzt, getestet; Merge von `cae920a` (Troops) | `melee_core`, `combat_formula` 68 |
| Waffen als Daten, epochenunabhängig (Nahkampf, Wurf, Bogen, Armbrust, Schleuder) | umgesetzt, getestet | `melee_weapons` |
| Ereignisse für den Ton (hit/draw/release mit Material A/B, Energie, Position, Waffenklasse) | umgesetzt, getestet | `melee_weapons`, `melee_feedback` 59 |
| KI-Duelle kommen zur Entscheidung (Öffnungen, Ausrichten, Schildarm) | umgesetzt, getestet | `melee_core` |
| Bestand | getestet | `combat_actions` 314, `unarmed_combat` 81, `combat_model` 230, `city_trade` 169, `village_childhood` 516, `natural_motion` 116, `childhood_integration` (über `check_prototype.py`) PASS |

Befehle: `python3 tools/check_prototype.py --godot <Godot 4.7.2> --only <Gruppe> --keep-going --report <Ordner>`; Gruppen `melee_tracks, melee_core, melee_visual_contact, melee_feedback, melee_camera, melee_weapons, combat_formula`.

## Nicht nachgewiesen

- **Gerendert:** Die Bildfolgen zum aktuellen Stand sind nicht erzeugt worden (der Renderlauf wartete bis zum Abschluss in der gemeinsamen Render-Warteschlange). Es gibt in diesem Branch keine Bilder; die in `LEVEL_A_MELEE.md` Abschnitt 4 beschriebenen Folgen stammen aus einem früheren Lauf vor diesen Änderungen und liegen nur im Arbeitsverzeichnis der Sitzung. Neu erzeugen:
  `MELEE_EVIDENCE_OUT=<Ordner> MELEE_EVIDENCE_COMMIT=<sha> xvfb-run -a -s "-screen 0 960x720x24" godot --path prototype --fixed-fps 60 --resolution 960x720 --script res://tests/melee_evidence_render.gd`, danach `python3 tools/melee_evidence_sheets.py <Ordner> <Ziel>`. Der Renderer selbst (zwei neue KI-Sequenzen, Tondatensätze je Sequenz) ist in dieser Fassung **ungetestet**.
- Die neuen Posen (hängender Schild, weggerissener Schild) sind nur geometrisch gemessen, nicht im Bild beurteilt.
- Kein vollständiger Suite-Lauf und kein Motion-Gate-Lauf auf diesem Stand; `action_world` war bei Abschluss nicht schlüssig (ein Lauf außerhalb des Test-Runners teilte sich den Spielstand mit anderen Sitzungen und ist deshalb ungültig).
- Kein Gerätelauf (Fold7).

## Offen (nächste Schritte)

1. Bildfolgen rendern, sichten, mit D-038-Metadaten in `docs/34_melee_level_a/evidence/` ablegen; Abschnitt 4 der Dokumentation anpassen.
2. Vollständige Suite und Motion-Gate laufen lassen; Sichtfreigaben für die geänderten Posen.
3. Fernwaffen sichtbar machen: Zieh-/Wurfposen, Lösungsframe vermessen, Geschossdarstellung, KI-Einsatz.
4. Legionär gegen Legionär kommt kaum zur Entscheidung (Scutum deckt frontal alles).
5. Dorf-Spielerpfad (`combat_actions.hit_damage`) auf `combat_balance.json` umstellen – ändert die Balance der Überfallgegner (Entscheidung Lead/Auftraggeber).
6. Balance (Troops-Datei): Pfeil stärker als Gladius-Hieb auf Ungerüstete; Kleidung ohne Schutzwert; Helme in den Kits.
7. Echte Tonaufnahmen statt der synthetisierten Platzhalter; Anschluss von `play_impact` durch die Ton-Sitzung.
