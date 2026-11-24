# AP-2 · Bestehende Brückenschritte als Missionsdaten

Stand: 24.11.2026. Ausgangspunkt ist `handoff/sol-20261124` bei
`94bb7cdd76a3fe2577610eac8da6948e29b0faab`.

## Änderung und Save-Vertrag

Neun bereits spielbare Brückenschritte liegen jetzt in sieben Missionsdateien:

| Datei unter `prototype/assets/story/missions/band1/` | Unveränderte Schritt-IDs | Fundstelle im Originaldrehbuch Band 1 |
|---|---|---|
| `I-02.json` | `i02_basket`, `i02_correct` | „I-02 · Der falsche Korb“, Tabelle 5 |
| `I-08.json` | `i08_tracks`, `i08_report` | „I-08 · Hufspuren im Regen“, Tabelle 11 |
| `I-10.json` | `i10_choice` | „I-10 · Die Nacht der Reiter“, Tabelle 13 |
| `I-11.json` | `i11_forge` | „I-11 · Die Schmiede im Feuer“, Tabelle 14 |
| `I-12.json` | `i12_father` | „I-12 · Der letzte Weg des Vaters“, Tabelle 15 |
| `I-13.json` | `i13_morning` | „I-13 · Morgen ohne Stimmen“, Tabelle 16 |
| `I-14.json` | `i14_oath` | „I-14 · Der Schwur“, Tabelle 17 |

Quelle: Produktionsfassung 1.0 vom 23.11.2026,
`IMPERATHEN_Drehbuch_Band_1_DAS_FEUER_VON_VALDORA(1).docx`,
SHA-256 `91b8185e0be6d1b79119c8791735d1ca7df570c0f9ddebc4ff11cad242b6a3f2`.
Die Originaldatei und ihre Volltextextraktion sind nicht Bestandteil des Repositorys.

Jede neue Missionsdatei enthält `steps: []` und ein separates `bridges`-Array.
`index.json` listet alle Missionsdateien weiterhin einmal in Missionsreihenfolge;
die neuen leeren `steps`-Arrays verändern die bestehende Kindheitsfolge nicht.
`MissionData.bridge_steps("band1")` lädt ausschließlich die Brückendaten in einen
eigenen ID-Katalog. Doppelte IDs oder widersprüchliche Missionszuordnungen lösen
einen Fehler aus.

`village_childhood.gd::_screenplay_step` enthält weiterhin genau dieselben
Auslösebedingungen, Sperren und Prioritäten. Nur die neun Datenliterale sind
durch Kopien der geladenen Dictionaries ersetzt. Jede Rückgabe ist wie zuvor
eine eigene veränderbare Ansicht; ein Leser kann dadurch nicht den gemeinsamen
Katalog beschädigen. Die I-03- und I-07-Brücken bleiben in diesem Arbeitspaket
an ihrer bisherigen Stelle im Code.

Es gibt keine neuen Schritt-IDs, Gegenstands-IDs oder gespeicherten Zustände.
`childhood.completed` behält seine 35 Indizes, der Welt-Save bleibt Schema v5
mit Envelope und `screenplay.version` bleibt 3. Deshalb benötigt diese reine
Auslagerung keine neue Migration. Die vorhandene v2→v3-Migration bleibt erhalten.

**Ergänzungen:** Die bereits im Handoff enthaltenen verdichteten Spielaufgaben
und verbindenden Dialoge sind weiterhin bestehende Ergänzungen zum Drehbuch.
Die Tabellenfundstellen belegen den Missionsrahmen und werden nicht als Beleg
für jede einzelne Spielformulierung ausgegeben. AP-2 fügt keine neue Handlung
oder Dialogzeile hinzu und behauptet keine vollständig inszenierten Missionen.

## Vorher/Nachher-Nachweis mit echter Godot-Laufzeit

Vor der ersten Änderung wurden die Daten mit
`4.7.2.stable.official.ed1daf0bf` aus dem unveränderten Handoff geladen und die
Ergebnisse gespeichert. Nach der Auslagerung wurde derselbe Aufruf wiederholt.
Die gespeicherte Referenz liegt unter
`prototype/tests/fixtures/mission_bridge_data/handoff_runtime.json` und wird
nicht durch den Test neu erzeugt.

Der Vergleich umfasst:

- alle Felder der 35 Stammschritt-Dictionaries, einschließlich Texte;
- sämtliche Gegenstandsübergaben und bisherigen Missionszuordnungen;
- alle zwölf Brückenrückgaben, einschließlich der nicht ausgelagerten I-03-/I-07-Schritte;
- die leere Rückgabe sowie 126 aufgezeichnete Grenz- und Prioritätsfälle des Selektors;
- den Schutz vor Änderungen am Katalog durch einen Leser der Rückgabe.

Die Serialisierung verwendet auf beiden Seiten
`JSON.stringify(value, "", true, true)` und einen Vergleich der UTF-8-Bytes.
Alle 16 verglichenen Serien sind bytegleich. Der vollständige Vergleich mit
Bytezahlen und SHA-256-Werten steht in
[`evidence/ap2_runtime_comparison.json`](evidence/ap2_runtime_comparison.json).

| Serie | Ergebnis | SHA-256 des vollständigen Stammschritt-Arrays |
|---|---|---|
| Vorher und nach AP-2 | bytegleich, 35 Schritte | `95e6b6b67f9d1bc2e50b44ba68e2cf7a319978ca7d29c63ef2f9b868b5b37fb6` |

Der Vorher-Hash von `village_childhood.gd` ist
`de98a2ada189ae2e7273e198c113ed7563c69af3bd4e6cb0e7637b273a69613a`.
Die vollständige Fixture hat SHA-256
`0c86a605fc43f531c8edd9e792a4b7dae09151de189f537b46d22b6821aed737`.

Der Testmodus `--exact-runtime` prüft zusätzlich zum dauerhaften Regressionstest
alle Stammschritt-Felder bytegenau. Er dient dem getrennten AP-2-Nachweis vor
den ausdrücklich beauftragten AP-1-Textkorrekturen. Der normale Regressionstest
prüft dauerhaft die unveränderlichen IDs, Indizes, Übergaben, Missionszuordnungen
und vollständigen Brücken-Dictionaries. Eine spätere bewusste Textkorrektur an
einem Stammschritt soll nicht die historische Vorher-Fixture überschreiben.

```bash
/opt/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --path prototype \
  --script res://tests/mission_bridge_data_test.gd -- --exact-runtime
```

Ergebnis dieses gezielten AP-2-Laufs: **215 Prüfungen, 0 Fehler**.
Originalausgabe: [`evidence/ap2_exact_runtime.log`](evidence/ap2_exact_runtime.log).
Die Python-Gesamtprüfung ergab **153 Tests, alle grün**. Der abschließende Engine-Gesamtlauf ist ebenfalls grün: **62/62 Gruppen**,
Godot `4.7.2.stable.official.ed1daf0bf`, keine Fehler.
Nachweise: [`evidence/ap2_engine_report.json`](evidence/ap2_engine_report.json)
und [`evidence/ap2_python.log`](evidence/ap2_python.log).

## Aufgezeichnete Spielstände

Drei v5-Envelopes wurden noch vor dem Refactor mit echten `WorldModel`-Befehlen
erzeugt und durch `save_game` geschrieben. Sie enthalten ausschließlich erzeugte
Testpartien. Der neue Test lädt diese unveränderten Dateien, prüft den gesamten
Kindheitsfortschritt und die Marcus-Wahl, führt den nächsten tatsächlichen
Befehl aus und prüft einen weiteren Save/Load-Durchgang.

| Fixture in `prototype/tests/fixtures/mission_bridge_data/` | Aufgezeichneter Zustand | SHA-256 |
|---|---|---|
| `handoff_i02_correct_v5.json` | Falscher Korb; Korrektur noch offen | `8ad49b99121ff1f08f913f2be242d18cc7117d1eacf037aa0a878edf563c0930` |
| `handoff_i08_report_v5.json` | Hufspuren untersucht; Bericht noch offen; Marcus-Wahl „Rivale“ erhalten | `8dd80df9e3018028dd8f587c9870f33a6a4cff0b5b392ce9d980d0342fddd5be` |
| `handoff_i10_choice_v5.json` | Alle 35 Stammschritte abgeschlossen; Nachtentscheidung noch offen | `952af7175b901a9f20575145b1575f7b709c9e558f6e26862939f68804a28d01` |

Dies sind Aufzeichnungen des genauen Handoff-Commits, keine vorgetäuschten
Spielstände von Heinz und keine nachträglich als „Build-7-Datei“ bezeichneten
Daten. Die bereits vorhandenen Tests für frühere Save-Versionen und die
v2→v3-Migration laufen weiterhin im Pflicht-Gesamtlauf.

## Sichtbare Änderungen und Grenzen

AP-2 ändert keine sichtbaren Texte, Figuren, Kamera, Materialien oder Geometrie.
Der bytegleiche Laufzeitdatenvergleich ist hier der unmittelbare
Regressionsnachweis. Die gesonderte Begleiteränderung AP-1 benötigt weiterhin
echte Vorher/Nachher-Bilder aus identischer Kamera. Diese Datenauslagerung
belegt weder neue Spielzeit noch Android-FPS oder Wärmeverhalten.
