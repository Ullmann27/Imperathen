# B2 – WORLD: verlässliche Geländewechsel

Stand: 24. November 2026. Arbeitsblock M4 auf Basis von `7a21dca5dad83bf637cfbe9c02f4d9ab5cd97337` (PR #53), Branch `feature/team-b-living-world-20261124`.

## Anlass und Ergebnis

Der vorhandene Stream begrenzte neu erzeugte Geländesektoren bereits auf zwei pro Aufruf. Die Hochstufung bereits vorhandener Sektoren erzeugte ihre Trimesh-Kollisionskörper dagegen ohne eigenes Arbeitsbudget. Bei der Umstellung von `low` auf `very_high` konnten so viele Collider im selben Aufruf entstehen. Außerdem besaß `low` ausschließlich im Sektor des Körpermittelpunkts einen Boden; unmittelbar vor einer Zellgrenze fehlte die physische Nachbarfläche. Die vorhandene Körperprüfung über eine Naht deckte nur `balanced` ab.

`regional_terrain.gd` verwendet nun getrennte Grenzen für neue Geometrie, neue Trimesh-Kollision und das Freigeben auslaufender Sektoren. Der aktuelle Spielerboden und unmittelbar benachbarte Bodenflächen werden vor anderen Anforderungen bearbeitet. Auf `low` werden innerhalb eines Meters von einer Zellkante ein oder bis zu drei Nachbarcollider bereitgestellt. Dies verändert weder die feste Geländegeometrie noch Weltkoordinaten, Bewohner-IDs, Missionen, Spielstände oder Grafikprofile.

## Laufzeitvertrag

Die vorhandene Schnittstelle `follow(position: Vector3, quality: String)` bleibt erhalten. `game_world.gd` ruft sie bereits einmal pro Physikschritt auf; eine neue Anbindung ist nicht erforderlich.

| Bereich | Vertrag |
|---|---|
| Neue Gelände-Meshes | Höchstens zwei je `follow` |
| Neue Trimesh-Kollisionskörper | Höchstens zwei je `follow`, einschließlich Hochstufungen vorhandener Meshes |
| Freigegebene Sektoren | Höchstens acht je `follow` |
| Aktueller Spielersektor | Erste Mesh- und Collideranforderung |
| Randvorhaltung | Bis zu vier unterstützte Zellen am Körper; nur `low` benötigt dadurch zusätzliche Collider außerhalb seines normalen Nahbereichs |
| Normaler Kollisionsumfang | Unveränderte Nahbereiche für `balanced`, `high`, `very_high`; `low` abseits von Kanten weiterhin ein Collider |
| Maximale Sektorresidenz | 145 Sektoren, entsprechend der größten vorhandenen Profilanforderung |
| Profilverkleinerung | Alte sichtbare Sektoren laufen budgetiert aus; die niedrigere gewünschte Grenze wird erst nach Abschluss erreicht |
| Veraltete Physik | Nicht mehr benötigte Kollisionskörper werden sofort entfernt; auslaufende Grafik behält keine veraltete Kollision |
| Erneuter Orts-/Profilwechsel | Veraltete Anforderungen werden verworfen und die noch residenten Sektoren gegen das neue Ziel abgeglichen |
| Gleiche Anforderung | Bestehende Nodes, Meshes und weiterhin benötigte Collider werden wiederverwendet |
| Ungültige Koordinaten | Aktueller Zustand bleibt unverändert |
| Unbekanntes Profil | Wird vor dem Änderungsvergleich zu `balanced` normalisiert |

Die Collider-Freigabe und die Prüfung der höchstens 145 residenten Sektoren sind weiterhin synchron. Das neue Budget begrenzt die teure Trimesh-Neuerstellung und die Anzahl vollständiger Sektorfreigaben; es ist kein garantierter Zeit- oder FPS-Grenzwert. Die Randvorhaltung ist für die vorhandene Fußgängerbewegung geprüft. Ein späteres schnelles Pferd oder Fahrzeug benötigt eine eigene vorausschauende Anforderung anhand von Geschwindigkeit und Bremsweg.

### Diagnose

`report()` behält seine vorhandenen Felder und ergänzt `retiring_sectors`, `pending_collisions`, `pending_work`, `collision_limit`, `support_sectors`, `resident_limit`, `last_mesh_builds`, `last_collider_builds`, `last_unloads` und das normalisierte `quality`.

`active_limit` bleibt die **gewünschte** Profilgrenze. Während einer Verkleinerung kann `loaded_sectors` diese vorübergehend überschreiten, jedoch nicht `resident_limit`. `pending_work == 0` kennzeichnet den Abschluss von Mesh-Aufbau, Collideraufbau und Sektorabbau. Diese Trennung verhindert eine falsche Behauptung, die kleinere Grenze sei bereits im ersten Aufruf erreicht.

## Ausgeführte Prüfung

Godot **4.7.2**, Headless, feste 60 Physikschritte pro Sekunde; isolierte XDG-Verzeichnisse und `IMPERATHEN_ISOLATED_TEST=1`. Befehl:

```bash
godot --headless --path prototype --fixed-fps 60 --script res://tests/regional_terrain_test.gd
```

Ergebnis des gezielten Laufs: **8.662 Prüfungen, 0 Fehler**, 1.009 `follow`-Aufrufe. Die Anzahl enthält wiederholte Invariantenprüfungen derselben Engine-Testgruppe und ist keine Anzahl unabhängiger Spielszenarien.

Geprüft wurden tatsächliche Node-/Colliderinstanzen zusätzlich zu den Diagnosezählern, Profilwechsel in beide Richtungen, Unterbrechung einer Ladefolge durch Ortswechsel, Rückkehr, unbekannte Profile, abgelehnte nichtendliche Koordinaten, identische Mesh-Kanten, korrekte Dreiecksnormalen, reale Strahlkollisionen und vollständige Node-Freigabe ohne verwaiste Nodes. Ein echter `CharacterBody3D` überquerte eine positive Zellgrenze in allen vier Profilen sowie negative und diagonale Grenzen auf `low`, ohne nach dem Aufsetzen den Bodenkontakt zu verlieren. Separate Strahlen bestätigen bei `low` physischen Nachbarboden bereits vor dem Übertritt des Körpermittelpunkts.

## Grenzen

Dieser Block liefert Terrain-Lebenszyklus und Bodensicherheit. Ferne Städte, Bewohner der gesamten Region, Welt-Navmeshes, Zellzustands-Speicherung und eine strategische Bevölkerungssimulation sind damit nicht implementiert. Das bestehende Valdora bleibt die ausgestaltete Siedlung. Die 32 × 32 km bezeichnen weiterhin die eigene technische Geländeplanung.

Keine neue APK, keine physische Fold7-Messung, keine nachgewiesene Verbesserung von Bildrate, Akku oder Wärme. Das Aussehen der Terrain-Meshes ist unverändert; die Prüfung belegt Kollisionsverhalten und Ressourcen-Lebenszyklus unter der genannten Testumgebung.
