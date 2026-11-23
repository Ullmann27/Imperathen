# IMPERATHEN

IMPERATHEN verbindet das Leben in einer antik inspirierten Grenzsiedlung mit Formationskämpfen und einer drehbaren Weltkugel. Android ARM64 ist die erste Zielplattform. Dieselbe Godot-Spielbasis exportiert für Windows und Linux.

**Kindheit im bestehenden Dorf, 23.11.2026.** Ein neuer römischer Lebenslauf beginnt mit zwölf Jahren bei der Familie. 35 verbundene Handlungen führen durch vier bewusst begonnene Dorftage mit Eltern, Markt, Schmiedelehre und begrenzter Wachhilfe. Die Szene umfasst 20 begehbare Wohnhäuser und 41 benannte erwachsene Dorfbewohner. Natürlicherer Armschwung, getrenntes Gehen/Laufen, erste unbewaffnete Techniken, Boden-/Personenkollisionen und größere Touchflächen ergänzen diesen Entwicklungsstand. [Übergabe, tatsächliche Prüfung und Grenzen](docs/18_childhood/HANDOFF.md) · [Auftrag für Chat A](docs/18_childhood/CHAT_A_BEWEGUNG_KAMPF_STEUERUNG.md) · [Auftrag für Chat B](docs/18_childhood/CHAT_B_DORF_GESCHICHTE_WELT.md)

**APK-Stand.** Die [zuletzt veröffentlichte und geprüfte APK](docs/17_village_life/DELIVERY.md) enthält noch den früheren Dorfanfang. Für den neuen Kindheitsumbau sind Android-Bau und ein angepasster tatsächlicher Laufzeitweg eine eigene nächste Abnahme. Die vorbereitete nächtliche Reitersequenz ist noch nicht fertig inszeniert.

**Aktueller Charakterausbau.** Der Italia-Hauptcharakter erhält eine anatomisch modellierte 3D-Figur mit separaten Augen, Gesichtsmorphs, vier Detailstufen und einer Blender-Quelle. Die Lieferung dokumentiert echte Blender-Renderings, Godot-Aufnahmen und die noch offenen Unterschiede zur vom Nutzer vorgegebenen PC-/Konsolenqualität. [Charakterlieferung und Prüfnachweise](docs/14_character_realism/DELIVERY.md) · [Historische Gesichtsquellen](docs/art/CHARACTER_REFERENCE_SOURCES_2026_11_22.md) · [Gladius und Scutum](art/weapons/README.md)

**Figuren.** Das Hauptmenü zeigt unter **Figuren** 18 freigestellte historische Charakterbilder. Die Chronik enthält die zu deinem Lebenslauf gehörenden Personen. [Figuren und Originaldateien](art/portraits/README.md) · [Android-, Windows- und Bilddownloads](https://github.com/Ullmann27/Imperathen/releases)

**Spielen.** Im Hauptmenü startet **Neues Leben** einen gespeicherten Lebenslauf aus einer von fünf Herkünften; die neue römische Partie verwendet den Familienanfang. **Fortsetzen** erhält den bisherigen Weg vorhandener Saves. **Talgefecht erproben** führt sofort in die Schlacht mit 60 Soldaten. **Weltkugel erkunden** öffnet eine freie Saisonkampagne. [Kindheit und Zeitvertrag](docs/18_childhood/STORY.md) · [Bisherige Spielanleitung](prototype/README.md)

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

Die aktuelle Fortsetzung liegt auf `feature/childhood-village-20261123` und baut auf `feature/village-life-delivery-20261123` auf. Sie erhält den Charakterstand aus PR #34 und die bestehenden Präsentations-/Save-Systeme aus PR #35. Der [ursprüngliche Integrations-PR #22](https://github.com/Ullmann27/Imperathen/pull/22), die früheren Fachkonzepte und Prüfberichte beschreiben ihre jeweiligen historischen Lieferstände. Die offene visuelle Abnahme des Hauptcharakters bleibt in [Issue #33](https://github.com/Ullmann27/Imperathen/issues/33) festgehalten.
