# IMPERATHEN – Unity-Produktionsstart, verifizierter Bericht
**Datum:** 27. November 2026  
**Repository:** [Ullmann27/Imperathen](https://github.com/Ullmann27/Imperathen)  
**Isolierter Integrations-PR:** [#181](https://github.com/Ullmann27/Imperathen/pull/181)  
**Primär-Engine:** Godot 4.7.2, Zielplattform Android/Fold7. Kein Wechsel zu Unity als Laufzeit-Engine.

## 1. Was tatsächlich funktioniert

| Nachweis | Befund | Quelle |
|---|---|---|
| Offizielle Unity CLI auf Linux GitHub Actions | **Erfolgreich**, Version 1.1.0 | GitHub-Lauf [#46047705733](https://github.com/Ullmann27/Imperathen/actions/runs/46047705733) |
| Unity-Servicekonto über GitHub Actions-Secrets | **Vorhanden**, Basic-Authentifizierung über REST tatsächlich erfolgreich | sanitierter API-Bericht desselben Laufs |
| Unity Asset Manager REST API / Projekt Imperathen | **Erfolgreich**: `IMPERATHEN_VISIBLE`, `project_seen=true` | `unity-asset-api-sanitized.json` |
| Aktuelles Cloud-Assetinventar | **0 Assets** in diesem Unity-Asset-Manager-Projekt | `unity-inventory-sanitized.json`: `ASSET_INVENTORY_CONFIRMED`, `asset_count=0` |
| Unity KI-Plugin | **Installiert** auf dem Linux-CI-Rechner | `checks.txt` |
| `unity ai doctor` | **Nicht bestanden** (`REQUIRES_SETUP`) | `unity-ai-readiness-sanitized.json` |
| `unity ai help` | **Noch nicht erfolgreich verfügbar** im Servicekonto-CI-Lauf | derselbe Bericht: `ai_help_available=false` |
| `unity ai consent show` | **Nicht erfolgreich lesbar** | derselbe Bericht: `consent_readable=false` |
| Default-Organisation in lokaler CI-Unity-CLI | `CLI_FAILED`; Asset-Manager-REST benötigt diese CLI-Auswahl jedoch nicht | derselbe Bericht |
| Neues Unity-KI-Asset erzeugt, bezahlt oder nach Godot importiert | **Nein** | keine Generierung gestartet, kein Unity-Creditverbrauch in den Prüfungen |

**Interpretation:** Die Speicher-/Asset-Manager-Verbindung ist nachgewiesen, **nicht** das Nutzungsrecht für Unity AI Generators. Der Unity-Servicekonto-Zugang zur Asset-Manager-API beweist nicht automatisch eine Unity-AI-Seat- oder Generatorberechtigung.

## 2. Zusätzliche Produktionsmöglichkeiten

Unity ist für IMPERATHEN eine **zweite Art- und Tool-Pipeline**. Sie ersetzt Godot weder beim Spielcode noch beim Android-Build.

| Disziplin | Sinnvolle zusätzliche Arbeit durch Unity | Abgrenzung |
|---|---|---|
| 3D-Requisiten | Statische, separat exportierbare Gebäude- und Inneneinrichtungsdetails, Werkzeuge, Marktstände, Möbel, Ausrüstung | Das Generatorergebnis ist **kein** fertiger Gameplay-Gegenstand |
| Figuren | Modellgenerierung, je nach verfügbarem Modell Rigging, Retopologie und Motion-Generierung | Animation/IK, Foot-Lock, Interaktion und historische Optik gesondert prüfen |
| PBR | Texturen, Materialkarten, Qualitätspässe und Referenzvarianten | Godot muss den Import in seinen Renderer korrekt abbilden |
| Umgebungen | Skybox, Umgebungskunst, Beschilderung ohne problematische Fantasie-Schrift, architektonische Props | Eigentliche Welt, Streaming, Navigation und Physik bleiben in Godot |
| Audio/Film | SFX, Musik, TTS, Video-Prototypen und Sequenzmaterial (je nach freigeschalteten Modellen) | Dialoglogik, Spiel-Story und gesetzte Szenen bleiben im eigentlichen Projekt |
| Asset Manager | Zentrale Lagerung, Versionskontrolle der Assets, Vorschauen, Metadatenextraktion, Optimize/Convert | Kein Ersatz für Quellcode-Versionsverwaltung/GitHub oder Godot-Abnahmetest |
| KI-Agenten | Bei eingerichteter Unity-Editor-Umgebung auch Editor-Kontext, Tool-Gateway, Automatisierung | Der aktuelle geprüfte Zugang ist **REST Asset Manager**, kein aktiver Unity-Editor |

Offizielle Quellen: [AI Generators CLI](https://docs.unity.com/en-us/ai/generators-cli/about-generators-cli), [Unity AI Voraussetzungen](https://docs.unity.com/en-us/ai/generators-cli/get-started), [Unity Asset Manager Konzepte](https://docs.unity.com/en-us/asset-manager/basic-concepts), [Asset-Transformationen](https://docs.unity.com/en-us/asset-manager/asset-transformation).

## 3. Tatsächlich eingeleitete Arbeiten

1. **Unity-AI-Bereitschaft:** `tools/unity_bridge/probe_ai_readiness.py` führt kostenfrei `unity ai help`, `unity ai doctor` und `unity ai consent show` aus und fasst Ergebnisse ohne Tokens, Org-IDs oder Guthabenwerte zusammen.
2. **Assetbestand:** `tools/unity_bridge/inventory_asset_manager.py` fragt das echte vorhandene Asset-Manager-Projekt mittels authentifizierter HTTPS-GETs ab; keine Uploads.
3. **Produktionskatalog:** `tools/unity_bridge/production_queue.json` enthält **15** neue, gesondert spezifizierte Zielassets von Schmiedewerkzeug über Markt- und Gasthausausstattung bis zu republikanischer Rüstung und drei Storyfiguren. Jeder Eintrag enthält Produktionsprompt, Schauplatz, historische Anforderungen, Importpfad und Abnahmegates.
4. **Maschinenprüfung:** `tools/unity_bridge/validate_production_queue.py` verifiziert Herkunft, einheitliche Namen, sichere Review-Pfade, Vollständigkeit, historische Startperiode, Verbot ungeprüfter Kosten und Verbot automatischen Release-Merges.
5. **Godot-Import:** Bereits vorhandenes `tools/unity_bridge/stage_asset.py` verifiziert echte .glb-Dateien mit dem vorhandenen GLB-Inspektor. Quelle und abgenommene Datei erhalten SHA-256; Geometrie, UV, PBR und Texturen sind Pflicht, Charaktere brauchen außerdem Skin und Animation. Erst danach Godot-Import und echte Engine-/Fold7-Abnahme.

**Alle 15 Einträge sind bisher ausschließlich detaillierte Produktionsaufträge. Die Dateien existieren dadurch noch nicht.**

## 4. Reihenfolge der ersten Produktionswelle

**Welle A – sichtbares Dorfleben:** Schmiedeamboss, Blasebalg, Werkbank, Marktstand, Tavernenbank/Tisch, Türen und Haushaltsobjekte. Ziel: die Kindheits- und Dorfphase sichtbar stärker machen, statt alte Platzhalterfiguren nochmals zu rendern.

**Welle B – spät-republikanische Ausrüstung:** sachlich passende Rüstung und Helme für 58 v. Chr., mit Größen-, Kollision-, Material- und Rig-Anpassung. Keine Gleichsetzung mit vorhandenen Meshy-Kandidaten für ca. 100 n. Chr. oder mit späterer lorica segmentata.

**Welle C – Storyfiguren:** Schmied als Mentor, Eltern als eigenständige Menschen mit Persönlichkeit, glaubwürdigen Gesichtern, Körperproportionen, Skelett, Gesichtskontrolle, Laufen, Interaktion und Zwischensequenzen. Keine behauptete „lebensechte KI“ allein aus einem 3D-Modell.

**Meshy-Wiederverwendung:** Der bestehende originale Meshy-Jugendliche (`b6856033-bc9f-44fe-af12-e9843f161aed`) und bereits fertig modellierte Ausrüstungsstücke werden auf Quelle und Qualität geprüft, bevor etwas kostenpflichtig neu generiert wird. Die bereits als unzureichend abgelehnten Platzhalterrenderings werden nicht erneut als Qualitätsfortschritt ausgegeben.

## 5. Kosten und Freigabe

Unity veröffentlicht am 27.11.2026 Beispiele von **38–194 Unity Credits je 3D-Generierung**, **42–59 für Rigging** und **49–122 für Text-zu-Animation**. Dies sind allgemeine Beispielspannen, **keine** bestätigten Kontopreise, Budgets, Angebote oder Credits des Nutzers. Ein Modellauftrag kann mehrere Schritte brauchen; bei mehreren Outputs können Kosten steigen. Vor einer tatsächlichen Generierung ist ein **kontospezifisches Angebot** einzuholen.  
Offizielle Referenz: https://docs.unity.com/en-us/ai/credits/credits-about

Der Ablauf startet **keine** Generierung, falls Unity AI nicht bereit ist oder keine ausdrückliche Kostenfreigabe bzw. bewusst eingerichtetes Budget vorliegt. Es wurde keine Budgetgrenze verändert, kein Guthaben gekauft und keine Unity-AI-Vereinbarung akzeptiert.

## 6. Weg in das tatsächliche Android-Spiel

`Unity AI oder wiederverwendetes Meshy-Original → echte Datei + Ursprungsnachweis → SHA-256 / Textur-/Rig-/UV-Prüfung → isolierte Godot-Review-Kopie → Import und Laufzeitprüfung → echte visuelle Szenenabnahme → Fold7-Android-Test → kontrollierter Merge`.

**Sofortige technische Übernahme** nach Erzeugung bedeutet nur ein möglicher automatisierter Review-Import; eine ungeprüfte Übernahme in die veröffentlichte Android-App wäre weder sicher noch ehrlich. Godot-Laufzeit, Savegames, UI/Steuerung, NPCs und Continuum bleiben unberührt, bis explizite Spieltests bestanden sind.

## 7. Offene Voraussetzungen

- Unity AI-Kommandozeile muss `doctor` bestehen: Organisationskontext, tatsächliche KI-Seat, Generator-Freigabe, Nutzungsbedingungen und Credits prüfen. Der derzeitige Servicekonto-CLI-Lauf besteht diese Prüfung **nicht**.
- Nach bestandener Diagnose echte Modellauswahl und konkretes Kostenzitat vor Generierung.
- Outputformat und Urheber-/Nutzungsrechte für Weiterverwendung im öffentlichen Godot-Spiel prüfen.
- GLB aus Unity und Godot müssen nicht dieselben Material- und Animationssysteme unterstützen; Import und Qualität gelten erst nach Engine-Test als bestanden.
- Eine fertige Android-APK ist **nicht** Ergebnis dieser Unity-CI-Prüfung.
