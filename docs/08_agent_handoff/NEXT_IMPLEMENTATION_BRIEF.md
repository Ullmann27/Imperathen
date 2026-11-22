# Nächster Implementierungsauftrag

**Aktualisiert 22.11.2026:** Der Nutzer hat den begrenzten Entwicklungsstart inzwischen beauftragt. Vorspann, Menü, gespeicherter Dorfanfang und lokale Agent-Pipeline bilden die erste Lieferung. Dieser Text beschreibt den anschließenden nativen Spielabschnitt; seine echten Engine-Nachweise stehen noch aus.

## Wofür dieser Auftrag gedacht ist

Die vorhandene Einstiegsvorschau demonstriert den ersten Zustand und die drei Handlungen. Der nächste Schritt überträgt den zuverlässigen Zusammenhang in eine tatsächlich begehbare Engine-Szene. Die alte Mappe bündelt unter einem „P0“ mehrere große Produktionsphasen; sie werden weiterhin in prüfbaren Abschnitten umgesetzt.

## Vor Beginn tatsächlich feststellen

Aktuelle Nutzervorgabe, Repository-Kopf, verfügbare Engine und Version, Toolchain, Hardware, Schreibzugang und ausführbare Tests. Unbekannte Daten nicht durch Annahmen ersetzen. Ein fehlender Enginezugang kann die Arbeit auf explizit beauftragte, unabhängig prüfbare Teile begrenzen; er rechtfertigt keine Behauptung eines gebauten Spiels.

## Vorgeschlagene erste Lieferung

Zuerst `game/Imperathen/Imperathen.uproject` auf einer tatsächlich vorhandenen Unreal-Installation kompilieren und starten. Danach einen minimalen Spielbereich umsetzen, in dem eine kontrollierte Figur eine vorhandene Ressource einsammelt, eine einfache Baustelle auf erlaubtem Grund anlegt, den Bestand konsistent verändert und diesen Zustand speichern und laden kann. Der Wechsel in eine einfache Bauansicht darf weder Inventar noch Aufenthaltsort duplizieren. Die Darstellungsqualität ist zunächst funktional.

Diese erste Lieferung hat absichtlich weniger Umfang als der vollständige spätere Dorfabschnitt. Gefährte, Kampf, regionale Karte und adaptive Fortsetzung werden in anschließenden getrennten Lieferungen angeschlossen. So wird ein Speicher- oder Zustandsfehler nicht erst nach großer Inhaltsproduktion entdeckt.

## Mindestnachweise dieser ersten Lieferung

1. Vorhandene Ressource und Besitz-/Nutzungsverhältnis sind explizit.
2. Dieselbe Sammelaktion kann nicht zweimal ausgezahlt werden.
3. Unzureichender oder reservierter Bestand erzeugt keine gültige Doppelbuchung.
4. Baustelle kann pausieren; bereits bestätigter Fortschritt bleibt erhalten.
5. Speichern/Laden erhält Ort, Vorrat, Reservierung und Fortschritt.
6. Ein tatsächlicher Build oder unabhängig ausführbarer Teil wird nur dann als solcher bezeichnet, wenn er wirklich erstellt und ausgeführt wurde.

## Erst danach

Gefährtenbegegnung mit Beziehung und Ereignis; eindeutiger Alters-/Zeitübergang; kleine erwachsene Kampfsituation mit Folgebuchung; regionaler Kartenbezug; kontrollierte Episode mit mindestens zwei gültigen Entscheidungen; Ausfallfortsetzung. Jede Lieferung erweitert einen bereits funktionierenden Zusammenhang.

## Grenzen und Kosten

Keine komplette Provinzwelt, keine 500.000 detaillierten Einheiten, keine fotorealistische Gesamtproduktion und kein Live-KI-Dienst als Voraussetzung des ersten Nachweises. Vor zusätzlichen externen Leistungen den konkreten Zweck und Kostenrahmen nennen. Die öffentliche Sichtbarkeit bleibt entsprechend Nutzerentscheidung bestehen.

## Abschluss

Quellstand, genaue Umgebung, Startanleitung, tatsächlich ausgeführte Prüffälle, Fehler und kurze echte Aufnahmen liefern. Konzeptbilder aus der Quellmappe werden nicht als Screenshots dieser Lieferung ausgegeben. Die Abnahme schließt nur den beauftragten kleinen Umfang ab.
