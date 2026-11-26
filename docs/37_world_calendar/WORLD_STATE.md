# Gemeinsamer Weltzustand: Kalender, Stammeswelt und Militär

Status: **implementiert und per Test belegt** auf `integ/world-state-20261126` (Vorgabe D-045, mit D-044, D-046 und D-048). Der Stand führt den Kalender aus #98, die Stammeswelt aus #99 und die Truppensimulation aus #100 zusammen. Was davon in der begehbaren Welt gerendert geprüft ist, steht im Abschnitt „Prüfung“. Auf einem Fold7 wurde nichts gemessen.

## 1. Eine Weltzeit

Der Spielstand führt genau eine Uhr: `calendar.clock` (Julianische Tageszahl und Sekunde des Tages, #98). Sie wird nie direkt gesetzt. `world_state.time` ist ihr Zeitbuch:

```
Uhr = Beginn + gebuchte Zeitspannen + abgeleitete Zeitspannen
```

| Ursache | Art | Entsteht durch |
|---|---|---|
| `sleep` | gebucht | Schlaf im Familienhaus, mit dem ein erzählter Kindheitstag endet (bis 6 Uhr des Folgetags) |
| `night` | gebucht | Nachtruhe vor I-10 (bis 22 Uhr desselben Tages) |
| `travel`, `wait`, `rest` | gebucht | `WorldModel.pass_calendar_days(tage, grund, "travel" \| "wait" \| "sleep")` |
| `trade` | gebucht | abgeschlossener Kauf oder Verkauf am Stand (`TRADE_SECONDS` = 30 Minuten, zentraler Balancewert) |
| `jump` | gebucht | Zeitsprungvertrag (sechs Kalenderjahre zu Beginn der Ausbildung), höchstens einmal |
| `season` | gebucht | eine Jahreszeit der Regionalkampagne, bis zum nächsten Jahreszeitbeginn des Kalenders |
| `migration` | gebucht | Tage, die ein älterer Spielstand beim Übergang bereits gelebt hatte |
| `village` | abgeleitet | älterer Dorfalltag: ein Wirtschaftstag ist ein Kalendertag |
| `battle` | abgeleitet | Sekunden des gespielten Talgefechts |

Ein Spielstand, dessen Uhr von dieser Summe abweicht, ist widersprüchlich und wird abgelehnt (`WorldClock.validate`). Dasselbe gilt, wenn erzählte Kindheitstage und gebuchter Schlaf, Kampagnenrunden und gebuchte Jahreszeiten oder Altersstufe und Zeitsprung nicht zusammenpassen.

Alles Zeitabhängige liest diese Uhr:

- **Alter** von Spielfigur und Gefährte aus `calendar.births` (Jahrgenauigkeit, 70 v. Chr. für die Kampagne). `player.age`, `companion.age` und `progress.years_elapsed` bleiben als gespeicherte Werte erhalten, müssen aber der Uhr entsprechen. Der Sechsjahressprung läuft über `TimeJumpContract` mit `CalendarAgeingParticipant`; das Ergebnis muss dem Alter der Uhr gleichen, sonst wird der Sprung verworfen.
- **Stammeswochen**: Tick t ist die Woche ab `1. März des Szenariojahres + 7·t`. `tribes.extra_days` bleibt im Format, muss aber 0 sein; die Stammeswelt zählt keine eigenen Tage mehr. Am 1. Mai 58 v. Chr. ist das Stammesjahr 61 Tage alt, eine neue Kampagne holt deshalb acht Wochen im Bildbudget nach (D-046).
- **Genesung und Beförderung** der Soldaten (Abschnitt 4).
- **Geschichtsrahmen**: Jahr, Herrscher und Anker (`WorldClock.history_frame`).
- **Anzeigen**: HUD, Atlaskopf, Dorfübersicht, Chronikeinträge (`WorldClock.view`, `WorldModel.world_time()`).

`world_seconds` bleibt die technische Simulationsuhr der Dorfsysteme (NPC-Verhalten, Chronikzeitstempel). Sie ist kein Datum und wird von keiner Anzeige mehr als Datum gelesen.

Bekannte Grenze: Die Stammeswelt rechnet intern weiter mit einem Jahr aus 52 Wochen (364 Tage). Ihre Wochenzählung hängt an der Weltuhr, ihre eigene Jahres- und Jahreszeitangabe (`TribalWorld.calendar`) läuft gegenüber dem Kalender um etwa 1,25 Tage pro Jahr nach, über Band I also etwa eine Woche. Die Ankerereignisse der Aufstellung sind auf Wochen gerundet und davon nicht betroffen. Eine Umstellung auf Kalenderjahreszeiten ändert die Simulationsbalance von #99 und ist dort zu entscheiden.

## 2. Speichervertrag v6 und Migration

Ein einziger Schemaschritt bringt Kalender, Stammeswelt und Weltzustand: `schema_version` 6 mit den neuen Schlüsseln `tribes`, `calendar` und `world_state` (`time`, `raids`, `military`).

| Ausgangsstand | Weg | Ergebnis |
|---|---|---|
| v1 bis v4 | bestehende Kette bis v5, dann v6 | wie v5 |
| v5 Kindheit (58 v. Chr.) | `_migrate_world_state` | Uhr = 1. Mai 58 v. Chr. + (erzählter Tag − 1); nach der Nachtruhe 22 Uhr; jeder gelebte Tag als Schlaf gebucht; Rheinaufstellung ab Woche 0, holt bis zur Uhr auf |
| v5 und älter, Laufbahn um 100 n. Chr. | `_migrate_world_state` | eigene Zeitlinie (`origin_year` 100): Frühling 100 n. Chr. + vergangene Jahre + Jahreszeit der Runde; Sprung und Jahreszeiten unter ihrer Ursache gebucht; keine Stammesaufstellung |
| v6 der Zwischenform aus #99 (ohne Kalender) | `_migrate_world_state` | gemeldete `extra_days` werden Reisezeit auf der Uhr |
| v6 ohne Kalender, aber mit `world_state`, oder neuer als v6 | – | abgelehnt, nichts wird repariert |

Die Migration ändert nichts, was der alte Stand bereits entschieden hatte: Alter, vergangene Jahre, Dorf, Wirtschaft, Kampagne, Gefecht und Chronik bleiben wertgleich (Test über alle vorhandenen Schlüssel). Stände um 100 n. Chr. werden nicht auf 58 v. Chr. umgeschrieben (D-044); sie behalten Trajan, die Dakerkriege als eigene Anker und ihre Jahreszählung. Ein bereits geschlagenes Gefecht wird auf den Tag der Übernahme datiert, weil ältere Fassungen kein Gefechtsdatum führten; die Genesung beginnt dort.

Für v5 liegen drei aufgezeichnete Spielstände vor (`prototype/tests/fixtures/mission_bridge_data/`). Für v4 gibt es im Repository keine aufgezeichnete Datei; der Test schreibt eine gespielte Laufbahn im v4-Format (dasselbe Verfahren wie `domain_test` und `tribal_save`).

## 3. Buchungen zwischen Dorf und Stammeswelt

`world_state.raids` hält je Dorfüberfall, den eine Gruppe der Stammeswelt trägt, einen Beleg. Bisher ist das die geschützte Nacht I-10: Sobald der Überfall im Dorf beginnt, bricht die Reitergruppe in der Stammeswelt auf (`commit_story_raid`, Anlass `quest_dispute`, Quelle `mission:I-10`); ist er im Dorf ausgespielt, meldet die Brücke Ergebnis, Gefallene und Beute genau einmal (`apply_raid_result`). Das Dorfledger bleibt für die Güter des Dorfes zuständig, das Stammesledger bucht die gemeldete Beute. Ein Beleg mit abweichender, doppelter oder wieder geöffneter Buchung wird abgelehnt.

Dabei wurde ein Fehler aus dem Zusammenspiel behoben: Chronik und Ledger der Stammeswelt wurden nur am Wochenende gekürzt. Eine Buchung zwischen zwei Wochen (gespielter Überfall, Tat der Spielfigur) konnte ein volles Ledger überlaufen lassen; die Weltprüfung verwarf dann die gesamte Aktion, hier die Entscheidung in I-10. `TribalWorld.trim` läuft jetzt nach jedem solchen Schreibzugriff.

Die übrigen Überfälle der älteren Dorfschleife und die von der Stammes-KI selbst geplanten Züge gegen Valdora sind noch nicht verbunden (Plan in `docs/34_tribes/STAMMESWELT.md`, Abschnitt 8).

## 4. Soldaten auf der Weltzeit

Das Gefecht bleibt die Quelle der Soldatenidentität (#100). `world_state.military` speichert nur Musterungstag, Gefechtsende und Beförderungen. Der Stand eines Soldaten an einem Tag wird abgeleitet: `SoldierRoster.recover(Gefechtsakte, Tage seit Gefechtsende)` und danach die Beförderungen bis zu diesem Tag (`WorldState.soldier`, `WorldModel.soldiers()`). Es gibt keine zweite Kopie, die der Gefechtsakte widersprechen könnte; ein Gefallener bleibt gefallen, gleich wie viel Zeit vergeht oder wie oft gespeichert und geladen wird.

`WorldModel.promote_soldier(uid, stufe, bestand, befugnisse)` befördert nur nach dem Gefecht, nur genesene, lebende, nicht ausgeschiedene Soldaten, frühestens 90 Tage nach der vorigen Beförderung (`MIN_DAYS_IN_GRADE`, zentraler Balancewert), und nur über den Aufstiegsweg des Truppenkatalogs (Erfahrung, Befugnis, Ausrüstung, Epoche). Der Speichervertrag lehnt Beförderungen Verwundeter, Gefallener oder Ausgeschiedener, Sprünge über Stufen und zu kurze Dienstzeiten ab.

Offen: Das Talgefecht ist ein Prüfstand mit festem Szenariojahr 58 v. Chr. (`BattleModel.VALLEY_SCENARIO`), wird aber bisher nur in Laufbahnen um 100 n. Chr. erreicht. Der Katalog verweigert dort Beförderungen zu Recht, weil die Zielstufen in dieser Epoche nicht gelten. Eine gewährte Beförderung ist deshalb über den Weltzustand getestet, nicht über einen durchgespielten Kampagnenweg. Das Gefecht sollte sein Jahr von der Weltuhr erhalten, sobald die Kampagne von 58 v. Chr. das Erwachsenenkapitel erreicht (Paket #100). Auswirkungen von Rekrutierung, Verwundung und Tod auf die Siedlungen (D-043) sind nicht gebaut.

## 5. Personenkennungen

`PersonRegistry` gibt jeder Person genau eine Kennung `<Raum>:<lokale Kennung>`:

| Raum | Personen | Quelle |
|---|---|---|
| `pc` | Spielfigur und Gefährte (`pc:player`, `pc:companion`) | Weltmodell |
| `vil` | Bewohner Valdoras | Verhaltensroster, Dorf-NPCs, Wirtschaft |
| `frt` | Personen des älteren Grenzkapitels | `frontier_chapter` |
| `trb` | Personen der Stammeswelt | `tribes.persons` |
| `sol` | Soldaten des Gefechts | `SoldierRoster`-Kennungen |

Die Module behalten ihre lokalen Kennungen; das Register bildet sie ab und löst bekannte Doppelnennungen auf (`vil:marcus` → `pc:companion`, Stammesziel `player` → `pc:player`). Geprüft wird beim Speichern und Laden: gültige Kennungen, keine Person doppelt, jedes Milizmitglied ist ein Bewohner, jede Person des Beziehungsgraphen ist eine Person des Registers. Alter stehen nicht im Register, sie folgen der Uhr; das Alter eines Soldaten zählt vom Musterungstag.

Grenze: Die Kennungen werden beim Lesen gebildet, nicht in die bestehenden Datensätze geschrieben. Ein Bewohner, der Soldat wird, ist noch nicht als dieselbe Person verknüpft, weil das Gefecht seine Soldaten selbst erzeugt.

## 6. Beziehungsgraph

Der Graph `tribes.relations` (`ActorRelations`: gerichtete Kanten zwischen Gruppen und Personen, mit Erinnerungen) ist Teil des Spielstands. Werte ändern sich nur über `ActorRelations.apply` mit einer Ereigniskennung oder über das langsame Verblassen. Schreiben darf:

- die Stammessimulation selbst (immer mit Ereignis);
- alles andere ausschließlich über das Weltmodell: `WorldModel.relation_event(person, gruppe, art, notiz)` für eine Tat einer Person gegenüber einer Gruppe und `WorldModel.mission_dispute(a, b, quelle, notiz, wochen)` für einen Streit aus einer Mission oder Quest (D-048: kein Konflikt ohne gespeicherten Anlass; die Quelle muss mit `mission:` oder `quest:` beginnen).

Ein Test durchsucht die Skripte: Nur `tribal_world.gd` ruft die schreibenden Funktionen des Beziehungskerns auf, und kein Skript ändert Kanten direkt.

Grenze: Kameradschaft der Soldaten (#100, in der Gefechtsakte) und das soziale Gedächtnis der Dorf-NPCs (`npc_social_memory`) bleiben eigene Speicher ihrer Module. `relation_event` nimmt bisher nur Taten der Spielfigur an, weil nur sie ein Ziel der Stammeswelt ist.

## 7. Behobene Kalenderfehler

Aus dem Integrationsplan in [WORLD_CALENDAR.md](WORLD_CALENDAR.md):

| Punkt | Fehler | Stand |
|---|---|---|
| 1–3 | Schema, Migration, Altersprüfung | umgesetzt (Abschnitte 1 und 2) |
| 4 | Legacy-Sprung ohne Vertrag | über `TimeJumpContract`; die Chronik nennt Datum und nicht simulierte Bereiche |
| 5 | Regionalkampagne rechnet `100 + turn/4` | die Runde bucht ihre Jahreszeit auf der Uhr; der Atlas zeigt das Datum der Uhr; `summary.year` zählt ohne Jahr null |
| 6 | „−58 n. Chr.“ im Dorf, 94 n. Chr. im Atlas für junge Spielfiguren, feste Jahresliterale im Vorspann | Anzeigen lesen die Uhr bzw. `WorldCalendar.format_year` |
| 7 | Jahr 0 aus `start_year + years_elapsed`; „Trajan“ in 58-v.-Chr.-Ständen; Trajan-Anker in der Kampagne | Jahr der Uhr; Herrscher und Anker aus der Ära-Registry, für Stände um 100 n. Chr. eigene Einträge |
| 8 | Texte mit Trajan oder späteren Namen | Decimus nennt Trajan nur, solange Trajan am Weltdatum regiert; Atlasregionen wählen Name und Notiz nach Registry oder Jahr (`AtlasData.region_view`) |
| 10 | Datendateien fehlen im Export | Ära-Registry, Stammesaufstellung und Missionszeitleiste in den Exportfiltern und im APK-Prüfer |

Nicht umgesetzt: Punkt 9 (Delegation von `LifePathPolicy`, Ausblenden von Stadtobjekten nach `era_min_ce`, Truppenkatalog nach Weltdatum) und die Dokumenttexte aus Punkt 8 in anderen Ordnern. Die Atlasvarianten für Hispania Ulterior, die vorrömische Eisenzeit, Africa mit Utica, Gandhāra und die Andenküste sind gesetzte Vorgaben ohne geprüfte Literatur und fachlich zu prüfen. Die Meldungen der Regionalkampagne nennen Regionen weiter mit ihrem Namen der Zeit um 100 n. Chr.; eine junge Spielfigur der Kampagne kann dort noch nicht handeln.

## 8. Technik und Quellen

Gewählt ist ein gespeicherter Zustand mit einem Summenbuch je Ursache statt eines Ereignisprotokolls, das beim Laden abgespielt wird: Abspielen bricht, sobald sich die Logik ändert, und ein Summenbuch genügt, um jede Uhrzeit zu erklären und eine zweite Zeitquelle zu erkennen. Abgeleitete Werte (Alter, Genesung, Stammeswoche) werden aus dem maßgeblichen Zustand berechnet und beim Laden geprüft, nicht als eigene Wahrheit gespeichert.

- Speicherarchitektur mit einer Quelle je System, abgeleiteten Daten und Versionsnummer: [Archon Engine, Save/Load Architecture](https://forgottenhistory.github.io/Archon-Engine/Docs/Engine/save-load-architecture.html)
- Abspielen von Ereignissen als Fehlerquelle bei Spielständen: [Eliminating Event Replay to Prevent Save Desync](https://drwjf.github.io/roc/notes/11-oos)
- Determinismus und Reihenfolge: [Riot Games, Determinism in League of Legends](https://technology.riotgames.com/node/68), [TimeSteward](https://github.com/adamnemecek/time-steward/blob/master/README.md)
- Tageszählung und Jahreszählung ohne Jahr null: [Julian day](https://en.wikipedia.org/wiki/Julian_day), [Astronomical year numbering](https://www.wikipedia.org/wiki/Astronomical_year_numbering)

## 9. Prüfung

Gruppe `world_state` in `tools/check_prototype.py` (`prototype/tests/world_state_test.gd`): eine Uhr und ihre Leser, kein Jahr null über 80 Jahre, einmalige Alterung bei Sprung, Jahreszeiten, Reise, Speichern und Laden, Zeitursachen, einmal gebuchter Überfall auf dem aufgezeichneten Stand vor I-10, Soldaten auf der Weltzeit, drei aufgezeichnete v5-Stände, eine v4-Laufbahn, die Zeitlinie um 100 n. Chr., Personenkennungen und der Schreibweg des Beziehungsgraphen. `tribal_save` folgt der Uhr.

Lauf: `python3 tools/check_prototype.py --godot <godot> --only world_state tribal_save tribal_world tribal_atlas world_calendar era_registry time_jump_contract --report <ordner>`.

Bildnachweis für HUD und Atlaskopf: `prototype/tests/world_date_review.gd` startet eine neue Kampagne über die Produktionsszene und speichert HUD und Atlas; dasselbe Skript läuft auch auf dem Stand vor der Integration.
