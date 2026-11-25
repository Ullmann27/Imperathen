# Sichtprüfung der Vegetation

25.11.2026. Alle drei unten genannten PNGs wurden nach dem letzten erfolgreichen
Blenderlauf geöffnet und visuell betrachtet. Die Bilder zeigen wieder importierte
GLB-Geometrie, mit dem dokumentierten Ausschluss der Windfarben aus dem Albedo.

| Bild | Beobachtung |
| --- | --- |
| `vegetation_overview.png` | Alle drei Pflanzen vollständig im Bild. Ulme mit dünneren, gekrümmten Hauptästen und räumlicher verzweigter Krone; schmalere dichtere Zypresse; Lorbeer mit getrennten Trieben. Stämme und Blattsilhouetten erkennbar, echte Bodenschatten. |
| `elm_bark_closeup.png` | Rindenplatten, Mikrostruktur und Astansatz sichtbar. Die zuvor zu regelmäßigen parallelen Rillen wurden ersetzt. Keine einfarbige, untexturierte Stammfläche. |
| `laurel_leaf_closeup.png` | Einzelne Blattflächen, Mitteladern, Farbvarianten und feinere verholzte Triebe sichtbar. Die Blätter sind wirkliche Geometrie, keine geschlossene Kugel oder gekreuzte großflächige Krone. |

## Grenzen der erreichten Qualität

Die Ulme besitzt weiterhin eine relativ offene, erkennbar prozedurale Krone.
Ein sehr dichter natürlicher Altbaum mit organisch verschmolzenen Astgabeln ist
damit noch nicht erreicht. Die Rindenplatten sind eine eigene Materialstudie,
keine fotografisch belegte Ulmenrinde. In der sehr nahen Blattansicht sind die
polygonalen Umrisse sichtbar. Die Zypresse nutzt vereinfachte geometrische
Blattsprosse, keine vollständige botanische Rekonstruktion ihrer Schuppenblätter.

Die Lieferung ist als nutzbarer Spielbausatz und technische Wind-/LOD-Grundlage
geprüft. Sie wird nicht als photorealistischer oder abschließend freigegebener
AAA-Baumbestand ausgegeben. 24 Cycles-Samples ohne Denoiser lassen in Schatten
sichtbares Renderrauschen; das ist kein Godot-Texturfehler.

Die letzte Blenderausführung endete mit Exit 0 und ohne die Tangentwarnungen der
ersten Version. Die neun GLBs besitzen zwei Oberflächen, eingebettete PBR-Maps,
UVs und exportierte Winddaten. Die separat ausgeführte Godot-Prüfung und das
Zusammenspiel mit Wind und Tageslicht gehören zur gemeinsamen Integrations-
übergabe; diese drei Standbilder allein belegen keine Bewegung oder Android-FPS.
