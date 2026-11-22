# Prüfung der Vorproduktionsunterlagen

**Prüfdatum: 22.11.2026 · Gegenstand: Dokumentationsstand dieses Vorbereitungsbranches.**

## Tatsächlich durchgeführt

1. Die bereitgestellte ZIP vollständig entpackt und mit der ZIP-Integritätsprüfung geprüft: 50 Dateieinträge, kein CRC-Fehler. Prüfsummen für Archiv und sämtliche Quelldateien erfasst.
2. Konzept, Arbeitsaufträge, Architektur, Demonstrationsschema/-validator und historische Testunterlagen statisch verglichen. Der [Quellenaudit](../00_governance/SOURCE_AUDIT.md) nennt konkrete Befunde und Herkunft.
3. Sechs Gameplaydokumente gegen die sechs Architektur-/Qualitätsdokumente unabhängig gegengeprüft. Gefundene Systemübergänge vor Übernahme präzisiert.
4. Den aktuellen Auftrag gegen README, Agentenanweisungen, Arbeitsregeln, Produktionsplan und Übergabe abgeglichen: öffentliche Sichtbarkeit bleibt; keine Spielprogrammierung gestartet; keine Privat-Voraussetzung.
5. Relative Markdown-Dateiverweise im gesamten vorbereiteten Verzeichnis geprüft. Keine fehlenden lokalen Dateiziele im geprüften Stand. Das prüft keine Erreichbarkeit aller externen Internetseiten und keine inhaltliche Vollständigkeit.
6. Wesentliche externe Quellen der Namensvorprüfung geöffnet beziehungsweise anhand amtlicher Auskünfte geprüft. Grenzen direkter Registerabfragen ausdrücklich erhalten.
7. GitHub-Ausgangsstand, vorhandenen Draft-PR und die angelegten Issues über den verbundenen Zugang geprüft. Die tatsächliche Dateiübernahme wird zusätzlich durch den Commit und dessen Dateibaum belegt.

## Korrigierte konkrete Probleme

| Befund | Behandlung |
| --- | --- |
| Früherer Prompt verlangt sofortige Implementierung | Neuer aktueller Einstieg mit klarer Phasengrenze |
| Ein Begriff P0 bündelt widersprüchliche Umfänge | Vorproduktion, technischer Nachweis und Spielabschnitt getrennt |
| Einzelne KI-Buchungen können zusammen den Vorrat überschreiten | Transaktion der gewählten Folge; alternative Zweige getrennt |
| Karriereabschluss könnte durch neue Episoden aufgehoben werden | Persistenter Endzustand; unvereinbare Reserve verwerfen |
| Mehrtägiger Bau wird mit atomarer Buchung verwechselt | Langlaufender Prozess mit bestätigten Teilschritten |
| Pause/Inaktivität verfälscht geschätzten Storybedarf | Aktive Zeit und tatsächlichen Inhaltsverbrauch getrennt |
| Fremdes Eigentum wird trotz Nutzungserlaubnis pauschal abgelehnt | Bau-/Nutzungsrecht berücksichtigen |
| Fernkamera könnte Reise und Wissen umgehen | Aufenthaltsort, Reise, Aufklärung und Befugnisse bleiben maßgeblich |
| Alterssprung betrifft scheinbar nur den Helden | Gemeinsame Weltzeit und betroffene Prozesse fortschreiben |
| Zivile Vollkampagnen wurden unbemerkt zur Pflicht | Als Erweiterungsvorschlag eingeordnet |
| Rekrutierung und Stadt-Detailwechsel fehlen als zentrale Prüffälle | Abnahmematrix auf 28 spezifizierte Fälle ergänzt |
| Rechte-/Kostenentscheidung in P4 zu spät verortet | Frühe Schritte benötigen ihre Entscheidungen vor Beauftragung; P4 betrifft Vollproduktion |

## Grenzen dieser Prüfung

Es wurden keine Spieltests, Engine-Builds, Blender-Ausführungen oder Leistungsbenchmarks durchgeführt. Die 28 neuen Abnahmeszenarien sind ein geplanter Nachweisumfang. Die acht berichteten Demotests und 92 geplanten Fälle der Quellmappe bleiben historische beziehungsweise noch nicht durchgeführte Quellenangaben.

Die 13 Originalbilder wurden katalogisiert; es wurden keine neuen Bilder oder Modelle erzeugt. Eine Namensvorprüfung ist keine abschließende Markenfreigabe. Die dokumentierten GitHub-Arbeitsregeln sind keine technisch eingerichtete Branch-Sperre.

Die Prüfung verbessert Konsistenz und Nachvollziehbarkeit. Sie beweist keine Vollständigkeit eines späteren Spiels. Weitere fachliche Entscheidungen besitzen eigene [GitHub-Aufgaben](../06_production/BACKLOG.md).
