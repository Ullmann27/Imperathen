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
