# Lokales Setup

## Geltungsbereich

Diese Anleitung gilt für den Standardbranch `main`. Er enthält derzeit nur
Dokumentation, kein ausführbares Spielprojekt. Andere Entwicklungsbranches und
Pull Requests sind kein in dieser Anleitung verifizierter Einstiegspunkt.

## Voraussetzungen

- Git mit HTTPS-Unterstützung: [Download und Installationsanleitungen](https://git-scm.com/downloads).
- Zugriff auf `https://github.com/Ullmann27/Imperathen`.
- Ein Terminal; die Befehle sind mit einer POSIX-Shell unter Linux geprüft.
  Unter Windows eignet sich Git Bash. Windows und macOS wurden im Audit nicht getestet.

Es gibt auf `main` noch keine festgelegte Engine-, SDK- oder Paketmanager-Version,
keine Abhängigkeitsinstallation und keine Vorlage für Umgebungsvariablen.
Für das Lesen der Dokumentation sind keine zusätzlichen Projektpakete oder
Zugangsdaten erforderlich.

## Repository klonen und prüfen

In einem Verzeichnis beginnen, in dem noch kein Ordner `Imperathen` existiert:

```sh
git --version
git clone --branch main --single-branch https://github.com/Ullmann27/Imperathen.git
cd Imperathen
git ls-files
```

`git --version` muss eine Versionsnummer ausgeben. Nach dem Klonen zeigt
`git ls-files` die versionierten Dateien, darunter `README.md` und nach Aufnahme
dieser Dokumentation auch die Dateien unter `docs/`.

**Hier endet das derzeit mögliche Setup.** Es gibt keinen unterstützten Befehl
für Installation, Spielstart, Build oder Tests. Ein erfolgreicher Clone ist kein
erfolgreicher Spiel-Build. Auch ein leeres Fehlerprotokoll würde keinen Testlauf
ersetzen.

## Häufige Probleme

- **`git: command not found`:** Git über den obigen Link installieren und das
  Terminal neu öffnen. Danach erneut mit `git --version` beginnen.
- **Zielverzeichnis existiert bereits:** Einen anderen übergeordneten Ordner
  wählen oder den vorhandenen Clone verwenden. Keine lokalen Dateien löschen,
  nur um den Clone-Befehl erneut auszuführen.
- **HTTPS-/Netzwerkfehler:** Erreichbarkeit von GitHub sowie lokale Proxy- und
  Zertifikatseinstellungen prüfen. Die TLS-Zertifikatsprüfung nicht deaktivieren.
- **Keine Projektdatei oder kein Build-/Testbefehl gefunden:** Das ist beim
  aktuellen `main` der erwartete Stand und kein fehlendes lokal installiertes
  Paket. Nicht auf Verdacht eine Engine installieren oder Befehle anderer
  Entwicklungsbranches übernehmen.

## Was vor einem ausführbaren Setup ergänzt werden muss

Sobald ein ausführbarer Projektstand als unterstützter Einstieg festgelegt ist,
müssen Quellcode und Projektdateien sowie die dazugehörigen Anweisungen zusammen
bereitgestellt werden:

1. Unterstützte Betriebssysteme und exakte Engine-/SDK-/Toolversionen.
2. Abhängigkeiten und gegebenenfalls benötigte Assets, Dienste oder
   Umgebungsvariablen, ohne geheime Werte einzuchecken.
3. Konkrete Installations-, Start-, Build- und Testbefehle mit Arbeitsverzeichnis
   und erwarteten Ergebnissen.
4. Ein erneuter Durchlauf dieser Befehle in einem frischen Clone ohne vorherige
   Projektinstallation, einschließlich der tatsächlichen Build- oder Testergebnisse.

Bis dahin ist ein Build-/Testlauf blockiert. Das
[Auditprotokoll](ONBOARDING_AUDIT.md) hält die überprüften Schritte und Lücken fest.
