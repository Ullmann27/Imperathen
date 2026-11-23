# Spielanfang – geprüfter Beitrag für Chat 1

Stand: 23. November 2026. Unterstützungs-PR: [#35](https://github.com/Ullmann27/Imperathen/pull/35), aufbauend auf [#34](https://github.com/Ullmann27/Imperathen/pull/34). Branch: `feature/cinematic-opening-20261123`. Ziel des PR ist `feature/hero-realism-20261122`; es erfolgte kein Merge nach `main`.

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

Der [Enginebericht](evidence/engine/validation_report.json) enthält Resultate, Laufzeiten und SHA-256 der tatsächlich geprüften Quellen. Die zugehörigen Logs liegen im selben Verzeichnis. Dieser Lauf verwendet den Headless-Treiber und ist kein Bild- oder Frameratenbeleg.

Zusätzlich wurde Chat 1s aktueller Frontier-Arbeitsstand in einer getrennten Kopie mit den drei gemeinsam bearbeiteten Hauptdateien zusammengeführt. Nach frischem Import bestanden dort **1.419 Szenario- und Regelprüfungen** aus Frontier-Erzählung, Figuren, Bevölkerung, Opening-Ablauf und beiden Integrationssuiten. Der vorhandene Frontier-Integrationstest musste nach Neuanfang und Ausbildung zunächst die neuen echten Intro-Bedienelemente durchlaufen; seine bisherigen inhaltlichen Assertions blieben erhalten. Der [Kombinationsbericht](integration/combined-evidence/combined-validation-report.json) trennt den unveränderten Ausgangslauf von der anschließenden erfolgreichen Testanpassung.

## Tatsächliche Bildnachweise

Die Dateien unter [evidence/render](evidence/render) stammen aus Godot und zeigen die implementierte Welt. Fünf Standbilder zeigen die Grafikstufe „Sehr hoch“: vier in 1280 × 720 und eine quadratische Ansicht in 1024 × 1024. Der kurze Film `opening-runtime-excerpt.mp4` ist ein **12 Sekunden langer Regieauszug**, kein vollständiger Durchlauf des ungefähr 43 Sekunden langen Intros. Er zeigt jeweils zwei Sekunden aus fünf Einstellungen sowie die Zielkarte mit unveränderter Kamerageschwindigkeit.

Der Film wird in „Ausgewogen“ mit 1280 × 720 und 12 aufgenommenen Bildern pro Sekunde erstellt. Diese zeitgesteuerte Softwareaufnahme belegt keine gemessene Spielleistung. Die vorhandene Datei `prototype/assets/frontier_ambience.wav` wird für die Videopräsentation nachträglich mit −15 dB unterlegt. Es gibt keine gesprochenen Dialogaufnahmen. Aufnahmeparameter, Quellhashes, Dateihashes und der tatsächliche Reparaturvergleich werden in den Aufnahmebelegen dokumentiert.

## Übernahme durch Chat 1

Die laufende Chat-1-Arbeitskopie wurde nicht verändert. Der [Integrationshinweis](integration/README.md) erklärt die vorbereitete Zusammenführung. `chat1-opening.patch` betrifft ausschließlich Main, Spielwelt und Oberfläche; die zusätzlichen Opening-Module werden aus diesem Branch übernommen. Ein Prüfer bindet den Patch an die exakten gelesenen Quelldateien und verweigert veraltete Stände. Er prüft standardmäßig nur und schreibt ausschließlich mit `--apply`.

Die Zusammenführung erhält insbesondere Frontier-Dialoge und Befehle, Dorfbevölkerung, Aufgabenkarte, Blicksteuerung und Wagenfortschritt. Die getrennte Engineprüfung belegt die erfasste Kombination; weiterlaufende Änderungen von Chat 1 benötigen erneut einen Abgleich.

## Qualitätsstand und verbleibende Arbeit

Dieser Beitrag liefert einen ausführbaren, erzählerisch begründeten und unterbrechbaren Einstieg. Die Bilder zeigen weiterhin die übernommenen Prototypmodelle und ihre tatsächliche Detailstufe. Das gewünschte PC-/PS5-Gefühl bleibt bei Figuren, Materialdetail, Gesichtsanimation und sprachlichem Schauspiel ein Produktionsziel. Insbesondere Livia hat in dieser Basis noch kein eigenes Modell; ihre Zeile erscheint während der Markteinstellung als Untertitel. Die Brunnenreparatur zeigt zwei gespeicherte Zustände, noch keinen animierten Arbeitsablauf.

Android bleibt die Zielplattform. Der Android-Prüfläufer wurde für Intro, Zurück, Pause, Überspringen und Zielkarte ergänzt; für diesen neuen Branch wurde hier keine frische APK gebaut und kein physisches Android-Gerät geprüft. Nach Übernahme in Chat 1 folgen dessen Android-Bau und Geräteprüfung. Grafikaufnahmen aus der Entwicklungsumgebung ersetzen diese Freigabe nicht.
