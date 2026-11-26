# Nahkampf Ebene A – Kern, Messwerte, Integration (D-026)

Stand 26.11.2026, Branch `feat/melee-combat-core-20261126` (Basis `ffbe3ad`, dazu per Merge `cae920a` das gemeinsame Kampfwertmodul des Troops-Branches). Umsetzung der verbindlichen Entscheidungen D-026 (**Ebene A**: individuelle Kampfphysik im sichtbaren Nahbereich), D-042 (eine Schadensformel) und D-050 (datengetriebene, epochenunabhängige Waffen, Kampfereignisse für den Ton). Ebene B (Formation) und C (Verband) sind nicht Teil dieses Branches; die Schnittstellen dafür sind unten beschrieben. Ryse (filmische Dynamik) und Bannerlord (Einzelkampf) dienen nur als Qualitätsmaßstab; nichts daraus ist übernommen.

Kernregel: **Kein Schaden vor dem sichtbaren Treffer.** Kontakt wird nicht mehr zeitlich geplant, sondern Frame für Frame aus der tatsächlich angezeigten Waffen- bzw. Körpergeometrie berechnet.

## 1. Befund vor der Änderung (gemessen, nicht geschätzt)

| Messung | Ergebnis |
|---|---|
| Spieler-Autorität `combat_actions.gd` (Basis) | Schaden ab Beginn des *autorisierten* Aktivfensters, 0–5 Frames (bis 83 ms) **vor** dem sichtbaren Bewegungshöhepunkt; Reichweitenprüfung mit Mittelpunktabständen von 0,85–2,00 m, obwohl Faust/Fuß/Kopf nur 0,38–0,88 m vor der Körperachse ankommen (Tabelle 3). |
| Bisherige Gladius-Präsentation (`character_motion.gd`, `armed_pose`) | Klinge bleibt in allen fünf Schwertstilen nahezu senkrecht: Spitze 1,86–2,16 m hoch, nach vorn nur 0,02–0,74 m (`FINDINGS.legacy_armed_pose/*`). Ein „Stoß“ zeigt keine nach vorn gerichtete Klinge. |
| Importierter Meshy-Axtkämpfer-Clip `attack` (+15 % Overlay) | Axtkopf maximal 0,24 m vor der Körperachse, Sprünge bis 0,18 m innerhalb eines 60-Hz-Frames (`FINDINGS.legacy_meshy_attack_clip/overhead`). |
| Schlachtrig `soldiers/spear_near.glb`, Clip `attack` | Speerspitze maximal 0,21 m vor, aber 0,95 m **hinter** dem Akteur (`FINDINGS.legacy_soldier_spear_attack_clip`). |

Aus diesen Clips lassen sich ehrliche, aber für Nahkampf unbrauchbare Kontaktframes ableiten. Deshalb wurden für Ebene A eigene, vermessene Schlagbewegungen gebaut (Abschnitt 2.2). Die alten Clips und `character_motion.gd` bleiben unverändert erhalten.

## 2. Aufbau

### 2.1 Module

| Datei | Rolle |
|---|---|
| `prototype/scripts/domain/melee/melee_track_data.gd` | **Generiert** von `tests/melee_strike_bake.gd --write`. Pro Bewegung 60-Hz-Spuren des Schlagkörpers (Kapselsegment Basis→Spitze + Radius), Schildrahmen pro Frame, Peak, Live-Fenster, Reichweite, Bogen, Fußgleiten, Gewichtsverlagerung; pro Ausrüstung Körperkapsel, Zonenhöhen, Schildmaße. |
| `prototype/scripts/domain/melee/melee_tracks.gd` | Lesezugriff, Zeit→Frame, gemeinsamer Körper-Sweep (`sweep_body`), Antriebsgeschwindigkeit. |
| `prototype/scripts/domain/melee/melee_geometry.gd` | Segment-Segment-Abstand, Segment-gegen-Box (Schild), Welttransformation, Richtungsklassen, deterministischer FNV-Hash. |
| `prototype/scripts/domain/melee/melee_core.gd` | Ebene-A-Autorität: Kämpfer, Befehle, 60-Hz-Schritte, Kontakt, Block/Parade, Ausweichen, Reaktionen, Ausdauer/Ermüdung, Verletzungen, Moral, Ereignisse. |
| `prototype/scripts/domain/melee/melee_ai.gd` | Deterministische Entscheidungshilfe für NPC-Kämpfer: Annäherung auf gemessene Reichweite, **Öffnung erkennen** (`Core.preview_strike`: welcher vermessene Schlag erreicht von hier aus den Körper statt Schild oder Luft), Schlagwahl nach Stil, Schlag auf die eigene Schlaglinie ausrichten (`Core.aim_yaw`), Deckungsstil aus Lage der gegnerischen Waffe, Ausweichen, Rückzug bei Erschöpfung (langsamer als Vorgehen), Nachsetzen auf einen weichenden Gegner, geseedete „Lese“-Chancen. Ändert nichts selbst; Anwendung über `Core.command/place`. |
| `prototype/scripts/domain/melee/melee_damage.gd` | Einzige Tür der Ebene A zum Schaden: übersetzt einen Kern-Kämpfer in die Eingaben des gemeinsamen Moduls `scripts/battle/combat_formula.gd` (D-042, siehe 6.2). Enthält keinen Balancewert und keine eigene Rechnung. |
| `prototype/assets/combat/weapons.json` + `scripts/domain/melee/weapon_catalog.gd` | Waffen als reine Daten (D-050): Klasse (unbewaffnet, Nahkampf, Wurf, Bogen, Armbrust, Schleuder), Mechanismus, Materialien, physikalische Werte, Epoche, `balance_family`. Der Kern nennt keine Waffe beim Namen (siehe 2.7). |
| `prototype/scripts/domain/melee/melee_ranged.gd` | Geschossmechanik: Abflug, ballistischer Flug mit Luftwiderstand, widerstandskorrigiertes Zielen, fertigkeitsabhängige Streuung. Reine Funktionen; Zustand und Kontakt liegen im Kern. |
| `prototype/scripts/domain/melee/combat_impacts.gd` (+ `combat_impact_hub.gd`) | Ein Signal für Ton und Effekte: normalisierter Datensatz je hörbarem Kampfmoment (Aufprall, Schwung, Ziehen, Lösen, Bruch) mit Material A/B, Energie, Position, Richtung, Waffenklasse, Frame (siehe 2.8). |
| `prototype/scripts/domain/melee/melee_feedback.gd` | Material → Partikel (Funken/Splitter/Staub/Fasern) und Klang-ID, mit Fold7-Budget. |
| `prototype/scripts/visuals/melee_pose.gd` | Ebene-A-Posen auf den 15-Knochen-Rigs (Held, Meshy, Schlachtrig): Schläge, Schilddeckungen, Ausweichschritte, gerichtete Trefferreaktionen, Überblendung. |
| `prototype/scripts/visuals/melee_presenter.gd` | Zeigt einen Kern-Kämpfer exakt zur autoritativen Clipzeit; ändert nie den Zustand. Überblendung zwischen Zuständen (0,14 s, nie in einen Schlag hinein) und Fußarbeit in Grundstellung/Deckung: Füße bleiben in der Welt stehen und schreiten einzeln nach (Auslöser 8 cm, 0,24 s, 7 cm Hub, Landepunkt ab halbem Schritt fest). |
| `prototype/scripts/visuals/melee_camera.gd` | Dynamische, steuerbare Kampfkamera: über die Schulter des fokussierten Kämpfers, beide Körper sicher im Bild, Orbit/Zoom durch den Spieler, kritisch gedämpfte Glättung, energieabhängiger Kamerastoß am Kontaktframe. |
| `prototype/scripts/visuals/melee_impact_fx.gd` | CPU-Partikel-Pool (≤ 6 × 48 Partikel) + 3D-Audio. |
| `prototype/scripts/visuals/melee_impact_audio.gd` | **Prozedural synthetisierte Platzhalter-Klänge, bis echte Foley-Aufnahmen vorliegen** (Metall, Bronze, Holz, Holzbruch, Leder, Kettenhemd, Körper, Luftzug). Keine Downloads. |
| `prototype/scripts/domain/combat_actions.gd` | Bestehende Spieler-Autorität (11-Feld-v1-Save unverändert) nutzt jetzt denselben Kontakt-Sweep und die gemessenen Fenster. |
| `prototype/scripts/world/player_action_world.gd` | Zielauswahl mit gemessener Reichweite je Alter; Schwerttechniken des Spielers werden mit den vermessenen Ebene-A-Posen gezeigt. |

### 2.2 Schlagbewegungen und Messung

- Waffen-Posen (`melee_pose.gd`) werden aus Schlüsselposen mit kubischer Hermite-Interpolation (stetige Geschwindigkeit durch den Kontaktschlüssel), Großkreis-Interpolation für Klingen-, Schneiden- und Schildrichtungen und Zwei-Knochen-IK erzeugt. Stützfüße bleiben exakt stehen; nur ein Schrittfuß bewegt sich angehoben. Ist ein Fuß unerreichbar, wird das Becken abgesenkt statt den Fuß zu ziehen.
- Die Messung (`tests/melee_strike_bake.gd`) liest **nichts Autoriertes**: Faust = Knöchelcluster der Hand-Skin (Bindpose + Griff-Morph `HandGrip`), Fuß = Zehencluster, Kopf = Stirncluster, Gladius = Parierstange bis Spitze aus dem Prop-Mesh (0,608 m Klinge, Halbbreite 0,039 m), Axt = Kopfbereich des Prop-Meshes (0,32–0,50 m am Stiel, Radius 0,080 m), Speer = am `Hand_R` gewichtete Spitzenvertices (1,305 m ab Hand), Schilde aus Prop-Mesh (Scutum 0,778 × 1,198 m, Rundschild Ø 0,66 m) bzw. Skin (Schlachtrig).
- **Animations-Peak** = erster Frame innerhalb 5 mm der maximalen Vorwärtsreichweite der Spitze (Haken, Uppercut und Hochkick plateauen; der Schlag kommt am Plateaubeginn sichtbar an).
- **Live-Fenster** = zusammenhängende Frames um den Peak: vor dem Peak vorwärts (≥ −0,2 m/s) mit ≥ 20 % der Spitzenhöchstgeschwindigkeit oder ≤ 3 cm unter Peak-Reichweite; nach dem Peak ≤ 3 cm unter Peak-Reichweite oder weiter fegend (≥ 20 %, radial ≥ −0,3 m/s); nie innerhalb des eigenen Torsoradius.
- Kontrollgrenzen (Test schlägt fehl, wenn überschritten): Stützfußgleiten ≤ 0,015 m (Motion-Gate „human“), treibender Knochen ≤ 12 m/s (Motion-Gate Rig-Grenze), Becken über der Standlinie.
- Der Check `melee_tracks` misst bei jedem Lauf neu und schlägt fehl, wenn die committeten Daten von der angezeigten Animation abweichen (> 2 mm oder anderer Frame).

### 2.3 Kontakt, Block, Ausweichen

- Je Clip-Frame im Live-Fenster wird das Schlag-Kapselsegment vom vorigen zum aktuellen Frame in ≤ 3-cm-Teilschritten gefegt, zuerst gegen die Schildbox des Gegners (aus dessen aktueller Pose: Deckung, Schlag oder Grundstellung), dann gegen die senkrechte Körperkapsel. Der früheste Teilschritt entscheidet. Treffer, Block und Reaktion tragen genau diesen Frame.
- Gleichzeitige Schläge: Kontakte eines Frames werden gegen den Zustand zu Framebeginn gesucht und danach angewandt (fairer Schlagabtausch).
- Treffer/Block: **Trefferpause nach Aufprallenergie** (log-skaliert wie Lautstärke und Partikel: 2–6 Frames am Körper, +1 am Schild; gemessen Kindergerade 29 J → 4, Gladius-Stoß 43 J → 5, Axt-Überkopf 260 J → 6 Frames), der Clip steht exakt so lange, danach **Rückprall** (`recoil`, 0,30 s) statt Durchschwung durch Körper oder Schild.
- Ein Schild deckt nur, solange der Arm ihn halten kann und er in der Linie steht: unter 5 Ausdauer hängt er (`shield_lowered`), ein Deckungsbruch oder Stolpern reißt ihn für die ersten 80 % der Reaktion aus der Linie (`shield_open`, bei `guard_broken` 29 Frames = 0,48 s). Vorher blockte ein Schild in Grundstellung jeden Frontalschlag, auch bei 0 Ausdauer und mitten im Taumeln.
- Gleichzeitige Kontakte desselben Frames werden beide gebucht, auch wenn der erste den zweiten Angreifer aus dem Schlag wirft (der Kontakt trägt seinen eigenen Schlag; vorher Absturz).
- Parade: Deckung höchstens 0,20 s vor dem Kontakt gehoben → Angreifer `parried` (0,45 s), halbe Ausdauerkosten.
- Ausweichen ist rein geometrisch (Wurzelbewegung 0,55 m zurück bzw. 0,50 m seitlich, keine Unverwundbarkeitsframes); Beinwunde verkürzt auf 60 %.
- Optionaler Weltcheck `world_clear(Vector3, Vector3)` für Wände/andere Personen zwischen Angreiferbrust und Kontaktpunkt.

### 2.4 Reaktionen und Zustand

- Aufprallenergie E = ½ · m_eff · v² mit der **Antriebsgeschwindigkeit** (schnellste Geschwindigkeit des Kontaktpunkts im Live-Fenster bis zum Kontakt; ein früh „gestauchter“ Schlag trägt nur den bis dahin aufgebauten Schwung, zusätzlich ×0,5…1 nach Fortschritt). m_eff steht je Waffe in `weapons.json` (Schätzwerte, nicht gemessen): Faust 1,2 kg, Fuß 3,0, Kopf 4,0, Gladius 1,8, Axt 2,4, Speer 2,2.
- Standfestigkeit = Masse × 1,6 J/kg, ×0,8 im eigenen Schlag, ×0,6 auf einem Bein (Tritt), ×1,2 in Deckung, bis −30 % durch Ermüdung, ×0,7 mit Beinwunde. Verhältnis E/Stand → `absorbed` < 0,15 ≤ `flinch` < 0,5 ≤ `stagger` (0,18 m Schritt) < 1,2 ≤ `stumble` (0,40 m) < 2,2 ≤ `down`. Richtung vorn/hinten/links/rechts relativ zur Blickrichtung; Schrittfuß folgt der Stoßrichtung.
- Eine Reaktion vor dem eigenen Kontakt bricht den eigenen Schlag ab (`interrupted`, 0 Schaden).
- Schaden (D-042, Handbuch S. 79) ausschließlich über das gemeinsame Modul `combat_formula.gd` mit `assets/balance/combat_balance.json`: Waffenbasis × Qualität × Kompetenz × Trefferzone × Schutzfaktor × Kontakt. Ausdauer und Verletzungen wirken nur in der Kompetenz, Verschleiß nur in der Qualität, Rüstung und Verteidigerfertigkeit nur im Schutz. Der Kontaktfaktor ist der physikalische Aufprall am gemessenen Kontaktframe (√(E/E_frei), 0,3–1,3; unabhängig von der Körpergröße). Keine Streuung, kein zweiter Tabellenwert im Kern. Alle Faktoren stehen im Ereignis (`damage_terms`). Schildposition wirkt geometrisch: Trifft der Schlag die Schildbox, ist es ein Block (kein Schaden), bevor die Formel gerufen wird. Verschleiß von Waffe und Rüstung wird aus der Ausgabe der Formel gebucht.
- Verletzungen (geseedet, Chance mit Schaden steigend): Gehirnerschütterung (Tempo −), Blutung (Lebenspunkte/s), Waffenarm (Schaden ×0,75, Tempo −0,10), Schildarm (Blockkosten ×1,4), Bein (Ausweichen ×0,6, Stand ×0,7).
- Ausdauer: Schlagkosten beim Start (Spielertechniken aus `TECHNIQUES`, sonst der Wert der Waffenfamilie aus `combat_balance.json`), Blockkosten 0,10 J⁻¹ × E (3–40), ungedeckt ×1,5; zu wenig Ausdauer → `guard_broken`. Ermüdung wächst mit verbrauchter Ausdauer, senkt Regeneration und ab 0,3 das Tempo.
- Moral 0–100 mit Ereignissen `wavering` (< 35, Tempo −0,08, Regeneration ×0,6) und `breaking` (< 15); `morale_event()` für externe Anlässe (gefallener Kamerad, Offizier, Flucht nebenan).
- Determinismus: 60-Hz-Festschritte mit Restübertrag (beliebige Tick-Aufteilung ergibt identische Ereignisse), Zufall nur über FNV-Hash aus Seed + Zähler. Zustand ist reines JSON (Speichern mitten im Schlag geprüft).

### 2.5 Rückmeldung

- Eisen auf Eisen/Kettenhemd → Funken + `metal_clang`; auf Bronzebuckel → Funken + `metal_ring`; Eisen auf Schildholz → Splitter + Staub + `wood_chop`; Leder/Wolle → Staub + `leather_slap`; Faust/Fuß auf Kettenhemd → `mail_rattle`; Leinen → Fasern + `body_thud`; Luftschlag → `swish`; Schildbruch → `wood_crack`.
- Menge und Lautstärke logarithmisch mit der Energie; höchstens 48 Partikel je Stoß und 6 gleichzeitige Stöße (≤ 288 CPU-Partikel), CPU-Partikel vermeiden Partikel-Shader-Kompilierung im Compatibility-Renderer.
- Klänge sind **synthetisiert und als Platzhalter gekennzeichnet** (`SYNTHESIZED`, Ressourcenname enthält „synthesized placeholder pending recorded foley“). Gemessene Spektralschwerpunkte: Eisen 2809 Hz, Bronze 2414 Hz, Holz 1516 Hz, Körper 513 Hz.

## 2.6 Bezug zur AAA-Vorgabe (Punkt 8 „Kampf und filmische Qualität“)

| Anforderung | Stand in diesem Branch | Nachweis |
|---|---|---|
| Flüssige Übergänge Bewegung/Angriff/Verteidigung | Überblendung zwischen Zuständen, Rückprall statt Durchschwung, Fußarbeit ohne Gleiten beim Annähern, Schlag beginnt auf den tatsächlich gesetzten Füßen | `melee_visual_contact` (Fußarbeit: 0,0000 m Gleiten, 7 Schritte auf 1,8 m; Annäherung + Stoß: 0,0000 m Fußsprung, 0,1 mm Abweichung der Klinge von der gemessenen Spur), Bilder |
| Glaubwürdige Schildführung | Schild in Grundstellung vor dem Körper, fünf Deckungen mit gemessener Schildfläche, Hochdeckung nach oben gewandt | Block-Matrix, Deckungswinkel, Bilder |
| Individuelle Trefferreaktionen | Richtung × Stärke aus Impuls/Standfestigkeit × Trefferzone (Kopf schnellt, Rumpf knickt, Arm dreht die Schulter, Bein knickt ein), Schrittfuß, Abbruch des eigenen Schlags | `melee_core`; `melee_visual_contact`: Kopfdrehung 23,8° (Kopf) gegen 9,7° (Rumpf), 7,6° (Arme), 5,0° (Bein); Beckenabsenkung 0,141 m (Bein) gegen 0,065 m |
| Materialabhängige Treffergeräusche | Metall, Bronze, Holz, Holzbruch, Leder, Kettenhemd, Körper, Luftzug – **synthetisiert, als Platzhalter gekennzeichnet** | `melee_feedback` (Spektralschwerpunkte) |
| Funken, Staub, situationsabhängige Partikel | Funken (Metall/Bronze), Splitter (Holz), Staub, Fasern; Menge nach Energie | `melee_feedback`, Bilder |
| Realistische Waffenhaltung | Klinge/Axt/Speer über die Hand ausgerichtet (vorher senkrechter Gladius), Griffmorph | Befund-Tabelle, Bilder |
| Körperliche Wucht | Ausfallschritt, Beckenabsenkung, Oberkörperdrehung, Trefferpause 2–7 Frames nach Aufprallenergie, Kamerastoß | Bilder, `melee_camera` |
| Individuelle Kampfstile | Römische Haltung (Stoß aus der Hüfte hinter dem Scutum) gegenüber germanischer Haltung (Überkopf-/Diagonalhiebe, Rundschild, näherer Abstand), Speer auf Distanz; Stildaten je Familie in `melee_ai.gd` (Gewichte, Abstand, Lesefähigkeit). **Weitere D-024-Familien (Plänkler, Schwertkämpfer, Reiter, Gefolgschaften) fehlen noch als Rigs** | Tabelle 3, Kampfstil-Messung |
| Dynamische, steuerbare Kamera | `melee_camera.gd` (noch nicht an `game_world` angeschlossen, das gehört nicht zu diesem Branch) | `melee_camera` (69 Prüfungen), Bild `dynamic_camera_block` |
| Synchronität Animation/Treffer/Klang | Ereignis, Partikel und Klang entstehen im selben Frame wie der gemessene Kontakt | `melee_visual_contact`, `melee_feedback` |

**Fehlende Klänge (Bedarf, keine Downloads):** lizenzierte Foley-Aufnahmen für Gladius auf Kettenhemd, Gladius auf Scutum (Holz/Leder/Bronzebuckel), Axt auf Rundschild (Holz/Eisenbuckel), Speer auf Schild, Klinge auf Klinge, Faust/Tritt auf Körper/Leder/Leinen, Schildbruch, Luftzug je Waffe, Körperfall, Schritte auf Erde/Pflaster/Gras im Kampf, Atem/Anstrengung, Schmerzlaute. Bis dahin gelten die synthetisierten Platzhalter.

## 2.7 Waffen als Daten (D-050) und Fernwaffen

- `assets/combat/weapons.json` beschreibt jede Waffe als Datenzeile: `class` (unarmed, melee, thrown, bow, crossbow, sling), `mechanism` (strike, cut_thrust, chop, thrust, throw, draw_hold_release, span_trigger, whirl_release), Materialien (Waffe, Griff, Sehne, Geschosskopf), wirksame Masse bzw. Geschoss (Masse, Abfluggeschwindigkeit, Radius, Luftwiderstand je Meter, bleibt im Schild stecken, verbiegt sich), Phasen, Streuung Anfänger/Könner, Munition, Gültigkeitsjahre und Belegstufe. Schadensbasis und Ausdauerkosten stehen nur in `combat_balance.json` unter `balance_family`.
- Eine Waffe einer späteren Epoche ist ein Eintrag dort plus ihr Balancewert; `melee_core.gd` nennt keine Waffe beim Namen (Test). Als Beispiel liegt die Armbrust als Vorlage bei (Belegstufe `design_assumption`, nicht in 58 v. Chr. verfügbar: `available_in(-58)` liefert sie nicht).
- Nahkampfzeiten kommen ausschließlich aus den vermessenen Schlagspuren. **Die Phasen der Fernwaffen sind gesetzte Werte** (`timing_source: authored`), weil es noch keine Zieh-, Wurf- und Schleuderclips gibt; sobald es sie gibt, muss der Lösungsframe wie beim Nahkampf aus der Hand vermessen werden. Fernwaffen sind deshalb **implementiert und getestet, aber nicht gerendert** (keine Pose, kein Geschossmodell).
- Ablauf im Kern: `draw` (Kosten = Balancewert; Ereignis `draw` im ersten Frame) → `hold` (Ausdauer läuft, über die bequeme Haltezeit hinaus wächst die Streuung, bei Überhalten wird abgesetzt; die gespannte Armbrust hält ohne Kraft) → `release` (das Geschoss entsteht exakt im letzten Frame der Lösephase am Abflugpunkt der Waffe; Ereignis `release`) → `recover`. Ein Treffer während des Ausholens bricht ab, das Geschoss bleibt.
- Flug: Schwerkraft und Geschwindigkeitsverlust je geflogenem Meter bei 60 Hz. Gezielt wird mit der flachen Bahn, korrigiert durch Fliegen des Schusses mit demselben Gesetz (Restfehler < 1 cm auf 30 m). Der Weg jedes Frames wird in ≤ 3-cm-Schritten gegen Schildboxen, Körperkapseln, die Welt (`world_clear`) und den Boden gefegt. **Kein Schaden, bevor die Bahn den Körper erreicht**; der Trefferframe stimmt mit einem unabhängigen Orakel überein. Geschosse treffen jeden, der in der Bahn steht (auch eigene Leute).
- Schild: Pfeil und Wurfspeer bleiben im Holz stecken, das Schleuderblei prallt ab; ein Pilum verbiegt sich und hängt am Schild (`shield_fouled`, jeder weitere Block kostet die Hälfte mehr Ausdauer; Caes. Gall. 1,25). Nicht modelliert: Durchschlag durch den Schild in den Körper, Vorhalten auf bewegte Ziele.
- Schaden über dieselbe Formel mit `ranged` (die Waffenfertigkeit des Verteidigers pariert keine Geschosse); Kompetenz und Ausdauer des Schützen zählen zum Zeitpunkt des Lösens, der Kontaktfaktor ist die Restenergie gegenüber der Abflugenergie.

## 2.8 Kampfereignisse für Ton und Effekte (D-050)

```gdscript
const CombatImpacts = preload("res://scripts/domain/melee/combat_impacts.gd")
CombatImpacts.connect_listener(audio.play_impact)     # func play_impact(record: Dictionary)
```

`Core.step()` veröffentlicht je hörbarem Moment genau einen Datensatz im Frame des Geschehens (ohne Zuhörer keine Arbeit; private Simulationen wie `simulate_strike` sind stumm, eigene Zustände mit `state.silent = true`). Zuhörer dürfen den Kampfzustand nicht ändern.

| Feld | Inhalt |
|---|---|
| `kind` | `impact` (Treffer, Block, Parade, Deckungsbruch, Geschosstreffer/-block/-fehlschuss), `swing` (erster Frame des gemessenen Live-Fensters), `draw`, `release`, `break` (Schildbruch) |
| `event`, `outcome` | Quellereignis; `hit`, `block`, `parry`, `guard_broken`, `lodged`, `deflected`, `miss` |
| `frame`, `clip_frame`, `time_s` | Simulationsframe (60 Hz), gemessener Clipframe des Kontakts (−1 bei Geschossen), Zeit |
| `material_a`, `material_b` | schlagendes und getroffenes Material (iron, bronze, wood, leather, cloth, flesh, lead, sinew, hemp, soil, world, air) |
| `energy_j`, `speed_m_s` | kinetische Energie und Geschwindigkeit am Kontakt (bei `draw`/`release`: Abflugenergie) |
| `position`, `direction` | Weltposition des Kontakts bzw. Abflugpunkts, Flug-/Schlagrichtung |
| `weapon_id`, `weapon_class`, `mechanism`, `strike_kind` | aus `weapons.json` |
| `source`, `target`, `zone`, `braced` | Kämpferkennungen, Trefferzone, Deckung gehalten |
| `sound_hint`, `gain_db` | Kennung des synthetisierten Platzhalters und Pegelvorschlag aus der Energie (leer, wo es keinen Platzhalter gibt: Ziehen, Lösen) |

Gemessen (`melee_weapons`): Bogen `draw` Frame 1, `release` Frame 45 (37,5 J), Aufprall Frame 53 (Eisen auf Eisen, 36,6 J); Armbrust `release` Frame 242 (90,8 J); Pilum `release` Frame 39 (324 J), Aufprall Frame 61 (334 J).

## 3. Gemessene Zeiten

Alle Werte aus `melee_core_test` bzw. `melee_strike_bake` (60 Hz). „Kontakt am Peak-Ziel“: Gegner exakt dort, wo die angezeigte Spitze im Peak ankommt (1 mm innerhalb seiner Kapsel); „2 cm näher“: 2 cm weiter innen.

| Rig/Bewegung | Dauer | Live-Fenster | Peak | Kontakt am Peak-Ziel | Kontakt 2 cm näher | Reichweite (Achse→Spitze) | Spitze max. | Gleiten Stützfuß |
|---|---|---|---|---|---|---|---|---|
| legionary/thrust | 0,82 s | 13–27 | 25 (0,417 s) | 25 | 24 | 1,63 m | 6,9 m/s | 7,5 mm |
| legionary/cut_inward | 0,90 s | 19–28 | 27 (0,450 s) | 27 | 27 | 1,44 m | 17,7 m/s | 4,2 mm |
| legionary/cut_outward | 0,94 s | 16–29 | 25 (0,417 s) | 25 | 25 | 1,52 m | 13,5 m/s | 4,9 mm |
| legionary/overhead | 1,12 s | 25–40 | 38 (0,633 s) | 38 | 37 | 1,55 m | 12,1 m/s | 3,5 mm |
| legionary/turn_cut | 1,24 s | 30–41 | 39 (0,650 s) | 39 | 39 | 1,47 m | 15,5 m/s | 3,8 mm |
| axe_fighter/axe_overhead | 1,00 s | 25–35 | 33 (0,550 s) | 33 | 32 | 1,34 m | 14,7 m/s | 1,7 mm |
| axe_fighter/axe_cut_inward | 0,90 s | 20–28 | 28 (0,467 s) | 28 | 28 | 1,24 m | 12,3 m/s | 6,5 mm |
| axe_fighter/axe_cut_outward | 0,90 s | 16–28 | 24 (0,400 s) | 24 | 24 | 1,30 m | 10,8 m/s | 6,5 mm |
| spearman/spear_thrust | 0,95 s | 15–34 | 30 (0,500 s) | 30 | 29 | 2,15 m | 6,4 m/s | 9,5 mm |
| youth_unarmed/jab_left | 0,62 s | 4–20 | 13 (0,217 s) | 13 | 12 | 0,52 m | 6,9 m/s | 0 |
| youth_unarmed/jab_right | 0,68 s | 4–22 | 15 (0,250 s) | 15 | 13 | 0,52 m | 6,3 m/s | 0 |
| youth_unarmed/hook_left/right | 0,82 s | 6–39 | 18 (0,300 s) | 18 | 17 | 0,44 m | 5,3 m/s | 0 |
| youth_unarmed/uppercut_left/right | 0,90 s | 6–35 | 18 (0,300 s) | 18 | 14 | 0,38 m | 4,9 m/s | 0 |
| youth_unarmed/headbutt | 0,76 s | 8–25 | 18 (0,300 s) | 18 | 17 | 0,44 m | 1,1 m/s | 0 |
| youth_unarmed/front_kick | 1,05 s | 2–31 | 25 (0,417 s) | 25 | 24 | 0,81 m | 3,0 m/s | 4,9 mm |
| youth_unarmed/side_kick | 1,20 s | 2–36 | 29 (0,483 s) | 29 | 27 | 0,88 m | 3,1 m/s | 10,1 mm |
| youth_unarmed/high_kick | 1,30 s | 3–42 | 29 (0,483 s) | 29 | 28 | 0,84 m | 3,4 m/s | 3,7 mm |

Vergleich mit der alten Spieler-Autorität (Schaden ab autorisiertem Fensterbeginn): Gerade L/R 2 Frames (33 ms) zu früh, Kopfstoß und Frontkick 4 Frames (67 ms), Sidekick 5 Frames (83 ms); alte Reichweiten 0,85–2,00 m gegen gemessen 0,58–1,09 m Mittelpunktabstand (inkl. 0,20 m Raider-Kapsel). Erwachsene unbewaffnet: dieselbe Pose, gemessen exakt ×1,14 (Fehler 0,0000 m).

Weitere Messwerte (`melee_core_test`):

- Block-Matrix Gladius-Stoß gegen Axtkämpfer, Angriffswinkel −90/−45/0/45/90° (negativ = Schildseite): ohne Deckung Treffer/Treffer/**Block (ungedeckt)**/Treffer/Treffer; `guard_front` Treffer/Treffer/**Block**/Treffer/Treffer; `guard_left` Treffer/**Block**/Treffer/Treffer/Treffer; `guard_right` Treffer/Treffer/Treffer/**Block**/Treffer.
- Deckungswinkel (halbe Breite / Abstand der Schildmitte zur Körperachse in Frontdeckung): Scutum ±33°, Rundschild ±28°, Schild des Speerrigs ±20°.
- Parade: Deckung 8 Frames vor dem Peak → `parry` + Angreifer `parried`; 30 Frames vorher gehalten → `block`.
- Reaktionen: Speerstoß gegen Jugendlichen 45 J, Verhältnis 0,70 → `stagger`; Kindergerade in den Rücken eines Legionärs 23,9 J, 0,22 → `flinch`.
- Axt-Überkopf auf Scutum-Hochdeckung: 237 J, 23,7 Ausdauer; erschöpfte Deckung bricht. Wiederholte Axthiebe spalten den Scutum (Integrität 0 → kein Block mehr).
- 8 Axthiebe (Seed 99): 4 Verletzungen, Moral des Getroffenen steady → wavering → breaking.
- KI-Duelle (Seeds 1–12, je bis 90 s; entschieden = tot oder Moral gebrochen): Axtkämpfer gegen Axtkämpfer 12/12 entschieden (Sieger 6:6, Median 20 s; 50 Treffer, 42 Blocks, 18 Deckungsbrüche, 12 Fehlschläge); Legionär gegen Axtkämpfer 8/12 (Sieger 4:4, Median 48 s; 46 Treffer, 221 Blocks, 54 Deckungsbrüche); Speerträger gegen Axtkämpfer 11/12 (0:11 – der Axtkämpfer unterläuft den Speer; Median 52 s). Vor dieser Arbeit: Legionär gegen Axtkämpfer (Seed 8, 25 s) 0 Treffer; sechs Duelle ohne Scutum zusammen 3 Treffer bei 38 Fehlschlägen. **Zwei Legionäre hinter Scuta kommen weiterhin kaum durch** (12 Duelle zu 90 s: 7 Treffer, keine Entscheidung; offener Punkt). Kleinster Körperabstand 0,506 m (keine Durchdringung).
- Ausrichten des Schlags: Jeder Schlag kommt neben der Körpermittellinie an (Peilung der Spitze im Peak: Axt-Überkopf 8,7°, Gladius-Außenhieb 13,2°, Speer 1,9°). `Core.aim_yaw` dreht den Körper um genau diese Peilung; größter Restfehler über alle 19 Bewegungen < 0,0001 rad. Die frühere Rechnung in `simulate_strike` hatte das falsche Vorzeichen (Fehler = doppelte Peilung).
- Schadensformel (gemeinsames Modul; Gladius-Hieb auf ungerüsteten Rumpf, Fertigkeit 65 gegen 40): 23; Veteran (Fertigkeit 80) mit Q1-Klinge 25 gegen Rekrut (25) mit Q4-Klinge 16; Kopf 35, mit Montefortino-Helm 17, Kettenhemd 10; erschöpft 16, verschlissene Klinge 16, Waffenarmwunde 17, gestauchter Kontakt 7, geübter Verteidiger (95) 19.
- Fernwaffen (`melee_weapons`): Bogen auf 6/12/18 m – `release` Frame 45, Treffer Frame 52/59/67 (Flug 7/14/22 Frames, jeweils gleich dem Orakel), 35/34/34 Schaden, 36,7/35,9/35,0 J. Pfeil auf 6 m: ungerüstet 35, Kettenhemd 19, ungeübter Schütze (20) 11. Pilum 9 m auf Scutum-Frontdeckung: steckt, 332 J, Schildintegrität 0,78, 33 Ausdauer; in den Rücken: 18 Schaden, zu Boden. Reichweiten bei 20° Abwurf: Pilum 25,6 m, Wurfspeer 36,0 m, Schleuder 75 m, Bogen 139 m, Armbrust 170 m. Bogen 25 m, je 40 Schüsse: Fertigkeit 90 trifft 31, Fertigkeit 10 trifft 11.
- Balance-Hinweis (Werte gehören dem Troops-Branch): Ein Pfeil (Basis 25, gegen Geschosse hilft die Verteidigerfertigkeit nicht) richtet auf Ungerüstete mehr Schaden an als ein Gladius-Hieb (Basis 24 × Parade des Verteidigers); Wolle/Leder/Leinen haben in `combat_balance.json` keinen Rüstungseintrag und schützen daher nicht.
- Kampfstile (400 Entscheidungen, Seed 5): Legionär sticht in 53 % der Fälle (213× Stoß, 65/69 Hiebe, 38 Überkopf, 15 Drehhieb), Axtkämpfer bevorzugt den Überkopfhieb (191 / 128 / 81); Einsatzdistanz Speer 2,30 m gegen Axt 1,36 m.

## 4. Nachweise

Darstellungsrenderer: `gl_compatibility`, Xvfb, 960×720, echte Rigs (Held erwachsen mit Dienst-Gladius/Scutum, Meshy-Axtkämpfer mit Axt/Rundschild) auf einer neutralen Testfläche, gesteuert vom Kern über den Presenter. Beschriftung je Bild: Simulationsframe, Abstand zum Ereignisframe, Clipframe, Phase, Ereignis.

- `evidence/hit_weapon_side.jpg` – Gladius-Stoß von der Waffenseite (90°) an der Rundschild-Frontdeckung vorbei: Klingenspitze erreicht den Mantel in Frame 24 (`hit arm_weapon`, `flinch`), Trefferpause bis Frame 26 (Clip bleibt 24), danach Rückprall.
- `evidence/block_front.jpg` – gleicher Stoß frontal: Spitze trifft in Frame 19 das Rundschildbrett, Holzsplitter, Rückprall.
- `evidence/block_axe_on_scutum.jpg` – Axt-Überkopfhieb auf die nach oben gewandte Scutum-Hochdeckung: Kontakt an der Oberkante in Frame 29, Splitterwolke, 6 Frames Pause, Rückprall statt Durchschwung.
- `evidence/scutum_edge_catches_flank.jpg` – Axt-Innenhieb von rechts (70°): der 0,78 m breite Scutum fängt ihn an der Kante (Block). Ursprünglich als Flankentreffer angelegt; die Geometrie ergab ehrlich einen Block.
- `evidence/flank_hit_reaction.jpg` – Axt-Überkopfhieb von rechts hinten (105°) an der Frontdeckung vorbei: Treffer mit gerichteter Reaktion.
- `evidence/whiff_out_of_reach.jpg` – Axt-Überkopfhieb außerhalb der Reichweite (auch vor dem Scutum): Fehlschlag am Fensterende, keine Wirkung.
- `evidence/youth_jab_on_raider.jpg` – der 12-Jährige (`youth_unarmed`, dieselben Spuren wie die Spieler-Autorität) schlägt eine rechte Gerade gegen einen Axtkämpfer von dessen Waffenseite.
- `evidence/spear_reach_vs_axe.jpg` – Speerstoß des Schlachtrigs (2,15 m Reichweite) gegen den Axtkämpfer von dessen Waffenseite.
- `evidence/dynamic_camera_block.jpg` – dieselbe Engine-Szene mit der dynamischen Kampfkamera über der Schulter des Legionärs; Kamerastoß am Kontaktframe.

Ehrliche Grenzen der Bilder: Die Klinge dringt am Ereignisframe bis zu 2 cm in die Kapsel ein (Endpose des gefegten Frames, im Test `melee_visual_contact` gemessen); die Kapsel ist eine Torsonäherung, kein Hautkontakt; die Testfläche ist kein Spielweltausschnitt; Flinch-Reaktionen sind klein und auf Standbildern kaum sichtbar.

## 5. Tests

| Check (`tools/check_prototype.py --only …`) | Inhalt | Ergebnis (dieser Branch) |
|---|---|---|
| `melee_tracks` | Neu-Messung aller 19 Bewegungen/18 Schildposen gegen committete Daten; Fußgleiten ≤ 15 mm; Knochen ≤ 12 m/s; Erwachsenenskala | PASS |
| `melee_core` | 1159 Prüfungen: Kontaktframe jeder Bewegung gegen unabhängiges Abtast-Orakel (±0,5 mm), kein Schaden davor, ±1 Frame zum Peak, Fehlschlag, unterbrochener Schlag = 0 Schaden, Block vorn/seitlich, Parade, Ausweichen, Reaktionen, Ausdauer, Deckungsbruch, Verletzungen, Moral, Seeds, Tick-Aufteilung, JSON-Fortsetzung, Schildbruch, KI-Deckungswahl, KI-Duelle, Kampfstile, Ebene-B-Hilfsfunktion; neu: Schaden = gemeinsame Formel (kein zweiter Tabellenwert im Kern), Trefferpause nach Energie, gleichzeitiger Schlagabtausch, Schildöffnungen, `aim_yaw` für alle Bewegungen, `preview_strike` = tatsächlicher Ausgang (20/20), Duelle kommen zur Entscheidung | PASS |
| `melee_visual_contact` | 242 Prüfungen auf den gerenderten Rigs: angezeigte Waffe vor dem Ereignis nie im Körper (Toleranz 12 mm), am Trefferframe in Kontakt, am Blockframe im gerenderten Schild, Trefferpause hält die Waffe still; Fußarbeit ohne Gleiten; Schlag nach Annäherung ohne Fußsprung und auf der gemessenen Spur; Trefferreaktionen je Zone messbar verschieden; gerenderter Schild folgt den Öffnungen der Autorität (hängend, weggerissen; höchstens 3 von 36 Frames Abweichung) | PASS |
| `melee_camera` | 75 Prüfungen: eigener Schild verdeckt den Gegner nie (Ausweichwinkel bis 80°), beide Kämpfer im Bild (unabhängiger Frustum-Test, 0,9–3,5 m, drei Richtungen), Kamera hinter dem fokussierten Kämpfer, Orbit/Zoom, Glättung bei Sprüngen (< 12 m/s, eingeschwungen < 1,5 s), Stoß nach Energie, Abklingen | PASS |
| `melee_feedback` | 59 Prüfungen: Materialzuordnung, Energieskalierung, Partikelbudget, Determinismus und Kennzeichnung der Klänge, Spektralordnung | PASS |
| `melee_weapons` | 198 Prüfungen: Waffenkatalog (Klassen, Epochen, Erweiterung als Datenzeile, ungültige Einträge abgewiesen, Kern nennt keine Waffe), Bogen-Zeitlinie mit Orakel, Halten/Absetzen, Armbrust, unterbrochener Wurf, Schild und Pilum, Formel für Geschosse, Reichweiten, Zielkorrektur, Wand, Streuung nach Fertigkeit, Determinismus, JSON-Fortsetzung mit Geschoss in der Luft, Tick-Aufteilung, Ereignis-Hub (Reihenfolge, Felder, Frames, Materialien, Stummschaltung) | PASS |
| `combat_formula` (Troops-Branch) | 68 Prüfungen des gemeinsamen Moduls inkl. Armbrust-Eintrag | PASS |
| `combat_actions` (314), `unarmed_combat` (81), `combat_model` (230), `village_childhood` (516), `city_trade` (169) | angepasst (siehe 6.4), plus Erwachsenenreichweite | PASS |
| `action_world` (56), `natural_motion` (116), `action_adapter`, `touch_controls`, `childhood_integration` (96), `integration` (76) | Produktionsszene; `action_world` trainiert jetzt in 0,5 m am Pfahl, Wandprüfung mit Kontrollversuch (siehe 6.4) | PASS (einzeln, headless) |

## 6. API und Integrationshinweise

### 6.1 Ebene A direkt (`melee_core.gd`)

```gdscript
var s := Core.new_state(seed)
Core.add_fighter(s, "soldier_0042", "legionary", {"team":"rome", "x":0.0, "z":0.0, "yaw":0.0, "scale":1.0, "health":100.0,
	"skill":70.0, "weapon_quality":2, "armor_pieces":{"torso":{"family":"lorica_hamata", "quality":2, "wear":0.0}}, "ranged":["pilum"]})
Core.place(s, id, x, z, yaw)            # Fortbewegung kommt von außen (KI, Ebene B, Spieler)
Core.face(s, id, target_id)
Core.command(s, id, "attack", {"move":"thrust"})   # guard {style}, release, dodge {style}
Core.command(s, id, "draw", {"weapon":"pilum", "target":enemy_id})   # loose {target|yaw,pitch}, lower
Core.aim_yaw(s, id, target_id, move)     # Körperdrehung, die die Schlaglinie aufs Ziel legt
Core.preview_strike(s, id, move)         # body | shield | none, ohne Zustandsänderung
var events := Core.step(s, delta, world_clear)      # Ereignisse mit frame/clip_frame
Core.phase(s.fighters[id])               # windup | active | recovery | guard | dodge | react | down | idle
Core.nominal_reach(kit, move, defender_radius)      # Abstandsplanung für KI und Ebene B
Core.morale_event(s, id, delta, reason)  # externe Moral
var d := AI.decide(s, id, target_id, skill)   # optional: NPC-Entscheidung
AI.apply(s, id, target_id, d, delta, speed, motion_check)
```

Ereignisse: `swing`, `hit` (zone, damage, damage_terms, energy_j, hitstop_frames, direction, direction_vector, reaction, point, Materialien), `block`/`parry`/`guard_broken` (braced, stamina_cost, surface_material, shield_integrity), `whiff`, `interrupted`, `reaction`, `injury`, `morale`, `shield_broken`, `killed`, `recovered`; Fernwaffen: `draw`, `release`, `lowered`, `projectile_hit`, `projectile_block` (lodged, shield_fouled), `projectile_miss` (soil/world). Präsentation: `melee_presenter.gd` pro Akteur, `melee_impact_fx.gd.spawn(event, point, normal)`; Ton: Abschnitt 2.8.

### 6.2 Schadensformel (D-042) – Vertrag

- Einziger Rechenweg der Ebene A: `scripts/battle/combat_formula.gd` `resolve_hit()` mit `assets/balance/combat_balance.json` (Troops-Branch, hier per Merge von `cae920a`). `MeleeDamage.compute(hit)` übersetzt nur: Waffe → `{family: balance_family, quality 0–4, wear, strike}`, Angreifer → `{skill 0–100, stamina 0–100, injuries}`, Verteidiger → `{skill, armor: {zone: {family, quality, wear}}}`, `zone`, `shield_cover 0` (Blocks sind Geometrie), `ranged`, `impact` (Aufprall am gemessenen Kontaktframe). Rückgabe: Schaden (gerundet), die sechs Faktoren, Verschleiß.
- Kämpfer tragen dafür `skill` (Ausbildung, Standard 55 = Kompetenz 1,0), `weapon_quality` (Standard 2) und `armor_pieces`. Kit-Kleidung `mail` steht für ein Kettenhemd (`lorica_hamata`) am Rumpf; Helme sind als `armor_pieces.head` möglich (die Kits setzen keinen, weil die Rigs keinen eigenen Helm-Eintrag haben). Wolle/Leder/Leinen haben in der Balancedatei keinen Eintrag und schützen nicht (vorher 0,75–0,95; Entscheidung des Balance-Eigentümers).
- Einzige Ergänzung an der gemeinsamen Datei: ein Balancewert für die Armbrust (Basis 30, als Vorlage späterer Epoche gekennzeichnet).
- **Noch nicht auf der gemeinsamen Formel:** der gespeicherte Spielerpfad des Dorfes (`combat_actions.gd.hit_damage()`). Er behält seine Technikwerte (`TECHNIQUES.damage`) und die Handelsboni als getrennte, begrenzte Faktoren, weil die Überfall- und Begegnungsgegner (Leben 45–60, kein Rüstungs-, Zonen- oder Fertigkeitsmodell) darauf abgestimmt sind und anderen Branches gehören. Die Umstellung ändert deren Balance und ist eine Entscheidung für Lead/Auftraggeber (siehe 7).

### 6.3 Dorfüberfall (Branch `fix/village-raid-approach-20261126`, nicht von mir geändert)

- Die gegnerischen Schläge des Überfalls (`village_life.gd`, `attack_timer`) sind weiterhin zeitgeplant. Empfohlener Weg: Raider als Kern-Kämpfer (`axe_fighter` bzw. künftige Kriegerfamilien) führen, `Core.step` im selben Festschritt wie `CombatActions.advance` takten und `hit`-Ereignisse gegen den Spieler in die bestehende Gesundheits-/Blocklogik buchen. Der Spieler steht im Kern als `youth_unarmed` (Kind, Skala 1,0) bzw. `legionary`.
- Annäherung: Raider müssen auf `Core.nominal_reach(...)` herankommen (Axt 1,24–1,34 m + Zielradius). Die Spielerfaust reicht nur 0,52 m (+0,20 m Raider-Kapsel = 0,72 m); `personal space` der Welt (0,56 m Mindestabstand) erlaubt das.
- `block_window`/`dodge_window` des Überfalls bleiben vorerst zeitbasiert. Für Ebene A sollten Block und Ausweichen über Schildbox bzw. Wurzelbewegung des Kerns laufen.

### 6.4 Geänderte Bestandsdateien

- `combat_actions.gd`: Kontakt nur noch per gemessenem Sweep im Live-Fenster; `windup/active/reach/arc_dot` sind die Messwerte (Test hält sie synchron); `view()` liefert zusätzlich `contact_peak`; Speicherformat unverändert (11 Felder).
- `action_world_test.gd`: Training in 0,5 m statt 0,7 m Abstand zum Pfahl (Spielerkapsel 0,28 m + Pfahl 0,16 m lassen 6 cm Luft), „keine Gutschrift vor dem gemessenen Kontaktframe“, Wandprüfung aus 0,7 m mit Frontkick und Gegenprobe ohne Wand.
- Tests mit Übungspfahl in 1,0–1,3 m bzw. Raider in 1,0 m (vorher nur durch die übergroße Reichweite erreichbar) stehen jetzt 0,6 m vom Pfahl bzw. 0,7 m vom Raider entfernt; Prüfzeitpunkte folgen den gemessenen Kontaktframes. Keine Schwelle gesenkt; zusätzliche Prüfungen gegen das Orakel.
- `quality/motion_contract.json`: neue Skripte registriert, `melee_pose.gd`/`melee_presenter.gd` als prozedurale Bewegung der Familien hero, service_gear, meshy_people, meshy_gear, battle_rigs; zusätzliche Pflichtchecks `melee_tracks`/`melee_visual_contact`. Die Sichtfreigaben in `motion_reviews.json` müssen für die neuen Bytes neu erfolgen.

### 6.5 Ebene B (Formation) und C

- `Core.simulate_strike(attacker_kit, move, defender_kit, distance, bearing_deg, guard, seed, defender_options, attacker_options)` liefert ohne eigene Zustandsverwaltung das erste Kontakt- bzw. Fehlschlagereignis mit Clipframe (gemessen: Gladius-Stoß frontal in `guard_front` → Block Frame 19; von der Waffenseite → Treffer Frame 24, `arm_weapon`, 14 Schaden; 1 m zu weit → Fehlschlag).
- Ebene B kann für einzelne Duelle an der Front `Core` direkt instanziieren (gleiche Soldaten-ID als Kämpfer-ID; Zustand ist JSON) oder für vereinfachte Agenten nur `Tracks.timing(kit, move)` (Fensterframes, Peak, Reichweite) und `Core.nominal_reach` verwenden, damit Trefferereignisse in B denselben Zeitpunkten folgen wie in A.
- Übergabe A↔B ohne Duplikate: Kämpfer beim Wechsel in A mit `add_fighter` aus der persistenten Identität erzeugen, beim Verlassen Gesundheit, Verletzungen, Ermüdung, Moral und Schildintegrität zurückschreiben und den Eintrag entfernen. Tote (`killed`) bleiben tot.

## 7. Offene Punkte

- Die ungetrackte Meshy-Jugendfigur (`hero_meshy_italia_*`, Mocap-Clips) ist nicht vermessen. Ein informativer Versuch in diesem Arbeitsbaum war **nicht schlüssig**: Beim Sampeln der Clips `jab_*` über `VillagePerson.sample_combat` bewegten sich die Knochen des ersten `Skeleton3D` nicht (Hand_R konstant), die Clips treiben offenbar ein anderes Skelett bzw. andere Knochen. Sobald die Figur eingecheckt ist, muss sie ins Bake; bis dahin passen die Kontaktframes des 12-Jährigen nur zur Prozedural-Figur `hero_quality`.
- Schlagbewegungen sind prozedurale Schlüsselposen, kein Motion Capture; Gewichtsverlagerung über Becken/Schritt, aber keine Hüftrotation über die Füße; Kontaktpose dringt bis 2 cm ein (keine IK-Anpassung am Ziel).
- Schildarten: Rundschild als flächengleiches Quadrat (Halbseite = R·0,886), Scutum als Box inkl. Wölbung; Schild des Speerrigs aus Skinvertices (Box in Knochenachsen).
- Massen, Standfestigkeit, Geschosswerte (Masse, Abfluggeschwindigkeit, Luftwiderstand) und Verletzungschancen sind dokumentierte Schätzwerte, keine Messungen; Balancewerte gehören `combat_balance.json`.
- **Fernwaffen sind nicht gerendert:** keine Zieh-/Wurf-/Schleuderposen, kein Geschossmodell, Phasenzeiten gesetzt statt vermessen. Für die Abnahme fehlen Clips oder prozedurale Posen samt Vermessung des Lösungsframes, Geschoss-Darstellung (Pfeil im Schild, verbogenes Pilum) und eine KI, die Fernwaffen einsetzt.
- **Legionär gegen Legionär** (beide mit Scutum) kommt kaum zur Entscheidung: der Scutum deckt frontal alles, und die KI umgeht ihn nicht (kein Umkreisen, keine Finten, kein Schildstoß, Drehung ohne Drehratenbegrenzung). Ein früherer Versuch mit Drehratenbegrenzung und Annäherung zur Waffenseite führte zu gegenseitigem Umkreisen ohne Angriffe.
- Der Spielerpfad des Dorfes (`combat_actions.hit_damage`) rechnet noch mit eigenen Technikwerten statt mit `combat_balance.json` (siehe 6.2).
- Kleidung aus Wolle/Leder/Leinen und Helme der Kits: in der Balancedatei gibt es keine Einträge für Kleidung, und die Kits setzen keinen Helm.
- Klänge sind synthetisierte Platzhalter bis zu lizenzierten Foley-Aufnahmen.
- Kein Gerät-/Fold7-Lauf dieses Branches; Partikelbudget ist begrenzt, aber auf dem Gerät nicht gemessen.
- Spieler-Deckung/-Ausweichen im Dorf bleiben die bisherigen Zeitfenster (`combat_actions`), nicht die Schildgeometrie.

## 8. Technikrecherche (D-050) und was daraus übernommen wurde

- Trefferpause (Hit-Stop): gängige Praxis ist, leichte Treffer nur 2–3 Frames und schwere länger anzuhalten, die Dauer am Treffergewicht zu skalieren und den Ton an die Pause zu binden ([GameJuice: Hit-stop frame trick](https://gamejuice.pages.dev/articles/hit-stop-frame-trick); Obsidian zu Avowed: Hit-Stop je Animation abgestimmt, [PC Gamer](https://www.pcgamer.com/games/rpg/if-youve-been-worried-about-avowed-not-looking-punchy-enough-obsidians-combat-designer-has-a-hitstop-animation-superpower-that-might-reassure-you)). Übernommen: Pause 2–6 Frames nach Aufprallenergie (+1 am Schild) statt fester 4/6; Ereignis, Partikel und Tondatensatz entstehen im selben Frame.
- Waffe am Kontakt stoppen statt durchschwingen ([gamedev.net, ARPG-Nahkampf](https://gamedev.net/forums/topic/661629-designing-a-good-feel-arpg-melee-combat-system/5185267/)): bereits umgesetzt als Trefferpause + Rückprall.
- Kamerastoß: energieabhängiger, abklingender Impuls nach dem „Trauma“-Modell (Squirrel Eiserloh, GDC 2016, [Math for Game Programmers: Juicing Your Cameras With Math](https://gdcvault.com/play/1023146/Math-for-Game-Programmers-Juicing)); `melee_camera.gd` folgt diesem Prinzip (Stärke aus der Aufprallenergie, Abklingen, begrenzte Auslenkung).
- Kontakt aus gefegter Waffengeometrie zwischen Animationsframes statt geplanter Trefferzeit: hier mit Messung aus den tatsächlich angezeigten Rigs und Teilschritten ≤ 3 cm umgesetzt (Abschnitt 2.2/2.3); für Geschosse dasselbe Verfahren entlang der Flugbahn.
- Nicht übernommen, weil ohne Daten nicht belegbar: Motion Matching bzw. Mocap-Übergänge (keine Aufnahmen vorhanden), physikalische Ragdoll-Mischreaktionen (Renderer/Performance auf dem Zielgerät nicht messbar).
