# Figuren von IMPERATHEN

Die Figurengalerie im Hauptmenü zeigt 18 freigestellte Figurenbilder. Die persönliche Chronik zeigt die Spielfigur und ihren eigenen Gefährten bei der Ankunft im Dorf. Für den römischen Lebensweg gibt es zusätzlich die beiden erwachsenen Fassungen nach dem sechsjährigen Zeitsprung.

| Sammlung | Dargestellte Personen |
| --- | --- |
| Truppe und Hof | Legionär, Speerträger der Hilfstruppen, Bogenschütze, Zenturio, Feldzeichenträger und Kaiser |
| Jugend | Fünf Spielfiguren aus Italien, dem Gebiet östlich des Rheins, dem Weichselraum, den Östlichen Han und Wa der Yayoi-Zeit |
| Begegnungen | Marcus, Albrun, Lin, Aki und Mira |
| Nach der Ausbildung | Die erwachsene Hauptfigur aus Italien und Marcus |

Die sechs Original-PNGs unter [source/](source/) wurden für diesen Entwicklungsblock mit OpenAI ImageGen erstellt. Drei Originale enthalten jeweils sechs Figuren. Legionär, Kaiser und die erwachsene römische Hauptfigur wurden zusätzlich als einzelne Bilder mit 1.024 × 1.536 Pixeln erzeugt. Die Spielbilder besitzen echte Alphakanäle. Waffen, Kleidung und Gesichter sind künstlerische Interpretationen für die Zeit um 100 n. Chr. Der Kaiser ist eine an Trajans Zeit angelehnte Darstellung. Meshy wurde für die Bilder nicht verwendet.

[Legionär](../../prototype/assets/portraits/legionary.webp) · [Kaiser](../../prototype/assets/portraits/emperor.webp) · [Hauptfigur aus Italien](../../prototype/assets/portraits/adult_italia.webp) · [Alle freigestellten Spielbilder](../../prototype/assets/portraits/) · [Produktionsprompts](prompts.json)

Vom Repository-Stamm exportiert `python3 art/portraits/package.py` die 18 WebP-Dateien mit Pillow verlustfrei aus den erhaltenen Originalen. Das Werkzeug schneidet die transparenten Bilder einzeln zu und fügt acht Pixel transparenten Rand an. Godot lädt das ausgewählte Bild bei Bedarf. Die [animierten taktischen 3D-Modelle](../soldiers/README.md) haben eigene Geometrie und Rigs. Ihr Aussehen aus der Nähe ist in den [Blender-Mehransichten](../landscape/meshy/README.md) dokumentiert.
