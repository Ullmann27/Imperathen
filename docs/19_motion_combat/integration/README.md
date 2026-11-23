# Begrenzte Anschluss-Patches

Diese fünf Patches enthalten ausschließlich die Änderungen an den gemeinsam
genutzten Dateien gegenüber `2909040deeb33b99ad4180b884b38921f28233a9`:

| Patch | Gemeinsame Datei |
| --- | --- |
| `world_model.gd.patch` | `prototype/scripts/domain/world_model.gd` |
| `main.gd.patch` | `prototype/scripts/main.gd` |
| `game_world.gd.patch` | `prototype/scripts/world/game_world.gd` |
| `village_life.gd.patch` | `prototype/scripts/story/village_life.gd` |
| `village_population.gd.patch` | `prototype/scripts/world/village/village_population.gd` |

`manifest.json` benennt für jede Datei die SHA-256-Prüfsumme der Grundlage und
des gelieferten Standes sowie die Prüfsumme des Patches. Die dort aufgeführten
neuen Module, angepassten Darstellungs-/Touchdateien und vier Faustressourcen
gehören gemeinsam zur Integration. Die Patches allein ergeben kein vollständiges
Spiel.

Vor dem Übernehmen die Zielstände mit dem Manifest vergleichen. Bei derselben
Grundlage lässt sich die Anwendbarkeit in einem eigenen Integrationscheckout
mit `git apply --check` prüfen. Bei einem inzwischen fortgeschrittenen
Kindheitszweig die abweichenden Anschlussstellen einzeln zusammenführen;
keinen aktiven fremden Arbeitsbaum zurücksetzen.

Die empfohlene vollständige Quelle ist der Draft-PR dieses Arbeitszweigs.
Die Patches sind eine zusätzliche Reviewhilfe für den koordinierenden Chat.
Die Schnittstellen und Speicherregeln stehen eine Ebene darüber in
[INTEGRATION.md](../INTEGRATION.md).
