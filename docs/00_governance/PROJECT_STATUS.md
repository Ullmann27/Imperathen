# Projektstatus

**Aktuelle Charakterfortsetzung, 22.11.2026.** Der Arbeitsbranch `feature/hero-realism-20261122` baut auf `integration/realistic-android-23` auf. Ausführbare Änderungen, Originalmodelle, Renderings und aktuelle Prüfungen stehen im [Charakter-Lieferbericht](../14_character_realism/DELIVERY.md). Die vom Nutzer mit einem Spielbild konkretisierte PC-/Konsolenqualität bleibt der visuelle Maßstab; weder ein Konzeptbild noch ein bestandener Dateivertrag schließen die Qualitätsanforderung aus [Issue #33](https://github.com/Ullmann27/Imperathen/issues/33).

**Aktueller Integrationsstand.** Die zusammengeführte Android- und Desktop-Linie, Abnahme und offene Punkte stehen im [Lieferbericht](../12_integration/DELIVERY.md). Die folgenden Angaben dokumentieren den vorausgehenden Arbeitsstand.

**Stand: 22.11.2026 · Phase: erster ausführbarer Funktionsprototyp · Arbeitstitel: IMPERATHEN**

## Neuer Entwicklungsauftrag

Der Nutzer hat nach der Dokumentenlieferung ausdrücklich den weiteren Spielaufbau mit drei Agenten beauftragt. Die frühere Programmierpause ist für diesen Block aufgehoben. Aktueller eigener Branch: `feature/prototype-foundation-20261122`, Ausgangscommit `a3e036ba24b99416b016337d81ab2b4067350fa3`, Koordination [#17](https://github.com/Ullmann27/Imperathen/issues/17).

Aktuelle Lieferung: [`prototype/`](../../prototype/README.md), eine tatsächlich gebaute ARM64-Test-APK, erfolgreicher separater Android-x86_64-Emulatorlauf, eigene Blender-Assetquelle und Headless-Prüfungen. Für den tatsächlichen Teststatus und Nachweisgrenzen gilt [VALIDATION.md](../10_development/VALIDATION.md), für die Zusammenführung der parallelen Arbeitslinien [NEXT_AGENT.md](../10_development/NEXT_AGENT.md). Die folgenden Zahlen zur Dokumentenlieferung bleiben ein historischer Ausgangsstand und beschreiben nicht den heutigen Codeumfang.

Der Nutzer hat ausdrücklich festgelegt: zuerst Android. PC ist eine spätere Erweiterung. Der Prototyp besitzt Touchsteuerung, skalierbare Darstellung, Android-Zurück-Verhalten, Hintergrundspeicherung und einen automatisierten APK-Export. Der konkrete Liefer- und Laufzeitstand steht in [ANDROID_INSTALL.md](../10_development/ANDROID_INSTALL.md). Die langfristige Engineentscheidung und der Nachweis auf physischen ARM64-Geräten bleiben offen.

## Verbindlicher aktueller Rahmen

Der Nutzer hat die autonome Vorarbeit beauftragt und anschließend ausdrücklich bestimmt, dass das Repository öffentlich bleiben soll. Eine Privatisierung ist keine Voraussetzung. Der frühere Planpunkt „zuerst privat stellen“ ist damit aufgehoben. Der Nutzer entscheidet selbst über einen späteren Sichtbarkeitswechsel.

Die erste Dokumentenlieferung war noch keine Programmierfreigabe. Der nachfolgende ausdrückliche Entwicklungsauftrag erweitert diese Phase; ausführbarer Prototypcode wird getrennt von der langfristigen Produktvision geliefert. Ein veröffentlichter Store-Build besteht weiterhin nicht.

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
- Langfristige Produktionsengine, konkrete Android-Zielgeräte und verbindliches Leistungsbudget. Der vorhandene begrenzte Prototyp verwendet nachgewiesen Godot 4.7.2.
- Fachentscheidungen zu Zeitmodell, Alterssprung, Karrieregrenzen, Storyreserve und Reichweiten der Simulation.
- Tatsächliche Engine-/Blender-Ausführung und Funktionsprüfungen: siehe aktuellen Entwicklungsnachweis. Grafikleistung, Geräteabnahme und Store-Build sind noch offen.
- Technische Branch-Regeln und ein echtes GitHub-Projects-Board sind weiterhin nicht eingerichtet. Eine Android-Baupipeline ist inzwischen vorhanden; sie ersetzt keine Branch-Regeln oder Storefreigabe.

## Belegregeln

Eine geplante Prüfung bleibt geplant, bis sie ausgeführt wurde. Die acht historischen Demonstrationstests der Quellmappe sind kein heutiger Testlauf und kein Nachweis der späteren Spielarchitektur. Konzeptgrafiken sind Stilreferenzen. Die Repository-Sichtbarkeit sagt nichts über Rechte an einzelnen Fremdinhalten aus.
