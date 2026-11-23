# Touchsteuerung, Kamera und Android-Prüfstrecke

Stand: 23.11.2026. Arbeitsbranch: `feature/chat-a-movement-combat-20261123`.
Die Umsetzung gehört zum Auftrag aus
`../18_childhood/CHAT_A_BEWEGUNG_KAMPF_STEUERUNG.md`.

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

Die untere Navigation enthält Figur, Stadt, Karte, Dorf und Vorhaben. Vorhaben
öffnet Bauen, Ausbildung, Truppe, Verteidigung und Weltkugel. Technik- und
Vorhabenmenü blenden die aktiven Spielsteuerungen aus und fangen Berührungen
ab. Pause, Hintergrund, Fokusverlust, Ausblenden und Ansichtswechsel beenden
alle gehaltenen Touchzustände. Spätere Drag-Ereignisse ohne neuen Touch-Start
reaktivieren die Eingabe nicht. Auch native Abbruchereignisse mit weiterhin
gesetztem `pressed`-Bit werden zurückgesetzt.

UI-Zuständigkeiten: `prototype/scripts/ui/game_ui.gd`, `touch_pad.gd`,
`touch_action.gd`, `touch_look.gd` und `touch_modal.gd`. Die kleinen Aktionssymbole
werden aus eigenen SVG-Definitionen erzeugt. Alte Spielstände ohne
`village.unarmed` behalten ihre bisherigen Angriffs-, Block- und Ausweichbefehle.

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

## Tatsächlich abgeschlossene Prüfungen

| Prüfung | Ergebnis | Aussage |
| --- | --- | --- |
| `prototype/tests/touch_controls_test.gd` | **196/196**, Exitcode 0 | Native `InputEventScreenTouch`/`Drag` durch den Godot-Viewport; drei gleichzeitige Finger, genau ein Kameradelta, Zoom, Abbruch, Pause, Tempo, Auswahl und Scrollen. |
| `prototype/tests/touch_hud_review.gd` | **18/18**, Exitcode 0 | Tatsächliche `main.tscn`, neue Kindheits-Partie, integrierte World-Kamera, neutrale Kontakte nach Pause und echte Diagnosebeobachtung. |
| `tests/android_runtime_smoke_test.py` | **42/42**, davon 9 neu | Python-Prüfungen für Beobachtungsformat, Koordinaten, frische Snapshots, Bewegung und neutrale Kontakte. |

Die Touchprüfung deckt 1280×720, 960×540, 820×480, 900×900, 480×840 und
640×360 ab, zusätzlich eine sichere Bildschirmfläche von 892×680 innerhalb
960×720 bei 125 % Textskalierung. Die vorhandenen UI-, Dorfpanel- und
Opening-Overlay-Prüfungen wurden ebenfalls erfolgreich ausgeführt
(129, 41 und 66 Checks).

Die finalen Bilder stammen aus Godot 4.7.2, Compatibility-Renderer und Mesa
llvmpipe auf dem Entwicklungsrechner. Sie wurden einzeln visuell geprüft:

- [Phone 1280×720](evidence/touch/phone-1280x720.png)
- [Fold 884×760](evidence/touch/fold-884x760.png)
- [Geöffnete Techniken auf Fold](evidence/touch/fold-techniques-884x760.png)

[touch-hud-review.json](evidence/touch/touch-hud-review.json) enthält die 18
Prüfergebnisse und SHA-256-Werte von neun beteiligten Quelldateien. Alle neun
stimmten bei der abschließenden Kontrolle mit dem integrierten Quellstand
überein. [capture-attempt.json](evidence/touch/capture-attempt.json) bestätigt
Exitcode 0 und den erfolgreichen Abschlussmarker; `runtime.log` enthält die
Laufzeitausgabe. `touch-input-review.json` und `touch-input.log` belegen die
196 Eingabeprüfungen. Reproduktion aus dem Repository-Stamm:

```bash
godot --headless --path prototype --fixed-fps 60 --script res://tests/touch_controls_test.gd
python3 tools/characters/capture_touch_hud.py --output /dev/shm/imperathen-touch-review
```

## Android: implementiert, tatsächlicher ADB-Lauf noch ausstehend

`prototype/scripts/ui/android_village_diagnostics.gd` beobachtet den aktuellen
Modus, die Weltposition, Geschwindigkeit, Bewegungseingabe und gehaltene
Kontakte über `action_runtime` Version 1. Sichtbare Bedienelemente liefern
native Bildschirmkoordinaten; das Steuerfeld liefert zusätzlich Achspunkte.
Die Beobachtung verändert keinen Spielzustand. Ein geöffnetes Modal liefert
nur seine bedienbaren Elemente, keine blockierten Tasten dahinter. Die neue
Beschriftung „Dorf“ wird erkannt. Diese Eigenschaften wurden in den 18 echten
Main-Prüfungen mitgeprüft.

`tools/android_runtime_smoke.py` erkennt die neuen Module im tatsächlichen APK
und erweitert den bestehenden ADB-Ablauf um:

1. Neue Partie im unbewaffneten Aktionsmodus erkennen; mit einem echten ADB-Swipe
   am beobachteten Steuerfeld mindestens 0,10 m horizontale Bewegung erreichen.
2. Nach Loslassen neutrale Kontakte und Stillstand prüfen; Gehen/Laufen durch
   reale Taps umschalten und den tatsächlichen Modus beobachten.
3. Techniken durch einen realen Tap öffnen und die rechte Gerade auswählen;
   Auswahl und geschlossenes Menü anhand frischer Snapshots bestätigen.
4. Einen nativen Pointer mit `input motionevent DOWN` halten, per Android-Zurück
   pausieren und leere Kontakte prüfen; den Pointer freigeben und fortsetzen.
5. Nach dem vorhandenen Hintergrund-/Prozessneustart-Ablauf erneut neutrale
   Eingaben und Stillstand bestätigen.

**Dieser neue ADB-Ablauf ist lokal noch nicht ausgeführt.** Die 42 Python-Tests
prüfen das Testwerkzeug; die Desktopbilder und Godot-Touchereignisse belegen
keinen Android-Emulator- oder Gerätelauf. Nächster Schritt ist der vorhandene
Android-CI-Prüfbau mit anschließendem ADB-Szenario aus demselben Commit.
Physische Geräte, tatsächliches Falten und Dauerlast bleiben gesonderte Prüfungen.
