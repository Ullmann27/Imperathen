# Grafik Weg A (gl_compatibility): Versuch und Entscheidung

Regel: nur nachweislich Besseres übernehmen. Ergebnis: **keine Grafikänderung übernommen.**

## Aufbau
- Versuchsskript (nicht committet): `/workspace/imperathen-screens/grafik-experiment-weg-a/_exp_lighting.gd`.
- Gleiche Spielkamera wie `live_graphics_review.gd`, Profil `very_high`, 1920×1080, Xvfb und Mesa llvmpipe (CPU). **llvmpipe ≠ Leistungsmessung.**
- Pro Variante drei Bilder: Dorf/Spielkamera, Nahaufnahme Kind und die „trainer“-Position.
- Bilder: `/workspace/imperathen-screens/grafik-experiment-weg-a/<variante>-{village,child,trainer}.png` und Übersichten `sheet-*.png`, `sheet2-*.png`.

## Messwerte (Graustufen-Mittel/Std. der Bilder, keine Qualitätsmetrik)

| Variante | Dorf Mittel/Std | Kind Mittel/Std | Bewertung |
|---|---|---|---|
| base (Build 7) | 84,0 / 20,8 | 87,2 / 24,6 | Referenz |
| glow (Intensität 0,55, Soft-Light) | 84,4 / 21,5 | 87,6 / 25,1 | kaum sichtbar (Szene hat praktisch keine HDR-Spitzen) |
| filmic (Belichtung 1,25, Weiß 6) | 98,0 / 25,5 | 101,4 / 29,3 | heller und kontrastreicher, Hauttöne entsättigt: Geschmacksfrage, nicht eindeutig besser |
| AgX (Belichtung 1,35) | 94,4 / 25,4 | 97,5 / 29,1 | wie filmic, etwas flacher |
| Sonne ×1,6, Umgebung ×0,85 | 78,6 / 19,1 | 82,3 / 24,3 | Innenraum dunkler, nicht besser |
| weiche Schatten hoch + 16× anisotrop | 84,0 / 20,8 | 87,3 / 24,6 | ≈ 2 % der Pixel geändert, im Ausschnitt visuell gleich |

## Entscheidung
Keine Variante ist eindeutig besser, daher ist alles verworfen und `game_world.gd` sowie `quality_profiles.json` bleiben unverändert (Android-Profile identisch).

Der Profil-Schalter `glow` in `quality_profiles.json` wird im Code nirgends gelesen. Ihn zu aktivieren brächte nach dem Versuch keinen sichtbaren Gewinn.

Die sichtbaren Grenzen liegen nicht im Renderer, sondern im Inhalt: Wandtexturen ohne Detail/Normal-Maps, einfache Innenraumbeleuchtung ohne Fenster-/Feuerlicht und Figurenmaterialien. Weg B (Forward+ nur Desktop) ist deshalb nicht umgesetzt. SSAO/SDFGI würden die Innenräume zwar verbessern, lassen sich aber auf llvmpipe nicht fair beurteilen. Empfehlung: auf einem Desktop mit echter GPU prüfen.

## Reparatur des Nahaufnahme-Skripts
- `live_graphics_review.gd` verlässt jetzt die verketteten Openings (I-00 → Familienmorgen), bevor es aufnimmt. Commit dc9974c.
- Im Kindheitsdorf ist der alte Ausbilder ausgeblendet; statt einer leeren `close-trainer`-Aufnahme macht das Skript `close-resident` von einer sichtbaren Bewohnerin (Julia bevorzugt).
