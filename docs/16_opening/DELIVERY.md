# Spielanfang – geprüfter Beitrag für Chat 1

Stand: 23. November 2026. Ausführbarer Quellstand: `b356a0c8e3a01285d5c55fc426299fe94d8b30d9`. Unterstützungs-PR: [#35](https://github.com/Ullmann27/Imperathen/pull/35), aufbauend auf [#34](https://github.com/Ullmann27/Imperathen/pull/34). Branch: `feature/cinematic-opening-20261123`. Ziel des PR ist `feature/hero-realism-20261122`; es erfolgte kein Merge nach `main`.

## Was jetzt im Spiel funktioniert

Der erste Tag beginnt nach der Herkunftswahl mit fünf Einstellungen in der tatsächlichen Spielwelt. Dorf und Straße setzen den Rahmen; Livia erklärt das freigegebene Holz und den Bauplatz. Marcus bittet am Brunnen um vier Holzstücke. Der Blick auf den Bauplatz führt zum persönlichen Ziel: **ein Dach vor dem Abend**. Die Kamera zeigt abschließend die Spielerfigur und fährt in die reguläre Spielansicht zurück.

Die fünf Einstellungen benötigen automatisch ungefähr 43 Sekunden. Lesemodus, Weiter, Pause und Überspringen lassen dem Spieler Kontrolle über das Tempo. Nach dem Film wartet eine Zielkarte bis zur Bestätigung: acht Holz für die Unterkunft, gegebenenfalls vier weitere für Marcus, anschließend östlich des Weges bauen. Auch Überspringen erreicht diese Orientierung, bevor die Weltsteuerung freigegeben wird.

Die erste Begegnung wird durch tatsächlich vorhandene Spielregeln getragen. Hilfe verbraucht vier Holz und setzt das Vertrauen auf +20. Ablehnung verbraucht kein Holz und setzt es auf −5. Später wiederkommen trifft keine dauerhafte Entscheidung. Fehlt Holz, erklärt eine gesperrte Hilfsantwort den Grund. Die Brunnenstrebe erscheint zuerst gebrochen und nach erfolgreicher Hilfe repariert. Sie wird ausschließlich aus der gespeicherten Gefährtenentscheidung abgeleitet.

Die bestehende Ausbildung bleibt an ihre bisherigen Voraussetzungen gebunden. Vor dem Übergang wird angekündigt, dass sechs Jahre vergehen. Erst der erfolgreiche Spielbefehl führt zur Erwachsenenmontage; diese erinnert an die tatsächlich getroffene Gefährtenentscheidung. Kamera und Untertitel vergeben keine Güter und lassen die Figuren nicht selbst altern. Alle fünf vorhandenen Herkünfte haben passende Namen und Texte.

## Inszenierung und Bedienung

- Fünf Kameraaufbauten mit sanften Fahrten, vorhandenen Weltankern und reversibler Lichtanpassung. Die bisherige Spielkamera und Beleuchtung werden wiederhergestellt.
- Ruhige Schriftgestaltung in Elfenbein, Bronze und dunklem Rot; Kapitel, Ort, Sprecher und Fortschritt bleiben klar getrennt. Safe Areas, vergrößerte Schrift und quadratische Ansichten sind berücksichtigt.
- Lesemodus, reduzierte Kamerabewegung, Pause, Tastatur, Controller und Touch sind angeschlossen. Android-Zurück pausiert den Film; ein Hintergrundwechsel hält die Szene an.
- Ein eigener kleiner Checkpoint setzt nach Neustart am Anfang der zuletzt erreichten Einstellung fort. Ein abgeschlossenes Intro wird nicht bei jedem Laden wiederholt.
- Fehlgeschlagene Kampagnenspeicherung lässt die Erwachsenenmontage im Pausenzustand warten. Ein Darstellungsmarker wird nicht als Beleg für einen erfolgreich gespeicherten Lebenslauf behandelt.

Dialoge, Szenenaufbau und Datenvertrag stehen im [Regiebuch](REGIEBUCH.md).

## Ausgeführte Prüfung

Der vollständige lokale Prüflauf mit Godot **4.7.2** hat **21 Prüfstationen ohne Warnungen bestanden**. Die fünf zusätzlichen Opening-Suiten umfassen **269 Einzelchecks**: Erzählung 59, Brunnenmodell 36, Kameraregie 76, Oberfläche 66 und integrierter Ablauf 32. Bestehende Prüfungen für Weltmodell, Bauen, Ausbildung, Kampf, Figuren, Anzeige und Fortsetzen bleiben erfolgreich.

Der [erste Enginebericht](evidence/engine/validation_report.json) und der [erneute Bericht nach der Himmelskorrektur](evidence/refinement-engine/validation_report.json) enthalten Resultate, Laufzeiten und SHA-256 der tatsächlich geprüften Quellen. Beide vollständigen Läufe bestanden. Die CI führte dieselben 21 Prüfstationen auf dem gebauten Quellstand erfolgreich aus. Die zugehörigen Headless-Läufe sind keine Bild- oder Frameratenbelege.

Zusätzlich wurde Chat 1s aktueller Frontier-Arbeitsstand in einer getrennten Kopie mit den drei gemeinsam bearbeiteten Hauptdateien zusammengeführt. Nach frischem Import bestanden dort **1.419 Szenario- und Regelprüfungen** aus Frontier-Erzählung, Figuren, Bevölkerung, Opening-Ablauf und beiden Integrationssuiten. Der vorhandene Frontier-Integrationstest musste nach Neuanfang und Ausbildung zunächst die neuen echten Intro-Bedienelemente durchlaufen; seine bisherigen inhaltlichen Assertions blieben erhalten. Der [Kombinationsbericht](integration/combined-evidence/combined-validation-report.json) trennt den unveränderten Ausgangslauf von der anschließenden erfolgreichen Testanpassung.

## Tatsächliche Bildnachweise

Die erste Abnahme unter [evidence/render](evidence/render) bleibt unverändert erhalten. Nach der gezielten Himmelskorrektur entstanden der [aktuelle Talblick](evidence/sky-seam/1280x720-valley-corrected.png) und der [aktuelle Film](evidence/sky-seam/opening-runtime-excerpt.mp4) in einem neuen normalen Spielprozess. Die [Bildprüfung](evidence/sky-seam/sky-seam-review.json) belegt die entfernte Texturabtastnaht; ein Kontrollbereich im Himmel blieb pixelgleich. Alle Dateien stammen aus Godot und zeigen die implementierte Welt. Fünf Standbilder zeigen die Grafikstufe „Sehr hoch“: vier in 1280 × 720 und eine quadratische Ansicht in 1024 × 1024. Der kurze Film `opening-runtime-excerpt.mp4` ist ein **12 Sekunden langer Regieauszug**, kein vollständiger Durchlauf des ungefähr 43 Sekunden langen Intros. Er zeigt jeweils zwei Sekunden aus fünf Einstellungen sowie die Zielkarte mit unveränderter Kamerageschwindigkeit.

Der Film wird in „Ausgewogen“ mit 1280 × 720 und 12 aufgenommenen Bildern pro Sekunde erstellt. Diese zeitgesteuerte Softwareaufnahme belegt keine gemessene Spielleistung. Die vorhandene Datei `prototype/assets/frontier_ambience.wav` wird für die Videopräsentation nachträglich mit −15 dB unterlegt. Es gibt keine gesprochenen Dialogaufnahmen. Aufnahmeparameter, die vor und nach dem Capture identischen 14 Quellhashes einschließlich des korrigierten Wolkenshaders, Dateihashes und der tatsächliche Reparaturvergleich stehen im [aktuellen Filmbeleg](evidence/sky-seam/motion-review.json). Der aktuelle Film enthält 144 frisch gerenderte Frames; der vollständige Dekodierungstest verlief fehlerfrei.

## Übernahme durch Chat 1

Die laufende Chat-1-Arbeitskopie wurde nicht verändert. Der [Integrationshinweis](integration/README.md) erklärt die vorbereitete Zusammenführung. `chat1-opening.patch` betrifft ausschließlich Main, Spielwelt und Oberfläche; die zusätzlichen Opening-Module werden aus diesem Branch übernommen. Der Prüfer in Version 2 bindet den Patch an die exakten gelesenen Hauptdateien sowie an alle fünf Laufzeitmodule und deren fünf UID-Dateien. 17 gezielte Fälle bestätigen korrekte Übernahme und Ablehnung veralteter oder unvollständiger Dateien ohne Schreibänderung. Er prüft standardmäßig nur und schreibt ausschließlich mit `--apply`. Der separate `sky-seam.patch` besitzt einen eigenen Prüfer und drei nachgewiesene Kopienprüfungen; dadurch lässt sich die Himmelskorrektur ohne Ersatz der übrigen Weltgestaltung übernehmen.

Die Zusammenführung erhält insbesondere Frontier-Dialoge und Befehle, Dorfbevölkerung, Aufgabenkarte, Blicksteuerung und Wagenfortschritt. Die getrennte Engineprüfung belegt die erfasste Kombination; weiterlaufende Änderungen von Chat 1 benötigen erneut einen Abgleich.

## Qualitätsstand und verbleibende Arbeit

Dieser Beitrag liefert einen ausführbaren, erzählerisch begründeten und unterbrechbaren Einstieg. Die Bilder zeigen weiterhin die übernommenen Prototypmodelle und ihre tatsächliche Detailstufe. Das gewünschte PC-/PS5-Gefühl bleibt bei Figuren, Materialdetail, Gesichtsanimation und sprachlichem Schauspiel ein Produktionsziel. Insbesondere Livia hat in dieser Basis noch kein eigenes Modell; ihre Zeile erscheint während der Markteinstellung als Untertitel. Die Brunnenreparatur zeigt zwei gespeicherte Zustände, noch keinen animierten Arbeitsablauf.

## Gebaute und geprüfte Dateien

Der [CI-Lauf 45115192890](https://github.com/Ullmann27/Imperathen/actions/runs/45115192890) auf `b356a0c8e3a01285d5c55fc426299fe94d8b30d9` endete erfolgreich. Android bleibt die Zielplattform; zusätzlich erzeugte der bereits vorhandene Bauweg Desktop-Prüfdateien.

| Datei | Nachweis |
| --- | --- |
| `IMPERATHEN-b356a0c8-arm64.apk` | 107.859.841 Byte; Signatur, Manifest, ARM64-Bibliothek, Ressourcen und ZIP-Ausrichtung bestanden; nach Download SHA-256 geprüft |
| `IMPERATHEN-b356a0c8-Windows-x86_64.zip` | 112.285.576 Byte; nach Download SHA-256, ZIP-CRC, x86_64-PE und eingebetteter Godot-Datenteil geprüft; keine Windows-Laufzeitprüfung |
| `IMPERATHEN-b356a0c8-Pruefnachweise.zip` | APK-/Laufzeitnachweise, Prüfsummen und ausschließlich verschlüsselte Sicherung des Test-Signierschlüssels |

Der tatsächliche Android-15/API-35-Lauf mit x86_64 bestand **41 Bedien- und Laufzeitprüfungen**. Intro, Zurück/Pause, Wiederaufnahme, Überspringen, die Touch-Bestätigung der Zielkarte sowie Speichern, Neustart und Fortsetzen sind darin enthalten. Die ARM64-Download-Datei wurde zusätzlich unter Emulatorübersetzung installiert und bis zur gerenderten Startoberfläche ausgeführt. Ein physischer Telefontest bleibt offen. Die [echten Android-Bilder](evidence/android-ci/10_android_opening.png) und der [heruntergeladene Laufzeitbericht](evidence/android-ci/downloaded-runtime-report.json) gehören zu diesem Quellstand.

Alle fünf neuen Intro-Module und der bytegenau korrigierte Wolkenshader wurden auch in der heruntergeladenen APK nachgewiesen. Der [Dateinachweis](evidence/android-ci/downloaded-apk-validation.json) und der [Desktopnachweis](evidence/android-ci/downloaded-desktop-validation.json) dokumentieren die Grenzen dieser Prüfungen. Das Linux-Paket startete in der CI erfolgreich im Headless-Modus; daraus wird kein Windows-Spieltest abgeleitet.

Der Build verwendet einen neu erzeugten Test-Signierschlüssel. Eine frühere anders signierte Installation lässt sich gegebenenfalls nicht direkt damit aktualisieren; vorhandene Spielstände vor einem Wechsel sichern. Die verschlüsselte Schlüsselsicherung liegt bei den Prüfnachweisen. Eine PS5-Version oder ein Store-Release ist nicht Bestandteil dieses Beitrags.
