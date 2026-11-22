# Bäume, Siedlungen und Freisteller

Sämtliche Geometrie, Texturen und Posen dieser Studie sind für IMPERATHEN lokal erzeugte Originale. Die Bäume und Bauten haben eigene Blender-Quellen. Der erwachsene Feldarbeiter verwendet den im selben Repository erstellten Figurenkörper mit eigenem Gewand, Gürtelbeutel, Hut und Feldhacke. Es wurden keine fremden Modelle, Fotografien oder Texturen eingelesen. Die regionale Zuordnung bezeichnet eine gestalterische Annäherung. Eine Vermessung archäologischer Einzelbauten oder botanischer Referenzexemplare liegt nicht vor.

## Transparente Qualitätskontrolle

Die Platten zeigen echte Blender-Cycles-Renderings der wieder importierten Spiel-GLBs. Unter `review/` liegt auch jede Figur, jedes Gebäude und jeder Baum einzeln als beschnittenes RGBA-PNG. Jedes Bild besitzt vollständig transparente und vollständig deckende Pixel. Die Größen der Motive auf den Platten dienen der Einzelprüfung und bilden keinen gemeinsamen Maßstab ab.

- [Schweres Fußvolk, Speerträger, Bogenschütze und Offizier](review/soldiers.png)
- [Drei Feldarbeiter mit gemeinsamer Originalfigur und unterschiedlicher Arbeitskleidung](review/workers.png)
- [Römisch inspiriertes Grenzhaus, Brunnen und Atriumhaus](review/roman.png)
- [Pinie, Olive und Eiche](review/trees.png)
- [Han-Haus, Wa-Speicher, Wa-Wohnhütte, mitteleuropäisches Langhaus und Feldarbeiter](review/settlements.png)

## Gerüst und Blattwerk

| Art | Silhouette | Dreiecke nah / mittel / fern |
| --- | --- | --- |
| Pinie | Hoher freier Stamm, Schirmkrone, einzelne Nadelbüschel | 30742 / 9586 / 1762 |
| Olive | Verdrehter geteilter Stamm, silbrige lanzettliche Blätter | 29654 / 10074 / 1776 |
| Eiche | Breite Krone mit gestaffelten Gerüstästen und gelappten Blättern | 36222 / 11258 / 2054 |

Die Stämme, Astgabeln und nahen Endzweige sind räumliche Meshes. Die Krone setzt sich aus gebogenen Sprossflächen mit gezeichneten, ausgeschnittenen Einzelblättern beziehungsweise Nadeln zusammen. Jeder Baum verwendet eine Rinden- und eine zweiseitige Alpha-Masken-Oberfläche. Die Anzahl pro Export steht in [metrics.json](metrics.json). Der lokale Generator schreibt die Rinden- und Sprosstexturen in die Blender-Quellen und GLBs. Die Darstellung ist statisch.

`grove.gd` instanziert bis zu neun MultiMesh-Gruppen, eine je Art und aktiver Detailstufe. „Ausgewogen“ zieht die Grenzen bei 17 und 52 Metern, „hoch“ bei 28 und 76 Metern. „Niedrig“ beginnt mit der mittleren Stufe und schaltet bei 24 Metern auf fern. Entfernungen werden im lokalen Koordinatensystem des unskalierten Hains geprüft. Die Wahl der Darstellung beeinflusst das Spielmodell nicht.

Die römische Vergleichsplatte nutzt die echten Projektquellen der Integrationslinie. Grenzhaus und Brunnen stammen aus der Architekturstudie von PR #21 unter [art/visual_benchmark](../visual_benchmark/README.md). Das Atriumhaus stammt aus [art/architecture/build_atrium.py](../architecture/build_atrium.py). Der Freistellerjob lädt die drei GLBs aus `prototype/assets/architecture/`.

## Regionale Bauteile

| Asset | Rolle und Geometrie |
| --- | --- |
| han_house | Han-inspirierter Holzständerbau auf Erdplattform mit Steinabschluss, Säulenvorbau, drei Fassadenfeldern, Gitterfenstern und einfachem abgewalmten Ziegeldach. |
| wa_store | Yayoi-inspirierter erhöhter Vorratsspeicher mit sechs Tragpfosten, Nagetiersperren, Bretterboden, Zugang über eine Leiter und steilem Strohdach. |
| wa_house | Yayoi-inspirierter Wohnbau mit niedrigem Walmdach aus Stroh, vier Innenpfosten, überdecktem Eingang und tiefer liegendem Innenboden. Der erhöhte Erdrand bildet die Grube relativ zur durchgehenden Geländefläche ab. |
| wood_longhouse | Mitteleuropäischer Langhausentwurf mit Pfostenreihen, Lehmgefachen, sichtbarer Flechtwerkstelle, seitlichem Eingang und tiefem Strohdach. |
| farmer | Erwachsener Feldarbeiter mit einfachem Leinengewand, Hut und Hacke. Die Clips idle und march sind auf dem 15-Knochen-Rig abspielbar. |

Die Varianten `han_farmer` und `wa_farmer` nutzen denselben Körper und dieselben beiden Arbeitswege-Clips. Der Han-Entwurf besitzt überlappende Jackenkanten, Hose, Beinwickel und Kopftuch. Der Wa-Entwurf verwendet Gürtel, Haarband, Schultergurt und einen hölzernen Grabstock mit breitem Blatt. Diese Gewänder sind Spielentwürfe. Die Gebäude besitzen echte Türöffnungen. Ihre GLBs liefern sichtbare Gebäudestrukturen mit Bodenpivot in Metern. Spielkollision und Gebäudeinteraktion liegen in der jeweiligen Integrationsszene. Die PBR-Atlasmaterialien der Gebäude benötigen je eine Oberfläche. [Dreieckzahlen und Dateigrößen](settlement_metrics.json)

## Reproduktion und Prüfung

Vom Repository-Stamm aus mit Blender 4.3.2 und Godot 4.7.2 ausführen. Die Blender-Python-Umgebung benötigt Pillow und NumPy für die Texturerzeugung.

```sh
blender -b -t 2 -P art/landscape/build.py
blender -b -t 2 -P art/landscape/build_settlements.py
blender -b -t 4 -P art/landscape/render_cutouts.py -- soldiers trees settlements workers roman
godot --headless --path prototype --import
godot --headless --path prototype --script "$PWD/art/landscape/verify.gd"
```

Die Godot-Prüfung lädt die neun Baum-GLBs, prüft sinkende Dreieckzahlen, Alpha-Scissor und zwei Oberflächen, instanziert alle neun Gruppen, schaltet die Qualität und entfernt alle Bäume. Sie lädt außerdem die vier regionalen Gebäude und drei Feldarbeiter und prüft die tatsächliche Animationswiedergabe der Arbeiter. Gerätebildzeiten hängen von Blickrichtung, Alpha-Überdeckung, LOD und Anzahl sichtbarer Bäume ab.
