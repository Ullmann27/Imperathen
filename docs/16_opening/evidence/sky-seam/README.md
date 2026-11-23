# Nachweis: Wolkennaht im Talblick korrigiert

**Ergebnis:** Die dünne blaue gestrichelte Linie im Himmelsbereich des Talbildes ist im echten Godot-Viewport behoben. Der neue Produktionsstill ist [`1280x720-valley-corrected.png`](1280x720-valley-corrected.png). Die vorherigen Abnahmebilder und der ursprüngliche Film unter `../render/` bleiben unverändert erhalten.

## Ursache und gezielte Änderung

Die Wolkentextur verwendet die Kugelkoordinate `SKY_COORDS.x`. An deren Umlauf springt die Längengradkoordinate von 1 auf 0. Die bisherige Abtastung mit `texture(...)` berücksichtigte diesen Sprung bei der impliziten Auswahl der Mipmap-Stufe. Dadurch erschien entlang einzelner Pixelgruppen der blauere Grundhimmel statt der Wolkenfarbe.

In `prototype/scripts/world/village/clouds.gdshader` wird jetzt nur der periodische x-Anteil der beiden Texturgradienten um den nächsten ganzzahligen Umlauf korrigiert. `textureGrad(...)` erhält diese Gradienten. Der vorhandene Mipmap-Sampler, die Textur, Wolkenbewegung, Farben und Qualitätsprofile bleiben erhalten. Die feste LOD-0-Abtastung war ausschließlich ein Diagnoseschritt und wurde nicht in das Produkt übernommen.

Die API-Bedeutung ist in der offiziellen [Godot-Dokumentation zu `textureGrad`](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shader_functions.html#shader-func-texturegrad) beschrieben; die konkrete Fehlerursache wurde zusätzlich durch die folgenden echten Rendervergleiche geprüft.

## Isolation und Bildvergleich

| Prüfschritt | Tatsächlicher Befund |
| --- | --- |
| Originalszene ohne Overlay | Die Linie bleibt sichtbar: [`baseline-without-ui.png`](baseline-without-ui.png). |
| Alle sichtbaren Welt-Geometrien ausgeblendet | Die Linie bleibt im Himmel: [`sky-original.png`](sky-original.png). |
| Temporärer Shaderklon mit expliziter LOD 0 | Die Linie verschwindet. Dieser Schritt isoliert die Mipmap-Auswahl als Ursache. |
| Temporärer Shaderklon mit korrigierten Gradienten | Die Linie verschwindet bei beibehaltenen Mipmaps: [`sky-corrected.png`](sky-corrected.png). |
| Separat gerenderte Maske großer unbereinigter Längengrad-Ableitungen | Die Maske folgt der Linie: [`sky-derivative-mask.png`](sky-derivative-mask.png). |
| Neuer Prozess mit korrigierter Produktionsdatei | Fehlerfreier echter Main → Neues Spiel → Intro; kein Laufzeit-Austausch von Material oder Shader. |

Im oberen Himmelsbereich von 1280 × 165 Pixeln unterscheiden sich 160 Pixel um mehr als zwei 8-Bit-Farbstufen. 158 davon liegen direkt auf der separat gerenderten Ableitungsmaske, die zwei weiteren unmittelbar an ihrem Rand. Die maximale Korrektur beträgt 61/255 je Farbkanal. Der Kontrollbereich von 750 × 165 Pixeln ist vollständig pixelgleich. Das Himmelsbild mit korrigierten Gradienten ist außerdem pixelgleich zum unabhängigen LOD-0-Diagnosebild. Einzelwerte stehen in [`pixel-analysis.json`](pixel-analysis.json).

Auch beim Vergleich des neuen vollständigen Talbildes mit dem zuvor freigegebenen Talbild bleibt dieser Kontrollbereich exakt gleich. Die Korrektur kaschiert die Linie folglich weder durch einen anderen Blickwinkel noch durch geänderte Himmelsfarben.

## Prüfbedingungen und Grenzen

Der neue Produktionsstill wurde mit Godot 4.7.2, `gl_compatibility`, Mesa llvmpipe, 1280 × 720 Pixeln, Profil `very_high` und 3D-Skalierung 1,0 aufgenommen. Kamera: `valley`, Zeitpunkt 0,55; feste Darstellungszeit 4,0 Sekunden. Der Prozess endet mit Exit 0 und ohne `ERROR` oder `SCRIPT ERROR`. Der Log enthält lediglich den vorhandenen Hinweis, dass der Softwaretreiber den VSync-Modus nicht umschalten kann. Spielerposition und maßgeblicher Spielzustand sind vor und nach der Aufnahme identisch. Details: [`production-still.json`](production-still.json) und [`production-still.log`](production-still.log).

Die temporären Isolationsprozesse tauschten Sky-Materialien im laufenden Renderer. Beim Beenden meldeten sie jeweils zwei GL-Texturlecks von je 21.844 Bytes; diese Meldungen bleiben in den Diagnose-Logs sichtbar. Der getrennte Produktionsprozess verwendet keine solchen Materialwechsel und zeigt diese Meldungen nicht. Die Diagnose-Logs werden deshalb nicht als fehlerfreie Produktläufe bezeichnet.

Dies ist ein visueller Desktop-Software-Rendernachweis. Er belegt weder eine Android-Geräteleistung noch eine bestimmte Bildrate auf einem Telefon oder einer Konsole. Die Korrektur verändert keine Assets und macht aus dem vorhandenen Prototyp keine Produktionsgrafik einer PS5-Veröffentlichung.

## Quellenstand

- Vorheriger Shader SHA-256: `54c25d9207c817a50727fa9c2cd938ad79e79b457b83a4b06f86690c545891e3`
- Korrigierter Shader SHA-256: `be8a689ab1f4ef3bafd02360a7c30dbde6aa6183bf4510c71b4fd529cc6eb391`
- Neuer Talstill SHA-256: `b7f9c8df85defa36fd6955b8fb271f3bc089ee9cf92fe25566d09af5f55bf6b0`

Die maschinenlesbare Zusammenfassung mit Dateihashes steht in [`sky-seam-review.json`](sky-seam-review.json).

## Aktualisierter Bewegungsauszug

[`opening-runtime-excerpt.mp4`](opening-runtime-excerpt.mp4) zeigt 12,000 Sekunden aus dem tatsächlichen aktuellen Renderer: je zwei Sekunden aus den fünf Kameraeinstellungen und zwei Sekunden Zielkarte. Es handelt sich ausdrücklich um einen Auszug mit unveränderter Kamerageschwindigkeit, nicht um das vollständige Intro. Die Wiedergabe verwendet 1280 × 720 Pixel, 12 Bilder/Sekunde und das Profil `balanced`; sie ist kein Laufzeit-Benchmark. Alle 144 Frames wurden neu mit dem korrigierten Produktionsshader gerendert.

Der Film enthält die vorhandene `frontier_ambience.wav`, nachträglich mit −15 dB unterlegt und auf die Filmlänge geloopt. Es gibt keine gesprochenen Stimmen. Das MP4 ist 2,862,933 Bytes groß, H.264/AAC, mit vollständiger fehlerfreier Decodierprüfung. Die Datei-SHA-256 lautet `23c9671f625bd9b45184eff7197e90cfb9425a2697be5f09b28a958dfb7b393b`.

[`motion-review.json`](motion-review.json) nennt den Shader-SHA ausdrücklich, prüft alle 14 erfassten Quellen vor und nach der Aufnahme und dokumentiert Audioquelle, Gain und nachträgliche Unterlegung. Der reale Übergang zur Steuerung und die vorhandene Vier-Holz-Brunnenentscheidung wurden im selben Lauf erneut ausgeführt; die zugehörigen aktuellen Bilder und Ergebnisse liegen ebenfalls hier. Die alten Abnahmen unter `../render/` sind gegen den vorherigen veröffentlichten Commit als unverändert geprüft.
