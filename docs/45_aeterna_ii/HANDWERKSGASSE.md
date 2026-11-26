# Handwerksgasse am Forum

Die Handwerksgasse ist ein 26 m langer Abschnitt der bestehenden freien Stadterkundung. Sie liegt östlich von deren Startpunkt. Auf der Ostseite stehen Schmiede und Taberna mit eigenen Eingängen. Gegenüber stehen ein zweigeschossiges Stadtwohnhaus mit Laden und die Wasserstelle auf einem gepflasterten Absatz. Der Straßenkörper enthält einzeln geformte Basaltsteine, eine gewölbte Fahrbahn, zwei Wagenspuren, Gehsteige und Trittsteine. Kanten, Sandfugen und Kies liegen in getrennten Meshes. Die vier Grafikprofile behalten dieselben Gebäude, Interaktionen und Kollisionsflächen. Das Profil Leicht blendet nur den Kies des neuen Straßenabschnitts aus.

Am Tresen lässt sich eine Wachstafel lesen. Ihre Warenliste gehört als Umgebungsdetail zur freien Stadterkundung. Die Aktion ist auf Sichtkontakt und Reichweite beschränkt. Sie verändert weder das Inventar noch die Kindheitsgeschichte.

## Modellquellen

- `prototype/assets/roman_quarter/paving/source/paving.blend` enthält die Geometrie und gepackte Farb-, Normal- und Rauheitskarten. Der Seed, die SHA-256 und die Dreieckszahlen stehen in `prototype/assets/roman_quarter/paving/metrics.json`.
- `prototype/assets/roman_quarter/workshop/source/roman_workshop.blend` enthält beide eingerichteten Räume. Das Haus gegenüber liegt in `prototype/assets/roman_quarter/workshop/source/roman_narrow_domus.blend`. Die Kollisionshüllen beider Bauten haben getrennte GLBs.
- `tools/world/fontana.blend` und `tools/world/wax_tablet.blend` sind die Blender-Quellen der Wasserstelle und der aus Holz, Wachs und Griffel aufgebauten Tafel.

Das Ensemble ist ein eigener römischer Straßenzug. Gewölbte Pflasterung, Bordsteine und die Anordnung von Trittsteinen stützen sich auf Befunde aus Pompeji. Die erhaltenen Straßen dokumentieren mehrere Bauphasen. Sie dienen als Vergleich für die Bauweise eines republikanischen Schauplatzes. [Paving Pompeii, American Journal of Archaeology](https://ajaonline.org/article/3761/) · [Architecture of the Street, Oxford University Press](https://academic.oup.com/book/7089/chapter-abstract/151593483)

## Reproduktion mit Blender 4.3.2 und Godot 4.7.2

```bash
blender -b -t 6 --python-exit-code 1 \
  --python tools/world/build_roman_quarter_paving.py -- --output /tmp/paving --render

blender -b -t 6 --python-exit-code 1 \
  --python tools/world/build_roman_test_city.py -- --output /tmp/roman-city
cp /tmp/roman-city/imperathen_roman_test_city.glb prototype/assets/world/roman_city_test.glb
cp /tmp/roman-city/roman_city_collision.glb prototype/assets/world/roman_city_collision.glb

godot --headless --path prototype --editor --import
godot --headless --path prototype --fixed-fps 60 --script res://tests/roman_quarter_test.gd
godot --headless --path prototype --fixed-fps 60 --script res://tests/roman_city_real_walk_test.gd
godot --path prototype --script res://tests/roman_quarter_capture.gd -- /tmp/roman-quarter-captures
```

Beim lokalen Spieltest steigt der Spieler vom Forum auf die Straße, passiert alle vier Türen mit normaler Bewegung, wird an Fassadenwand und Trog aufgehalten und kann die Tafel am Tresen öffnen. Ein Modellfehler an der Gehwegkante wurde über die begehbare Bordsteingeometrie der Kollisionsfläche korrigiert. Die Screenshots entstanden in der regulären Stadtszene mit eingefrorener Kamera in Godot Compatibility unter llvmpipe. Die Prüfungen belegen lokale Engine-Funktion und zeigen den Stand der Grafik. Leistungswerte für Fold7 und RTX 3050 Ti fehlen.

## Abgleich zur Übergabe von PR #101

Auf `625316b17d134e7c658c5de7349129891da6b9b3` bestehen Import sowie `raid_route_world_c` (22), `raid_strike_timing` (59), `village_experience` (224), `tribal_save` (41), `landscape` und `camera_collision` (48, ohne Leckmeldung). Der Lauf verwendete die vorhandenen privaten Originaljungen-Dateien und die neu exportierte Stadt. Er ist ein gezielter Wiederholungslauf. [Älterer Volllauf auf 7f46fa0](https://github.com/Ullmann27/Imperathen/pull/101#issuecomment-7188089076)

Die Regel `82af7cd` ändert die Zuordnung von Skripten zum Bewegungsinventar. Im A/B-Test auf demselben Baum entfallen auf `f770025` zehn Inventarbefunde. Dieselbe Regel stuft in Gegenproben dynamischen Property-Zugriff und indirekte Node3D-Vererbung zu weitgehend als Datenlogik ein. Eine automatische Ausnahme für diese Runtime-Skripte ist als Freigabenachweis verworfen. Inventarbefunde und gemessene Motion-Verstöße bleiben getrennt. Der Wiederholungslauf enthält keine vollständige Bewegungsabnahme.
