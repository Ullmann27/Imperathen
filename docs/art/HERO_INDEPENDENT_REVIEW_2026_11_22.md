# Unabhängige Prüfung des anatomischen Hauptcharakters

**Stand: 22. November 2026 · geprüfter Export: 18:39:42 UTC · Bezug: Issue #33.**

## Ergebnis

**Die vier GLB-Dateien bestehen die hier dokumentierte statische Exportprüfung. Der vom Nutzer vorgegebene visuelle Qualitätsmaßstab ist noch nicht erreicht.** Die Figur besitzt jetzt einen anatomisch modellierten menschlichen Kopf, sichtbare Augen, Haut und Haare, eine wiedererkennbare Erwachsenenvariante sowie tatsächlich verformende Gesichtsmorphs. Die überprüften Blender-Bilder zeigen den Fortschritt. Sie rechtfertigen weder eine AAA-Freigabe noch einen bestandenen Android-Grafik- und Spieltest.

Die Prüfung wurde getrennt von Änderungen am Charaktergenerator und an der Laufzeitintegration durchgeführt. Ausgangspunkt war die ausdrückliche Meldung des Charakterbearbeiters, dass alle vier Exporte und sechs Reviewbilder schreibstabil sind. Die Dateihashes im [JSON-Prüfbeleg](../../art/hero_quality/validation.json) bezeichnen genau die geprüften GLBs. Ergänzend wurden vier tatsächliche Godot-Studioaufnahmen mit der abschließenden Beleuchtung unabhängig angesehen; deren Beobachtungen und Hashes stehen in Abschnitt 4.

## 1. Maßstab aus der Nutzerreferenz

Die zusätzlich bereitgestellte Dialogszene wurde angesehen. Das Nutzerbild wurde für diese Prüfung nicht in das öffentliche Repository kopiert. Es dient als Qualitätsreferenz für Darstellung und Ausdruck; seine mittelalterlich wirkende Ausstattung ist keine Kostümvorlage für die antike Spielwelt.

| Sichtbares Qualitätsmerkmal der Nutzerreferenz | Abnahmeziel für Imperathen | Beobachtung am aktuellen Kandidaten |
| --- | --- | --- |
| Gesichter bleiben bereits in einer Dialogansicht lesbar; Blicke und Gesten vermitteln eine Situation | Charakter, Blickrichtung und Emotion müssen auch außerhalb extremer Nahaufnahmen verständlich sein | Der Kopf ist klar menschlich. Die Studiobilder zeigen überwiegend einen neutralen Ausdruck; ein glaubwürdiger gespielter Dialog ist damit noch nicht belegt. |
| Haare und Bärte besitzen gebrochene Konturen, Strähnen und unterschiedliche Dichte | Haaransatz, Volumen und Ränder dürfen nicht wie eine geschlossene Schale erscheinen | Haarfarbe und Strähnentextur sind sichtbar; das Volumen wirkt weiterhin kompakt und kappenartig. |
| Stoff, Leder und Metall besitzen unterscheidbare Oberflächen, Dicke und Gebrauchsspuren | Materialwirkung muss auch unter wechselndem Spiellicht bestehen | Haut, Stoff und Lederriemen sind unterscheidbar. Die Haut wirkt noch gleichmäßig, Stofffalten und Nähte bleiben einfach. Dieser Held trägt in den Bildern keine ausgearbeitete Metallrüstung. |
| Kleidung liegt nachvollziehbar am Körper und bildet natürliche Schichten und Falten | Hals, Schulter, Achsel und bewegte Säume dürfen keine störenden Durchdringungen zeigen | Die großen Schulteröffnungen und gezackten Kragenlöcher früherer Zwischenstände sind behoben. Saum und Gürtel bleiben geometrisch einfach; in der Laufpose wird der Saum steif mit dem Bein angehoben. |
| Warmes Seitenlicht, weiches Fülllicht und Schatten verbinden Menschen und Umgebung | Eine echte Spielszene muss dieselben Materialien glaubwürdig in ihren Raum einbinden | Die vorliegenden Bilder sind kontrollierte Blender- und Godot-Studioaufnahmen ohne Dorfumgebung. Eine vergleichbare Dialogbeleuchtung im laufenden Android-Spiel ist nicht nachgewiesen. |

Diese Kriterien sind visuelle Produktionsentscheidungen auf Grundlage des Nutzerbilds. Aus ihnen wird keine Behauptung über dessen Spieltitel, verwendete Engine oder technische Herstellung abgeleitet.

## 2. Statischer Exportnachweis

Der wiederverwendbare Prüfläufer [validate_hero.py](../../tools/characters/validate_hero.py) liest die tatsächlichen GLB-Binärdaten. Er verwendet die vorhandene allgemeine GLB-Inspektion und ergänzt den Vertrag dieses Hauptcharakters. Ein Buildreport des Generators allein genügt dafür nicht.

```bash
python tools/characters/validate_hero.py --report art/hero_quality/validation.json
```

| Export | Tatsächliche Dreiecke | Dateigröße in Bytes | Größte eingebettete Bildkante | Ergebnis |
| --- | ---: | ---: | ---: | --- |
| [LOD 0](../../prototype/assets/characters/hero_quality_0.glb) | 32.820 | 13.644.588 | 2.048 px | Bestanden |
| [LOD 1](../../prototype/assets/characters/hero_quality_1.glb) | 16.417 | 6.030.876 | 1.024 px | Bestanden |
| [LOD 2](../../prototype/assets/characters/hero_quality_2.glb) | 7.222 | 3.026.828 | 512 px | Bestanden |
| [LOD 3](../../prototype/assets/characters/hero_quality_3.glb) | 2.820 | 966.952 | 256 px | Bestanden |

Alle vier Exporte enthalten jeweils 14 Meshes mit 14 Primitives, fünf Materialien und neun eindeutige eingebettete Bilddateien. Vier Materialien verwenden Bildtexturen. Die tatsächlichen Dreieckszahlen sinken strikt. Die Prüfung kontrolliert Buffer, Accessors, Indexgrenzen, endliche Daten, Normalen, Bilder und Material-/UV-Bezüge über die allgemeine Bibliothek; zusätzlich verlangt sie UVs am `HeroBody` und die oben genannten Bildgrößengrenzen.

Jeder geprüfte Skin verwendet genau diese 15 Gelenknamen: `Pelvis`, `Spine`, `Head`, `Arm_L`, `Arm_R`, `Forearm_L`, `Forearm_R`, `Hand_L`, `Hand_R`, `Thigh_L`, `Thigh_R`, `Shin_L`, `Shin_R`, `Foot_L`, `Foot_R`. Die Gewichte summieren sich innerhalb der Toleranz zu eins. Der größte gemessene Summenfehler liegt bei ungefähr **0,000000119**; es wurden keine ungültigen Gelenkindizes und keine Gewichte außerhalb des zulässigen Bereichs gefunden.

Alle elf erwarteten Clips sind enthalten: `idle`, `march`, `run`, `gather`, `talk`, `train`, `work`, `block`, `attack`, `hit`, `death`. Die Prüfroutine verlangt positive Dauer und tatsächlich variierende exportierte Animationswerte. Das ist ein Datennachweis; Bewegungsqualität, Fußkontakt und sinnvolle Übergänge werden damit nicht automatisch bestätigt.

### Tatsächliche Gesichtsdaten

Die sieben Morphs werden ausdrücklich am skinned `HeroBody` geprüft. Ein lediglich gleich benannter Eintrag an einem Zubehörteil könnte diese Prüfung nicht erfüllen. Jeder Morph besitzt endliche Positionsdeltas und verändert tatsächlich Vertices.

| Morph | Veränderte Positionszeilen in LOD 0 | Veränderte Positionszeilen in LOD 3 |
| --- | ---: | ---: |
| `Mature` | 12.109 | 1.246 |
| `Companion` | 4.368 | 349 |
| `Blink_L` | 348 | 21 |
| `Blink_R` | 348 | 25 |
| `JawOpen` | 959 | 95 |
| `Smile` | 940 | 80 |
| `BrowDown` | 1.695 | 99 |

Die Zahlen beziehen sich auf tatsächlich exportierte Positionszeilen, einschließlich möglicher UV-bedingter Vertexaufteilung; sie sind keine anatomische Klassifikation. Linkes und rechtes Blinzeln besitzen numerisch unterschiedliche Verformungen. Die weitere Abnahme muss die Form dieser Verformung in Bewegung prüfen, besonders bei stark vereinfachten LODs.

Als Negativkontrolle wurden die vier bisherigen `villager`-Dateien dem neuen Prüfläufer übergeben. Er lehnte sie erwartungsgemäß ab, unter anderem wegen des fehlenden `HeroBody`-Vertrags und der größeren Textur in deren LOD 3. Damit wurde kein Fehler der bisherigen Legacy-Laufzeit behauptet.

## 3. Tatsächlich geprüfte Blenderbilder

| Bild | Beobachtung |
| --- | --- |
| [Gesicht der jungen Figur](../../art/hero_quality/review/hero_child_face.png) | Räumliche Nase, Lippen, Lider und Ohren; braune Iris und Sklera sichtbar. Die vorherigen vollständig dunklen Augen sind behoben. Haarvolumen und gleichmäßige Hautwirkung bleiben ausbaufähig. |
| [Junge Figur, Ganzkörper](../../art/hero_quality/review/hero_child_full.png) | Menschliche Körper-, Hand- und Fußformen mit einfacher Tunika und Sandalen. Die großen Schulterlöcher früherer Entwürfe sind geschlossen. Das Bild allein belegt kein exakt wahrgenommenes Alter von zwölf Jahren; dafür bleibt die gestalterische Altersabnahme erforderlich. |
| [Erwachsenenvariante](../../art/hero_quality/review/hero_adult_face.png) | Längere Kiefer-/Gesichtsform; grundlegende Identität bleibt erkennbar. Dieselben Haare und die einfache Kleidung begrenzen die Unterscheidung der Lebensphasen. Eine vollständige spätere Soldatenausstattung ist hier nicht dargestellt. |
| [Blinzeln](../../art/hero_quality/review/hero_blink.png) | Beide Augen werden sichtbar von den Lidern abgedeckt. Am inneren Lidwinkel bleibt eine auffällige Falte beziehungsweise kleine dunkle Kerbe. Eine fertige Nahaufnahmequalität wird deshalb nicht bescheinigt. |
| [Geöffneter Mund](../../art/hero_quality/review/hero_jaw.png) | Kiefer-/Lippenverformung ist sichtbar. Der Mund erscheint als dunkler Hohlraum; Zähne, Zunge und ein ausgearbeiteter Innenraum sind im Bild nicht erkennbar. Für hochwertige sprechende Dialogfiguren reicht diese Darstellung noch nicht aus. |
| [Laufpose](../../art/hero_quality/review/hero_run.png) | Das geskinte Modell und der Saum verändern ihre Pose. Der Saum bildet eine steife, kantige Anhebung. Ein einzelner Frame bestätigt keinen natürlichen kompletten Laufzyklus. |

Die sechs Bilder wurden einzeln angesehen. Sie zeigen tatsächliche gerenderte 3D-Geometrie aus dem Charakterstand, keine bloßen Zielillustrationen. Die vorhandene ältere [Dorf-Nahaufnahme](../13_visual_upgrade/evidence/close-child.webp) wurde ebenfalls gesichtet. Da dort ein anderer Renderer, eine andere Kamera und anderes Licht wirken, wird daraus kein numerischer Vorher-nachher-Qualitätsvergleich abgeleitet.

Die folgenden Bildhashes halten den betrachteten Stand fest:

| Datei | SHA-256 |
| --- | --- |
| `hero_child_face.png` | `d01e5b10b1e9b29a4cab948896cac0017eb51ef706d12ce079a567d23b00f3f8` |
| `hero_child_full.png` | `1a7fccae50672ca05a69b1a1916169b83919aac1973885491abf9ee3d26a9fd3` |
| `hero_adult_face.png` | `3a0524fb946038895335568a2270c87c3f23787728e3f6664c6dd779905b3aae` |
| `hero_blink.png` | `28a659b28e799493f28aabd7588ea6d1575009cf96012e8b4c0772a808a1fe85` |
| `hero_jaw.png` | `b6c4369430f278f3e9e22b7aa0cbe5da31e41b11862f86922ed2c22542166346` |
| `hero_run.png` | `83876f1251ddd98d98cea4f1c0d3af7ba5786ee01adcda4004e4620f02a77c39` |

## 4. Zusätzliche unabhängige Sichtprüfung in Godot

Die abschließenden Bilder unter [evidence/after](../14_character_realism/evidence/after/runtime-review.json) stammen aus einer tatsächlichen Godot-Viewportaufnahme mit dem Produktionsakteur `VillagePerson`. Der Beleg nennt **Godot 4.7.2, OpenGL-Kompatibilitätsrenderer, llvmpipe-Softwaregrafik und 1.600 × 900 Bildpunkte**. Er enthält 18 Aufnahmeeinträge und keine gemeldeten Capturefehler. Die folgende unabhängige Sichtprüfung umfasst gezielt vier dieser Bilder.

Die Bilder verwenden den abschließend korrigierten Lichtstand, der auch für die Legacy-Vergleichsaufnahmen verwendet wurde. Die vier GLB-Hashes im Godot-Beleg stimmen mit dem unabhängigen statischen Prüfbeleg überein; nach dem Lichtwechsel wurden keine anderen Modelldateien eingeschoben.

| Godot-Bild | Unabhängige Beobachtung |
| --- | --- |
| [Erwachsener mit Blinzeln](../14_character_realism/evidence/after/adult-blink.png) | Die Kombination aus Erwachsenenform und Blinzeln ist sichtbar. Der Kopf bleibt zusammenhängend; die Lider decken die Augen weitgehend ab. Das stärkere Seitenlicht zeigt allerdings harte Lidkanten und auffällige dunkle Falten-/Schattenformen. Dies ist keine fertige Gesichtsabnahme. |
| [Junge Figur mit Blinzeln](../14_character_realism/evidence/after/child-blink.png) | Ein Auge bleibt im aufgenommenen Moment teilweise offen. Der Beleg nennt `Blink_L = 0,90785` und `Blink_R = 0,67317`: Das Bild zeigt eine Zwischenphase des wirklichen Controllers, keinen erzwungenen Endzustand mit beiden Gewichten auf eins. Aus diesem Frame allein lässt sich daher kein Fehler eines vollständig geschlossenen Blinks ableiten. Die Lidform braucht weiterhin visuelle Nacharbeit. |
| [Ganzkörper im Alter 22](../14_character_realism/evidence/after/full-body-22.png) | Die Erwachsenenform ist als vollständiger Akteur mit Kleidung und Bodenschatten dargestellt. Große Schulterdurchbrüche sind nicht sichtbar. Einfache Kleidungskonturen und einzelne Kanten am seitlichen Stoff bleiben erkennbar; die entspannte Arm-/Handhaltung ist noch wenig charaktervoll. |
| [LOD 3 absichtlich aus der Nähe](../14_character_realism/evidence/after/asset-lod-3.png) | Der reduzierte Export erscheint tatsächlich im Renderer. Ohren, Haaransatz und Lider werden deutlich kantiger; unter einem Auge bleibt ein kleiner dunkler/rötlicher Dreiecksrest. Der Beleg setzt `forced_asset_lod = true`: Dies ist eine gezielte Nahprüfung des Fernmodells. Dieser LOD darf aus diesem Bild heraus nicht als geeignete Dialog-Nahaufnahme freigegeben werden. |

Beim Erwachsenen-Blink nennt der Beleg Gewichte von ungefähr 0,91217 und 0,98088. Diese Einträge belegen die tatsächliche Kombination im dargestellten Frame, nicht die Qualität sämtlicher Zwischenformen. Auch ein bestandener Funktionstest ersetzt diese visuelle Unterscheidung nicht.

| Abschließende Godot-Datei | SHA-256 |
| --- | --- |
| `adult-blink.png` | `3613a08595cdcc3ffb7b24e5ee78855c728210601db38e6768086ca2ebf92a0e` |
| `child-blink.png` | `9799d1573a9e6b4a0ff6729e06739adfd003c38d79e740f7b761cea521b5ad8b` |
| `full-body-22.png` | `2234cb31ac3fbd636dba30904923de339b75795624c1ccd633a8cd75da10b382` |
| `asset-lod-3.png` | `79851f42a0bf4d2ae1c865003fbc90de32672c09c3cb36695126f903b14078c0` |

Diese Godot-Bilder bestätigen die Integration im kontrollierten Studio. Sie stammen nicht von einem Android-Gerät und bilden keine vollständige Dorf- oder Kampfszene ab. Der Runtime-Beleg nennt außerdem 72 zeitlich abgetastete Marschframes bei vorgesehener Wiedergabe mit 24 Bildern pro Sekunde; diese Wiedergaberate ist ausdrücklich **keine gemessene Gerätebildrate**.

## 5. Grenzen und nächste Abnahmen

Der größte technische Materialstand hat rechnerisch **59.768.832 Bytes beziehungsweise 57 MiB** für seine eindeutigen Bild-Basisstufen bei vier Bytes pro Pixel. Dies ist eine unkomprimierte Quellbildschätzung ohne Mipmaps; sie ist weder gemessener Android-Grafikspeicher noch eine Aussage über die tatsächliche GPU-Texturkompression. Der kleinere LOD-Stand reduziert diesen Wert, aber Gerätebudget, Texturlebensdauer und gleichzeitig sichtbare Figuren müssen im Spiel gemessen werden.

Vor einer offiziellen visuellen Abnahme bleiben besonders relevant:

1. Haarform und Haaransatz, natürliche Hautvariation, Augenfeuchtigkeit und korrigierte innere Lidform in tatsächlichen Dialogansichten.
2. Ausgearbeiteter Mundraum und glaubwürdige Sprechbewegungen; ein einzelner Kiefer-Morph ersetzt keine geprüften Dialoganimationen.
3. Sauberer Schnitt, nachvollziehbare Säume und Nähte, natürliche Gewichtsverteilung der Kleidung sowie korrekte Verformung beim Laufen, Blocken und Kämpfen.
4. Die Alterswirkung derselben Person in neutraler Vorder-, Profil- und Dreiviertelansicht sowie bei Bewegung. Das [Buildprotokoll](../../art/hero_quality/build_report.json) beschreibt die Erwachsenenform als an ein gemeinsames Rest-Rig angepassten Morph; daraus wird keine vollständig eigenständige Erwachsenen-Rig-Produktion abgeleitet.
5. Integration in die tatsächliche Spielkamera und anschließende Bedienungs-, Bildraten- und Temperaturprüfung auf einem benannten Android-Gerät mit bestimmtem Build. Der aktuelle statische Audit und diese Blenderbilder bestätigen diese Geräteabnahme nicht.

Die historische Besetzung und die vorhandenen Kalenderstarts 94/100 n. Chr. sind im [separaten Quellenblatt](CHARACTER_REFERENCE_SOURCES_2026_11_22.md) dokumentiert. Dieser technische Charakterexport erstellt keine fertigen historischen Personen und ändert die bestehende Epoche nicht.
