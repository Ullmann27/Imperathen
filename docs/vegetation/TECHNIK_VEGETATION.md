# Technik der Vegetation (Valdora)

Stand 26.11.2026, Branch `feat/vegetation-20261126`. Welche Verfahren die Vegetationsschicht nutzt, woher sie stammen (Vorgabe D-050) und was davon gemessen ist. Bau und Dateien: [art/vegetation/README.md](../../art/vegetation/README.md). Arten: [ARTENLISTE_VALDORA_58VC.md](ARTENLISTE_VALDORA_58VC.md).

Alle Zahlen stammen vom Entwicklungsrechner (Software-Renderer llvmpipe, Compatibility). Sie zeigen Verhältnisse zwischen Profilen, keine Geräteleistung. Auf dem Fold7 ist nichts gemessen.

## Verfahren und Quellen

| Thema | Umsetzung | Quelle |
|---|---|---|
| Wind an Bäumen | drei Ebenen im Vertex-Shader: Stamm biegt längenerhaltend, Äste wippen (Vertexfarbe R Gewicht, G Phase), Blattspitzen flattern (B); Phase und Steifigkeit je Instanz aus `INSTANCE_CUSTOM` | Sousa, „Vegetation Procedural Animation and Shading in Crysis“, [GPU Gems 3, Kap. 16](https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-16-vegetation-procedural-animation-and-shading-crysis) |
| Böenfeld | zwei Oktaven Wertrauschen, die mit dem Wind über die Landschaft wandern (Fronten etwa 30 m, 4,5 m/s; Wirbel 7 m/s). Jede Pflanze und jeder Grashalm liest dasselbe Feld an seinem Standort, deshalb laufen Böen sichtbar über Wiese, Feld und Kronen | Wohllaib, „Procedural Grass in Ghost of Tsushima“, [GDC 2021](https://gdcvault.com/play/1027214/); Rockenbeck, [„Blowing from the West“](https://gdcvault.com/play/1027350/Blowing-from-the-West-Simulating) |
| Gras aus Einzelhalmen | Halmbüschel als echte Geometrie ohne Textur und ohne Alpha-Test (22 Halme, 154 Dreiecke nah; 9 Halme, 27 Dreiecke fern), in 8-m-Zellen um die Kamera als MultiMesh; Höhe, Trockenheit und Deckung driften in Horsten (Rauschfelder der Ökologie); Halme weichen der Spielfigur aus | Wohllaib (wie oben): Halme je Kachel, Horstbildung, Wind aus scrollendem 2D-Rauschen; freie Nachbauten [GodotGrass](https://github.com/2Retr0/GodotGrass), [Unity-Grass](https://cainrademan.github.io/Unity-Grass/) |
| Instanzierung | `MultiMesh` je Art und Detailstufe, Zellen 32 m; Zeichenaufrufe hängen von den sichtbaren Arten ab, nicht von der Baumzahl | Godot-Dokumentation, [Optimization using MultiMeshes](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) |
| Blattkarten in der Ferne | Alpha wird mit der Mip-Stufe angehoben, damit Kronen in der Ferne nicht ausdünnen | Castaño, [Computing Alpha Mipmaps](https://www.ludicon.com/castano/blog/?p=1218); Wyman/McGuire, [Hashed Alpha Testing](https://research.nvidia.com/sites/default/files/pubs/2017-02_Hashed-Alpha-Testing/Wyman2017Hashed.pdf) (Problemstellung) |
| Kronen als Volumen | Blattkarten-Normalen zur Kronenoberfläche gebogen, Rückseiten behalten sie; gebackene Kronenverschattung in Vertexfarbe A; Durchlicht über `BACKLIGHT` | Sousa (wie oben) |
| Ferne Bäume | Impostor-Karte mit 8 gebackenen Ansichten (Albedo und Normalen), zur Kamera gedreht | gängiges Verfahren; oktaedrische Impostoren wären der nächste Schritt (siehe offene Punkte) |

Nicht übernommen: GPU-Compute für Halme (Compatibility hat keine Compute-Shader), Bézier-Halme je Vertex (hier feste Halmformen je Büschel, dafür ein Zeichenaufruf je Zelle).

## Profile

Werte in `prototype/assets/vegetation/vegetation_profiles.json`. Alle Profile setzen dieselben Bäume und Kollisionen; sie unterscheiden sich in Detail, Reichweite, Schatten, Windebenen und Dichte.

| | Leicht | Ausgewogen (Fold7) | Hoch | Ultra |
|---|---|---|---|---|
| Baum-LOD0 bis (14-m-Baum) | 10 m | 16 m | 26 m | 36 m |
| Impostor ab / bis | 80 / 170 m | 115 / 240 m | 160 / 290 m | 200 / 300 m |
| Schatten werfen | nein | bis LOD1 | bis LOD2 | bis LOD2 |
| Wind | nur Stamm, eine Sinusfront | Stamm, Äste, Blätter, Böenfeld | wie Ausgewogen | wie Ausgewogen |
| Kraut-/Feldkarten Dichte, Reichweite | 25 %, 20 / 55 m | 55 %, 36 / 80 m | 85 %, 55 / 130 m | 100 %, 75 / 160 m |
| Halmgras: Büschel je m², Reichweite | keines | 3, 12 m (leichtes Büschel) | 6,5, 26 m (volle Halme bis 10 m) | 12, 42 m (volle Halme bis 17 m) |

Ultra hat nach D-060 keine künstliche Dichtegrenze. Ob Ausgewogen auf dem Fold7 flüssig läuft, ist offen, bis dort gemessen wird; die Halmdichte von Ausgewogen ist deshalb vorsichtig gewählt.

## Offene Punkte

- Halmzellen werden in GDScript erzeugt (wenige je Bild). Beim schnellen Lauf über eine Ultra-Wiese kann das auf einem Telefon ruckeln; ein Hintergrund-Thread wäre der nächste Schritt. Nicht gemessen.
- Impostoren haben 8 Ansichten um die Hochachse. Von oben (Übersichtskamera) kippt die Karte nicht mit; oktaedrische Impostoren würden das lösen.
- Rinde und Blätter sind prozedural gemalt, nicht gescannt. Fotogrammetrie oder lizenzierte Scans würden Nahaufnahmen deutlich heben; das wäre eine Beschaffungsentscheidung.
- Die Halme werfen keine Schatten und empfangen den Baumschatten nur über die Sonnen-Schattenkarte des jeweiligen Profils.
