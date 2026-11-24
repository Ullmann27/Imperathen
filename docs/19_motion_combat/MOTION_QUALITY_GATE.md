# IMPERATHEN – verbindlicher Bewegungs- und Freigabestandard

Dieser Vertrag gilt für alle aktuellen und künftigen beweglichen Figuren, Tiere, Reittiere, Waffen, Geräte, Räder, Fahrzeuge und mechanisch animierten Gegenstände. Die Datei `quality/motion_contract.json` registriert vorhandene Ressourcen und ausführbare Quellen ausdrücklich. Ein neuer, nicht klassifizierter Modell-/Szenen-/Skriptpfad blockiert den unterstützten APK-Bau. Statische Meshes dürfen keine animierten Skins oder Clips verstecken. Rohquellen bleiben vom Export ausgeschlossen.

## 1. Verbindliche Freigabe

1. Tatsächliche Engine-/Szenenprüfungen; keine Syntax- oder Dateinamenprüfung als Bewegungsnachweis.
2. Numerische Messung bei 60 Hz über vollständige Clips. Gelenksegmentfehler höchstens 5 mm; Loop-Sprung höchstens 3 cm bzw. 12 Grad; keine ungültigen Transformationswerte oder eingefrorenen vorgeschriebenen Bewegungsclips. Projektgrenzwerte für linear/angular speed sind im Gate in m/s und Grad/s festgelegt.
3. Bewegungsfamilien müssen eigene Messnachweise für sämtliche registrierten Modelle und Szenarien liefern. Fuß-/Hufkontakt, Durchdringung, Griff-/Sitzpunkte, Übergänge, Räder und mechanische Gelenke haben getrennte Grenzwerte. Keine Übertragung eines bestandenen Tests auf eine andere Familie.
4. Visuelle Prüfung der realen Modellbewegung: Gewicht, Rhythmus, glaubwürdige Körpermechanik, Griff, Kollision, Übergänge und sichtbare Fern-LOD-Bewegung. Für jede aktive Familie ist ein freigegebener, quellbytegebundener Prüfdatensatz mit überprüfbaren Bewegungsaufnahmen erforderlich. Ein numerischer Pass ersetzt die Sichtprüfung nicht.
5. Nur bei vollständig bestandenem Gate darf der unterstützte Android-Export laufen. Release erfordert zusätzlich Paketprüfung und Android-Laufzeitprüfung.

Die konkreten Zahlen sind konservative projektinterne Akzeptanzschwellen, keine universellen physiologischen Grenzwerte. Sondermechaniken müssen über explizite eigene Profile mit physikalisch begründeten Messgrößen aufgenommen werden, nicht über Ausnahmen oder stilles Umbenennen zu statischen Objekten.

## 2. Spezifische Regeln

- Mensch: Stand/Sprache/Atmung, Gehen/Laufen, Anhalten/Starten/Drehen, Arbeit, Kampf, Reaktionen; maximal 15 mm Standfußdrift, 10 mm ungewollte Bodendurchdringung; keine Hautkantenverletzung.
- Tier: eigene anatomische Gangarten, Huf-/Pfotenauflage und Kopf-/Schwanzführung, Beschleunigung und Wendung; keine kopierten menschlichen Gänge.
- Reiter: getrennte Pferde- und Reiterskelette, Sitz-, Zügel- und Beinanker sowie phasenkonsistente Bewegungen, Auf-/Absteigen. Ein verbundenes Pferd-Reiter-Standmesh erfüllt keinen Reitvertrag.
- Getragene Waffen/Props: echte animierte Socket-Bindung, maximal 2 mm Grip-Drift, maximal 2 Grad Orientierungsfehler relativ zur Sollbefestigung, Clearance und gültige Ausrüstungsfreigabe.
- Wagen, schiebbare Geschütze und andere Fahrzeuge: Radumfang/Drehung müssen tatsächliche Translation erklären, maximal 3 % Rollwegfehler; Achsen und Bodenauflage bleiben zusammen; Anfahren/Bremsen ohne unkommandierten Geschwindigkeitssprung.
- Artikulierte Geräte: Gelenkgrenzen, feste Anker, nachvollziehbare Trägheit, Kollisionsfreiheit, Bediener-Handkontakt.
- Fern-LOD: vereinfachte Bewegung darf nicht zu einem schwebenden oder starren sichtbaren Soldaten führen. Phasen-/Kontaktwechsel von Nah zu Fern separat nachweisen.

Nicht implementierte Pferde-/Tier-/Reit-/Maschinenfamilien bleiben inaktiv und ohne Runtime-Ressourcen. Sie sind kein Grund, vorzutäuschen, dass eine bereits vorhandene Figur geprüft wurde. Bei ihrer Aktivierung müssen alle erforderlichen Messwerte und visuellen Szenarien vorliegen.

## 3. Aktuelle Lücken und Belege

Der neue Gate-Stand beginnt absichtlich ohne fingierte Freigaben. `quality/motion_reviews.json` ist leer. Ausstehende realweltbezogene Kontakt-, Szenen- und Sichtprüfungen bleiben Blocker; insbesondere direkter Snapshot-Positionswechsel der Raid-Angreifer, vereinfachte Fernränge und nicht vollständig vermessene Meshy-/Arbeiter-Gänge. Der bisherige Build 7 bleibt der vorherige Prüfstand, nicht der Nachweis dieses strengeren Standards.

`prototype/tests/motion_quality_measurement.gd` misst die tatsächlich importierten skinned GLBs und den echten Hero-Solver. Die erzeugte Meldung `MOTION_MEASURED` belegt ausschließlich die Messausführung. Die numerische, vollständige und visuelle Freigabe ist `MOTION_QUALITY_GATE_PASS`.

Für eine visuelle Freigabe ist pro aktiver Familie genau ein Eintrag mit `family`, `status: approved`, `reviewer`, `source_fingerprint`, sämtlichen `scenarios` und `captures` (relative Videodatei unter docs/, SHA-256, abgedeckte Szenarien) erforderlich. Tatsächliche Qualität muss anhand dieser Bewegungsaufnahmen beurteilt werden. Keine automatisch ausgefüllte Zustimmung.

## 4. Ausführung

```sh
python3 tools/check_prototype.py --godot godot --keep-going --report artifacts/engine-checks
python3 tools/motion_quality_gate.py --evidence artifacts/engine-checks
```

Der Buildpfad überprüft die Nachweise erneut vor dem Export. Fehlende, veraltete oder abweichende Belege blockieren. Die Veröffentlichung ist separat an die Android-Laufzeitprüfung gebunden. Der Standard ist kein Ersatz für eine physische Fold7-Leistungs- und Wärmeprüfung. Er ersetzt auch keine Branch-Schutzrechte: Ein Entwickler, der den Gate-Code bewusst umgeht, kann durch diese Dateien allein nicht kontrolliert werden.
