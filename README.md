# IMPERATHEN

**Arbeitstitel · Android als Hauptplattform · erster 3D-Funktionsprototyp · Stand: 22. November 2026**

IMPERATHEN verbindet als langfristiges Spielziel persönliches Rollenspiel, Echtzeit-Städtebau, strategische Weltkarte, Diplomatie und eine an Entscheidungen anknüpfende Geschichte. Unter [`prototype/`](prototype/README.md) entsteht jetzt der erste ausführbare Abschnitt: ein römisch geprägtes Grenzdorf mit Sammeln, Bauen, Gefährtenentscheidung, Ausbildung, kleinem Gefecht und persistenten Folgen. Er setzt einen begrenzten Teil der größeren Projektmappe um.

## Auf Android anfangen

Der Einstieg für Spieler ist die **ARM64-Test-APK**. Die APK wurde bereits exportiert; Download, Prüfsumme, Installationsschritte und der aktuelle Android-Prüfbefund werden in der [Android-Installationsanleitung](docs/10_development/ANDROID_INSTALL.md) geführt. Der vollständige [Android-CI-Lauf](https://github.com/Ullmann27/Imperathen/actions/runs/45038377950) ist erfolgreich: Installation, Menü, Touch-Spielstart, Android-Zurück/Pause und App-Wechsel wurden im x86_64-Emulator tatsächlich ausgeführt. Eine Ausführung auf einem echten ARM64-Handy ist weiterhin nicht nachgewiesen.

Nach der Installation **IMPERATHEN im Querformat** starten, den Vorspann ansehen oder überspringen und **Neues Leben** wählen. Linkes Analogpad: bewegen. Rechte Tasten: interagieren und angreifen. **Pause**, **Chronik** und die Ansichten sind über sichtbare Schaltflächen erreichbar. [Touchbedienung, Android-Zurück und vollständiger Spielweg](prototype/README.md).

Die Spielschleife umfasst Holzsammeln, eine gespeicherte Gefährtenentscheidung, frei platzierbare Hütten auf der erlaubten Baufläche, einen erklärten Altersübergang, Ausbildung, bis zu drei Rekruten, ein Gefecht gegen drei Gegner und eine abschließende Folgeentscheidung. Eine Niederlage beendet diesen Lebensbogen. Provinzeroberung, Politik, Kaiserkarriere, große Armeen und generativ erweiterte Kapitel sind noch nicht umgesetzt.

Android ist gemäß dem aktuellen Nutzerauftrag und der [gemeinsamen Projektabstimmung](https://github.com/Ullmann27/Imperathen/issues/17#issuecomment-7080358655) die Hauptplattform; PC folgt als spätere Erweiterung. Zum Spielen der APK sind kein Editor, Blender oder KI-API-Schlüssel erforderlich.

## Entwicklungsstand prüfen

Die automatischen Headless-Läufe umfassen derzeit **115 UI-Prüfungen** und **35 Integrationsprüfungen** mit der tatsächlichen Hauptszene. Die Integration prüft unter anderem den Fensterpfad für Android-Zurück, Bauabbruch, Spielpause, Entscheidungen und gespeicherte Folgen. Nachweise: [UI-Protokoll](docs/10_development/evidence/ui.log), [Integrationsprotokoll](docs/10_development/evidence/integration.log) und [Prüfläufer](tools/check_prototype.py). Diese Läufe belegen keine Bildrate oder Gerätefreigabe.

Für Entwickler: [`prototype/project.godot`](prototype/project.godot) in **Godot 4.7.2** importieren und mit **F5** starten; alternativ `godot --path prototype`. [Entwicklerstart und Prüfungen](prototype/README.md#für-die-entwicklung-editor-und-prüfungen), [Android-Bauweg](docs/10_development/ANDROID_BUILD.md) und [nächster Entwicklungsdurchgang](docs/10_development/NEXT_AGENT.md). Die vorhandene Godot-Linie legt die endgültige Produktionsengine noch nicht fest.

## Hier anfangen

1. [Projektauftrag und Spielziel](docs/01_product/PROJECT_CHARTER.md)
2. [Anforderungen und ihre Zuordnung](docs/01_product/REQUIREMENTS_REGISTER.md)
3. [Aktueller Projektstatus](docs/00_governance/PROJECT_STATUS.md)
4. [Arbeitsplan und GitHub-Aufgaben](docs/06_production/BACKLOG.md)
5. [Startanweisung für den nächsten Entwicklungsagenten](docs/08_agent_handoff/START_HERE.md)

## Was hier vorbereitet wird

| Bereich | Einstieg |
| --- | --- |
| Spielsysteme und Lebensweg | [Spielpfeiler](docs/02_game_design/GAME_PILLARS.md) und [Spielerverlauf](docs/02_game_design/PLAYER_JOURNEY.md) |
| Stadt, Wirtschaft und Armeen | [Stadt und Wirtschaft](docs/02_game_design/CITY_AND_ECONOMY.md), [Kampf](docs/02_game_design/ARMIES_AND_COMBAT.md) |
| Weltkarte und Politik | [Welt und Diplomatie](docs/02_game_design/WORLD_AND_DIPLOMACY.md) |
| Eingabe und Lesbarkeit | [Bedienung und Zugänglichkeit](docs/02_game_design/CONTROLS_AND_ACCESSIBILITY.md) |
| Technische Verträge | [Weltzustand und Zeit](docs/03_engineering/WORLD_STATE_AND_TIME_CONTRACT.md), [Erzählung](docs/03_engineering/NARRATIVE_CONTRACT.md) |
| Grafik, Audio und Herkunft | [Produktionsplan](docs/04_art_audio/ART_AND_AUDIO_PLAN.md), [Bildreferenzen](docs/09_sources/VISUAL_REFERENCE_INDEX.md) |
| Qualität und Nachweise | [Teststrategie](docs/05_quality/TEST_STRATEGY.md), [Abnahmematrix](docs/05_quality/ACCEPTANCE_MATRIX.md) |
| Entscheidungen und Risiken | [Entscheidungsprotokoll](docs/00_governance/DECISION_LOG.md), [Risiken](docs/00_governance/RISK_REGISTER.md) |
| Name und Rechte | [Namensprüfung](docs/07_legal/NAME_REVIEW.md), [Rechteplan](docs/07_legal/RIGHTS_AND_PROVENANCE.md) |

## Arbeitsstand und Regeln

Das Repository bleibt auf ausdrücklichen Wunsch des Projektinhabers **öffentlich**. Eine Umstellung auf privat ist keine Voraussetzung für diese Vorarbeit. Die technischen Schutz- und Kontoeinstellungen sind getrennt vom dokumentierten Arbeitsablauf zu prüfen.

Der aktuelle Auftrag erlaubt den autonomen Entwicklungsaufbau mit drei Agenten. Spielcode, lokale Engine-Ausführung, eigene Blender-Assets und Prüfungen sind auf diesem isolierten Arbeitszweig beauftragt. Die frühere Beschränkung auf Vorarbeit ist damit erweitert. Zusätzliche kostenpflichtige Dienste oder ein Merge nach `main` gehören nicht zu diesem Block. Siehe [AGENTS.md](AGENTS.md).

IMPERATHEN ist ein vorläufiger Name. Dieses Repository behauptet weder eine abgeschlossene Markenprüfung noch eine Markenregistrierung. Die ältere Projektmappe „IRON BANNERS“ bleibt als Herkunftsquelle erkennbar. Ihre früheren Anweisungen zum sofortigen Programmieren sind für die aktuelle Phase überholt.

Konzeptbilder und Zielwerte sind keine Nachweise eines fertigen Spiels. Tatsächliche Prüfläufe und Grenzen stehen im aktuellen Entwicklungsbericht. Andere parallel laufende Teams bauen Einstiegsvorschau, Unreal-Basis und detailliertere Grafikassets; deren noch nicht übernommene Ergebnisse werden hier nicht als integriert ausgegeben.
