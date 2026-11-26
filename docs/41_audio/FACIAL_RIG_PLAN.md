# Gesichtsrig-Plan für Erwachsene und Kinder

Stand: 26.11.2026 · Status: **Plan** (nicht umgesetzt), außer wo ausdrücklich „implementiert“ steht.

## 1. Ausgangslage im Repository

| Figurengruppe | Gesichtsdaten heute | Quelle |
|---|---|---|
| Ursprünglicher Jugendlicher (Meshy, privat, nicht im Checkout) | 35 Joints inklusive `Jaw` | Auftrag; Dateien liegen nicht in diesem Arbeitsstand |
| Erwachsene Meshy-Figuren | 15 Joints, **kein** Kiefer, keine Gesichtsmorphs | Auftrag |
| Frontier-Figuren und Hero-Qualitätsmodell (eigene Blender-Modelle) | Morphs `Blink_L`, `Blink_R`, `JawOpen`, `Smile`, `BrowDown` (+ `Mature`, `Companion`) | [DELIVERY.md, „Mimik“](../14_character_realism/DELIVERY.md); `prototype/scripts/visuals/facial_motion.gd` |

**Implementiert in diesem Branch:** `prototype/scripts/audio/face_driver.gd` liest phonemgenaue Visemspuren und treibt – je nachdem, was ein Modell besitzt – (a) einen `Jaw`-Knochen, (b) Blendshapes `viseme_*` (15er-Satz), (c) ARKit-Namen (`jawOpen`, `mouthFunnel`, `mouthPucker`, `mouthClose`, `mouthStretch*`, `mouthRollLower`, `mouthPress*`), (d) die generischen Formen `jaw_open`, `lip_round`, `lip_wide`, `lip_close`, `lip_tuck` und (e) die vorhandenen Morphs `JawOpen`, `Blink_L`, `Blink_R`. Getestet ist das am prozeduralen Testkopf (Knochen + Blendshapes); die Einbindung in `village_person.gd`/`soldier_visual.gd` ist **noch nicht** erfolgt.

Grenze heute: Figuren, die nur `JawOpen` haben, können Lippenrundung (o/u/ü), Lippenschluss (p/b/m) und Labiodentale (f/w) **nicht** zeigen. Für die 15-Joint-Erwachsenen ohne Kiefer und ohne Morphs ist keine Mundbewegung möglich.

## 2. Ziel-Rig für Erwachsene (Vorschlag)

Hybrid aus wenigen Knochen und einem kleinen Blendshape-Satz. Begründung: Der Kiefer ist eine Rotation um das Kiefergelenk – als Knochen exakt, billig und retargetbar; Lippenformen sind weiche Gewebeverformungen – als Blendshapes besser als zusätzliche Knochen.

**Zusätzliche Joints (5):** `Jaw` (Drehpunkt am Kiefergelenk, vor dem Ohr), `Eye_L`, `Eye_R` (Blickrichtung), `Lid_Upper_L/R` optional nur in LOD 0 – sonst Lidschluss als Blendshape.

**Blendshapes, Pflicht (12):**

| Gruppe | Formen | Treiber im Code |
|---|---|---|
| Lippen | `mouthClose` (p/b/m), `mouthFunnel` (o), `mouthPucker` (u/ü/sch), `mouthStretchLeft/Right` (i/s), `mouthRollLower` (f/w), `mouthUpperUp` (Zähne zeigen bei a/e) | `face_driver.gd` – vorhanden bis auf `mouthUpperUp` |
| Augen | `eyeBlinkLeft/Right`, `eyeSquintLeft/Right` | Blinzeln vorhanden, Squint offen |
| Ausdruck | `browInnerUp`, `browDown` | an bestehende `facial_motion.gd`-Ausdrücke koppeln |

Die Namen folgen dem verbreiteten ARKit-Satz (52 Formen, [Apple-Dokumentation `ARFaceAnchor.BlendShapeLocation`](https://developer.apple.com/documentation/arkit/arfaceanchor/blendshapelocation)), damit spätere Gesichtsaufnahmen oder Werkzeuge direkt passen. Der vollständige 52er-Satz ist für das Android-Budget nicht nötig.

**Kinder:** Gleicher Satz; Proportionen (größere Augen, kürzere Mundbreite, flacheres Kinn) über die Basisgeometrie, nicht über eigene Formen. Kiefer-Maximalwinkel 11° statt 13° (`jaw_max_angle`).

## 3. Verhalten

| Kanal | Regel | Quelle / Begründung | Status |
|---|---|---|---|
| Mund | Visemspur aus erzwungener Phonemausrichtung, Koartikulation durch überlappende 60/80-ms-Rampen, Schnittpunkt 0,5 exakt auf der Phonemgrenze | `face_driver.gd`, Test `dialogue_lipsync_test.gd` | implementiert, getestet am Testkopf |
| Kiefer | 0–13° Rotation; „a“ = voll, „i“ ≈ 0,28, Bilabiale fast geschlossen | Annahme: Sprechöffnung deutlich unter der maximalen Mundöffnung; an Referenzvideo zu prüfen | implementiert |
| Blinzeln | Ruhe ≈ 17/min, Gespräch ≈ 26/min; 150 ms (60 ms zu, 90 ms auf) | Bentivoglio et al. 1997, *Movement Disorders* 12(6): 1028–1034 | implementiert (wenn Formen vorhanden) |
| Blinzeln an Phrasengrenzen | Blinzeln bevorzugt in Pausen ≥ 250 ms der Visemspur | Plan | offen |
| Blick | Sakkaden zum Gesprächspartner alle 1,5–4 s, Wechsel Auge–Mund–Auge; Lidschluss folgt großen Blickwechseln | Plan; benötigt `Eye_L/R` | offen |
| Atmung | Ruhe 12–20 Atemzüge/min über Brust-/Schulterknochen (Skalierung 1–2 %); beim Sprechen schnelles Einatmen in Pausen ≥ 300 ms vor der nächsten Phrase, langsames Ausatmen während der Phrase | Plan; Sprechatmung koppelt an Pausen der Visemspur | offen |

## 4. Mobile-Budget (Android, GL Compatibility)

- Nur Figuren mit Detailstufe 0 (Nahbereich, wie `facial_motion.gd`) erhalten Lippensynchronität; Detailstufe 1 nur Kiefer; ab 2 keine Gesichtsupdates.
- Gleichzeitig sprechende Figuren: eine Hauptzeile, maximal zwei Umgebungsstimmen.
- **Nicht gemessen:** Kosten der Blendshape-Auswertung im Compatibility-Renderer auf dem Zielgerät. Vor der Einbindung in alle Dorfbewohner ist eine Messung auf dem Gerät nötig (Bildzeit und Temperatur, Vergleich mit/ohne Gesichtsupdates).

## 5. Arbeitspakete

1. `face_driver.gd` in `village_person.gd`/`soldier_visual.gd` als Sprechquelle einhängen; `facial_motion.gd` behält Ausdruck und Blinzeln, solange keine Zeile läuft, und überlässt `JawOpen` während einer Zeile dem Treiber.
2. Blender: für die Frontier-Figuren die sieben Lippenformen aus Abschnitt 2 modellieren (Basis: vorhandene Topologie um den Mund), exportieren, Morphdeltas prüfen wie in DELIVERY.md.
3. Erwachsene Meshy-Figuren: Entscheidung, ob `Jaw` + Augen ergänzt oder die Figuren durch eigene Köpfe mit dem Satz aus Abschnitt 2 ersetzt werden (Eigentümerentscheidung, siehe Bericht).
4. Jugendlicher (privat): `Jaw` ist vorhanden; Lippenformen fehlen laut Auftrag → bis dahin nur Kiefer.
5. Blick und Atmung nach Abschnitt 3, Messung nach Abschnitt 4.
