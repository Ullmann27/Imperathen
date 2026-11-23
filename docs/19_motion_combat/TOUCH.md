# Touchsteuerung, Kamera und Android-Prüfstrecke

Stand: 23.11.2026. Arbeitsbranch: `feature/chat-a-movement-combat-20261123`.
Die Umsetzung gehört zum Auftrag aus
`../18_childhood/CHAT_A_BEWEGUNG_KAMPF_STEUERUNG.md`.

Die aktuelle Zusammenführung verbindet Chat A aus
`5d95676626d8eeee5589973603cb1da523ca4970` mit dem Familienstart aus
`e5735509622c9a94564dc5fe21257c07074f9df5`. Die unten verlinkten bisherigen
Aufnahmen und die Zahlen **196/18/42 gehören ausschließlich zum älteren
5d956-Stand**. Sie belegen nicht die jetzt zusammengeführte Familien-Partie.

## Bedienung und Zuständigkeiten

Das analoge Steuerfeld sitzt über der unteren Navigation und besitzt eine
großzügige rechteckige Trefferfläche. Bewegung, Kamerablick und Aktion halten
jeweils eigene Fingerkontakte. Ein weiterer Kamerafinger ermöglicht Zoom.
Die Kamera übernimmt nur freie Flächen im rechten Weltbereich; Bedienelemente
und modale Menüs haben Vorrang. Ein Fingerwechsel erzeugt keinen Sprung.

Rechts stehen sechs Aktionen: Interagieren, ausgewählte Schlagtechnik,
Deckung, Ausweichen, Techniken und Gehen/Laufen. Der Tempoknopf zeigt den
aktuellen Modus und wechselt ihn auch bei gehaltenem Steuerfeld. Die zehn
Techniken stehen in einer scrollbar geöffneten Liste mit Ausdauerbedarf und
Freischaltbedingung. Eine Auswahl löst noch keinen Schlag aus. Der Katalog
und die Verfügbarkeit stammen aus `scripts/domain/combat_actions.gd`.

Die untere Navigation enthält Figur, Stadt, Karte, Dorf und Vorhaben. In alten
Spielpfaden öffnet Vorhaben Bauen, Ausbildung, Truppe, Verteidigung und
Weltkugel; im Familienstart bleiben die überholten Erwachsenenaktionen
ausgeblendet. Technik- und
Vorhabenmenü blenden die aktiven Spielsteuerungen aus und fangen Berührungen
ab. Pause, Hintergrund, Fokusverlust, Ausblenden und Ansichtswechsel beenden
alle gehaltenen Touchzustände. Spätere Drag-Ereignisse ohne neuen Touch-Start
reaktivieren die Eingabe nicht. Auch native Abbruchereignisse mit weiterhin
gesetztem `pressed`-Bit werden zurückgesetzt.

UI-Zuständigkeiten: `prototype/scripts/ui/game_ui.gd`, `touch_pad.gd`,
`touch_action.gd`, `touch_look.gd` und `touch_modal.gd`. Die kleinen Aktionssymbole
werden aus eigenen SVG-Definitionen erzeugt. Alte Spielstände ohne
`village.unarmed` behalten ihre bisherigen Angriffs-, Block- und Ausweichbefehle.

## Neue Zusammenführung: Familie und Nordkarte

`WorldModel.new_game("italia", true, true)` startet jetzt die Familie einschließlich
des modernen unbewaffneten Kampfs. Die 35 Kindheitshandlungen aus e573 bleiben
erhalten. Die HUD-Aufgabe, der bewusst erzählte Dorftag und die kleine Nordkarte
folgen `Childhood.view()` und `World.navigation_view()`. Die Karte wird über
`UI.update_navigation(value)` aktualisiert; `village_navigation.gd` verwendet
die tatsächlichen Hausgrundrisse und das aktuelle Auftragsziel.

Die vorhandenen Touchereignisse und das Technikoverlay bleiben bestehen.
`show_combat_palette(state)` ist für den Übungspfahl ein kleiner Anschluss an
dieses Overlay; es entsteht kein zusätzlicher Main-Bildschirm. Gesprächsknöpfe
behalten ihren eigentlichen Befehl und dessen Argumente als Metadaten, damit
die Android-Beobachtung die echte Mutterantwort lokalisieren kann.

Der Tempoknopf übernimmt den tatsächlichen Modus aus `state.running`. Ein
Layoutneuaufbau sendet keinen alten Geh-/Laufwert zurück an die Welt. Ein
bewusster Tempo-Tap aktualisiert den UI-Zwischenstand sofort, damit ein
anschließender Portraitwechsel die Auswahl erhält. Beim Fortsetzen übernimmt
die Oberfläche den von der neu aufgebauten Welt vorgegebenen Gehmodus.

Der e573-Fix für `InputEvent.DEVICE_ID_EMULATION` ist in Bewegungsfeld und
Aktionstasten erhalten. Eine verzögerte synthetische Mauskopie darf nach dem
Loslassen oder nach einem Bildschirmwechsel keinen neuen Bewegungs- oder
Angriffspfad auslösen. Neue Regressionen prüfen diese Situation und die
Nordkarte bei sechs Displaygrößen. Der Kindheitsintegrationstest verwendet
die zusammengeführten Aktionsknöpfe, Mutterantwort, tatsächlichen Krugauftrag
und Speichern/Fortsetzen. Seine gezielte Platzierung der Figur bleibt als
Testhilfe gekennzeichnet; die Android-Prüfstrecke setzt keine Positionen.

### Prüfstand dieser Zusammenführung

Im wiederhergestellten gemeinsamen Checkout wurden **85 Python-Tests tatsächlich
ausgeführt und bestanden**. Darin enthalten sind **55 Tests** aus
`tests/android_runtime_smoke_test.py`: die bisherigen 42 und 13 zusätzliche
Fälle für APK-Routenauswahl, Familienzustand, Kamerarichtung, native
Steuerkoordinaten und die konkrete Scrollregression aus CI 27.

Nach einer gezielten Korrektur der Temposynchronisierung bestand der tatsächliche
Kindheitsintegrationstest **94/94 Checks, Exitcode 0**. Er prüft beide nativen
Tempo-Taps, Portraitwechsel, erneutes `show_game`, Speichern/Fortsetzen und
Aktualisierung des UI-Tempos aus der Welt. Der Testhelfer verwendet dabei nur
sichtbare, nicht zum Löschen vorgemerkte Knöpfe; ein veralteter Verweis auf den
vorherigen Bildschirm hatte zuvor den zweiten Tap verhindert. Die Gehprüfung
wurde erhalten und um diese Fälle erweitert.

**Der vollständige gemeinsame Godot-Abschluss, aktuelle Familien-HUD-Aufnahmen
und der echte ADB-Lauf des zusammengeführten Stands sind noch offen.** Ein
bestandener Einzeltest wird hier nicht als abgeschlossener Gesamtprüflauf
ausgegeben. Die historischen Nachweise im nächsten Abschnitt bleiben davon
getrennt.

## Schnittstelle zwischen UI und Spielwelt

Die UI sendet über `action_requested(action, payload)`:

| Aktion | Nutzdaten | Bedeutung |
| --- | --- | --- |
| `move_axis` | `{x, y}` | Analoge Bewegung; `{0, 0}` beendet die Eingabe. |
| `movement_pace` | `{running: bool}` | Gehen/Laufen über `World.set_running()`. |
| `touch_camera_managed` | `{enabled: bool}` | `World.set_touch_camera_managed()` schaltet den alten Touchpfad der Figurenkamera aus. |
| `camera_look` | `{x, y}` | Einmaliges Viewport-Delta für `World.apply_camera_look(Vector2)`. |
| `camera_zoom` | `{factor}` | Verhältnis alter/neuer Fingerabstand für `World.apply_camera_zoom()`. |
| `select_technique` | `{technique: id}` | Auswahl über `World.set_selected_technique()`; kein Angriff. |
| `attack` | `{technique: id}` | Ausgewählte Technik über `World.perform_attack()`; Altspeicher senden weiterhin `{}`. |
| `village_unarmed_guard` | `{}` | Deckung im neuen Aktionsmodus. |
| `village_unarmed_dodge` | `{}` | Ausweichen im neuen Aktionsmodus. |

`main.gd` verbindet diese Ereignisse mit der Welt und dem autoritativen Modell.
Der alte Weltkontaktpfad darf bei verwalteter Touchkamera keinen Finger erneut
übernehmen. Pause/Hintergrund deaktivieren zusätzlich die Welt und unterbrechen
die ausstehende Kampfaktion; die UI allein entscheidet keine Kampftreffer.

## Historische Prüfungen: ausschließlich 5d956

Die folgenden Ergebnisse wurden vor der Zusammenführung mit e573 erhoben und
gehören zu `5d95676626d8eeee5589973603cb1da523ca4970`:

| Prüfung | Ergebnis | Aussage |
| --- | --- | --- |
| `prototype/tests/touch_controls_test.gd` | **196/196**, Exitcode 0 | Native `InputEventScreenTouch`/`Drag` durch den Godot-Viewport; drei gleichzeitige Finger, genau ein Kameradelta, Zoom, Abbruch, Pause, Tempo, Auswahl und Scrollen. |
| `prototype/tests/touch_hud_review.gd` | **18/18**, Exitcode 0 | Tatsächliche `main.tscn` mit damaligem Dorfanfang, integrierter World-Kamera, neutralen Kontakten nach Pause und Diagnosebeobachtung; noch ohne den jetzt übernommenen Familienstart. |
| `tests/android_runtime_smoke_test.py` | **42/42**, davon 9 neu | Python-Prüfungen für Beobachtungsformat, Koordinaten, frische Snapshots, Bewegung und neutrale Kontakte. |

Die damalige Touchprüfung deckte 1280×720, 960×540, 820×480, 900×900, 480×840 und
640×360 ab, zusätzlich eine sichere Bildschirmfläche von 892×680 innerhalb
960×720 bei 125 % Textskalierung. Die vorhandenen UI-, Dorfpanel- und
Opening-Overlay-Prüfungen wurden ebenfalls erfolgreich ausgeführt
(129, 41 und 66 Checks).

Die folgenden **historischen Bilder aus 5d956** stammen aus Godot 4.7.2,
Compatibility-Renderer und Mesa llvmpipe auf dem damaligen Entwicklungsrechner.
Sie wurden damals einzeln visuell geprüft; sie zeigen nicht den aktuellen
Familienstart und seine Nordkarte:

- [Phone 1280×720](evidence/touch/phone-1280x720.png)
- [Fold 884×760](evidence/touch/fold-884x760.png)
- [Geöffnete Techniken auf Fold](evidence/touch/fold-techniques-884x760.png)

[touch-hud-review.json](evidence/touch/touch-hud-review.json) enthält die 18
Prüfergebnisse und SHA-256-Werte von neun beteiligten Quelldateien. Alle neun
stimmten bei der damaligen Kontrolle mit dem Quellstand vor der neuen
Zusammenführung überein. [capture-attempt.json](evidence/touch/capture-attempt.json) bestätigt
Exitcode 0 und den erfolgreichen Abschlussmarker; `runtime.log` enthält die
Laufzeitausgabe. `touch-input-review.json` und `touch-input.log` belegen die
196 damaligen Eingabeprüfungen. Diese Dateien werden nicht als neue Ergebnisse
umetikettiert. Eine neue Aufnahme muss den zusammengeführten Quellstand mit
eigenem Rückgabecode, Prüfbericht und Quellhashes belegen.

## Android: implementiert, tatsächlicher ADB-Lauf noch ausstehend

`prototype/scripts/ui/android_village_diagnostics.gd` beobachtet den aktuellen
Modus, die Weltposition, Geschwindigkeit, Bewegungseingabe und gehaltene
Kontakte über `action_runtime` Version 1. Sichtbare Bedienelemente liefern
native Bildschirmkoordinaten; das Steuerfeld liefert zusätzlich Achspunkte.
Die Beobachtung verändert keinen Spielzustand. Ein geöffnetes Modal liefert
nur seine bedienbaren Elemente, keine blockierten Tasten dahinter. Die neue
Beschriftung „Dorf“ wird erkannt. Der Grundvertrag dieser Beobachtung wurde in
den 18 historischen Main-Prüfungen mitgeprüft. Neu hinzu kommen
`childhood_runtime` Version 1 mit Schrittfolge, stabilen Gegenstandskennungen,
Familienziel und Haustür-/Wasserpunkt sowie der tatsächliche Kamerawinkel in
`action_runtime`. Die neuen Familienfelder benötigen noch den aktuellen
Engine- und Android-Nachweis.

`tools/android_runtime_smoke.py` erkennt anhand des tatsächlichen APK-Inhalts,
ob die Familiengeschichte vorhanden ist. Nur APKs ohne Kindheitsmodul verwenden
weiter den alten Decimus-/Arbeitsverteilungsweg. Der neue Weg verwendet:

1. Normale Weiter-Taps durch das Familienintro bis zur gesonderten Annahme des
   ersten Auftrags, einschließlich Android-Zurück zum Pausieren/Fortsetzen.
2. Einen echten Joystickweg vom Familienhaus durch die Haustür zu Antonia,
   die tatsächliche Antwort `mother_morning`, den Rückweg zum Wassertisch und
   `fill_water` durch Interagieren. Nur diese ersten zwei Handlungen sind
   Prüfgegenstand; der Haushaltsdenar und der gefüllte Krug müssen wirklich
   im Auftragsinventar stehen. Keine Teleports oder geschriebenen Questdaten.
3. Neue Partie im unbewaffneten Aktionsmodus erkennen; mit einem echten ADB-Swipe
   am beobachteten Steuerfeld mindestens 0,10 m horizontale Bewegung erreichen.
4. Nach Loslassen neutrale Kontakte und Stillstand prüfen; Gehen/Laufen durch
   reale Taps umschalten und den tatsächlichen Modus beobachten.
5. Techniken durch einen realen Tap öffnen und die rechte Gerade auswählen;
   Auswahl und geschlossenes Menü anhand frischer Snapshots bestätigen.
6. Einen nativen Pointer mit `input motionevent DOWN` halten, per Android-Zurück
   pausieren und leere Kontakte prüfen; den Pointer freigeben und fortsetzen.
7. Nach dem vorhandenen Hintergrund-/Prozessneustart-Ablauf dieselbe Welt,
   beide Familienhandlungen und beide Gegenstände sowie neutrale Eingaben und
   Stillstand bestätigen.

Der echte ältere Android-CI-Lauf 27 zu 5d956 scheiterte beim Einblenden des
Arbeitsplatz-Auswahlfelds für Aelia. Die neue Korrektur begrenzt die Scrollgeste
anhand der beobachteten Position und wartet anschließend auf stabile Geometrie,
statt wiederholt über die ganze sichtbare Fläche zu wischen. Ein Pythonfall
verwendet die tatsächlich protokollierten Fehlerkoordinaten. Ein erfolgreicher
Android-Nachlauf dieses Fixes ist damit noch nicht belegt.

**Der neue Familien-ADB-Ablauf ist noch nicht ausgeführt.** Die 85 Python-Tests
einschließlich der 55 Harnessfälle prüfen das Testwerkzeug und Paketregeln;
sie ersetzen keinen Android-Emulator- oder Gerätelauf. Nächster Schritt ist
nach dem Engine-Gate der Android-CI-Prüfbau mit dem neuen ADB-Szenario aus
demselben Commit.
Physische Geräte, tatsächliches Falten und Dauerlast bleiben gesonderte Prüfungen.
