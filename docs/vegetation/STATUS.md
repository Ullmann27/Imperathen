# Status Vegetation Valdora (26.11.2026, Abbruch auf Anweisung)

**Umgesetzt:** Artenliste mit Quellen; prozedurale Texturen; Blender-Bau von 17 Baum-, Strauch- und Rebenmodellen mit LOD0–3, Kraut-/Feldkarten und Halmbüscheln; Windshader mit Böenfeld und Variation je Instanz; MultiMesh-Schicht; ökologische Platzierung über die gemeinsame Land-Maske (`valdora_land.gd`, Kopie vom Terrain-Branch); Halmgras um die Kamera; Budgets je Profil.

**Getestet:** `tests/vegetation_test.gd` headless, 261 Prüfungen, 15 Fehler. Alle 15 sind die Impostor-Prüfungen: Der Cycles-Bake ist nie gelaufen, es gibt keine Impostor-Texturen. Der Lauf fand vor der letzten Budgetänderung (Ausgewogen `grass_near_m` 0) statt.

**Nicht getestet:** die übrige Regression. `main_scene` schlug einmal fehl, wegen veralteter Import-Caches der Frontier-Figuren im Worktree; nach dem Neuimport nicht erneut gelaufen.

**Nicht gerendert:** Es gibt kein einziges Godot-Bild, weder vorher noch nachher, und keine Windsequenz. Die Shader sind im Spiel ungesehen; Aussage zur Bildqualität ist nicht möglich. Keine Polygon-/Instanzzahlen aus dem Spiel, nur aus dem Headless-Test.

**Nächste Schritte:** Impostor-Bake (`blender -b -P art/vegetation/build.py`, Heavy-Lock, in Gruppen), `tests/vegetation_review.gd` vorher (89e735d) und nachher je Profil, `art/vegetation/evidence.py`, volle Regression, Fold7-Messung.
