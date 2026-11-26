# Erwachsene, Soldaten, Bewohner: Rig, Hände, Gesicht – STATUS

**26. November 2026 · Branch `feat/people-detail-realism-20261126` (auf `df15a2e`) · Abschluss nach Wrap-up-Anweisung.**

Kurzfassung: Der Bauweg für Finger, Kiefer, Augen, Lippenformen und gegriffene Waffen ist geschrieben und in
Blender an zwei Figuren ausprobiert. **Die Laufzeit-GLBs in diesem Branch sind unverändert die Exporte von
`df15a2e`.** Es gibt keinen Godot-Test, kein Motion-Gate-Ergebnis und kein Godot-Renderbild für den neuen Stand.
D-035 ist damit für keine Figurengruppe erfüllt.

## Stand je Baustein

| Baustein | umgesetzt (Code) | in Blender ausprobiert | Godot-Test | Godot-Render |
|---|---|---|---|---|
| Finger: 15 Gelenke je Hand (`Thumb/Index/Middle/Ring/Pinky` `1..3` `_L/_R`), Gewichte aus den CC0-MakeHuman-Gewichten | ja, `tools/characters/extend_adult_rig.py` | `civilian_man`, `legionary`, `archer` (Export lief durch) | nein | nein |
| `Jaw` (Kind von `Head`, Drehpunkt aus dem vorhandenen `JawOpen`-Morph gelöst, Streuung 4,7–5,5 mm) | ja | ja (Messwert) | nein | nein |
| `Eye_L` / `Eye_R` | ja | ja (Export) | nein | nein |
| Lippen-/Lid-/Brauenformen für Lippensynchronität (10 Formen, siehe unten) | ja, prozedural aus Muskelmasken | nur exportiert, **nie angesehen** | nein | nein |
| Fingerkeys in allen Clips (Ruhe, Gehen, Sprechen, Arbeit, Kampf, Tod) | ja | Standbilder Ruhe/Sprechen/Arbeit/Angriff | nein | nein |
| Soldatenhände: Größe (Faktor 1,42; die Company-Anpassung hatte sie auf etwa zwei Drittel verkleinert), Griffstange in die Handfläche, Finger bis zum Kontakt geschlossen | ja | Legionär rechts: Finger liegen an (Restspalt 0,9–1,5 mm); **Daumen ohne gültige Lösung, fällt auf die Faustpose zurück**; Schildhand nur Faust, der Schild hat keinen Griff | nein | nein |
| Kanäle von `Jaw`/`Eye_*` nach dem Export aus den Clips entfernt (`release_runtime_joints`) | ja | **nicht gelaufen** | nein | nein |
| Blick (Sakkaden, Blickziel) in `facial_motion.gd` | ja | – | **nein, nie ausgeführt** | nein |
| Identitätsschicht der Bewohner (Gesichter, Haare, Bärte, Kleidung; Vorarbeit der vorigen Sitzung) | ja | laut deren Protokollen gebaut | deren Test nicht neu gelaufen | nein |

Blender-Entwicklungsvorschauen (Cycles, 8 Samples, **keine Ingame-Grafik**, kein Nachweis nach D-038):
`docs/14_character_realism/rig_preview/blender_dev_legionary_grip.jpg`,
`docs/14_character_realism/rig_preview/blender_dev_civilian_hands.jpg`.

## Namen für den Lippensynchron-Treiber (`docs/41_audio/FACIAL_RIG_PLAN.md`, Branch `feat/voices-lipsync-sfx-20261126`)

| Plan | in den Frontier-Exporten dieses Bauwegs |
|---|---|
| Joint `Jaw` | `Jaw`; Öffnen = Drehung um die seitliche Achse (+X im Armature-Raum), 12° entsprechen `JawOpen` = 1 |
| Joints `Eye_L`, `Eye_R` | gleich; lokale Y-Achse zeigt nach vorn |
| `mouthClose`, `mouthFunnel`, `mouthPucker`, `mouthStretchLeft`, `mouthStretchRight`, `mouthRollLower`, `mouthUpperUp` | gleichnamig auf `HeroBody` (und `IdentityBeard`), nur Stufe 0 und 1 |
| `eyeSquintLeft`, `eyeSquintRight`, `browInnerUp` | gleichnamig |
| `eyeBlinkLeft`, `eyeBlinkRight`, `browDown` | **nicht umbenannt**: vorhanden als `Blink_L`, `Blink_R`, `BrowDown` (der Treiber kennt `Blink_*` bereits) |
| `Lid_Upper_L/R` | nicht vorhanden |

Alle vier Stufen tragen dasselbe Skelett (48 Gelenke, Bogenschütze 50): Die Laufzeit übergibt Posen beim
Stufenwechsel gelenkweise, und das Motion-Gate vergleicht sie (`lod_transition`).

## Geprüft auf dem Quellstand dieses Branches (alte GLBs, neue Skripte) – 26.11., leichte Sperre, headless

`python3 tools/check_prototype.py --godot Godot_v4.7.2 --only <gruppe> --keep-going`

| Gruppe | Ergebnis |
|---|---|
| `village_people` | PASS |
| `frontier_people` | **FAIL im Runner**, obwohl `FRONTIER_PEOPLE_PASS 251 checks, 0 failed`: beim Freigeben eines Körpers (`village_person.gd:239`, `body.free()`) meldet Godot headless viermal `ERROR: Parameter "material" is null` (`material_get_instance_shader_parameters`). Ursache liegt in den Shadermaterialien der Identitätsschicht (`resident_look.gd`); auf `df15a2e` tritt die Meldung nicht auf. **Offene Regression**, nicht behoben. |

Alle anderen Gruppen und das Motion-Gate sind auf diesem Stand nicht gelaufen.

## Nicht begonnen

- Meshy-Figuren, Company-Soldaten (`art/soldiers`), Dorfmodell (`art/village_characters/build.py`), Held: kein Finger-/Kieferrig.
- Gangprüfung (Fußgleiten, Knie, Becken, Armschwung, Drehen, Anlauf/Stopp) aus Bildfolgen: nicht durchgeführt.
- Laufzeit-Griffe für Requisiten der Bewohner (`hand_pose.gd` kennt nur das Hero-Morph).
- `tests/frontier_people_test.gd` erwartet noch 15/17 Gelenke; muss mit dem Neuexport auf 48/50 und um
  Finger-, Kiefer-, Blick- und Formprüfungen ergänzt werden.
- Die Testgruppe `resident_identity` ist in `tools/check_prototype.py` **nicht** eingetragen, weil sie ohne
  neu gebaute GLBs nicht bestehen kann.

## Nächste Schritte

1. Motion-Branch (`/home/user/work/imp-motion`, Achselnaht-Reparaturen 58786f9/aeeed93) einmischen, damit der Export sie nicht verliert.
2. Neu exportieren (je Art ein Lauf, Soldaten etwa 35 s):
   `blender -b -t 1 -P tools/characters/build_frontier_people.py -- --export-only --types legionary` (ebenso `officer spearman archer`);
   `blender -b -t 1 -P art/village_characters/build_resident_identity.py -- --kinds civilian_man` (ebenso `civilian_woman elder`).
3. `godot --headless --path prototype --import`, Tests anpassen, dann
   `python3 tools/check_prototype.py --godot … --only frontier_people village_people natural_motion motion_skin_measurement`
   und `python3 tools/motion_quality_gate.py --evidence <dir>` (Basis 351 bei `df15a2e`).
4. Vorher/Nachher mit `prototype/tests/resident_identity_review.gd` (Aufnahmen `close,talk,full,walk,hand,lineup`;
   die Kameras hängen nur an den 15 alten Gelenken und gelten für beide Stände).
5. `art/frontier_people/provenance.json` trägt noch den Skripthash des vorigen Stands.

## Quellen

- MakeHuman-Gewichte und Gelenkhelfer: `art/hero_quality/source/default_weights.mhw`, `base.obj` (CC0, siehe `source/provenance.json`).
- Formnamen: Apple ARKit `ARFaceAnchor.BlendShapeLocation`, über den Plan der Audio-Sitzung.
