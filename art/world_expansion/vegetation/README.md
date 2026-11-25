# Vegetationsbausatz – Ulme, Zypresse und Lorbeer

Stand: 25.11.2026. Ergänzung für die neue Weltbauszene; die vorhandenen Eichen-,
Oliven- und Pinienquellen unter `art/landscape/` werden nicht ersetzt.

Die drei Modelle sind eigenständig erzeugte Spielstudien. Es wurden keine
Fremdmodelle, Fotografien oder Texturen übernommen. Die Artenbezeichnungen
beschreiben die gestalterische Richtung, keine vermessenen botanischen Exemplare
oder eine photogrammetrische Rekonstruktion.

## Tatsächlich erzeugte Dateien

| Modell | Dreiecke LOD0 / LOD1 / LOD2 | Größte Breite × Tiefe über alle LODs | Größte Höhe |
| --- | ---: | ---: | ---: |
| Feldulme | 59.934 / 12.988 / 3.638 | 8,39 × 8,30 m | 8,76 m |
| Zypresse | 50.136 / 11.208 / 2.720 | 2,22 × 2,17 m | 9,13 m |
| Lorbeergebüsch | 11.622 / 2.912 / 758 | 2,16 × 2,21 m | 1,96 m |

Die Zahlen stammen aus den tatsächlichen exportierten GLB-Accessors, nicht aus
einer geschätzten Objektzahl. [build_report.json](build_report.json) enthält alle
neun Dateien mit SHA-256, Bytes, Bounds, Windkanälen, Blatt- und Astzahlen.

- Bearbeitbare Blender-Quellen: `field_elm.blend`, `cypress.blend`, `laurel.blend`.
- Spielmodelle: `prototype/assets/world_expansion/vegetation/<name>_lod0.glb`,
  entsprechend `lod1` und `lod2`.
- Reproduzierbarer Generator: [`tools/world_art/vegetation.py`](../../../tools/world_art/vegetation.py).
- Der Generator erzeugt `textures/` lokal neu. Die Texturen sind vollständig in
  den Blender-Quellen und GLBs gepackt; die zusätzlichen PNG-Arbeitskopien werden
  nicht noch einmal versioniert.

Jedes Modell besteht aus einem Mesh mit genau zwei Materialoberflächen: Rinde und
Blattwerk. Stämme, Wurzeln, Gerüstäste und nahe Zweige sind echte räumliche Netze.
Die Blätter besitzen eine zugespitzte, leicht gebogene Geometrie. Sie benötigen
keine durchsichtigen Sprosskarten. Das Blattmaterial ist deckend und zweiseitig.
Dadurch bleibt die Blattsilhouette an die Geometrie gebunden.

Die Ulme besitzt geschwungene Hauptäste und räumlich verteilte Sekundärzweige.
Die Zypresse verwendet eine schmale, gestaffelte Krone. Das Lorbeergebüsch enthält
mehrere getrennte verholzte Triebe. Die Blattadern und die unregelmäßigen
Rindenplatten sind eigene Albedo-, Normal- und Roughness-Texturen.

## Maße, Materialien und Detailstufen

Blender verwendet Meter und Z als Hochachse. Der GLB-Export konvertiert nach Y-up;
der niedrigste exportierte Punkt liegt auf Y=0. Der Bodenpivot liegt unter dem
Stamm beziehungsweise der Strauchmitte. Eine Weltkollision gehört in die
Integrationsszene und ist kein Bestandteil dieser dekorativen GLBs.

Die Texturgröße sinkt mit der Detailstufe von 1.024 auf 512 und 256 Pixel je Seite.
Verkleinerte Normalmaps werden wieder auf Einheitslänge gebracht. Die Blattkarte
enthält vier Farbvarianten; UV-Ränder schützen vor dem Übergreifen zwischen den
vier Atlasfeldern. Das Quell-Blender enthält die nahen Materialien als gepackte
Bilder. Die GLBs enthalten Albedo, Tangentennormalen und gepackte Materialkanäle.

LOD1 reduziert Blattzahl, Blattflächen und feine Zweigsegmente. LOD2 behält Stamm,
Wurzeln und Hauptäste und verzichtet auf kleinste Holzsegmente. Größere, weniger
zahlreiche Blattflächen erhalten die Fernsilhouette. Das ist eine diskrete
Darstellungsumschaltung; ein lückenloser Übergang zwischen allen Detailstufen ist
damit nicht automatisch nachgewiesen. Die nahen Bäume sind für wenige nahe
Ansichten vorgesehen, nicht für eine gesamte Landschaft auf LOD0.

## Windvertrag

`COLOR_0` ist **kein Farbauftrag**. Der angeschlossene Windshader muss diese Daten
als Gewichte lesen und darf sie nicht mit der Texturfarbe multiplizieren.

| Kanal | Bedeutung |
| --- | --- |
| R | Gemeinsame, aus der Vertexhöhe abgeleitete Biegekurve; Boden und Wurzelspitzen sind verankert. |
| G | Blattflattern: Holz und Blattansatz 0, zur Blattspitze steigend. |
| B | Stabile Ast-/Blattphase; nur für den Flatteranteil verwenden. |
| A | Konstant 1. |

Die breite Baumbewegung verwendet eine gemeinsame Weltankerphase. Gleiche
Höhenkurve und gemeinsamer Sway verhindern unterschiedliche Verschiebungen an
Astansätzen. Die individuelle B-Phase gehört ausschließlich in den durch G
gewichteten Blattanteil. Das Material darf die Vertexfarben weder als Albedo
noch als Transparenz übernehmen.

Ein gewöhnlicher glTF-Viewer multipliziert Vertexfarben gemäß glTF-Semantik in
die Oberfläche und zeigt diese Daten daher als falsche Farben. Die Blender-
Quellen verwenden keine solche Farbverknüpfung. Für die Reviewbilder werden die
wirklichen GLBs wieder importiert und ihre Albedotexturen direkt verbunden,
entsprechend dem Albedopfad des Runtime-Windshaders. Geometrie, UVs und Texturen
werden dabei nicht ersetzt. Windanimation ist in den Standbildern nicht sichtbar.

## Prüfung und Reproduktion

```sh
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=2 blender --background --factory-startup --disable-autoexec -t 2 -P tools/world_art/vegetation.py -- --render --samples 24
```

Ein reiner Renderdurchlauf verwendet `--render-only`. Für die Texturerzeugung
werden NumPy und Pillow benötigt. Der Generator prüft die tatsächlich erzeugten
Dateien auf endliche Geometrie, zwei Oberflächen, eingebettete PBR-Texturen,
UVs/Normalen/COLOR_0, vollständig deckendes Alpha, fehlendes Holzflattern,
Y-up-Grundhöhe und strikt sinkende Dreieckzahlen. Bodenpunkte werden bei der
Geometrieerzeugung ausdrücklich mit R=G=0 verankert; der separate Integrations-
prüfer kontrolliert diesen Vertrag an den exportierten Bytes erneut.

Die Materialkappen sind explizit trianguliert, damit der Export auch Tangenten
für die Normalmaps berechnen kann. Die letzte Ausführung besitzt keine
Tangentwarnung. Die ursprüngliche und die zwischenzeitliche Ausführung bleiben
unter `review/blender_initial.log` und `review/blender_intermediate.log` als
vorherige Versuche erhalten; maßgeblich ist `review/blender_build.log`.

Die Reviewbilder sind tatsächliche Cycles-CPU-Renderings der wieder importierten
nahen GLBs mit zwei Threads, 24 Samples und ohne Denoiser:

- [Gesamter Bausatz](review/vegetation_overview.png)
- [Rinde und Astansatz der Ulme](review/elm_bark_closeup.png)
- [Lorbeerblätter und Verzweigung](review/laurel_leaf_closeup.png)

Der Engine-Import, dynamische Wind, Tag/Nacht und die Einbindung in die neue
Weltbauszene werden getrennt von dieser Asseterzeugung geprüft. Diese Lieferung
belegt keine neue Android-APK, keine Fold7-Bildrate und keine gemessene
thermische Dauerlast. Die spielerische Bevölkerungs- und Handelslogik wird durch
diese Pflanzen nicht verändert.
