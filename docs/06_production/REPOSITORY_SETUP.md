# GitHub-Gründung und tatsächlicher Einrichtungsstand

**Repository:** `Ullmann27/Imperathen`  
**Sichtbarkeit:** öffentlich, ausdrücklich so gewünscht.  
**Arbeitsbranch:** `docs/bootstrap-governance-20261122`  
**Review:** [Draft-PR #1](https://github.com/Ullmann27/Imperathen/pull/1)

## Ordner mit tatsächlichem Inhalt

| Pfad | Zweck |
| --- | --- |
| `.github/ISSUE_TEMPLATE/` | Vorlagen für Vorarbeit, Entscheidungen und Befunde |
| `docs/00_governance/` | Status, Quellenprüfung, Entscheidungen, Risiken und Arbeitsregeln |
| `docs/01_product/` | Produktauftrag und Anforderungszuordnung |
| `docs/02_game_design/` | Sechs zusammenhängende Gameplaybereiche |
| `docs/03_engineering/` | Zustands-, Zeit-, Erzähl- und Leistungsplanung |
| `docs/04_art_audio/` | Modulare Assetproduktion, Audio und Referenzregister |
| `docs/05_quality/` | Prüfansatz und konkrete spätere Abnahmeszenarien |
| `docs/06_production/` | Arbeitsplan, Aufgaben und Phasen |
| `docs/07_legal/` | Namensvorprüfung und Herkunfts-/Rechteplan |
| `docs/08_agent_handoff/` | Aktueller Arbeitsauftrag und begrenzte spätere Übergabe |
| `docs/09_sources/` | Herkunftsverzeichnis, Prüfsummen und Bildzuordnung |

Es werden keine leeren Spiel-, Engine- oder Backendordner angelegt. Solche Verzeichnisse entstehen später mit konkretem Inhalt. Die `.gitignore` schützt typische lokale Arbeitsreste; sie ersetzt keine Inhaltsprüfung und entfernt keine bereits veröffentlichten Daten.

## Aufgaben statt bloßer Themenliste

Issues #2–#15 enthalten Ziel, benötigte Dokumente, Abhängigkeiten und Abnahmekriterien. Die [Aufgabenübersicht](BACKLOG.md) ist im Repository lesbar. Sie ist kein GitHub-Projects-Board. Für die gegenwärtige Vorarbeit reichen Issues und der bestehende Draft-PR.

## Technische Einstellungen

Diese Vorarbeit richtet keine Branch-Protection, Rulesets, kostenpflichtigen Prüfungen, automatische Builds oder externen Bot-Abos ein. Der verwendete GitHub-Zugang unterstützt die Datei- und Aufgabenarbeit, stellt für einige dieser Verwaltungsaktionen aber keine geeignete Schreibfunktion bereit. Die Dokumentation gibt deshalb keine technische Erzwingung vor.

Die lesende Prüfung am 22.11.2026 meldete für `main` den Wert `protected: false`; die Repository-Ruleset-Abfrage lieferte eine leere Liste. Das ist der beobachtete Stand dieser Abfragen, keine pauschale Aussage über sämtliche Sicherheitseinstellungen des Kontos.

Ein späteres Regelwerk muss zum tatsächlichen Arbeitsablauf passen. Eine zwingende zweite unabhängige Freigabe ohne zweite verfügbare Person könnte einen Einpersonen-Workflow blockieren. Sinnvoll zu prüfen sind Schutz vor erzwungenen Aktualisierungen, nachvollziehbare PR-Arbeit und gezielte Checks, sobald es echte überprüfbare Software gibt. Es wird derzeit kein kostenpflichtiger Tarifwechsel veranlasst.

## Bestehende Integrationen

Im vorhandenen PR sind Hinweise vorhandener Prüf-Bots sichtbar. Diese Hinweise sind keine Aufforderung, Upgrades abzuschließen oder Reviews kostenpflichtig zu starten. In dieser Vorarbeit werden solche Abos nicht aktiviert. Automatische Aktivitäten bereits bestehender Integrationen können durch deren eigene Einstellungen beeinflusst sein; die Kontorechnung wird durch diese Dokumentation nicht kontrolliert.

## Nachvollziehbarkeit

Ein veröffentlichtes Dokument wird anhand Branch und Commit identifiziert. Vor einem Update wird der vorhandene Kopf geprüft. Der Draft bleibt ein Reviewstand; `main` wird ohne passenden Auftrag nicht zusammengeführt. Eine Änderung der Repository-Sichtbarkeit gehört nach der aktuellen Nutzerentscheidung nicht zu den nächsten Aufgaben.
