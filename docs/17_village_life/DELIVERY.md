# IMPERATHEN – wiederaufgenommener Dorfanfang

23. November 2026 · Arbeitsbranch `feature/village-life-delivery-20261123`

## Abgeschlossene Android-Lieferung · 23.11.2026

**[IMPERATHEN-e1b1c1fb-arm64.apk herunterladen](https://github.com/Ullmann27/Imperathen/releases/download/village-2026-11-23-e1b1c1fb/IMPERATHEN-e1b1c1fb-arm64.apk)** ·
[Veröffentlichung und sieben Prüfdateien](https://github.com/Ullmann27/Imperathen/releases/tag/village-2026-11-23-e1b1c1fb) ·
[Erfolgreicher Bau- und Android-Lauf 25](https://github.com/Ullmann27/Imperathen/actions/runs/45178232563)

| Merkmal | Nachgewiesener Stand |
| --- | --- |
| Version / Paket | `0.3.0-village` (3) · `at.heinz.imperathen` |
| Gerätefassung | ARM64 · 150.393.060 Bytes, rund 150,4 MB |
| APK-Quellcommit | `e1b1c1fb16d63056e4eb80891d84ed75c79b4ed6` |
| Python-Regressionsprüfungen | 55 bestanden |
| Godot 4.7.2 | 33 Prüfgruppen bestanden; 198 Quellprüfsummen abgeglichen |
| Android 15 / API 35 | 50 Laufzeitprüfungen bestanden; keine erkannten Laufzeitfehler |
| ARM64-Downloadfassung | Tatsächlich installiert und unter ARM64-Übersetzung gestartet |
| Veröffentlichung | Öffentliche Prüffassung; alle sieben Assetgrößen und SHA-256-Werte stimmen mit den geprüften Dateien überein |
| Physisches Telefon | Noch nicht getestet |

SHA-256 der herunterladbaren APK:

```text
9b9d6655cca0ee4d04b67cd318dbb74c11cec9523cf9d4e94306975c690d2015
```

Der vollständige Spielweg wurde mit der passenden x86_64-APK im Android-Emulator
bedient. Er umfasst den Einstieg, Decimus, die Arbeitserlaubnis, das Scrollen
zu Aelia und ihre tatsächliche Zuweisung zum Holzfällerlager. Das echte Popup
benötigte drei Pfeil-ab-Eingaben bis zum beobachteten Eintrag 2. Die daraufhin
gespeicherte Zuweisung, die Bekanntschaft mit Decimus und die Arbeitserlaubnis
waren nach einem Prozessneustart erhalten. Pause, Hintergrundwechsel,
Talgefecht, quadratische Darstellung, Weltkugel und Figurenansicht gehören
ebenfalls zum abgeschlossenen Prüfprogramm.

Die ARM64-APK wurde zusätzlich auf demselben Emulator installiert und unter
Übersetzung bis zum laufenden Intro gestartet. Das belegt keinen vollständigen
ARM64-Spielweg auf einem physischen Telefon und keine dortige Bildrate oder
Temperaturentwicklung.

Der unabhängige Dateiabgleich prüfte beide tatsächlichen APKs: ZIP-Integrität,
je 1.060 eindeutige Einträge, native Architektur, 19 erforderliche Paketprüfungen
sowie jeweils 48 Featuredateien und 48 Exportverweise. Die 568 geprüften
Spiel-, Werkzeug- und Testdateien passen zum entfernten Git-Baum. Die Signatur
(v2/v3) wurde im CI mit `apksigner` erfolgreich geprüft; eine erneute lokale
`apksigner`-Ausführung wird nicht behauptet. Der lokale Hashabgleich bindet
diesen Nachweis an die tatsächlich heruntergeladenen APK-Bytes.

**Bei vorhandenen Spielständen:** Dieser Prüfbau besitzt einen neuen
Testsignierschlüssel. Direkte Updates über beliebige frühere Prüfbauten werden
nicht zugesagt. Eine vorhandene Installation mit wichtigem Spielstand nicht
vorschnell deinstallieren; die [Installationsanleitung](../10_development/ANDROID_INSTALL.md)
beschreibt die Einschränkung.

### Dauerhaft gespeicherte Abschlussnachweise

- [Abschließender unabhängiger Lieferabgleich](evidence/android-delivery/final-delivery-audit.json)
- [Unabhängiger APK-Byteabgleich](evidence/android-delivery/independent-build-byte-audit.json)
- [Unabhängiger Laufzeit- und Bildabgleich](evidence/android-delivery/independent-runtime-audit.json)
- [APK-Prüfung](evidence/android-delivery/IMPERATHEN-e1b1c1fb-APK-Pruefung.json),
  [Godot-Prüfungen](evidence/android-delivery/IMPERATHEN-e1b1c1fb-Godot-Pruefungen.json),
  [Android-Laufzeitbericht](evidence/android-delivery/IMPERATHEN-e1b1c1fb-Emulatorpruefung.json)
- [Vollständige Serie der 14 tatsächlichen Android-Aufnahmen](evidence/android-delivery/SCREENSHOTS.md)

Die folgenden Abschnitte dokumentieren die Entwicklung und die bewusst
zurückgehaltenen fehlgeschlagenen Zwischenstände. Maßgeblich für die ausgelieferte
APK ist der erfolgreiche Lauf 25 auf `e1b1c1fb`.

## Anlass und Zusammenstellung

Heinz hat die Fortsetzung des im Screenshot unterbrochenen Arbeitsstands beauftragt. Der neueste erhaltene Arbeitsstand lag noch uncommitted vor; der entfernte Frontier-Zweig stand auf `148dd69`. Diese Fortsetzung verwendet eine getrennte Arbeitskopie des tatsächlichen Dorfleben-Stands auf Basis des Opening-Commits `ea9987c08a7a98f3bca6b793a424d396b2c0dab6`. Die älteren Arbeitskopien wurden nicht überschrieben.

Der Anfang enthält den filmischen Einstieg und seine überspringbare Zielkarte, Decimus als Dorfverwalter, den Wiederaufbau mit vierzehn namentlichen Erwachsenen, fünf reale Arbeitsstätten, persönliche Bekanntschaften, Berufslehre, Verbündete und wiederkehrende Überfälle. Ressourcen, Gesundheit, Arbeitszuweisung und Miliz verwenden denselben gespeicherten Zustand. Ein abgezogener Arbeiter arbeitet nicht gleichzeitig im Betrieb. Die persönliche Figur beginnt weiterhin mit zwölf Jahren; der ausdrücklich angekündigte spätere Ausbildungsschritt führt sie auf achtzehn.

Die sieben Frontier-Figurentypen verwenden insgesamt 28 importierte GLBs. Die Modelle und ihre vorhandenen Herkunftsnachweise werden wiederhergestellt; der erste menschliche Hauptcharakter und die vier Grafikprofile bleiben erhalten. Diese Sicherung ist keine neue Modellierung aller Gesichter.

## Korrekturen in dieser Fortsetzung

- Treffen, Hilfsbitte und erste Berufslehre funktionieren auch bei bereits hohem Vertrauen. Zuwächse halten die zulässige Obergrenze ein; Kosten und einmalige Folgen bleiben wirksam.
- Bewohnernamensschilder verschwinden bei zu geringem Kameraabstand, am seitlichen Nahbereich der Kamera, hinter ihr sowie während Gesprächen und Pausen. Sie überdecken keine Nahaufnahme.
- Gesprächsergebnisse erscheinen im Dialog. Vorherige Meldungen schweben nicht mehr über dem Text und den Antworten.
- Die Arbeitsübersicht öffnet am Anfang. Nach einer Zuweisung bleiben Scrollposition und der gewählte Einwohner erhalten; Tastatur und Controller behalten den Fokus.
- Android erhält `0.3.0-village`, Versionscode `3`. Die Paketprüfung verlangt die neuen tatsächlichen Modell- und Skriptdateien. Der Laufzeitprüfer benutzt echte Eingaben für Decimus, die Arbeitserlaubnis, eine Arbeitszuweisung und die spätere Fortsetzung.

## Frisch ausgeführte lokale Prüfungen

| Prüfung | Tatsächlicher Befund |
| --- | --- |
| Vollständiger Godot-4.7.2-Durchlauf | 33 Prüfgruppen bestanden, keine Warnungen; [Bericht](evidence/resume-engine/validation_report.json) |
| Android-Payload-Prüfungen | 16 Python-Prüfungen bestanden; fehlende Modelle, Skripte und fehlerhafte Exportverweise werden abgewiesen |
| Neue Panelregression | 15 Prüfungen: Scrollposition, Fokus, tatsächliche Arbeitszuweisung, Gesprächsrückmeldung, schmales Layout |
| Neue Namensschildregression | 10 Prüfungen an tatsächlicher Spielwelt und Kamera |
| Vertrauensregression | Vor der Korrektur sechs nachgewiesene Fehler; nach der Korrektur 167 Dorfleben-Prüfungen bestanden |
| Gesamter Dorfweg | Produktions-Main, UI, Welt, Arbeit, Beruf, Überfall, Rettung, Speichern/Fortsetzen und spätere Miliz im Engine-Durchlauf geprüft |

Der Engine-Dorfweg verwendet ausdrücklich Testpositionen und vorgespulte Simulationszeit. Er ist ein Integrationsnachweis und kein manuell durchgespielter Android-Hardwaretest. Die übernommenen älteren Belege unter `evidence/engine/` bleiben historische Zwischenstände; maßgeblich für diesen Durchgang ist `evidence/resume-engine/`.

## Wiederaufnahme des Lieferabschlusses

Die Fortsetzung setzt auf dem tatsächlich gespeicherten Quellstand
`f60fd4e1b5ff8a0ed9b21861bc8515ca64da33b8` auf. Alle 42 Blenderquellen,
28 Frontier-GLBs und fünf zugehörigen Register-/Generatordateien wurden unabhängig
gegen den entfernten Git-Baum geprüft; alle 75 Dateien stimmen überein.
Zusätzlich stimmen die 35 registrierten SHA-256-Werte der sieben Frontierquellen
und 28 GLBs. [Wiederherstellung](BLENDER_SOURCE_RECOVERY.md) und
[maschineller Abgleich](evidence/delivery-resume/source-integrity.json) dokumentieren
die unverändert gesicherten Quellen.

Der vorherige Android-Lauf [45123561944](https://github.com/Ullmann27/Imperathen/actions/runs/45123561944)
hatte beide APKs gebaut, scheiterte aber beim Zugriff auf `aelia_assignment`:
Nach dem Tippen auf den Arbeitsreiter lag noch die Diagnose der Dorfübersicht vor.
Der Prüfer wartet jetzt auf eine neue Beobachtung mit dem tatsächlich benötigten
Bedienelement. Ein ausbleibender Wechsel, ein deaktiviertes Element oder ein
Laufzeitfehler bleibt ein Fehler; Spielzustände werden nicht künstlich gesetzt.
Die ergänzte Engineprüfung bedient denselben Übergang mit echten
`InputEventScreenTouch`-Ereignissen und prüft die sichtbare Auswahl.

Die Veröffentlichung findet einen bereits angelegten Download-Entwurf jetzt über
seinen Tag und seine bestätigte Release-ID wieder. Fehlerhafte Abfragen, andere
Quellstände und abweichende vorhandene APK-Bytes werden weiterhin abgewiesen.

Frisch ausgeführte Prüfungen dieses Wiederaufnahmedurchgangs:

| Prüfung | Ergebnis und Beleg |
| --- | --- |
| Godot 4.7.2, vollständiger Durchlauf | 33 von 33 Gruppen bestanden, keine Warnungen; [Bericht](evidence/delivery-resume/engine/validation_report.json) |
| Erweiterter Dorfablauf | 140 Prüfungen, 0 Fehler; [Log](evidence/delivery-resume/engine/village_experience.log) |
| APK-Inhalte, Laufzeitprüfer und Entwurfswiederaufnahme | 30 Pythonprüfungen bestanden, darunter acht zur Zustandswarteprüfung und sechs zur Veröffentlichung; [Log](evidence/delivery-resume/android-python-tests.log) |

## Android und Bildnachweise

Der anschließend ausgeführte [Android-Lauf 22](https://github.com/Ullmann27/Imperathen/actions/runs/45169603293)
baute und prüfte beide APKs erfolgreich. Die neue Zustandswarteprüfung erreichte
die echte Arbeitsübersicht, deckte aber einen weiteren Bedienungsfehler auf:
Die Arbeitskarten blockierten die Wischbewegungen zum übergeordneten Scrollbereich.
Nach 14 echten Android-Wischbewegungen blieb Aelias aktiviertes Auswahlfeld
unterhalb des sichtbaren Ausschnitts. Der Lauf schlug deshalb korrekt fehl;
die Veröffentlichung wurde übersprungen.
[Androidbericht](evidence/touch-scroll/android22-runtime-report.json) und
[Downloadbeleg](evidence/touch-scroll/android22-download-receipt.json) gehören
ausdrücklich zu diesem fehlgeschlagenen Stand `00d5d041`.

Die Korrektur ist auf das Dorfmenü begrenzt: Karten und gewöhnliche Schaltflächen
reichen Ziehbewegungen an den Scrollbereich weiter. Auswahlmenüs behalten ihre
eigene Eingabebehandlung; der äußere Dialog fängt weiterhin Eingaben vor der
Spielwelt ab. Eine native Touchregression reproduziert den Fehler vor der
Korrektur bei 960 × 540 und 1280 × 720: jeweils 14 Wischbewegungen ohne Bewegung.
Danach wird Aelia mit drei beziehungsweise zwei Wischbewegungen sichtbar.
Eine zusätzliche Wischbewegung, die direkt auf einer aktiven Reparaturschaltfläche
beginnt, scrollt ebenfalls, ohne einen Auftrag auszulösen. Alle 41 Panelprüfungen
bestehen, der Modellzustand bleibt dabei unverändert und es gelangen keine
unbehandelten Berührungen an die Spielwelt.
[Vorher](evidence/touch-scroll/native-drag-before.log) ·
[Nachher](evidence/touch-scroll/native-drag-after.log).

Nach dieser UI-Korrektur wurde der vollständige Godot-Durchlauf erneut ausgeführt:
**33 von 33 Gruppen bestanden, keine Warnungen**, darunter 41 Panelprüfungen und
140 Prüfungen des gesamten Dorfablaufs. Der Android-Python-Prüflauf bestand erneut
alle 30 Tests. [Vollständiger neuer Bericht](evidence/touch-scroll/engine/validation_report.json).

Der anschließend ausgeführte [Android-Lauf 23](https://github.com/Ullmann27/Imperathen/actions/runs/45172468045)
bestätigte die Scrollkorrektur im Android-Emulator: Aelias aktiviertes Auswahlfeld
wurde sichtbar erreicht. Die 22 bis dahin ausgeführten Laufzeitprüfungen bestanden.
Die nachfolgende Arbeitszuweisung blieb jedoch aus; die Veröffentlichung wurde
erneut korrekt übersprungen. Der
[aus dem abgeschlossenen CI-Log extrahierte Laufzeitbericht](evidence/popup-focus/android23-runtime-report.json)
belegt diesen fehlgeschlagenen Zwischenstand `87fec53f`.

Der Prüfer hatte nach dem Öffnen des Auswahlmenüs zwei feste Pfeil-ab-Ereignisse
gesendet. Im tatsächlich verwendeten
[Godot-4.7.2-OptionButton](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/gui/option_button.cpp)
setzt das Öffnen per Maus beziehungsweise emulierter Berührung den Tastaturfokus
nicht zwingend auf die aktuelle Auswahl. Der
[PopupMenu-Code](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/gui/popup_menu.cpp)
beginnt die nächste Navigation beim beobachteten Fokus. Damit sind zwei feste
Tastenschritte kein belastbarer Nachweis für die beabsichtigte Zeile.

Die ergänzte Diagnose liest ausschließlich die tatsächliche Sichtbarkeit,
Instanzkennung, Menüeinträge, den Fokus, die Scrollposition und die sichtbare
Rückmeldung. Der Prüfer wartet nach dem Scrollen auf stabile Koordinaten,
öffnet das echte Auswahlmenü, bestimmt darin den eindeutigen aktivierten Eintrag
„Holzfällerlager“ und beobachtet den Fokus nach jedem nativen Tastenschritt.
Er bestätigt ausschließlich diesen beobachteten Eintrag derselben Menüinstanz.
Geschlossene oder ersetzte Menüs, veränderte Einträge, ausbleibender Fortschritt
und Zeitüberschreitungen bleiben Fehler. Die anschließende echte Arbeitszuweisung
und ihre Erhaltung beim Neustart bleiben zwingende Prüfungen.

Der [Android-Lauf 24](https://github.com/Ullmann27/Imperathen/actions/runs/45175493459)
bestätigte anschließend **43 Pythonprüfungen**, **33 Godot-Prüfgruppen** sowie
beide APK-Exporte und Paketprüfungen. Die Android-Laufzeitprüfung scheiterte
noch vor der neuen Popupnavigation: Die vergrößerte Diagnosemeldung der
Arbeitsübersicht wurde im Android-Protokoll abgeschnitten. Der JSON-Leser
brach deshalb ausdrücklich ab; die Veröffentlichung blieb gesperrt.
[Fehlgeschlagener Laufzeitbericht](evidence/log-transport/android24-runtime-report.json).

Die Diagnose wird jetzt einmal als UTF-8/Base64 kodiert und in nummerierten
Abschnitten mit höchstens 512 ASCII-Zeichen übertragen. Beobachterkennung und
fortlaufende Bildnummer verhindern das Vermischen unterschiedlicher Zustände.
Der Leser verlangt vollständige, zusammengehörige Abschnitte und berücksichtigt
bei einer Bedienaktion bereits begonnene Meldungen. Ein unvollständiger neuer
Zustand darf nicht durch einen älteren vollständigen Zustand ersetzt werden.
Die Diagnose bleibt ausschließlich lesend; alle bisherigen Bedienungs- und
Speicherprüfungen gelten unverändert.

Die wieder verfügbare lokale Godot-4.7.2-Umgebung hat den tatsächlichen neuen
Logger mit einer synthetischen Unicode-Meldung von **5.756 UTF-8-Bytes** ausgeführt:
zwei fortlaufende Zustände mit je 15 Abschnitten wurden bytegenau wiederhergestellt.
Die längste einzelne Meldung hatte einschließlich Kennung **565 ASCII-Bytes**.
Das ist ein gezielter Übertragungsnachweis, kein Android-Gerätetest.
[Maschineller Prüfbericht](evidence/log-transport/producer-probe.json).

Der anschließende Lauf 25 bestand alle 55 Pythonprüfungen, 33 Godot-Gruppen
und 50 Android-Laufzeitprüfungen. Die Veröffentlichung wurde danach erfolgreich
ausgeführt; die konkrete Lieferung und die Abschlussnachweise stehen oben.

## Konkrete Grenzen

- Die vorhandene Grafik ist weiterhin Prototypqualität und erreicht Heinz' AAA-Referenz nicht durchgehend. Gesichter, Haare, Kleidungsverformung, Kampfanimation und individuelle Bewohner benötigen weitere Arbeit.
- 32 × 32 km sind ein adressierbarer Geländerahmen mit getesteten Sektoren. Dreizehn entfernte Orte sind geplant; ihre Markierungen bedeuten keine fertig bewohnten Städte.
- Der historische Rahmen nennt Trajan; örtliche Figuren und Überfälle sind eigene Fiktion. Spielbare Missionen, die belegte Großereignisse verändern, sind noch nicht umgesetzt. [Quellen und Trennung](HISTORICAL_SOURCES.json)
- Das geerbte Replay-Protokoll begrenzt erfolgreiche gekennzeichnete Befehle auf 1.024. Dieser Stand ist deshalb noch keine unbegrenzt fortsetzbare Kampagne. Eine dauerhafte monotone Empfangsbestätigung muss vor dem langen Kampagnentest folgen.
- Die Dorfchronik beginnt bei 100 n. Chr. und erreicht beim Altersübergang 106 n. Chr.; die Saisonanzeige der Weltkugel übernimmt diesen sechsjährigen Versatz noch nicht. Die beiden Kalenderanzeigen sind nach dem Übergang noch nicht synchron.
- Physische Android-Geräte, dauerhafte Temperaturentwicklung und mobile Bildraten sind nicht durch die lokalen Engine- oder Softwarebilder nachgewiesen.

Es erfolgt kein Merge nach `main` und kein Store-Release.
