# I-01: Frühstücksbrot

Der Eintrag `table_bread` steht bereits einmal in `HouseholdDesigns.items("baker_home")`. Nicht zusätzlich instanziieren. `prototype/assets/operation_prima/breakfast_bread.gd` baut das Brett, den Laib und drei Einschnitte als ein Mesh beim Laden des Einrichtungskits, nicht pro Bild. Die drei Oberflächen erhalten eigene raue Materialien durch `interior_kit.gd`; ihre lokalen UVs passen nicht zum gepackten Atlas der importierten Requisiten. Die Produktivansicht zeigte mit dem falschen Material ein fast schwarzes Brett.

Kein externer Asset-Import. Ursprung, Weltplatzierung, Spielstand und Manifest-Kollider bleiben gleich; 1.140 Dreiecke bei einem vorhandenen Budget von 1.184. Prüfung: `operation_prima_art_test.gd`. Die echte erste Tischeinstellung kann mit `operation_prima_table_capture.gd` wiederholt werden; Beispiel und Grenzen im [Produktionsbericht](../../docs/44_integration/OPERATION_PRIMA.md).
