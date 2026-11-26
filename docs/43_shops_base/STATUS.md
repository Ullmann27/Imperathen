# Stand Ausrüstungsläden und Meshy-Modelle (26.11.2026, Abbruch auf Anweisung)

**Geprüft**
- Meshy-Bestand: 58 Text-zu-3D- und 43 Bild-zu-3D-Aufträge gelistet, 38 Quellen geladen und in `lock.json` gesperrt; 0 Credits verbraucht. `python3 -m unittest tests.android_meshy_asset_test`: 6 Tests OK.
- Blender-Bau aller 43 Laufzeit-GLBs (12.481.912 Bytes) lief durch; Godot-Import `--import`: Exit 0.
- `gear_market`: 443 Prüfungen, 5 Fehler, alle aus einer Ursache (Zusatzfeld `uid` im gespeicherten Befehlsergebnis). Die Korrektur ist eingecheckt, der Wiederholungslauf wurde **nicht** mehr ausgeführt.

**Nicht geprüft**
- `gear_visuals` (kein Ergebnis), die bestehenden Gruppen `city_trade`, `commerce_transaction`, `city_market_bridge`, `city_inventory_ui`, `meshy_registry`, `service_gear`, `meshy_equipment` nach den Eingriffen in `world_model.gd`, `city_trade.gd`, `village_person.gd`; das Bewegungsgate.
- Keine Godot-Renders. Die Modelle wurden nur in einer Software-Vorschau der GLB-Dateien angesehen.

**Offen**
- Kein Laden ist im laufenden Spiel bedienbar: `gear_sites` wird von keiner Szene gesetzt, Stadtpanel und HUD senden die Befehle nicht.
- Reiterschild nur mit Nahstufe; Rohstoff-Requisiten unter 512 px/m; Scutum-Fernstufe mit einem Fehl-Dreieck.
- Zurückgehalten mit Grund: Bogen, Armbrust, Hörnchensattel, Galena, Muskelpanzer, Caesar, Tempel (`ASSET_LEDGER.md`).

**Nächste Schritte:** `python3 tools/check_prototype.py --only gear_market gear_visuals city_trade commerce_transaction city_market_bridge city_inventory_ui meshy_registry service_gear meshy_equipment`, danach `tests/gear_review.gd` für die Renders.
