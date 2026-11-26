# Motion-Gate – Blocker-Register (D-039)

Stand 26.11.2026, Branch `feat/motion-gate-blockers-20261126` (Basis 89e735d + Reparaturstapel df15a2e = PR #88–#95).
Gate: `tools/motion_quality_gate.py`, Messung: `prototype/tests/motion_quality_measurement.gd` (+ `motion_world_measurement.gd`,
`motion_equipment_measurement.gd`, `motion_skin_measurement.gd`). Alle Grenzwerte, Profile, Szenarien und Sichtprüfungsregeln sind
unverändert; dieses Register ändert keinen Grenzwert.

<!-- RESULT -->

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

<!-- TABLE -->

Zählweise: eine Zeile `MOTION_GATE_BLOCKER` = ein Blocker. Das Gate meldet denselben Grenzwertverstoß je Subjekt und Szenario
(z. B. `attack_guard_reaction` und `contact_and_weight`) und zusätzlich auf Familienebene; deshalb erzeugt eine Ursache meist mehrere Zeilen.

## 4. Behobene Ursachen

<!-- FIXES -->

## 5. Offene Ursachen mit Befund

<!-- OPEN -->

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

<!-- DECISIONS -->

## 8. Messprotokoll

<!-- PROTOCOL -->
