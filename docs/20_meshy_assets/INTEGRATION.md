# Meshy → Godot/Android: Integrationsvertrag

## Ziel

Die Meshy-Modelle ergänzen den aktuellen Godot-Prototypen, ohne vorhandene
Bewegungs-, Kampf-, Inventar-, Story- oder Speicherlogik zu umgehen. Android
bleibt Hauptplattform; die unveränderten Quellen-GLBs bleiben zugleich für
spätere PC-Profile nutzbar.

## Import-Gates

1. Das **exakte** GLB des im Manifest genannten Meshy-Tasks herunterladen und
   unter dessen `intended_source_path` ablegen.
2. Datei-Hash erfassen; GLB-Struktur, Dreiecke, Normalen, UVs, eingebettete
   Texturen und PBR-Materialien statisch prüfen.
3. Godot 4.7.2 importieren. Maßstab: 1 Einheit = 1 Meter; glTF Y-up, Front +Z.
   Keine pauschale zusätzliche Achsenrotation.
4. Pivot/Bodenkontakt, Silhouette und Materialzuweisung in einer echten
   Viewport-Aufnahme prüfen.
5. Für Figuren: Rig, Skin-Gewichte, Retargeting und Animation getrennt
   verifizieren. A-Pose-Geometrie allein gilt nicht als animiert.
6. Für Waffen/Ausrüstung: definierte Sockets statt Einbacken in den Körper:
   rechte Hand, linke Hand/Unterarm, Rücken, Hüfte; beim Sattel getrenntes
   Pferde-Rig.
7. Kollisionskörper, Trefferkörper und Navigation als vereinfachte Runtime-
   Geometrie anlegen; nicht das Render-Mesh ungeprüft als Vollkollision nutzen.
8. Erst nach Spiel-, Bild- und Android-Test `runtime_ready=true` setzen.

## Android-LOD

Die 4K-PBR-Dateien sind **Masterquellen**, nicht automatisch das Texturbudget
jeder Android-Stufe. Für Hoch, Ausgewogen und Niedrig werden abgeleitete
Textur-/LOD-Varianten gebaut. Dünne Teile – Bogensehne, Lanze, Speer, Signum,
Sling-Cords und Schildränder – müssen im Bildtest gegen aggressives Auto-LOD
geschützt werden.

Empfohlener Produktionspfad:

- Quelle/Hoch: kanonisches Meshy-GLB, PBR-Master erhalten.
- Ausgewogen: geprüfte Geometrie-Reduktion und 2K-Texturen, falls Bildvergleich
  keinen relevanten Verlust zeigt.
- Niedrig: weiter reduzierte Meshes/Texturen; Kernausrüstung und lesbare
  Silhouette bleiben erhalten.
- Fernmassen: instanzierte LODs/impostor-artige Lösungen erst nach Messung; keine
  ungeprüfte Behauptung über Drawcalls oder FPS.

## Gameplay-Anschluss

Ein vorhandenes Modell erteilt dem Spieler **keine** Waffe. Der aktuelle
Kampfvertrag verlangt weiterhin ausdrücklich erworbene/geliehene Ausrüstung.
Inventar und Story entscheiden Besitz; Visuals folgen diesem Zustand.

- Gladius/Spatha/Pugio: Hüft-/Hand-Sockets, Ziehen/Stecken separat animieren.
- Pilum/Speer/Lanze: Handhaltung, Wurf/Stoß und Reichweite aus Gameplay-Daten,
  nicht aus Mesh-Länge allein ableiten.
- Schilde: Blockrichtung und Deckungslogik bleiben autoritativ im Kampfsystem.
- Bogen/Sling/Armbrustkonzept: Projektil-/Release-Logik getrennt implementieren.
- Signifer: Standard ist Rollen-/Moralequipment, nicht bloße Dekoration.
- Ressourcen: Spawnpunkt ist Visual; Abbaumenge, Besitz, Transport und
  Wirtschaft bleiben Domänenzustand.
- Vierhornsattel: sichtbares Ausrüstungsteil; Reiter-Pferd-Kopplung erfordert
  ein geprüftes Mount-/Dismount-System.

## Historische Kennzeichnung

Die Assets sind historisch orientierte Spielmodelle. Die Armbrust ist im
Manifest ausdrücklich als Forschungs-/Spielkonzept markiert, nicht als
behauptete exakte archäologische Rekonstruktion. Historische Persönlichkeiten
benötigen zusätzlich einen eigenen Referenz- und Quellencheck.

## Abnahmekriterien

Ein Asset darf erst als integriert gelten, wenn mindestens Dateiintegrität,
Godot-Import, sichtbare Materialprüfung, Skalierung/Pivot, Kollisions-/Socket-
Prüfung und ein aktueller Regressionstest bestanden sind. Figuren benötigen
zusätzlich Rig-/Animationsprüfung; Android-Tauglichkeit benötigt einen echten
Mobile-Renderer- bzw. Geräte-/Emulatorlauf mit dokumentierten Grenzen.

## Modularer Einheitenbaukasten

Die Datei `prototype/assets/meshy/loadouts.json` verbindet die kanonischen
Stable-IDs ausschließlich auf Präsentationsebene. Sie vergibt weder Besitz noch
Kampffreigaben. Schwere und leichte römische Kavallerie bestehen getrennt aus
Reiter, `mount_ancient_cavalry_horse`, Vierhornsattel, Lanze, Spatha und
Kavallerieschild. Der germanische berittene Gefolgsmann verwendet dasselbe
Pferde-Asset mit eigener Ausrüstung.

Das Pferd ist eine 28k-Smart-Topology-Quelle aus Meshy-Preview
`01a20934-c44a-77ea-95a7-5e2c2c804d5e`. Es ist derzeit untexturiert und
ungeriggt. Vor produktiver Nutzung sind Quadruped-Rig, Skin-Gewichte, Gangarten,
Reiter-/Sattel-Anker, Huf-Bodenkontakt, Kollision, Mount/Dismount und ein echter
Godot-/Android-Bildtest erforderlich.

`tools/art/validate_meshy_loadouts.py` prüft Komponentenklassen und eindeutige
Rohstoffbindungen. `meshy_loadout_registry.gd` liest dieselben Daten in Godot,
ohne fehlende optionale GLBs zu erzwingen.
