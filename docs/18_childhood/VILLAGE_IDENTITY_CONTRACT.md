# Dorf, Haushalte und Einwohneridentitäten

Stand: 23. November 2026. Chat B, Agent 2. Ausgangscommit `2909040deeb33b99ad4180b884b38921f28233a9`; anschließend mit dem parallelen Koordinatorstand `e5735509622c9a94564dc5fe21257c07074f9df5` zusammengeführt.

## Tatsächlich implementierter Umfang

Der erste Chat-B-Schritt ergänzte die 13 Wohnhausinstanzen des Ausgangsstands um zwei südliche Häuser. Die Zusammenführung erhält inzwischen alle 20 Wohnhäuser des Koordinatorstands. Unsere beiden südlichen Haushalte verwenden dieselben Hauskennungen; sie werden nicht nochmals erzeugt. Die neuen Häuser belegen weder den bestehenden Baugrund noch den Wagenplatz. Eine texturierte Gasse bei z = 28,7 verbindet ihre Eingänge mit dem südlichen Hauptweg und der Oststraße. Rufinas bisher durch dieses Gebiet verlaufender Weg führt jetzt um die Hausgruppe herum.

Alle 20 Häuser behalten ihre begehbare Grundausstattung. Drei Häuser besitzen für den neuen Kindheitsbogen eine eigene Einrichtung:

| Haushalt | Szenenkennung | Hausmitte x/z | Eingang außen x/z | Verwendung |
| --- | --- | --- | --- | --- |
| Familie | `south_weaver_home` | −5 / 24 | −5 / 27,65 | Julia und Silvanus; gemeinsamer Tisch, Brot, Geschirr, gefüllter Krug, Becher, Vorratsbehälter, Elternbett und gesonderte Schlafmatte |
| Nachbarschaft | `south_baker_home` | −14 / 24 | −14 / 27,65 | Wohnraum und Backhaushalt am selben Weg; keine zusätzliche Einwohnerbuchung |
| Schmiede | `smith_home` | 38 / −26 | 34,35 / −26 | Sextus; Werkbank, Amboss, Handwerkzeuge, Wasser und Vorräte |

Die tatsächlichen Innenböden des Modells liegen 0,3925 m über Gelände. Der vorherige regionale Kollisionsaufbau besaß dort nur Wände. `childhood_neighborhood.gd` ergänzt für diese drei Häuser durchgehende Böden, eine sichtbare steinerne Eingangsschräge, passende Kollisionskeile, Türrahmen sowie Tisch- und Bankkollisionen. Die Kollisionsöffnung entspricht der 1,12 m breiten Modelltür. Die bestehende Spieler-Kapsel kann ohne Sprung hinein- und wieder hinausgehen.

Für diese drei Häuser werden die während der parallelen Arbeit ergänzten Standardböden und Standardmöbel im modernen Kapitel gezielt abgeschaltet. So liegen weder doppelte Böden noch doppelte Möbelkörper übereinander. Beim Laden des früheren Kindheitsbogens kehrt dessen ursprüngliche Einrichtung wieder zurück. Ein tatsächlicher Wechsel vom früheren Save zurück zur neuen Partie gehört zur Identitätsprüfung.

Die ausgelieferte GLB bündelt Bauteile nach Material: Dachholz und Möbel befinden sich teilweise im selben Mesh. Deshalb werden die für eine Innenansicht nötigen Flächen einmal aus genau dieser vorhandenen Geometrie ausgewählt. Material, UVs, Normalen und Instanztransformationen bleiben erhalten. Beim Eintritt wird die betreffende obere Gebäudeansicht ausgeblendet; Tisch, Bank und Wände bleiben stehen. Beim Austritt erscheint das Originaldach wieder. Die Original-GLB und die reproduzierbare Blenderquelle `tools/art/build_architecture.py` wurden nicht verändert oder ersetzt.

## Eine Person, eine gespeicherte Identität

| Gespeicherte ID | Rolle in der Kindheit | Darstellung |
| --- | --- | --- |
| `julia` | Mutter und Bäuerin | Bestehende Wirtschaftsperson; kein neuer Mutter-NPC |
| `silvanus` | Vater und Lastenträger | Bestehende Wirtschaftsperson; kein neuer Vater-NPC |
| `sextus` | Schmied, enger Freund des Vaters und Mentor | Bestehende Wirtschaftsperson; kein zusätzlicher Schmied mit anderer ID |
| `marcus` | Freund | Der vorhandene Gefährte bleibt zuständig |

`village_life_world.gd` rendert jede Wirtschaftsperson genau einmal in seinem nach ID indizierten `actors`-Register. Das Modell erhält `resident_id` und `identity_source` als Metadaten. Eine angezeigte Familienrolle ist keine zweite Beschäftigung, keine zweite Ressourcenquelle und kein eigener Bevölkerungsdatensatz. Der Hintergrundbevölkerung steht `set_excluded_ids(Array)` zur Verfügung, damit die Integration eine dort ebenfalls vorhandene Identität gezielt unterdrücken und später wiederherstellen kann.

Die gespeicherte Wirtschaftsperson entscheidet über `alive`. Tote Personen bleiben unsichtbar und ihre Kollisionskörper werden deaktiviert. Ein Eintrag in der Miliz entfernt dieselbe Person aus der zivilen Darstellung. Das Laden, der Grafikprofilwechsel und das Betreten eines Hauses dürfen diese Entscheidungen nicht umkehren.

Die moderne neue Partie zeigt 26 Hintergrundbewohner sowie 14 autoritative Wirtschaftspersonen und Decimus. Diese 41 Bürger besitzen jeweils genau einen Kollisionskörper auf der gemeinsamen Schicht 8. Marcus wird zusätzlich als bestehender Gefährte geführt: insgesamt 42 benannte NPC-Instanzen neben dem Spieler. Diese Darstellungszahl ist keine Behauptung von 42 Arbeitskräften. Die vorhandenen Hintergrundbewegungen und das Kampfsystem bleiben erhalten. Das ist kein Nachweis einer vollständigen stadtweiten Navigation aller Figuren.

## Sichtbar ausgeliehener oder erworbener Übungsstab

`village_person.gd` bietet `set_practice_staff_equipped(bool)` als kleine Darstellungsschnittstelle. Die Welt leitet das Flag aus dem vorhandenen Zustand `childhood.equipment.practice_staff` ab: `loaned` und `owned` zeigen den Gegenstand, `none` und `returned` entfernen ihn beim Kind. Der Setter vergibt keinen Besitz und verändert keine Kampfwerte, Animationen oder Bewegungsparameter.

Verwendet wird ausschließlich das bereits ausgelieferte, an die rechte Hand gebundene Skin-Mesh `PracticeBlade`. Es ist in allen vier Detailstufen des Hero-Modells und des vorhandenen Ersatzmodells enthalten. Beim Hero handelt es sich um einen kurzen Übungsstab von etwa 0,48 m Länge. Ein langer Kampfstab oder zusätzliche Waffen werden damit nicht behauptet. Die Original-GLBs und ihre Animationen bleiben unverändert.

Die Darstellung behält das Flag bei Modell-/LOD-Wechseln und prüft es bei Clipwechseln erneut. Ohne ausdrücklich getragenen Gegenstand bleibt die frühere Erwachsenenregel erhalten: Ab 18 Jahren ist das bisherige Übungsobjekt bei `attack`, `train` und `block` sichtbar und wird ansonsten verstaut. Ein Gefährte erhält durch das Spielerflag keinen zusätzlichen Gegenstand.

## Aufenthaltsorte und Interaktion

Die einzige fachliche Quelle der x/z-Aufenthaltsorte bleibt `VillageLife.actor_position(data, id)`. Der Erzählbaustein kann dort seine zeitabhängigen `Childhood.actor_position`-Ergebnisse bereitstellen. Die Darstellung ergänzt für Personen innerhalb der drei Haushalte ausschließlich die sichtbare Bodenhöhe; sie vergibt keine Arbeit, keine Erfahrung und keinen Lohn.

Die mit Agent 1 vereinbarten freien Standplätze sind Julia bei −4 / 24,9, Silvanus bei −6,8 / 24,8 sowie Sextus bei 37,2 / −27,3. Diese Punkte wurden mit der tatsächlichen Spieler-Kapsel gegen Hauswände und Möbel geprüft. Weitere Arbeits- und Besuchsorte werden von der Geschichte festgelegt. Ein Tätigkeitswort wie „trinken“ allein wird nicht als fertig animierte Trinkhandlung ausgewiesen. Krüge, Wasser, Becher und Geschirr sind sichtbare Gegenstände; eine neue Arm-/Trinkanimation gehört zur abgestimmten Animationsarbeit.

Die tatsächliche Marktgegenstandsprüfung fand Cassia und Antonia zunächst im Verkaufstisch. Die fachliche Positionsquelle wurde gemeinsam mit Agent 1 auf die freien Plätze 24,3 / 25,3 und 25,7 / 25,3 korrigiert; Darstellung, Handelsreichweite und Erzählziele lesen dieselben Positionen. Der vollständige Weltaufbau prüft alle 15 Personen gegen Hauswände, Möbel und andere feste Einwohnerkörper.

Gespräche im Kindheitsmodus prüfen Sichtkontakt zum verfügbaren Sprecher. Durch eine Hauswand wird kein Familiendialog geöffnet. Die Gesprächskamera muss beim eigenen Sichtstrahl den Kollisionskörper des gewählten Sprechers ausschließen; dafür liefert `actor_collision_rid(id)` die tatsächliche RID.

## Julias gespeicherter Weg zum Schutzort

Die Rettung führt dieselbe Julia aus dem Familienhaus über dessen Tür und die südliche Gasse durch die Nachbartür. Die sechs Wegabschnitte ergeben zusammen rund 15,718 m. `childhood.escort.progress` und `childhood.escort.position` speichern den erreichten Standort; ein bloßer Versatz zur Spielerposition wird nicht verwendet. Die Geschichte begrenzt das Gehen auf 1,35 m/s und verlangt Julias eigene Ankunft im Schutzraum.

Vor jedem aktiven Fortschritt prüft `village_life_world.escort_progress_limit(data, delta)` den nächsten Wegabschnitt mit einer Kapsel von 0,29 m Radius und 1,72 m Höhe. Diese Maße entsprechen Julias vorhandenem Kollisionskörper. Die Form wird entlang der Route gegen Häuser, andere Personen, Spieler und Truppen geführt; dazu gehört ausdrücklich die gemeinsame Bürgerschicht 8. Ein Hindernis gewährt keinen weiteren Fortschritt. Der Aufruf `model.advance(delta, limit)` übergibt genau diese Grenze an die Geschichte. Anschließend projiziert `sync_escort(data, delta)` den akzeptierten gespeicherten Standort und ruft die vorhandene Gehanimation auf. Das Verfahren erzeugt weder eine zweite Bewegungsquelle noch eine zusätzliche Mutterfigur.

`resident_floor_height_at` berücksichtigt die runde Kapselauflage an der Kante zwischen dem erhöhten Innenboden und der steinernen Schräge. Ohne diese Auflage würde eine reine Höhenabfrage unter dem Figurenmittelpunkt den Körper kurz in die Bodenkante drücken und eine ansonsten freie Tür fälschlich blockieren. Die tatsächlich begehbare Route wurde zusätzlich vollständig mit einer `CharacterBody3D` derselben Maße abgelaufen. Das ist ein gezielter Fluchtweg für diesen Abschnitt; eine allgemeine Wegsuche durch das gesamte Dorf ist damit nicht verbunden.

## Schnittstelle für die Integration

`ChildhoodNeighborhood` wird als eigener Node einmal in die bestehende Welt eingebunden:

1. Nach dem Aufbau der regionalen Häuser `build(regional)` aufrufen. Wiederholte Aufrufe erzeugen keine weiteren Innenräume oder Kollisionskörper.
2. Nach Zustandswechseln `sync_state(data)` aufrufen. Maßgeblich ist `data.village.childhood.enabled`. Für andere Spielstände bleiben die zusätzlichen Kapitelansichten und Kollisionen abgeschaltet.
3. Bei Kamera-/Spielerbewegung `update_view(player_position)` aufrufen. Nur das gerade betretene Haus erhält die Innenansicht.
4. Das vorhandene Grafikprofil mit `set_quality(profile)` weiterreichen. Die Innenraumgegenstände besitzen begrenzte Sichtweiten; ihre Funktion und die Kollisionskörper hängen nicht von der Detailstufe ab.

`navigation_target(player, target)` führt ein Ziel im Haus zunächst über dessen Eingang und inneren Türpunkt. Beim Verlassen führt es ebenfalls durch die Tür. Es verhindert insbesondere einen Richtungswechsel zurück nach draußen mitten auf der Eingangsschräge. Dieser kleine Helfer ist keine allgemeine Wegsuche für beliebige Hindernisse zwischen unterschiedlichen Dorfquartieren.

Weitere abfragbare Funktionen sind `house_at(Vector2)`, `floor_height_at(Vector2)`, `resident_floor_height_at(Vector2, radius)`, `entrance_position(id)` und `snapshot()`. Die Geometrie benutzt Meter; Positionslisten im Storyzustand bleiben unverändert serialisierbare Daten.

## Sichtbare Folgen des Überfalls

Die Ansicht liest ausschließlich die gespeicherten Lebenszustände. Nach Silvanus' Tod erscheint am Familienhaus eine kleine Gedenkstelle. Julia wird dort nur genannt, wenn sie im tatsächlich gewählten Verlauf ebenfalls gestorben ist. Bei Sextus' Tod erscheinen eine kleine Gedenkstelle und eine Abdeckung auf dem unbenutzten Amboss. Die Ansicht entscheidet nicht selbst, wer stirbt oder welcher Ausgang gewählt wird. Das Laden einer älteren lebenden Geschichte zeigt wieder deren eigenen damaligen Zustand.

## Ausgeführte Prüfung

Ausgeführt mit lokalem Godot `4.7.2.stable.official.ed1daf0bf`:

```text
godot --headless --path prototype --script res://tests/childhood_neighborhood_test.gd
CHILDHOOD_NEIGHBORHOOD_RESULT checks=138 failures=0

godot --headless --path prototype --script res://tests/childhood_resident_identity_test.gd
CHILDHOOD_RESIDENT_IDENTITY_RESULT checks=101 failures=0

godot --headless --path prototype --script res://tests/childhood_escort_physics_test.gd
CHILDHOOD_ESCORT_PHYSICS_RESULT checks=22 failures=0

godot --headless --path prototype --script res://tests/childhood_equipment_visual_test.gd
CHILDHOOD_EQUIPMENT_VISUAL_RESULT checks=37 failures=0
```

Der Lauf instanziiert die tatsächliche regionale Dorfarchitektur und bewegt eine `CharacterBody3D` mit den vorhandenen Spielermaßen durch alle drei Türen hinein und wieder hinaus. Geprüft wurden Fußhöhe, Boden-/Schrägenkollision, freie Personenplätze, Dachwechsel an tatsächlichen Meshes, unveränderte Wiederholungsinitialisierung, Flächenüberschneidungen der beiden neuen Häuser und die aus gespeicherten Todesfällen abgeleiteten Gedenkstellen. Die Originaldatei und Blenderquelle wurden zusätzlich mit ihren Git-Blobs des Ausgangscommits verglichen; beide sind unverändert.

Die Identitätsprüfung baut die gesamte Spielwelt auf. Sie prüft eindeutige Personen, freie Standplätze, echte Familienböden, durch Wände gesperrte Gespräche, die gespeicherten Todesfälle von Silvanus und Sextus, die überlebende Julia und unveränderte Personen-IDs bei Grafikwechsel. Ein anschließender Wechsel in eine andere Region darf keine unsichtbaren römischen Kollisionskörper hinterlassen. Der Escort-Test prüft zusätzlich den vollständigen freien Weg, Blockade und Freigabe durch echte Kollisionskörper, alle sechs physisch abgelaufenen Abschnitte sowie die exakte Wiederherstellung derselben Julia am gespeicherten Standort.

Die Ausrüstungsprüfung instanziiert die tatsächlichen Figurenmodelle. Sie prüft fehlende, ausgeliehene, gekaufte und zurückgegebene Ausrüstung, einen einzigen vorhandenen Skin-Gegenstand in allen vier LOD-Stufen, unveränderte Bewegungsphase und Geschwindigkeit beim Umschalten, Wiederherstellung vor dem ersten Modellaufbau und die unveränderten Erwachsenen-/Gefährtenregeln. Die fachliche Berechtigung zum Ausleihen und Kaufen bleibt im getrennten Storytest verankert; der Darstellungstest erzeugt keine neue Inventarautorität.

Das ist ein realer Engine- und Physiknachweis. Es ist kein FPS-, Temperatur- oder physischer Android-Gerätenachweis. Die zusammengeführte neue Partie, Dialoge, Save/Load und die endgültigen Android-Artefakte werden separat vom koordinierenden Chat geprüft.
