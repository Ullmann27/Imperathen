# IMPERATHEN – Weltwerkstatt: verifizierte Übergabe

**Stand:** 25. November 2026  
**Jüngster geprüfter Engine-/Weltbau-Commit:** `2452d9f5034041b7ee99e48a7824161f3e20a365`  
**Erfolgreicher vollständiger Godot-/Renderlauf:** https://github.com/Ullmann27/Imperathen/actions/runs/45634331129  
**Erfolgreicher Foundation-Lauf:** https://github.com/Ullmann27/Imperathen/actions/runs/45634347131  
**Bild- und Modell-Artefakt:** https://github.com/Ullmann27/Imperathen/actions/runs/45634331129/artifacts/15033035227  
**Archiv-Digest:** `sha256:e07fde27440a00c2e822ad9a2c05617a0e4dfaa9c55212913a306f81f10d622d` (GitHub-Angabe; Ablauf 25.12.2026).
**Vorheriger vollständig geprüfter Ausgangsstand:** `4d07b325ab5f2d7799cfe171f27a5f21e377ff6d` (CI 45606606311).

**Arbeitszweig:** `feature/world-expansion-blender-20261125`  
**PR:** https://github.com/Ullmann27/Imperathen/pull/58  
**Unveränderter erfolgreicher CI-Lauf:** https://github.com/Ullmann27/Imperathen/actions/runs/45606606311  
**CI-Artefakt mit zehn echten Godot-Bildern, GLBs, Blenderquellen und Prüfberichten:** https://github.com/Ullmann27/Imperathen/actions/runs/45606606311/artifacts/15018470946  
**Artefakt-SHA-256:** `086504aff61e35c43d172417432b363c92a26dc14518342e6f18f3b5a0997443` (GitHub-Angabe). Aufbewahrung bis 25. Dezember 2026.

## Gelieferte Original-Assets

| Typ | Bearbeitbare Quellen | GLB-Detailstufen |
| --- | --- | --- |
| Taberna / Ladenhaus | `art/world_expansion/architecture/taberna.blend` | LOD0–2 |
| Insula / Stadthaus | `art/world_expansion/architecture/insula.blend` | LOD0–2 |
| Verwaltung / Basilika | `art/world_expansion/architecture/basilica.blend` | LOD0–2 |
| Basalt-Straßenmodul | `art/world_expansion/architecture/basalt_road.blend` | LOD0–2 |
| Feldulme | `art/world_expansion/vegetation/field_elm.blend` | LOD0–2 |
| Zypresse | `art/world_expansion/vegetation/cypress.blend` | LOD0–2 |
| Lorbeergebüsch | `art/world_expansion/vegetation/laurel.blend` | LOD0–2 |

**Tatsächlich vorhanden:** sieben `.blend`-Quellen, 21 exportierte GLBs. Die Texturen sind in den Quellen und GLBs eingebettet. Metermaßstab; GLB `+Y` nach oben, Gebäudefront `+Z`. Drei LODs reduzieren Mesh-Komplexität. Die Steinflächen, Dachziegel, Vorhallen, Balkonzugang und Materialien wurden in Blender gerendert beziehungsweise nach korrigierten Exporten geprüft. Das ist keine archäologisch vermessene Rekonstruktion und keine fotorealistische Endabnahme.

## Weltwerkstatt und Umfang

Eigenständige Godot-Szene: `prototype/scenes/world_expansion/preview.tscn`. Vier auswählbare Größen mit **48, 256, 1.024 und 4.000 Gebäudeplatzierungen**, erzeugt aus wiederholten Grundmodulen; jeweils die gewählte Siedlung wird dargestellt. Der regionale Atlas umfasst fünf Produktionsorte mit zusammen **9.328 konfigurierten Platzierungen** (davon zweimal 4.000) und fünf verbundene Handelsrouten. Kein simultanes 9.328-Gebäude-Streaming, keine fertigen Städtebewohner.

64-m-Gruppen und Godot MultiMesh teilen die vorhandenen Meshdaten und wählen LODs entfernungsabhängig. Vier Qualitätsprofile begrenzen Sichtweite und Schatten. Für die Stadtübersicht wird die Fern-LOD gebündelt und die Kamera auf die tatsächlichen Geometriegrenzen ausgerichtet. Ein separates Präsentationssystem bietet Tageszeit, Sonne/Mond, atmosphärisches Licht und Wind; es verändert weder Story-Zeit noch Spielstände.

Acht **Anschlussrollen** für Bäckerei, Schenke, Schmiede, Töpferei, Weberei, Getreidehandel, Stall und Warenlager stehen im Manifest. Sie sind Metadaten, **keine** neuen Kauf-, Inventar- oder KI-Funktionen. Die Handelslogik bleibt beim bestehenden Team.

## Reproduzierbare Qualitätssicherung

Für den exakten Commit `4d07b325` ist der CI-Job `World expansion - Blender and Godot` **success**. Der zusätzlich gestartete `Foundation checks`-Lauf `45606621423` ist ebenfalls **success**.

- `tools/world_art/validate.py`: **12 Architektur-GLBs + 9 Vegetations-GLBs**, Status `passed`, keine gemeldeten Fehler.
- `tools/world_art/test_regional_routes.py`: **7/7** Prüfungen bestanden, einschließlich Umleitung und getrennter Route.
- `tools/world_art/verify_environment.py --render`: Status **passed** nach echtem Godot-Import, Runtime-Test und grafischem Lauf. Die lokalen Abschlussprüfungen erreichten **120 einzelne Assertions**, der CI-Bericht ist maßgeblich für die auf GitHub vorliegenden Bytes.
- **10 Enginebilder zu 1280 × 720**: Dorf mittags/Abend/Nacht; Wind t=0 und t=2; Windstille t=0 und t=2; Hauptstadt mit 4.000 Platzierungen; regionaler Atlas; Basilika/Normalmap.
- Test-Gate: geänderter Windzeitpunkt muss bei Wind tatsächlich unterschiedliche Pixel liefern; bei Windstille, fixierter Uhr und identischer Kamera müssen die Pixel identisch bleiben. Der Aufnahmemodus stellt die Himmelsreflexion deterministisch fertig; normale interaktive Qualitätseinstellungen bleiben unverändert.
- Tests prüfen ausdrücklich auch normal-mapped Tangenten der optimierten Basilika sowie Platzierungsgrenzen für asymmetrische Markisen/Vorhallen.

## Agentenkoordination und Abhängigkeiten

- **Architektur-Agent**: `tools/world_art/architecture.py`, `art/world_expansion/architecture/`, `prototype/assets/world_expansion/architecture/`
- **Vegetations-Agent**: `tools/world_art/vegetation.py`, `art/world_expansion/vegetation/`, `prototype/assets/world_expansion/vegetation/`
- **Environment-Agent**: `prototype/{scripts,shaders,scenes}/world_expansion/`, `prototype/tests/world_expansion_environment_test.gd`
- **Integration**: `coordination/world_expansion.json`, `tools/world_art/pipeline.py`, `docs/26_world_expansion/`, eigener Workflow.

Pfade werden über `coordination/world_expansion.json` reserviert; externe Teamzuständigkeiten und Übergaben laufen in https://github.com/Ullmann27/Imperathen/issues/16. Shop-/Innenraum-Arbeit: https://github.com/Ullmann27/Imperathen/pull/57. Die ursprüngliche Team-B-Branchbasis ist `7af39f35b1947595f95e365eb7762592feabf234`. Andere neue Stadt-PRs sind **nicht automatisch integriert**. Es erfolgte kein Merge nach `main`.

## Offene Qualitätsgrenzen

1. Feldulmenkrone wirkt noch relativ regelmäßig/offen. Astgabeln, Blattkonturen und Mikronormalen sind Original-Spielstudien und erfordern weitere Nahbereichsarbeit.
2. Windshader verschiebt Zweige und Blätter, rotiert jedoch nicht die komplette Licht-Tangentenbasis mit; besonders bei starkem Wind sichtbar.
3. Tausende Instanzen sind nicht Tausende individuell modellierte Häuser; Bürger, Händlerbewegung, Innenraum-Navigation, echte Warenbestände, Wege und Kollisionsabnahmen fehlen in diesem isolierten Modul.
4. Kein neu gebautes Android-Installationspaket; **keine** FPS-, Akkudauer- oder Thermikmessung am Galaxy Z Fold7. CI-Aufnahmen verwenden Desktop-Software-Rendering.
5. Die Produktionsorte sind fiktive Layoutanker. „Hafenstadt“ und „Fluss-Marktstadt“ behaupten keinen bereits eingebauten Hafen oder Wasserlauf.

**Integrationsregel:** Erst Daten-/API-Abgleich mit den parallel laufenden Stadt- und Handelsteams, dann Engine- und visueller Regressionstest des zusammengeführten Branches. Kein Main-Merge ohne ausdrückliche Freigabe.

## Zweite, grafisch überprüfte Fortsetzung – Commit `2452d9f5`

Die ursprünglichen Blenderdateien und 21 GLBs wurden **nicht** durch generierte Platzhalter ersetzt. Drei neue Quellcommits ergänzten ausschließlich die Weltwerkstatt:

1. `eb8b5df8`: reproduzierbare Bezirkstypen (Forum/Markt/Wohnen/Rand), Fassaden in vier Richtungen, konservativ skaliert und innerhalb der Grundstücksmaße, Shop-Metadaten an konkreten Gebäudepositionen. Bei 1.024 Gebäudeplatzierungen dokumentieren die Enginebelege 36 Forums-, 241 Markt-, 507 Wohn- und 240 Randbereichszuordnungen, 129 Händleranschlusspunkte und vier Fassadenrichtungen. **Kein** neues Händlerinventar oder Kaufabschluss.
2. `a6c159f4`: eigenständig erzeugter, reproduzierbarer Bodenshader mit kleinskaliger Farbstruktur und maximal **acht** lokalen, schattenlosen, warmen Markt-Lichtquellen statt einer Lampe pro Haus. Direkter Wechsel zwischen Nacht- und Tageslicht schaltet sie ohne Verzögerung. Die Lampen haben ein einfaches Leuchtkugel-Proxy und ersetzen noch keine modellierten Öl- oder Feuerschalen.
3. `2452d9f5`: Boden-Schattierung an die vier Profile gekoppelt; **low** unterdrückt die aufwendigeren Noise-Abfragen, `balanced`, `high` und `very_high` steuern die Stärke. Die konkrete Bildrate auf Android muss weiterhin gemessen werden.

### Tatsächlich verifiziert

- **CI `45634331129`: success**, Quellcommit `2452d9f5`. Godot 4.7.2; **133/133 Runtime-Assertions** in der isolierten Headless-Szene und **133/133 grafische Runtime-Assertions**. Das sind zwei Betriebsarten desselben Prüfsatzes, nicht 266 unabhängige Tests.
- 21/21 tatsächliche GLB-Dateien in vier Architektur-/drei Vegetationsgruppen strukturell validiert, sieben regionale Python-Routentests erfolgreich. Wind bei t=0/t=2 verändert Pixel; bei Windstärke 0 bleibt die Darstellung pixelgleich.
- **Zehn neue 1280×720-Bilder** als echte Godot-GL-Compatibility-Aufnahmen, `llvmpipe (LLVM 20.1.2, 256 bits)`, einschließlich Dorf bei drei Tageszeiten, Baumwind und Windstille, 4.000er-Übersicht, Atlas, Basilika. Alle Aufnahmen sind im verknüpften CI-Artefakt; die Datei `capture.json` dokumentiert Pixel-Hashes, `report.json` die Tests und Quellhashes.
- **Foundation `45634347131`: success**.
- Die tatsächlichen Bilder wurden zusätzlich visuell gesichtet. Die Dorfkulisse zeigt organischere Bodenvariation und warme Lichtinseln bei Nacht. Sie besitzt weiter zu viele identische Taberna-Hauskörper und großflächig freie Parzellen; die Hauptstadtübersicht wirkt im Fernmaßstab noch schematisch. Das wird nicht als fotorealistisches AAA-Endergebnis bezeichnet.

Ausführlicher Bildbefund: [VISUAL_REVIEW.md](VISUAL_REVIEW.md). Die zwei vorhandenen VIVA-ROMA-Bauzweige nutzen teilweise denselben Vegetationsshader; siehe [Koordinationskommentar zu PR #71](https://github.com/Ullmann27/Imperathen/pull/71#issuecomment-7165087462). Der neue Bodenshader wurde in eigenem `world_expansion`-Pfad angelegt und greift nicht in fremde Stadt-Szenen ein.

### Freigabe weiterhin ausgeschlossen

Die Modellqualität der Bäume, eine stärker variierte dörfliche Architektur, glaubwürdige Zwischenräume/Gärten/Höfe, begehbare Kaufhäuser, NPCs, Karawanen, die vorhandenen aktiven Handelslogiken und die physische Fold7-Messung sind weiterhin separate Arbeit. Keine neue APK, kein Merge nach `main`.
