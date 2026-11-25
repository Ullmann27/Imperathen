# Visuelle Abnahme – IMPERATHEN Weltwerkstatt, 25. November 2026

**Quellstand:** `2452d9f5034041b7ee99e48a7824161f3e20a365`  
**Godot-Aktionslauf:** https://github.com/Ullmann27/Imperathen/actions/runs/45634331129  
**Bildpaket mit allen zehn Original-PNGs:** https://github.com/Ullmann27/Imperathen/actions/runs/45634331129/artifacts/15033035227  
**Engine:** Godot 4.7.2, GL-Compatibility unter llvmpipe/Mesa, 1280 × 720. Kein Fold7-Leistungsnachweis.

## Geprüfte Bilder

| Bild im CI-Archiv | Sichtprüfung |
| --- | --- |
| `01_village_midday.png` | Unterschiedliche Gebäudefronten und Dachausrichtungen; neues, nicht mehr rein flächiges Erd-/Grasmaterial; zu große leere Zwischenflächen |
| `02_village_sunset.png` | Beleuchtungswechsel zu wärmeren Tönen, noch keine eigenständige Atmosphäre mit Rauch/Nebelpartikeln |
| `03_village_night.png` | Maximal acht warme Lichtinseln am Markt; der Fernbereich bleibt absichtlich schwach beleuchtet, Lichtmodell/Quellen sind noch vereinfachte Studien |
| `04_vegetation_wind_t0.png`, `05_vegetation_wind_t2.png` | Tatsächliche Ulme, Zypresse, Lorbeer im selben Bild; Wind verändert Pixel, Krone und Blattgeometrie noch deutlich prozedural |
| `06_vegetation_calm_t0.png`, `07_vegetation_calm_t2.png` | Bei Windstille exakt identische Pixel-Hashes trotz geänderter Animationszeit |
| `08_capital_4000.png` | 4.000 Instanzen technisch dargestellt; sehr regelmäßiges, aus großer Höhe rasterartiges Siedlungsbild, keine entwickelte historische Hauptstadt |
| `09_regional_routes.png` | Fünf regional verknüpfte Produktionsorte und Routen, keine echte Weltreise-Simulation |
| `10_basilica_normalmap.png` | Vorderansicht mit Säulen, portikaler Überdachung und Dachziegeln; Normalmapping im Import geprüft, Kulissen- und Parzellengestaltung weiterhin schematisch |

## Direkt vergleichbare Verbesserung

Gleiche Dorfkamera im ursprünglichen geprüften Stand `eb8b5df8` und dem neuen Stand `2452d9f5`: Das neue Tagesbild besitzt sichtbare Bodenfleckung, das Nachtbild gezielte warme Shopbeleuchtung statt ausschließlich dunkler Fassaden. Zwei festgelegte Fassaden-Bildausschnitte ergeben bei 8-Bit-Bildhelligkeit im **Zwischenstand** `a6c159f4`:
- Links: Mittelwert **19,86 auf 26,81**.
- Rechts: Mittelwert **17,72 auf 24,97**.

Diese Ausschnittswerte dienen nur als reproduzierbare Bilddiagnose. Sie sind kein Beleuchtungsstärken-Nachweis in Lux und kein FPS- oder HDR-Benchmark. Die neueste Variante `2452d9f5` ergänzt daran vor allem den profilstufenabhängigen Bodenshader.

## Nächste Qualitätsdefizite (noch offen)

1. **Wiederholungsmuster:** 48 Dorfhäuser sind momentan derselbe Taberna-Grundtyp mit Variationen in Ausrichtung und Größe. Benötigt werden echte zusätzliche Blender-Wohn-/Hof-/Werkstattmodule, Texturen und innerstädtische Zwischenräume.
2. **Straßenraum:** Regelmäßiges Steinpflaster benötigt echte Abzweige, Gebrauchsspuren, Entwässerung, Mauern, Stufen und enge Gassen statt flächiger Wiederholung.
3. **Vegetation:** Eine offene, zu regelmäßige Ulmenkrone, kantige Blattumrisse und simplified wind-normal shading werden durch den bestandenen Shader-Pixeltest nicht automatisch hochwertig.
4. **Nachtatmosphäre:** Echte gebaute Öllampen/Fackeln, Brandflackern, warme Fenster, Innenräume, globale Lichtexposition und LOD-Lichtbudgets fehlen.
5. **Stadtsilhouette:** Befestigungsringe, Forumplatz, Straßenhierarchie, Therme, Aquädukt und Verwaltungsbezirk sind bisher keine ausgeformte, historisch verankerte Großstadt.
6. **Zielgerät:** Ein dauerhafter Galaxy-Z-Fold7-Test muss reale Frametimes, GPU/RAM-Last und Wärme pro Profil messen. Software-Rendering im CI ersetzt das nicht.

**Freigabefazit:** Nutzbarer, überprüfbarer Weltbau- und Shader-Baukasten. Nicht die versprochene endgültige AAA-Open-World-Grafik. Keinen Main-Merge oder APK-Release allein aufgrund dieser Darstellung durchführen.
