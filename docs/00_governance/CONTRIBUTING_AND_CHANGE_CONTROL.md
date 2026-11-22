# IMPERATHEN – Arbeits- und Änderungsregeln

## Branch-Modell
- `main`: stabile, geprüfte Basis. Keine Agenten-Direktwrites.
- Dokumentation: `docs/<thema>`; spätere Umsetzung: `feature/<issue>-<thema>`, `fix/<issue>-<thema>`, Assets: `assets/<issue>-<thema>`.
- Jede Änderung arbeitet innerhalb eines abgegrenzten Fachbereichs.

## Pull Requests
Jeder PR beschreibt (1) Ziel und Zuordnung zu Issue/Entscheidung, (2) konkrete Dateien, (3) Auswirkungen auf vorhandene Verträge, (4) überprüfbare Nachweise, (5) Risiken, (6) Rückbauplan. Keine automatischen Merges ohne explizite Projektfreigabe.

## Begriffe für Status
- **Geplant:** nur Entwurf.
- **Implementiert:** Dateien/Code vorhanden.
- **Integriert:** mit abhängigen Systemen verbunden.
- **Verifiziert:** konkrete Tests mit Ergebnis bestanden.
- **Ausgeliefert:** aus einem nachweislich reproduzierbaren Build bereitgestellt.

## Eine einzige autoritative Wahrheit
Eine Quelle pro Weltzustand, Zeit, Inventar, Identität, Beziehung, Ressource und Armee. KI darf nur validierte Veränderungsbefehle an diese Systeme geben. Entwürfe sind keine freigegebenen Engine-Entscheidungen.

## Asset- und Geheimnisschutz
Keine privaten API-Schlüssel, Passwörter oder Kundendaten in Commits. Vor Import externer Bilder/Modelle Rechte, Herkunft, Lizenz und erlaubten Einsatzzweck dokumentieren. Große binäre Game-Assets erst nach Git-LFS-/Perforce-Entscheidung versionieren.

## Qualitätstore
- **G0:** Name und Rechtsgrundlagen geklärt.
- **G1:** Produktionsarchitektur, Abnahmekriterien, Rechte, Speicher-/Versionsstrategie und Repository-Zugriff geklärt.
- **G2:** Erstes spielbares End-to-End-Szenario nach ausdrücklicher Freigabe, einschließlich Save/Load-Test.
- **G3:** Größere integrierte Welt mit gemessener Performance.

## Agenten
KI-Agenten sollen Risiken, Widersprüche und fehlende Abhängigkeiten eigenständig aufdecken. Sie dürfen NICHT ohne Freigabe veröffentlichen, Kosten auslösen, auf `main` mergen oder sensible Daten hochladen.

Dieses Dokument ist eine vorbereitende Policy; technische Enforcement-Einstellungen müssen nach der Privatisierung eigens eingerichtet und geprüft werden.
