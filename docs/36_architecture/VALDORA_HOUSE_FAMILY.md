# Valdora – modulare Hausfamilie und Dorfpflaster

Stand 26.11.2026, Branch `feat/architecture-families-20261126`. Umsetzung der Punkte 1 und 2 der [AAA Visual Quality Directive](../00_governance/GAME_DIRECTION_2026-11-26_C.md) (D-031, D-034, D-038) für die Häuser, die der Spieler in First Play I-01 bis I-04 zuerst sieht. Die Stadtfamilien folgen als zweiter Abschnitt.

Bisher standen alle 20 Wohnhäuser von Valdora als dieselbe Datei `frontier_house.glb` im Dorf, nur der Putz war umgefärbt. Jetzt setzt sich jedes Haus aus einem gemeinsamen Bausatz zusammen und gehört nach seinem Haushalt zu einer von drei Wohlstandsstufen.

## Historische Grundlage (58 v. Chr., Umland von Aquileia)

Belegt oder archäologisch gut gesichert:

- Sockel aus Feld- und Flusssteinen mit Kalkmörtel, darüber Mauerwerk in *opus incertum* (Vitruv 2,8,1; republikanische Bauten Mittel- und Norditaliens). Ziegelverblendung (*opus testaceum*) und Netzmauerwerk (*opus reticulatum*) als Fassade sind kaiserzeitlich bzw. stadtrömisch und kommen nicht vor.
- Kalkputz (*intonaco*), Sockelmalerei mit rotem oder gelbem Ocker; der Erste Stil (Quadermalerei in Stuck) für wohlhabende Häuser (2.–1. Jh. v. Chr.).
- Fachwerk mit Lehmflechtwerk (*craticii parietes*, Vitruv 2,8,20) für einfache Häuser.
- Dachdeckung aus *tegulae* mit Randleisten und darübergelegten *imbrices*; der First in Mörtel gesetzt. Etrusko-italische Stirnziegel (Antefixe) an der Traufe wohlhabender Häuser.
- Fenster ohne Glas: Holzläden und Eisengitter. Holztüren aus Brettern mit Querleisten, eisernen Bändern und Nägeln.
- Tuskische (italische) Säulen mit Basis, sich verjüngendem Schaft und Echinus (Vitruv 4,7).
- Holzbalkone (*maeniana*, nach C. Maenius 318 v. Chr.) an zweigeschossigen Häusern.
- Pflaster aus Flusskieseln der Isonzo-/Torre-Ebene, Kalksteinplatten und gestampftem Kies (*glarea*); polygonale Steinpflasterung (*silex*) gehört zu Straßen der Städte.

Gestalterische Annahmen (nicht einzeln belegt): Rauchhaube über dem Herd (Rauch zieht durch Tür, Fenster und Dachdeckung), die konkrete Lage der Vorhalle, der Ockerton je Haus, die Verteilung der Alterungszustände.

## Bausatz und Varianten

Generator: `art/architecture/valdora_family/` – `family_kit.py` (Bausteine), `family_houses.py` (Rezepte), `build_family.py` (Blender-Export, Manifest, Cycles-Bilder), `family_textures.py` und `paving_textures.py` (Texturebenen). Alle Formen und Texturen sind lokal und mit festen Seeds erzeugt; keine Fotos, Scans oder Downloads.

Bausteine: Bruchsteinsockel aus Einzelsteinen in Mörtelbett, verschobener Putz mit echten Fehlstellen (2,4 cm tief bis aufs Mauerwerk, mit Bruchkanten), Laibungen, Eckquader, Fachwerk mit Streben, Tür mit Brettern, Leisten, Bändern, Nägeln und Ring, Fenster mit Rahmen, Steinbank, Läden und Gitter, Sparren, Schalung und Traufbrett, Tegulae mit Randleisten und konische Imbrices je Stück, Firstziegel im Mörtelbett, Ortgangbretter, Antefixe, Rauchhaube, Vordach auf Kragbalken, tuskische Vorhalle, Holzbalkon, Rampe aus Eichenbohlen oder Steinplatten mit Griffrillen und Wangen. Alle Kanten sind gefast (1–4,5 cm); gewichtete Normalen lassen sie gerundet erscheinen. Durchhängende Firste, leicht gekippte Ziegel, versetzte Steine und eine gewellte Putzhaut nehmen den Häusern das Modellhafte.

| Variante | Stufe | Beschreibung | Dach | Dreiecke LOD0 (Hülle / Detail / Einbauten) | Budget | GLB |
| --- | --- | --- | --- | --- | --- | --- |
| `valdora_t1_daub` | 1 | Fachwerk mit Lehmflechtwerk, Bruchsteinsockel | gable_front | 32544 (28914 / 2816 / 814) | 36000 | 4.5 MB |
| `valdora_t1_rubble` | 1 | Bruchsteinhaus mit Lehmputzresten | eave_front | 32138 (28728 / 2596 / 814) | 36000 | 4.4 MB |
| `valdora_t2_render` | 2 | Kalkputzhaus mit Vordach | gable_front | 32424 (28090 / 3520 / 814) | 38000 | 4.4 MB |
| `valdora_t2_eave` | 2 | Traufständiges Putzhaus mit Ockerband | eave_front | 31658 (26840 / 4004 / 814) | 38000 | 4.3 MB |
| `valdora_t2_mixed` | 2 | Teilverputztes Bruchsteinhaus mit Fenstergittern | gable_front | 33374 (28644 / 3916 / 814) | 38000 | 4.5 MB |
| `valdora_t2_hip` | 2 | Putzhaus mit Walmdach und Ockersockel | hip | 32790 (27972 / 4004 / 814) | 38000 | 4.5 MB |
| `valdora_t3_portico` | 3 | Haus mit tuskischer Vorhalle, Antefixen und Ziermalerei | eave_front | 37558 (31608 / 5136 / 814) | 50000 | 5.1 MB |
| `valdora_t3_upper` | 3 | Zweigeschossiges Haus mit Holzbalkon (maenianum) | gable_front | 43414 (38068 / 4532 / 814) | 50000 | 6.2 MB |
| `valdora_forge` | – | Schmiede des Nerva (Pultdach auf Eichenpfosten); sieben Stationen als eigene Knoten | Pultdach | 19094 (6260 / 2286 / 10548) | 24000 | 2.7 MB |

Zuordnung (nach dem Wohlstand der Haushalte aus `household_designs.gd` des Innenraum-Pakets, Tabelle `ASSIGNMENT` in `valdora_house_family.gd`): Stufe 1 – Feldarbeiter, Köhler (Fachwerk), Straßenwache, Spinnerin (Bruchstein); Stufe 3 – Älteste (Vorhalle), Schreiber und Tuchhändlerin (zweigeschossig); alle übrigen Stufe 2 in vier Varianten. Verwendet werden alle acht Varianten, keine öfter als viermal (geprüft in `verify_family.gd`).

Alterungszustände (gepflegt, verwittert, abgenutzt, verfallen) wirken über Vertexfarben – Feuchte, Moos und Flechten, Ruß, abgestoßene Kanten – und Materialparameter. Dazu kommen der Putzton je Haus und eine großflächige Weltvariation im Shader.

## Innenraumvertrag

Jede Variante behält den gemeinsamen Raum des Dorfes, damit die Möbel des Innenraum-Pakets passen: Boden 0,3925 m, Putzflächen x = ±2,68 m und z = ±2,17 m, Tür in der Straßenwand (lichte Weite 1,12 × 2,08 m, Flügel bei (−0,575; 2,15) um 100° nach innen geöffnet), Fenster an den bisherigen Stellen, Tisch, Wandbank und Vorratskrug als eigene Knoten `Fixture_*`. Das Manifest veröffentlicht den Vertrag unter `interior_contract`. Stufe 3 ergänzt einen Dachboden (2,82 m lichte Höhe unter den Balken) bzw. eine überdachte Vorhalle.

## Pflaster und Wege

`valdora_paving.gd` legt flache Flächen 6 mm über die Bodenebene (Kollision bei −0,01 m), eigene Kollision entfällt: gepflasterter Platz aus Flusskieseln um Brunnen und Markt mit Plattenkranz am Brunnen, eine Vorfläche vor jeder Rampe (Stufe 1 Erde mit Trittsteinen, Stufe 2 Kiesel, Stufe 3 Platten mit Bordsteinen), Traufstreifen aus Kies, Wege von jeder Tür zur nächsten Gasse, Pfützenmulden in den Fahrspuren. Die Ränder lösen sich Stein für Stein in den Boden auf (Alpha-Scissor über die Höhenkarte), statt mit einer geraden Kante zu enden. Fugen sind schmal und mit Erde gefüllt, also dunkler als die Steine. Nässe und Pfützen folgen der Jahreszeit (`village_scenery.apply_season`).

## Budgets je Grafikprofil (D-034)

| Profil | Texturebenen Haus / Pflaster | Normal- und Höhenkarten | Detailnetz (Beschläge, Gitter, Antefixe, Kiesel) | volles Haus, danach Silhouette | Pflaster | automatische LOD-Schwelle |
| --- | --- | --- | --- | --- | --- | --- |
| Leicht | 16 × 256² / 8 × 256², nur Farbe und AO/Rauheit/Höhe | keine | bis 12 m, ohne Schatten | 55 m | bis 40 m | 3,0 |
| Ausgewogen (Fold7) | 16 × 512² / 8 × 512² | Normalkarten | bis 26 m, ohne Schatten | 95 m | bis 70 m | 1,5 |
| Hoch | wie Ausgewogen | Normalkarten, Pflaster mit Parallaxe | bis 45 m, mit Schatten | 150 m | bis 110 m | 0,65 |
| Sehr hoch (Ultra) | 16 × 1024² / 8 × 1024² | Normalkarten 1024², Haus und Pflaster mit Parallaxe | bis 70 m, mit Schatten | 220 m | bis 150 m | 0,4 |

Dreiecksbudget der höchsten Stufe je Haus (Hülle, Detail, Einbauten): Stufe 1 36.000, Stufe 2 38.000, Stufe 3 50.000; Detailnetz ≤ 6.000, Silhouette ≤ 400. Godot erzeugt beim Import weitere LOD-Stufen. Texturspeicher (VRAM-komprimiert mit Mipmaps, rechnerisch, nicht gemessen): Häuser 8,0 MiB, Pflaster 4,0 MiB in Ausgewogen/Hoch, etwa das Vierfache in Sehr hoch, zusammen 2,0 MiB in Leicht; alle Varianten teilen dieselben Texturarrays.

Gemessene Godot-Werte (Zeichenaufrufe, Dreiecke im Bild, Speicher) stehen erst nach den Aufnahmen fest, siehe STATUS.

## Prüfung und Renderbelege (D-038)

Siehe Abschnitt STATUS unten.

## Nachstellen

```sh
python3 art/architecture/valdora_family/family_textures.py --out prototype/assets/architecture/valdora
python3 art/architecture/valdora_family/paving_textures.py --out prototype/assets/architecture/valdora
blender -b -t 1 --python-exit-code 1 -P art/architecture/valdora_family/build_family.py -- --variants all [--render all]
godot --headless --path prototype --import
godot --headless --path prototype --script "$PWD/art/architecture/valdora_family/verify_family.gd"
xvfb-run godot --path prototype --rendering-method gl_compatibility \
  --script "$PWD/art/architecture/valdora_family/capture_valdora.gd" -- --out=<dir> --label=after --profile=balanced
```

## Offene Punkte

Siehe Abschnitt STATUS unten.

## Schmiede des Nerva (D-052)

`family_forge.py` baut die Dorfschmiede aus demselben Bausatz: Pultdach mit Tegulae und Imbrices auf Eichenpfosten mit Kopfbändern vor dem Haus des Schmieds, Flechtwand mit Lehm hinter der Esse, gemauerte Esse mit lehmausgekleidetem Feuerbett, Holzkohle, Rauchfang und Tondüse, Doppelblasebalg mit Wippe, Blockamboss im Eichenstock (römische Ambosse sind Blöcke ohne langes Horn), Werkzeugwand mit Zangen, Hämmern, Meißeln und Schere, Löschtrog, Werkbank mit fertiger Ware (Sicheln, Messer, Axtkopf, Pflugschar, Nägel), Stabeisen, Luppen und Holzkohlebottich. Jede Station ist ein eigener Knoten (`Fixture_Hearth`, `Fixture_Bellows`, `Fixture_Anvil`, `Fixture_ToolRack`, `Fixture_QuenchTrough`, `Fixture_Workbench`, `Fixture_Stock`).

`settlement_dressing.gd` ersetzt damit die bisherige Schmiede aus Quadern. Die Stationen stehen an denselben Stellen (Blasebalg, Amboss und Löschtrog der Schmiedelehre), die Knoten `VillageForge/Hearth|Bellows|Anvil|ToolRack|QuenchTrough` bleiben und tragen die Kollision; neu sind `Workbench` und `Stock` mit den Metadaten `station`, `goods` und `materials` als Anknüpfung für Warenbestand und Interaktionen. Der Weg von der Gasse zur Haustür des Schmieds (lokal z −0,75 bis 0,75) bleibt frei. Handel, Bestand und zusätzliche Interaktionen sind noch nicht angebunden.

## STATUS (26.11.2026, Abschluss dieses Durchgangs)

Umgesetzt und geprüft:

- Bausatz, acht Hausvarianten in drei Wohlstandsstufen, Schmiede, 16 Hausebenen und 8 Pflasterebenen in 1024², 512² und 256², Shader für Häuser und Pflaster, Zuordnung der 20 Haushalte, Pflasterflächen und Wege, Budgets und Sichtweiten je Profil.
- `verify_family.gd` (Gruppe `valdora_family` in `tools/check_prototype.py`): 713 Prüfungen, `VALDORA_FAMILY errors []`. Geprüft werden Aufbau und Budgets jeder GLB, erzeugte LOD-Stufen, Texturarrays, Profilunterschiede, die Zuordnung, freie Türöffnungen in Netz und Physik, feste Wände neben der Tür, sichtbare Schwelle, Rampe und Vorhalle höchstens 3 cm von der Kollision, Boden auf Pflasterhöhe, Pflaster flach auf dem Boden.
- Die Prüfung hat vier echte Fehler der ersten Fassung gefunden, die behoben sind: Schwellbalken und Ständer quer durch die Tür der Fachwerkhäuser, ein Putzstreifen quer durch die Tür, zu tiefe Bodenfugen und offene Fugen in der Vorhalle.

Nicht abgeschlossen:

- Godot-Aufnahmen vorher/nachher mit gleicher Kamera (`capture_valdora.gd`, sechs Einstellungen) und die Cycles-Bilder (`build_family.py --render all`) waren bei Abschluss noch nicht entstanden; die Renderwarteschlange der gemeinsamen Maschine war überlastet. Es gibt deshalb noch keine Sichtabnahme der Häuser, der Schmiede und des Pflasters in der Engine und keine gemessenen Zeichenaufrufe oder Speicherwerte. Die Shader sind bisher nur ohne Bildausgabe geladen worden.
- Die editierbare `source/valdora_family.blend` wird erst mit einem Lauf ohne `--no-save` geschrieben.
- Regressionsgruppen des Dorfes siehe Übergabebericht des Durchgangs.
- Stadtfamilien (Hauptstraße, Marktviertel, Forum), das Stadtpflaster, das Kolosseum als späteres Epochenbauwerk, Rom 58 v. Chr. (D-060) und die Meshy-Vorlagen (D-059) sind nicht begonnen. Für das Stadtpflaster hat der Pflaster-Shader einen Modus mit fester Ebene (`fixed_layer`, Ebene `silex`); eingebaut ist er nicht.
- Leder des Blasebalgs nutzt mangels eigener Ebene die Lehmebene; eine Leder- und eine Flechtwerkebene fehlen im Texturarray.
- Fold7: keine Gerätemessung.
