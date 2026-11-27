# IMPERATHEN – Unity CLI als isolierte Asset-Schnittstelle (27.11.2026)

## Ausgangslage und Entscheidung

- **Produktion:** Das bestehende Spiel bleibt Godot-basiert, Android zuerst; keine Unity-Engine-Migration, kein `main`-Merge.
- **Unity-Zugang:** Die Unity-Downloadseite oder eine Anmeldung am Android-Browser ist keine überprüfte Unity-Editor- bzw. Cloud-Sitzung im GitHub-CI-Runner.
- **Verifizierbarer neuer Weg:** Offizielle Unity CLI (experimentell) lässt sich unabhängig vom Unity Hub auf einem Linux-CI-Rechner installieren. Die offizielle Pipeline benutzt die Unity-CDN-Quelle `https://public-cdn.cloud.unity3d.com/hub/prod/cli/install.sh` (Beta-Kanal). Dokumentation: https://docs.unity.com/en-us/unity-cli/use-unity-cli
- **Grenze:** Der CLI-Installations- und Status-Test erzeugt **keine** Modelle, kein Unity-Projekt und keine KI-Assets. Der Unity Editor setzt eine gültige Lizenz / Anmeldung voraus; Unity KI-Generatoren laufen laut Unity-Dokumentation im Editor und benötigen ein verknüpftes Cloud-Projekt. Sie sind zunächst für statische Requisiten und Umgebungselemente geeignet, nicht für garantiert vollständig geriggte AAA-Spielfiguren. Dokumentation: https://docs.unity.com/en-us/engine/6000.3/manual/unity-ai/ai-menu-access und https://unity.com/blog/unity-ai-3d-object-generator
- **Asset-Verbindung:** Bestehende Originalmodelle aus dem mit ChatGPT verbundenen Meshy-Konto können als GLB in Godot importiert werden, **ohne Unity zu benötigen**. Eine Person/Story-Szene wird erst nach realem Modellimport, passendem Rig/LOD, Originalherkunft, Engine-Aufnahme und visueller Abnahme als spielbar bezeichnet.

## Nur lesender, echter CI-Nachweis

`.github/workflows/imperathen-unity-cli-probe.yml`:
1. Lädt die Installationsdatei direkt von Unity und protokolliert ihren SHA-256.
2. Prüft die Shell-Syntax, installiert die CLI temporär und ruft `unity --version` und `unity --help` auf.
3. Prüft den Login-Zustand und den Editorbestand **ohne** Zugangsdaten, Anmeldeaufforderung, bezahlte Cloud-Anfragen, Editor-/Projektinstallation und GitHub-Schreibrechte.
4. Speichert einen neutralen Beleg als GitHub-Actions-Artefakt, ohne Anmeldedaten oder private Meshy-Modelle.

**Nach dem Test:** Erst eine nachgewiesene zulässige Unity-Editor-Lizenz/Cloud-Berechtigung erlaubt den nächsten separaten Schritt: Unity-Editor im Runner aktivieren, 3D-Generierung technisch nachweisen und die Ausgabe als GLB/FBX in einer isolierten Godot-Importprüfung testen. Keine Kosten auslösen, keine Kennwörter in Repositorydateien. `UNITY_LICENSE` usw. wären nur über GitHub Actions Secrets zulässig, nie in öffentlichem Quellcode.

**Keine Freigabe zur Produktion:** Ein erfolgreicher CLI-Probe ist nur ein Nachweis, dass sich Unity's Steuerwerkzeug auf CI installieren lässt. Er ist keine Unity-AI-Anmeldung, kein Asset- und kein Android-Spieltest.

## Verifizierte Cloud-Benutzeroberfläche und autorisierte Verbindung

Nutzer-Screenshots vom 27.11.2026 zeigen die angemeldete Unity-Cloud-Oberfläche mit Accountname `heinzullmann2212` sowie das bereits angelegte Cloud-Projekt **Imperathen**. Das ist ein vorhandenes Cloud-Projekt, **nicht** der Nachweis eines installierten Unity-Editors oder einer funktionsfähigen KI-Asset-Erstellung. Keine zweite Cloud-Projektanlage ausführen.

Die offizielle Unity-Dokumentation bestätigt für GitHub-CI: **Service Accounts** und die Variablen `UNITY_SERVICE_ACCOUNT_ID` und `UNITY_SERVICE_ACCOUNT_SECRET`; die zwei Werte werden von der Unity CLI zur Authentifizierung gelesen. Die Unity-CLI-Version ab Oktober 2026 listet Projekte mit `unity cloud projects --format json` (nicht mehr mit `unity cloud project list`). Die konkrete isolierte CI-Prüfung prüft jetzt zusätzlich, dass im tatsächlichen Cloud-Ergebnis ein Projekt namens `Imperathen` sichtbar ist; es erfolgt kein Upload.

### Einmalige Konto-Einrichtung durch den Inhaber

1. Im Unity Dashboard **Organisation leiten** → **Administration** → **Service Accounts** → **New**. Als Bezeichnung `IMPERATHEN-GitHub-CI` wählen.
2. **Keys** → **Add key**. **Key ID** und **Secret key** nur in sicheren Eingabefeldern aufbewahren. Nicht im Chat, in Issues, in PR-Kommentaren, in öffentlichem GitHub-Code oder in Logs.
3. **Manage project roles** → ausschließlich **Imperathen**, mit den für das Prüfen benötigten minimalen Leseberechtigungen. Keine pauschalen Organisations-Owner-Rechte. Spätere Upload-Rechte nur nach nachgewiesener Notwendigkeit freigeben.
4. In `Ullmann27/Imperathen` unter **Settings → Secrets and variables → Actions** zwei Repository-Secrets erstellen:
   - `IMPERATHEN_UNITY_SA_ID` = Unity **Key ID**.
   - `IMPERATHEN_UNITY_SA_SECRET` = Unity **Secret key**.
5. Den isolierten Prüflauf auf `integration/unity-cli-exploration-20261127` erneut auslösen (Branch-Push oder zugängliche Actions-Auslösung), und nur nach `UNITY_CLOUD_IMPERATHEN_PROJECT_VISIBLE` in den gespeicherten Test-Evidenzen den Cloud-Zugriff als bestanden ausgeben. Die Cloud-Projektliste und Authentifizierungsantwort werden ausdrücklich nicht in den Artefakten gespeichert.

Quellen:
- https://docs.unity.com/en-us/cloud/accounts/create-service-account
- https://docs.unity.com/en-us/unity-cli/use-unity-cli
- https://docs.unity.com/en-us/unity-cli/reference/output-formats
- https://docs.unity.com/en-us/unity-cli/release-notes/2026/october

### Verbindliche Import- und Qualitätsgrenze

Unity-Cloud-Login ist nicht Unity-AI-3D-Produktion und nicht Godot-Integration. Nur **tatsächlich erstellte/erhaltene** 3D-Dateien mit geklärter Lizenz und überprüfter Textur-/Rig-Herkunft können in den bestehenden Godot-Asset-Staging-Branch übernommen werden. Danach Import-/Animations-/LOD-/Collision-/Android-Renderprüfungen gegen denselben Spielstand. Weder alte ersetzende Nadel-Figuren noch künstlich als Unity-Originale präsentierte Renderings akzeptieren. Keine unbeaufsichtigte Freigabe zu `main` oder Release. 
