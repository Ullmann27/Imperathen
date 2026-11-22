# Anforderungsregister

**Stand: 22.11.2026.** U = ausdrücklich aus dem Nutzerauftrag; P = Planungsableitung/Vorschlag; O = offene Entscheidung. „Abnahme“ beschreibt einen später zu erbringenden Nachweis, keinen bestandenen Test.

## Produkt und Spielerlebnis

| ID | Typ | Anforderung | Fachdokument / späterer Nachweis |
| --- | --- | --- | --- |
| R-001 | U | Freie Bauplatzwahl und begehbare Stadt statt bloßer Gebäudeliste | [Stadt](../02_game_design/CITY_AND_ECONOMY.md): Bauplatz, Material, Baufortschritt und Zugang im selben Ort |
| R-002 | U | Echtzeit-Wirtschaft mit realen Arbeits- und Versorgungsketten | Stadt: unterbrochene Lieferung stoppt den betroffenen Betrieb |
| R-003 | U | Mehrere Regionen mit persistenter Entwicklung | [Welt](../02_game_design/WORLD_AND_DIPLOMACY.md): Stadt nach Rückkehr unverändert konsistent |
| R-004 | U | Strategische Kampagnenkarte, Besitz, Handel und Diplomatie | Welt: Vertrag, Reise und Gebietskonflikt haben nachvollziehbare Folgen |
| R-005 | U | Rekrutierung eigener Truppen und verschiedene Armeestrukturen | [Kampf](../02_game_design/ARMIES_AND_COMBAT.md): Rekrutierung verbraucht Personal und Versorgung |
| R-006 | U | Persönliches Mitkämpfen neben Taktikbefehlen | Kampf: Perspektivwechsel bewahrt Figur, Einheit, Moral und Verluste |
| R-007 | U | Einfacher Anfang mit Arbeit und erster Unterkunft | [Lebensweg](../02_game_design/PLAYER_JOURNEY.md): bedeutsame, verständliche Anfangstätigkeiten |
| R-008 | U | Früher Gefährte kann Freund, Feind oder politischer Gegner werden | Lebensweg: unterschiedliche Entscheidungen verändern dieselbe Figur kausal |
| R-009 | U | Ausbildung vermittelt Steuerung und bewertet gezeigtes Können | Lebensweg: verschiedene Ausbildungsleistungen mit erklärbarer Folge |
| R-010 | U | Weitere Fähigkeiten können im Kampf erworben werden | Lebensweg: noch offene Fähigkeiten bleiben durch passende Erfahrung erreichbar |
| R-011 | U | Laufbahn kann als Soldat oder in höheren Positionen enden | Lebensweg: mindestens zwei unterscheidbare Endzustände ohne garantierte Kaiserwürde |
| R-012 | U | Vertrauen und Politik können Herrschaft/Nachfolge ermöglichen | Welt: Beförderung braucht weltlich nachvollziehbare Voraussetzungen |
| R-013 | U | Kaiserpfad eröffnet erheblich größere Reichsverwaltung | Welt: Herrschaft erweitert Zuständigkeiten und Aufgaben |
| R-014 | U | Intrigen und Niederlagen können schwere Folgen bis zum Tod haben | Lebensweg/Welt: Folgen richten sich nach entdeckten Handlungen, nicht zufälliger nachträglicher Umschreibung |
| R-015 | U | Geschichte reagiert auf wirkliche Entscheidungen und Ereignisse | [Erzählvertrag](../03_engineering/NARRATIVE_CONTRACT.md): Ereignisbezug und gültige Voraussetzungen |
| R-016 | U | Längere Kampagne und abwechslungsreiche Wiederholung | Lebensweg: spätere Spieltests messen Vielfalt, Dauer und Leerlauf getrennt |
| R-017 | U | Hochwertige realistische Darstellung | [Grafikplan](../04_art_audio/ART_AND_AUDIO_PLAN.md): lesbarer realer Engine-Nachweis unter gemessenem Budget |
| R-018 | U | Große strategische Armeen bis in den Bereich 100.000–500.000 als Fernziel | [Leistungsplan](../03_engineering/PLATFORM_AND_PERFORMANCE_PLAN.md): getrennte Zählung und Messung der Simulationsebenen |
| R-019 | U | Figurenvarianten modular wiederverwenden | Grafikplan: Rollen, Gesichter und Ausrüstung kombinieren, Variantenanzahl erst später festlegen |
| R-020 | U | Selbstständige Agentenarbeit mit Kontrolle und vollständiger Übergabe | [Agentenauftrag](../08_agent_handoff/AGENT_BRIEF.md): Dateien, Nachweise und offene Fragen liefern |

## Abgeleitete Funktionsbedingungen

| ID | Typ | Anforderung | Fachdokument / späterer Nachweis |
| --- | --- | --- | --- |
| R-021 | P | Gemeinsamer Weltzustand für Figur, Stadt, Schlacht und Karte | [Weltvertrag](../03_engineering/WORLD_STATE_AND_TIME_CONTRACT.md): gleiche IDs und Bestände beim Moduswechsel |
| R-022 | P | Zeit, Lebensalter und Reisen besitzen explizite Regeln | Weltvertrag: keine Zeitdoppelung oder unbemerkte Offline-Alterung |
| R-023 | P | Save/Load erhält Ergebnisse und bereits gewählte Story | Weltvertrag: Wiederladen erzeugt keine Wiederholung derselben Auszahlung |
| R-024 | P | KI schlägt nur kontrollierte Szenen und zulässige Zustandsänderungen vor | Erzählvertrag: ungültiger Vorschlag wird verworfen, gültige Alternative fortgesetzt |
| R-025 | P | Ressourcenänderungen einer Wahl werden gemeinsam geprüft | Erzählvertrag: kumulierte Überziehung wird verhindert |
| R-026 | P | Bei KI-Ausfall bleibt eine sinnvolle spielbare Fortsetzung | Erzählvertrag: vorhandene Reserve/regelbasierte Folge ohne bezahlten Notaufruf |
| R-027 | P | Bedienung funktioniert mit Tastatur/Maus und geplantem Controller | [Bedienung](../02_game_design/CONTROLS_AND_ACCESSIBILITY.md): Fokus, Remapping und Moduswechsel |
| R-028 | P | Skalierbare Schrift, Kontrast und verständliche Zustandsanzeigen | Bedienung: relevante Information ist auch ohne Farberkennung oder sehr kleine Schrift auffindbar |
| R-029 | P | Herkunft, Versionsstand und Nutzungsrecht jedes Produktionsassets erfassen | [Rechteplan](../07_legal/RIGHTS_AND_PROVENANCE.md): Asseteintrag und Nachweis vor Produktionseinsatz |

## Projektgrenzen und offene Entscheidungen

| ID | Typ | Anforderung / Frage | Behandlung |
| --- | --- | --- | --- |
| R-030 | U | IMPERATHEN bleibt zunächst Arbeitstitel; vor endgültiger Festlegung vertieft prüfen | [Namensakte](../07_legal/NAME_REVIEW.md), keine Freigabe fingieren |
| R-031 | U | In dieser Phase keine eigentliche Spielprogrammierung | AGENTS.md und Agentenübergabe verbindlich aktuell halten |
| R-032 | U | Öffentliches Repository beibehalten | Keine Privat-Voraussetzung oder eigenmächtige Umstellung |
| R-033 | U | Kosten-/Nutzungslimits schonen und nötige Zusatzleistungen vorher erklären | [Rechenplan](../06_production/COST_AND_COMPUTE_POLICY.md), kein unprüfbares „unbegrenzt“ versprechen |
| R-034 | O | Exakte Epoche, Startalter und Übergang zur erwachsenen Figur | Entscheidungsprotokoll, keine militärische Karriere eines Kindes stillschweigend annehmen |
| R-035 | O | Wann und wie eine Karrieregrenze endgültig wird | Erholung, Hinweise und Enden gegen Nutzerwunsch prüfen |
| R-036 | O | Engine, konkrete Version, Zielhardware und Leistungsbudgets | Kandidaten anhand erster zusammenhängender Spielsituation bewerten |
| R-037 | O | Weltumfang und verbindliche Spielstunden | Aus Prototypdaten ableiten, keine künstlichen Wartezeiten als Inhalt zählen |

## Pflege

Jede wesentliche Änderung erhält den Bezug auf mindestens eine Anforderung oder eine begründete neue ID. Eine Anforderung ist nicht erfüllt, weil ihre Fachbeschreibung existiert. In der Vorproduktion ist das Ziel zunächst „beschrieben und später prüfbar“. Umsetzung und Abnahme erhalten eigene Statusnachweise.
