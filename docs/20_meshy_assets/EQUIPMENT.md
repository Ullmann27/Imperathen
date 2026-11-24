# Meshy-Ausrüstung an den vorhandenen NPCs

Stand: 24.11.2026. Die folgenden Änderungen betreffen die Darstellung vorhandener NPC-Ausrüstung. Inventar, Schaden, Questfortschritt und Waffenberechtigungen werden dadurch nicht verändert.

## Behobene Regression

Der bisherige `frontier_spearman` enthält Speer und Schild im skinnenden Mesh `FrontierRomanKit`. Beim Austausch durch den Meshy-Axtkämpfer ging diese Geometrie verloren. Der neue Körper enthielt keine eigenständige Handbewaffnung. Der Nachweis liegt sowohl im ursprünglichen Ausrüstungsgenerator `art/soldiers/build.py` als auch im bestehenden Godot-Bild `art/frontier_people/runtime_review/spearman-full.png`.

Die beiden tatsächlich eingesetzten Meshy-Figuren erhalten jetzt separate, maßstäbliche Gegenstände an ihren echten Handknochen:

| Figur | Gegenstand | Bindung | Größe |
| --- | --- | --- | --- |
| Germanischer Angreifer | `weap_germanic_hand_axe` | `Hand_R` | 0,62 m Gesamtlänge |
| Germanischer Angreifer | `gear_germanic_round_shield` | `Hand_L` | 0,66 m Durchmesser |
| Severus | `gear_roman_signum` | `Hand_R` | ungefähr 2,10 m Gesamtlänge |

Die Größen sind lokale Gestaltungsentscheidungen für diese Figuren, keine neue historische Vermessung. Die historische Abnahme der vorhandenen Quellen bleibt gesondert zu behandeln.

## Vorhandene Quellen und lokale Bearbeitung

Es wurden ausschließlich drei bereits erfolgreiche Meshy-Aufträge abgerufen und heruntergeladen:

| Gegenstand | Vorhandene Task-ID |
| --- | --- |
| Axt | `01a2091d-a272-7367-a22f-848695eccb27` |
| Rundschild | `01a20922-ab81-74fa-9139-87adebe3a5d9` |
| Signum | `01a20924-b3e4-7055-bc44-a7d05160d252` |

Es wurde kein neuer Generierungs-, Rigging- oder kostenpflichtiger Konvertierungsauftrag ausgelöst. Die Original-GLBs bleiben unverändert unter dem ignorierten `prototype/assets/meshy/source/`-Verzeichnis. Ihre Prüfsummen und Downloadgrößen stehen in `equipment-sources.json`.

Die visuelle Quellenprüfung zeigte an der Axt einen ungewollten zweiten, querstehenden Holzgriff. Die Datei enthielt drei getrennte Geometriekomponenten. Der lokale Blender-Generator entfernt genau diese eine Komponente mit 518 verschweißten Vertices; Eisenkopf und durchgehender Hauptschaft bleiben erhalten. Kopf und Schaft werden anschließend auf eine kompakte Form skaliert. Schild und Signum werden lokal skaliert und am Griff zentriert. Vor jeder Ableitung prüft der Generator die erwartete Original-Prüfsumme und bricht bei einer anderen Quelle ab.

Reproduzierbarer Generator:

```bash
blender -b -t 2 -P tools/characters/build_meshy_equipment.py
```

## Mobile Ressourcen und Lebenszyklus

Unter `prototype/assets/meshy/equipment/` liegen sechs GLBs, je zwei Detailstufen pro Gegenstand. Zusammen belegen sie **598.104 Bytes**. Die Nahstufe verwendet Texturen bis 512 Pixel, die Fernstufe bis 256 Pixel.

| Gegenstand | Dreiecke Nahstufe | Dreiecke Fernstufe |
| --- | ---: | ---: |
| Axt | 828 | 350 |
| Rundschild | 1.800 | 450 |
| Signum | 1.400 | 450 |

Die vollständigen Maße, Exportprüfsummen und Größen stehen in `equipment-build.json`. Der Helper `prototype/scripts/visuals/meshy_equipment.gd` wählt für Körper-LOD 0 und 1 die Nahstufe, für Körper-LOD 2 und 3 die Fernstufe.

`VillagePerson._reload()` fügt die Gegenstände nach jedem vollständigen Modellwechsel einmalig an. `BoneAttachment3D` folgt dem vorhandenen Handknochen, ohne dessen Pose zu überschreiben. Die lokale Grifforientierung wird aus dessen globaler Ruhebasis abgeleitet. Das Freigeben des alten Körpers entfernt auch dessen Ausrüstung. Ein wiederholter Attach-Aufruf entfernt die bisherigen Ausrüstungsknoten und erzeugt keine Duplikate.

`configure_meshy()` verlangt sowohl die vier Körpertierstufen als auch beide benötigten Ausrüstungsstufen. Fehlt eine notwendige Ressource, bleibt die bisherige bewaffnete Frontier-Figur der Rückfallpfad. Spieler und Begleiter erhalten über diese NPC-Auswahl keine Ausrüstung.

Die Gegenstände besitzen keine Kollisionskörper und ändern keine Domain-Daten. Die vorhandenen Handformen und Körperanimationen bleiben erhalten; es wurde kein zusätzliches Fingerrig oder eigener Waffenkampf eingeführt.

## Tatsächliche Prüfungen

`prototype/tests/meshy_equipment_test.gd` prüft die importierten Gegenstände im produktiven `VillagePerson` einschließlich:

- vollständiger Ausrüstung in allen vier Körper-LODs;
- tatsächlicher Bindung an `Hand_R` bzw. `Hand_L` und Bewegung mit den animierten Händen;
- Textur- und Dreiecksgrenzen;
- Freigabe alter Knoten und Ausbleiben doppelter Gegenstände;
- Wiederherstellung des ursprünglichen bewaffneten Frontier-Modells;
- Ausschluss der Ausrüstung vom kindlichen Spieler.

Der abschließende echte Godot-Viewportlauf besteht **138 Prüfungen ohne Fehler** und erzeugt zehn Bilder. Alle zehn wurden angesehen. Der zunächst sichtbare Griffversatz wurde korrigiert; insbesondere liegt die Schildhand nun hinter dem Schild. Die Dateien liegen unter `evidence/equipment/`, der Erfolgsmarker lautet `MESHY_EQUIPMENT_PASS`. Die bewusst aus der Nähe aufgenommenen Fernstufen zeigen die Geometrieprüfung der niedrigsten Stufe und sind keine Behauptung derselben Nahbildqualität.

Die lesende Android-Diagnose meldet zusätzlich den tatsächlich geladenen Signum-Pfad, den Knochen und die erfolgreiche Bindung. Das bestehende Android-Gate `meshy_severus_loaded` sowie dessen Neustart-Gegenstück verlangen nun auch diesen gebundenen Gegenstand und seinen Ressourcenpfad in der APK. Die Python-Prüfungen dieses Testwerkzeugs bestehen **88 Tests**.

Der echte Main-Speichern-/Laden-Pfad innerhalb eines Godot-Prozesses wurde mit der neuen Diagnose erneut geprüft: 42 beobachtete NPCs, unveränderter Live-/Save-Zustand durch die Diagnose, korrekt fortlaufender Behavior-Zustand nach Laden sowie Severus mit `gear_roman_signum_1.glb` an `Hand_R`. Diese Probe steht unter `docs/21_living_npcs/evidence/android-observer/` und ersetzt ausdrücklich keinen nativen Android-Prozessneustart. Der Android-Gerätelauf wird durch die zentralen Release-Gates separat nachgewiesen.
