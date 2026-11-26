# Valdoras Osttor und die Route zum Alten Steinbruch

Die Regionalübersicht markiert die 1.780,99 m lange Trasse vom Osttor (46 / −13 m) zum Atlasanker des Alten Steinbruchs (1500 / −750 m). Am Tor führt ein sichtbarer 44 m langer Erdweg über den bestehenden Dorf- und Kollisionsboden. Dahinter geht die Trasse über die bereits gestreamten Geländezellen. Die Regionalkarte zeigt ihren Verlauf und bezeichnet den Steinbruch als geplanten Zielort.

Valdora ist die bewohnte Einstiegssiedlung dieser Geländewelt. Die Aquileia-Inszenierung der Einleitung und die Rom-Stadtansicht verwenden eigene Szenen. Die vorhandenen Atlasorte stellen keinen durchgehenden Weg zwischen diesen Städten bereit.

## Messung in Godot 4.7.2

| Durchgang | Geschwindigkeit | Nominell aus Trassenlänge | Gemessene Physikzeit | Zurückgelegte Strecke |
| --- | ---: | ---: | ---: | ---: |
| Gehen mit dem vorhandenen Spielercontroller | 1,45 m/s | 20:28,27 min | 20:39,33 min | 1.780,78 m |
| Kollisionskapsel im Reittempo | 2,90 m/s | 10:14,13 min | 10:17,35 min | 1.780,58 m |

Beide Durchgänge erreichen alle neun Wegpunkte, bleiben über neun Sektorwechsel am Boden und enden weniger als 20 cm vom Zielpunkt entfernt. Das Reittempo ist ein Richtwert für die Geländephysik. Es verwendet dieselbe Kapsel mit einer festen Zielgeschwindigkeit. Für die Gehzeit sind Beschleunigung, Steuerung und Gelände bereits berücksichtigt.

Die Zeiten zählen Spiel-Physikschritte. In der Kindheit läuft die technische Simulationszeit während des Spielens mit. Der historische Kalender schreitet in diesem Abschnitt bei erzählten Ereignissen fort. Der Test verwendet einen frischen Zustand ohne Speichern.

```sh
IMPERATHEN_ISOLATED_TEST=1 godot --headless --path prototype --fixed-fps 60 --script res://tests/regional_footpath_test.gd
IMPERATHEN_ISOLATED_TEST=1 godot --headless --path prototype --fixed-fps 60 --script res://tests/regional_terrain_test.gd
IMPERATHEN_ISOLATED_TEST=1 godot --headless --path prototype --fixed-fps 60 --script res://tests/regional_worker_test.gd
python3 -m unittest discover -s tools/world_art -p test_regional_routes.py
```
