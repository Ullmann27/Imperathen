# Geprüfte Zusammenführung für Chat 1

Dieses Paket führt den filmischen Anfang mit dem separat gelesenen, bereits erweiterten Frontier-Arbeitsstand zusammen. Es ersetzt keine Hauptdatei durch eine ältere Fassung. Der Patch ändert ausschließlich:

- `prototype/scripts/main.gd`
- `prototype/scripts/world/game_world.gd`
- `prototype/scripts/ui/game_ui.gd`

Ausgangsbasis des Dreiwegevergleichs ist Commit `148dd69`. Vier Konflikte in Main und zwei in der Spielwelt wurden in einer getrennten Staging-Kopie gelöst; UI ließ sich ohne Textkonflikt zusammenführen. Die drei Inhalte des aktiven Chat-1-Checkouts wurden vor und nach Erstellung anhand SHA-256 verglichen. Das aktive Checkout und die Hauptdateien des Opening-Branches wurden dabei nicht verändert.

## Erhaltene Funktionen

Main behält `frontier_npc`, `_ui_state()`, `frontier_objective`, `set_frontier_time`, die Frontier-Dialoge, die zugehörigen zulässigen Befehle und deren Speicherung. Die Opening-Funktionen einschließlich wartender Zielkarte, Checkpoints, Pause, Wiederaufnahme und `pending_opening` bei einem fehlgeschlagenen Kampagnensave werden hinzugefügt. Vor Übernahme durch die Filmkamera wird ein noch offener Frontier-Fokus gezielt aufgehoben.

Die Spielwelt behält die Dorfpopulation, ihre Positionen, Blicksteuerung, den Wagenfortschritt und sämtliche Frontier-Schnittstellen. Dazu kommen die Filmkamera-Anker und die aus der bestehenden Gefährtenentscheidung abgeleitete Brunnenstrebe. Die Oberfläche behält Frontier-Dialoge und Aufgabenkarte; ihre zusätzlichen Funktionen sind die Filmoberfläche, gespeicherter Lesemodus, gesperrte Hilfsantwort bei zu wenig Holz und der sichtbare Hinweis auf den sechsjährigen Übergang.

## Vor dem Anwenden

Die fünf zusätzlichen Laufzeitdateien aus dem Opening-Branch müssen bereits im Zielcheckout vorhanden sein. Sie sind im Manifest unter `required_additive_files` aufgeführt. Die mitgelieferten Opening-Tests und ihre Prüfläufer gehören ebenfalls zur Gesamtintegration, werden aber nicht durch diesen auf drei bestehende Dateien begrenzten Patch installiert.

Das Manifest `chat1-opening-guard.json` enthält für jede der drei Dateien die exakt gelesene Chat-1-Prüfsumme und die Prüfsumme der geprüften Zusammenführung. Außerdem bindet es die konkrete Patchdatei an deren SHA-256. Falls Chat 1 seither weitergeschrieben hat, muss die neue Fassung erneut zusammengeführt werden. Keine Hashprüfung entfernen und keine fremden Änderungen durch alte Komplettdateien ersetzen.

## Prüfen und anwenden

Im folgenden Aufruf ist `/pfad/zum/chat1-checkout` durch das beabsichtigte Zielcheckout zu ersetzen. Der erste Aufruf führt ausschließlich Prüfungen aus:

```bash
python docs/16_opening/integration/apply_chat1_opening.py --repo /pfad/zum/chat1-checkout
```

Wenn die zusätzliche Prüfung den aktuellen Stand bestätigt, wendet dieser ausdrückliche Aufruf den Patch an:

```bash
python docs/16_opening/integration/apply_chat1_opening.py --repo /pfad/zum/chat1-checkout --apply
```

Der Prüfer kontrolliert vor dem Anwenden nochmals sämtliche Quellhashes und anschließend die Ergebnishashes. Er erstellt weder einen Commit noch einen Indexeintrag. Während des eigentlichen Anwendens sollen keine anderen Prozesse dieselben drei Dateien bearbeiten. Ändert sich der Inhalt vor der Anwendung, bricht der Prüfer ab; die Auflösung muss dann auf dem neuen Stand erfolgen.

## Nachweisgrenze

`git apply --check` wurde gegen die unveränderte erfasste Chat-1-Kopie erfolgreich ausgeführt. Die separate Guard-Prüfung dokumentiert den kontrollierten Staging-Lauf.

Zusätzlich wurde eine weitere vollständige Kopie frisch in Godot importiert und tatsächlich ausgeführt: **sechs Szenario-/Regelgruppen mit insgesamt 1.419 Prüfungen bestanden**, dazu der frische Import, ohne Warnungen. Die Zusammenstellung, die anfängliche Testanpassung und die Nachweisgrenzen stehen in [COMBINED_CHECK.md](COMBINED_CHECK.md). Das ist ein gemeinsamer Engine-Nachweis; ein physischer Android-Lauf oder eine Grafikabnahme wird damit nicht behauptet.

Der separate `frontier-integration-test.patch` ergänzt ausschließlich in Chat 1s bestehendem Integrationstest die neuen Schritte „Film überspringen → Zielkarte annehmen“. Alle alten Assertions bleiben erhalten; die vorhandenen Prüfungen werden weiterhin über echte Main-, UI- und Weltaktionen ausgeführt. `frontier-integration-test-guard.json` bindet diese zusätzliche Testanpassung an die exakt gelesene ursprüngliche Testdatei. Der Produktionspatch bleibt unverändert auf drei Dateien begrenzt. Vor der Übernahme des Testpatches ebenfalls die dort gespeicherte Ausgangs-SHA prüfen; bei Abweichungen den aktuellen Test erneut zusammenführen.
