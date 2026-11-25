# AETERNA: Begleiter, LOD-Kontakte und Meshy-Sohlen

Stand: 25. November 2026. Basis: [`261639105dcaa72f8dd92e73f4db1d9ab7d90a23`](https://github.com/Ullmann27/Imperathen/commit/261639105dcaa72f8dd92e73f4db1d9ab7d90a23), der geprüfte Kopf von [Draft-PR #56](https://github.com/Ullmann27/Imperathen/pull/56).

## Ergebnis und Abnahmeumfang

Vier nachgewiesene Ursachen sind in einem eigenen Folgebranch behoben: sofortiges Loslaufen noch während einer starken Richtungsänderung, doppelte Fortschreibung der Fußkontakthistorie beim LOD-Wechsel, unerreichbare Fußziele in zwei Meshy-Gangprofilen und das Verwischen bereits starrer Fußgewichte. Zusätzlich erhält die Prüfung geschlossener Meshes eine eng begrenzte Cachekorrektur.

Alle neun gezielten Integrationsgruppen bestehen auf identischer Quelle. Der gemeinsame Quellfingerprint lautet `a36c7e490e09617bde1bc143ee622584b8f98034158d72db96cb9a6ec573ff0f`. Die fünf neuen unabhängigen Python-Prüfmethoden bestehen ebenfalls. Der vollständige GitHub-Prüflauf muss anschließend genau den veröffentlichten Commit prüfen; sein Ergebnis wird in der PR-Beschreibung mit Run- und Artefaktverweis dokumentiert. Dieser Bericht behauptet keine bereits abgeschlossene Gesamtprüfung.

**Das strenge Motion-Gate bleibt nicht freigegeben.** Die Messberichte behalten `complete: false`, soweit sie nur gezielte Ausschnitte prüfen. Die Grenzwerte, die vier übergeordneten Motion-Sampler und die Qualitätsspezifikation bleiben unverändert. Die dargestellten Kontaktverbesserungen ersetzen weder die noch ausstehenden Sichtabnahmen noch einen erfolgreichen vollständigen Gate-Lauf.

## 1. Begleiter richten sich vor dem Anlaufen aus

`CompanionFollow` drehte bisher erst nach einer Bewegung mit voller angeforderter Geschwindigkeit. Marcus begann den betroffenen Weg mit ungefähr 131° Richtungsfehler; der Körper lief bereits, während seine Orientierung noch nicht zum Weg passte. Die gepflanzten Füße mussten einen zu großen Versatz ausgleichen.

Die vorhandene Drehgrenze von 4,5 rad/s wirkt jetzt vor dem Physikschritt. Die nichtnegative Vorwärtsprojektion begrenzt die Geschwindigkeit während der Ausrichtung. Bei einem Ziel hinter der Figur dreht diese zunächst am Ort. Das Anfahren ist mit 8 m/s² begrenzt; die vorgesehenen 4,1 m/s bleiben erreichbar. Der flüchtige Geschwindigkeitswunsch ist von der tatsächlichen Kollisionsbewegung getrennt und wird bei Pause, Reset und Körperwechsel zurückgesetzt. So bleibt auch die Hausrampe passierbar.

Die Darstellung erhält weiterhin die tatsächlich gemessene Bewegung. Missionswege, Pause, Dialog, Körperidentität und Save/Load bleiben durch die bestehenden Prüfungen abgedeckt.

## 2. Ein LOD-Wechsel ist kein zusätzlicher Bewegungsschritt

Bei Silvanus wurde in Frame 482 nach der Körperbewegung ein neues Detailmodell aufgebaut, während die Animationsphase noch den vorherigen Tick bezeichnete. Die Ersatzdarstellung schrieb den letzten Standoffset um **68,333 mm** weiter; der Körper hatte sich tatsächlich **68,333 mm** bewegt. Der erste anschließende Schwung übernahm diesen Schritt dadurch doppelt.

`VillagePerson._reload` stellt jetzt nach dem Aufbau der Ersatzpose den zuvor gesicherten Kontakt-Snapshot wieder her. Die berechnete Ersatzpose bleibt erhalten; die zeitliche Kontakthistorie stammt wieder vom letzten echten Tick. Im selben Prüfweg beträgt die ungewollte Offsetänderung danach null.

### Tatsächliche Begleiterwege, unveränderter Messablauf

| Figur / Messgröße | Basis | Kandidat |
| --- | ---: | ---: |
| Marcus: größte Knochenrotation pro Frame | 31,651015° | 21,883231° |
| Marcus: größter Knochenpositionsschritt | 193,958268 mm | 161,454394 mm |
| Marcus: größter Standfußversatz | 13,833697 mm | 0,005395 mm |
| Silvanus: größte Knochenrotation pro Frame | 23,563750° | 22,277519° |
| Silvanus: größter Knochenpositionsschritt | 184,772387 mm | 187,171772 mm |
| Silvanus: größter Standfußversatz | 8,412944 mm | 0,006877 mm |

Der Standfußversatz dieser Tabelle bezeichnet den **Fußknochen**, nicht die verformte Sohlenoberfläche. Beide Figuren erreichen ihren Haltepunkt mit ungefähr 0,18 m Abstand und Geschwindigkeit null; während der Pause bewegen sie sich nicht. Durch die Ausrichtung und das Anfahren verlängert sich die Route um ungefähr 1,07 s bei Marcus und 0,73 s bei Silvanus.

Die Grenzen von **20° Rotation** und **60 mm Positionsschritt** bleiben überschritten. Silvanus' Positionsmaximum verschlechtert sich um 2,399385 mm. Dieser Maximalwert entsteht im laufenden `run`-Clip auf `Shin_R`, Frame 360, Phase 0,469541739, bei unverändertem LOD2 und ohne Körperdrehung. Die finalen Rotationsmaxima entstehen ebenfalls im Lauf, ohne LOD-Wechsel oder Körperdrehung. Der Bericht [COMPANION_TURN_CONTINUATION.md](COMPANION_TURN_CONTINUATION.md) enthält die vollständigen Routen, zusätzliche 30/60/120-Hz-Stressbefunde und verworfene Gegenversuche.

## 3. Erreichbare Gangziele und unveränderte starre Fußbindungen

Für den germanischen Axtkämpfer und den römischen Signifer wurde der Generator korrigiert und je vier Detailstufen neu erzeugt.

Der Generator löst sagittale Beinbewegungen. Er verwendete dafür volle 3D-Segmentlängen und klemmte unerreichbare Fußziele, wodurch Standfüße über dem Boden blieben. Jetzt verwendet er die tatsächlichen YZ-Projektionen, berechnet zunächst beide Ziele und senkt das gemeinsame Becken so weit, dass beide erreichbar werden. Erst danach löst er beide Beine. Die zusätzliche Beckensenkung erreicht etwa 65,8 mm und verändert die Haltung tatsächlich.

Der zweite Fehler lag in der Gewichtsglättung nach der Meshreduktion: Ein zuvor vollständig an den Fuß gebundener Sohlenvertex erhielt einen Anteil des Schienbeins. Beim Axtkämpfer LOD3 bewegte sich dadurch die sichtbare Sohle um **17,269032 mm**, obwohl ihr Fußknochen praktisch stillstand. Der Generator sichert jetzt ausschließlich die bereits vor der Glättung starren Fußzuordnungen und stellt sie nach den unveränderten beiden Glättungspässen wieder her. Die gleiche tatsächliche Sohle bewegt sich anschließend um **0,000246 mm**.

### Acht Modelle, vollständig verglichene Produktionsclips

| Messgröße im begrenzten Meshy-Umfang | Ergebnis |
| --- | ---: |
| Untersuchte Produktionsclip-Datensätze | 88 |
| Datensätze ohne tatsächlichen Stützkontakt | 12 → 0 |
| Runtime-Rig-Verstöße nach unveränderter Prüffunktion | 28 → 0 |
| Rig-Verstöße in den rohen GLB-Clips | 0 → 0 |
| `march`-/`run`-Fälle mit beobachteten Sohlen beider Füße | 16/16 |
| Größter Sohlenversatz über diese 16 Gangfälle | 0,000478 mm |
| Größte Sohlenpenetration über diese 16 Gangfälle | 0,142363 mm |
| Skin-Edge-Verletzungen in den Gangfällen | 0 |

Diese Werte betreffen tatsächliche verformte Sohlenoberflächen. Die Grenzen bleiben **15 mm Versatz** und **10 mm Penetration**. Die Zählung 28 → 0 gilt für die Runtime-Rig-Prüfung dieser acht Modelle und ist keine Vorhersage des gesamten Motion-Gates.

Zwei Accessor-Vergleiche belegen die genaue Änderung: Die Gangkorrektur ändert nur `march` und `run`; die abschließende Gewichtskorrektur ändert ausschließlich gezielte `JOINTS_0`-/`WEIGHTS_0`-Zeilen. Positionen, Normalen, UVs, Dreiecke und die neun anderen Animationsclips bleiben gegenüber der Basis unverändert. Alle acht finalen GLBs stimmen mit ihrem Buildbericht und dem SHA-256-Dateimanifest überein.

Der [Meshy-Abschlussbericht](evidence/contact-grounding/meshy-final-report.md), der [88-Clip-Vergleich](evidence/contact-grounding/meshy-final-comparison.json) und das [vollständige Belegpaket](evidence/contact-grounding/meshy-rig-audit-evidence.zip) enthalten Messungen, Rohprotokolle, Quellenvergleiche und Gegenproben.

### Tatsächliche Bilder mit gleichem Modellpfad und gleicher Ausrüstung

Die vier Bilder stammen aus Godot 4.7.2 Compatibility/llvmpipe. Identität, Ausrüstung, Modellpfad, LOD3, Phase 0 und Geschwindigkeit stimmen vor und nach der Änderung überein. Die kanonischen Modellbytes wurden zwischen separaten Import-/Engine-Prozessen getauscht und die finalen Dateien anschließend anhand ihrer Hashes wiederhergestellt. Das [Capture-Manifest](evidence/contact-grounding/geometry-final/capture-manifest.json) enthält Quell- und Bildhashes sowie den exakten Laufzeitkontext.

| Modell | Vorher | Nachher |
| --- | --- | --- |
| Axtkämpfer | [Godot-Aufnahme](evidence/contact-grounding/geometry-final/unit_germanic_axe_fighter-before.png) | [Godot-Aufnahme](evidence/contact-grounding/geometry-final/unit_germanic_axe_fighter-after.png) |
| Signifer | [Godot-Aufnahme](evidence/contact-grounding/geometry-final/unit_roman_signifer-before.png) | [Godot-Aufnahme](evidence/contact-grounding/geometry-final/unit_roman_signifer-after.png) |

Die Bilder zeigen nur diese konkreten Posen. Der Signifer steht in der ersten Pose weiterhin 5,20/17,20 mm über der Bodenebene und liegt damit innerhalb der vorhandenen 20-mm-Kontaktzone. Daraus folgt weder perfekte Bodenbündigkeit noch eine vollständige Sicht- oder Android-Leistungsabnahme.

## 4. Geschlossene Komponenten korrekt neu prüfen

Der Mesh-Clearance-Cache konnte zwei zunächst berührende, jeweils geschlossene Komponenten nach ihrer Trennung fälschlich als offen markieren. Wenn solche zuvor gültigen Schweißpaare auseinanderlaufen, verwirft die Prüfung nun den Cache und bestimmt die Geschlossenheit anhand der aktuellen Dreiecke neu. Echte offene Nähte bleiben ungültig; Toleranz und vollständige Paarprüfung bleiben erhalten.

Die neue Gegenprobe erzeugt mit dem Originalcode **zwei Fehler unter 19 Prüfungen** und besteht nach der Korrektur **19/19**. Sie prüft sowohl die getrennten geschlossenen Komponenten als auch tatsächliche Volumeneinschließung. Das vorhandene Negativbeispiel mit fehlender Fläche schlägt weiterhin korrekt als unbewiesen an.

Damit sind die acht Ausrüstungs-Samplingfehler noch nicht behoben: Die importierte Hero-Geometrie enthält bereits vor der Animation offene Körper-, Tunika-, Rock- und Gürtelränder. Schwert und Schild sind in der konkreten Gegenprobe geschlossen. Gemeldete AABB-Werte sind konservative obere Schranken und dürfen nicht als tatsächliche Eindringtiefe ausgegeben werden. [Topologiebericht und Quellprobe](evidence/contact-grounding/gear-audit.md) dokumentieren diese Abgrenzung.

## Prüfbelege

| Prüfung | Finaler gezielter Lauf | Gegenprobe |
| --- | ---: | --- |
| Godot-Import | bestanden | — |
| Begleiternavigation | 32/32 | direkte Routenabkehr statt indirekter Erstsekunden-Geschwindigkeitsannahme |
| Wendung und Wiederanfahren, 30/60/120 Hz | 66/66 | 24 Fehler mit Originalproduktion |
| LOD-Kontakthistorie, 36 Fälle mit Kontrollakteur | 216/216 | 108 Fehler mit Originalproduktion |
| Follow, Pause, Dialog und Save/Load | 269/269 | bestehende Prüfung |
| Bestehende CharacterMotion-Prüfung | 560/560 | bestehende Prüfung |
| Bestehende Meshy-Prüfung | 304/304 | bestehende Prüfung |
| Tatsächliche Skin- und Sohlenprüfung | 300/300 | ein Fehler vor der gezielten Gewichtskorrektur |
| Mesh-Clearance | 19/19 | zwei Fehler mit Originalproduktion |
| Neue unabhängige Python-FK-Regression | 5/5 Methoden | vier Profil-/Gang-Unterfälle scheitern im Original |

Die neun Godot-Integrationsgruppen einschließlich Import wurden im gemeinsamen Root-Checkout geprüft. Der [Integrationsbericht](evidence/contact-grounding/focused-integration.json) bestätigt die unveränderte Quelle während des Laufs; die [Rohprotokolle](evidence/contact-grounding/focused-integration-logs.zip) sind beigefügt. Die beiden neuen Godot-Gruppen sind im vollständigen Prüflauf registriert; die neue Python-Datei wird von der vorhandenen Testsuche erfasst.

Eine unabhängige abschließende Integrationskontrolle bestätigt bytegleiche Übernahme der beiden Navigations-/LOD-Produktionsdateien und aller zwölf Dateien der Meshy-Übergabe. Die [Navigations-/LOD-Prüfung](evidence/contact-grounding/companion-projection-lod-review-evidence.md) und die [Gewichtsprüfung](evidence/contact-grounding/meshy-rigid-foot-review-evidence.md) bewerten die eng begrenzten Änderungen und halten die verbleibenden Einschränkungen ausdrücklich fest.

## Offen und für die nächste Korrektur vorbereitet

1. **Bewegungsspitzen der Begleiter:** Beide überschreiten weiter 20°/60 mm. Silvanus' Positionsmaximum und zwei 30-Hz-Stressmaxima verschlechtern sich geringfügig; sämtliche Werte bleiben im Vergleich sichtbar. Ein angehobener Fuß nach dem Stop ist ebenfalls noch offen.
2. **Nicht-Gang-Clips der Meshy-Modelle:** Acht `death`-, sieben `attack`- und vier `train`-Datensätze überschreiten weiterhin die Sohlenversatzgrenze. Bei `death` erreicht die Penetration 192,334 mm und der Versatz 1.045,891 mm. Axe LOD3 `attack` verschlechtert sich von 19,288395 auf 21,312431 mm und lag schon vorher außerhalb der Grenze.
3. **Neu sichtbare Train-Grenzüberschreitung:** Signifer LOD3 `train` steigt im unveränderten Sampler von 12,747829 auf 23,202851 mm. Die [konkrete Vertexprobe](evidence/contact-grounding/train-contact-probe.json) weist den Anker bereits im ungestützten Frame 37 nach; der erste tatsächliche Stützframe ist 39. Die Landebewegung wird dadurch als Versatz mitgezählt. Diese Ursachenklärung ersetzt keinen Gate-Pass: Der offizielle Wert bleibt ein Fehler. Eine Sampleränderung ist nicht Bestandteil dieser Integration.
4. **Frontier:** 80 ursprüngliche fehlende Kontakt-Datensätze bleiben offen. Eine Diagnose beseitigte das Schweben im Einzelmodell, würde bei breiter Regeneration jedoch unbemerkt neuere Hero-/Equipment-Quellen übernehmen. Diese Versuche sind ausschließlich als Diagnose im Belegpaket abgelegt; alle Frontier-Produktionsdateien bleiben auf der Basis.
5. **Ausrüstung und Sichtabnahme:** Offene Hero-Oberflächen, weitere Übergangs- und Oberflächenfehler sowie ausstehende Sichtabnahmen bleiben für das strenge Gate maßgeblich.

Der Basislauf [45564458686](https://github.com/Ullmann27/Imperathen/actions/runs/45564458686) bestand 70 Godot-Gruppen, 205 Python-Tests und 55 Kamera-Prüfungen; das strenge Gate enthielt trotzdem 536 Einträge. Das [unveränderte Basisartefakt](evidence/contact-grounding/baseline-engine-2616391.zip) ist mit SHA-256 `fa3440215ffedfe8412534fb0556bfb14e71dec07e66f3e3a327363af46a000b` gesichert. Erst der vollständige gemeinsame CI-Lauf liefert die neue Gesamtzahl.

## Übergabe und Veröffentlichungsgrenze

Der Folgebranch `fix/aeterna-contact-validation-20261125` baut auf PR #56 auf und richtet seinen Draft-PR gegen dessen Branch. Der CI-Trigger ergänzt ausschließlich diesen Zielzweig. Vollständiger Engine-Lauf, Python-Prüfungen, Kameravergleich und das unverändert strenge Gate bleiben aktiv. Die Workflowänderung enthält keine APK-Erzeugung und keinen Release-Schritt.

Das Meshy-Belegpaket hat SHA-256 `60a7017ee1376d7b70ead0641bebccb4bcac3b54f33583ec0c9cf9cca859ce12`. Die endgültigen CI-Links und deren Commitbindung gehören in die PR-Beschreibung, damit nach dem Prüflauf kein ungeprüfter Folgecommit allein für die Statusdokumentation entsteht.
