# Hier weiterarbeiten

**Aktueller Modus: begrenzter Entwicklungsstart, drei Agents.** Der neue Auftrag vom 22.11.2026 erweitert die frühere Vorproduktionssperre; siehe [Entwicklungsstart](../00_governance/DEVELOPMENT_START.md).

## Vor Änderungen

1. AGENTS.md, aktuellen Repository-Kopf, [Projektstatus](../00_governance/PROJECT_STATUS.md) und [Prüfbericht](../05_quality/FOUNDATION_REVIEW.md) lesen.
2. Offene PRs/Branches und [Koordination #16](https://github.com/Ullmann27/Imperathen/issues/16) prüfen. Ungespeicherte fremde Arbeit nicht überschreiben.
3. [Agent-Pipeline](AGENT_PIPELINE.md) lesen. Für die eigene Rolle claimen, nur zugeteilte Dateien bearbeiten, prüfen und mit Dateinachweisen übergeben.

## Was gestartet werden kann

- `npm start`: tatsächlich lauffähige lokale Browser-Vorschau.
- `npm run check`: Kern-, Koordinations- und Quellprüfungen; tatsächlichen Prüfumfang lesen.
- `npm run check:browser`: Browserprüfung mit vorhandener Playwright-/Chromium-Installation.
- `game/Imperathen/`: native Projektbasis; deren erster echter Unreal-Build ist noch auszuführen.

Die Vorschau enthält ein gespeichertes erstes Leben mit drei Handlungen. Sie ist weder die fertige 3D-Welt noch ein Unreal-Build. Bestehende Saveformate nicht stillschweigend inkompatibel ändern.

## Nächster Arbeitsblock

Zuerst die konkrete Unreal-Installation/Toolchain ermitteln und das native Projekt kompilieren; Compiler- und Enginefehler mit realen Logs beheben. Danach in einem eigenen kleinen Abschnitt die begehbare Dorfwelt, das sichtbare Bauen und eine Figur anschließen. Den vorhandenen Menüfluss und Save-Schutz dabei erhalten. [Nächster Implementierungsauftrag](NEXT_IMPLEMENTATION_BRIEF.md).

Keine neuen kostenpflichtigen Dienste, Modell-APIs oder unaufgeforderten Veröffentlichungen starten. Die lokale Pipeline kann das ChatGPT-Kontingent nicht ablesen. Ein späterer intensiver Astra-/Sol-Gesamtcheck braucht einen konkreten Prüfgegenstand und wird dem Nutzer vor einem bewusst zusätzlich gestarteten Modellauftrag erklärt.
