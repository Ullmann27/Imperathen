# Durchgehende Familienroute

## Zweck und Stand

Dieser separate Review startet die echte Main-Szene über **Neues Leben**. Die korrigierte Familienroute hat am 23.11.2026 die [GitHub-Actions-Abnahme 45206876533](https://github.com/Ullmann27/Imperathen/actions/runs/45206876533) auf dem unveränderten Commit `62adc18e9c7be9f8318ea93aea716a499bdfced7` vollständig bestanden: **77/77 Headless-Prüfungen und 89/89 grafische Prüfungen**, jeweils Engine-Exitcode 0. Alle zwölf tatsächlich gerenderten Stationsbilder wurden einzeln angesehen. Originalberichte, Bilder, Quellenhashes und konkrete visuelle Grenzen stehen unter [CI 1 / VISUAL_REVIEW.md](evidence/family_route/ci1/VISUAL_REVIEW.md).

Zuvor bestand der lokale Lauf **76 Prüfungen** mit dem Profil `balanced`. Er führte vom möblierten Familienhaus durch die echte Tür, über zwei Familienhandlungen und Geh-/Laufabschnitte zum Üben, Speichern und Fortsetzen. Der vollständige lokale Originalbericht liegt unter [03_corrected_pass/action-route-review.json](evidence/family_route/03_corrected_pass/action-route-review.json). Die CI verwendet `low`: Daraus entsteht eine zusätzliche Qualitäts-UI-Prüfung und im grafischen Lauf zusätzlich je eine erfolgreiche Speicherung der zwölf Stationsbilder.

Der Spielcode des lokalen Laufs entspricht `db90dee785cbaef97a5d85357b7b9cda762dc9cd`. Für diesen Lauf waren ausschließlich die beiden Reviewwerkzeuge unter `tools/characters` geändert; der Commit ist deshalb im Manifest ausdrücklich als Basis des Arbeitsbaums bezeichnet. Alle erfassten Quellhashes blieben während des Laufs unverändert. Die folgenden CI-Läufe nutzen die inzwischen veröffentlichten Reviewwerkzeuge im sauberen Commit `62adc18`. Keiner dieser Nachweise ist ein Android-Gerätetest oder eine Messung von Bildrate beziehungsweise Temperatur.

Die früheren 67 erfolgreichen Headless-Prüfungen betrafen den vorherigen Dorfanfang. Sie belegen diese neue Familienroute nicht. Frühere grafische Zwischenläufe waren unvollständig; ein erfasster Lauf endete mit SIGKILL. Verlorene Bilder oder Trajektorien wurden nicht nachgebildet.

## Nachweise der neuen Familienroute

| Versuch | Ergebnis | Beleg |
| --- | --- | --- |
| Unveränderte erste Fassung | SIGKILL nach Station 05; 19 erfolgreiche Prüfungen, unvollständig. Die Ursache des Signals ist nicht belegt. | [01_interrupted](evidence/family_route/01_interrupted/action-route-review.json) |
| Zweiter Lauf derselben Fassung | Regulärer Exit 1: 21 erfolgreiche Prüfungen und eine gemeldete physische Blockade. Der Zielpunkt `(-9,16)` lag im bestehenden Vorratsgebäude. | [02_blocked_waypoint](evidence/family_route/02_blocked_waypoint/action-route-review.json) |
| Korrigierter Prüfweg | Exit 0, `ACTION_ROUTE_REVIEW_PASS`, 76/76 Prüfungen bestanden, vollständiges Speichern und Fortsetzen. | [03_corrected_pass](evidence/family_route/03_corrected_pass/action-route-review.json) |
| CI 1, Headless / `low` | Exit 0, 77/77 Prüfungen, saubere Quelle `62adc18`, unveränderte Quellhashes. | [ci1/headless](evidence/family_route/ci1/headless/action-route-review.json) |
| CI 1, tatsächliche Grafik / `low` | Exit 0, 89/89 Prüfungen, zwölf echte Engine-Bilder; alle angesehen, konkrete Darstellungsgrenzen dokumentiert. | [ci1/graphical](evidence/family_route/ci1/graphical/action-route-review.json) |

Die Blockade des zweiten Versuchs trat bei `(-12.8509,15.1735)` trotz nichtnulliger Joystickauslenkung auf. Die Quellprüfung ergibt an dieser Stelle die Westwand von `ProvisionStore` einschließlich des 0,28-m-Spielerradius. Korrigiert wurde allein der Prüfweg: erst nach `(-13,17.6)`, dann südlich um das Gebäude nach `(-7,18)`. Haus, Rampe, Wände, Bewohner und Spiellogik wurden dafür nicht verändert.

Der bestandene Lauf erfasst **62,5396 m** tatsächlich zurückgelegten Weg, **666 Trajektorienpunkte** und **12 Stationen** bei **66,55 s** Simulationszeit. Der größte horizontale Einzelschritt beträgt **0,0633343 m** bei 60-Hz-Physik. Die gemessene Wanduhrzeit von 68,104 s beschreibt nur diesen automatisierten Headlesslauf; daraus folgt keine Bildraten- oder Android-Leistungsangabe. Das vorhandene Profil war `balanced`.

Am Übungspfahl wurden 21 Kontakte tatsächlich verdient: 14 `jab_left` sowie je einer für `jab_right`, `hook_left`, `uppercut_right`, `headbutt`, `front_kick`, `side_kick` und `high_kick`. Fortsetzen stellte diese 21 Kontakte, die Weltidentität, die erreichte Position sowie die beiden tatsächlichen Familienhandlungen `mother_morning` und `fill_water` mit Haushaltsdenar und Wasserkrug wieder her. Der anschließende Gehabschnitt behielt diesen Fortschritt.

Zu jedem Versuch sind das unveränderte `runtime.log`, `capture-manifest.json` und `action-route-review.json` gespeichert. SHA-256 des erfolgreichen Berichts: `4c5fd189464389d57cee56708daebcc32456da6e66fbe9f77b9700a0bfbf4341`. Die dabei verwendete Routenquelle hat SHA-256 `0f8c7d3e10704c66acf88797f26ca96848e38950ac44d0617678e260fe7df03d`, der damalige Runner `e3cc15d779dfc3d7e7f3ccf12d81d19bb9cd4672bf4d66ccbd1f5b64eff75d04`.

Nach diesem Lauf wurde ausschließlich die Metadatenerfassung des Runners eingeschränkt: `git status` betrachtet nun `prototype` und `tools/characters`, damit neu geschriebene CI-Ausgaben und Dokumentation keinen falschen Hinweis auf geänderte Spieleingaben auslösen. Dieser letzte Metadatenwechsel ist im lokalen Erfolgslauf noch nicht enthalten; die gespeicherten Belege und ihre damaligen Hashes wurden nicht nachträglich angepasst. Die anschließend erfolgreichen CI-Läufe erfassen ihre eigenen vollständigen Quellhashes und melden beide `clean_checkout`.

## Tatsächlicher Weg

Die automatisierte Steuerung beginnt an der regulären Position im möblierten Familienhaus. Sie geht durch die bestehende schmale Haustür und über deren physische Rampe zu Antonia. Die Interaktion und die erste Dialogwahl laufen über echte Touchereignisse. Anschließend geht die Figur zurück ins Haus und erledigt den Wasserauftrag mit der vorhandenen Interaktion. Nach dem erneuten Verlassen des Hauses führt der Weg südlich um das Vorratsgebäude; darauf folgen getrennte Geh- und Laufabschnitte durch die Dorfmitte bis zum bestehenden Übungspfahl.

Dort muss jeder der ersten 14 geraden Schläge tatsächlich genau einen Übungskontakt erhalten. Die weiteren sieben gewählten Techniken werden ausschließlich über ihre dann freigeschalteten UI-Steuerelemente gewählt. Ein erwarteter Zählerstand ist eine Prüfbedingung und wird niemals in den Spielzustand geschrieben. Abschließend öffnet die Prüfung Pause und Speichern, zerstört die Main-Instanz, erzeugt sie neu und verwendet Fortsetzen. Eine kurze weitere Touchbewegung prüft die wieder aufgenommene Steuerung.

Der Neustart betrifft die Anwendungsszene im selben Engine-Prozess. Ein Android-Prozessneustart ist ein eigener Nachweis.

## Methode und Grenzen

- Es werden keine Spielerpositionen, Ausdauerwerte, Queststände oder Technikfreigaben gesetzt. Die Wegpunkte steuern ausschließlich den tatsächlichen Touchstick. Bei einer physischen Blockierung bricht die Prüfung mit der erreichten Position ab.
- Bewegung, Kamera, Gehen/Laufen, Interagieren, Angriffe und die erste Mutter-Dialogwahl verwenden native Touchereignisse. Menübefehle wie Neues Leben, Pause, Speichern und Fortsetzen sowie die Technikwahl verwenden die verbundenen Signale ihrer tatsächlich sichtbaren Buttons. Diese Unterscheidung steht zusätzlich im Aktionsprotokoll.
- Die regulären Main- und World-Physikmethoden werden in jedem tatsächlichen Physiktakt mit `1/60 s` aufgerufen. Ihre automatische Verarbeitung wird dafür abgeschaltet, damit es keine doppelten Simulationsschritte gibt. Die Modell- und Kollisionsmethoden bleiben unverändert.
- Das Protokoll erfasst die Position, reale Geschwindigkeit und Joystickauslenkung alle sechs Physikschritte. Weglänge und größter horizontaler Einzelschritt werden in jedem Schritt erfasst. Teilstände werden nach jeder Station gespeichert und ausdrücklich als unvollständig markiert.
- Der grafische Modus rendert echte Engine-Bilder an den Stationen. Die automatische Dauerrenderschleife bleibt aus, um den Software-Renderer nicht mit einer permanenten Vollweltdarstellung zu belasten. Daraus folgt keine Aussage über Bildrate, flüssigen Dauerbetrieb, Android-Leistung oder Temperatur.
- Die verwendete Qualitätsstufe steht im Protokoll. `low` wird über die bestehende Einstellungsoberfläche gewählt und beim Fortsetzen auf Wiederherstellung geprüft. Sämtliche Benutzerdaten des Reviews liegen in eigenen temporären Daten-, Konfigurations- und Cacheverzeichnissen.
- Die sichtbare Familie und das benannte Familienhaus folgen dem vorhandenen Kindheitsvertrag. Die Prüfung erfindet keine zusätzliche gespeicherte Haushaltszuordnung.

## Ausführung

Vom Repository-Verzeichnis aus, nach dem normalen Godot-Import:

```sh
python3 tools/characters/capture_action_route.py --headless --output /tmp/imperathen-family-route-headless
python3 tools/characters/capture_action_route.py --quality low --output /tmp/imperathen-family-route-images
```

Für einen bereits vorhandenen X11-Displayserver, beispielsweise in CI:

```sh
xvfb-run -a python3 tools/characters/capture_action_route.py --use-existing-display --quality low --output /tmp/imperathen-family-route-images
```

Der Runner schreibt `capture-manifest.json`, `runtime.log` und `action-route-review.json`, im grafischen Modus zusätzlich die Stationsbilder. Das Manifest sichert die SHA-256-Werte der Skripte vor dem Start. Nach Ende werden sie erneut abgeglichen; auch Prozesscode und Signal werden protokolliert. Ein Prozessabbruch oder ein bloßer Zwischenstand reicht nicht für einen erfolgreichen Nachweis.

Temporäre Datenverzeichnisse folgen dem normalen `TMPDIR` der Umgebung. Auf der lokalen Entwicklungsmaschine wurde `TMPDIR=/dev/shm` gesetzt; CI muss das nicht übernehmen und benötigt keinen großen `/dev/shm`-Mount.
