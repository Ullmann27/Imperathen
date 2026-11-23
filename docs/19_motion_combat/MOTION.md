# Figurenbewegung und unbewaffnete Darstellung

## Umfang dieser Lieferung

Die ursprünglichen GLBs, Gesichter, Altersformen, Materialien und fünf Herkunftswege bleiben erhalten. Der vorhandene detaillierte Italia-Spieler erhält eine anatomisch berechnete Ruhehaltung, neue Schrittführung sowie zehn getrennte unbewaffnete Posen. Die äußere Welt steuert Tempo und Kollision; die Darstellung verwendet die tatsächlich erreichte Geschwindigkeit. Treffer, Ausdauer und Technikzeit gehören weiterhin zur autoritativen Spiellogik.

Die sichtbare Ursache der alten Armhaltung lag bereits in der importierten Bindepose: Die Unterarme führten nach vorne. Im identischen Seitenbild betrug der Vorversatz des linken Handgelenks gegenüber dem Ellbogen etwa 14,7 cm; die neue entspannte Haltung liegt bei etwa 4,9 cm. Schulter-, Ellbogen- und Handpositionen werden anhand der tatsächlichen Restachsen bestimmt. Einfache Euler-Korrekturen hätten die unterschiedlichen Knochenachsen nicht zuverlässig abgebildet.

## Gang und Unterbrechungen

- Arme und Beine bewegen sich gegensinnig. Becken und Schultern drehen leicht gegeneinander; der Kopf bleibt überwiegend stabil und kann einer Drehung vorauseilen.
- Die Gangphase hängt vom zurückgelegten Weg ab. Die volle Schrittlänge des Kindmodells beträgt im eigenen Animationsentwurf 1,04 m pro vollständigem Gehzyklus und 2,0 m pro Laufzyklus. Diese Werte sind keine Messwerte fremder Spiele.
- Kleinere Joystickbewegungen reduzieren Schrittweite und Frequenz gemeinsam. Ein gesetzter Fuß bewegt sich im Modellraum so weit nach hinten, wie die Figur tatsächlich nach vorne läuft. Die Kontaktprüfung deckt 0,45, 1,0 und 1,45 m/s ab.
- Gehen/Laufen wechseln mit Hysterese. Ein Wechsel zwischen diesen Gangarten behält die Phase. Ein kurzes Überblenden federt Start und Anhalten ab.
- Der Parent liefert `get_real_velocity()`. An einer blockierenden Wand entsteht dadurch keine volle Laufanimation aus einem nur gewünschten Bewegungsvektor.
- Pause, Abbruch und Treffer können die gesteuerte Kampfpose beenden. Beim LOD-Wechsel bleiben Technik, normierter Zeitpunkt und Faustschluss erhalten.

## Tatsächliche Faust statt offener Finger

Das Modell besitzt 15 Laufzeitknochen und keine einzelnen Fingerknochen. Die erste einfache mathematische Handkrümmung wurde nach einer Nahaufnahme verworfen. `build_hand_grips.py` verwendet stattdessen die bereits enthaltenen CC0-Gelenkpunkte und Hautgewichte des MakeHuman-Ursprungs. Blender 4.3.2 berechnet die drei Glieder jedes Fingers getrennt; die eigene Pose legt auch den Daumen an. Die resultierenden Deltas und Normalenrotationen werden auf die tatsächlichen vier vorhandenen LODs übertragen.

Die vier komprimierten `hero_hand_grip_*.res` umfassen zusammen **180.014 Bytes**. Kein GLB wurde neu exportiert, kein zusätzlicher Laufzeitknochen eingeführt. Die Ressource erzeugt einen zusätzlichen `HandGrip`-Morph auf einer pro Quellmesh wiederverwendeten Kopie. Gesichts- und Altersmorphs bleiben erhalten. Ruhe und Gehen verwenden einen leichten, entspannteren Faustschluss; während des aktiven Schlags schließen die Finger vollständig.

Dieser detaillierte Faustmorph gilt für den Italia-Spieler. Die anderen Herkunftsmodelle behalten zunächst ihre bestehende Handgeometrie. Ihre Körperbewegung verwendet bei passendem Rig ebenfalls die neue Ruhe-/Gangkorrektur.

## Anschlussvertrag

| Methode | Aufgabe |
| --- | --- |
| `drive(real_speed, turn_rate = 0.0)` | Tatsächliche horizontale Geschwindigkeit in m/s und optionale Drehgeschwindigkeit in rad/s. |
| `sample_combat(technique, progress)` | Autoritativ gesteuerte Technik bei normiertem Fortschritt 0..1; bevorzugter Spielpfad. |
| `cue_combat(technique, duration)` | Zeitgesteuerte Darstellung für kontrollierte lokale Aufrufe; bucht keine Treffer. |
| `cancel_action()` | Entfernt die gesteuerte Technik und kehrt zur normalen Darstellung zurück. |
| `set_equipment(sword, shield = false)` | Explizite visuelle Ausrüstung; das Lebensalter allein zeigt kein Schwert mehr. Kein Inventarerwerb durch diese Methode. |
| `sample_pose(action, progress)` | Reproduzierbarer Review sowie weiterhin vorhandene GLB-Aktionen. |

Technik-IDs: `jab_left`, `jab_right`, `hook_left`, `hook_right`, `uppercut_left`, `uppercut_right`, `headbutt`, `front_kick`, `side_kick`, `high_kick`. Vorbereitung, Spitzenpose und Rücknahme folgen den vereinbarten Zeitfenstern aus `combat_actions.gd`. Beim Sidekick dreht sich der Körper seitlich; der Fuß trifft weiter in die autoritative Vorwärtsrichtung. Die Darstellung vergibt keinen Erfolg.

## Nachweise

`evidence/motion/before/` enthält den tatsächlichen alten Stand, `after/` den neuen. Die fünf gemeinsamen Ansichten verwenden dasselbe Asset und exakt dieselbe Kamera. In `after/` liegen zusätzlich alle zehn Techniken, eine Faustnahaufnahme und vier LOD-Ansichten. `character-motion.mp4` enthält acht Sekunden reproduzierbare Engine-Aufnahmen mit 1,45 m/s Gehphase, 3,8 m/s Laufphase und zeitlich abgestimmten Techniken. Das ist ein Studio mit zentrierter Figur, kein Android-Gerätetest und kein gemessener FPS-Nachweis.

Tatsächlich erfolgreiche Prüfungen:

- `character_motion_test.gd`: **344 Prüfungen, 0 Fehler**. Tatsächliches importiertes Skelett, analoge Kontaktwege, Gegenschwung, erhaltene Gliedlängen, zehn unterscheidbare Posen, drei Kickrichtungen, LOD-Übergabe, Griff, Ausrüstung, Gehen/Laufen/Anhalten. Der maximale Fehler der Standfuß-Knochenhöhe gegenüber der importierten Referenz betrug über 120 Phasen rund 0,000000238 m. Das ist eine numerische Kinematikprüfung, keine Messung von Fußdruck oder Gerätedynamik.
- `village_person_test.gd`: **222 Prüfungen, 0 Fehler**. Bestehende Figuren, Identitäten, Altersformen, Materialpfade, LODs, Clips und explizite Ausrüstung.
- `validation.json` bestätigt die gemeinsamen Kameras und die SHA-256-Zuordnung der finalen Renderquellen.

### Gleicher Aufwandstest vor und nach der Änderung

Ein Italia-Kind, LOD0, `very_high`, 1100×800 Pixel, gleicher Hintergrund, gleiche Kamera, 1,45 m/s. Vorher wird der ursprüngliche Figurcode aus Commit `2909040deeb33b99ad4180b884b38921f28233a9` in eine separate temporäre Skriptdatei geladen. Produktionsdateien werden dabei nicht zurückgetauscht. Beide Läufe verwenden Godot 4.7.2 und `llvmpipe (LLVM 19.1.7, 256 bits)`.

| Messgröße | Vorher | Nachher |
| --- | ---: | ---: |
| Figur-Nodes | 20 | 20 |
| Mesh-Instanzen der Figur | 14 | 14 |
| Sichtbare Dreiecke der Figur | 32.804 | 32.804 |
| Drawcalls des gesamten Studios | 31 | 31 |
| CPU-Mittelwert pro `actor._process` | 4,49 µs | 39,66 µs |
| CPU-Median | 5 µs | 34 µs |
| CPU-95.-Perzentil | 6 µs | 82 µs |

Die CPU-Stichprobe enthält 600 synchrone Aufrufe nach 60 Aufwärmaufrufen bei dt=1/60. Rendering, Physik, Ladevorgang und Betriebssystem-Taktung sind ausgeschlossen. Die neue Körperberechnung benötigt mehr CPU; die gemessenen Mesh-/Dreieck-/Drawcall-Zahlen steigen in dieser Szene nicht. Aus diesen Desktopwerten wird keine Aussage über Android-Bildraten, Temperatur oder Akkulaufzeit abgeleitet.

## Reproduktion

```bash
blender --background --python tools/characters/build_hand_grips.py
godot --headless --path prototype --script res://tests/character_motion_test.gd
python3 tools/characters/capture_motion.py --output /dev/shm/imperathen-motion-review --motion
python3 tools/characters/capture_motion.py --output /dev/shm/imperathen-motion-baseline --baseline-ref 2909040deeb33b99ad4180b884b38921f28233a9 --metrics-only
```

## Verbleibende sichtbare Grenzen

Die Tunika verwendet weiterhin die ursprünglichen Hautgewichte und keine Stoffsimulation. Besonders beim Highkick bleibt ihr Saum steif und kann mit dem gehobenen Bein ungünstig verformen. Die Aufnahmen zeigen das ausdrücklich. Ein spezifisches Tunika-Korrekturmodell oder Stoffrig ist der nächste geeignete Grafikschritt. Die vorhandenen Haut-/Schulterdetails sind weiterhin Prototypqualität; die Lieferung beansprucht keine fertige AAA-Charakteranimation.
