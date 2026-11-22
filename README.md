# IMPERATHEN

IMPERATHEN verbindet das Leben in einer antik inspirierten Grenzsiedlung mit Formationskämpfen und einer drehbaren Weltkugel. Android ARM64 ist die erste Zielplattform. Dieselbe Godot-Spielbasis exportiert für Windows und Linux.

**Figuren.** Das Hauptmenü zeigt unter **Figuren** 18 freigestellte historische Charakterbilder. Die Chronik enthält die zu deinem Lebenslauf gehörenden Personen. [Figuren und Originaldateien](art/portraits/README.md) · [Android-, Windows- und Bilddownloads](https://github.com/Ullmann27/Imperathen/releases)

**Spielen.** Im Hauptmenü startet **Neues Leben** einen gespeicherten Lebenslauf aus einer von fünf Herkünften. **Talgefecht erproben** führt sofort in die Schlacht mit 60 Soldaten. **Weltkugel erkunden** öffnet eine freie Saisonkampagne. Im Lebenslauf werden die regionalen Aufträge nach der Dorfverteidigung zugänglich. [Spielanleitung](prototype/README.md)

**In der 3D-Welt.** Die Talwache setzt bei Marsch, Lauf und Rückzug ihre Füße entsprechend der zurückgelegten Strecke. Das römische Atriumhaus ist durch die offene Eingangspassage begehbar. [Marschaufnahme](art/soldiers/field_march.webm) · [Gebäude im Vergleich](art/architecture/review/vergleich.jpg) · [Optionale Vulkan-Anbindung für PC](docs/12_integration/GRAPHICS.md)

**Bauen.** Godot **4.7.2** öffnen und `prototype/project.godot` starten. Die Android-Paketkennung lautet `at.heinz.imperathen`. Der Android-Workflow liefert nach Commit benannte APKs, Windows-ZIP, Linux-Archiv, Prüfsummen und Laufzeitprotokolle. [Integration und Prüfergebnisse](docs/12_integration/DELIVERY.md) · [Android-Bauweg](docs/10_development/ANDROID_BUILD.md) · [Engineentscheidung](docs/03_engineering/ADR_GODOT_ANDROID.md)

**Weitere Projekteinstiege.** Die technische Unreal-Referenz liegt in `game/Imperathen/`. `npm start` öffnet die lokale Webvorschau aus PR #19. Originalmodelle, Blender-Quellen und Grafik-Schauraum aus #20 und #21 sind im Integrationsbranch enthalten. [Historischer Rahmen und Kartenherkunft](docs/12_integration/ATLAS_SOURCES.md) · [Freigestellte Grafikstudien](art/landscape/README.md)

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

## Entwicklung

Aktuelle Entwicklung und Abnahme erfolgen im [Integrations-PR #22](https://github.com/Ullmann27/Imperathen/pull/22). Die früheren Fachkonzepte und Prüfberichte beschreiben ihre jeweiligen historischen Lieferstände.
