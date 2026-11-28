# Onboarding-Audit vom 28. November 2026

## Ausgangspunkt und Methode

Geprüft wurde `main` am Commit
`e9e1bb16da02de9217e422fa013fdafdb5b80a80` (`Initial commit`).
Die damalige README bestand nur aus Überschrift und Projektbeschreibung.
`git ls-tree -r --name-only origin/main` zeigte ausschließlich `README.md`.

Die Prüfung erfolgte unter Linux mit Git 2.43.0 und einer POSIX-Shell in einem
neu angelegten temporären Verzeichnis. Es wurden keine lokalen Projektdateien,
installierten Projektabhängigkeiten oder Zugangsdaten für das Spiel übernommen.
Das war ein frischer Clone auf einem vorhandenen Linux-System, keine neu
installierte Maschine; die Installation von Git und andere Betriebssysteme
wurden nicht getestet.

## Schritte und Ergebnisse

Die ursprüngliche README enthielt keine ausführbaren Setup-Schritte. Die
folgenden Clone- und Inventarprüfungen waren daher Untersuchungsschritte, keine
damals dokumentierten Anweisungen:

1. `git --version` — erfolgreich: `git version 2.43.0`.
2. `git clone --branch main --single-branch https://github.com/Ullmann27/Imperathen.git`
   — erfolgreich in einem leeren übergeordneten Verzeichnis.
3. `cd Imperathen` — erfolgreich.
4. `cat README.md` — erfolgreich; nur Projektbeschreibung, keine Voraussetzungen
   und keine Installations-, Start-, Build- oder Testanleitung.
5. `git ls-files` — erfolgreich; Ausgabe exakt `README.md`. Damit fehlten auch
   weitere Setup-Dokumente, Quellcode, Projekt-/Abhängigkeitsdateien, Skripte,
   Tests und CI-Konfiguration auf diesem Stand von `main`.
6. `git status --short` — erfolgreich, leere Ausgabe; der Clone war unverändert.
7. Installation, Spielstart, Build und Tests — **blockiert, nicht ausgeführt**:
   Weder entsprechende Anweisungen noch ausführbare Projektdateien waren vorhanden.

Kein dokumentierter Befehl schlug fehl, weil es keine dokumentierten Befehle gab.
Es wurden keine veralteten Versionsangaben gefunden; Versionsangaben fehlten
vollständig. Es wurde kein Build- oder Testerfolg behauptet.

## Gefundene Lücken und Änderungen

| Lücke | Änderung / verbleibender Status |
| --- | --- |
| Projektbeschreibung unterscheidet nicht zwischen Ziel und spielbarem Stand | README kennzeichnet das Projektziel und den nicht ausführbaren Stand von `main`. |
| Voraussetzungen, Clone-Adresse und Arbeitsverzeichnis fehlen | README und Setup-Anleitung nennen Git, Netzwerkzugriff und die Clone-Schritte. |
| Keine separate Setup-Dokumentation oder Fehlerbehebung | `SETUP.md` ergänzt Grenzen und Hilfen für typische Clone-Probleme; diese Fehler wurden nicht künstlich ausgelöst. |
| Kein dokumentierter unterstützter Einstieg in die vorhandenen Entwicklungsbranches | Anleitung begrenzt sich ausdrücklich auf `main`; kein ungeprüfter Branch wird empfohlen. |
| Engine-/SDK-Versionen, Abhängigkeiten und Konfiguration fehlen | Bleibt offen, bis ein unterstützter ausführbarer Projektstand feststeht; keine Versionen erfunden. |
| Quellcode, Projektdateien, Build-/Testskripte und Tests fehlen auf `main` | Weiterhin blockiert; deren Einführung ist keine kleine Dokumentations- oder Skriptreparatur. |

## Verifikation der Dokumentationsänderungen

Die Befehle aus README und Setup-Anleitung wurden zusätzlich an einem frischen
lokalen Clone des Dokumentationscommits geprüft. Die HTTPS-Clone-Adresse wurde
separat mit dem oben protokollierten Clone von GitHub geprüft. Das verifiziert
den derzeit möglichen Dokumentationseinstieg, nicht einen Spielstart, Build oder
Testlauf.
