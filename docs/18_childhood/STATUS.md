# Status I-01 bis I-04 (Branch `feat/i01-three-cups-slice-20261126`)

Stand 26.11.2026, Abschluss auf Anweisung des Auftraggebers. Vier Stufen werden getrennt genannt: **umgesetzt** (Code/Daten im Branch), **getestet** (Headless-Test bestanden), **gerendert** (Engine-Bild liegt vor und wurde angesehen), **offen**.

## Überblick

| Abschnitt | Umgesetzt | Getestet | Gerendert |
| --- | --- | --- | --- |
| I-01 Spielablauf (Becher, Brunnen, Frühstück, VID-A/B/C, Start ohne Geld, kein Kampf-HUD) | ja | ja (`i01_slice`, `i01_flow`) | nur fünf ältere VID-A-Bilder (1280×720, Stand 456aae1); 1384×1536 fehlt |
| I-01 VID-B als Filmszene (Einstellungsgrößen, Reaktionsschnitte, Pausen, Innenlicht, nahtlose Rückgabe) | ja | ja (`i01_flow`: Schnittplan, Linsen, Lichtverhältnis, Rückgabe auf die Spielkamera, Umgebungslicht wiederhergestellt) | **nein** |
| I-03 Besorgungsgang mit Marcus (Gasse, Brunnen, Stand, VID-A/B/C, Erinnerungen, Migration v4→v5) | ja | ja (`i03_slice` 309 Prüfungen, `i03_flow`) | **nein** |
| I-04 Werkstattbesuch (Arbeitswahl, Gespräch am Amboss, VID-A/B, VID-C-Zeile, Requisiten, Feuerschein, Migration v5→v6) | ja | Domäne siehe unten; kein Ablauftest durch das Hauptprogramm | **nein** |
| I-01 bis I-04 als zusammenhängende Folge | Kette I-01 → I-02 → I-03 → Bestellung → I-04 läuft über dieselben Befehle | durch die Modelltests bis zum Probemorgen gespielt | nein |

Kein Bild der neuen Kameras, des Lichts, der Requisiten am Handelstisch oder in der Schmiede wurde bisher angesehen. Positionen der Requisiten sind aus dem Code der vorhandenen Szene abgeleitet (Handelstisch 3 × 1,2 m bei (25, 24), Amboss, Kühltrog, Blasebalg der Schmiede), nicht am Bild geprüft. Vor einer Abnahme müssen die Bilder erzeugt und geprüft werden.

## Bilder erzeugen (schwere Spur, je Aufruf höchstens 12 Minuten)

Das Skript `one.sh` im Arbeitsordner `…/scratchpad/i01/shots/` startet je einen Lauf unter `godot_heavy.lock`. Die Läufe standen beim Abschluss noch in der Warteschlange und wurden beendet. Befehle:

```
xvfb-run -a -s "-screen 0 1384x1536x24" $GODOT --path prototype --rendering-method gl_compatibility \
  --resolution 1280x720 --fixed-fps 60 --script res://tests/i03_flow_test.gd -- --size=1280x720 --capture-dir=<Ordner>
```

Dasselbe mit `i01_flow_test.gd` und mit `--resolution 1384x1536 --size=1384x1536`. Beide Tests schreiben neben den Bildern einen Bericht mit Kamera, Einstellung und Beat je Bild. Für VID-B gibt es zusätzlich das nicht eingecheckte Hilfsskript `zz_vidb_render.gd` (Kopie im Arbeitsordner `…/scratchpad/i01/zz/`), das jeden Beat und Schnitt einzeln aufnimmt, wahlweise ohne Filmlicht (`--rig=off`) für den Vergleich mit gleicher Kamera.

## Tests

Einzelgruppen mit `python3 tools/check_prototype.py --godot $GODOT --only <Gruppe> --keep-going --report <Ordner>`; Ergebnisse des letzten Laufs stehen in der Commit-Nachricht des jeweiligen Commits. Neue Gruppen: `i03_slice`, `i03_flow`, `i04_slice`. Kein vollständiger Suite-Lauf und kein Motion-Gate auf diesem Stand.

## Offen, in dieser Reihenfolge

1. Bilder in 1280×720 und 1384×1536 erzeugen, ansehen, Kameras/Licht/Requisiten korrigieren; Nachweis nach D-038 schreiben.
2. I-04: Ablauftest durch das Hauptprogramm (Film öffnet nach der Übergabe, Skip hält an der Wahl, Requisiten folgen dem Zustand, Krug/Kleinholz in der Hand). Die Tests `chapter_abilities`, `band1_expansion`, `village_childhood` und weitere spielen die neuen Schritte mit ihrer ersten Option; Ergebnis siehe letzter Commit.
3. Zeitmessung (`i01_playthrough_test`) nach den neuen Pausen in VID-B wiederholen; die Zahlen im Sequenzplan I-01 gelten für die alte Fassung.
4. `docs/18_childhood/I04_SEQUENZPLAN.md` fehlt; Inhalt bis dahin in `I-04.json` (`slice`) und `scripts/story/i04_workshop.gd`.
5. Stimmen, Lippenbewegung, Finger-, Trage-, Sitz- und Greifclips fehlen überall. `line_id`/`speaker_id` sind stabil; I-03 und I-04 tragen `voice: "pending_recording"`.
6. Der Originaljunge trägt im Mesh weiterhin Rüstung (zivile Kleidung ist ein eigenes Arbeitspaket, D-032).
7. Spielzeit: jede Mission dauert wenige Minuten, nicht die 30–40 Minuten des Handbuchs.

## Entscheidungen für den Auftraggeber

- `companion.choice` und der feste Vertrauenswert (20 / −5) bleiben als abgeleitete Zusammenfassung der I-03-Erinnerungen bestehen, weil die Weltprüfung damit rechnet. Die vollständige Ablösung gehört zum Akteurkern (D-016).
- Ist Marcus an der Gasse nicht verfügbar, wartet I-03 auf ihn und Julias Bestellung bleibt gesperrt. Alternative: Bestellung ohne Marcus freigeben und das Treffen später nachholen.
- Der aufgezeichnete Vergleichstest `mission_bridge_data` erwartet für die frühere Marcus-Brücke jetzt den neuen ersten Schritt des Besorgungsgangs.
