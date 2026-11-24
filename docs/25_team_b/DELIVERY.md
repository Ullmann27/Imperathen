# Team B – Living World: erster integrierter Arbeitsblock

**Stand:** 24. November 2026. **Branch:** `feature/team-b-living-world-20261124`.
**Unveränderter Ausgangsstand:** `7a21dca5dad83bf637cfbe9c02f4d9ab5cd97337`, Branch `feature/ap1-ap2-companions-20261124`, PR #53.
**Status:** Implementiert; lokal und auf GitHub vollständig geprüft. Sechs Vergleichsbilder wurden aufgenommen, automatisch verglichen und visuell kontrolliert. **[Entwurfs-PR #55](https://github.com/Ullmann27/Imperathen/pull/55)**, geprüfter Implementierungscommit **`b90d7b30830e86030b29e744452f17ba7cee25fc`**.

## Auftrag und geliefertes Spielergebnis

Team B verantwortet die eigenständig lebende Welt. Dieser erste zusammenhängende Block verbindet die bestehende NPC-Entscheidung, reale Weltgeometrie, begrenzte Beziehungserinnerungen und die vorhandene Dorfwirtschaft. Er baut auf den bereits integrierten Begleitern und Kapitel-I-Fähigkeiten auf. `main` und die Zweige anderer Teams werden nicht verändert.

| Zuständigkeit | Tatsächlich umgesetzt | Ausführliche Übergabe |
|---|---|---|
| B1 – INTELLIGENCE | Gegenseitige beobachtete Gespräche hinterlassen gespeicherte Bekanntschaften und Freundschaften. Sie beeinflussen die spätere Partnerwahl. Wände, Höhenunterschiede und Abwesenheit begrenzen Wahrnehmung und Beziehungsertrag. | [B1_INTELLIGENCE.md](B1_INTELLIGENCE.md) |
| B2 – WORLD | Getrennte Arbeitsbudgets für Gelände-Meshes, Kollisionskörper und Sektorabbau; Boden wird auf dem niedrigen Profil schon vor der Zellgrenze vorgehalten. | [B2_WORLD.md](B2_WORLD.md) |
| B3 – SIMULATION | Holzlieferungen erfordern vollständige Bezahlung. Lebensmittelkäufe füllen dieselbe Händlerkasse auf. Nur tatsächlich ausgeführte Arbeit trägt zur Produktion bei. | [B3_SIMULATION.md](B3_SIMULATION.md) |
| Gemeinsame Integration | Sichtprüfung an echter Physik, rückwärtskompatibles Laden, sichtbare Beziehungen im Bewohnerpanel, zwei vorhandene Marktkräfte beim neuen Kindheitsstart, Regression und reproduzierbare Vergleichsszenen. | Dieses Dokument |

Die Zahlen für soziale Schwellen, Terrainbudgets und Wirtschaft sind technische Spielregeln. Die neue Mithilfe der bereits vorhandenen Töpferin Antonia am Markt ist eine **Ergänzung der Spielausgestaltung**, keine Behauptung einer zusätzlichen Drehbuchszene. Es werden weder neue kanonische Figuren noch historische Ereignisse erfunden. Die aktuelle Drehbuchbasis des Projekts und die bereits vorhandenen Bewohneridentitäten bleiben maßgeblich.

## Gemeinsame Verträge

### Wahrnehmung und Welt

`main.gd` verbindet `model.npc_sight_check` mit `world.npc_sight_clear`. WorldModel reicht den Callback an `NpcBehavior.advance` weiter. Der Adapter prüft zwischen beiden Fußpunkten mit jeweils 1,45 Metern Augenhöhe die tatsächliche Kollisionsgeometrie. Er verwendet die vorhandene statische Weltmaske, schließt die identifizierten Endpunktakteure aus und hängt nicht von der aktuellen Spielerhöhe ab. Nähe- und Höhenprüfungen gehen dem Raycast voraus; ein Cache gilt nur innerhalb einer Entscheidungsrunde.

Marcus' bisher gespeicherte Beobachtung enthält einen Mittelversatz von 0,9 Metern. Ausschließlich der vorübergehende Wahrnehmungssnapshot korrigiert diesen Versatz. Das Speicherformat und die bestehende Wiederherstellung ziehen weiterhin wie zuvor zusammen. Die Integration prüft Marcus' tatsächliche Weltbeobachtung, eine niedrige Wand und die gespeicherte Wiederherstellung.

### Beziehungen und Spielstände

Schema v5, Wirtschafts-Version 1 und Bewohner-Version 1 bleiben erhalten. Neu ist nur der versionierte Unterbereich `village.behavior.social`. Ein gültiger alter Spielstand erhält beim Laden leere soziale Erinnerungen. Vorhandene fehlerhafte Beziehungen werden abgelehnt. Ganzzahlige Versions- und Begegnungswerte werden nach JSON-Laden normalisiert; die Prüfung vergleicht den vollständig gespeicherten und fortgesetzten Zustand.

Die gemeinsame Erinnerung ist auf 96 Paare begrenzt. Sie verleiht weder Spielervertrauen noch Belohnungen, Ressourcen oder Storyfortschritt. Das Bewohnerpanel zeigt für bereits bekannte Einwohner bis zu drei gespeicherte Kontakte an. Die Anzeige ist eine reine Abfrage und verändert den Zustand nicht.

### Arbeit und Wirtschaft

Beim ausdrücklich neuen Kindheitsspiel helfen Cassia und Antonia am Markt. Antonia bleibt dieselbe vorhandene Töpferin; Silvanus und die Begleiterzuweisungen bleiben erhalten. Alte Spielstände behalten ihre Belegschaft. Die weiterhin vorhandenen 14 Wirtschaftsidentitäten sind nicht mit der gesamten sichtbaren Bevölkerung gleichzusetzen.

Eine zulässig umgeteilte Wache entscheidet an einem zivilen Arbeitsplatz nun `work`. Nur tatsächlicher Wachdienst darf `patrol` oder `alert` als Dienstzeit anrechnen. Diese gemeinsame Korrektur verhindert, dass eine rechtmäßig zugeteilte Arbeitskraft dauerhaft unproduktiv bleibt.

Für eine Lieferung werden vier Holz nur gegen den vollständigen Lohn von sechs beziehungsweise sieben Denaren ausgetauscht. Fehlendes Händlergeld pausiert die Lieferung und erhält Teilarbeit. Beim Notgetreidekauf erreicht die Zahlung diese Händlerkasse. Lager- und Kassenobergrenzen werden vor Änderungen geprüft; wiederholte Befehlskennungen bleiben auch nach Neustart wirkungslos.

## Nachweise

Alle folgenden lokalen Läufe wurden nach den beiden im unabhängigen Review gefundenen Anschlusskorrekturen ausgeführt. Engine: **Godot 4.7.2.stable.official.ed1daf0bf**. Jeder Prüflauf verwendet getrennte, wegwerfbare Speicherverzeichnisse.

| Prüfung | Tatsächliches Ergebnis | Beleg |
|---|---:|---|
| Vollständige Engine-Matrix einschließlich Import | **67/67 Gruppen bestanden**, keine vom Prüfläufer gefundenen Warnungen | [validation_report.json](evidence/local/engine/validation_report.json) |
| Bestehende Python-Prüfungen | **167 Tests bestanden** | [python.log](evidence/local/python.log) |
| Neue NPC-Regeln | **72 Prüfungen bestanden** | [npc_social_memory.log](evidence/local/engine/npc_social_memory.log) |
| Neue Handelstransaktionen | **245 Prüfungen bestanden** | [commerce_transaction.log](evidence/local/engine/commerce_transaction.log) |
| Gelände und physische Zellwechsel | **8.662 Invariantenprüfungen bei 1.009 Aufrufen**, null Fehler | [regional_terrain.log](evidence/local/engine/regional_terrain.log) |
| Speicher-, Welt- und Panelintegration | **32 Prüfungen bestanden** | [team_b_integration.log](evidence/local/engine/team_b_integration.log) |
| Kontrollierter Wirtschaftslauf auf Basis und Änderung | Unterbezahlung und verschwindende Kaufzahlung auf der Basis reproduziert, neue Bilanz nachgewiesen | [economy-before-after.log](evidence/local/economy-before-after.log) |

Die Einzelzahlen sind Teil der 67 Gruppen und werden nicht zu einer vermeintlichen Zahl unabhängiger Spielszenarien addiert. Insbesondere die Geländeprüfung wiederholt Invarianten über viele Streamingaufrufe. Ihre CPU-Zeitangaben sind keine Android-Bildratenmessung.

Die Integrationsprüfung verwendet echte `CharacterBody3D`-/Weltgeometrie, tatsächliche Speicher-Envelopes und das produktive Bewohnerpanel. Kontrollierte Gesprächsabsichten und Beobachtungen sind ausdrücklich Testeingaben. Das ist kein unbeaufsichtigter Langzeitdurchlauf des gesamten Dorfes.

### Sichtbarer Vergleich

`prototype/tests/team_b_review.gd` wird als dieselbe externe Datei sowohl auf `7a21dca` als auch auf dem Team-B-Commit ausgeführt. Drei Szenen zeigen die Marktbesetzung, die Arbeitsübersicht und das Bewohnerpanel nach identischen Gesprächseingaben. Kamera, Auflösung 1280 × 720, Profil, Darstellungstakt und feste Figurpose müssen übereinstimmen. Die Bilder stammen aus der produktiven Welt und UI. Die Prüfszene setzt Gesprächsabsichten, jedoch keine Beziehungserinnerung von Hand.

`tools/capture_living_world_comparison.py` prüft Quellhashes vor und nach Import beziehungsweise Aufnahme, dieselbe Skriptdatei, Bildgrößen und Bildprüfsummen. Bekannte GLB-Importableitungen werden durch die bereits vorhandene Herkunftsprüfung geprüft. `.github/workflows/living-world-review.yml` erfasst beide Revisionen unter derselben offiziellen Engine und lädt die Nachweise als CI-Artefakt hoch.

Die soziale Vergleichsaufnahme verwendet den dokumentierten Domain-Fallback ohne Geometrie-Callback. Sie belegt das neue Panel nach gleichen Gesprächseingaben; die echte Sichtanbindung belegt die separate Integrationsprüfung. `all_panel_text_including_scrolled_content` enthält auch außerhalb des Bildausschnitts liegende Labeltexte und ersetzt keine visuelle Kontrolle.

Der [GitHub-Lauf 45445434654](https://github.com/Ullmann27/Imperathen/actions/runs/45445434654) bestand am 24. November 2026 auf dem veröffentlichten Implementierungscommit erneut **67/67 Engine-Gruppen und 167 Python-Tests**, jeweils ohne vom Prüfläufer gefundene Warnungen. Der X11-/OpenGL-Vergleich bestand für alle drei Szenen. Renderer: `gl_compatibility`, Softwareadapter `llvmpipe (LLVM 20.1.2, 256 bits)`. Das sind tatsächliche Desktop-Bilder, keine physische Android-Aufnahme.

| Bildpaar | Visuell kontrolliertes Ergebnis | Bilder |
|---|---|---|
| Marktstand | Antonia steht zusätzlich am vorhandenen Marktstand; der identische Kamerablick zeigt beide eingeteilten Arbeitskräfte. | [Vorher](evidence/ci/before/01_market_staff.png) · [Nachher](evidence/ci/after/01_market_staff.png) |
| Arbeit & Versorgung | Vorher eine Marktkraft mit Personalmangel, nachher zwei. Die weiterhin fehlenden vier Holz werden korrekt als Betriebsgrund angezeigt; die Aufnahme behauptet keine bereits erfolgte Lieferung. | [Vorher](evidence/ci/before/02_work_panel.png) · [Nachher](evidence/ci/after/02_work_panel.png) |
| Menschen & Berufe | Die neuen gegenseitigen Einträge „Vertrauter Nachbar“ bei Julia und Silvanus sind sichtbar und lesbar. Sie stammen aus denselben 16 halben Gesprächssekunden. | [Vorher](evidence/ci/before/03_social_panel.png) · [Nachher](evidence/ci/after/03_social_panel.png) |

[Vergleichsbericht](evidence/ci/comparison.json), [visuelle Sichtung](evidence/ci/review-receipt.json), [CI-Enginebericht](evidence/ci/engine/validation_report.json) und [CI-Pythonprotokoll](evidence/ci/python.log) sind zusammen mit den unveränderten PNG-Dateien im Repository gespeichert. Alle sechs Bilder wurden tatsächlich geöffnet und kontrolliert; der Nachweis beruht nicht allein auf ausgelesenen Paneltexten. Die bestehenden CI-Läufe „Foundation checks“ und „NPC and animated asset regressions“ bestanden ebenfalls.

Während dieser Lieferung rückte der Ausgangszweig auf `6fd8978f957018bf752e6f54f98ca7781a1651a3` vor. Diese Änderungen betreffen Android-Export, Paketprüfung, Signierung und deren Dokumentation; keine GDScript-Laufzeitdatei überschneidet sich. PR #55 bleibt dagegen konfliktfrei zusammenführbar. Der unveränderte Team-B-Vergleich bezieht sich ausdrücklich weiterhin auf `7a21dca` und `b90d7b3`; ein späterer Integrationsstand braucht seine eigene Freigabe.

## Reproduktion

Ab dem Repository-Stamm:

```bash
python3 -m unittest discover -s tests -p 'android_*_test.py'
python3 tools/check_prototype.py --godot godot --keep-going --report /tmp/imperathen-team-b-check
```

Der CI-Workflow reproduziert zusätzlich den Vergleich gegen den eingefrorenen Ausgangscommit. Er baut keine APK und verändert keine vorhandenen Freigabeschranken.

## Grenzen und nächster Anschluss

Dieser Block liefert den ersten integrierten Abschnitt der umfassenden Team-B-Zuständigkeit. Richtungsabhängige Blickkegel, Geräusche, Gerüchte, vollständige regionale Bevölkerung, ferne Städte, ein Welt-Navmesh, persistente Zellzustände, Karawanen, freie Preisbildung, Diplomatie und langfristige Armeelogistik sind damit noch nicht umgesetzt. Die vorhandene strategische Saisonkarte bleibt ein getrenntes Planspiel.

Die Terrainbudgets begrenzen Stückzahlen pro Aufruf; sie garantieren keine Zeitgrenze oder bestimmte Bildrate. Der physische Zellwechsel wurde für die vorhandene Fußgängerbewegung geprüft. Es gibt hier keine physische Android-Messung zu Bildrate, Wärme, Akku oder Touchbedienung und keine neue APK. Die bereits dokumentierten Bewegungsfreigaben des anderen Teams bleiben separat offen.

Der nächste ausführbare Anschluss ist ein gemeinsamer Spielablauf mit frei bewegten Bewohnern: Weg zum Betrieb, Arbeitsunterbrechung, Wiederaufnahme und gespeicherte Begegnung zusammen beobachten. Danach kann B2 persistente Zellzustände und B3 den Warentransport zwischen tatsächlich ausgebauten Siedlungen ergänzen. Für gemeinsame Dateien bleibt eine koordinierte Integration erforderlich; die drei Fachmodule werden nicht durch konkurrierende Änderungen an WorldModel/Main verbunden.
