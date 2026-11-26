# Römisches HUD „Tabula & Velum“ (D-037)

Stand: 26.11.2026 · Branch `feat/roman-hud-20261126` · Godot 4.7.2, `gl_compatibility`.
Gerätestatus: **implementiert und headless getestet; Render unter xvfb/llvmpipe; nicht auf dem Fold7 bestätigt.**

## Ziel

Ein eigenes Interface mit römischer Identität, das in ruhiger Erkundung möglichst viel Welt frei lässt und nur dann
Präsenz zeigt, wenn eine Information gebraucht wird. Vergleichsspiele dienen nur als Qualitätsmaßstab; Formen, Glyphen
und Farben sind eigene Vektorzeichnung, die einzige mitgelieferte Schrift ist Cinzel (SIL OFL 1.1).

## Gestaltungssystem (`prototype/scripts/ui/roman_hud/`)

| Datei | Aufgabe |
| --- | --- |
| `hud_style.gd` | Farben (Aurum, Bronze, Atramentum, Charta, Minium, Aerugo), Typo- und Bewegungsskala, dp-Maßstab, Plaketten und Velum |
| `hud_icons.gd` | Eigene Linien-Glyphen (24er-Raster, SVG), in der exakten Pixelgröße des Elements gerastert |
| `hud_director.gd` | Präsenzregie: was ruht, was durch Ereignisse geweckt wird |
| `compass_ribbon.gd` | Kompassband mit Zielmarke und Entfernung, Ortskarte auf Antippen |
| `medallion_button.gd` | Runde Bronze-Medaillons der Touch-Steuerung, Kontextaktion mit vergoldetem Ring |
| `vitals.gd` | Lebenskraft und Ausdauer, nur bei Bedarf |
| `dialogue_stage.gd` | Filmisches Gespräch: Balken, unteres Drittel, nummerierte Antworten (I, II, III …) |
| `menu_kit.gd` | Hintergrundgradierung über der lebenden Welt, Regel, Antwortplakette, Gegenstandskarte, Figurine |
| `codex.gd` | „Dein Lebensweg“: Chronik, Ausrüstung und Beutel, Fähigkeiten, Menschen |

Angeschlossene Bildschirme: Spielansicht und Pause (`game_ui.gd`), Verwaltung „Dein Leben im Dorf“
(`village_life_panel.gd`: Dorfleben, Arbeit & Versorgung, Menschen & Berufe, Region), Handel und Beutel
(`city_support_panel.gd`).

## Verhalten

- **Missionsanzeige:** eine Zeile oben links; die Erläuterung erscheint bei neuem Ziel für 9 s und ruht danach. Antippen
  holt sie zurück.
- **Kompass:** schmales Band statt dauerhafter Karte; die Ortskarte öffnet sich auf Antippen und schließt selbst.
- **Präsenzregie:** Vorrat nur bei Änderung, Lebenskraft/Ausdauer nur bei Bedarf oder Gefahr, Befehlsplaketten in ruhiger
  Erkundung als Glyphen, Tastaturhinweise nur beim Einstieg. Gefahr, Bau- und Stadtmodus holen alles zurück.
- **Kontextaktion:** die Welt meldet die nächste sinnvolle Handlung; das Interagieren-Medaillon nennt sie und leuchtet
  (Desktop: Tastenhinweis).
- **Einstellung „Anzeigen dauerhaft einblenden“:** nichts ruht. Die HUD-Dichte ist damit eine Wahl des Spielers und
  keine erzwungene Reduktion.
- **Bewegung:** 0,14 / 0,22 / 0,42 s, kubisch auslaufend; „Bewegungseffekte reduzieren“ lässt nur kurze Überblendungen.

## Touch, Formate, sichere Fläche

- Layout in dp: `HudStyle.units_per_dp()` leitet aus Anzeigedichte und Canvas-Streckung ab, wie viele logische
  Einheiten ein dp hat. 48 dp sind damit auf Innen- und Außendisplay dieselbe Fingergröße.
- Jedes Touch-Ziel hat mindestens 48 × 48 dp: Medaillons, Plaketten, Menüknöpfe, Auswahlfelder, Reiter, Kompassband.
  Das Bewegungsfeld hält mindestens 156 dp.
- Die sichere Fläche kommt aus `DisplayServer.get_display_safe_area()` (`safe_area.gd`); das gesamte HUD liegt darin.
- Geprüfte Formate: 1280 × 720, 1384 × 1536, 960 × 540 sowie simulierte Fold7-Dichten (Außendisplay hoch und quer,
  Innendisplay). Die Dichten sind im Test simuliert, nicht am Gerät gemessen.

## Kinderregel aus I-01

Für den Zwölfjährigen im ersten Morgen: keine Angriffs-, Deckungs-, Ausweich- oder Technikknöpfe, kein Legionseintrag
im Pausenmenü, kein Waffen- oder Schildplatz in der Ausrüstung, Familie statt Truppe und Moral, kein Dorfvorrat im HUD.
Die Einstellung „dauerhaft einblenden“ ändert daran nichts. Geprüft in `roman_hud_test.gd`.

## Flächenanteil in ruhiger Erkundung

Messung: Vereinigung aller sichtbaren, zeichnenden HUD-Elemente (Deckkraft über 5 %) im 4-px-Raster, Touch-HUD, Kind im
ersten Morgen, gleiche Position und Kamera. Zusätzlich im Render die Pixeldifferenz gegen dasselbe Bild ohne HUD.

| Format | vorher (`c7931ab`) | nachher | Quelle |
| --- | --- | --- | --- |
| 1280 × 720 | 36,3 % | 12,3 % | geometrisch, headless (`roman_hud`, Probelauf des Render-Skripts) |
| 1384 × 1536 | 16,4 % | 6,0 % | geometrisch, headless |

Die Pixelmessung im echten Render (mit/ohne HUD) liegt noch nicht vor, siehe Status.

Der Test `roman_hud` hält die Obergrenzen 14 % (1280 × 720) und 7 % (1384 × 1536) fest. Der größte Einzelposten ist das
Bewegungsfeld (208 × 208 Einheiten, 4,7 % bei 1280 × 720); es bleibt als Touch-Ziel bewusst sichtbar.

## Nachweise

- Tests: `python3 tools/check_prototype.py --godot <godot> --only roman_hud,ui,roman_menu,touch_controls,village_panels,… --keep-going`.
- Render nach D-038: `python3 tools/ui/capture_roman_hud.py --godot <godot> --output <dir> --label after [--tree <checkout>] [--parts explore|world|fixtures]`.
  Dasselbe Skript rendert den Stand vorher und nachher (gleiche Position, gleiche Kamera, gleiche Zustände) und schreibt
  Commit, Renderer, Treiber, Auflösung, geladene Modelle mit SHA-256, Licht, Speicher und Bildzeiten in die Quittung.
  Aufnahmen mit `fixture: true` zeigen die echten UI-Klassen mit echtem Modellzustand vor neutralem Hintergrund (ohne
  Welt), weil der Zwölfjährige Arbeitszuweisung, Erwachsenen-Kodex und Markt noch nicht erreicht.

Vorher/Nachher-Render: **noch nicht erzeugt**, siehe Status.

## Recherche (D-050)

- Mindestgröße für Touch-Ziele 48 × 48 dp (etwa 9 mm), 8 dp Abstand:
  [Android Accessibility Help – Touch target size](https://support.google.com/accessibility/android/answer/7101858).
- Sichere Fläche und Aussparungen in Godot 4: `DisplayServer.get_display_safe_area()` und `get_display_cutouts()`,
  [Klassenreferenz DisplayServer](https://docs.godotengine.org/en/4.7/classes/class_displayserver.html).
- Kontextabhängiges Ein- und Ausblenden und HUD-Dichte als Spielereinstellung; Langzeittrend zu reduzierten HUDs in
  Action-Adventures 2014–2025:
  [Toward Minimalist HUDs? (Universität Bonn)](https://bonndoc.ulb.uni-bonn.de/xmlui/handle/20.500.11811/14207),
  [Game UI & HUD Design Patterns](https://cdn.jsdelivr.net/npm/@hegemonart/get-design-done@1.60.4/reference/domains/gaming-patterns.md).
- Lesbarkeit: Kontrast nach WCAG 2.1 AA (4,5 : 1 für Text) als Richtwert; helle Schrift auf Atramentum mit Kontur und
  Schatten über der Welt. Gerechnet auf deckendem Plakettengrund: Charta 15,2 : 1, Charta gedämpft 10,3 : 1,
  Aurum 11,2 : 1, Aerugo 9,0 : 1, deaktiviert 6,3 : 1; Aurum hell auf der roten Hauptplakette 8,5 : 1. Die Plaketten
  sind zu 78–93 % deckend; der Kontrast über beliebigem Weltbild ist nicht automatisch gemessen.

## Status (26.11.2026, Abschluss auf Anweisung des Auftraggebers)

**Implementiert:** Gestaltungssystem, Spielansicht mit Präsenzregie, Kompassband mit Ortskarte, Kontextaktion,
Touch-Medaillons, Pause, Kodex (Chronik, Ausrüstung, Fähigkeiten, Menschen), filmisches Gespräch, Handel und Beutel,
Verwaltung „Dein Leben im Dorf“, Einstellung „Anzeigen dauerhaft einblenden“, 48 dp für Menüknöpfe, Auswahlfelder und
Kompassband, Render-Skript mit Teilläufen.

**Getestet (headless, `tools/check_prototype.py --only <gruppe>`):**

- Auf dem Stand mit allen Laufzeitänderungen bestanden: `roman_hud`, `ui`, `village_panels`, `roman_menu`,
  `touch_controls`, `npc_behavior_ui`, `team_b_integration`, `city_inventory_ui`, `village_experience`, `i01_flow`
  (weitere siehe Übergabebericht).
- Nur auf dem Stand davor (`07159a0`) bestanden, danach nicht wiederholt: `village_nameplates`, `opening_overlay`,
  `opening_flow`, `i01_slice`, `childhood_integration`, `frontier_integration`.
- Auf dem aktuellen Stand nicht gelaufen: `integration`, `action_world`, `companion_follow`, `figure_gallery`,
  `city_support`, `city_market_bridge`, `city_exploration_detail`, `runtime_display_lifecycle`, `camera_collision`,
  `locomotion_regression`, `main_scene`. Keine vollständige Suite, kein Motion-Gate.
- Probelauf des Render-Skripts (headless, ohne Pixel) für alle drei Teile bestanden.

**Gerendert:** nichts. Die gemeinsame Renderwarteschlange (ein Renderauftrag zur Zeit, über 25 Wartende) hat bis zum
Abschluss keinen Lauf dieses Pakets zugelassen. Es gibt deshalb **keine Vorher/Nachher-Bilder** und keine
Pixelmessung; das Aussehen der neuen Bildschirme ist von niemandem am Bild geprüft. Insbesondere die neu gestaltete
Verwaltung (Commit `e6656f6`) wurde nur über ihre Tests und nie als Bild gesehen.

**Nächste Schritte:**

1. Vorher: `git worktree add <vorher> c7931ab`, das aktuelle `prototype/tests/roman_hud_review.gd` hineinkopieren,
   importieren, dann je Teil
   `python3 tools/ui/capture_roman_hud.py --godot <godot> --output <dir>/before --label before --tree <vorher> --parts explore`
   (ebenso `world`, `fixtures`).
2. Nachher: dieselben drei Aufrufe ohne `--tree`, `--label after`.
3. Bilder kritisch ansehen (Überläufe, Umbrüche, Lesbarkeit bei 1384 × 1536, Verwaltung und Karte), Flächentabelle um
   `pixel_share` ergänzen.
4. Übrige UI-Gruppen auf diesem Stand laufen lassen (Liste oben).
5. Am Fold7 prüfen: dp-Maßstab, sichere Fläche gefaltet und entfaltet, Daumenzonen. Bisher nur simuliert.

**Bekannte Grenzen:** Einstellungen, Galerie, Bestätigungsdialog und Technikmenü nutzen die Plaketten, aber noch
nicht durchgehend Karten und Überschriften des Kits. Die Erwachsenen-Bildschirme sind im Render-Skript Fixtures ohne
Welt.
