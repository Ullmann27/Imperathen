# Durchgehende Familienroute

## Zweck und Stand

Dieser separate Review startet die echte Main-Szene über **Neues Leben**. Er soll den zusammenhängenden Weg vom neuen Familienanfang bis zum Üben und Speichern nachvollziehbar prüfen. Die neue Routenfassung ist nach der Wiederherstellung der Entwicklungsumgebung vorbereitet; ein bestandener Lauf darf erst aus einem vollständig abgeschlossenen `action-route-review.json` mit `passed: true`, unveränderten Quellhashes und erfolgreichem Prozessende abgeleitet werden.

Die früheren 67 erfolgreichen Headless-Prüfungen betrafen den vorherigen Dorfanfang. Sie belegen diese neue Familienroute nicht. Frühere grafische Zwischenläufe waren unvollständig; ein erfasster Lauf endete mit SIGKILL. Verlorene Bilder oder Trajektorien wurden nicht nachgebildet.

## Tatsächlicher Weg

Die automatisierte Steuerung beginnt an der regulären Position im möblierten Familienhaus. Sie geht durch die bestehende schmale Haustür und über deren physische Rampe zu Antonia. Die Interaktion und die erste Dialogwahl laufen über echte Touchereignisse. Anschließend geht die Figur zurück ins Haus und erledigt den Wasserauftrag mit der vorhandenen Interaktion. Nach dem erneuten Verlassen des Hauses folgen getrennte Geh- und Laufabschnitte durch die Dorfmitte bis zum bestehenden Übungspfahl.

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
