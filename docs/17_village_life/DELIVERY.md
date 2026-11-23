# IMPERATHEN – wiederaufgenommener Dorfanfang

23. November 2026 · Arbeitsbranch `feature/village-life-delivery-20261123`

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

Die beiden lokalen Korrekturen werden mit dieser Quellsicherung in den bestehenden
Lieferzweig übernommen und lösen den vorhandenen Android-Workflow aus. Der frische
Android-Lauf und die Veröffentlichung sind an diesem Quellcheckpoint noch nicht
abgeschlossen. Ein APK-Download wird erst nach erfolgreichem Bau, tatsächlichem
Android-Lauf und Prüfung der passenden Quelldateien angegeben. Frühere Hero- oder
Opening-APKs werden nicht als neue Dorfleben-APK ausgegeben.

## Konkrete Grenzen

- Die vorhandene Grafik ist weiterhin Prototypqualität und erreicht Heinz' AAA-Referenz nicht durchgehend. Gesichter, Haare, Kleidungsverformung, Kampfanimation und individuelle Bewohner benötigen weitere Arbeit.
- 32 × 32 km sind ein adressierbarer Geländerahmen mit getesteten Sektoren. Dreizehn entfernte Orte sind geplant; ihre Markierungen bedeuten keine fertig bewohnten Städte.
- Der historische Rahmen nennt Trajan; örtliche Figuren und Überfälle sind eigene Fiktion. Spielbare Missionen, die belegte Großereignisse verändern, sind noch nicht umgesetzt. [Quellen und Trennung](HISTORICAL_SOURCES.json)
- Das geerbte Replay-Protokoll begrenzt erfolgreiche gekennzeichnete Befehle auf 1.024. Dieser Stand ist deshalb noch keine unbegrenzt fortsetzbare Kampagne. Eine dauerhafte monotone Empfangsbestätigung muss vor dem langen Kampagnentest folgen.
- Physische Android-Geräte, dauerhafte Temperaturentwicklung und mobile Bildraten sind nicht durch die lokalen Engine- oder Softwarebilder nachgewiesen.

Es erfolgt kein Merge nach `main` und kein Store-Release.
