# Prüfung des ersten Entwicklungsstands

**22. November 2026 · IMPERATHEN 0.1 · eigener Entwicklungsbranch auf Vorproduktion a3e036b**

## Ergebnis

Die erste Einstiegsvorschau, ihr Speicher-/Aktionskern und die lokale Agent-Pipeline sind implementiert. 18 JavaScript-Kerntests und 14 Python-Pipelinetests bestanden. Der von Unreal unabhängige C++-Regelkern wurde tatsächlich mit einem C++-Compiler gebaut und sein Test ausgeführt. Frontend- und Bundle-JavaScript bestanden den Syntaxcheck. Diese Ergebnisse enthalten keinen Browser-Bediennachweis und keinen Unreal-Build.

## Tatsächliche Umgebung

| Bereich | Beobachtung |
| --- | --- |
| Node | v24.22.3 |
| Python | 3.12.14 |
| C++ | Debian GCC 14.2.0, C++17, Wall/Wextra/Werror/pedantic |
| UnrealEditor / UnrealBuildTool | Nicht installiert |
| Chromium im Kommando-Executor | Start scheitert an gesperrtem AF_UNIX-Socket für process_singleton |
| Bereitgestellter Browser | Lokale Datei-URL durch Browserrichtlinie ausdrücklich abgewiesen; kein Ausweichweg verwendet |

## Ausgeführte Prüfungen

| Prüfung | Ergebnis | Aussage |
| --- | --- | --- |
| node --test tests/core.test.mjs | 18 bestanden | Endliche Handlungskette, Ressourcen, Neustart, Save-/Settings- und Fehlerpfade |
| Python unittest pipeline_test.py | 14 bestanden | Dateibesitz, Abhängigkeiten, sichere lokale Zustandsänderung und Prüfbelege |
| node --check preview/app.mjs | Bestanden | JavaScript-Syntax; keine Aussage über Layout oder Browserinteraktion |
| node --check auf eingebettetem Bundle-Skript | Bestanden | Einzeldatei enthält syntaktisch gültigen Code ohne Modulimporte |
| tools/verify_unreal.py | Bestanden | Projektstruktur/Includes plus tatsächlich gebauter unabhängiger C++-Regeltest |
| Agent-Pipeline check --require-ready | Bestanden | Alle drei Rollen haben mit aktuellen Dateinachweisen übergeben |
| Agent-Pipeline run | Bestanden | Gemeinsamer Lauf der oben verfügbaren Prüfungen |
| Frontend-Dateien | 50 eindeutige DOM-IDs, lokale Referenzen vorhanden, SVGs XML-valide | Struktur, keine visuelle Abnahme |
| Einzeldateibuild | 158.738 Bytes, keine externen Skript-, Stil- oder Bildabhängigkeiten | Offline gebündeltes Vorschauartefakt; Speicherung hängt vom verwendeten Browser ab |

## Geprüfte Risiken des Browserkerns

1. Kein vorgetäuschter Spielstand und Ton startet stumm.
2. Holzverlauf 0 → 6 → 2 → 0, endlicher Vorrat und gespeicherte Handlungsschritte.
3. Wiederholung einer Aktion ändert weder Vorräte noch Vertrauen, Chronik oder Fortschritt.
4. Menüwechsel und abgebrochenes neues Leben verändern den Spielstand nicht.
5. Bestätigter Neustart sichert den vorigen gültigen Stand.
6. Fehler beim Backup-/Hauptschreibvorgang übernehmen keine Aktion in die aktive Welt.
7. Misslungenes erstes Speichern erzeugt keine scheinbar sichere laufende Partie.
8. Korrupte Primärdaten bleiben bis zur ausdrücklich ausgelösten Wiederherstellung erhalten.
9. Fehlende Möglichkeit zur Sicherung des Originals bricht die Wiederherstellung ab.
10. Neuere/fremde Primär- und Backupformate werden nicht stillschweigend ersetzt.
11. Beschädigung, inkonsistente Ressourcen und ungültige Backups verhindern Fortsetzen.
12. Beobachtete Änderungen durch ein anderes Store-Fenster erzeugen einen Konflikt.
13. Einstellungen überleben einen Neustart; ungültige Werte und neue Formate bleiben kontrolliert.
14. Nicht verfügbarer Speicher liefert sichtbare Fehler.
15. Namen werden vor dem Speichern normalisiert und validiert.
16. Zurückgegebene Kopien und fehlerhafte UI-Abonnenten können den gespeicherten Zustand nicht verändern.

localStorage ist keine vollständige Transaktion über mehrere Browserfenster. Der Prototyp ist auf eine aktive Spielinstanz ausgerichtet. Der Schadenserkennungswert ist kein kryptografischer Manipulationsschutz.

## Gegenprüfung der nativen Vorbereitung

Ein unabhängiger Agent identifizierte und der Integrator korrigierte: Schutz neuerer Formate bei Recovery, Erhalt eines bereits archivierten Originals, Prüfung veralteter aktiver Slotdaten, Entfernen alter Fehlermeldungen nach einem neuen Versuch, Rücksetzen des Eingabemodus in EndPlay sowie verzögerten Tastaturfokus nach Einbindung des Widgets. Zusätzlich werden beschädigte oder inkompatible Backups nicht regulär überschrieben.

Die nativen Regeln sind separat kompiliert. Slate-Code, SaveGame-Plattformverhalten, Hintergrundgrafik und Engine-Initialisierung wurden nur anhand des Quellcodes und offizieller Epic-API-Dokumentation geprüft. Das ist keine erfolgreiche Unreal-Kompilierung.

## Ausstehende Abnahme

- `npm run check:browser` in einer Umgebung mit zulässigem Browserstart ausführen: Intro automatisch/übersprungen, mehrfache Menüzyklen, tatsächliches Speichern/Neuladen und kleine Anzeige mit 130%-Text.
- Das Menüpanorama wurde separat mit Inkscape als SVG gerendert und visuell geprüft; eine global abdunkelnde Filterebene wurde entfernt. Das prüft dieses einzelne Motiv, nicht das Browserlayout. Hintergrund-/Dorf-SVGs sind Original-Vektorgrafik; kein behaupteter Screenshot einer laufenden 3D-Welt.
- Unreal-Version und Rechner ermitteln; Editor/Game-Ziele kompilieren, Entry-Map-Verhalten und Cooking prüfen.
- Native Maus-, Tastatur-/Controllerbedienung und Eingabewechsel im Viewport prüfen.
- Browser- und native Saveformate langfristig konsolidieren; keine jetzige Kompatibilität behaupten.
- Erst danach frei begehbare Figur und die tatsächliche 3D-Dorfbaustelle anschließen.

## Was die Agent-Pipeline bedeutet

Die drei tatsächlichen Agents bearbeiteten Frontend, Spielfundament und Pipeline. Alle lieferten über Claim → Prüfkommandos → Handoff. Die lokale Pipeline prüft Koordinationsdaten und Belege; sie startet keine Modelle, keine kostenpflichtigen Dienste und keinen Hintergrundagenten. GitHub-CI wird durch die eingecheckte Workflow-Datei beschrieben; ein Remote-CI-Ergebnis muss separat vom jeweiligen echten Run abgelesen werden.
