# IMPERATHEN – Unity-AI-CLI: verifizierte Brücke für neue Game-Assets (27.11.2026)

## Verifizierte Implementierung (keine Render-Abnahme)

- Bestehendes Spiel: Godot/Android. Dieses Experiment ist **kein** Unity-Enginewechsel und berührt keine Game-Assets, Saves oder den Hauptbranch.
- Unity-Konto und bestehendes Cloud-Projekt **Imperathen** sind durch Nutzerscreenshots im Unity-Dashboard sichtbar. Diese Ansichten beweisen weder Unity AI Credits noch ein online nutzbares CI-Servicekonto.
- Die offizielle Unity CLI **1.1.0** wurde auf GitHub Actions erfolgreich installiert und ihre Ausgabe in sanitisierten CI-Artefakten dokumentiert.
- Unity-Servicekonto-Credentials sind als GitHub-Actions-Secrets referenziert; der lokale Unity-CLI-`auth status` hat mit beiden Variablen Exitcode 0 gemeldet. Die tatsächlichen `unity cloud projects`- und `unity cloud orgs`-Abfragen sind dagegen fehlgeschlagen. Die sichere Fehlerklassifikation meldet `AUTHENTICATION_NEEDED`. **Daraus darf kein erfolgreich verbundener Cloudzugang abgeleitet werden.** Die offizielle, nicht persistierende explizite Servicekonto-Anmeldung wird separat getestet.
- `unity plugin install ai` war in einem separaten, kostenfreien Probe-Schritt erfolgreich. `unity ai doctor` meldete **`NEEDS_SETUP`**. Es ist kein neues KI-Modell generiert worden und es wurden dafür keine Unity Credits verbraucht.

## Entscheidender neuer technischer Pfad

Unity hat inzwischen ein offizielles **AI Generators for Unity CLI**-Plugin. Es kann laut Unity-Dokumentation 3D-Modelle, Rigging, Charakterbewegungen, Materialien und weitere Assets direkt auf einem unterstützten Linux-CI-System ausgeben – **ohne lokalen Unity-Editor**. Ausgaben werden als Dateien mit Provenienzbeleg gespeichert. Für jede konkrete verfügbare Modellfamilie sind ihre Eingaben, Dateiformate und Kosten über die aktuell installierten `unity ai`-Befehle zu ermitteln.

Offizielle Dokumentation:
- https://docs.unity.com/en-us/ai/generators-cli/about-generators-cli
- https://docs.unity.com/en-us/ai/generators-cli/get-started
- https://docs.unity.com/en-us/ai/generators-cli/troubleshoot
- https://docs.unity.com/en-us/unity-cli/use-unity-cli

### Zugangsvoraussetzungen

Vor einem KI-Assetauftrag muss eine **tatsächliche** Unity-Cloud-Authentifizierung und Berechtigung vorliegen. Zusätzlich setzt Unity AI u. a. eine zulässige Unity-AI-Subscription samt Sitz, aktivierte Generators, Unity Credits und akzeptierte AI-Terms voraus. `unity ai doctor` ist kostenlos und dient zur Diagnose; `unity ai help` liefert die verfügbaren Modelle/Kommandos. Keine Terms eigenmächtig akzeptieren, keine Credits kaufen, keine Kostenlimits erhöhen.

### Echter Produktionsvertrag

1. **Nachweis der Konto- und Modellberechtigung**: nur öffentlich erkennbare Status-/Fehlerklassen in CI; Secrets, API-Antworten und Cloud-Identifikatoren bleiben verborgen.
2. **Kostenangebot**: Angebot mit konkreter Modellbezeichnung und Credits prüfen. Keine automatisch bezahlte Generierung ohne ausdrückliche Kostenfreigabe bzw. zuvor vom Eigentümer bewusst festgelegte Limits.
3. **Originalgenerierung**: einen von den alten Platzhalter-/Nadel-Figuren unabhängigen, hochqualitativen Modellauftrag ausführen; rohes Original unverändert mit eindeutigem Ursprung/Task/Prüfsumme sichern.
4. **Technische Inspektion**: Dateien öffnen, Triangles/UV/PBR/Texturen, Maßstab, Rig-/Skin-Integrität, Animationsclips, mögliche Fehler prüfen. Für eine statische Requisite keine Spielanimation behaupten.
5. **Godot-Übertragung**: GLB/FBX oder fachgerecht umgewandelte Datei über den **bestehenden** Godot-Asset-Prozess, mit Kopie in isoliertem Branch, Import- und Laufzeitprüfung sowie echten Engine-Frames verwenden. Kein Konzept- oder Unity-Vorschaubild als IMPERATHEN-Screenshot ausgeben.
6. **Spielabnahme**: Figur/Gebäude/Ausrüstung sichtbar an echter Produktionsstelle testen; Kamera, Kollision, Performance, Motion, Texturen, Save/Load, Android-Export und Fold7-Hardware-Abnahme getrennt belegen. Ohne bestandene Abnahme kein Merge nach `main`.

**Dies ist der verbindliche Status für diesen Integrationsversuch, keine Behauptung, ein neues Modell sei bereits generiert oder im Android-Spiel vorhanden.**
