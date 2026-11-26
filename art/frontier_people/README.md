# Figuren für die lebendige Grenzsiedlung

Diese Serie erweitert die vorhandene anatomische Hero-Basis um sieben erwachsene
Figuren. Sie ersetzt die Italia-Hauptfigur nicht. Die Blender-Dateien sind die
bearbeitbaren Quellen; im Spiel werden die exportierten GLBs verwendet.

## Inhalt

| Kennung | Eigene Merkmale | Rig und Bewegung |
| --- | --- | --- |
| `civilian_man` | Ockerfarbene Tunika, männliche Hauttextur, breite Kieferform | 15 Gelenke; 11 bestehende Hero-Clips |
| `civilian_woman` | Schmalerer Oberkörper und Kiefer, langes gefälteltes Kleid, gebundene Haare | Angepasste 15-Gelenk-Ruhepose; 11 Hero-Clips |
| `elder` | Breitere untere Gesichtskontur, graues Haar, kleiner Kinnbart, gedeckte Tunika | 15 Gelenke; 11 Hero-Clips |
| `legionary` | Stahlbänderpanzer, Helm, rotes Scutum, Gladius, Nieten und Lederriemen | Bestehendes 15-Gelenk-Kompanie-Rig; 11 Kampf-Clips |
| `officer` | Bronzevariante, Querbusch, Mantel, eigener Schild | Dasselbe bewährte Kompanie-Rig |
| `spearman` | Speer, grüner Rundschild, Rüstung und Helm | Dasselbe bewährte Kompanie-Rig |
| `archer` | Bogen, Pfeil, Köcher und Wollkappe; anatomischer Körper | Bestehendes 17-Gelenk-Rig einschließlich Nocke/Pfeil |

Die Ausrüstung bleibt eine stilisierte römische Studie des Projekts. Die Modelle
sind keine archäologisch geprüfte Rekonstruktion und keine neuen Körperscans.
Frauen- und Altersmerkmale wurden auf der vorhandenen Basis ausgearbeitet. Diese
erste Serie ersetzt keine spätere individuelle Gesichts- und Haarproduktion.

## Herkunft und Bearbeitung

Die vorhandene CC0-Grafikbasis stammt aus dem MakeHuman-Repository, Revision
`a8bc2d54ff0ac92e78ff71431b1023eda42bf482`. Maßgeblich bleiben die bereits
vendorten Lizenzbelege und Hashes in
[`../hero_quality/source/provenance.json`](../hero_quality/source/provenance.json)
sowie dessen verwiesenem System-Assets-Manifest. Es wurde kein MakeHuman-Programmcode
übernommen und für diese Serie nichts heruntergeladen.

Anatomie, Haut- und Haar-UVs werden aus `art/hero_quality/hero.blend` abgeleitet.
Die männliche Hauttextur stammt ebenfalls aus dem bereits vorhandenen,
nachgewiesenen CC0-Bestand. Die neuen geometrischen Änderungen, Farben,
Leinenmuster, Iristextur und Rüstungsdetails erzeugt
`tools/characters/build_frontier_people.py`. Ausrüstung und Kampfanimationen
verwenden die eigene Projektquelle `art/soldiers/build.py`.
[`provenance.json`](provenance.json) verknüpft die Quellen und deren SHA-256-Hashes.

Der Erwachsene-Morph wird vor der Bearbeitung in die Geometrie eingerechnet.
`Mature` und `Companion` sind deshalb in diesen erwachsenen Figuren nicht mehr
schaltbar. Blinzeln links/rechts, Mundöffnung, Lächeln und Stirnspannung bleiben
auf LOD 0 und 1 als echte deformierende Morphs erhalten. Die transparente äußere
Augenschale wird entfernt; die darunter liegende Irisfläche nutzt einen eigenen
opaken Atlas und benötigt keinen transparenten Zeichenpass.

Die Anatomie der Soldaten wird auf die bestehende Kompanie-Ruhepose angepasst.
Die getesteten Gelenkpositionen, Gangzyklen, Schildposen und der Schussablauf
bleiben erhalten. Das Gewand wird in die Rüstung eingepasst. Die Hauptfigur und
deren Originalexporte bleiben unverändert.

## Detailstufen und Materialnutzung

Jede Kennung hat vier GLBs. Texturkanten sind auf 1024/512/256/128 Pixel begrenzt.
Die exakten Dreieckszahlen, Bytegrößen und Exporthashes stehen in
[`build_report.json`](build_report.json). Die aktuellen Modelle liegen in der
Nähe bei etwa 18.300–20.400 Dreiecken; die niedrigste Stufe bei unter 900.
Die beiden fernen Stufen enthalten keine Gesichtsmorphs.

Die GLBs enthalten ihre Texturen bereits. Godot extrahiert beim ersten Import
zusätzliche `frontier_*.png` samt Importmetadaten. Diese abgeleiteten Arbeitsdateien
müssen nicht zusätzlich versioniert werden; ein sauberer Editor-/CI-Import
erzeugt sie aus den GLBs. Der Android-Export erfolgt anschließend aus den
importierten Ressourcen.

`VillagePerson.configure_appearance(id, variation)` wählt die Figur. Bei
Bewohnern kombinieren die Varianten sechs Gewandfarben und Körperhöhen mit drei
Haarfarben. Identität und Mimik bleiben deterministisch. Importierte Meshes
werden geteilt; Farbänderungen erhalten eigene Materialinstanzen. Die Varianten
ändern niemals das Quellmaterial eines Nachbarn. Nicht mehr verwendete
Materialvarianten werden nur schwach im Cache gehalten, damit ihre Texturen
freigegeben werden können.

Für Bewohner liegen die Distanzgrenzen bei 6/15/30 Metern, multipliziert mit
dem Faktor des gewählten Grafikprofils: 0,55 / 0,86 / 1,15 / 1,5.
Nah am Spieler und in Gesprächen bleibt die feinere Anatomie sichtbar. Kinder
verwenden weiterhin ihre bisherige Altersroute. Eine unbekannte Kennung fällt
auf das vorhandene Bewohner-Modell zurück.

`SoldierVisual` verwendet die neue Anatomie für die nahen und mittleren Stufen
aller vier Kampfrollen. In der Ferne bleiben die vorhandenen kleinen,
instanzierten Kompanie-Meshes erhalten. Damit erzeugt die neue Anatomie keine
voll animierten Figuren für jeden weit entfernten Soldaten.

## Reproduzieren und prüfen

```sh
blender -b -t 3 -P tools/characters/build_frontier_people.py -- --export
blender -b -t 2 -P tools/characters/build_frontier_people.py -- --review-only
python3 tests/frontier_exports_test.py --report
godot --headless --editor --path prototype --import
godot --headless --path prototype --script res://tests/frontier_people_test.gd
python3 art/frontier_people/capture_runtime.py
```

`frontier_exports_test.py` liest die tatsächlichen GLB-Bytes. Es prüft die
Geometrie- und Texturbudgets, streng sinkende Detailstufen, normierte
Skin-Gewichte, Gelenklisten, bewegte Animationskanäle, echte Gesichtsdeltas und
die Exporthashes. Sein Prüfbeleg ist [`validation.json`](validation.json).
Ein bestandener Dateitest bestätigt allein keine sichtbare Qualität.

`frontier_people_test.gd` prüft den echten Godot-Import, die Auswahl der neuen
Figuren, die erhaltene Animationsphase beim LOD-Wechsel, bewegte Gelenke, die
Mimik, unabhängig gefärbte Bewohner, alle vier Grafikprofile und die
Kompanie-Anbindung. Zusätzlich bleiben die bestehenden Soldaten-, Gang- und
VillagePerson-Tests relevant.

Die Bilder in `review/` sind echte Blender-Studioaufnahmen der gespeicherten
Modelle. `runtime_review/` enthält echte Godot-Viewport-Aufnahmen des produktiven
`VillagePerson` in einer isolierten Studioumgebung samt Metadaten und Hashes.
Beide Reihen sind **keine Aufnahmen des belebten Dorfs**. Die vollständige
Spielszene und die Android-Prüf-APK werden im übergeordneten Durchgang geprüft.
Es wird keine gemessene Android-Bildrate oder thermische Stabilität behauptet.

## Individuelle Bewohner (Identitätsschicht)

Die drei zivilen Exporte (`civilian_man`, `civilian_woman`, `elder`) erhalten
nach dem Export zusätzlich die Identitätsschicht aus
[`../village_characters/build_resident_identity.py`](../village_characters/build_resident_identity.py):
Gesichts- und Körperformen als Morphs, Haar-, Bart- und Kleidungsteile,
neutrales Leinen für echte Färbungen. `build_frontier_people.py` ruft diesen
Schritt bei zivilen Exporten selbst auf. Die Bewohner wählen ihr Aussehen über
`scripts/visuals/resident_identity.gd`; die frühere reine Farbvariation gilt
nur noch als Rückfall. Einzelheiten in
[`../village_characters/README.md`](../village_characters/README.md).

## Noch offene sichtbare Grenzen

Haare und Kinnbart sind eine vereinfachte erste Ausarbeitung. Gesicht und Hände
haben noch keine individuelle Detailmodellierung je Dorfbewohner. Die Stoffe
nutzen Hautgewichte statt einer Stoffsimulation; insbesondere beim langen Kleid
bleiben extreme Lauf- und Kampfposen ein eigener visueller Abnahmepunkt.
Die Ausrüstung wurde an Körper und bestehende Animationen angepasst, aber nicht
für jede mögliche Kampfkontaktpose einzeln künstlerisch abgenommen.
