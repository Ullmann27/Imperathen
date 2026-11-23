# Frühere Kindheits-Spielstände aus e573550

Diese drei Dateien wurden mit dem **vollständig unveränderten Skriptbaum** des
Commits `e5735509622c9a94564dc5fe21257c07074f9df5` erzeugt. Dafür wurde
`git archive <commit> prototype/scripts` in ein kleines getrenntes Godot-Projekt
extrahiert. Der Generator verwendete die ursprüngliche `WorldModel`-Klasse und
deren wirkliche Methoden `new_game`, `execute`, `advance` und `save_game`.
Die Erzeugung lud keine Module aus dem bereits zusammengeführten Arbeitsbaum.

Es wurden keine Fortschritts-, Rollen-, Lohn-, Todes- oder Zeitfelder von Hand
gesetzt. Die Figurenposition wurde für die einzelnen Begegnungen ausdrücklich
über `set_player_position` gewählt; diese Fixtures messen keine Geh- oder
Spielzeit. Die originale Weltkennung und die originalen Hash-Umschläge bleiben
unverändert erhalten.

| Datei | Tatsächlich erzeugter Zustand |
| --- | --- |
| `base_childhood_start_e573550.json` | Originaler `new_game("italia", true, true)`-Anfang: Mutter Antonia, Vater Sextus, Schmied Quintus, Schema 5, keine abgeschlossene Aufgabe. |
| `base_childhood_mid_work_e573550.json` | Zwölf gültige Aufgaben samt nötigen Begegnungen erledigt; `begin_forge_bellows` wirklich angenommen; 3,25 Sekunden am Blasebalg gearbeitet, Arbeit noch nicht abgeschlossen. |
| `base_childhood_pending_unarmed_e573550.json` | Am Übungspfahl eine linke Gerade tatsächlich aufgelöst; eine zweite angenommen und nur 0,10 Sekunden simuliert. Ein Übungstreffer, zweiter Schlag noch nicht aufgelöst. |

Die mittlere Arbeitsfixture stammt aus derselben Partie wie die Startfixture.
Die gespeicherten Befehlskennungen beginnen mit `fixture_meet_` und
`fixture_step_`; der Arbeitsbeginn heißt `fixture_work_start`. Die Kampffixture
verwendet `fixture_first_attack` und `fixture_pending_attack`. Dadurch lässt
sich nach der Migration auch die unveränderte Wiederholungssperre testen.

`base_childhood_provenance.json` enthält Quellcommit, tatsächliche Enginefassung,
SHA-256 der unveränderten Dateien und Nutzdaten sowie die beobachteten
Prüfzustände. Die üblichen Gleitkommareste der originalen Simulationsuhr werden
nicht nachträglich auf glatt dargestellte Dezimalwerte korrigiert.

Der Helfer `res://tests/base_childhood_fixture.gd` lädt diese Dateien über den
normalen öffentlichen Dateilader. Er setzt die neue Partie weder auf alte Ziele
zurück noch bietet er im Produkt einen zweiten Startschalter an. Der aktuelle
Lader ergänzt Schema 6 und den leeren Handelsvertrag; der alte Kindheitsvertrag
einschließlich seiner 3.600-Sekunden-Wirtschaftsuhr bleibt bestehen.

Für tatsächliche Main-Prüfungen werden die originalen Fixture-Bytes in das
isolierte `user://`-Speicherziel kopiert und anschließend über „Fortsetzen“
geladen. Diese Dateien sind Prüfmaterial, keine produktiven Spielerstände.
