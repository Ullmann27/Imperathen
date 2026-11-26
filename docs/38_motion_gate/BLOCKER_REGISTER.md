# Motion-Gate – Blocker-Register (D-039)

Stand 26.11.2026, Branch `feat/motion-gate-blockers-20261126` (Basis 89e735d + Reparaturstapel df15a2e = PR #88–#95).
Gate: `tools/motion_quality_gate.py`, Messung: `prototype/tests/motion_quality_measurement.gd` (+ `motion_world_measurement.gd`,
`motion_equipment_measurement.gd`, `motion_skin_measurement.gd`). Alle Grenzwerte, Profile, Szenarien und Sichtprüfungsregeln sind
unverändert; dieses Register ändert keinen Grenzwert.

## STATUS (26.11.2026, Abschlussstand dieses Branches)

**Engine-gemessene Blockerzahl auf dem Head: liegt nicht vor.** Der Messlauf (`motion_measurement`, ca. 9–12 Minuten) stand beim
Abschluss noch in der Warteschlange der gemeinsamen Godot-Sperre. Es wird hier keine Zahl „nach den Korrekturen“ behauptet.

| Stufe | Stand |
|---|---|
| Nachgewiesen ohne Engine (Gate-Lauf auf dem Head, reines Python) | Inventarblocker 84 → 4 lokal (die vier privaten Youth-GLBs; in CI zusätzlich 2 Dateien des privaten Stadtpakets = 6). **351 − 78 = höchstens 273**, falls sich sonst nichts geändert hätte. |
| Offline gemessen (CPU-Skinning der exportierten Clips bei 60 Hz, Gate-Kriterium), Engine-Bestätigung offen | Angriff/Training-Standfuß (B1, Teile von B2/B3), Hautkanten der Tuniken (C1, 10 von 12 Zeilen C2) |
| Implementiert mit Tests, Engine-Messung offen | Rückzug als Laufzyklus (D1, 48 Zeilen), Hero-Tritte (B4, 5 Zeilen) |
| Engine-Diagnose vorhanden, keine Korrektur | Weltübergänge (E1–E3), Youth-Standfuß (B5), Ausrüstung (F), LOD-Wechsel (G1) |
| Nicht angefasst, bewusst | Sichtprüfung (H1, 12), offene Vertragsanforderungen (I1, 4), private CI-Assets (A4, 6) |

Wenn die Engine alle offline gemessenen und implementierten Korrekturen bestätigt, bleiben rechnerisch etwa 85–95 Zeilen
(A4 6, B5 2, C2 2–3, E 30, F 18, G1 5, H1 12, I1 4 sowie Restwerte der Todesclips in B2). Das ist eine **Erwartung, kein Messwert**.

Nächster Schritt für die Fortsetzung: `scratchpad/motion/job.sh <name>` (Import in der leichten Spur, `check_prototype.py --only
motion_measurement` mit `timeout 720` in der schweren Spur, danach `motion_quality_gate.py --evidence`), die Liste mit
`scratchpad/motion/py/register.py` klassifizieren und die Tabelle in Abschnitt 3 ergänzen. Für die mit CI vergleichbare Summe müssen
zusätzlich die 29 `required_checks` der aktiven Familien im selben Lauf bestehen.

## 1. Ausgangsbasis und Vergleich

| Lauf | Quelle | Blocker |
|---|---|---|
| #87 CI | 89e735d, `baseline87/gate_blockers_pr87_sorted.txt` | 587 |
| #95 CI (**Basis dieses Registers**) | df15a2e (Merge-Ref von PR #95), `ci95.blk`, 26.11. 03:55 UTC | 351 |
| #98 CI | Run 45761482750 / Job 139712260775, Kalender-Branch auf #87 | 593 |
| zwei weitere #87-basierte Läufe | Jobs 139737517424 und 139737710632 | 589 / 589 |

**#87 → #95 (−236)** stammt aus dem Reparaturstapel: Sohlendurchdringung von Tod/Hocke (S1, 116), Skelettprobenfehler der
Frontier-Laufzeit (S2, 80), dazu niedrigere Gleit- und Hautkantenwerte (B2–B4, C1, C2).

## 2. Die Schwankung 587 / 589 / 593 ist kein Messrauschen

Befund aus dem zeilenweisen Vergleich der fünf CI-Listen:

- Die Messwerte sind in allen #87-basierten Läufen **zeichengleich**. #93 und #94 sind untereinander identisch (355). Kein Messwert
  schwankt zwischen zwei Läufen desselben Quellstands; die 60-Hz-Messung ist deterministisch.
- Die Listen unterscheiden sich ausschließlich in Zeilen `Unclassified runtime script`: 589 = 587 + `soldier_roster.gd`,
  `troop_catalog.gd` (ein Lauf) bzw. + `actor_relations.gd`, `tribal_world.gd` (der andere, gleiche Summe, andere Dateien);
  593 = 587 + sechs Kalenderskripte.
- Ursache: Das Gate verlangt für jedes Skript unter `prototype/` einen geprüften Eintrag in `runtime_scripts`. Jeder Branch, der ein
  Skript hinzufügt, bekommt deshalb je Datei einen Inventarblocker – auch für reine Tabellen und Domänenlogik, die nichts bewegen
  kann. Die Summe mischte Pfadinventar und Bewegungsbefunde und sah dadurch wie Rauschen aus.

Behebung (82af7cd):

1. Ein GDScript, das **nachweislich reine Datenlogik** ist, braucht keinen Listeneintrag mehr. Der Nachweis wird bei jedem Gate-Lauf
   am Quelltext geführt (`data_logic_scripts`): Basisklasse `RefCounted`/`Resource`/`Object` oder ein selbst so nachgewiesenes Skript;
   kein Szenen-, Knoten-, Raum-, Animations-, Physik- oder Renderbezeichner; kein Zugriff auf Raum- oder Abspiel-Member
   (`.position`, `.transform`, `.play`, `.advance` …); kein dynamischer Zugriff (`.set`, `.call`); jedes geladene Skript ist selbst
   geprüft oder Datenlogik. Berechnete Ladepfade, Szenen und Shader fallen nie darunter; Kommentare und Zeichenketteninhalte zählen nicht.
   Alles andere blockiert unverändert.
2. Die Abschlusszeile des Gates weist `inventory_blockers` und `motion_blockers` getrennt aus. Läufe verschiedener Branches werden über
   `motion_blockers` verglichen.

Geprüft gegen die parallelen Arbeitsbäume (nur gelesen): `soldier_roster`, `troop_catalog`, `combat_formula`, `actor_relations`,
`world_calendar`, `era_registry`, `campaign_timeline`, `time_jump_participant`, `troop_motion` (Grenzwerttabelle), `raider_strike`,
`resident_identity` gelten als Datenlogik. Weiter ausdrücklich zu klassifizieren – von dem Branch, der sie einführt – sind
`tribal_world` (Vector2-Positionen), `time_jump_contract` und `calendar_ageing_participant` (`.advance`), `formation_agents`,
`formation_levels`, `raid_route`, `resident_look`, die Melee-Presenter und jeder Shader. Die Regel ist bewusst vorsichtig: ein Skript,
das Raumtypen rechnet, bleibt prüfpflichtig, auch wenn es selbst keinen Knoten anfasst.

Damit sinken die drei beobachteten Abweichungen auf diesem Regelstand von +2 / +2 / +6 auf 0 / +1 / +2; der Rest sind echte,
einmalige Klassifizierungen. Tests: `tests/motion_quality_gate_test.py` (18 Tests, darunter 22 Positiv-/Negativfälle der Regel).

## 3. Klassen und Zählung

| Klasse | Ursache | #87 | #95 (Basis) | Head |
|---|---|---|---|---|
| A1 | Inventar: statisches GLB ohne Vertragsklasse | 33 | 33 | **0** (Gate-Lauf) |
| A2 | Inventar: Laufzeitskript/Shader ohne Vertragsklasse | 40 | 40 | **0** (Gate-Lauf) |
| A3 | Inventar: Modus-Einstiegsszene ohne Vertragsklasse | 5 | 5 | **0** (Gate-Lauf) |
| A4 | Inventar: privates CI-Asset (Youth, Stadtpaket) | 6 | 6 | 6 in CI, 4 lokal |
| B1 | Standfußgleiten: Kompanie-Angriff im Battle-Rig | 17 | 17 | offline 0, Engine offen |
| B2 | Standfußgleiten: Kompanie-Clips über VillagePerson | 75 | 71 | Angriff/Training offline 0; Todesclip-Rest erwartet; Engine offen |
| B3 | Standfußgleiten: zivile Frontier-Varianten | 24 | 6 | offline 0, Engine offen |
| B4 | Standfußgleiten: Hero-Tritte | 9 | 5 | implementiert, Engine offen |
| B5 | Standfußgleiten: Spieler (Youth) in der Weltfixture | 2 | 2 | 2 (unverändert, siehe 5) |
| C1 | Hautkanten: Frontier-Militär | 49 | 37 | offline 0, Engine offen |
| C2 | Hautkanten: zivile Frontier-Varianten | 14 | 12 | offline 2–3 (`civilian_woman_1`), Engine offen |
| D1 | Loop-Naht `retreat` über VillagePerson | 48 | 48 | implementiert, Engine offen |
| E1 | Weltübergang Position (village_navigation) | 13 | 13 | 13 (siehe 5) |
| E2 | Weltübergang Rotation (village_navigation) | 10 | 10 | 10 (siehe 5) |
| E3 | Weltübergang (raid_motion) | 7 | 7 | 7 (Raid-Agent) |
| F1 | Ausrüstung: Durchdringung | 10 | 10 | 10 |
| F2 | Ausrüstung: ungültige Probe (offene Meshes) | 8 | 8 | 8 |
| G1 | LOD-Wechsel Fernreihe ↔ Nah-Rig | 5 | 5 | 5 (Formation-Branch) |
| H1 | Sichtprüfung fehlt | 12 | 12 | 12 |
| I1 | offene Vertragsanforderung | 4 | 4 | 4 |
| S1 | Sohlendurchdringung Tod/Hocke | 116 | 0 | 0 |
| S2 | Skelettprobenfehler Frontier-Laufzeit | 80 | 0 | 0 |
| | **Summe** | **587** | **351** | **nicht gemessen** |

„Gate-Lauf“ = `python3 tools/motion_quality_gate.py --evidence <leer>` auf dem Head: `inventory_blockers= 4`.
„offline“ = CPU-Nachmessung der exportierten GLB-Clips mit dem Gate-Kriterium, keine Engine.

Zählweise: eine Zeile `MOTION_GATE_BLOCKER` = ein Blocker. Das Gate meldet denselben Grenzwertverstoß je Subjekt und Szenario
(z. B. `attack_guard_reaction` und `contact_and_weight`) und zusätzlich auf Familienebene; deshalb erzeugt eine Ursache meist mehrere Zeilen.

## 4. Behobene Ursachen

| Commit | Klasse | Ursache | Korrektur | Nachweis |
|---|---|---|---|---|
| 7611118 | A1–A3 (78) | Pfade nie klassifiziert | 33 GLBs nach `inspect_static_glb` als statisch, 40 Skripte/Shader registriert (vier Stadt-Personentreiber mit offener Anforderung), fünf Modus-Szenen als Support mit Strukturprüfung | Gate-Lauf: 84 → 4 lokal; Unit-Test |
| 1a35d55, 19d5c62 | B1, B2, B3 | `art/soldiers/build.py`: Angriff/Training drehen den linken Oberschenkel um 11,6° bei starrem Becken, die Sohle wischt 6–19 cm | erster Thigh_L-Key über den Clip, 54 Exporte | offline Sohlengleiten 0,062–0,187 m → 0,0000 m; `tests/attack_lead_foot_test.py`; Engine offen |
| 8f5dce0 | B4 | Trittfuß senkt sich auf einer Geraden und läuft im Kontaktband noch 2 cm | Fuß hebt zuerst, reist erst frei vom Boden | Engine offen |
| 66a5f38 | D1 (48) | VillagePerson spielte den Rückzug als stehende Einmalaktion, der Fußlock behandelte ihn als Gang: 0,72 m / 58° Nahtfehler | Rückzug läuft schrittsynchron wie Marsch/Lauf; Messung treibt ihn mit echtem Wurzelweg | Engine offen |
| 58786f9, aeeed93 | C1, C2 | Tunika-Achsel: Nachbarvertices ganz an Arm_L bzw. Spine/Pelvis gebunden | lokale Nachbarmischung nur der gerissenen Vertices, für Zivil-LODs sanftere Stufen; Export nur, wenn keine Kante reißt und kein Körperpunkt weiter durchkommt | offline: 12 Militär-Exporte 25–1297 → 0, fünf Zivil-Exporte 25–33 → 0; `civilian_woman_1` abgelehnt (Körper +2 mm), unverändert |
| 82af7cd | Zähldrift | siehe Abschnitt 2 | strukturelle Datenlogik-Regel, getrennte Summen | 18 Unit-Tests |
| 2744c3a | Diagnose | — | Weltbeobachter speichert zusätzlich Wurzelschritt und wurzelrelativen Knochenschritt; keine Gate-Metrik geändert | Syntaxprüfung; Engine-Lauf offen |

## 5. Offene Ursachen mit Befund

Quelle der Befunde: Diagnosefelder des Messberichts `scratchpad/qa/engine-seam-meshy/motion-measurements.json` (Stand df15a2e) und
ein Diagnoselauf der unveränderten Weltfixture auf diesem Branch (`scratchpad/motion/wd3.log`, frische Importe).

**E1/E2 village_navigation, E3 raid_motion (30 Zeilen).** Alle Höchstwerte fallen in ungestörte Gangzyklen: gleicher Clip, kein
LOD-Wechsel, keine Wurzeldrehung. Die Metrik `max_transition_position_jump_m` misst im Weltbeobachter den Weltschritt jedes Knochens
je 60-Hz-Bild, also Geschwindigkeit: 0,06 m entsprechen 3,6 m/s.
- Position: Schon ein Bewohner, der mit 0,9 m/s geht, erreicht 0,0725 m (Knie des Schwungbeins: 0,058 m relativ zur Wurzel + 0,015 m
  Wurzelweg). Begleiter im Lauf mit 4,1 m/s erreichen 0,15–0,19 m. Dasselbe Profil erlaubt der Wurzel 0,12 m je Bild
  (`max_root_step_m`); beide Grenzen können bei einem Körper, der schneller als 3,6 m/s reist, nicht zugleich gelten. Das ist kein
  Animationsfehler, sondern eine Eigenschaft der Messgröße. **Nicht geändert** (D-039); Vorschlag unter 7.
- Rotation (22–23° je Bild): echter Befund. Der Laufclip dauert 0,72 s und deckt 1,49 m (Zivil, × 1,14 Körpermaß) bzw. 1,75 m
  (Kompanie) je Zyklus, also 2,1–2,4 m/s. Begleiter holen mit 4,1 m/s auf (`companion_world.gd`), der Clip läuft dafür 1,7–2-fach
  beschleunigt: 4,8–5,5 Schritte je Sekunde. Abhilfe ist ein Sprintzyklus mit etwa 3 m Zykluslänge (Asset-Arbeit an den
  Erwachsenen-Rigs) oder eine geringere Aufholgeschwindigkeit (Spielentscheidung).
- `dialogue_transition` 0,0857 m: beim Ansprechen wechselt Marcellus in 0,12 s von der Arbeits- in die Gesprächshaltung; der ganze
  Körper verschiebt sich dabei bis 4,9 cm je Bild und stoppt abrupt, im nächsten Bild springt das Knie des Wendeschritts um 9,8 cm.
  Ursache ist die feste Überblendzeit unabhängig vom Haltungsabstand. Vorbereitete, **nicht umgesetzte** Korrektur: Überblenddauer
  in `CharacterMotion.capture_transition/_blend_transition` aus dem Haltungsabstand ableiten (Becken ≤ ca. 1 m/s, Gelenke ≤ ca.
  420°/s), nur für ruhige Zielaktionen (idle/talk/work), damit Kampfreaktionen nicht verzögert werden. Ein Versuch, nur das Anheben
  des Wendeschritts zu glätten (sin²), verschlechterte den Wert und wurde verworfen.

**B5 Spieler (Youth), 0,185 m.** Das Gleiten wächst in den ersten 0,4 s des Anlaufens, während die Geschwindigkeit von 0 auf
1,45 m/s steigt; danach bleibt es stehen. Der Youth-Gang korrigiert den Standfuß bewusst nur bis 7,5 cm und nur in der mittleren
Standphase (`plant_world_feet`, `preserve_authored_roll`). Betrifft das private Youth-Asset; nicht bearbeitet.

**F1/F2 Ausrüstung (18 Zeilen).** Schnittpunkte liegen an Hand, Handgelenk und Hüfte (z. B. Gladius bei `cut_inward` Phase 0,
Signum schon im Stand). Ausgenommen ist nur eine Kugel von 8 cm um den Griffpunkt; die gemeldeten 0,13–0,43 m sind die konservative
AABB-Obergrenze, nicht die Eindringtiefe. F2: Scutum, Gladius, Rundschild, Signum-LOD1 und Axt-LOD1 sind offene oder uneinheitlich
orientierte Meshes, für die der Einschlussnachweis nicht geführt werden kann. Nötig: geschlossene Prop-Meshes und überarbeitete
Halteposen. Nicht bearbeitet.

**G1 LOD-Wechsel (5 Zeilen), 0,138 m.** Der Höchstwert entsteht im ersten Bild nach einem Gangwechsel, solange das Nah-Rig noch
0,12 s überblendet, die Fernreihe aber schon den neuen Gang zeigt. Der Formation-Branch führt `Soldier.switch_ready()` ein und hält
den Wechsel bis zum Ende der Überblendung; die Fixture muss danach nur wechselbereite Zustände vergleichen. Hier nicht dupliziert.

**C2 `frontier_civilian_woman_1`.** Jede lokale Gewichtsmischung (auch 15 % nur auf den gerissenen Vertices) lässt den Körper 2 mm
weiter durch die Tunika treten. Braucht Gewichtsmalerei an der Quell-Tunika.

**B2 Todesclips.** Nach der Erdung aus #88–#95 bleibt eine Fersenrolle von 0,016–0,039 m offline messbar (Grenze 0,015).

## 6. Sichtprüfung (H1) – Vertrag und Stand

Das Gate verlangt je aktiver Familie genau einen Datensatz in `quality/motion_reviews.json` mit `status: approved`, nicht leerem
`reviewer`, `source_fingerprint` gleich dem SHA-256 über **alle** Projektbytes unter `prototype/` (plus Gate-, Prüf-, Build- und
Capture-Werkzeugen und Workflow), allen `review_scope`-Szenarien und Videoaufnahmen unter `docs/` (mp4/webm/gif, > 1 KiB, mit
ffprobe fehlerfrei dekodierbar, ≥ 0,5 s, ≥ 2 Bilder, ≥ 32 px, SHA-256 passend), die zusammen alle Szenarien abdecken.
`docs/19_motion_combat/MOTION_QUALITY_GATE.md` verlangt ausdrücklich eine Beurteilung anhand der Aufnahmen und „keine automatisch
ausgefüllte Zustimmung“; das Handbuch (Masterhandbuch 3.0) sieht „Video und metrische Logs für Fable“, für Kinoszenen „zwei unabhängige
Reviews“ und für die Renderer-QA „menschliche Art-Abnahme“ vor. `tools/characters/capture_motion_quality.py` erzeugt nur Aufnahmen und
nie einen Freigabeeintrag.

Daher wurde **kein Review-Datensatz geschrieben**:
- Jede aktive Familie verletzt noch numerische Grenzwerte oder offene Anforderungen (außer `cinematic_people`). Eine Freigabe von
  Gewicht, Rhythmus und Körpermechanik wäre für diese Bytes sachlich falsch.
- Der Fingerabdruck umfasst den ganzen Prototyp. Jeder weitere Commit eines der parallelen Branches macht jede heute geschriebene
  Freigabe ungültig. Aufnahmen und Review gehören an den eingefrorenen Release-Kandidaten, nachdem die numerischen Blocker weg sind.
- Die Freigabe ist eine Qualitätsentscheidung einer unabhängigen Prüfinstanz (Fable bzw. menschliche Abnahme), nicht des Agenten,
  der die Bewegung selbst geändert hat. **Eigentümerentscheidung**: wer die zwölf Familien am Release-Kandidaten abnimmt.

## 7. Eigentümerentscheidungen

1. **Sichtprüfung:** Wer nimmt die zwölf Familien am eingefrorenen Release-Kandidaten ab (Abschnitt 6)?
2. **Private Assets (A4):** `hero_meshy_italia_*` und das Stadtpaket sind nur in CI vorhanden. Ein Vertragseintrag bräche jeden
   Checkout ohne diese Dateien („Registered runtime resource missing“). Entweder die Dateien ins Repository aufnehmen oder der
   Vertrag bekommt eine geprüfte Klasse „optional vorhanden, dann voll gemessen“.
3. **Weltübergang Position:** Soll der Weltbeobachter den Knochenschritt künftig ohne den eigenen Wurzelweg des Akteurs messen
   (Wurzelweg bleibt über `max_root_step_m` begrenzt)? Der Diagnosewert wird seit 2744c3a mitgeschrieben. Ohne diese Entscheidung
   kann kein gehender oder laufender Mensch die 0,06 m einhalten. Der Grenzwert selbst bliebe unverändert.
4. **Aufholgeschwindigkeit der Begleiter:** Sprintzyklus bauen oder 4,1 m/s senken?
5. **Datenlogik-Regel (82af7cd):** Sie ersetzt für nachweislich reine Datenskripte die ausdrückliche Liste. Wenn die ausdrückliche
   Liste ausnahmslos gewünscht ist, genügt es, den Aufruf von `data_logic_scripts` zu entfernen; die getrennte Zählung bleibt nützlich.

## 8. Messprotokoll

| Befehl | Ergebnis |
|---|---|
| `python3 -m unittest tests.motion_quality_gate_test` | 18 Tests OK |
| `python3 -m unittest tests.frontier_tunic_seam_test.TunicSeamJsonTest` | OK |
| `python3 tools/motion_quality_gate.py --evidence <leer>` (Head) | `blockers= 149 … inventory_blockers= 4 motion_blockers= 145`; ohne Engine-Nachweis, nur für das Inventar aussagekräftig |
| `smooth_frontier_skirt_seam.py --cloth HeroTunic` auf fünf Zivil-Exporten | vier geschrieben (Reißen 25–33 → 0), einer abgelehnt |
| Godot `--check-only` auf `motion_world_measurement.gd` | ohne Fehler |
| Weltfixture-Diagnose (leichte Spur, frische Importe) | reproduziert #95: `dialogue_transition` 0,0857 m, `walk_run_stop` Standfuß 0,1854 m |
| `check_prototype.py --only motion_measurement` (Head) | **nicht gelaufen** – wartete beim Abschluss auf die gemeinsame Sperre |

Technikhinweis zur vorbereiteten Überblendkorrektur: Übergänge aus dem Haltungsabstand statt mit fester Dauer zu führen entspricht
dem Stand der Technik (Inertialisierung, D. Bollo, GDC 2018, „Inertialization: High-Performance Animation Transitions in Gears of
War“); Godots `AnimationPlayer` bietet nur lineares Überblenden, deshalb der Ansatz im eigenen Posen-Übergang. Aus dem Gedächtnis
zitiert, in dieser Sitzung nicht nachgeschlagen.

Überschneidungen mit parallelen Branches: `village_person.gd` (People- und Raid-Agent ändern andere Stellen als 66a5f38),
`build_frontier_people.py` und `quality/motion_contract.json` (People-Agent), `art/frontier_people/build_report.json`. Die
Tunika-Einträge des Build-Reports wurden vom Nahtwerkzeug nachgetragen, nicht durch einen Blender-Neubau; ihr Schlüsselformat
weicht von dem ab, was `build_frontier_people.py` beim nächsten Neubau schreibt.
