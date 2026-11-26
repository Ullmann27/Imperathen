# Germanische Kriegerfamilien

Umsetzung von D-024 (Game Direction vom 26.11.2026, Teil B): Der vorhandene
Meshy-Axtkämpfer bleibt erhalten. Axt mit Schild gilt als seltenere,
künstlerisch rekonstruierte Variante und ist in keiner Standardausrüstung
enthalten. Neu sind zehn Figuren aus fünf Kriegerfamilien für zwei fiktive,
historisch plausible Gruppen am Rhein im Jahr 58 v. Chr. Jede Figur hat eigene
Kleidung, eigene Ausrüstung sowie ein eigenes Gesicht, eigene Haare und einen
eigenen Körperbau. Es sind keine umgefärbten Römer.

| Gruppe | Erkennungsmerkmale |
| --- | --- |
| `river_kin`, Flussleute vom Rhein | Gefärbte Wolle in Krapprot, Waidblau und Ocker, gewebte Karos, Bronzebeschläge, hohe Ovalschilde rot mit hellem Motiv, gebundenes oder kurzes Haar, gestutzte Bärte |
| `forest_kin`, Waldsippen der Höhen | Ungefärbtes Braun und Grau sowie Dunkelgrün, Fischgrat, Pelzumhänge, Seitenknoten, volle Bärte, runde dunkle Plankenschilde mit hellen Ringen oder Bändern |

| Familie (Stufe) | Flussleute | Waldsippen |
| --- | --- | --- |
| Plänkler (1) | Kurzärmlige Tunika, drei Speere, gebundenes Haar | Nackter Oberkörper mit Fell (Caesar BG 6.21), Zöpfe, drei Speere |
| Ziviles Aufgebot (2) | Ungefärbte Tunika, Mantel, einfacher Speer, Rechteckbrett mit Mittelrippe | Grobe Tunika, Pfahlspeer mit gehärteter Spitze, Holzbuckelschild; Axt und Keule nur als Alternative |
| Speer und Schild (3) | Rote Tunika mit Borte, Karomantel mit Bronzefibel, Framea, Ovalschild, Wurfspeere hinter dem Schild | Fischgrattunika, Pelz, Seitenknoten, Framea, Rundschild mit Eisenbuckel |
| Erfahrener Schwertkämpfer (4) | Langes zweischneidiges Schwert, Scheide, Schnurrbart | Einschneidiges Schwert, Wolfspelz, langer grauer Bart |
| Gefolgschaft (5) | Seltener Kettenpanzer, Karohose, Armring, Schwert der Stufe Q3, Rad-Motiv | Framea der Stufe Q3 mit Bronzebändern, Pelzkragen über dem Mantel, Armringe, Nietenbuckel |

Die Qualität der Ausrüstung von Q0 bis Q3 folgt den Werten für Wohlstand,
Handel, Handwerk und Erfahrung jeder Figur (`status` in `registry.json`). Jede
Gestaltungsentscheidung ist dort mit `attested`, `plausible` oder `design`
gekennzeichnet. Quellen tragen den Vermerk [Q]: Die Stellen stammen aus
Fachwissen und sind vor einer Übernahme zu prüfen. Tacitus' *Germania* entstand
um 98 n. Chr., etwa 150 Jahre nach 58 v. Chr.; Seitenknoten, Framea und
Gefolgschaft sind deshalb höchstens `plausible`. Zeitgenössisch ist nur
Caesar. Die Moorfunde (Thorsberg, Damendorf, Osterby) sind jünger, der
Hjortspring-Fund älter.

## Technik

- Körper: vollständiges CC0-MakeHuman-Basismodell des Hero (Erwachsenen-Target),
  angepasst an das unveränderte 15-Knochen-Kompanie-Rig aus
  `art/soldiers/build.py`. Gliedmaßen werden nur längs der Knochen gestreckt.
  `fit_to_company` der Frontier-Figuren bläht dagegen das Becken um 52 % und
  den Oberarm um 33 % auf. Die Sohle wird ohne Knochenänderung auf den Boden
  gesetzt.
- Hände: Eine Faust um einen senkrechten Schaft ist in die Ruhepose gebacken
  (Handgelenk nach vorn, anatomische Fingersegment-Gewichte).
- Körperbau (`lean_young`, `athletic`, `broad`, `stocky`, `wiry`, `veteran`) und
  Gesichter sind radiale beziehungsweise landmarkenbezogene Verformungen. Die
  Knochen bleiben unverändert.
- Kleidung als echte Geometrie: Hose und Tunika sind vom Körper abgeleitet und
  übernehmen dessen Skin-Gewichte. Hinzu kommen Tunikarock, Kettenhemd,
  Mantel und Fell mit Faltenwurf, Wickelbänder, Schuhe mit Riemen, Gürtel,
  Borten, Fibel und Armringe. Haar und Bart (Kappe mit geglätteter
  Haarlinie, Knoten, Zopf, Schwanz, Bart mit Kiefer-Morph) sind ebenfalls
  Geometrie. Bedeckte Haut wird entfernt.
- Materialien: prozedurale, kachelbare PBR-Texturen in `surfaces.py`
  (Köper, Fischgrat, Leinwand, Karo, Leder, Fell, Haar, Holz, Eisen, Bronze,
  Kettengeflecht, bemalte Schildbretter mit Abplatzungen). Die Haut ist eine
  Variante der vorhandenen CC0-Haut mit Ton, Wetter, Sommersprossen,
  Bartschatten und Narben.
- Clips: die elf Kompanie-Clips mit Rolle `spear` oder `heavy`. Bei den
  Plänklern ist `shoot` ein Speerwurf. Nach jedem Export läuft die gemeinsame
  Todes-Erdung `tools/characters/ground_death_clip.py` aus dem
  zusammengeführten Reparaturstapel (#87 bis #95, df15a2e).
- Ausrüstung: in jede Figur als eigene, zu 100 % an `Hand_L`/`Hand_R`/`Pelvis`
  gebundene Meshes gebacken. Zusätzlich existiert eine Bibliothek in
  `export/equipment/<id>_<0|1>.glb`, griffzentriert mit
  `SOCKET_RIGHT_HAND`, `SOCKET_LEFT_HAND` oder `SOCKET_BELT_LEFT` wie die
  Meshy-Ausrüstung.
- LOD 0 bis 3 mit den Budgets aus `registry.json` (22 000, 7 600, 2 400 und
  900 Dreiecke, Texturkante 1024/512/256/128). Gesichtsmorphs gibt es nur auf
  LOD 0 und 1.

## Nachstellen

```sh
B=/home/user/tools/blender-4.3.2-linux-x64/blender
$B -b -t 3 -P art/germanic_warriors/build.py -- --export --equipment
$B -b -P art/germanic_warriors/measure.py
python3 tests/germanic_warriors_test.py
G=/home/user/tools/godot/Godot_v4.7.2-stable_linux.x86_64
xvfb-run -a -s "-screen 0 1280x720x24" $G --path prototype --rendering-method gl_compatibility \
  --resolution 1280x720 --script "$PWD/art/germanic_warriors/review.gd" -- balanced /tmp/review turntable
```

## Warum die GLBs (noch) nicht unter `prototype/` liegen

`tools/motion_quality_gate.py` verlangt für jede 3D-Ressource unter
`prototype/` eine Bewegungsfamilie im `quality/motion_contract.json`.
Andernfalls entsteht ein Blocker „Unclassified runtime 3D resource“. Jede neue
aktive Familie braucht außerdem eine von Menschen freigegebene Sichtprüfung,
die sich nicht selbst erteilen lässt. Eine Aufnahme unter `prototype/` hätte
deshalb zwangsläufig neue Gate-Blocker erzeugt. Die Exporte liegen bis zur
Integration und Freigabe in `art/germanic_warriors/export/`. Rig, Clips und
Sockets sind bereits zu den Kampf- und Überfallfiguren kompatibel; das prüft
`tests/germanic_warriors_test.py`. Für die Integration ist die Familie im
Vertrag einzutragen. Danach folgen die gezielte Messung, die Sichtprüfung,
die Routen in `village_person.gd` beziehungsweise `soldier_visual.gd` und
`.import`-Dateien mit abgeschaltetem Keyframe-Optimizer wie bei den 54
Kompanie-Exporten.

Vorschlag für den Vertragseintrag bei der Integration (noch nicht eingetragen):

```json
{"id": "germanic_warriors", "profile": "human", "status": "active",
 "resources": ["assets/germanic_warriors/germanic_<figur>_<0-3>.glb", "…"],
 "required_checks": ["germanic_warriors", "npc_behavior_world"],
 "review_scope": ["idle_talk", "walk_run_stop", "attack_guard_reaction",
                  "contact_and_weight", "lod_transition", "military_equipment"],
 "open_requirements": []}
```

## Grenzen

- Berittene Einheiten fehlen. Das Pferd ist untexturiert und nicht lokal
  vorhanden, und `mounted_units` ist im Bewegungsvertrag inaktiv. Ohne Pferd
  lassen sich weder Sitz noch Zügel noch Steigbügelanker messen.
- Clips stammen aus dem Kompanie-Rig. Keine Figur hat eigene germanische
  Kampfchoreografie, Fingerknochen, Stoffsimulation oder Laufzeit-IK.
- Die Gesichter sind Varianten derselben CC0-Basis, keine Scans. Haar und Bart
  sind texturierte Geometrie ohne Haarkarten.
- Die Messungen in `measurements.json` betreffen exportierte LOD-0-Bytes in
  Blender. Sie ersetzen weder die Engine-Messung des Motion-Gates noch eine
  Messung auf dem Fold7.

## Stand 26.11.2026 (Arbeit pausiert, D-056)

Dieser Stand ist ein Zwischenstand und gilt nicht als produziert.

- Eingecheckt sind nur Generator, Register, Prüfskripte und Test. Die Exporte
  (`export/`), `build_report.json` und `measurements.json` sind nicht
  eingecheckt: Die Quellen wurden nach dem letzten vollständigen Build noch
  geändert (Kollisionskorrektur `push_out` für Mantel, Fell und Haar, neue
  Ausrüstungseinträge), ein Neubau damit steht aus.
- Letzter vollständiger Build (vor diesen Änderungen), `tests/germanic_warriors_test.py`:
  8 von 10 Prüfungen bestanden (Rig und elf Clips wie das Kompanie-Rig,
  Dreiecksbudgets LOD 0 bis 3, Register). Nicht bestanden: Kleidungsdurchdringung
  (Mantel und Fell bis etwa 8 cm, Grenze 1 cm) und die Ausrüstungsbibliothek
  (`forest_javelin_r_q0` noch nicht exportiert).
- `socket_check.gd` meldet für alle Gegenstände 1 bis 2,5 m Abweichung. Ob die
  Prüfung oder die Daten falsch sind, ist ungeklärt.
- Die Godot-Sichtprüfung (`review.gd`) lief noch nie durch; es gibt keine
  Godot-Renders.
- Es fehlen: Bogenschützen, Blender-Axtkämpfer, berittene Einheiten (kein
  Pferdemodell im Repo), Anführer/Edler, Läufer, ein eigener Wurf-Clip für alle
  Figuren, die Zuordnung zu allen zwölf germanischen `troop_id`, die Ablage
  unter `prototype/assets/` und die Bewegungsfamilie im Motion-Vertrag.
- LOD 0 nutzt bis zu 67 Texturen und rund 25 Materialien je Figur. Für Truppen
  ist ein Atlas je Figur ab LOD 2 nötig.
