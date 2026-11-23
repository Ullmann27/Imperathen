# Chat A – Zusammengeführter Entwicklungsstand

23. November 2026 · Branch `feature/chat-a-movement-combat-20261123`

## Gelieferter Quellstand

Der Integrationscommit ist **`db90dee785cbaef97a5d85357b7b9cda762dc9cd`**.
Er führt die Eltern `5d95676626d8eeee5589973603cb1da523ca4970` (erste Chat-A-Fassung)
und `e5735509622c9a94564dc5fe21257c07074f9df5` (vollständiger Dorf-/Familienanfang)
zusammen. Sein Git-Tree `d4ca46c2199e6d2a755bb921aa954b4c66125851` stimmt exakt
mit dem lokal geprüften und anschließend übertragenen Baum überein.

[Draft-PR 39](https://github.com/Ullmann27/Imperathen/pull/39) ist auf den
Kindheitszweig gerichtet und hat auf dieser Grundlage keine Mergekonflikte mehr.
Es wurde nicht nach `main` gemergt und kein Store-Release veröffentlicht.
Drei tatsächliche Arbeitsagenten plus Integration haben den Auftrag umgesetzt.
Docker bzw. ein Docker-Socket waren in der Ausführungsumgebung nicht vorhanden.

## Spielverhalten und erhaltene Arbeit

Die Figur geht analog mit einer vorgesehenen vollen Gehgeschwindigkeit von
1,45 m/s und kann ausdrücklich auf den kindlichen Laufmodus mit 3,8 m/s
wechseln. Reale Kollisionsgeschwindigkeit steuert den Gang. Ruhehaltung,
Gegenschwung, Drehung und Bremsen sind getrennt; die Handressourcen schließen
die tatsächlichen Finger des Italia-Spielers.

Zehn unbewaffnete Techniken verwenden Vorbereitung, aktives Kontaktfenster,
Erholung und Ausdauer. Entfernung, Richtung, Hindernis und Zielzustand werden
beim Kontakt erneut geprüft. Ein Angriff bucht höchstens einen Kontakt.
Übung, tatsächlicher Gegnerkontakt und spätere Erwachsenen-Ausbildung sind
getrennt. Ausweichen endet körperlich mit seiner autoritativen Unterbrechung.

Die 35 verbundenen Kindheitshandlungen, Antonia, Sextus, Quintus, das
Auftragsinventar, bewusst begonnene Dorftage, Nachtfreigabe, Häuser, Böden,
Türen, Bewohnerwege und Nordkarte bleiben aus dem Dorfzweig erhalten.
Native zivile Kollisionskörper werden wiederverwendet. Helm und Holzschild
bleiben nur bei gespeichertem Leihstatus sichtbar. Alter allein erzeugt
keine Waffe.

Bewegung, Kamera und Aktion besitzen getrennte Touchkontakte. Das vergrößerte
Steuerfeld, sechs Aktionsknöpfe, Technikwahl und Tempo bleiben mit Auftrag und
Karte verbunden. UI und Welt synchronisieren den tatsächlichen Geh-/Laufmodus
auch bei Layoutwechsel und Fortsetzen.

## Tatsächliche lokale Prüfung

Alle **46 unterschiedlichen Godot-Prüfgruppen** sind für denselben durch
SHA-256 erfassten Quellstand erfolgreich geprüft. Im letzten Gesamtlauf
bestanden 45; ein Kindheitsprozess endete mit SIGKILL, dessen Ursache nicht
gesichert ist. Der unveränderte Wiederholungslauf bestand alle 94 Checks.
Originalabbruch und Wiederholung bleiben beide nachvollziehbar erhalten.
Die **85 Pythonprüfungen** bestanden ebenfalls.

| Bereich | Bestandene Checks |
| --- | ---: |
| Kampfregeln | 171 |
| Gemeinsames Modell und Speicherung | 226 |
| Vollständiger Kindheitsvertrag | 323 |
| Delegierender Kampfvertrag | 71 |
| Kindheit mit wirklichem Main, Touch und Speichern | 94 |
| Native Touchereignisse und Layouts | 240 |
| Weltadapter, Personenidentität und Ausweichabbruch | 56 |
| Tatsächliche Bewegung, Kontakte und Neustart | 43 |
| Rig und anatomische Bewegungsprüfung | 344 |
| Figuren und Detailstufen | 222 |
| Zusammengeführte Bewegung und Leihdarstellung | 109 |

Diese Teilzahlen sind nicht voneinander unabhängige Spielerlebnisse.
Die [Verifikationsübersicht](evidence/integration/verification.json) verknüpft
Gesamtlauf, Wiederholung und Quellen. Domain-/Fixtureprüfungen versetzen ihre
Testfiguren ausdrücklich; sie sind nicht der durchgehende Fußweg.

Die fünf [Integrationspatches](integration/manifest.json) wurden einzeln auf
`e573550…` angewendet und ergaben bytegenau die gelieferten Dateien. Die neue
API und gemeinsame Autorität stehen in [INTEGRATION.md](INTEGRATION.md) und
[COMBAT_CONTRACT.md](COMBAT_CONTRACT.md).

## Android und kontinuierlicher Familienweg

Der [Android-Lauf 30](https://github.com/Ullmann27/Imperathen/actions/runs/45204185930)
verwendete exakt den Integrationscommit. Seine komplette Engine-Regressionsstufe,
beide APK-Exporte samt statischer Prüfung und die Desktop-Exporte bestanden.
Die tatsächliche Android-APK wurde installiert und bis zum Familienhaus bedient;
22 Laufzeitchecks bestanden. Der Lauf scheiterte anschließend am ersten kurzen
automatisierten Bewegungsimpuls. Er ist keine bestandene Android-Laufzeitabnahme.
Der Beobachter protokollierte auf dem langsamen Emulator nur etwa alle 13–17
Wanduhrsekunden; die 900-ms-Geste ergab keinen beobachteten Ortswechsel.
Die anschließende Korrektur und ihr neuer Lauf werden getrennt nachgewiesen.

Der vorherige [Lauf 27](https://github.com/Ullmann27/Imperathen/actions/runs/45195592091)
baute und startete die frühere APK, scheiterte aber beim Scrollen zu einer
Arbeitszuweisung. Sein Fehler wurde gezielt korrigiert und als Pythonregression
erfasst. Für APKs mit Kindheitsmodul verwendet der neue ADB-Weg normale
Intro-Weiter-Taps, reale Joystickwege, Antonia und Wasserholen. Aufträge und
Gegenstände werden nach Prozessneustart erneut beobachtet.

Der neue [kontinuierliche Weg](CONTINUOUS_ROUTE.md) bestand lokal alle 76 Checks:
Familienhaus, tatsächliche schmale Tür, Muttergespräch, Wasserauftrag,
Gehen/Laufen, Übungsplatz, acht Techniken, Pause/Speichern und ein neuer
Main-Start. Er umfasst 62,5396 m und 21 tatsächliche Übungskontakte, die nach
Fortsetzen erhalten blieben. Das Prüfsystem setzt weder Spielerposition noch
Aufgabenstatus oder Technikfreischaltungen. Die Originalbelege liegen unter
`evidence/family_route/03_corrected_pass/`; beide vorherigen Fehlversuche bleiben
ebenfalls erhalten. Der Testwerkzeug-Commit `62adc18e9c7be9f8318ea93aea716a499bdfced7`
startete den separaten [grafischen CI-Weg](https://github.com/Ullmann27/Imperathen/actions/runs/45206876533).
Sein Produktionscode ist bytegleich zum Integrationscommit. Dieser saubere
Checkout bestand **77/77 Headless-Prüfungen und 89/89 grafische Prüfungen**,
jeweils mit Exitcode 0. Alle zwölf Originalbilder wurden einzeln angesehen.
Die 65 erfassten Quellhashes stimmten zwischen beiden Läufen überein und
blieben währenddessen unverändert. Vollständige Berichte und Bilder sind unter
`evidence/family_route/ci1/` erhalten; die
[Bildprüfung](evidence/family_route/ci1/VISUAL_REVIEW.md) nennt auch die Fehler.

## Bilder, Messungen und Grenzen

Die bewahrten Studio-Vorher-/Nachher-Bilder, zehn Technikansichten, vier LODs,
Faustnahaufnahme und acht Sekunden Engine-Video gehören zur ersten Chat-A-
Fassung `5d956…`. Ebenso die ersten Phone-/Fold-Bilder. Kameras, Quellhashes
und Bildumfang stehen in [MOTION.md](MOTION.md) und [TOUCH.md](TOUCH.md).
Sie werden nicht als neue Grafikabnahme des Familienanfangs ausgegeben.

Im identischen Figurenstudio blieben 20 Nodes, 14 Meshes, 32.804 sichtbare
Dreiecke und 31 Drawcalls erhalten. Die Körperberechnung benötigte mehr CPU:
gemessener Mittelwert 4,49 auf 39,66 Mikrosekunden pro Actor-Aufruf. Diese
begrenzte Desktopmessung belegt keine Android-FPS-, Akku- oder Temperaturwirkung.

Die Tunika bleibt beim Highkick teilweise steif. Der Kontaktweg ist noch keine
vollständige anatomische Hand-/Fuß-Hitboxsimulation; Deckung ist nicht
richtungsabhängig. Der detaillierte Faustmorph gilt zunächst für Italia.
Geliehener Helm/Holzschild ersetzen kein fertiges bewaffnetes Kampfsystem.
In der geprüften Mutterdialogansicht verdeckt eine nahe Wand Antonia; der
Dialogtext bleibt lesbar. Einzelne Weltbeschriftungen werden am rechten Rand
abgeschnitten. Die Füße liegen in mehreren Stationsbildern unter der unteren
Navigation oder außerhalb des Bilds; diese Ansichten belegen keinen
vollständigen Fußkontakt. Die Stationsbilder sind keine Daueraufnahme oder
FPS-Messung.
Ein physisches Telefon, tatsächliches Falten und thermische Dauerlast wurden
nicht geprüft. Auch das größere Dorf und verbundene Aufgaben machen diesen
Abschnitt noch nicht zu einer fertigen offenen Welt oder einem AAA-Spiel.
