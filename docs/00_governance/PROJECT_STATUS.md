# Projektstatus

**22.11.2026 · Phase: erster Entwicklungsstand · Arbeitstitel IMPERATHEN**

Der neuere Nutzerauftrag aktiviert den begrenzten Spielaufbau mit drei Agents. [Entwicklungsstart](DEVELOPMENT_START.md) dokumentiert Auftrag und beobachteten Ausgangsstand. Der frühere Vorproduktionsstatus unten bleibt zur Nachvollziehbarkeit erhalten und ist für diese Lieferung überholt.

## Aktuelle Implementierung

- Deutschsprachiger dreiteiliger Vorspann, Hauptmenü und eigenständige römische SVG-Szene.
- Neues Leben, Fortsetzen, ein Browser-Spielstand mit Sicherung, Einstellungen und drei endliche Dorfhandlungen.
- Sichtbarer Unterstand nach erfolgreicher Bauaktion, Chronik und persistente Beziehung zu Marcus im Browserkern.
- Lokale Drei-Agent-Pipeline mit Dateibesitz, Claims, Pflichtprüfungen, Abhängigkeiten und nachvollziehbarer Übergabe.
- Native Unreal-Projektbasis in game/Imperathen; unabhängig kompilierter C++-Regelkern.
- Einzeln lieferbare HTML-Vorschau, reproduzierbar mit `npm run build:preview`.

## Nachweise und Grenzen

[Prüfbericht](../05_quality/FOUNDATION_REVIEW.md): 18 JavaScript-Kerntests, 14 Pipeline-Regressionstests und der native C++-Regeltest bestanden. Frontend und eingebettetes Bundle sind syntaktisch geprüft; Dateiverweise und SVG-Struktur sind geprüft. Alle drei tatsächlichen Agents haben mit aktuellen Nachweisen übergeben.

Die visuelle Browserprüfung war in dieser Umgebung blockiert: Chromium konnte keine erforderliche Unix-Socket-Funktion nutzen, und der bereitgestellte Browser lehnte die lokale Datei-URL ausdrücklich ab. Es gibt daher keinen behaupteten Screenshot eines laufenden Spiels oder bestandenen Browser-Bedienlauf. Die Unreal-Engine fehlt; ihr Build, die native UI und das Cooken sind nicht ausgeführt.

Die 3D-Welt, freies Begehen, Kampf, große Städtebau-/Wirtschaftssimulation und vollständige Karriere sind weiterhin offen. Der Name bleibt vorläufig. Die vorhandene Repository-Sichtbarkeit wurde nicht geändert.

## Zusammenarbeit

Koordination: [Issue #16](https://github.com/Ullmann27/Imperathen/issues/16). Eigener Branch: `feat/entry-foundation-three-agents-20261122`, aufgebaut auf Dokumentations-PR #1. Die Übergabe nennt den tatsächlichen Liefercommit; main und der vorhandene Dokumentationsbranch werden nicht überschrieben.

Die Pipeline startet keine Modelle und arbeitet nicht unbeaufsichtigt weiter, sobald eine Sitzung endet. Die Aufgaben- und Übergabedokumente ermöglichen dem nächsten Bearbeiter den geordneten Anschluss. Zusätzliche bezahlte Dienste/Modell-APIs wurden nicht beauftragt. Ein persönliches ChatGPT-Restkontingent kann nicht verlässlich eingesehen werden.

---

# Historischer Vorproduktionsstand

**Stand: 22.11.2026 · Phase: Vorproduktion · Arbeitstitel: IMPERATHEN**

## Verbindlicher aktueller Rahmen

Der Nutzer hat die autonome Vorarbeit beauftragt und anschließend ausdrücklich bestimmt, dass das Repository öffentlich bleiben soll. Eine Privatisierung ist keine Voraussetzung. Der frühere Planpunkt „zuerst privat stellen“ ist damit aufgehoben. Der Nutzer entscheidet selbst über einen späteren Sichtbarkeitswechsel.

Der Auftrag zur Vorarbeit ist keine Freigabe zur eigentlichen Spielprogrammierung. Diese Sammlung beschreibt Anforderungen, Abhängigkeiten, Entscheidungen und spätere Prüfungen. Es gibt hier keinen fertigen Spielkern und keinen ausgelieferten Build.

## Nachgewiesener Ausgangsstand

- Repository: `Ullmann27/Imperathen`, über den verbundenen GitHub-Zugang les- und beschreibbar.
- Ausgangsstand von `main`: `e9e1bb16da02de9217e422fa013fdafdb5b80a80` mit Projekt-README.
- Vorhandener Arbeitsbranch: `docs/bootstrap-governance-20261122`.
- Bestehender Draft-PR: [#1](https://github.com/Ullmann27/Imperathen/pull/1).
- Ausgangsstand dieses Arbeitsblocks: `bc979e00e89c4a0a690a2f52890dbd7ff4df9e1b`.
- Die bereitgestellte IRON-BANNERS-ZIP wurde vollständig entpackt und auf ZIP-Integrität geprüft: 50 Dateieinträge, kein CRC-Fehler. Der [Quellenaudit](SOURCE_AUDIT.md) beschreibt den Inhalt und konkrete Widersprüche.

## In dieser Sammlung vorbereitet

Anforderungsregister, Fachkonzepte, Architekturverträge in Prosa, Asset- und Rechteplanung, Qualitäts- und Abnahmekriterien, Aufgabenstruktur, Entscheidungsprotokoll und aktuelle Agentenübergabe. Die [Aufgabenübersicht](../06_production/BACKLOG.md) nennt den tatsächlichen GitHub-Stand und trennt vorbereitete Unterlagen von noch offenen Entscheidungen.

## Aktuelle Dokumentenlieferung

42 Dateien, darunter 39 Markdown-Dokumente und zwei Quellen-/Referenzregister, mit 37 Anforderungen und 28 geplanten Akzeptanzfällen. Die erste Inhaltslieferung liegt in Commit `cb97c920f1cd6f3e1e5eee8ff2de080e32635f52`; alle 42 Dateien wurden nach dem Speichern anhand ihrer Git-Blob-Prüfsummen abgeglichen, ohne Abweichung. 62 relative Dateiverweise sind auflösbar. Vier Vorbereitungsissues wurden mit Liefernachweis geschlossen; zehn bleiben für weitere Entscheidungen und Vertiefung offen.

## Noch offen

- Abschließende Namens- und Ähnlichkeitsprüfung; keine Markenfreigabe oder Anmeldung behauptet.
- Engine-Version, Zielrechner, verbindliches Leistungsbudget und endgültiger Umfang des ersten spielbaren Abschnitts.
- Fachentscheidungen zu Zeitmodell, Alterssprung, Karrieregrenzen, Storyreserve und Reichweiten der Simulation.
- Tatsächliche Engine-, Blender-, Build-, Spiel- und Leistungstests: nicht begonnen.
- Technische Branch-Regeln, ein echtes GitHub-Projects-Board und Build-Automatisierung: nicht eingerichtet. Dokumentierte Regeln sind nicht mit technisch erzwungenen Einstellungen gleichzusetzen.

## Belegregeln

Eine geplante Prüfung bleibt geplant, bis sie ausgeführt wurde. Die acht historischen Demonstrationstests der Quellmappe sind kein heutiger Testlauf und kein Nachweis der späteren Spielarchitektur. Konzeptgrafiken sind Stilreferenzen. Die Repository-Sichtbarkeit sagt nichts über Rechte an einzelnen Fremdinhalten aus.
