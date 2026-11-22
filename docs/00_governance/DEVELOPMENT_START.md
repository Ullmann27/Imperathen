# Entwicklungsstart – 22. November 2026

## Neuer Auftrag

Heinz hat nach der Vorproduktion ausdrücklich den Spielaufbau beauftragt: auf dem vorhandenen Repository und den bisherigen Chats aufsetzen, drei Agents koordinieren, Vorspann und Hauptmenü entwickeln und eine dafür vorgesehene Agent-Pipeline einrichten. Dieser Auftrag erweitert die alte Grenze „noch keine Spielprogrammierung“ für den hier beschriebenen Einstieg. Es ist keine neue Rückfrage für bereits beauftragte reversible Entwicklungsarbeit erforderlich.

## Tatsächlich gefundener Ausgangsstand

- Zugängliches Projekt: `Ullmann27/Imperathen`, GitHub meldete **public**.
- Vorproduktion: PR #1, `docs/bootstrap-governance-20261122`, Commit `a3e036ba24b99416b016337d81ab2b4067350fa3`.
- `main`: `e9e1bb16da02de9217e422fa013fdafdb5b80a80`.
- Beim Einstieg waren diese zwei Branches sichtbar. Kein weiterer aktiver Spielcode, ausführbarer Agent-Runner oder separates privates Rome-Repository war im verbundenen Zugang sichtbar. Das ist keine Aussage über ungespeicherte Arbeiten anderer Sitzungen.
- Die Sichtbarkeit wurde nicht geändert. Die neue Koordination ist [Issue #16](https://github.com/Ullmann27/Imperathen/issues/16).

## Aktuelle Lieferung

Ein eigener Branch `feat/entry-foundation-three-agents-20261122` erweitert die Vorproduktion. Die drei Rollen bearbeiten abgegrenzte Dateien. Der Integrator prüft die gemeinsame Lieferung und hält einen eigenen Draft-PR bereit, ohne den Dokumentations-PR fremd zu überschreiben.

Die lokal prüfbare Einstiegsvorschau enthält Vorspann, Hauptmenü, Einstellungen, Speicherstände und einen kleinen Dorfablauf. Das ist eine funktionale Vorstufe für Gestaltung und Zustandsverhalten. Sie ersetzt nicht die geplante große 3D-Stadt-, Kampf- und Weltsimulation.

Die Unreal-Projektbasis wird getrennt unter `game/Imperathen/` geführt. Unreal 5 bleibt der bisherige Zielvorschlag; keine konkrete Engineversion wird als erfolgreich gebaut ausgegeben. In dieser Arbeitsumgebung stehen Node, Python, ein C++-Compiler und Chromium zur Verfügung, aber weder UnrealEditor noch UnrealBuildTool. Native Engine- und Pakettests benötigen daher eine vorhandene Unreal-Installation.

## Budget und Integration

Keine zusätzlichen kostenpflichtigen Dienste, GPU-Aufträge oder Modell-APIs wurden beauftragt. Die lokale Agent-Pipeline startet keine Sprachmodelle und kann das persönliche ChatGPT-Kontingent weder ablesen noch begrenzen. Ein gezielter tiefer Gesamtcheck durch Astra/Sol bleibt ein späterer Arbeitsschritt; es wird keine Kosten- oder Kontingentfreiheit versprochen.

Ein Merge nach `main`, die Freischaltung neuer Dienste und die endgültige Marke sind nicht Teil dieser Lieferung. Bereits autorisierte Entwicklungsarbeit wird unabhängig davon vollständig ausgeführt. Historische Vorproduktionsdokumente und ältere Issues werden zeitlich eingeordnet; ihre früheren Grenzen heben diesen neueren Auftrag nicht auf.
