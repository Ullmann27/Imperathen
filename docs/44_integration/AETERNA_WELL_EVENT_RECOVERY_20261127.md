# Aeterna · I-01-Export und Stadtereignisse (27.11.2026)

Basis: b13be32c0ef7d476f9fb9aaf69b0375f511543bc, PR #156. Die echten GitHub-Logs
https://github.com/Ullmann27/Imperathen/actions/runs/45987590381
und https://github.com/Ullmann27/Imperathen/actions/runs/45987590141
zeigen einen fehlenden Brunnen-Mesh-Vertrag (1/236) und einen fehlgeschlagenen
Stadtereignis-Test (1/107), obwohl 1801 Käufe und 65 Lieferungen gebucht wurden.

- Blender: statische Geometrie bleibt nach Material gebündelt. Die originalen
  beweglichen Eimerteile, Seil, Windenachse, Seilanschläge, Wicklung und Kurbel
  bleiben einzeln benannt. Das bisherige GLB hatte zehn Material-Batches; die
  Laufzeit sucht echte benannte Meshknoten. Kein Ersatzmodell.
- Godot: Bindung kontrolliert die tatsächlich aktuelle Brunneninstanz sowie
  lebende Bauteile. Ein unterbrochener Windenablauf stellt Originaltransforms
  wieder her. Kein fingiertes `well_visual_bound`.
- Stadt: 320 Ereignisse sind ein flüchtiger Ringpuffer. Der Test beobachtet
  die gesamte 36h budgetierte Simulation über die öffentliche Sequenzschnittstelle;
  keine Lücken und Kaufereignisse genau entsprechend der autoritativen Kaufzahl.
  Ununterbrochener Lauf, Zustands-Hash, Save/Load und Wirtschaftsprüfung bleiben.
- Der reguläre 09:00-Start und die gemeinsame Wetterberechnung sind bereits
  vorhanden (`local_weather_test.gd`); sie werden hier nicht dupliziert.

Neue Blender-/Godot-Läufe sind erst nach CI-Ergebnis belegt. Keine visuelle
Fold7-Freigabe, keine APK-Veröffentlichung, kein Merge nach main.
