# Phasen und konkrete Übergänge

**Aktualisierung 22.11.2026:** Der begrenzte Entwicklungsstart ist jetzt beauftragt; siehe [aktueller Auftrag](../00_governance/DEVELOPMENT_START.md). Frühere Phasenbeschränkungen unten dokumentieren die Vorproduktion. Große Gameplay-, Engine- und Leistungsnachweise bleiben eigene Aufgaben.

**Stand: 22.11.2026.** Ein Übergang ist eine inhaltliche Abnahme, keine pauschale Aufforderung, für jeden Vorbereitungsschritt neue Erlaubnis einzuholen.

## P0 – Vorarbeit, aktueller Auftrag

| Lieferung | Status |
| --- | --- |
| Repositoryzugang und vorhandener Draft-PR | Vorhanden und geprüft |
| Öffentliches Repository | Ausdrückliche Nutzerentscheidung; bleibt so |
| Ursprungsmappe inventarisieren und Widersprüche prüfen | Audit und Herkunftsregister erstellt |
| Produktziel und Anforderungszuordnung | Dokumentiert |
| Gameplay, Datenverträge und Abnahmeplan | Entwürfe erstellt und fachlich abgeglichen |
| Grafik-/Audio-/Rechteplanung | Dokumentiert; keine Produktionsfreigabe aller Assets behauptet |
| GitHub-Aufgaben mit Abhängigkeiten | Issues #2–#15 angelegt |
| Agentenübergabe | Für Vorarbeit und späteren begrenzten Start vorbereitet |
| Vertiefte Namensprüfung | Webvorprüfung dokumentiert; direkte Registerergebnisse und Bewertung offen |

P0 liefert eine nutzbare Entscheidungs- und Arbeitsbasis. Sie behauptet nicht, dass sämtliche langfristigen Produktentscheidungen bereits getroffen oder alle Risiken beseitigt sind. Fehlende Kontoeinstellungen blockieren das Schreiben fachlicher Dokumentation nicht.

## P1 – Erster technischer Funktionsnachweis, später

Voraussetzungen: ein ausdrücklicher Auftrag zum Entwicklungsstart, ein begrenzter erster Spielabschnitt, verfügbare und geprüfte Werkzeuge sowie die für diesen Abschnitt erforderlichen Entscheidungen. Der erste Nachweis muss Zustandsänderung, Moduswechsel und Speichern zusammen zeigen. Kein kompletter Reichssimulator als „P0“ verstecken.

Ein noch vorläufiger interner Arbeitstitel macht einen Funktionsnachweis nicht technisch unmöglich. Vor endgültiger Namensfestlegung und entsprechenden Veröffentlichungen bleibt die separate Namens-/Rechteentscheidung nötig. Eine Privatstellung ist keine Voraussetzung.

## P2 – Ein kleiner spielbarer Abschnitt

Eine überschaubare Dorf- und Konfliktsequenz mit realer Bedienung, sinnvollen Folgen und reproduzierbarem Save/Load. Mindestens zwei unterscheidbare Fortsetzungen aus tatsächlich verschiedenen Entscheidungen. Grafik zunächst ausreichend für Lesbarkeit und Prüfung, anschließend gezielt verbessern.

## P3 – Erweiterte verbundene Simulation

Weitere Siedlungen, Wirtschaft, taktische Größen, politische Rollen und Erzählvorrat auf Basis gemessener Leistung erweitern. Jede Vergrößerung nennt ihr Ziel, ihren Messaufbau und die beobachteten Grenzen. Strategische Truppenstärke darf nicht als Zahl gleichzeitig detailliert simulierten Kämpfer ausgegeben werden.

## P4 – Produktion und Veröffentlichung

Nach Spielbarkeitsnachweisen die abschließenden Plattform-, Inhalts-, Budget- und Veröffentlichungsentscheidungen für die Vollproduktion treffen. Erforderliche Rechte- und Kostenentscheidungen für frühere Arbeitsschritte müssen bereits vor der jeweiligen Assetnutzung oder Beauftragung vorliegen. Ein Datum wird nicht aus der Geschwindigkeit von Dokumenterstellung abgeleitet. Konsolen benötigen eigene tatsächliche Voraussetzungen; eine PC-Demo beweist noch keinen Konsolenport.

## Aktuelle Grenzen

Keine Spielprogrammierung, Engine-Initialisierung, Renderaufträge, kostenpflichtigen Dienste, Markenanmeldung oder Zusammenführung nach `main` innerhalb dieses Vorbereitungsauftrags. Innerhalb von P0 kann der Agent die beauftragte Arbeit eigenständig vervollständigen.
