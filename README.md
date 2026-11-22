# IMPERATHEN

**Arbeitstitel · Einstieg 0.1 · Stand: 22. November 2026**

IMPERATHEN verbindet als Ziel persönliches Rollenspiel, Echtzeit-Städtebau, eine strategische Weltkarte, Diplomatie und eine an Entscheidungen anknüpfende Geschichte. Der erste Entwicklungsstand enthält eine lokal spielbare Einstiegsvorschau: Vorspann, Hauptmenü, Einstellungen, einen gespeicherten Dorfanfang und eine ausführbare Drei-Agent-Pipeline. Eine native Unreal-Projektbasis liegt getrennt vor und benötigt ihren ersten Engine-Build.

## Direkt starten

Mit Node 20 oder neuer und Python 3; es gibt keine npm-Abhängigkeiten und keinen externen Dienst für die Vorschau:

```sh
npm start
```

Im Browser `http://127.0.0.1:4173` öffnen. Der Server bindet nur an den lokalen Rechner. Neues Leben → Name eingeben → Holz sammeln → Unterstand errichten → Marcus helfen. Fortschritt und Einstellungen liegen in diesem Browser. Fortsetzen lädt nur einen gültigen vorhandenen Stand. Ein neues Leben ersetzt ihn erst nach ausdrücklicher Bestätigung.

```sh
npm test
npm run check
npm run agents
```

`npm run build:preview` erzeugt zusätzlich eine einzelne HTML-Datei für die Vorschau. Das ist keine Windows-EXE oder Unreal-Paketierung. [Unreal-Projektbasis und ihre Prüfgrenzen](game/Imperathen/README.md), [Prüfbericht](docs/05_quality/FOUNDATION_REVIEW.md), [Agent-Pipeline](docs/08_agent_handoff/AGENT_PIPELINE.md).

## Hier anfangen

1. [Aktueller Entwicklungsauftrag](docs/00_governance/DEVELOPMENT_START.md) und [Spielziel](docs/01_product/PROJECT_CHARTER.md)
2. [Anforderungen und ihre Zuordnung](docs/01_product/REQUIREMENTS_REGISTER.md)
3. [Aktueller Projektstatus](docs/00_governance/PROJECT_STATUS.md)
4. [Arbeitsplan und GitHub-Aufgaben](docs/06_production/BACKLOG.md)
5. [Startanweisung für den nächsten Entwicklungsagenten](docs/08_agent_handoff/START_HERE.md)

## Was hier vorbereitet wird

| Bereich | Einstieg |
| --- | --- |
| Spielsysteme und Lebensweg | [Spielpfeiler](docs/02_game_design/GAME_PILLARS.md) und [Spielerverlauf](docs/02_game_design/PLAYER_JOURNEY.md) |
| Stadt, Wirtschaft und Armeen | [Stadt und Wirtschaft](docs/02_game_design/CITY_AND_ECONOMY.md), [Kampf](docs/02_game_design/ARMIES_AND_COMBAT.md) |
| Weltkarte und Politik | [Welt und Diplomatie](docs/02_game_design/WORLD_AND_DIPLOMACY.md) |
| Eingabe und Lesbarkeit | [Bedienung und Zugänglichkeit](docs/02_game_design/CONTROLS_AND_ACCESSIBILITY.md) |
| Technische Verträge | [Weltzustand und Zeit](docs/03_engineering/WORLD_STATE_AND_TIME_CONTRACT.md), [Erzählung](docs/03_engineering/NARRATIVE_CONTRACT.md) |
| Grafik, Audio und Herkunft | [Produktionsplan](docs/04_art_audio/ART_AND_AUDIO_PLAN.md), [Bildreferenzen](docs/09_sources/VISUAL_REFERENCE_INDEX.md) |
| Qualität und Nachweise | [Teststrategie](docs/05_quality/TEST_STRATEGY.md), [Abnahmematrix](docs/05_quality/ACCEPTANCE_MATRIX.md) |
| Entscheidungen und Risiken | [Entscheidungsprotokoll](docs/00_governance/DECISION_LOG.md), [Risiken](docs/00_governance/RISK_REGISTER.md) |
| Name und Rechte | [Namensprüfung](docs/07_legal/NAME_REVIEW.md), [Rechteplan](docs/07_legal/RIGHTS_AND_PROVENANCE.md) |

## Arbeitsstand und Regeln

GitHub meldete das zugängliche Repository beim Arbeitsbeginn als **öffentlich**. Die Sichtbarkeit wurde nicht geändert. Ein separates privates Rome-Repository war im verbundenen Zugang nicht sichtbar. Die Kooperation mit weiteren Bearbeitern läuft über [Issue #16](https://github.com/Ullmann27/Imperathen/issues/16), eindeutige Dateizuständigkeiten und den eigenen Entwicklungsbranch.

Der neuere Auftrag aktiviert Vorspann, Hauptmenü und den begrenzten Spielaufbau mit drei Agents. Er erweitert die frühere Vorproduktionsgrenze. Die große 3D-Welt, frei steuerbare Figur, Kämpfe und Stadtbausimulation sind noch nicht implementiert. Neue kostenpflichtige Dienste oder Modell-APIs sind nicht Bestandteil dieser Lieferung. Siehe [AGENTS.md](AGENTS.md).

IMPERATHEN ist ein vorläufiger Name. Dieses Repository behauptet weder eine abgeschlossene Markenprüfung noch eine Markenregistrierung. Die ältere Projektmappe „IRON BANNERS“ bleibt als Herkunftsquelle erkennbar; maßgeblich sind die aktuellen konsolidierten Anforderungen und der neuere Entwicklungsauftrag.

Konzeptbilder, Zielwerte und Testpläne sind keine Nachweise eines fertigen Spiels. Fortschritt wird mit Dateien, Entscheidungen, Aufgaben und später mit tatsächlich ausgeführten Tests und Builds dokumentiert.
